#!/usr/bin/env python3
"""
Prepara a exportação Web do Godot para hospedagem com limite de tamanho por arquivo:
divide index.wasm em partes de até 12 MB e gera uma página (play.html) que
remonta o motor no navegador antes de iniciar o jogo.

Uso:
    godot --headless --path . --export-release "Web" build/web/index.html
    python3 tools/web/make_page.py build/web build/webpub
"""
import json, os, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
CHUNK = 12 * 1024 * 1024

wasm = open(os.path.join(src, "index.wasm"), "rb").read()
parts = []
for i in range(0, len(wasm), CHUNK):
    name = f"engine.part{len(parts)}.wasm"
    open(os.path.join(dst, name), "wb").write(wasm[i:i + CHUNK])
    parts.append(name)
for f in ["index.js", "index.audio.worklet.js"]:
    shutil.copy(os.path.join(src, f), os.path.join(dst, f))
shutil.copy(os.path.join(src, "index.pck"), os.path.join(dst, "game.pck.wasm"))
for old in ["index.pck"] + [f"engine.part{i}.bin" for i in range(8)]:
    if os.path.exists(os.path.join(dst, old)):
        os.remove(os.path.join(dst, old))
pck_size = os.path.getsize(os.path.join(src, "index.pck"))

page = r"""<title>SHIN: A Lenda do Samurai das Sombras</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>
:root{--ink:#0b0809;--paper:#f3ece2;--blood:#b3161c;--gold:#c9a25c;--mist:#8a8080;color-scheme:dark;
--display:"Shippori Mincho B1","Shippori Mincho","Noto Serif JP",Georgia,serif;--body:"Noto Sans","Segoe UI",system-ui,sans-serif}
html,body{height:100%;margin:0;background:var(--ink);color:var(--paper);overflow:hidden}
#canvas{position:fixed;inset:0;width:100%;height:100%;display:block;background:#000;outline:none;touch-action:none}
#gate{position:fixed;inset:0;display:grid;place-items:center;padding-block:24px;
padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));
background:radial-gradient(ellipse at 70% 30%,#3a0b10 0%,var(--ink) 62%);z-index:5}
.card{max-width:640px;width:100%;display:grid;gap:18px;text-align:left}
.eyebrow{font:600 12px/1 var(--body);letter-spacing:.32em;text-transform:uppercase;color:var(--gold)}
h1{margin:0;font:800 clamp(64px,14vw,132px)/.9 var(--display);letter-spacing:.02em;text-wrap:balance}
h1 span{display:inline-grid;place-items:center;font-size:.42em;width:1.5em;height:1.5em;margin-left:.25em;
vertical-align:.55em;background:var(--blood);color:var(--paper);border-radius:6px}
.sub{font:700 clamp(16px,3.4vw,24px)/1.2 var(--display);color:#e0433f;margin:0}
p{margin:0;font:15px/1.55 var(--body);color:#cfc5bb;max-width:60ch}
#play{justify-self:start;font:700 18px/1 var(--body);letter-spacing:.08em;color:var(--paper);background:var(--blood);
border:1px solid var(--gold);border-radius:4px;padding:16px 34px;cursor:pointer}
#play:hover{background:#d01d24}#play:focus-visible{outline:2px solid var(--gold);outline-offset:3px}
#play[disabled]{opacity:.6;cursor:progress}
.bar{height:3px;background:#2a1f20;border-radius:2px;overflow:hidden}.bar i{display:block;height:100%;width:0;background:var(--gold);transition:width .2s}
#status{font:13px/1.4 var(--body);color:var(--mist);min-height:1.4em}
.keys{font:12px/1.6 var(--body);color:var(--mist)}
.keys b{color:var(--paper);font-weight:600}
#err{color:#ff8f86}[hidden]{display:none!important}
@media (prefers-reduced-motion:reduce){.bar i{transition:none}}
</style>
<canvas id="canvas" tabindex="0">Seu navegador não suporta canvas.</canvas>
<div id="gate">
  <div class="card">
    <div class="eyebrow">Ação e aventura em 3D • Edição cinematográfica</div>
    <h1>SHIN<span>侍</span></h1>
    <p class="sub">A Lenda do Samurai das Sombras</p>
    <p>Cinco fases, do despertar na floresta de bambu ao duelo contra Lorde Akuma sob a Lua Sangrenta. Melhor no computador com teclado e mouse; no celular, use o modo paisagem.</p>
    <button id="play" type="button">JOGAR</button>
    <div class="bar"><i id="prog"></i></div>
    <div id="status">Download de ~42 MB na primeira vez.</div>
    <div class="keys"><b>WASD</b> mover · <b>Mouse</b> câmera · <b>Clique</b> atacar (segure: pesado) · <b>Botão dir.</b> defender · <b>F</b> aparar · <b>Espaço</b> esquivar · <b>Shift</b> correr · <b>Q</b> especial · <b>E</b> interagir · <b>Esc</b> pausa</div>
  </div>
</div>
<script src="index.js"></script>
<script>
(function(){
  var PARTS = __PARTS__;
  var WASM_SIZE = __WASM__;
  var PCK_SIZE = __PCK__;
  var statusEl = document.getElementById('status');
  var prog = document.getElementById('prog');
  var btn = document.getElementById('play');
  function setStatus(t, err){ statusEl.textContent = t; statusEl.id = err ? 'err' : 'status'; if (err) statusEl.style.color = '#ff8f86'; }
  var origFetch = window.fetch.bind(window);
  var loaded = 0;
  var wasmPromise = null;
  function fetchPart(u){
    return origFetch(u).then(function(r){
      if (!r.ok) throw new Error('Falha ao baixar ' + u + ' (' + r.status + ')');
      return r.arrayBuffer();
    }).then(function(b){ loaded += b.byteLength; prog.style.width = Math.min(95, loaded / (WASM_SIZE + PCK_SIZE) * 100) + '%'; return b; });
  }
  function assemble(){
    if (!wasmPromise) wasmPromise = Promise.all(PARTS.map(fetchPart)).then(function(bufs){ return new Blob(bufs, {type: 'application/wasm'}); });
    return wasmPromise;
  }
  window.fetch = function(input, init){
    var url = (typeof input === 'string') ? input : (input && input.url) || '';
    if (/index\.pck(\?|$)/.test(url)) {
      return origFetch('game.pck.wasm').then(function(r){
        if (!r.ok) throw new Error('Falha ao baixar o pacote do jogo (' + r.status + ')');
        return r.arrayBuffer();
      }).then(function(b){ return new Response(b, {status: 200, headers: {'Content-Type': 'application/octet-stream', 'Content-Length': String(b.byteLength)}}); });
    }
    if (/index\.wasm(\?|$)/.test(url)) {
      return assemble().then(function(b){ return new Response(b, {status: 200, headers: {'Content-Type': 'application/wasm', 'Content-Length': String(b.size)}}); });
    }
    return origFetch(input, init);
  };
  if (typeof Engine === 'undefined') { setStatus('Não foi possível carregar o motor do jogo nesta visualização.', true); btn.disabled = true; return; }
  var missing = Engine.getMissingFeatures({threads: false});
  if (missing.length) { setStatus('Seu navegador não tem recursos necessários: ' + missing.join(', ') + '. Tente o Chrome, Edge ou Firefox atualizados.', true); btn.disabled = true; return; }
  var engine = new Engine({
    args: [], canvasResizePolicy: 2, executable: 'index', experimentalVK: false, focusCanvas: true,
    fileSizes: {'index.pck': PCK_SIZE, 'index.wasm': WASM_SIZE}, gdextensionLibs: [],
    canvas: document.getElementById('canvas'),
    ensureCrossOriginIsolationHeaders: false,
    onPrint: function(){ hideGate(); console.log.apply(console, arguments); },
    onPrintError: function(){ console.warn.apply(console, arguments); }
  });
  var hidden = false;
  function hideGate(){ if (hidden) return; hidden = true; setTimeout(function(){ document.getElementById('gate').hidden = true; document.getElementById('canvas').focus(); }, 600); }
  btn.addEventListener('click', function(){
    btn.disabled = true;
    setStatus('Carregando o motor e os recursos...');
    engine.startGame({
      onProgress: function(cur, total){ if (total > 0) { prog.style.width = Math.min(100, cur / total * 100) + '%'; setStatus('Carregando... ' + Math.round(cur / total * 100) + '%'); } }
    }).then(hideGate).catch(function(e){
      btn.disabled = false;
      setStatus('Erro ao iniciar: ' + (e && e.message ? e.message : e), true);
    });
  });
})();
</script>
"""
page = page.replace("__PARTS__", json.dumps(parts)).replace("__WASM__", str(len(wasm))).replace("__PCK__", str(pck_size))
open(os.path.join(dst, "play.html"), "w").write(page)
print("partes:", parts, "pck:", pck_size)
