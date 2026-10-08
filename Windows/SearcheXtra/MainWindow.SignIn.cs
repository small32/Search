using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private (Guid Tab, string Verifier, DateTimeOffset Started)? aiSignIn;
    private const string AICallback = "https://officecommun.com/search/ai/callback";
    private void StartAISignIn()
    {
        static string Base64Url(byte[] bytes) => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var verifier = Base64Url(RandomNumberGenerator.GetBytes(32)); var challenge = Base64Url(SHA256.HashData(Encoding.UTF8.GetBytes(verifier)));
        DismissOverlay(); var tab = AddTab("https://openrouter.ai/auth?callback_url=" + Uri.EscapeDataString(AICallback) + "&code_challenge=" + challenge + "&code_challenge_method=S256&key_label=SearcheXtra");
        aiSignIn = (tab.Id, verifier, DateTimeOffset.UtcNow);
    }
    private bool InterceptAISignIn(BrowserTab tab, string target, string source)
    {
        if (aiSignIn is not { } flow || flow.Tab != tab.Id || !Uri.TryCreate(target, UriKind.Absolute, out var uri) || uri.GetLeftPart(UriPartial.Path) != AICallback) return false;
        aiSignIn = null;
        if (DateTimeOffset.UtcNow - flow.Started > TimeSpan.FromMinutes(10) || !Uri.TryCreate(source, UriKind.Absolute, out var from) || from.Host != "openrouter.ai") { Status.Text = T("Sign-in expired.", "登录已过期。"); return true; }
        var code = uri.Query.TrimStart('?').Split('&').Select(s => s.Split('=', 2)).FirstOrDefault(p => p.Length == 2 && p[0] == "code")?[1];
        if (string.IsNullOrEmpty(code) || code.Length > 1024) { Status.Text = T("Sign-in returned no code.", "登录未返回授权码。"); return true; }
        _ = FinishAISignInAsync(tab, Uri.UnescapeDataString(code), flow.Verifier); return true;
    }
    private async Task FinishAISignInAsync(BrowserTab tab, string code, string verifier)
    {
        try
        {
            using var handler = new HttpClientHandler { AllowAutoRedirect = false }; using var client = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(30) };
            using var response = await client.PostAsync("https://openrouter.ai/api/v1/auth/keys", new StringContent(JsonSerializer.Serialize(new { code, code_verifier = verifier, code_challenge_method = "S256" }), Encoding.UTF8, "application/json"));
            if (!response.IsSuccessStatusCode) throw new HttpRequestException($"Sign-in failed: HTTP {(int)response.StatusCode}");
            using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync()); await AIClient.SaveKeyAsync("openRouter", doc.RootElement.GetProperty("key").GetString() ?? "");
            CloseTab(tab); Settings.AIProvider = "openRouter"; Settings.AIEnabled = true; Settings.SettingsPage = "ai"; ScheduleSave(); await ShowSettingsAsync();
        }
        catch (Exception ex) { Status.Text = ex.Message; }
    }
}
