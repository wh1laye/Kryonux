(function(){
  var NEB='<defs><radialGradient id="zsm" cx=".35" cy=".3" r=".9"><stop offset="0" stop-color="#9aa3b5"/><stop offset=".6" stop-color="#5b6275"/><stop offset="1" stop-color="#2b3040"/></radialGradient></defs><path d="M18 42L32 20L60 12L88 18L112 34L120 56L102 74L68 80L36 72L14 58Z" fill="url(#zsm)" stroke="#1c2030" stroke-width="2" stroke-linejoin="round"/><ellipse cx="48" cy="34" rx="9" ry="6" fill="#3a4052" opacity=".7"/><ellipse cx="86" cy="52" rx="12" ry="8" fill="#3a4052" opacity=".7"/><ellipse cx="62" cy="62" rx="6" ry="4" fill="#3a4052" opacity=".7"/>';
  var SATELLITE='<g transform="translate(0 2)"><rect x="24" y="24" width="12" height="3" fill="#90a4ae" stroke="#455a64" stroke-width="1.2"/><rect x="28" y="20" width="4" height="8" fill="#90a4ae" stroke="#455a64" stroke-width="1"/><circle cx="30" cy="28" r="3" fill="#cfd8dc" stroke="#455a64" stroke-width="1.2"/><path d="M30 24l0 -8M30 32l0 8M22 28l8 0M38 28l8 0" stroke="#455a64" stroke-width="1.5" stroke-linecap="round"/><path d="M30 20l0 -14" stroke="#78909c" stroke-width="2" stroke-linecap="round" opacity=".75"/></g>';
  var COMET='<g transform="translate(0 0)"><circle cx="10" cy="10" r="2.8" fill="#fff" stroke="#b0bec5" stroke-width="1"/><path d="M10 10Q-26 -8 -70 -26" fill="none" stroke="rgba(255,255,255,.6)" stroke-width="3" stroke-linecap="round" opacity=".7"/><path d="M10 10Q-40 -14 -100 -38" fill="none" stroke="rgba(255,255,255,.25)" stroke-width="6" stroke-linecap="round" opacity=".45"/></g>';
  function starSprite(k){
    return k.sprite(10,10,function(c){
      c.fillStyle='#fff';c.beginPath();c.arc(0,0,3,0,6.283);c.fill();
      c.lineWidth=1;c.strokeStyle='rgba(255,255,255,.75)';c.stroke();
    });
  }
  window.KryonuxSeason.reg('cs',{
    init:function(k){
      var m=k.mobile(),gh=m?30:40,i;
      for(i=0;i<(m?3:6);i++)k.el('zs-logo zs-rock',k.svg('0 0 136 86',NEB),'left:'+k.rnd(-30,60).toFixed(1)+'%;top:'+(m?12+i*24:8+i*9)+'%;--dy:'+(m?24+i*18:20+i*12)+'vh;width:'+Math.round(k.rnd(m?34:46,m?64:96))+'px;animation-duration:'+Math.round(k.rnd(70,150))+'s;animation-delay:'+(-i*21).toFixed(1)+'s;opacity:.92');
      k.el('',k.strip(gh,[{d:k.hill(1000,gh*.7,gh*.55,9,15),fill:'#05050a',line:'#2a2a4e',w:2},{d:k.hill(1000,gh*.92,gh*.4,11,21),fill:'#0a0a12',line:'#3a3a66',w:2}]),'left:0;right:0;bottom:0;height:'+gh+'px',true);
      var sat=k.el('zs-fly zs-orbit',k.svg('0 0 62 42',SATELLITE),'right:6%;top:'+Math.round(gh*.3)+'px;width:'+(m?38:60)+'px;animation-duration:'+(m?100:140)+'s;animation-delay:-60s');
      sat.innerHTML='<div>'+sat.innerHTML+'</div>';
      k.hbWatch(function(hb){sat.style.top=(hb+(m?2:8))+'px'});
      var ss=starSprite(k),st=[],ns=k.n(240),s0;
      for(s0=0;s0<ns;s0++)st.push({x:Math.random(),y:Math.random(),z:k.rnd(.5,1.6),tw:k.rnd(1.0,4.6),p:k.rnd(0,6.28),ph:k.rnd(0,6.28),g:Math.random()<.17});
      k.canvas(function(c,dt,t,w,h){
        var cnt=Math.ceil(ns*k.q()),j,o;
        for(j=0;j<cnt;j++){
          o=st[j];
          c.globalAlpha=.18+.82*Math.abs(Math.sin(t*o.tw+o.p));
          if(o.g){
            c.save();c.translate(o.x*w,o.y*h);c.scale(o.z,o.z);
            c.fillStyle='rgba(255,255,255,.55)';c.beginPath();c.arc(0,0,16*o.z,0,6.283);c.fill();c.restore();
          }else{
            k.put(c,ss,o.x*w+Math.sin(t*1+o.ph)*2,o.y*h,o.z,0);
          }
        }
        c.globalAlpha=1;
      },true,24);
      if(k.pc()){
        for(i=0;i<8;i++)k.el('zs-shoot','','left:'+k.rnd(4,84).toFixed(1)+'%;top:'+(3+i*5)+'%;animation-delay:'+(-i*3.0).toFixed(1)+'s;animation-duration:'+(9+i*4.0).toFixed(1)+'s',true);
        for(i=0;i<10;i++)k.el('zs-glint','','left:'+k.rnd(2,98).toFixed(1)+'%;bottom:'+Math.round(k.rnd(gh*.2,gh*.9))+'px;animation-delay:'+(-k.rnd(0,3)).toFixed(2)+'s;animation-duration:'+k.rnd(2,4.4).toFixed(1)+'s',true);
        for(i=0;i<4;i++)k.el('zs-fly zs-comet',k.svg('0 0 94 52',COMET),'left:'+(i*9)+'%;top:'+(8+i*13)+'%;width:'+(m?48:78)+'px;animation-duration:'+(m?120:170)+'s;animation-delay:'+(-i*24).toFixed(1)+'s');
      }
    }
  });
})();
