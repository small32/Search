using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;

namespace SearcheXtra.Windows;

public sealed partial class MainWindow
{
    private async Task TogglePictureInPictureAsync(bool selectNext = true)
    {
        if (ActiveView is not { } view || active is not { } tab) return;
        if (view.FloatingWindow != null) { view.FloatingWindow.Close(); return; }
        var result = await view.Control.CoreWebView2.ExecuteScriptAsync("""
            (()=>{
              const video=[...document.querySelectorAll('video')].find(v=>!v.paused)||document.querySelector('video');
              if(!video)return false;
              const records=[];const remember=e=>{records.push([e,e.getAttribute('style')]);};
              let node=video;while(node&&node!==document.documentElement){remember(node);node.style.setProperty('position','static','important');node.style.setProperty('width','100%','important');node.style.setProperty('height','100%','important');node.style.setProperty('margin','0','important');node.style.setProperty('padding','0','important');if(node.parentElement)for(const sibling of node.parentElement.children)if(sibling!==node){remember(sibling);sibling.style.setProperty('display','none','important');}node=node.parentElement;}
              remember(video);video.style.setProperty('position','fixed','important');video.style.setProperty('inset','0','important');video.style.setProperty('object-fit','contain','important');video.controls=true;
              window.__searchVideoRestore=()=>{for(const [e,s] of records.reverse())if(s===null)e.removeAttribute('style');else e.setAttribute('style',s);delete window.__searchVideoRestore;};return true;
            })()
            """);
        if (result != "true") { Status.Text = T("No video in the main page. Embedded players can use their own fullscreen controls.", "主页面中未找到视频。嵌入式播放器可使用自己的全屏控件。"); return; }
        await view.Control.CoreWebView2.ExecuteScriptAsync("window.__searchFloating=true");
        Pages.Children.Remove(view.Control);
        var host = new Grid(); host.Children.Add(view.Control); view.Control.Visibility = Visibility.Visible;
        var window = new Window { Title = tab.Title, Content = host };
        WindowsIntegration.SetWindowIcon(window);
        view.FloatingWindow = window;
        window.AppWindow.SetPresenter(AppWindowPresenterKind.CompactOverlay);
        window.AppWindow.Resize(new global::Windows.Graphics.SizeInt32(480, 300));
        window.Closed += async (_, _) =>
        {
            host.Children.Remove(view.Control); view.FloatingWindow = null;
            if (closing || view.IsDisposed || !tabs.Contains(tab)) return;
            await view.Control.CoreWebView2.ExecuteScriptAsync("window.__searchFloating=false;window.__searchVideoRestore?.()");
            Pages.Children.Add(view.Control); view.Control.Visibility = Visibility.Collapsed;
            if (active == tab) await SelectAsync(tab);
        };
        window.Activate();
        if (!selectNext) return;
        var next = tabs.FirstOrDefault(t => t != tab && t.Space == space);
        if (next != null) await SelectAsync(next); else AddTab();
    }
}
