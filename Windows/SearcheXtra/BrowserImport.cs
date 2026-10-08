using Microsoft.Data.Sqlite;
using System.Text.Json;

namespace SearcheXtra.Windows;

public sealed record ImportResult(List<Bookmark> Bookmarks, List<HistoryEntry> History);
public static class BrowserImport
{
    public static List<Bookmark> ChromeBookmarks(string json)
    {
        using var doc = JsonDocument.Parse(json);
        Bookmark? Read(JsonElement node)
        {
            var title = node.TryGetProperty("name", out var name) ? name.GetString() ?? "" : "";
            if (node.TryGetProperty("children", out var children)) return new() { Title = title, Children = children.EnumerateArray().Select(Read).OfType<Bookmark>().ToList() };
            if (node.TryGetProperty("url", out var url) && AddressParser.IsWeb(url.GetString() ?? "")) return new() { Title = title, Url = url.GetString() };
            return null;
        }
        return doc.RootElement.GetProperty("roots").EnumerateObject().Select(p => Read(p.Value)).OfType<Bookmark>().ToList();
    }
    public static async Task<ImportResult> ProfileAsync(string folder)
    {
        var bookmarks = new List<Bookmark>(); var history = new List<HistoryEntry>();
        var chromeBookmarks = Path.Combine(folder, "Bookmarks"); var firefox = Path.Combine(folder, "places.sqlite");
        if (File.Exists(chromeBookmarks)) bookmarks.AddRange(ChromeBookmarks(await File.ReadAllTextAsync(chromeBookmarks)));
        var db = File.Exists(firefox) ? firefox : Path.Combine(folder, "History");
        if (!File.Exists(db)) return new(bookmarks, history);
        await using var connection = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = db, Mode = SqliteOpenMode.ReadOnly }.ToString()); await connection.OpenAsync();
        if (File.Exists(firefox))
        {
            using var query = connection.CreateCommand(); query.CommandText = "SELECT b.id,b.parent,b.type,COALESCE(b.title,''),p.url FROM moz_bookmarks b LEFT JOIN moz_places p ON b.fk=p.id ORDER BY b.position";
            using var reader = await query.ExecuteReaderAsync(); var nodes = new Dictionary<long, (long Parent, Bookmark Node)>();
            while (await reader.ReadAsync()) { var type = reader.GetInt32(2); var url = reader.IsDBNull(4) ? null : reader.GetString(4); if (type == 2 || type == 1 && AddressParser.IsWeb(url ?? "")) nodes[reader.GetInt64(0)] = (reader.GetInt64(1), new() { Title = reader.GetString(3), Url = type == 1 ? url : null, Children = type == 2 ? [] : null }); }
            foreach (var item in nodes.Values) if (nodes.TryGetValue(item.Parent, out var parent) && parent.Node.Children != null) parent.Node.Children.Add(item.Node); else bookmarks.Add(item.Node);
        }
        using var visits = connection.CreateCommand(); visits.CommandText = File.Exists(firefox) ? "SELECT url,COALESCE(title,''),last_visit_date FROM moz_places WHERE last_visit_date IS NOT NULL ORDER BY last_visit_date DESC LIMIT 10000" : "SELECT url,COALESCE(title,''),last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 10000";
        using var rows = await visits.ExecuteReaderAsync();
        while (await rows.ReadAsync()) { var url = rows.GetString(0); if (!AddressParser.IsWeb(url)) continue; var milliseconds = rows.GetInt64(2) / 1000 - (File.Exists(firefox) ? 0 : 11644473600000L); if (milliseconds < -62135596800000L || milliseconds > 253402300799999L) continue; history.Add(new(url, rows.GetString(1), DateTimeOffset.FromUnixTimeMilliseconds(milliseconds))); }
        return new(bookmarks, history);
    }
}
