using System.Text.Json;

namespace SearcheXtra.Windows;

public sealed class DataStore
{
    public static string Root { get; } = Environment.GetEnvironmentVariable("SEARCHEXTRA_DATA_DIR") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SearcheXtra");
    public BrowserSettings Settings { get; set; } = new();
    public List<Bookmark> Bookmarks { get; set; } = [];
    public List<HistoryEntry> History { get; set; } = [];
    public List<DownloadRecord> Downloads { get; set; } = [];
    public List<string> Spaces { get; set; } = ["Default"];
    public Dictionary<string, List<string>> HiddenElements { get; set; } = [];
    public SessionState Session { get; set; } = new();
    public List<SessionState> WindowSessions { get; set; } = [];
    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly JsonSerializerOptions json = new() { WriteIndented = true };
    public event Action? Changed;
    public void Notify() => Changed?.Invoke();

    public static async Task<DataStore> LoadAsync()
    {
        Directory.CreateDirectory(Root);
        var store = new DataStore();
        store.Settings = await ReadAsync("settings.json", new BrowserSettings());
        store.Bookmarks = await ReadAsync("bookmarks.json", new List<Bookmark>());
        store.History = await ReadAsync("history.json", new List<HistoryEntry>());
        store.Downloads = await ReadAsync("downloads.json", new List<DownloadRecord>());
        store.Spaces = await ReadAsync("spaces.json", new List<string> { "Default" });
        store.HiddenElements = await ReadAsync("hidden.json", new Dictionary<string, List<string>>());
        store.Session = await ReadAsync("session.json", new SessionState());
        store.WindowSessions = await ReadAsync("windows.json", new List<SessionState>());
        if (store.Spaces.Count == 0) store.Spaces.Add("Default");
        return store;
    }

    private static async Task<T> ReadAsync<T>(string file, T fallback)
    {
        var path = Path.Combine(Root, file);
        if (!File.Exists(path)) return fallback;
        try
        {
            await using var stream = File.OpenRead(path);
            return await JsonSerializer.DeserializeAsync<T>(stream) ?? fallback;
        }
        catch (JsonException) { File.Copy(path, path + ".corrupt-" + DateTime.UtcNow.Ticks); return fallback; }
    }

    public async Task SaveAsync()
    {
        // Copy UI-owned collections, then encode and write them off the UI thread.
        static Bookmark Copy(Bookmark node) => new() { Id = node.Id, Title = node.Title, Url = node.Url, Children = node.Children?.Select(Copy).ToList() };
        var snapshot = new Dictionary<string, object>
        {
            ["settings.json"] = JsonSerializer.Deserialize<BrowserSettings>(JsonSerializer.Serialize(Settings))!,
            ["bookmarks.json"] = Bookmarks.Select(Copy).ToArray(),
            ["history.json"] = History.Take(10000).ToArray(),
            ["downloads.json"] = Downloads.Take(50).ToArray(),
            ["spaces.json"] = Spaces.ToArray(),
            ["hidden.json"] = HiddenElements.ToDictionary(p => p.Key, p => p.Value.ToArray()),
            ["session.json"] = Session,
            ["windows.json"] = WindowSessions.ToArray()
        };
        await gate.WaitAsync();
        try
        {
            foreach (var (file, value) in snapshot)
            {
                var contents = await Task.Run(() => JsonSerializer.Serialize(value, json));
                var path = Path.Combine(Root, file);
                await File.WriteAllTextAsync(path + ".tmp", contents);
                File.Move(path + ".tmp", path, true);
            }
        }
        finally { gate.Release(); }
    }
}
