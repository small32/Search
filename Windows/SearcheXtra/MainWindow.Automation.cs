using System.IO.Pipes;
using System.Text;
using System.Text.Json;

namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private CancellationTokenSource? benchCancellation;
    private readonly Dictionary<Guid, BrowserTab> benchTabs = [];
    private void UpdateBench()
    {
        if (Settings.Bench && App.Windows.Count > 0 && App.Windows.First() != this) return;
        if (Settings.Bench && benchCancellation == null)
        {
            benchCancellation = new(); var cancellation = benchCancellation.Token;
            var name = "SearcheXtra-" + Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(DataStore.Root)))[..20];
            File.WriteAllText(Path.Combine(DataStore.Root, "bench-pipe.txt"), name);
            _ = Task.Run(async () =>
            {
                while (!cancellation.IsCancellationRequested)
                {
                    try
                    {
                        await using var pipe = new NamedPipeServerStream(name, PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
                        await pipe.WaitForConnectionAsync(cancellation); using var reader = new StreamReader(pipe, leaveOpen: true); using var writer = new StreamWriter(pipe, leaveOpen: true) { AutoFlush = true };
                        var line = await reader.ReadLineAsync(cancellation); if (line == null) continue;
                        var done = new TaskCompletionSource<string>();
                        DispatcherQueue.TryEnqueue(async () => { try { done.SetResult(await BenchRequestAsync(line)); } catch (Exception ex) { done.SetResult(JsonSerializer.Serialize(new { error = ex.Message })); } });
                        await writer.WriteLineAsync(await done.Task.WaitAsync(cancellation));
                    }
                    catch (OperationCanceledException) { break; }
                    catch (IOException) { }
                }
            });
        }
        else if (!Settings.Bench && benchCancellation != null)
        {
            benchCancellation.Cancel(); benchCancellation.Dispose(); benchCancellation = null;
            foreach (var tab in benchTabs.Values.ToArray()) CloseTab(tab); benchTabs.Clear();
        }
    }
    private async Task<string> BenchRequestAsync(string line)
    {
        using var doc = JsonDocument.Parse(line); var request = doc.RootElement; var op = request.GetProperty("op").GetString();
        if (op == "open")
        {
            var url = request.GetProperty("url").GetString() ?? ""; if (!AddressParser.IsWeb(url)) throw new ArgumentException("HTTP(S) URL required.");
            var created = AddTab(url, false, true); benchTabs[created.Id] = created; await GetViewAsync(created); return JsonSerializer.Serialize(new { id = created.Id });
        }
        if (op == "tabs") return JsonSerializer.Serialize(benchTabs.Values.Select(t => new { id = t.Id, url = t.Url, title = t.Title, loading = t.Loading }));
        var id = request.GetProperty("id").GetGuid(); if (!benchTabs.TryGetValue(id, out var tab)) throw new ArgumentException("The script can only access its own tabs.");
        if (op == "close") { benchTabs.Remove(id); CloseTab(tab); return "{\"ok\":true}"; }
        var view = await GetViewAsync(tab);
        if (op == "eval") return await view.Control.CoreWebView2.ExecuteScriptAsync(request.GetProperty("script").GetString() ?? "");
        if (op == "navigate") { var url = request.GetProperty("url").GetString() ?? ""; if (!AddressParser.IsWeb(url)) throw new ArgumentException("HTTP(S) URL required."); view.Navigate(url); return "{\"ok\":true}"; }
        throw new ArgumentException("Unknown operation.");
    }
    private async Task<bool> RunAddressCommandAsync(string text)
    {
        if (!Settings.AddressCommands) return false;
        switch (text.Trim().ToLowerInvariant())
        {
            case "settings": case "preferences": case "设置": case "偏好设置": await ShowSettingsAsync(); break;
            case "new tab": case "新建标签页": AddTab(); break;
            case "private tab": case "new private tab": case "无痕标签页": case "新建无痕标签页": AddTab(isPrivate: true); break;
            case "bookmarks": case "书签": await ShowBookmarksAsync(); break;
            case "history": case "历史记录": await ShowHistoryAsync(); break;
            case "downloads": case "下载": await ShowDownloadsAsync(); break;
            case "passwords": case "密码": await ShowPasswordsAsync(); break;
            case "new space": case "新建空间": if (!Settings.UsesSpaces) return false; await CreateSpaceAsync(); break;
            case "sidebar": case "toggle sidebar": case "切换侧边栏": case "侧边栏": Settings.Sidebar = !Settings.Sidebar; store.Notify(); ScheduleSave(); break;
            default: return false;
        }
        EndAddressEdit(); return true;
    }
    private async Task CreateSpaceAsync()
    {
        var name = await PromptAsync(T("New space", "新建空间"), T("Name", "名称")); if (string.IsNullOrWhiteSpace(name) || store.Spaces.Contains(name)) return;
        store.Spaces.Add(name); space = name; ApplySettings(); RefreshTabLists(); AddTab(); ScheduleSave();
    }
}
