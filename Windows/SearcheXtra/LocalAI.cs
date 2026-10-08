using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace SearcheXtra.Windows;

public static class LocalAI
{
    public static string ModelPath => Path.Combine(DataStore.Root, "AI", "Qwen3-1.7B-Q4_K_M.gguf");
    private const string ModelUrl = "https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/d7f544eead698dbd1f15126ef60b45a1e1933222/Qwen3-1.7B-Q4_K_M.gguf";
    private const string ModelHash = "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897";
    private const long ModelSize = 1_107_409_472;
    private static readonly SemaphoreSlim gate = new(1, 1);
    private static Process? worker;
    private static Timer? idle;
    public static async Task InstallAsync(IProgress<double>? progress, CancellationToken cancellation = default)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(ModelPath)!);
        using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(30) }; using var response = await client.GetAsync(ModelUrl, HttpCompletionOption.ResponseHeadersRead, cancellation); response.EnsureSuccessStatusCode();
        await using var input = await response.Content.ReadAsStreamAsync(cancellation);
        await using (var output = File.Create(ModelPath + ".download")) { var buffer = new byte[131072]; long read = 0; int size; while ((size = await input.ReadAsync(buffer, cancellation)) > 0) { await output.WriteAsync(buffer.AsMemory(0, size), cancellation); read += size; progress?.Report((double)read / ModelSize); } }
        await VerifyAsync(ModelPath + ".download", cancellation); File.Move(ModelPath + ".download", ModelPath, true);
    }
    public static async Task ImportAsync(string path, CancellationToken cancellation = default)
    {
        await VerifyAsync(path, cancellation); Directory.CreateDirectory(Path.GetDirectoryName(ModelPath)!);
        Stop(); File.Copy(path, ModelPath, true);
    }
    private static async Task VerifyAsync(string path, CancellationToken cancellation)
    {
        await using var stream = File.OpenRead(path);
        if (stream.Length != ModelSize || Convert.ToHexString(await SHA256.HashDataAsync(stream, cancellation)).ToLowerInvariant() != ModelHash) throw new InvalidDataException("Local model verification failed.");
    }
    public static async Task<string> AskAsync(string system, string prompt, CancellationToken cancellation, string? workerPath = null)
    {
        await gate.WaitAsync(cancellation);
        try
        {
            idle?.Dispose();
            if (worker == null || worker.HasExited)
            {
                await VerifyAsync(ModelPath, cancellation);
                var start = new ProcessStartInfo(workerPath ?? Path.Combine(AppContext.BaseDirectory, "AIWorker", "SearcheXtra.AIWorker.exe")) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
                start.ArgumentList.Add(ModelPath); worker = Process.Start(start) ?? throw new InvalidOperationException("Could not start local AI engine.");
                _ = worker.StandardError.ReadToEndAsync();
                var ready = await worker.StandardOutput.ReadLineAsync(cancellation);
                if (ready == null || !ready.Contains("\"ready\":true")) throw new InvalidOperationException("Local model could not be loaded.");
            }
            await worker.StandardInput.WriteLineAsync(JsonSerializer.Serialize(new { system, prompt })); await worker.StandardInput.FlushAsync(cancellation);
            var text = new StringBuilder();
            while (await worker.StandardOutput.ReadLineAsync(cancellation) is { } line)
            {
                using var doc = JsonDocument.Parse(line);
                if (doc.RootElement.TryGetProperty("piece", out var piece)) text.Append(piece.GetString());
                if (doc.RootElement.TryGetProperty("error", out _)) throw new InvalidOperationException("Local inference failed.");
                if (doc.RootElement.TryGetProperty("done", out _)) { idle = new Timer(_ => { if (gate.Wait(0)) { try { Stop(); } finally { gate.Release(); } } }, null, TimeSpan.FromMinutes(5), Timeout.InfiniteTimeSpan); return System.Text.RegularExpressions.Regex.Replace(text.ToString(), @"<think>[\s\S]*?</think>", "").Trim(); }
            }
            throw new InvalidOperationException("Local AI engine stopped.");
        }
        catch { Stop(); throw; }
        finally { gate.Release(); }
    }
    public static void Stop() { if (worker is { HasExited: false }) worker.Kill(true); worker?.Dispose(); worker = null; idle?.Dispose(); idle = null; }
}
