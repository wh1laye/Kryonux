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
  st.textContent='.gl body>*:not(.gate){visibility:hidden}.gl{overflow:hidden}.gate{position:fixed;inset:0;z-index:9999;background:#f4f8fd;display:flex;align-items:center;justify-content:center;padding:20px;font-family:system-ui,sans-serif;color:#1c2b44}.gate div.b{background:#fff;border:1px solid #d6e3f3;border-radius:14px;padding:26px 28px;display:flex;flex-direction:column;align-items:center;gap:16px;max-width:100%;text-align:center}.gate svg{width:48px;height:48px}.gate p{margin:0;font-weight:600}.gate small{color:#6b7f99}html[data-theme=gray] .gate{background:#202226;color:#e4e7eb}html[data-theme=gray] .gate div.b{background:#272a2f;border-color:#3b3f46}html[data-theme=gray] .gate small{color:#9ba4af}';
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
    g.innerHTML='<div class="b"><svg viewBox="0 0 256 256" aria-hidden="true"><path d="M66 36H104V108L168 36H212L138 118L216 218H170L104 142V218H66Z" fill="#0F172A"/><path d="M54 24H92V96L156 24H200L126 106L204 206H158L92 130V206H54Z" fill="#93C5FD" stroke="#0F172A" stroke-width="10" stroke-linejoin="miter"/><path d="M54 24H92V96L54 114Z" fill="#E0F2FE" stroke="#0F172A" stroke-width="8" stroke-linejoin="miter"/><path d="M156 24H200L126 106L104 92Z" fill="#60A5FA" stroke="#0F172A" stroke-width="8" stroke-linejoin="miter"/></svg><p>проверка перед входом</p><div id="gw"></div><small>это занимает пару секунд</small></div>';
    d.body.appendChild(g);
    var s=d.createElement('script');
    s.src='https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
    s.async=true;
    s.onload=function(){
      window.turnstile.render('#gw',{sitekey:KEY,callback:ok});
    };
    d.head.appendChild(s);
  }
  if(d.body)build();
  else d.addEventListener('DOMContentLoaded',build);
})();
