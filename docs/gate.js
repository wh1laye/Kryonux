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
+'.gate{position:fixed;inset:0;z-index:9999;display:flex;align-items:center;justify-content:center;padding:20px;color:#e9f8ff;font:600 15px/1.6 "Comfortaa",system-ui,sans-serif;-webkit-font-smoothing:antialiased;background:radial-gradient(60% 50% at 50% 0%,rgba(110,200,255,.2),transparent 70%),radial-gradient(50% 40% at 88% 100%,rgba(150,230,255,.1),transparent 70%),#07121c}'
+'.gate::before{content:"";position:absolute;inset:0;pointer-events:none;background:repeating-linear-gradient(60deg,transparent 0 54px,rgba(160,225,255,.035) 54px 55px),repeating-linear-gradient(-60deg,transparent 0 54px,rgba(160,225,255,.035) 54px 55px)}'
+'.gate .b{position:relative;width:min(340px,100%);display:flex;flex-direction:column;align-items:center;gap:14px;padding:30px 24px;text-align:center;background:linear-gradient(160deg,rgba(150,225,255,.1),rgba(14,30,44,.88) 45%);border:1px solid rgba(140,215,255,.22);border-radius:18px;box-shadow:0 30px 80px -30px rgba(80,180,255,.4),inset 0 1px 0 rgba(220,248,255,.18)}'
+'.gate p{margin:0;font-size:18px;font-weight:700}'
+'.gate small{color:#8fb4c9;font-weight:500;font-size:13px}'
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
g.innerHTML='<div class="b"><p>Security check</p><div id="gw"></div><small>This takes a couple of seconds</small></div>';
d.body.appendChild(g);
var s=d.createElement('script');
s.src='https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
s.async=true;
s.onload=function(){
window.turnstile.render('#gw',{sitekey:KEY,callback:ok,language:'en',theme:'dark'});
};
d.head.appendChild(s);
}
if(d.body)build();
else d.addEventListener('DOMContentLoaded',build);
})();
