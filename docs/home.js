(function(){
var d=document,W=window;
var T={
i:[['p','doas kryonux-install'],['p','reboot'],['p','doas kryonux-audit']],
p:[['p','doas kpkg sync'],['p','doas kpkg install nano'],['p','doas kpkg search htop'],['p','doas kpkg upgrade'],['p','doas kpkg rollback']],
s:[['p','sha256sum -c kryonux-live-amd64-*.iso.sha256'],['p','doas kryonux-firewall status'],['p','doas kryonux-firewall allow ssh'],['p','doas rc-update add sshd default']]
};
var D={
"быстрый и усиленный":"fast and hardened",", который ставится одной командой":", that installs with a single command",
"загружаешься с live iso, запускаешь установщик, через несколько минут в /mnt/kryonux уже готовая система. openrc, ядро kryonk, фаервол включён с первой загрузки.":"boot the live iso, run the installer, and in a few minutes there is a ready system in /mnt/kryonux. openrc, the kryonk kernel, firewall on from the first boot.",
"скачать live iso":"download live iso","читать справочник":"read the handbook","копировать":"copy","скопировано":"copied",
"установка":"install","пакеты":"packages","защита":"protection","терминал":"terminal","примеры команд":"command examples",
"версия проекта":"project version","размер iso":"ISO size","uefi и bios":"UEFI and BIOS","лицензия":"license",
"initramfs только для luks2":"initramfs only for luks2",
"из чего состоит":"what it is made of","каждый компонент выбран за простоту и предсказуемость, а не за количество галочек.":"every component is picked for simplicity and predictability, not for a checklist count.",
"быстрая установка":"fast install","система распаковывается прямо из iso, без скачивания и компиляции. режим auto сам размечает выбранный диск, режим manual трогает только разделы root и boot.":"the system is unpacked straight from the iso, with no download and no compiling. auto mode partitions the chosen disk itself, manual mode touches only the root and boot partitions.",
"усиленная база":"hardened base","kspp-опции ядра, подпись модулей, nftables с drop, обычный пользователь в wheel с doas.":"kspp kernel options, module signing, nftables with drop, a regular user in wheel with doas.",
"ядро kryonk":"kryonk kernel","драйверы дисков и файловых систем встроены: без шифрования система загружается без initramfs.":"disk and filesystem drivers are built in: without encryption the system boots without an initramfs.",
"openrc":"openrc","простая система служб без systemd, службы стартуют параллельно.":"a simple service system without systemd, services start in parallel.",
"limine":"limine","быстрый загрузчик с одним файлом конфига, для uefi и bios.":"a fast bootloader with a single config file, for uefi and bios.",
"kpkg":"kpkg","пакеты из исходников, свои рецепты, снимки btrfs перед обновлением.":"packages from source, own recipes, btrfs snapshots before upgrades.",
"secure boot и tpm2":"secure boot and tpm2","свои ключи secure boot, подписанный uki, разблокировка luks через tpm2 с запасным паролем. на реальном железе скрипты пока не проверены.":"your own secure boot keys, a signed uki, luks unlock through tpm2 with a fallback password. the scripts have not been tested on real hardware yet.",
"проверка защиты":"protection audit","одна команда показывает, что включено в системе: фаервол, ssh, sysctl, ядро.":"one command shows what is enabled in the system: firewall, ssh, sysctl, kernel.",
"установка в три шага":"installation in three steps","одной командой или вручную по справочнику.":"with one command or manually by the handbook.",
"live iso":"live iso","скачай, проверь сумму, запиши на флешку и загрузись. вход в live: kryonux / kryonux.":"download, check the sum, write it to a usb stick and boot. live login: kryonux / kryonux.",
"kryonux-install":"kryonux-install","диск, пароли, всё остальное само: форматирование, распаковка, limine, пользователи.":"disk, passwords, the rest is automatic: formatting, unpacking, limine, users.",
"reboot":"reboot","вход, сеть, пакеты. чистая консоль и обычный пользователь с doas.":"login, network, packages. a clean console and a regular user with doas.",
"безопасность по умолчанию":"secure by default","защита включена сразу после установки, а не спрятана в главе «потом настроишь».":"protection is on right after install, not hidden in a «configure it later» chapter.",
"фаервол с первой загрузки":"firewall from the first boot","nftables: входящие закрыты, исходящие открыты. управление через kryonux-firewall.":"nftables: incoming closed, outgoing open. managed through kryonux-firewall.",
"подписанные релизы":"signed releases","sha256 всех файлов и подпись minisign для iso, публичный ключ лежит на сайте.":"sha256 of all files and a minisign signature for the iso, the public key is on the site.",
"attestation в github actions":"attestation in github actions","происхождение сборки подтверждается в самом github, а не только словами.":"build provenance is confirmed by github itself, not just by words.",
"sshd выключен":"sshd is off","openssh стоит, но не запущен. root по ssh закрыт, включается двумя командами.":"OpenSSH is installed but not running. root over ssh is closed, it is enabled with two commands.",
"свой пакетный менеджер: пакеты собираются из исходников, на btrfs перед обновлением делается снимок.":"its own package manager: packages are built from source, on btrfs a snapshot is made before an upgrade.",
"снимки btrfs":"btrfs snapshots","upgrade сначала делает снимок корня, rollback загружается из него.":"upgrade makes a root snapshot first, rollback boots from it.",
"проверка при установке":"check on install","исходники kpkg проверяются подписью minisign, без неё установка отменяется.":"The kpkg sources are checked with a minisign signature, without it the install is aborted.",
"доктор":"doctor","kpkg doctor проверяет настройку, kpkg fix чинит окружение сборки.":"kpkg doctor checks the setup, kpkg fix repairs the build environment.",
"что внутри и чего нет":"what is inside and what is missing","честный список, без маркетинга.":"an honest list, without marketing.",
"что внутри":"what is inside","чего пока нет":"what is missing for now","gcc, glibc, binutils, python":"gcc, glibc, binutils, python","openrc, udev, dhcpcd, iwd":"openrc, udev, dhcpcd, iwd","opendoas вместо sudo":"OpenDoas instead of sudo","curl, git, nano, wget, rsync":"curl, git, nano, wget, rsync","nftables, gnupg, man-db":"nftables, gnupg, man-db","kpkg для пакетов":"kpkg for packages","выбор рабочего стола и графики":"a choice of desktop and graphics","arm, только x86_64":"ARM, only x86_64","графического установщика":"a graphical installer",
"новое":"news","последние изменения проекта.":"latest project changes.",
"частые вопросы":"faq",
"это отдельный дистрибутив или сборка чужого?":"is this a separate distribution or a rebuild of someone else's?","собственная система: база собрана по lfs с glibc, свой установщик, свой загрузочный образ и свои сборочные скрипты. рецепты пакетов в kpkg написаны для проекта.":"its own system: the base is built by lfs with glibc, with its own installer, boot image and build scripts. package recipes in kpkg are written for the project.",
"на каком железе работает?":"what hardware does it run on?","только x86_64, uefi и старый bios. на странице «железо» собрано, на чём проверено.":"only x86_64, uefi and legacy bios. the «hardware» page lists what it was tested on.",
"есть ли графика?":"is there graphics?","нет, после установки только консоль. всё остальное ты добавляешь сам через kpkg.":"no, only a console after install. everything else you add yourself through kpkg.",
"как проверить, что iso не подменён?":"how do i check that the iso is genuine?","сверь sha256 и, если в релизе есть файл .minisig, подпись minisign ключом с сайта. файлы и суммы лежат на странице релизов.":"compare the sha256 and, if the release has a .minisig file, the minisign signature with the key from the site. the files and checksums are on the releases page.",
"безопасно ли в live пароль Kryonux?":"is the Kryonux password in live safe?","пароль Kryonux известен всем и нужен только для live, ssh в live закрыт. в установленной системе такого пароля нет.":"the Kryonux password is public and only for live, ssh is closed in live. the installed system has no such password.",
"дальше":"next","справочник":"handbook","релизы":"releases","форум":"forum","железо":"hardware",
"установка, первые шаги и ошибки":"install, first steps and errors","live iso и контрольные суммы":"live iso and checksums","вопросы и обсуждение":"questions and discussion","что в работе и что в планах":"what is in progress and what is planned","на чём проверено, добавь своё":"what it was tested on, add yours",
"статус сборок":"build status","состояние github actions":"GitHub Actions state","сравнение":"comparison","чем Kryonux отличается от других":"how Kryonux differs from others","поставь Kryonux сегодня":"install Kryonux today","скачай live iso, проверь сумму и запусти установщик. хватит флешки и десяти минут.":"download the live iso, check the sum and run the installer. a usb stick and ten minutes are enough.",
"нет новостей":"no news"
};
if(W.I18N&&W.I18N.add)W.I18N.add(D);
function lang(){return W.KryonuxTheme&&W.KryonuxTheme.getLang?W.KryonuxTheme.getLang():'ru'}
function tr(s){return W.I18N&&W.I18N.t?W.I18N.t(s):s}
function $(s,r){return (r||d).querySelector(s)}
function el(t,c,x){var e=d.createElement(t);if(c)e.className=c;if(x!=null)e.textContent=x;return e}

var tb=$('#tmb'),cur='i';
function draw(k){
  cur=k;
  tb.className='tb';
  tb.textContent='';
  T[k].forEach(function(r){
    var l=el('span','l');
    if(r[0]==='p'){l.appendChild(el('span','p','$'));l.appendChild(d.createTextNode(r[1]))}
    else l.appendChild(el('span','c',tr(r[1])));
    tb.appendChild(l);
  });
  if(!W.matchMedia||!W.matchMedia('(prefers-reduced-motion: reduce)').matches){
    var ls=tb.children;
    for(var i=0;i<ls.length;i++)ls[i].style.animationDelay=(i*0.22)+'s';
    void tb.offsetWidth;
    tb.className='tb go';
  }
}
if(tb){
  [].forEach.call(d.querySelectorAll('.tab'),function(b){
    b.addEventListener('click',function(){
      [].forEach.call(d.querySelectorAll('.tab'),function(x){x.setAttribute('aria-selected',x===b?'true':'false')});
      draw(b.getAttribute('data-k'));
    });
  });
  draw('i');
  W.addEventListener('kryonuxlang',function(){draw(cur)});
}

[].forEach.call(d.querySelectorAll('[data-copy]'),function(b){
  var lab=$('span',b);
  b.addEventListener('click',function(){
    var v=b.getAttribute('data-copy');
    function ok(){
      b.classList.add('ok');
      if(lab)lab.textContent=tr('скопировано');
      setTimeout(function(){b.classList.remove('ok');if(lab)lab.textContent=tr('копировать')},1600);
    }
    if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(v).then(ok,function(){})}
  });
});

var rv=d.querySelectorAll('.rv');
if('IntersectionObserver' in W){
  var io=new IntersectionObserver(function(es){
    es.forEach(function(e){if(e.isIntersecting){e.target.classList.add('in');io.unobserve(e.target)}});
  },{threshold:.12,rootMargin:'0px 0px -40px 0px'});
  [].forEach.call(rv,function(n){io.observe(n)});
}else{
  [].forEach.call(rv,function(n){n.classList.add('in')});
}

function mb(n){return (n/1048576).toFixed(0)+(lang()==='en'?' mb':' мб')}
var a=$('#dl'),inf=$('#dlinfo');
if(W.fetch){
  fetch('https://api.github.com/repos/wh1laye/Kryonux/releases?per_page=10').then(function(r){return r.ok?r.json():[]}).then(function(rs){
    for(var k=0;k<rs.length;k++){
      var r=rs[k];
      if(r.draft)continue;
      var f=(r.assets||[]).filter(function(x){return /^kryonux-live-.*\.iso$/.test(x.name)})[0];
      if(!f)continue;
      var m=f.name.match(/(\d+(?:\.\d+)+)\.iso$/);
      if(a)a.href=f.browser_download_url;
      if(inf)inf.textContent=f.name.replace(/\.iso$/,'')+', '+mb(f.size);
      if(m){$('#kv').textContent='v'+m[1];$('#sv').textContent=m[1]}
      $('#ss').textContent=mb(f.size);
      return;
    }
  }).catch(function(){});
  var nl=$('#nl');
  fetch('news/news.json').then(function(r){return r.ok?r.json():[]}).then(function(ns){
    var en=lang()==='en';
    ns.slice(0,3).forEach(function(n){
      var c=el('a','card rv in');
      c.href='news/';
      c.style.textDecoration='none';
      c.style.color='inherit';
      c.appendChild(el('time','',n.d));
      c.appendChild(el('h3','',en&&n.te?n.te:n.t));
      c.appendChild(el('p','',en&&n.pe?n.pe:n.p));
      nl.appendChild(c);
    });
    if(!nl.children.length)nl.appendChild(el('p','mu',tr('нет новостей')));
  }).catch(function(){});
}
})();
