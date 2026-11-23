"use strict";
/* Propósito — app pessoal de finanças, foco e fé.
   Todos os dados ficam no localStorage deste aparelho. */

const STORE_KEY = "proposito.v1";
const FOCUS_MIN = 25;

// ---------- utilidades ----------
const $ = (s) => document.querySelector(s);
const pad = (n) => String(n).padStart(2, "0");
const dateKey = (d = new Date()) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const monthKey = (d = new Date()) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const BRL = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const money = (v) => BRL.format(v || 0);
const MONTHS = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];
const WEEKDAYS = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"];

function parseMoney(str) {
  let s = String(str || "").trim().replace(/[R$\s]/g, "");
  if (!s) return NaN;
  if (s.includes(",")) s = s.replace(/\./g, "").replace(",", ".");
  return Math.round(parseFloat(s) * 100) / 100;
}
function addMonths(mk, n) {
  const [y, m] = mk.split("-").map(Number);
  const d = new Date(y, m - 1 + n, 1);
  return monthKey(d);
}
function daysInMonth(mk) {
  const [y, m] = mk.split("-").map(Number);
  return new Date(y, m, 0).getDate();
}
function dayOfYear(d = new Date()) {
  return Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000);
}

// ---------- estado ----------
function freshState() {
  return {
    v: 1,
    name: "",
    game: { days: {}, disabled: [], custom: [], bible: { pos: 0, read: 0 }, badges: [], lastLevel: 1, focusSessions: 0 },
    fin: { incomes: [], fixed: [], paid: {}, expenses: [], goal: 0 },
    timer: { endAt: null, remaining: FOCUS_MIN * 60000 },
  };
}
function load() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return freshState();
    const s = JSON.parse(raw);
    const f = freshState();
    return { ...f, ...s, game: { ...f.game, ...s.game }, fin: { ...f.fin, ...s.fin }, timer: { ...f.timer, ...s.timer } };
  } catch (e) {
    console.error(e);
    return freshState();
  }
}
let S = load();
function save() {
  try { localStorage.setItem(STORE_KEY, JSON.stringify(S)); } catch (e) { toast("Não foi possível salvar 😕"); }
}

// ---------- jogo: XP, níveis, missões ----------
const xpForLevel = (L) => 50 * L * (L - 1);
const levelFromXp = (xp) => Math.max(1, Math.floor((1 + Math.sqrt(1 + xp / 12.5)) / 2));
const pillarLevel = (xp) => Math.max(1, Math.floor((1 + Math.sqrt(1 + xp / 5)) / 2)); // 20*L*(L-1)
const titleFor = (lvl) => TITLES.filter(([l]) => lvl >= l).pop()[1];

function missions() {
  const off = new Set(S.game.disabled);
  return [...DEFAULT_MISSIONS, ...S.game.custom].filter((m) => !off.has(m.id));
}
function allMissionDefs() { return [...DEFAULT_MISSIONS, ...S.game.custom]; }
function day(k = dateKey()) {
  if (!S.game.days[k]) S.game.days[k] = { done: {}, water: 0, focusMin: 0, gratitude: "", prayer: "" };
  return S.game.days[k];
}
function peekDay(k) { return S.game.days[k]; }

function totalXp() {
  let xp = 0;
  for (const d of Object.values(S.game.days)) for (const r of Object.values(d.done)) xp += r.xp;
  return xp;
}
function pillarXp() {
  const out = Object.fromEntries(Object.keys(PILLARS).map((k) => [k, 0]));
  for (const d of Object.values(S.game.days)) for (const r of Object.values(d.done)) if (out[r.p] != null) out[r.p] += r.xp;
  return out;
}
const doneCount = (d) => (d ? Object.keys(d.done).length : 0);
const dayIsValid = (d) => doneCount(d) >= 3;

function streaks() {
  // sequência atual: dias seguidos com 3+ missões (hoje conta se já valer; senão começa ontem)
  const t = new Date();
  let cur = 0;
  const cursor = new Date(t);
  if (!dayIsValid(peekDay(dateKey(cursor)))) cursor.setDate(cursor.getDate() - 1);
  while (dayIsValid(peekDay(dateKey(cursor)))) { cur++; cursor.setDate(cursor.getDate() - 1); }
  // melhor sequência
  const keys = Object.keys(S.game.days).filter((k) => dayIsValid(S.game.days[k])).sort();
  let best = 0, run = 0, prev = null;
  for (const k of keys) {
    const d = new Date(k + "T12:00:00");
    if (prev && Math.round((d - prev) / 86400000) === 1) run++; else run = 1;
    best = Math.max(best, run); prev = d;
  }
  return { cur, best: Math.max(best, cur) };
}
function countMission(id) {
  let n = 0;
  for (const d of Object.values(S.game.days)) if (d.done[id]) n++;
  return n;
}

function setMission(id, on, silent) {
  const m = allMissionDefs().find((x) => x.id === id);
  if (!m) return;
  const d = day();
  const had = !!d.done[id];
  if (on && !had) {
    d.done[id] = { xp: m.xp, p: m.p };
    if (!silent) toast(`+${m.xp} XP · ${m.name}`);
  } else if (!on && had) {
    delete d.done[id];
  } else return;
  save();
  afterProgress();
}
function autoMission(kind, on) {
  const m = missions().find((x) => x.auto === kind);
  if (m) setMission(m.id, on);
}

// ---------- conquistas ----------
function finStats() {
  let goodMonths = 0;
  const months = new Set(S.fin.expenses.map((e) => e.date.slice(0, 7)));
  const now = monthKey();
  for (const mk of months) {
    if (mk >= now) continue;
    const s = monthSummary(mk);
    if (s.income > 0 && s.balance >= Math.max(S.fin.goal, 0.01)) goodMonths++;
  }
  return { expenses: S.fin.expenses.length, goodMonths };
}
const BADGES = [
  { id: "first",     icon: "🌱", name: "Primeiro passo",   desc: "Complete sua primeira missão",        test: (x) => x.missions >= 1 },
  { id: "perfect1",  icon: "⭐", name: "Dia perfeito",     desc: "Complete todas as missões de um dia", test: (x) => x.perfect >= 1 },
  { id: "perfect10", icon: "🌟", name: "Fiel no pouco",    desc: "10 dias perfeitos",                   test: (x) => x.perfect >= 10 },
  { id: "streak3",   icon: "🔥", name: "Aquecendo",        desc: "3 dias seguidos",                     test: (x) => x.best >= 3 },
  { id: "streak7",   icon: "🔥", name: "Uma semana firme", desc: "7 dias seguidos",                     test: (x) => x.best >= 7 },
  { id: "streak30",  icon: "🏆", name: "Hábito formado",   desc: "30 dias seguidos",                    test: (x) => x.best >= 30 },
  { id: "streak100", icon: "👑", name: "Inabalável",       desc: "100 dias seguidos",                   test: (x) => x.best >= 100 },
  { id: "bible10",   icon: "📖", name: "Leitor da Palavra",desc: "Ler 10 capítulos da Bíblia",          test: (x) => x.bible >= 10 },
  { id: "bible100",  icon: "📜", name: "Escriba",          desc: "Ler 100 capítulos",                   test: (x) => x.bible >= 100 },
  { id: "bibleAll",  icon: "✝️", name: "Bíblia completa",  desc: "Ler a Bíblia toda (1189 capítulos)",         test: (x) => x.bible >= 1189 },
  { id: "gym10",     icon: "💪", name: "Templo forte",     desc: "10 treinos",                          test: (x) => x.gym >= 10 },
  { id: "gym50",     icon: "🏋️", name: "Atleta de Cristo", desc: "50 treinos",                          test: (x) => x.gym >= 50 },
  { id: "focus10",   icon: "🎯", name: "Mente afiada",     desc: "10 blocos de foco",                   test: (x) => x.focus >= 10 },
  { id: "focus100",  icon: "🧠", name: "Foco de águia",    desc: "100 blocos de foco",                  test: (x) => x.focus >= 100 },
  { id: "serve10",   icon: "🤝", name: "Servo de todos",   desc: "Servir alguém em 10 dias",            test: (x) => x.serve >= 10 },
  { id: "clean10",   icon: "🥗", name: "Prato limpo",      desc: "10 dias comendo limpo",               test: (x) => x.clean >= 10 },
  { id: "exp30",     icon: "🧾", name: "Mordomo atento",   desc: "Registrar 30 gastos",                 test: (x) => x.exp >= 30 },
  { id: "goal1",     icon: "💰", name: "Mês vitorioso",    desc: "Fechar um mês batendo a meta",        test: (x) => x.goodMonths >= 1 },
  { id: "lvl5",      icon: "🛡️", name: "Nível 5",          desc: "Alcançar o nível 5",                  test: (x) => x.level >= 5 },
  { id: "lvl10",     icon: "⚔️", name: "Nível 10",         desc: "Alcançar o nível 10",                 test: (x) => x.level >= 10 },
  { id: "lvl20",     icon: "🏰", name: "Nível 20",         desc: "Alcançar o nível 20",                 test: (x) => x.level >= 20 },
];
function gameStats() {
  const total = missions().length;
  let perfect = 0, ms = 0;
  for (const d of Object.values(S.game.days)) {
    const c = doneCount(d);
    ms += c;
    if (total && c >= total) perfect++;
  }
  const st = streaks();
  const fs = finStats();
  return {
    missions: ms, perfect, best: st.best, bible: S.game.bible.read, gym: countMission("corpo_treino"),
    focus: S.game.focusSessions, serve: countMission("fe_servir"), clean: countMission("saude_limpo"),
    exp: fs.expenses, goodMonths: fs.goodMonths, level: levelFromXp(totalXp()),
  };
}

function afterProgress() {
  const lvl = levelFromXp(totalXp());
  if (lvl > S.game.lastLevel) {
    S.game.lastLevel = lvl;
    save();
    $("#luLevel").textContent = `Nível ${lvl}`;
    $("#luName").textContent = titleFor(lvl);
    $("#levelup").hidden = false;
    beep(true);
  } else if (lvl < S.game.lastLevel) {
    S.game.lastLevel = lvl; save();
  }
  const x = gameStats();
  for (const b of BADGES) {
    if (!S.game.badges.includes(b.id) && b.test(x)) {
      S.game.badges.push(b.id);
      save();
      setTimeout(() => toast(`🏅 Conquista: ${b.name}`), 900);
    }
  }
  renderJornada();
  renderHeader();
}

// ---------- finanças ----------
const activeIn = (item, mk) => item.from <= mk && (!item.to || item.to >= mk);
function monthSummary(mk) {
  const incomes = S.fin.incomes.filter((i) => (i.recurring ? activeIn(i, mk) : i.month === mk));
  const fixed = S.fin.fixed.filter((f) => activeIn(f, mk));
  const expenses = S.fin.expenses.filter((e) => e.date.startsWith(mk));
  const income = incomes.reduce((a, b) => a + b.amount, 0);
  const fixedTotal = fixed.reduce((a, b) => a + b.amount, 0);
  const spent = expenses.reduce((a, b) => a + b.amount, 0);
  const paid = new Set(S.fin.paid[mk] || []);
  const toPay = fixed.filter((f) => !paid.has(f.id)).reduce((a, b) => a + b.amount, 0);
  return { incomes, fixed, expenses, income, fixedTotal, spent, toPay, paid, balance: income - fixedTotal - spent };
}
// remove item recorrente a partir do mês mk (mantém histórico dos meses anteriores)
function endRecurring(list, id, mk) {
  const i = list.findIndex((x) => x.id === id);
  if (i < 0) return;
  if (list[i].from >= mk) list.splice(i, 1);
  else list[i].to = addMonths(mk, -1);
}

// ---------- UI: geral ----------
let toastTimer;
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove("show"), 2200);
}
let audioCtx;
function beep(happy) {
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    const notes = happy ? [523, 659, 784, 1047] : [880, 660, 880];
    notes.forEach((f, i) => {
      const o = audioCtx.createOscillator(), g = audioCtx.createGain();
      o.frequency.value = f; o.type = "sine";
      g.gain.setValueAtTime(0.0001, audioCtx.currentTime + i * 0.15);
      g.gain.exponentialRampToValueAtTime(0.2, audioCtx.currentTime + i * 0.15 + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + i * 0.15 + 0.14);
      o.connect(g).connect(audioCtx.destination);
      o.start(audioCtx.currentTime + i * 0.15); o.stop(audioCtx.currentTime + i * 0.15 + 0.15);
    });
    if (navigator.vibrate) navigator.vibrate(happy ? [80, 60, 80, 60, 200] : [200, 100, 200]);
  } catch (e) { /* sem áudio */ }
}

// Diálogo genérico. fields: [{name,label,type,value,options,required,placeholder}]
function openDialog(title, fields, onOk, okLabel = "Salvar") {
  const dlg = $("#dlg");
  $("#dlgTitle").textContent = title;
  $("#dlgOk").textContent = okLabel;
  $("#dlgBody").innerHTML = fields.map((f) => {
    const id = "f_" + f.name;
    let input;
    if (f.type === "select") {
      input = `<select id="${id}" name="${f.name}">${f.options.map(([v, l]) => `<option value="${esc(v)}" ${v === f.value ? "selected" : ""}>${esc(l)}</option>`).join("")}</select>`;
    } else if (f.type === "checkbox") {
      return `<label class="check"><input type="checkbox" id="${id}" name="${f.name}" ${f.value ? "checked" : ""}> ${esc(f.label)}</label>`;
    } else if (f.type === "info") {
      return `<p class="muted small">${f.label}</p>`;
    } else {
      input = `<input id="${id}" name="${f.name}" type="${f.type || "text"}" value="${esc(f.value ?? "")}" placeholder="${esc(f.placeholder || "")}" ${f.required ? "required" : ""} ${f.type === "money" ? 'inputmode="decimal"' : ""} ${f.attrs || ""}>`;
      input = input.replace('type="money"', 'type="text"');
    }
    return `<label class="lbl" for="${id}">${esc(f.label)}</label>${input}`;
  }).join("");
  dlg.returnValue = "";
  dlg.onclose = () => {
    if (dlg.returnValue !== "ok") return;
    const vals = {};
    for (const f of fields) {
      const el = document.getElementById("f_" + f.name);
      if (!el) continue;
      vals[f.name] = f.type === "checkbox" ? el.checked : el.value;
    }
    onOk(vals);
  };
  dlg.showModal();
}

function renderHeader() {
  const now = new Date();
  const h = now.getHours();
  const greet = h < 12 ? "Bom dia" : h < 18 ? "Boa tarde" : "Boa noite";
  $("#hello").textContent = `${greet}${S.name ? ", " + S.name : ""}!`;
  $("#todayLabel").textContent = `${WEEKDAYS[now.getDay()]}, ${now.getDate()} de ${MONTHS[now.getMonth()]}`;
  $("#lvlChip").textContent = `Nv ${levelFromXp(totalXp())}`;
}

// ---------- UI: Jornada ----------
function renderJornada() {
  const [vt, vr] = VERSES[dayOfYear() % VERSES.length];
  $("#verseText").textContent = `“${vt}”`;
  $("#verseRef").textContent = vr;

  const xp = totalXp();
  const lvl = levelFromXp(xp);
  const base = xpForLevel(lvl), next = xpForLevel(lvl + 1);
  $("#heroTitle").textContent = `${titleFor(lvl)} · Nível ${lvl}`;
  $("#xpFill").style.width = `${((xp - base) / (next - base)) * 100}%`;
  $("#xpText").textContent = `${xp - base} / ${next - base} XP`;
  const st = streaks();
  $("#streakText").textContent = `🔥 ${st.cur} ${st.cur === 1 ? "dia" : "dias"} · recorde ${st.best}`;

  const ms = missions();
  const d = day();
  const done = ms.filter((m) => d.done[m.id]).length;
  const pct = ms.length ? Math.round((done / ms.length) * 100) : 0;
  $("#dayRing").style.setProperty("--p", pct);
  $("#dayPct").textContent = `${pct}%`;
  $("#dayDone").textContent = `${done} de ${ms.length} missões hoje`;
  const bucket = pct === 0 ? "zero" : pct === 100 ? "all" : pct >= 60 ? "most" : "some";
  const pool = MOTIVATION[bucket];
  $("#dayMsg").textContent = pool[(dayOfYear() + done) % pool.length];

  // missões agrupadas por pilar
  const groups = {};
  for (const m of ms) (groups[m.p] = groups[m.p] || []).push(m);
  $("#missions").innerHTML = Object.keys(PILLARS).filter((p) => groups[p]).map((p) => {
    const P = PILLARS[p];
    return `<div class="mgroup"><div class="mgroup-title" style="color:${P.color}">${P.icon} ${P.name}</div>` +
      groups[p].map((m) => `
        <button class="mission ${d.done[m.id] ? "done" : ""}" data-mid="${esc(m.id)}" style="--c:${P.color}">
          <span class="mcheck">${d.done[m.id] ? "✓" : ""}</span>
          <span class="mtext"><span class="mname">${esc(m.name)}</span>${m.hint ? `<span class="mhint">${esc(m.hint)}${m.auto ? " · automática" : ""}</span>` : ""}</span>
          <span class="mxp">+${m.xp}</span>
        </button>`).join("") + `</div>`;
  }).join("");

  // água
  $("#waterCups").innerHTML = Array.from({ length: 8 }, (_, i) => `<span class="cup ${i < d.water ? "full" : ""}"></span>`).join("");
  $("#waterText").textContent = `${d.water} / 8`;
  $("#focusToday").textContent = `${d.focusMin} min focado hoje`;

  // Bíblia
  const pos = Math.min(S.game.bible.pos, 1188);
  const [bk, ch] = bibleAt(pos);
  $("#bibleNext").textContent = S.game.bible.pos >= 1189 ? "Bíblia concluída! 🎉" : `${bk} ${ch}`;
  const bp = (Math.min(S.game.bible.pos, 1189) / 1189) * 100;
  $("#bibleFill").style.width = bp + "%";
  $("#bibleProg").textContent = `${Math.min(S.game.bible.pos, 1189)} de 1189 capítulos (${bp.toFixed(1)}%) · ${S.game.bible.read} lidos no app`;

  // diário (não sobrescreve enquanto digita)
  if (document.activeElement !== $("#gratitude")) $("#gratitude").value = d.gratitude || "";
  if (document.activeElement !== $("#prayer")) $("#prayer").value = d.prayer || "";

  // atributos
  const px = pillarXp();
  $("#pillars").innerHTML = Object.entries(PILLARS).map(([k, P]) => {
    const L = pillarLevel(px[k]);
    const b = 20 * L * (L - 1), n = 20 * (L + 1) * L;
    return `<div class="pillar"><span class="pname">${P.icon} ${P.name}</span><span class="plvl">Nv ${L}</span>
      <div class="bar"><div class="barfill" style="width:${((px[k] - b) / (n - b)) * 100}%;background:${P.color}"></div></div></div>`;
  }).join("");

  // conquistas
  $("#badges").innerHTML = BADGES.map((b) => {
    const got = S.game.badges.includes(b.id);
    return `<div class="badge ${got ? "got" : ""}" title="${esc(b.desc)}"><div class="bicon">${got ? b.icon : "🔒"}</div><div class="bname">${esc(b.name)}</div><div class="bdesc">${esc(b.desc)}</div></div>`;
  }).join("");

  // semana
  const total = ms.length || 1;
  const cells = [];
  for (let i = 6; i >= 0; i--) {
    const dt = new Date(); dt.setDate(dt.getDate() - i);
    const c = doneCount(peekDay(dateKey(dt)));
    const p = Math.min(100, Math.round((c / total) * 100));
    cells.push(`<div class="wday"><div class="wbar"><div class="wfill" style="height:${p}%"></div></div><div class="wlbl">${WEEKDAYS[dt.getDay()].slice(0, 3)}</div><div class="wnum">${c}</div></div>`);
  }
  $("#week").innerHTML = cells.join("");
  renderTimer();
}

function bibleAt(pos) {
  let p = pos;
  for (const [name, n] of BIBLE) {
    if (p < n) return [name, p + 1];
    p -= n;
  }
  return ["Apocalipse", 22];
}
function bibleIndex(bookIdx, chap) {
  let p = 0;
  for (let i = 0; i < bookIdx; i++) p += BIBLE[i][1];
  return p + Math.min(Math.max(1, chap), BIBLE[bookIdx][1]) - 1;
}

// ---------- timer de foco ----------
let timerInt = null;
function timerLeft() {
  return S.timer.endAt ? Math.max(0, S.timer.endAt - Date.now()) : S.timer.remaining;
}
function renderTimer() {
  const ms = timerLeft();
  const s = Math.ceil(ms / 1000);
  $("#timerText").textContent = `${pad(Math.floor(s / 60))}:${pad(s % 60)}`;
  $("#timerBtn").textContent = S.timer.endAt ? "Pausar" : S.timer.remaining < FOCUS_MIN * 60000 ? "Continuar" : "Iniciar";
  $("#timerText").classList.toggle("running", !!S.timer.endAt);
}
function tick() {
  if (S.timer.endAt && Date.now() >= S.timer.endAt) finishFocus();
  renderTimer();
}
function finishFocus() {
  S.timer = { endAt: null, remaining: FOCUS_MIN * 60000 };
  const d = day();
  d.focusMin += FOCUS_MIN;
  S.game.focusSessions++;
  save();
  beep(false);
  toast("⏱ Bloco de foco concluído! Descanse 5 minutos.");
  autoMission("focus", true);
  renderJornada();
}
function startTimer() {
  if (S.timer.endAt) {
    S.timer.remaining = timerLeft();
    S.timer.endAt = null;
  } else {
    S.timer.endAt = Date.now() + S.timer.remaining;
    if (audioCtx == null) try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) {}
  }
  save();
  renderTimer();
}

// ---------- UI: Finanças ----------
let curMonth = monthKey();
let selCat = "alimentacao";

function renderFin() {
  const mk = curMonth;
  const [y, m] = mk.split("-").map(Number);
  $("#monthLabel").textContent = `${MONTHS[m - 1]} ${y}`;
  const s = monthSummary(mk);

  $("#balance").textContent = money(s.balance);
  $("#balance").className = "balance " + (s.balance < 0 ? "neg" : "pos");
  $("#sIncome").textContent = money(s.income);
  $("#sFixed").textContent = money(s.fixedTotal);
  $("#sSpent").textContent = money(s.spent);

  const goal = S.fin.goal || 0;
  $("#goalValue").textContent = goal ? money(goal) : "não definida";
  const gp = goal ? Math.max(0, Math.min(100, (s.balance / goal) * 100)) : 0;
  $("#goalFill").style.width = gp + "%";
  $("#goalMsg").textContent = !goal ? "Defina quanto quer guardar por mês."
    : s.balance >= goal ? "🎉 Meta garantida neste mês! Continue assim."
    : s.balance > 0 ? `Faltam ${money(goal - s.balance)} para a meta.`
    : "Atenção: os gastos passaram da renda. Hora de ajustar.";

  // quanto pode gastar por dia
  const now = monthKey();
  if (mk === now && s.income > 0) {
    const left = daysInMonth(mk) - new Date().getDate() + 1;
    const free = s.balance - goal;
    $("#dailyAllow").innerHTML = free > 0
      ? `Para bater a meta, você pode gastar até <b>${money(free / left)}</b> por dia nos próximos ${left} dias.`
      : `Para bater a meta, evite novos gastos este mês.`;
  } else $("#dailyAllow").innerHTML = s.income ? "" : "Comece cadastrando sua renda (salário) logo abaixo. 👇";

  $("#finTip").textContent = FIN_TIPS[dayOfYear() % FIN_TIPS.length];

  // renda
  $("#incomeList").innerHTML = s.incomes.length ? s.incomes.map((i) => `
    <div class="item"><div class="itxt"><b>${esc(i.desc)}</b><span class="muted small">${i.recurring ? "todo mês" : "só este mês"}</span></div>
    <div class="ival pos">${money(i.amount)}</div><button class="icon-btn" data-inc-edit="${i.id}" aria-label="Editar">✎</button><button class="icon-btn" data-inc-del="${i.id}" aria-label="Remover">🗑</button></div>`).join("")
    : `<div class="empty">Nenhuma renda neste mês. Cadastre seu salário.</div>`;

  // contas fixas
  const today = new Date().getDate();
  const fixedSorted = [...s.fixed].sort((a, b) => a.day - b.day);
  $("#fixedList").innerHTML = fixedSorted.length ? fixedSorted.map((f) => {
    const paid = s.paid.has(f.id);
    const late = !paid && mk === now && f.day < today;
    const cat = EXPENSE_CATS.find((c) => c.id === f.cat) || EXPENSE_CATS[EXPENSE_CATS.length - 1];
    return `<div class="item ${paid ? "paid" : ""}">
      <button class="paybox ${paid ? "on" : ""}" data-fix-pay="${f.id}" aria-label="Marcar como paga">${paid ? "✓" : ""}</button>
      <div class="itxt"><b>${cat.icon} ${esc(f.name)}</b><span class="small ${late ? "neg" : "muted"}">vence dia ${f.day}${late ? " · atrasada!" : paid ? " · paga" : ""}</span></div>
      <div class="ival">${money(f.amount)}</div><button class="icon-btn" data-fix-edit="${f.id}" aria-label="Editar">✎</button><button class="icon-btn" data-fix-del="${f.id}" aria-label="Remover">🗑</button></div>`;
  }).join("") + `<div class="row-between small muted pad-t"><span>A pagar</span><b>${money(s.toPay)}</b></div>`
    : `<div class="empty">Cadastre aluguel, luz, internet, celular, academia…</div>`;

  // categorias do formulário
  $("#expCats").innerHTML = EXPENSE_CATS.map((c) => `<button type="button" class="cat ${c.id === selCat ? "on" : ""}" data-cat="${c.id}">${c.icon} ${c.name}</button>`).join("");
  if (!$("#expDate").value) $("#expDate").value = dateKey();

  // por categoria
  const byCat = {};
  for (const e of s.expenses) byCat[e.cat] = (byCat[e.cat] || 0) + e.amount;
  const rows = Object.entries(byCat).sort((a, b) => b[1] - a[1]);
  const max = rows.length ? rows[0][1] : 1;
  $("#catBreak").innerHTML = rows.length ? rows.map(([cid, v]) => {
    const c = EXPENSE_CATS.find((x) => x.id === cid) || { icon: "📦", name: cid };
    return `<div class="catrow"><div class="row-between small"><span>${c.icon} ${esc(c.name)}</span><b>${money(v)} <span class="muted">(${Math.round((v / s.spent) * 100)}%)</span></b></div>
      <div class="bar"><div class="barfill" style="width:${(v / max) * 100}%"></div></div></div>`;
  }).join("") : `<div class="empty">Sem gastos registrados neste mês.</div>`;

  // lista de gastos agrupada por dia
  const byDay = {};
  for (const e of s.expenses) (byDay[e.date] = byDay[e.date] || []).push(e);
  const dkeys = Object.keys(byDay).sort().reverse();
  $("#expList").innerHTML = dkeys.length ? dkeys.map((k) => {
    const dt = new Date(k + "T12:00:00");
    const tot = byDay[k].reduce((a, b) => a + b.amount, 0);
    return `<div class="dayhead"><span>${WEEKDAYS[dt.getDay()]}, ${dt.getDate()}/${pad(dt.getMonth() + 1)}</span><span>${money(tot)}</span></div>` +
      byDay[k].map((e) => {
        const c = EXPENSE_CATS.find((x) => x.id === e.cat) || { icon: "📦", name: "" };
        return `<div class="item"><div class="itxt"><b>${c.icon} ${esc(e.desc || c.name)}</b><span class="muted small">${esc(c.name)}</span></div>
          <div class="ival neg">${money(e.amount)}</div><button class="icon-btn" data-exp-del="${e.id}" aria-label="Remover">🗑</button></div>`;
      }).join("");
  }).join("") : `<div class="empty">Nada por aqui ainda.</div>`;
}

function incomeDialog(existing) {
  openDialog(existing ? "Editar renda" : "Nova renda", [
    { name: "desc", label: "Descrição", value: existing?.desc || "Salário", required: true },
    { name: "amount", label: "Valor", type: "money", value: existing ? String(existing.amount).replace(".", ",") : "", required: true, placeholder: "ex: 3500,00" },
    ...(existing ? [] : [{ name: "recurring", label: "Repete todo mês (ex: salário)", type: "checkbox", value: true }]),
  ], (v) => {
    const amount = parseMoney(v.amount);
    if (!(amount > 0)) return toast("Valor inválido");
    if (existing) Object.assign(existing, { desc: v.desc.trim() || "Renda", amount });
    else S.fin.incomes.push({ id: uid(), desc: v.desc.trim() || "Renda", amount, recurring: v.recurring, from: curMonth, month: curMonth });
    save(); renderFin();
  });
}
function fixedDialog(existing) {
  openDialog(existing ? "Editar conta fixa" : "Nova conta fixa", [
    { name: "name", label: "Nome", value: existing?.name || "", required: true, placeholder: "ex: Aluguel" },
    { name: "amount", label: "Valor mensal", type: "money", value: existing ? String(existing.amount).replace(".", ",") : "", required: true, placeholder: "ex: 120,00" },
    { name: "day", label: "Dia do vencimento", type: "number", value: existing?.day || 10, attrs: 'min="1" max="31" inputmode="numeric"' },
    { name: "cat", label: "Categoria", type: "select", value: existing?.cat || "casa", options: EXPENSE_CATS.map((c) => [c.id, `${c.icon} ${c.name}`]) },
  ], (v) => {
    const amount = parseMoney(v.amount);
    if (!(amount > 0)) return toast("Valor inválido");
    const dd = Math.min(31, Math.max(1, parseInt(v.day) || 1));
    if (existing) Object.assign(existing, { name: v.name.trim(), amount, day: dd, cat: v.cat });
    else S.fin.fixed.push({ id: uid(), name: v.name.trim() || "Conta", amount, day: dd, cat: v.cat, from: curMonth });
    save(); renderFin();
  });
}

// ---------- UI: Ajustes ----------
function renderSettings() {
  if (document.activeElement !== $("#nameInput")) $("#nameInput").value = S.name || "";
  const off = new Set(S.game.disabled);
  $("#misList").innerHTML = allMissionDefs().map((m) => {
    const P = PILLARS[m.p];
    const custom = S.game.custom.some((c) => c.id === m.id);
    return `<div class="item"><label class="switch"><input type="checkbox" data-mis-toggle="${esc(m.id)}" ${off.has(m.id) ? "" : "checked"}><span></span></label>
      <div class="itxt"><b>${esc(m.name)}</b><span class="muted small">${P.icon} ${P.name} · +${m.xp} XP${m.auto ? " · automática" : ""}</span></div>
      ${custom ? `<button class="icon-btn" data-mis-del="${esc(m.id)}" aria-label="Remover">🗑</button>` : ""}</div>`;
  }).join("");
}

// ---------- navegação ----------
function showView(v) {
  document.querySelectorAll(".view").forEach((el) => (el.hidden = el.id !== "view-" + v));
  document.querySelectorAll(".tabbar button").forEach((b) => b.classList.toggle("active", b.dataset.view === v));
  try { localStorage.setItem("proposito.tab", v); } catch (e) {}
  if (v === "financas") renderFin();
  if (v === "ajustes") renderSettings();
  if (v === "jornada") renderJornada();
  window.scrollTo(0, 0);
}

// ---------- eventos ----------
function bind() {
  document.querySelectorAll(".tabbar button").forEach((b) => b.addEventListener("click", () => showView(b.dataset.view)));

  $("#missions").addEventListener("click", (e) => {
    const b = e.target.closest("[data-mid]");
    if (!b) return;
    const id = b.dataset.mid;
    setMission(id, !day().done[id]);
  });

  $("#waterPlus").addEventListener("click", () => {
    const d = day(); if (d.water >= 20) return;
    d.water++; save();
    if (d.water === 8) autoMission("water", true); else renderJornada();
  });
  $("#waterMinus").addEventListener("click", () => {
    const d = day(); if (d.water <= 0) return;
    d.water--; save();
    if (d.water === 7) autoMission("water", false); else renderJornada();
  });

  $("#timerBtn").addEventListener("click", startTimer);
  $("#timerReset").addEventListener("click", () => { S.timer = { endAt: null, remaining: FOCUS_MIN * 60000 }; save(); renderTimer(); });

  $("#bibleRead").addEventListener("click", () => {
    if (S.game.bible.pos >= 1189) return toast("Você já concluiu a Bíblia! Recomece pelo seletor abaixo.");
    const [bk, ch] = bibleAt(S.game.bible.pos);
    S.game.bible.pos++; S.game.bible.read++;
    save();
    toast(`📖 ${bk} ${ch} lido!`);
    if (!day().done["fe_biblia"]) autoMission("bible", true); else afterProgress();
  });
  $("#bibleBook").innerHTML = BIBLE.map(([n], i) => `<option value="${i}">${n}</option>`).join("");
  $("#bibleSet").addEventListener("click", () => {
    const bi = parseInt($("#bibleBook").value), ch = parseInt($("#bibleChap").value) || 1;
    S.game.bible.pos = bibleIndex(bi, ch);
    save(); renderJornada(); toast("Ponto de leitura atualizado");
  });

  let jt;
  const saveJournal = () => {
    const d = day();
    d.gratitude = $("#gratitude").value;
    d.prayer = $("#prayer").value;
    save();
    $("#journalSaved").textContent = "Salvo ✓";
    const has = d.gratitude.trim().length >= 3;
    if (has !== !!d.done["fe_gratidao"]) autoMission("gratitude", has);
  };
  ["#gratitude", "#prayer"].forEach((s) => $(s).addEventListener("input", () => {
    $("#journalSaved").textContent = "…";
    clearTimeout(jt); jt = setTimeout(saveJournal, 700);
  }));

  $("#luClose").addEventListener("click", () => ($("#levelup").hidden = true));
  $("#levelup").addEventListener("click", (e) => { if (e.target.id === "levelup") $("#levelup").hidden = true; });

  // finanças
  $("#mPrev").addEventListener("click", () => { curMonth = addMonths(curMonth, -1); renderFin(); });
  $("#mNext").addEventListener("click", () => { curMonth = addMonths(curMonth, 1); renderFin(); });
  $("#expCats").addEventListener("click", (e) => {
    const b = e.target.closest("[data-cat]"); if (!b) return;
    selCat = b.dataset.cat;
    document.querySelectorAll("#expCats .cat").forEach((x) => x.classList.toggle("on", x === b));
  });
  $("#expForm").addEventListener("submit", (e) => {
    e.preventDefault();
    const amount = parseMoney($("#expAmount").value);
    if (!(amount > 0)) return toast("Digite um valor válido");
    const date = $("#expDate").value || dateKey();
    S.fin.expenses.push({ id: uid(), amount, desc: $("#expDesc").value.trim(), cat: selCat, date });
    save();
    $("#expAmount").value = ""; $("#expDesc").value = "";
    toast(`Gasto de ${money(amount)} salvo`);
    if (date.slice(0, 7) !== curMonth) curMonth = date.slice(0, 7);
    renderFin();
    if (date === dateKey()) autoMission("expense", true); else afterProgress();
  });
  $("#goalEdit").addEventListener("click", () => openDialog("Meta de economia mensal", [
    { name: "goal", label: "Quanto quero guardar por mês", type: "money", value: S.fin.goal ? String(S.fin.goal).replace(".", ",") : "", placeholder: "ex: 500,00" },
    { type: "info", name: "_", label: "Dica: comece com 10% da sua renda e vá aumentando." },
  ], (v) => { const g = parseMoney(v.goal); S.fin.goal = g > 0 ? g : 0; save(); renderFin(); }));
  $("#incAdd").addEventListener("click", () => incomeDialog());
  $("#fixAdd").addEventListener("click", () => fixedDialog());

  $("#view-financas").addEventListener("click", (e) => {
    const t = e.target.closest("button"); if (!t) return;
    const ds = t.dataset;
    if (ds.incEdit) incomeDialog(S.fin.incomes.find((i) => i.id === ds.incEdit));
    if (ds.incDel) {
      const it = S.fin.incomes.find((i) => i.id === ds.incDel);
      if (!it || !confirm(it.recurring ? `Remover "${it.desc}" deste mês em diante? (meses anteriores ficam como estão)` : `Remover "${it.desc}"?`)) return;
      if (it.recurring) endRecurring(S.fin.incomes, it.id, curMonth); else S.fin.incomes = S.fin.incomes.filter((i) => i.id !== it.id);
      save(); renderFin();
    }
    if (ds.fixPay) {
      const arr = S.fin.paid[curMonth] = S.fin.paid[curMonth] || [];
      const i = arr.indexOf(ds.fixPay);
      if (i >= 0) arr.splice(i, 1); else { arr.push(ds.fixPay); toast("Conta paga ✓"); }
      save(); renderFin();
    }
    if (ds.fixEdit) fixedDialog(S.fin.fixed.find((f) => f.id === ds.fixEdit));
    if (ds.fixDel) {
      const it = S.fin.fixed.find((f) => f.id === ds.fixDel);
      if (!it || !confirm(`Remover "${it.name}" deste mês em diante? (meses anteriores ficam como estão)`)) return;
      endRecurring(S.fin.fixed, it.id, curMonth);
      save(); renderFin();
    }
    if (ds.expDel) {
      if (!confirm("Remover este gasto?")) return;
      S.fin.expenses = S.fin.expenses.filter((x) => x.id !== ds.expDel);
      save(); renderFin();
    }
  });

  // ajustes
  $("#nameInput").addEventListener("input", (e) => { S.name = e.target.value.trim().slice(0, 30); save(); renderHeader(); });
  $("#misList").addEventListener("change", (e) => {
    const id = e.target.dataset.misToggle; if (!id) return;
    S.game.disabled = S.game.disabled.filter((x) => x !== id);
    if (!e.target.checked) S.game.disabled.push(id);
    save();
  });
  $("#misList").addEventListener("click", (e) => {
    const id = e.target.closest("[data-mis-del]")?.dataset.misDel; if (!id) return;
    if (!confirm("Remover esta missão? O XP já ganho com ela continua.")) return;
    S.game.custom = S.game.custom.filter((m) => m.id !== id);
    save(); renderSettings();
  });
  $("#misAdd").addEventListener("click", () => openDialog("Nova missão diária", [
    { name: "name", label: "Missão", required: true, placeholder: "ex: Jejum até meio-dia" },
    { name: "p", label: "Atributo", type: "select", value: "fe", options: Object.entries(PILLARS).map(([k, P]) => [k, `${P.icon} ${P.name}`]) },
    { name: "xp", label: "XP", type: "select", value: "10", options: [["5", "5 · fácil"], ["10", "10 · médio"], ["15", "15 · difícil"], ["20", "20 · desafio"]] },
    { name: "hint", label: "Detalhe (opcional)", placeholder: "ex: só água e café" },
  ], (v) => {
    if (!v.name.trim()) return;
    S.game.custom.push({ id: "c_" + uid(), p: v.p, xp: parseInt(v.xp), name: v.name.trim().slice(0, 50), hint: v.hint.trim().slice(0, 80) });
    save(); renderSettings(); toast("Missão criada");
  }));

  $("#exportBtn").addEventListener("click", () => {
    const blob = new Blob([JSON.stringify(S, null, 2)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `proposito-backup-${dateKey()}.json`;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  });
  $("#importFile").addEventListener("change", async (e) => {
    const file = e.target.files[0]; if (!file) return;
    try {
      const data = JSON.parse(await file.text());
      if (!data.game || !data.fin) throw new Error("formato");
      if (!confirm("Substituir os dados atuais pelos do backup?")) return;
      localStorage.setItem(STORE_KEY, JSON.stringify(data));
      S = load(); renderAll(); toast("Backup restaurado ✓");
    } catch (err) { toast("Arquivo de backup inválido"); }
    e.target.value = "";
  });
  $("#resetBtn").addEventListener("click", () => {
    if (!confirm("Apagar TODOS os dados (finanças e jornada)? Isso não pode ser desfeito.")) return;
    if (!confirm("Tem certeza mesmo? Faça um backup antes se quiser guardar.")) return;
    S = freshState(); save(); renderAll(); toast("Dados apagados");
  });

  let deferredPrompt;
  window.addEventListener("beforeinstallprompt", (e) => { e.preventDefault(); deferredPrompt = e; $("#installBtn").hidden = false; });
  $("#installBtn").addEventListener("click", async () => {
    if (!deferredPrompt) return;
    deferredPrompt.prompt(); await deferredPrompt.userChoice; deferredPrompt = null; $("#installBtn").hidden = true;
  });

  // ao voltar para o app (ex.: virou o dia), atualiza
  document.addEventListener("visibilitychange", () => { if (!document.hidden) { tick(); renderAll(); } });
}

function renderAll() {
  renderHeader();
  renderJornada();
  if (!$("#view-financas").hidden) renderFin();
  if (!$("#view-ajustes").hidden) renderSettings();
}

// ---------- início ----------
bind();
tick();
timerInt = setInterval(tick, 1000);
let startTab = "jornada";
try { startTab = localStorage.getItem("proposito.tab") || "jornada"; } catch (e) {}
showView(["jornada", "financas", "ajustes"].includes(startTab) ? startTab : "jornada");
renderHeader();

if ("serviceWorker" in navigator && location.protocol !== "file:") {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}
