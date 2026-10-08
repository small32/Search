using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Web.WebView2.Core;
using System.Text.Json;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private async void StoreInstall_Click(object sender, RoutedEventArgs e) { if (active != null && CrxInstaller.StoreId(active.Url) is { } id) await InstallStoreExtensionAsync(id); }
    private bool extensionBusy;
    private async Task<CoreWebView2Profile> CurrentProfileAsync()
    {
        if (active == null) throw new InvalidOperationException("No active tab.");
        return (await GetViewAsync(active)).Control.CoreWebView2.Profile;
    }
    private async Task InstallStoreExtensionAsync(string text)
    {
        var id = CrxInstaller.Id(text);
        if (id == null || extensionBusy) return;
        extensionBusy = true;
        try
        {
            Status.Text = T("Downloading and verifying extension…", "正在下载并校验扩展…");
            var folder = await CrxInstaller.FetchAsync(id, Path.Combine(DataStore.Root, "Extensions"));
            using var doc = JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(folder, "manifest.json")));
            var permissions = doc.RootElement.TryGetProperty("permissions", out var p) ? p.GetRawText() : "[]";
            if (doc.RootElement.TryGetProperty("host_permissions", out p)) permissions += "\n" + p.GetRawText();
            DismissOverlay();
            var explanation = new TextBlock { Text = T("Requested permissions:\n", "请求的权限：\n") + permissions, TextWrapping = TextWrapping.Wrap, MaxWidth = 480 };
            if (await ShowCardAsync(T("Install extension", "安装扩展"), explanation, T("Install", "安装")) != ContentDialogResult.Primary) return;
            await InstallExtensionFolderAsync(folder, id);
        }
        catch (Exception ex) { Status.Text = T("Extension installation failed: ", "扩展安装失败：") + ex.Message; }
        finally { extensionBusy = false; }
    }
    private async Task InstallExtensionFolderAsync(string folder, string? storeId = null)
    {
        using var doc = JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(folder, "manifest.json")));
        var manifest = doc.RootElement;
        var manifestVersion = manifest.GetProperty("manifest_version").GetInt32();
        if (manifestVersion is not (2 or 3)) throw new InvalidDataException(T("Only Manifest V2 and V3 extensions are supported.", "仅支持 Manifest V2 和 V3 扩展。"));
        var profile = await CurrentProfileAsync();
        if (storeId != null && Settings.Extensions.FirstOrDefault(e => e.StoreId == storeId) is { } previous) { var installed = (await profile.GetBrowserExtensionsAsync()).FirstOrDefault(e => e.Id == previous.Id); if (installed != null) await installed.RemoveAsync(); }
        CoreWebView2BrowserExtension native;
        try { native = await profile.AddBrowserExtensionAsync(folder); }
        catch (Exception ex)
        {
            if (storeId != null && Settings.Extensions.FirstOrDefault(e => e.StoreId == storeId) is { } restore && Directory.Exists(restore.Folder)) { var restored = await profile.AddBrowserExtensionAsync(restore.Folder); await restored.EnableAsync(restore.Enabled); }
            if (manifestVersion == 2 && ex is System.Runtime.InteropServices.COMException) throw new InvalidOperationException(T("This WebView2 Runtime rejected the MV2 extension. ", "当前 WebView2 Runtime 拒绝加载此 MV2 扩展。") + "Runtime: " + ActiveView?.Control.CoreWebView2.Environment.BrowserVersionString, ex);
            throw;
        }
        var item = Settings.Extensions.FirstOrDefault(e => e.Id == native.Id) ?? new InstalledExtension();
        if (item.Folder.Length > 0 && item.Folder != folder) Settings.ExtensionFolders.Remove(item.Folder);
        await native.EnableAsync(item.Enabled);
        Settings.RemovedExtensionIds.Remove(native.Id);
        item.ManifestVersion = manifestVersion;
        item.Id = native.Id; item.Name = native.Name; item.Folder = Path.GetFullPath(folder); item.StoreId = storeId;
        item.Version = manifest.GetProperty("version").GetString() ?? "";
        item.Popup = item.Options = item.NewTab = "";
        if (manifest.TryGetProperty("action", out var action) || manifest.TryGetProperty("browser_action", out action) || manifest.TryGetProperty("page_action", out action))
            if (action.TryGetProperty("default_popup", out var popup)) item.Popup = popup.GetString() ?? "";
        if (manifest.TryGetProperty("options_ui", out var options)) item.Options = options.GetProperty("page").GetString() ?? "";
        else if (manifest.TryGetProperty("options_page", out options)) item.Options = options.GetString() ?? "";
        if (manifest.TryGetProperty("chrome_url_overrides", out var overrides) && overrides.TryGetProperty("newtab", out var newtab)) item.NewTab = newtab.GetString() ?? "";
        if (!Settings.Extensions.Contains(item)) Settings.Extensions.Add(item);
        if (!Settings.ExtensionFolders.Contains(item.Folder)) Settings.ExtensionFolders.Add(item.Folder);
        Status.Text = T("Installed: ", "已安装：") + item.Name; store.Notify(); ScheduleSave();
    }
    private async Task SetExtensionEnabledAsync(InstalledExtension item, bool enabled)
    {
        var current = await CurrentProfileAsync();
        foreach (var profile in views.Values.Where(v => v.Control.CoreWebView2 != null).Select(v => v.Control.CoreWebView2.Profile).Append(current).DistinctBy(p => (p.ProfileName, p.IsInPrivateModeEnabled)))
        {
            var native = (await profile.GetBrowserExtensionsAsync()).FirstOrDefault(e => e.Id == item.Id);
            if (native != null) await native.EnableAsync(enabled);
        }
        item.Enabled = enabled; RefreshPinnedExtensions(); ScheduleSave();
    }
    private async Task RemoveExtensionAsync(InstalledExtension item)
    {
        // Extensions are per WebView2 profile, including every space currently open.
        foreach (var profile in views.Values.Where(v => v.Control.CoreWebView2 != null).Select(v => v.Control.CoreWebView2.Profile).DistinctBy(p => p.ProfileName))
        {
            var native = (await profile.GetBrowserExtensionsAsync()).FirstOrDefault(e => e.Id == item.Id);
            if (native != null) await native.RemoveAsync();
        }
        if (!Settings.RemovedExtensionIds.Contains(item.Id)) Settings.RemovedExtensionIds.Add(item.Id);
        Settings.Extensions.Remove(item); Settings.ExtensionFolders.Remove(item.Folder); ScheduleSave(); store.Notify();
    }
    private async Task ChooseExtensionFolderAsync()
    {
        var picker = new FolderPicker(); picker.FileTypeFilter.Add("*"); InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
        var folder = await picker.PickSingleFolderAsync(); if (folder == null) return;
        try { await InstallExtensionFolderAsync(folder.Path); }
        catch (Exception ex) { Status.Text = ex.Message; }
    }
    private async Task ChooseExtensionPackageAsync()
    {
        var picker = new FileOpenPicker(); picker.FileTypeFilter.Add(".crx"); picker.FileTypeFilter.Add(".zip"); InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
        var file = await picker.PickSingleFileAsync(); if (file == null) return;
        try { var folder = await CrxInstaller.ImportAsync(file.Path, Path.Combine(DataStore.Root, "Extensions")); await InstallExtensionFolderAsync(folder); }
        catch (Exception ex) { Status.Text = ex.Message; }
    }
    private async Task OpenExtensionPopupAsync(InstalledExtension item)
    {
        if (!item.Enabled) return;
        if (item.Popup.Length == 0) { if (item.Options.Length > 0) AddTab($"chrome-extension://{item.Id}/{item.Options}"); return; }
        DismissOverlay();
        var view = new WebView2 { Width = 360, Height = 480 };
        var source = ActiveView?.Control.CoreWebView2;
        if (source == null) return;
        await ShowExtensionCardAsync(view, source, item);
    }
    private async Task ShowExtensionCardAsync(WebView2 view, CoreWebView2 source, InstalledExtension item)
    {
        var pending = ShowCardAsync(item.Name, view);
        try
        {
            var options = source.Environment.CreateCoreWebView2ControllerOptions(); options.ProfileName = source.Profile.ProfileName; options.IsInPrivateModeEnabled = source.Profile.IsInPrivateModeEnabled;
            await view.EnsureCoreWebView2Async(source.Environment, options);
            view.CoreWebView2.Navigate($"chrome-extension://{item.Id}/{item.Popup}");
            await pending;
        }
        finally { view.Close(); }
    }
    private void RefreshPinnedExtensions()
    {
        PinnedExtensions.Children.Clear();
        foreach (var item in Settings.Extensions.Where(e => e.Enabled && e.Pinned))
        {
            var button = QuietButton(item.Name.Length > 0 ? item.Name[..1] : "◇"); ToolTipService.SetToolTip(button, item.Name);
            button.Click += async (_, _) => await OpenExtensionPopupAsync(item); PinnedExtensions.Children.Add(button);
        }
        DownloadsButton.Visibility = Settings.AlwaysShowsDownloads || downloads.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
    }
    private async void Downloads_Click(object sender, RoutedEventArgs e) => await ShowDownloadsAsync();
    private void Extensions_Click(object sender, RoutedEventArgs e) => ExtensionsMenu();
    private void ExtensionsMenu()
    {
        var menu = new MenuFlyout();
        foreach (var item in Settings.Extensions.Where(e => e.Enabled)) AddMenu(menu, (item.Pinned ? "● " : "") + item.Name, async () => await OpenExtensionPopupAsync(item));
        AddMenu(menu, T("Manage extensions", "管理扩展"), async () => { Settings.SettingsPage = "extensions"; await ShowSettingsAsync(); });
        menu.Placement = Microsoft.UI.Xaml.Controls.Primitives.FlyoutPlacementMode.BottomEdgeAlignedRight;
        menu.ShowAt(ExtensionsButton);
    }
}
