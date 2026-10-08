using System.Text.Json;

namespace SearcheXtra.Windows;

internal static partial class PageScripts
{
    public static string HiddenRules(Dictionary<string, List<string>> rules) => "(() => { const rules=" + JsonSerializer.Serialize(rules) + "; const selectors=rules[location.hostname]||[]; if(!selectors.length)return; const style=document.createElement('style'); style.textContent=selectors.map(s=>s+'{display:none!important}').join('\\n'); const inject=()=>{const root=document.head||document.documentElement;if(!root)return false;root.appendChild(style);return true;}; if(!inject()){const observer=new MutationObserver(()=>{if(inject())observer.disconnect();});observer.observe(document,{childList:true,subtree:true});} })();";
    public const string Busy = "(() => [...document.querySelectorAll('video,audio')].some(m=>!m.paused) || [...document.querySelectorAll('input,textarea')].some(e=>e.value!==e.defaultValue || e.checked!==e.defaultChecked) || !!window.__searchCapture)()";
    public const string Capture = """
        (()=>{const media=navigator.mediaDevices;if(!media)return;for(const name of ['getUserMedia','getDisplayMedia']){const original=media[name];if(!original)continue;media[name]=async function(...args){const stream=await original.apply(this,args);window.__searchCapture=(window.__searchCapture||0)+1;let stopped=false;const finish=()=>{if(!stopped&&stream.getTracks().every(t=>t.readyState==='ended')){stopped=true;window.__searchCapture--;}};for(const track of stream.getTracks())track.addEventListener('ended',finish);return stream;};}})()
        """;
    public static string Reader => "if(window.__searchReader){location.reload()}else{" + File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Assets", "reader.js")) + ";window.__searchReader=true;}";
    public const string Pip = """
        (async()=>{const video=[...document.querySelectorAll('video')].find(v=>!v.paused)||document.querySelector('video');if(video&&document.pictureInPictureEnabled){if(document.pictureInPictureElement)await document.exitPictureInPicture();else await video.requestPictureInPicture();}})()
        """;
    public const string Hide = """
        (()=>{
          if(window.__searchHideAbort)window.__searchHideAbort.abort();
          const abort=new AbortController();window.__searchHideAbort=abort;
          let selected=null,outline='';
          function reset(){if(selected)selected.style.outline=outline;}
          document.addEventListener('mouseover',e=>{reset();selected=e.target;outline=selected.style.outline;selected.style.outline='2px solid #4285ff';},{capture:true,signal:abort.signal});
          document.addEventListener('keydown',e=>{if(e.key==='Escape'){reset();abort.abort();}},{capture:true,signal:abort.signal});
          document.addEventListener('click',e=>{
            e.preventDefault();e.stopImmediatePropagation();reset();abort.abort();
            const target=e.target;let selector='';
            if(target.id)selector='#'+CSS.escape(target.id);
            else{let node=target,parts=[];while(node&&node!==document.body){const siblings=[...node.parentElement.children].filter(s=>s.tagName===node.tagName);parts.unshift(node.tagName.toLowerCase()+':nth-of-type('+(siblings.indexOf(node)+1)+')');node=node.parentElement;}selector='body > '+parts.join(' > ');}
            if(target===document.body||target===document.documentElement)return;
            target.style.display='none';window.chrome.webview.postMessage({type:'hide',selector});
          },{capture:true,once:true,signal:abort.signal});
        })()
        """;
}
