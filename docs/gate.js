(function(){
var KEY="0x4AAAAAAGLC2Z7LGzUdnI3p";
var HOURS=6;
if(!KEY)return;
try{
var t=+localStorage.getItem('cg');
if(t&&Date.now()-t<HOURS*36e5)return;
}catch(e){}
var d=document,h=d.documentElement;
h.classList.add('gl');
var st=d.createElement('style');
st.textContent='.gl body>*:not(.gate){visibility:hidden}.gl{overflow:hidden}'
+'.gate{position:fixed;inset:0;z-index:9999;display:flex;align-items:center;justify-content:center;padding:20px;background-color:var(--bg,#f1f7ff);color:var(--ink,#0e1c33);font:600 15px/1.6 "Comfortaa",system-ui,sans-serif;-webkit-font-smoothing:antialiased}'
+'html[data-theme=gray] .gate{background-image:linear-gradient(135deg,transparent 49.6%,rgba(150,210,255,.06) 50%,transparent 50.4%),linear-gradient(45deg,transparent 49.6%,rgba(150,210,255,.06) 50%,transparent 50.4%)}'
+'.gate .b{width:min(340px,100%);display:flex;flex-direction:column;align-items:center;gap:14px;padding:28px 24px;text-align:center;background:var(--surf,#fcfeff);border:1px solid var(--line,#d0e2f4);border-radius:16px}'
+'.gate svg{width:44px;height:44px}'
+'.gate p{margin:0;font-size:17px;font-weight:700}'
+'.gate small{color:var(--mute,#587089);font-weight:500;font-size:13px}'
+'.gate #gw{min-height:65px;display:flex;align-items:center;justify-content:center}';
d.head.appendChild(st);
function ok(){
try{localStorage.setItem('cg',String(Date.now()))}catch(e){}
h.classList.remove('gl');
var g=d.querySelector('.gate');
if(g)g.remove();
}
function build(){
var g=d.createElement('div');
g.className='gate';
g.setAttribute('lang','en');
g.innerHTML='<div class="b"><svg viewBox="0 0 256 256" aria-hidden="true"><path d="M66 36H104V108L168 36H212L138 118L216 218H170L104 142V218H66Z" fill="#0F172A"/><path d="M54 24H92V96L156 24H200L126 106L204 206H158L92 130V206H54Z" fill="#93C5FD" stroke="#0F172A" stroke-width="10" stroke-linejoin="miter"/><path d="M54 24H92V96L54 114Z" fill="#E0F2FE" stroke="#0F172A" stroke-width="8" stroke-linejoin="miter"/><path d="M156 24H200L126 106L104 92Z" fill="#60A5FA" stroke="#0F172A" stroke-width="8" stroke-linejoin="miter"/></svg><p>Security check</p><div id="gw"></div><small>This takes a couple of seconds</small></div>';
d.body.appendChild(g);
var s=d.createElement('script');
s.src='https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
s.async=true;
s.onload=function(){
var th=h.getAttribute('data-theme');
window.turnstile.render('#gw',{sitekey:KEY,callback:ok,language:'en',theme:th==='light'||th==='sepia'?'light':'dark'});
};
d.head.appendChild(s);
}
if(d.body)build();
else d.addEventListener('DOMContentLoaded',build);
})();
