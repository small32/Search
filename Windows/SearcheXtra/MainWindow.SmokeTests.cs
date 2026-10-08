using Microsoft.UI.Xaml;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private async Task RunSmokeTestsAsync(string reportPath)
    {
        var checks = new List<string>();
        var measurements = new Dictionary<string, double>();
        var server = new TcpListener(IPAddress.Loopback, 0);
        var cancellation = new CancellationTokenSource();
        void Check(bool result, string label) { if (!result) throw new Exception(label); checks.Add(label); File.AppendAllText(reportPath + ".progress", label + "\n"); }
        async Task Wait(Func<bool> predicate)
        {
            var started = Stopwatch.StartNew();
            while (!predicate()) { if (started.Elapsed > TimeSpan.FromSeconds(20)) throw new TimeoutException("Page initialization timed out"); await Task.Delay(25); }
        }
        try
        {
            server.Start();
            var port = ((IPEndPoint)server.LocalEndpoint).Port;
            _ = Task.Run(async () =>
            {
                while (!cancellation.IsCancellationRequested)
                {
                    try
                    {
                        var client = await server.AcceptTcpClientAsync(cancellation.Token);
                        _ = Task.Run(async () =>
                        {
                            using (client)
                            {
                                try
                                {
                                    using var stream = client.GetStream();
                                    var request = new byte[4096];
                                    if (await stream.ReadAsync(request, cancellation.Token) == 0) return;
                                    var html = "<!doctype html><html><head><title>SearcheXtra fixture</title></head><body><nav>Navigation fixture</nav><article><h1>Local browser test</h1><p>Native Windows shell, WebView2 content. " + new string('x', 500) + "</p><p>Article paragraph " + new string('y', 400) + "</p><input value='original'><form><input autocomplete='username'><input type='password'></form><div id='hide-me'>Hidden element fixture</div></article></body></html>";
                                    var body = Encoding.UTF8.GetBytes(html);
                                    var header = Encoding.ASCII.GetBytes($"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {body.Length}\r\nConnection: close\r\n\r\n");
                                    await stream.WriteAsync(header, cancellation.Token); await stream.WriteAsync(body, cancellation.Token);
                                }
                                catch (OperationCanceledException) { }
                                catch (IOException) { }
                            }
                        });
                    }
                    catch (OperationCanceledException) { break; }
                    catch (ObjectDisposedException) { break; }
                }
            });
            var fixture = $"http://127.0.0.1:{port}/";
            var watch = Stopwatch.StartNew();
            var first = AddTab(fixture, false);
            await SelectAsync(first);
            await Wait(() => !first.Loading && first.Title == "SearcheXtra fixture");
            measurements["FirstWebViewAndLocalNavigationMs"] = watch.Elapsed.TotalMilliseconds;
            Check(views.ContainsKey(first.Id), "Foreground page initialized");
            Root.UpdateLayout(); UpdateTitleBarRegions(); Root.UpdateLayout();
            if (TopTabs.ContainerFromIndex(TopTabs.Items.Count - 1) is FrameworkElement lastTab)
            {
                var end = lastTab.TransformToVisual(TopStrip).TransformPoint(new global::Windows.Foundation.Point(lastTab.ActualWidth, 0)).X;
                var plus = TopNew.TransformToVisual(TopStrip).TransformPoint(new global::Windows.Foundation.Point()).X;
                Check(Math.Abs(plus - end) < 2, "New tab button sits beside the last rendered tab without an empty gap");
            }
            else throw new Exception("Horizontal tab containers not realized");
            Check(!ReopenButton.IsEnabled, "Reopen button starts disabled without closed tabs");
            Check(Helm.Children.IndexOf(HomeButton) == Helm.Children.IndexOf(ReloadButton) + 1 &&
                Helm.Children.IndexOf(ReopenButton) == Helm.Children.IndexOf(HomeButton) + 1, "Home and reopen buttons follow reload in order");
            var previousStart = Settings.StartPage;
            var homeTabCount = tabs.Count;
            Settings.StartPage = fixture + "home";
            await GoHomeAsync();
            await Wait(() => !first.Loading && views[first.Id].Control.CoreWebView2.Source == fixture + "home");
            Check(active == first && tabs.Count == homeTabCount, "Home navigates the current tab to the configured start page");
            Settings.StartPage = "";
            await GoHomeAsync();
            await Wait(() => views[first.Id].Control.CoreWebView2.Source == "about:blank");
            Check(Welcome.Visibility == Visibility.Visible && tabs.Count == homeTabCount, "Home without a configured page restores the default welcome page");
            Settings.StartPage = previousStart;
            await NavigateAsync(fixture);
            await Wait(() => !first.Loading && first.Title == "SearcheXtra fixture");
            var olderClosed = AddTab(fixture + "older-closed", false);
            var lastClosed = AddTab(fixture + "last-closed", false, title: "Restored title", pinned: true, group: "Restored group");
            CloseTab(olderClosed); CloseTab(lastClosed);
            Check(ReopenButton.IsEnabled, "Closing a normal tab enables reopen");
            Reopen_Click(ReopenButton, new());
            await Wait(() => active?.Url == fixture + "last-closed");
            Check(active is { Pinned: true, Group: "Restored group" } && tabs.All(t => t.Url != fixture + "older-closed"), "Reopen restores the most recently closed tab and its metadata");
            var restoredClosed = active!;
            Reopen(); await Wait(() => active?.Url == fixture + "older-closed");
            Check(!ReopenButton.IsEnabled, "Reopen becomes disabled after the closed-tab stack is exhausted");
            CloseTab(active!); CloseTab(restoredClosed); closedTabs.Clear(); ReopenButton.IsEnabled = false;
            await SelectAsync(first);
            var firstView = views[first.Id];
            await firstView.Control.CoreWebView2.ExecuteScriptAsync("window.testMarker=42");
            var blank = AddTab("", false); await SelectAsync(blank);
            watch.Restart(); await SelectAsync(first);
            measurements["WarmTabSwitchMs"] = watch.Elapsed.TotalMilliseconds;
            Check(ReferenceEquals(firstView, views[first.Id]), "Tab switch reuses WebView2 instance");
            Check(await firstView.Control.CoreWebView2.ExecuteScriptAsync("window.testMarker") == "42", "Tab switch preserves JavaScript state");
            Settings.LazyBackgroundTabs = true;
            Settings.BookmarkOpening = BookmarkOpening.Background;
            var count = tabs.Count; OpenBookmark(fixture + "background");
            var background = tabs.Last();
            Check(tabs.Count == count + 1 && active == first, "Background bookmark preserves current tab");
            Check(!views.ContainsKey(background.Id), "Background bookmark creates no WebView until selected");
            await SelectAsync(background); await Wait(() => !background.Loading && background.Title == "SearcheXtra fixture");
            Check(views.ContainsKey(background.Id), "Selecting deferred tab loads its page");
            Settings.BookmarkOpening = BookmarkOpening.Foreground;
            count = tabs.Count; OpenBookmark(fixture + "foreground");
            var foreground = tabs.Last(); await Wait(() => active == foreground && !foreground.Loading && foreground.Title == "SearcheXtra fixture");
            Check(tabs.Count == count + 1 && active == foreground, "Foreground bookmark selects new tab");
            Settings.BookmarkOpening = BookmarkOpening.Default;
            count = tabs.Count; OpenBookmark(fixture + "current");
            await Wait(() => active == foreground && foreground.Url.EndsWith("current") && !foreground.Loading);
            Check(tabs.Count == count, "Default bookmark navigates existing tab");
            splitOwner = first; split = background; await SelectAsync(first);
            Check(firstView.Control.Visibility == Visibility.Visible && views[background.Id].Control.Visibility == Visibility.Visible, "Split view shows both pages");
            Check(Pages.ColumnDefinitions.Count == 3 && divider != null, "Split view provides resize divider");
            await SelectAsync(foreground);
            Check(Pages.ColumnDefinitions.Count == 0 && views[background.Id].Control.Visibility == Visibility.Collapsed, "Unrelated tab does not join split pair");
            split = null; splitOwner = null;
            await Task.Delay(300); // WinUI delays hiding the native controller by 200 ms to avoid flashing.
            await firstView.TrySuspendAsync();
            Check(first.Sleeping, "Hidden idle page suspends");
            await SelectAsync(first);
            Check(!first.Sleeping && await firstView.Control.CoreWebView2.ExecuteScriptAsync("window.testMarker") == "42", "Suspended page resumes without losing state");
            await firstView.Control.CoreWebView2.ExecuteScriptAsync("document.querySelector('input').value='edited'");
            await SelectAsync(foreground); await firstView.TrySuspendAsync();
            Check(!first.Sleeping, "Edited form prevents suspension");
            await SelectAsync(first);
            store.HiddenElements["127.0.0.1"] = ["#hide-me"];
            await firstView.UpdateDocumentScriptAsync();
            var reloaded = new TaskCompletionSource<bool>();
            void Completed(Microsoft.Web.WebView2.Core.CoreWebView2 sender, Microsoft.Web.WebView2.Core.CoreWebView2NavigationCompletedEventArgs args) => reloaded.TrySetResult(args.IsSuccess);
            firstView.Control.CoreWebView2.NavigationCompleted += Completed;
            try { firstView.Control.CoreWebView2.Reload(); Check(await reloaded.Task.WaitAsync(TimeSpan.FromSeconds(20)), "Hidden-rule test reload completes"); }
            finally { firstView.Control.CoreWebView2.NavigationCompleted -= Completed; }
            Check(await firstView.Control.CoreWebView2.ExecuteScriptAsync("getComputedStyle(document.querySelector('#hide-me')).display") == "\"none\"", "Saved element rules apply to subsequent navigation");
            var extensionFolder = Path.Combine(DataStore.Root, "fixture-extension");
            Directory.CreateDirectory(extensionFolder);
            await File.WriteAllTextAsync(Path.Combine(extensionFolder, "manifest.json"), """
                {"manifest_version":3,"name":"SearcheXtra test extension","version":"1.0","content_scripts":[{"matches":["http://127.0.0.1/*"],"js":["content.js"]}]}
                """);
            await File.WriteAllTextAsync(Path.Combine(extensionFolder, "content.js"), "document.documentElement.dataset.searchextraExtension='loaded';");
            var extension = await firstView.Control.CoreWebView2.Profile.AddBrowserExtensionAsync(extensionFolder);
            Check(extension.IsEnabled, "Unpacked extension loads into WebView2 profile");
            reloaded = new TaskCompletionSource<bool>();
            firstView.Control.CoreWebView2.NavigationCompleted += Completed;
            try { firstView.Control.CoreWebView2.Reload(); Check(await reloaded.Task.WaitAsync(TimeSpan.FromSeconds(20)), "Extension test reload completes"); }
            finally { firstView.Control.CoreWebView2.NavigationCompleted -= Completed; }
            Check(await firstView.Control.CoreWebView2.ExecuteScriptAsync("document.documentElement.dataset.searchextraExtension") == "\"loaded\"", "Extension content script runs on webpage");
            measurements["WebView2RuntimeMajor"] = int.Parse(firstView.Control.CoreWebView2.Environment.BrowserVersionString.Split('.')[0]);
            var mv2Folder = Path.Combine(DataStore.Root, "fixture-mv2-extension"); Directory.CreateDirectory(mv2Folder);
            await File.WriteAllTextAsync(Path.Combine(mv2Folder, "manifest.json"), """
                {"manifest_version":2,"name":"SearcheXtra MV2 compatibility fixture","version":"1.0","permissions":["storage","webRequest","webRequestBlocking","http://127.0.0.1/*"],"background":{"scripts":["background.js"],"persistent":true},"browser_action":{"default_popup":"popup.html"},"content_scripts":[{"matches":["http://127.0.0.1/*"],"js":["content.js"]}]}
                """);
            await File.WriteAllTextAsync(Path.Combine(mv2Folder, "background.js"), """
                chrome.webRequest.onBeforeRequest.addListener(d=>({cancel:d.url.includes('/mv2-blocked')}),{urls:['http://127.0.0.1/*']},['blocking']);
                chrome.storage.local.set({probe:'MV2 persistent background'});
                const instance=crypto.randomUUID();chrome.runtime.onMessage.addListener((m,s,reply)=>{chrome.storage.local.get('probe',data=>reply({value:data.probe,instance}));return true;});
                """);
            await File.WriteAllTextAsync(Path.Combine(mv2Folder, "content.js"), "chrome.runtime.sendMessage({probe:true},r=>{document.documentElement.dataset.mv2Background=r?.value||'missing';document.documentElement.dataset.mv2Instance=r?.instance||'missing';});");
            await File.WriteAllTextAsync(Path.Combine(mv2Folder, "popup.html"), "<!doctype html><title>MV2 popup</title><p id='status'></p><script src='popup.js'></script>");
            await File.WriteAllTextAsync(Path.Combine(mv2Folder, "popup.js"), "chrome.storage.local.get('probe',d=>document.querySelector('#status').textContent=d.probe);chrome.runtime.sendMessage({probe:true},r=>document.body.dataset.instance=r.instance);");
            await InstallExtensionFolderAsync(mv2Folder); var mv2 = Settings.Extensions.Single(e => e.Folder == mv2Folder);
            Check((await firstView.Control.CoreWebView2.Profile.GetBrowserExtensionsAsync()).Single(e => e.Id == mv2.Id).IsEnabled, "MV2 manifest loads without conversion");
            first.Loading = true; firstView.Control.CoreWebView2.Reload(); await Wait(() => !first.Loading); await Task.Delay(150);
            Check(await firstView.Control.CoreWebView2.ExecuteScriptAsync("document.documentElement.dataset.mv2Background") == "\"MV2 persistent background\"", "MV2 persistent background, messaging and storage work");
            await firstView.Control.CoreWebView2.ExecuteScriptAsync("window.mv2Blocked='pending';fetch('/mv2-blocked').then(()=>window.mv2Blocked='allowed').catch(()=>window.mv2Blocked='blocked');");
            await Task.Delay(250); Check(await firstView.Control.CoreWebView2.ExecuteScriptAsync("window.mv2Blocked") == "\"blocked\"", "MV2 blocking webRequest cancels a real request");
            var mv2Instance = await firstView.Control.CoreWebView2.ExecuteScriptAsync("document.documentElement.dataset.mv2Instance");
            var mv2Popup = AddTab($"chrome-extension://{mv2.Id}/popup.html", false); await SelectAsync(mv2Popup); await Wait(() => !mv2Popup.Loading && mv2Popup.Title == "MV2 popup"); await Task.Delay(150);
            Check(await views[mv2Popup.Id].Control.CoreWebView2.ExecuteScriptAsync("document.querySelector('#status').textContent") == "\"MV2 persistent background\"", "MV2 browser_action popup accesses native extension storage");
            Check(mv2Instance != "null" && await views[mv2Popup.Id].Control.CoreWebView2.ExecuteScriptAsync("document.body.dataset.instance") == mv2Instance, "Opening another WebView preserves the running MV2 background instance");
            CloseTab(mv2Popup); await SelectAsync(first); await RemoveExtensionAsync(mv2);
            await firstView.Control.CoreWebView2.ExecuteScriptAsync("""
                (async()=>{const canvas=document.createElement('canvas');canvas.width=320;canvas.height=180;canvas.getContext('2d').fillRect(0,0,320,180);const video=document.createElement('video');video.muted=true;video.srcObject=canvas.captureStream(5);document.body.appendChild(video);await video.play();})()
                """);
            await TogglePictureInPictureAsync();
            Check(firstView.FloatingWindow != null && !Pages.Children.Contains(firstView.Control), "Picture in picture reuses page in compact overlay");
            firstView.FloatingWindow!.Close(); await Task.Delay(300);
            Check(firstView.FloatingWindow == null && Pages.Children.Contains(firstView.Control), "Closing picture in picture restores original WebView");
            var historyCount = store.History.Count;
            var privateTab = AddTab(fixture + "private", false, true); await SelectAsync(privateTab);
            await Wait(() => !privateTab.Loading && privateTab.Title == "SearcheXtra fixture");
            Check(views[privateTab.Id].Control.CoreWebView2.Profile.IsInPrivateModeEnabled, "Private tab uses InPrivate profile");
            Check(store.History.Count == historyCount, "Private navigation is excluded from history");
            await SaveStateAsync();
            Check(store.Session.Tabs.All(t => !t.Url.EndsWith("private")), "Private tabs excluded from persisted session");
            Settings.CompactBookmarksBar = true;
            store.Bookmarks.Add(new() { Title = "Fixture bookmark", Url = fixture });
            RefreshBookmarkBar();
            Check(BookmarkRow.Spacing == 0 && BookmarkRow.Children.Count > 0, "Compact bookmark bar layout applied");
            Settings.Sidebar = true; ApplySettings();
            Check(Sidebar.Visibility == Visibility.Visible && TopTabs.Visibility == Visibility.Collapsed, "Vertical tab layout switches correctly");
            var realized = views.Count;
            watch.Restart();
            for (var i = 0; i < 50; i++) AddTab(fixture + "restored-" + i, false, loadBackground: false);
            measurements["Restore50TabModelsMs"] = watch.Elapsed.TotalMilliseconds;
            Check(views.Count == realized, "Restoring 50 tabs does not create 50 WebViews");
            await SelectAsync(first);
            var firstCore = views[first.Id].Control.CoreWebView2;
            Settings.SidebarRight = true; ApplySettings(); Check(Microsoft.UI.Xaml.Controls.Grid.GetColumn(Sidebar) == 2 && RightSidebarColumn.Width.Value == 232, "Right sidebar uses macOS width");
            Settings.NavigationLeft = true; Settings.Sidebar = false; ApplySettings(); Check(Microsoft.UI.Xaml.Controls.Grid.GetColumn(Helm) == 1, "Navigation buttons move before horizontal tabs");
            Check(AppWindow.Presenter is Microsoft.UI.Windowing.OverlappedPresenter { HasTitleBar: true, HasBorder: true, IsMinimizable: true, IsMaximizable: true }, "Windows owns native caption buttons and title bar dragging");
            Check(ExtendsContentIntoTitleBar && Toolbar.Height == 48 && editingAddressTab == null, "Tabs occupy the 48 point Windows title bar with no permanent address bar");
            Root.UpdateLayout(); UpdateTitleBarRegions(); Root.UpdateLayout();
            var plusX = TopNew.TransformToVisual(TopStrip).TransformPoint(new global::Windows.Foundation.Point()).X;
            Check(Math.Abs(plusX - TopTabs.ActualWidth) < 1, "New tab button directly follows the horizontal tab list");
            Check(TopSettings.Visibility == Visibility.Visible && ExtensionsButton.Visibility == Visibility.Visible && TitleActions.Parent == Toolbar, "Settings and extensions remain in the title bar");
            foreach (var navigationLeft in new[] { false, true })
            {
                Settings.NavigationLeft = navigationLeft; ApplySettings(); Root.UpdateLayout(); UpdateTitleBarRegions(); Root.UpdateLayout();
                var actionsEnd = TitleActions.TransformToVisual(Toolbar).TransformPoint(new global::Windows.Foundation.Point(TitleActions.ActualWidth, 0)).X;
                Check(Math.Abs(actionsEnd + 4 + CaptionInset.Width.Value - Toolbar.ActualWidth) < 1,
                    "Settings and extensions stay immediately left of native caption buttons, navigationLeft=" + navigationLeft);
            }
            foreach (var theme in new[] { ElementTheme.Light, ElementTheme.Dark })
            {
                Root.RequestedTheme = theme; SetupGlyphs();
                var glyph = (Microsoft.UI.Xaml.Shapes.Path)((Microsoft.UI.Xaml.Controls.Canvas)TopSettings.Content).Children[0];
                Check(((Microsoft.UI.Xaml.Media.SolidColorBrush)glyph.Stroke).Color == Brush("Ink").Color, "Toolbar glyph contrast follows " + theme);
            }
            Root.RequestedTheme = ElementTheme.Default; SetupGlyphs();
            FocusAddress(); Check(editingAddressTab == active && Address.Parent != AddressParking, "Address shortcut edits the active tab inline"); DismissOverlay();
            foreach (var page in new[] { "general", "tabs", "shortcuts", "extensions", "passwords", "downloads", "privacy", "about" })
            {
                Settings.SettingsPage = page; var panelTask = ShowSettingsAsync(); await Task.Delay(20);
                Check(OverlayLayer.Visibility == Visibility.Visible && OverlayLayer.Children[0] is Microsoft.UI.Xaml.Controls.Border { Child: Microsoft.UI.Xaml.Controls.Grid { Width: 660, Height: 500 } }, "Settings page renders: " + page);
                DismissOverlay(); await panelTask;
            }
            Settings.Keywords.Add(new("yt", "https://www.youtube.com/results?search_query=%s")); Check(ResolveAddress("yt cats & dogs").Query.Contains("cats%20%26%20dogs"), "Keyword search escapes query");
            Settings.SearchesSites = true; siteOffer = SiteSearch.Match(Settings, "gh"); searchSite = siteOffer; Check(ResolveAddress("C# & UI").AbsoluteUri.Contains("C%23%20%26%20UI"), "Tab-selected site search escapes user query");
            Settings.Sidebar = true; Settings.SidebarAutoHide = true; sidebarFolded = true; ApplySettings(); Check(Sidebar.Visibility == Visibility.Collapsed && SidebarColumn.Width.Value == 0 && RightSidebarColumn.Width.Value == 0, "Automatic sidebar folding survives settings refresh"); sidebarFolded = false; Settings.SidebarAutoHide = false; ApplySettings();
            Settings.AlwaysShowsDownloads = true; ApplySettings(); Check(DownloadsButton.Visibility == Visibility.Visible, "Always-show download preference creates usable button");
            Settings.Shortcuts["Ctrl+L"] = "Ctrl+Shift+L"; InstallShortcuts(); Check(Root.KeyboardAccelerators.Any(k => k.Key == global::Windows.System.VirtualKey.L && k.Modifiers.HasFlag(global::Windows.System.VirtualKeyModifiers.Shift)), "Custom shortcut replaces default accelerator"); Settings.Shortcuts.Clear(); InstallShortcuts();
            var otherSpace = AddTab(fixture, false, inSpace: "Isolated fixture"); await SelectAsync(otherSpace); await Wait(() => !otherSpace.Loading && otherSpace.Title == "SearcheXtra fixture");
            Check(views[otherSpace.Id].Control.CoreWebView2.Profile.ProfileName != firstCore.Profile.ProfileName, "Spaces use separate cookie and extension profiles");
            await SelectAsync(first); Settings.PageZoom = 1.25; ApplySettings(); await Task.Delay(100); Check(await firstCore.ExecuteScriptAsync("document.documentElement.style.zoom") == "\"1.25\"", "Default page zoom affects document"); Settings.PageZoom = 1;
            Settings.PreventTracking = false; ApplySettings(); Check(firstCore.Profile.PreferredTrackingPreventionLevel == Microsoft.Web.WebView2.Core.CoreWebView2TrackingPreventionLevel.None, "Tracking prevention preference reaches native profile"); Settings.PreventTracking = true;
            await PasswordStore.WriteAsync([new(fixture.TrimEnd('/'), "fixture-user", "fixture-password")]); first.Loading = true; firstCore.Reload(); await Wait(() => !first.Loading);
            var fillDeadline = Stopwatch.StartNew(); while (await firstCore.ExecuteScriptAsync("document.querySelector('input[type=password]')?.value") != "\"fixture-password\"") { if (fillDeadline.Elapsed > TimeSpan.FromSeconds(10)) throw new TimeoutException("Password autofill timed out"); await Task.Delay(25); }
            Check(await firstCore.ExecuteScriptAsync("document.querySelector('input[type=password]').value") == "\"fixture-password\"", "Saved password fills matching top-level origin");
            Check(!File.ReadAllText(Path.Combine(DataStore.Root, "settings.json")).Contains("fixture-password"), "Passwords are excluded from plain settings JSON");
            await views[first.Id].ReaderAsync(); Check(await firstCore.ExecuteScriptAsync("!!document.querySelector('#office-reader') && !document.querySelector('nav')") == "true", "Reader uses the macOS article extraction script");
            first.Loading = true; firstCore.Reload(); await Wait(() => !first.Loading); await Task.Delay(100);
            if (Environment.GetEnvironmentVariable("SEARCHEXTRA_TEST_STORE") == "1")
            {
                const string storeId = "aapbdbdomjkkjkaonfhkkikfgjllcleb";
                var folder = await CrxInstaller.FetchAsync(storeId, Path.Combine(DataStore.Root, "StoreProbe")); await InstallExtensionFolderAsync(folder, storeId);
                var storeExtension = Settings.Extensions.Single(e => e.StoreId == storeId); Check(storeExtension.Id == storeId, "Real Chrome store extension installs with original ID");
                await SetExtensionEnabledAsync(storeExtension, false); Check(!(await firstCore.Profile.GetBrowserExtensionsAsync()).Single(e => e.Id == storeId).IsEnabled, "Installed store extension disables natively");
                await SetExtensionEnabledAsync(storeExtension, true); Check((await firstCore.Profile.GetBrowserExtensionsAsync()).Single(e => e.Id == storeId).IsEnabled, "Installed store extension enables natively");
                await RemoveExtensionAsync(storeExtension); Check(!(await firstCore.Profile.GetBrowserExtensionsAsync()).Any(e => e.Id == storeId), "Store extension uninstalls natively");
            }
            if ((Environment.GetEnvironmentVariable("SEARCHEXTRA_TEST_MV2_PACKAGE") ?? Environment.GetEnvironmentVariable("SEARCHEXTRA_TEST_MV2_FOLDER")) is { Length: > 0 } realFolder)
            {
                if (File.Exists(realFolder)) realFolder = await CrxInstaller.ImportAsync(realFolder, Path.Combine(DataStore.Root, "RealMv2"));
                await SelectAsync(first); await InstallExtensionFolderAsync(realFolder); var real = Settings.Extensions.Single(e => e.Folder == Path.GetFullPath(realFolder));
                Check(real.ManifestVersion == 2 && (await firstCore.Profile.GetBrowserExtensionsAsync()).Single(e => e.Id == real.Id).IsEnabled, "Real MV2 extension loads unchanged: " + real.Name + " " + real.Version);
                var dashboard = AddTab($"chrome-extension://{real.Id}/dashboard.html", false); await SelectAsync(dashboard); await Wait(() => !dashboard.Loading && dashboard.Title.Contains("uBlock"));
                Check(await views[dashboard.Id].Control.CoreWebView2.ExecuteScriptAsync("typeof chrome.runtime.sendMessage === 'function' && typeof chrome.storage.local.get === 'function'") == "true", "Real uBlock Origin dashboard has native MV2 APIs");
                var dashboardCore = views[dashboard.Id].Control.CoreWebView2;
                // uBlock intentionally restarts on first Chromium installation (start.js).
                await Task.Delay(1000); dashboardCore.Navigate($"chrome-extension://{real.Id}/dashboard.html");
                var readyDeadline = Stopwatch.StartNew(); while (await dashboardCore.ExecuteScriptAsync("typeof vAPI?.messaging?.send") != "\"function\"") { if (readyDeadline.Elapsed > TimeSpan.FromSeconds(10)) throw new TimeoutException("uBlock dashboard did not recover after initial restart"); await Task.Delay(50); }
                await dashboardCore.ExecuteScriptAsync("window.mv2Rules='pending';(async()=>{while(!await vAPI.messaging.send('dashboard',{what:'readyToFilter'}))await new Promise(r=>setTimeout(r,100));await vAPI.messaging.send('dashboard',{what:'writeUserFilters',enabled:true,content:'*/ublock-test-blocked*'});await vAPI.messaging.send('dashboard',{what:'reloadAllFilters'});window.mv2Diagnostics={filters:await vAPI.messaging.send('dashboard',{what:'readUserFilters'}),tabs:await new Promise(r=>chrome.tabs.query({},r)),ready:await vAPI.messaging.send('dashboard',{what:'readyToFilter'})};window.mv2Rules='ready';})().catch(e=>window.mv2Rules=String(e));");
                var ruleDeadline = Stopwatch.StartNew(); while (await dashboardCore.ExecuteScriptAsync("window.mv2Rules") != "\"ready\"") { if (ruleDeadline.Elapsed > TimeSpan.FromSeconds(20)) throw new TimeoutException("uBlock filter initialization: " + await dashboardCore.ExecuteScriptAsync("JSON.stringify({state:window.mv2Rules,url:location.href,ready:document.readyState,vapi:typeof vAPI})")); await Task.Delay(50); }
                await SelectAsync(first); first.Loading = true; firstCore.Reload(); await Wait(() => !first.Loading); await Task.Delay(200);
                await firstCore.ExecuteScriptAsync("window.ublockResult='pending';fetch('/ublock-test-blocked').then(()=>window.ublockResult='allowed').catch(()=>window.ublockResult='blocked');");
                var fetchDeadline = Stopwatch.StartNew(); while (await firstCore.ExecuteScriptAsync("window.ublockResult") == "\"pending\"") { if (fetchDeadline.Elapsed > TimeSpan.FromSeconds(5)) break; await Task.Delay(25); }
                await dashboardCore.ExecuteScriptAsync("window.mv2DiagDone=false;(async()=>{window.mv2Diagnostics.lists=await vAPI.messaging.send('dashboard',{what:'getLists'});window.mv2Diagnostics.popup=await vAPI.messaging.send('popupPanel',{what:'getPopupData',tabId:window.mv2Diagnostics.tabs[0].id});window.mv2Diagnostics.background=Object.keys(chrome.extension.getBackgroundPage()?.vAPI?.net||{});window.mv2DiagDone=true;})().catch(e=>{window.mv2Diagnostics.error=String(e);window.mv2DiagDone=true;});");
                var diagnosticDeadline = Stopwatch.StartNew(); while (await dashboardCore.ExecuteScriptAsync("window.mv2DiagDone") != "true") { if (diagnosticDeadline.Elapsed > TimeSpan.FromSeconds(5)) break; await Task.Delay(25); }
                await File.WriteAllTextAsync(reportPath + ".mv2.json", JsonSerializer.Deserialize<string>(await dashboardCore.ExecuteScriptAsync("JSON.stringify(window.mv2Diagnostics)")) ?? "{}");
                Check(await firstCore.ExecuteScriptAsync("window.ublockResult") == "\"blocked\"", "Real uBlock Origin MV2 filter blocks a network request: " + await firstCore.ExecuteScriptAsync("window.ublockResult"));
                CloseTab(dashboard); await SelectAsync(first); await RemoveExtensionAsync(real);
            }
            await File.WriteAllTextAsync(reportPath, JsonSerializer.Serialize(new { success = true, checks, measurements }, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception ex)
        {
            await File.WriteAllTextAsync(reportPath, JsonSerializer.Serialize(new { success = false, checks, error = ex.ToString(), measurements }, new JsonSerializerOptions { WriteIndented = true }));
        }
        finally
        {
            cancellation.Cancel(); server.Stop(); Close();
        }
    }
}
