using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;

namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private BrowserTab? editingAddressTab;
    private Guid? pressedActiveTab;
    private double normalTabWidth = 186;
    private double addressTabWidth = 372;
    private ListView AddressList => Settings.Sidebar ? SideTabs : TopTabs;
    private double TabWidth(BrowserTab tab) => tab == editingAddressTab ? addressTabWidth : tab.Pinned ? 54 : normalTabWidth;

    private static string EditableTabAddress(string url) => url is "" or "about:blank" ||
        url.StartsWith("chrome-extension://", StringComparison.OrdinalIgnoreCase) ? "" : url;

    private static T? FindAddressPart<T>(DependencyObject root, string? name = null) where T : FrameworkElement
    {
        if (root is T match && (name == null || match.Name == name)) return match;
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
            if (FindAddressPart<T>(VisualTreeHelper.GetChild(root, i), name) is { } child) return child;
        return null;
    }

    private void ParkAddress()
    {
        if (Address.Parent is Grid host && host != AddressParking)
        {
            host.Children.Remove(Address);
            host.Visibility = Visibility.Collapsed;
            if (host.Parent is Grid body)
            {
                if (body.FindName("TabSiteInfo") is FrameworkElement info) info.Visibility = Visibility.Collapsed;
                if (body.FindName("TabLetter") is FrameworkElement letter) letter.Visibility = Visibility.Visible;
                if (body.FindName("TabFavicon") is FrameworkElement favicon) favicon.Visibility = Visibility.Visible;
                if (body.FindName("TabLabel") is FrameworkElement label) label.Visibility = Visibility.Visible;
                if (body.FindName("TabClose") is FrameworkElement close) close.Visibility = Visibility.Visible;
            }
            AddressParking.Children.Add(Address);
        }
    }

    private void AttachAddressEditor(bool focus)
    {
        if (editingAddressTab == null) return;
        if (AddressList.ContainerFromItem(editingAddressTab) is not ListViewItem item) return;
        if (FindAddressPart<Grid>(item, "TabAddressHost") is not { } host) return;
        if (Address.Parent != host)
        {
            ParkAddress();
            AddressParking.Children.Remove(Address);
            host.Children.Add(Address);
        }
        host.Visibility = Visibility.Visible;
        var isSite = AddressParser.IsWeb(editingAddressTab.Url);
        var info = FindAddressPart<Button>(item, "TabSiteInfo")!;
        info.Content = Glyph("sliders");
        info.Visibility = isSite ? Visibility.Visible : Visibility.Collapsed;
        ToolTipService.SetToolTip(info, T("Site information", "网站信息"));
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(info, T("Site information", "网站信息"));
        FindAddressPart<TextBlock>(item, "TabLetter")!.Visibility = isSite ? Visibility.Collapsed : Visibility.Visible;
        FindAddressPart<Image>(item, "TabFavicon")!.Visibility = isSite ? Visibility.Collapsed : Visibility.Visible;
        FindAddressPart<TextBlock>(item, "TabLabel")!.Visibility = Visibility.Collapsed;
        if (!Settings.Sidebar) item.Width = TabWidth(editingAddressTab);
        UpdateTitleBarRegions();
        if (focus) { Address.Focus(FocusState.Programmatic); Address.SelectAll(); }
    }

    private void FocusAddress()
    {
        if (active == null) return;
        var changed = editingAddressTab != active;
        editingAddressTab = active;
        searchSite = null; siteOffer = null;
        Address.PlaceholderText = T("Address or search", "网址或搜索");
        Address.Text = EditableTabAddress(active.Url);
        if (changed) RefreshTabLists();
        AddressList.ScrollIntoView(active);
        Root.UpdateLayout();
        AttachAddressEditor(true);
        DispatcherQueue.TryEnqueue(() => AttachAddressEditor(true));
    }

    private void EndAddressEdit()
    {
        if (editingAddressTab == null) return;
        ParkAddress();
        editingAddressTab = null;
        RefreshTabLists();
    }

    private void TabBody_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: BrowserTab tab } element &&
            e.GetCurrentPoint(element).Properties.PointerUpdateKind == Microsoft.UI.Input.PointerUpdateKind.LeftButtonPressed)
            pressedActiveTab = active == tab && editingAddressTab != tab ? tab.Id : null;
    }

    private void AddressOutside_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (editingAddressTab == null) return;
        for (var node = e.OriginalSource as DependencyObject; node != null; node = VisualTreeHelper.GetParent(node))
            if (node == Address || node is FrameworkElement { Name: "TabSiteInfo" }) return;
        EndAddressEdit();
    }

    private void TabBody_Tapped(object sender, TappedRoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: BrowserTab tab } && pressedActiveTab == tab.Id && active == tab)
            FocusAddress();
        pressedActiveTab = null;
    }
}
