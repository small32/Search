using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Text.Json;

namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private async Task ShowHiddenAsync()
    {
        if (active == null || !AddressParser.IsWeb(active.Url) || ActiveView?.Control.CoreWebView2 is not { } core) return;
        var host = new Uri(active.Url).Host; var panel = new StackPanel { Spacing = 8 };
        async Task RefreshRules()
        {
            foreach (var view in views.Values) await view.UpdateDocumentScriptAsync(); ScheduleSave(); core.Reload();
        }
        foreach (var selector in store.HiddenElements.GetValueOrDefault(host, []).ToArray())
        {
            var row = new Grid { ColumnSpacing = 8 }; row.ColumnDefinitions.Add(new() { Width = new(1, GridUnitType.Star) }); row.ColumnDefinitions.Add(new() { Width = GridLength.Auto });
            var name = new TextBlock { Text = selector, FontSize = 12, TextTrimming = TextTrimming.CharacterEllipsis, VerticalAlignment = VerticalAlignment.Center }; row.Children.Add(name);
            row.PointerEntered += async (_, _) => await core.ExecuteScriptAsync("(()=>{const e=document.querySelector(" + JsonSerializer.Serialize(selector) + ");if(!e)return;window.__searchHiddenPreview=[e,e.getAttribute('style')];e.style.setProperty('display','block','important');e.style.setProperty('outline','2px solid #999','important');e.scrollIntoView({block:'center'});})()");
            row.PointerExited += async (_, _) => await core.ExecuteScriptAsync("(()=>{const r=window.__searchHiddenPreview;if(!r)return;if(r[1]===null)r[0].removeAttribute('style');else r[0].setAttribute('style',r[1]);delete window.__searchHiddenPreview;})()");
            var restore = QuietButton(T("Restore", "恢复")); restore.Click += async (_, _) => { store.HiddenElements[host].Remove(selector); panel.Children.Remove(row); await RefreshRules(); }; Grid.SetColumn(restore, 1); row.Children.Add(restore); panel.Children.Add(row);
        }
        var controls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 }; var pick = QuietButton(T("Hide something", "隐藏元素")); pick.Click += async (_, _) => { DismissOverlay(); if (ActiveView != null) await ActiveView.PickHiddenElementAsync(); }; controls.Children.Add(pick);
        var all = QuietButton(T("Restore all", "全部恢复")); all.Click += async (_, _) => { store.HiddenElements.Remove(host); DismissOverlay(); await RefreshRules(); }; controls.Children.Add(all); panel.Children.Add(controls);
        await ShowCardAsync(host, panel);
        if (ActiveView?.Control.CoreWebView2 == core) await core.ExecuteScriptAsync("(()=>{const r=window.__searchHiddenPreview;if(r){if(r[1]===null)r[0].removeAttribute('style');else r[0].setAttribute('style',r[1]);delete window.__searchHiddenPreview;}})()");
    }
    private async Task ShowNavigationHistoryAsync(bool back, FrameworkElement anchor)
    {
        if (ActiveView?.Control.CoreWebView2 is not { } core || !Settings.HoldsHistory) return;
        using var doc = JsonDocument.Parse(await core.CallDevToolsProtocolMethodAsync("Page.getNavigationHistory", "{}")); var current = doc.RootElement.GetProperty("currentIndex").GetInt32(); var entries = doc.RootElement.GetProperty("entries").EnumerateArray().ToList();
        var menu = new MenuFlyout(); var chosen = back ? entries.Take(current).Reverse() : entries.Skip(current + 1);
        foreach (var entry in chosen) { var id = entry.GetProperty("id").GetInt32(); var label = entry.GetProperty("title").GetString(); AddMenu(menu, string.IsNullOrWhiteSpace(label) ? entry.GetProperty("url").GetString() ?? "" : label, async () => await core.CallDevToolsProtocolMethodAsync("Page.navigateToHistoryEntry", JsonSerializer.Serialize(new { entryId = id }))); }
        if (menu.Items.Count > 0) menu.ShowAt(anchor);
    }
}
