using System.Text.Json;

namespace SearcheXtra.Windows;

public static class ReleaseUpdates
{
    public static string Version => typeof(ReleaseUpdates).Assembly.GetName().Version!.ToString(3);
    public static async Task<string> LatestAsync()
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(20) }; client.DefaultRequestHeaders.UserAgent.ParseAdd("SearcheXtra/" + Version);
        using var doc = JsonDocument.Parse(await client.GetStringAsync("https://api.github.com/repos/small32/SearcheXtra/releases/latest"));
        return doc.RootElement.GetProperty("tag_name").GetString() + "\n\n" + doc.RootElement.GetProperty("body").GetString();
    }
}
