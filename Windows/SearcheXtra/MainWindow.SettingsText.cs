namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private static readonly (string, string, int)[] SettingsRows =
        {
            ("Default browser", "默认浏览器", 702), ("Bring things over", "导入数据", 708), ("Search keywords", "搜索关键词", 712),
            ("Appearance", "外观", 716), ("Default page zoom", "默认网页缩放", 718), ("Correct spelling as you type", "输入时自动纠正拼写", 720),
            ("Preview links with Shift-click", "Shift 点击预览链接", 722), ("Address bar commands", "地址栏命令", 726), ("Show link destinations", "显示链接目标地址", 728),
            ("Middle-click auto scroll", "鼠标中键自动滚动", 730), ("History on navigation hold", "按住导航按钮选择历史页面", 734), ("Flick floating video to a corner", "浮动视频快速贴角", 736),
            ("Wait for videos to play", "视频等待手动播放", 738), ("Float video when leaving a tab", "离开标签页时浮动视频", 740), ("Float video when switching apps", "切换应用时浮动视频", 742),
            ("Let scripts drive SearcheXtra", "允许脚本控制 SearcheXtra", 744), ("Navigation buttons on the left", "左侧显示导航按钮", 752), ("Sidebar", "侧边栏", 754),
            ("Sidebar position", "侧边栏位置", 756), ("Hide sidebar until pointer reaches edge", "指针靠近边缘时显示侧栏", 758), ("Tabs show", "标签页显示", 760),
            ("Bookmarks bar", "书签栏", 762), ("Reading mode", "阅读模式", 764), ("Put idle tabs to sleep", "休眠闲置标签页", 766), ("Load background tabs on demand", "按需加载后台标签页", 768),
            ("Search a site from the address field", "在地址栏搜索网站", 770), ("Spaces", "空间", 774), ("Tab groups", "标签组", 776), ("Pinned tabs as rows", "固定标签页使用列表", 778),
            ("Split view", "分屏", 780), ("Saved passwords", "已保存的密码", 784), ("Offer to save passwords", "提示保存密码", 787), ("Fill saved passwords", "自动填写已保存的密码", 788),
            ("Passkeys", "通行密钥", 790), ("Bring passwords over", "导入密码", 798), ("Save files to", "文件保存位置", 801), ("Ask where to save each file", "每次询问保存位置", 803),
            ("Always show downloads button", "始终显示下载按钮", 804), ("Block ads and trackers", "拦截广告与跟踪器", 806), ("Prevent cross-site tracking", "防止跨站跟踪", 812),
            ("Let sites ask to send notifications", "允许网站请求通知", 817), ("History", "历史记录", 819), ("Cookies and website data", "Cookie 与网站数据", 822), ("Cache", "缓存", 825)
        };

    // Reuse macOS's translations and descriptions, including its exact labels.
    private (string, string) SettingsRowText(string label, string detail)
    {
        var row = SettingsRows.FirstOrDefault(r => label == r.Item1 || label == r.Item2);
        if (row.Item3 != 0)
        {
            label = strings.Key($"Settings.{row.Item3:0000}");
            if (detail.Length == 0 && row.Item3 is not (702 or 787 or 790 or 801 or 803)) detail = strings.Key($"Settings.{row.Item3 + 1:0000}").Replace("{0}", T("left", "左侧"));
        }
        return (label, detail);
    }
}
