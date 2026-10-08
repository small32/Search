using System.Globalization;
using System.Text.Json;

namespace SearcheXtra.Windows;

public sealed class Strings(BrowserSettings settings)
{
    private static readonly Dictionary<string, Dictionary<string,string>> catalog = JsonSerializer.Deserialize<Dictionary<string,Dictionary<string,string>>>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Assets", "Translations.json")))!;
    public string Key(string key) => catalog.TryGetValue(key, out var text) ? text.GetValueOrDefault(Chinese ? "zh-Hans" : "en", key) : key;
    public bool Chinese => settings.Language == "zh-Hans" || settings.Language == "system" && CultureInfo.CurrentUICulture.Name.StartsWith("zh");
    public string Text(string english, string chinese) => Chinese ? chinese : english;
}
