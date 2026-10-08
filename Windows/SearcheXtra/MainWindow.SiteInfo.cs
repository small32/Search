using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Web.WebView2.Core;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;

namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private void SiteInfo_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not FrameworkElement anchor || active == null || !AddressParser.IsWeb(active.Url) || ActiveView is not { } view) return;
        var uri = new Uri(active.Url);
        var core = view.Control.CoreWebView2;
        var flyout = new Flyout { Placement = Microsoft.UI.Xaml.Controls.Primitives.FlyoutPlacementMode.Bottom };
        var panel = new StackPanel { Width = 320, Spacing = 12 };
        var message = new TextBlock { TextWrapping = TextWrapping.Wrap };
        void Header(string title, bool back = true)
        {
            panel.Children.Clear();
            var row = new Grid();
            var text = new TextBlock { Text = title, FontSize = 16, VerticalAlignment = VerticalAlignment.Center };
            row.Children.Add(text);
            var close = QuietButton("×"); close.HorizontalAlignment = HorizontalAlignment.Right; close.Click += (_, _) => flyout.Hide(); row.Children.Add(close);
            panel.Children.Add(row);
            if (back) { var previous = QuietButton(T("‹ Site information", "‹ 网站信息")); previous.Click += (_, _) => Front(); panel.Children.Add(previous); }
            message.Text = "";
        }
        void Action(string title, Func<Task> action)
        {
            var button = QuietButton(title); button.HorizontalAlignment = HorizontalAlignment.Stretch; button.HorizontalContentAlignment = HorizontalAlignment.Left;
            button.Click += async (_, _) => { try { await action(); } catch { message.Text = T("Could not complete this action. Try again.", "操作未完成，请重试。"); if (!panel.Children.Contains(message)) panel.Children.Add(message); } };
            panel.Children.Add(button);
        }
        void Front()
        {
            Header(uri.Host, false);
            Action(view.ConnectionSecurityState == "secure" ? T("Connection is secure  ›", "连接是安全的  ›") : T("Connection information  ›", "连接信息  ›"), Connection);
            Action(T("Cookies and site data  ›", "Cookie 和网站数据  ›"), Cookies);
            Action(T("Site settings  ↗", "网站设置  ↗"), async () => { flyout.Hide(); await ShowSiteCardAsync(); });
        }
        async Task Connection()
        {
            Header(T("Connection information", "连接信息"));
            panel.Children.Add(new TextBlock { Text = view.ConnectionSecurityState == "secure" ? T("The connection to this site is encrypted and verified.", "与此网站的连接已加密，证书已验证。") : uri.Scheme == "http" ? T("This connection is not encrypted.", "此连接未加密。") : T("This connection is not fully verified as secure.", "此连接未被完整验证为安全。"), TextWrapping = TextWrapping.Wrap });
            if (uri.Scheme == "https")
            {
                using var result = JsonDocument.Parse(await core.CallDevToolsProtocolMethodAsync("Network.getCertificate", JsonSerializer.Serialize(new { origin = uri.GetLeftPart(UriPartial.Authority) })));
                if (result.RootElement.TryGetProperty("tableNames", out var certificates) && certificates.GetArrayLength() > 0)
                {
                    using var certificate = new X509Certificate2(Convert.FromBase64String(certificates[0].GetString()!));
                    panel.Children.Add(new TextBlock { Text = T("Certificate", "证书") + "\n" + T("Subject: ", "颁发对象：") + certificate.Subject + "\n" + T("Issuer: ", "颁发机构：") + certificate.Issuer + "\n" + T("Valid from: ", "有效期开始：") + certificate.NotBefore.ToString("g") + "\n" + T("Valid until: ", "有效期结束：") + certificate.NotAfter.ToString("g"), TextWrapping = TextWrapping.Wrap });
                }
                else panel.Children.Add(new TextBlock { Text = T("No certificate available for this page.", "此页面暂无可查看的证书。") });
            }
        }
        async Task Cookies()
        {
            Header(T("Cookies and site data", "Cookie 和网站数据"));
            var cookies = await core.CookieManager.GetCookiesAsync(uri.AbsoluteUri);
            panel.Children.Add(new TextBlock { Text = T("Cookies: ", "Cookie 数量：") + cookies.Count });
            var list = new StackPanel { Spacing = 10 };
            foreach (var cookie in cookies)
            {
                var entry = new StackPanel { Spacing = 4 };
                entry.Children.Add(new TextBlock { Text = cookie.Name + "\n" + cookie.Domain + cookie.Path, TextWrapping = TextWrapping.Wrap });
                var value = new TextBox { Text = cookie.Value, Header = T("Value", "值") }; entry.Children.Add(value);
                var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
                var save = QuietButton(T("Save", "保存")); save.Click += (_, _) => { cookie.Value = value.Text; core.CookieManager.AddOrUpdateCookie(cookie); message.Text = T("Cookie saved.", "Cookie 已保存。"); };
                var remove = QuietButton(T("Delete", "删除")); remove.Click += async (_, _) => { core.CookieManager.DeleteCookie(cookie); await Cookies(); };
                actions.Children.Add(save); actions.Children.Add(remove); entry.Children.Add(actions); list.Children.Add(entry);
            }
            panel.Children.Add(new ScrollViewer { Content = list, MaxHeight = 300 });
            Action(T("Clear this site's data", "清除此网站数据"), async () => { await ClearSiteDataAsync(core, uri); await Cookies(); message.Text = T("Site data cleared. Reload to apply.", "网站数据已清除，刷新页面后生效。"); });
            panel.Children.Add(message);
        }
        Front(); flyout.Content = panel; anchor.Tag = flyout; flyout.ShowAt(anchor);
    }

    private static async Task ClearSiteDataAsync(CoreWebView2 core, Uri uri)
    {
        foreach (var cookie in await core.CookieManager.GetCookiesAsync(uri.AbsoluteUri)) core.CookieManager.DeleteCookie(cookie);
        await core.CallDevToolsProtocolMethodAsync("Storage.clearDataForOrigin", JsonSerializer.Serialize(new { origin = uri.GetLeftPart(UriPartial.Authority), storageTypes = "all" }));
        if (Uri.TryCreate(core.Source, UriKind.Absolute, out var current) && current.GetLeftPart(UriPartial.Authority) == uri.GetLeftPart(UriPartial.Authority))
            await core.ExecuteScriptAsync("sessionStorage.clear()");
    }
}
