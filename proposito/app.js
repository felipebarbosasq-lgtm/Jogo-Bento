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
    pin: "",
    remember: false,
    game: { days: {}, disabled: [], custom: [], bible: { pos: 0, read: 0 }, badges: [], lastLevel: 1, focusSessions: 0 },
    fin: { incomes: [], fixed: [], paid: {}, expenses: [], goal: 0 },
    timer: { endAt: null, remaining: FOCUS_MIN * 60000, len: FOCUS_MIN },
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

// =====================================================================
//  ÍCONES (traço, 24x24)
// =====================================================================
const ICONS = {
  home: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/><path d="M10 21v-6h4v6"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  flame: '<path d="M12 22c4.2 0 7-2.9 7-6.8 0-3.6-2.4-5.6-3.9-8.7-.9 1.8-1.9 2.9-3.1 3.2.3-3.2-.9-5.9-3-7.7.2 4.2-4 7-4 13.2C5 19.1 7.8 22 12 22z"/>',
  timer: '<circle cx="12" cy="14" r="7.5"/><path d="M12 10.5V14l2.2 2.2M9.5 2.5h5M12 2.5v4"/>',
  hourglass: '<path d="M6 2.5h12M6 21.5h12"/><path d="M7 2.5v3a5 5 0 0 0 10 0v-3M7 21.5v-3a5 5 0 0 1 10 0v3"/>',
  arrowLeft: '<path d="M20 12H4M10 6l-6 6 6 6"/>',
  arrowRight: '<path d="M4 12h16M14 6l6 6-6 6"/>',
  expand: '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>',
  cross: '<path d="M12 2.5v19M6.5 8h11"/>',
  dumbbell: '<path d="M6.5 6.5v11M3.5 9v6M17.5 6.5v11M20.5 9v6M6.5 12h11"/>',
  leaf: '<path d="M5 19c0-8 5-14 15-14 0 10-6 15-14 15"/><path d="M5 19 13 11"/>',
  book: '<path d="M3 5h6a3 3 0 0 1 3 3v13a2 2 0 0 0-2-2H3z"/><path d="M21 5h-6a3 3 0 0 0-3 3v13a2 2 0 0 1 2-2h7z"/>',
  target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.2"/>',
  wallet: '<rect x="3" y="6" width="18" height="14" rx="3"/><path d="M3 10h18M16 15h2"/><path d="M6 6V5a2 2 0 0 1 2-2h9"/>',
  droplet: '<path d="M12 3s7 7.2 7 12a7 7 0 0 1-14 0c0-4.8 7-12 7-12z"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2.5"/><path d="M8 11V7.5a4 4 0 0 1 8 0V11"/>',
  eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  eyeOff: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/><path d="M3 3l18 18"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
  heart: '<path d="M12 20.5s-8-4.9-8-11A4.5 4.5 0 0 1 12 6.6a4.5 4.5 0 0 1 8 2.9c0 6.1-8 11-8 11z"/>',
  trendUp: '<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/>',
  chevL: '<path d="m15 6-6 6 6 6"/>',
  chevR: '<path d="m9 6 6 6-6 6"/>',
  chevUp: '<path d="m5 15 7-7 7 7"/><path d="m5 20 7-7 7 7" opacity=".45"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  receipt: '<path d="M5 3v18l2-1.5L9 21l2-1.5 2 1.5 2-1.5 2 1.5 2-1.5V3l-2 1.5L15 3l-2 1.5L11 3 9 4.5 7 3z"/><path d="M9 9h6M9 13h6"/>',
  coins: '<circle cx="9" cy="9" r="6"/><path d="M15.4 9.6A6 6 0 1 1 9.6 15.4"/><path d="M9 7v4M7.5 8.5h3"/>',
  arrowDownIn: '<path d="M12 4v12M6 11l6 6 6-6"/><path d="M5 20h14"/>',
  star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
  medal: '<circle cx="12" cy="15" r="6"/><path d="M8.5 9.6 6 3h4l2 4 2-4h4l-2.5 6.6"/>',
};
const ic = (n) => `<svg class="i" viewBox="0 0 24 24" aria-hidden="true">${ICONS[n] || ""}</svg>`;
function hydrateIcons(root = document) {
  root.querySelectorAll("[data-ic]").forEach((el) => { el.innerHTML = ic(el.dataset.ic); });
}
const PILLAR_IC = { fe: "cross", corpo: "dumbbell", saude: "leaf", mente: "book", foco: "target", fin: "wallet" };
const WD_SHORT = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
const moneyR = (v) => new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL", maximumFractionDigits: Math.abs(v) >= 100 ? 0 : 2, minimumFractionDigits: Math.abs(v) >= 100 ? 0 : 2 }).format(v || 0);
const greeting = () => { const h = new Date().getHours(); return h < 12 ? "Bom dia" : h < 18 ? "Boa tarde" : "Boa noite"; };

// anel SVG simples
function ringSvg(pct, size, stroke, color, track) {
  const r = (size - stroke) / 2, c = 2 * Math.PI * r, p = Math.max(0, Math.min(1, pct));
  return `<svg viewBox="0 0 ${size} ${size}"><circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${track}" stroke-width="${stroke}"/>
    <circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${color}" stroke-width="${stroke}" stroke-linecap="round" stroke-dasharray="${c * p} ${c}" style="transition:stroke-dasharray .6s"/></svg>`;
}

// =====================================================================
//  JORNADA
// =====================================================================
function renderHeader() {
  $("#hello").textContent = `Olá${S.name ? ", " + S.name : ""},`;
  $("#finHello").textContent = `${greeting()}${S.name ? ", " + S.name : ""}`;
}

function renderJornada() {
  renderHeader();
  const [vt, vr] = VERSES[dayOfYear() % VERSES.length];
  $("#verseText").textContent = `“${vt}”`;
  $("#verseRef").textContent = `Versículo do dia · ${vr}`;

  const xp = totalXp();
  const lvl = levelFromXp(xp);
  const base = xpForLevel(lvl), next = xpForLevel(lvl + 1);
  $("#heroTitle").textContent = `Nível ${lvl} · ${titleFor(lvl)}`;
  $("#xpFill").style.width = `${((xp - base) / (next - base)) * 100}%`;
  $("#xpText").textContent = `${xp - base} / ${next - base} XP`;

  const ms = missions();
  const d = day();
  const done = ms.filter((m) => d.done[m.id]).length;
  const pct = ms.length ? done / ms.length : 0;
  const px = pillarXp();

  // atributos da semana (4 principais)
  $("#statIcons").innerHTML = ["fe", "corpo", "saude", "foco"].map((p) => {
    const active = ms.some((m) => m.p === p && d.done[m.id]);
    return `<button class="sicon ${active ? "on" : ""}" data-pillar="${p}"><span class="circle glass sm">${ic(PILLAR_IC[p])}</span><small>Nv ${pillarLevel(px[p])}</small></button>`;
  }).join("");

  // missão ativa
  const next1 = ms.find((m) => !d.done[m.id]);
  $("#activeName").textContent = next1 ? next1.name : "Dia completo! 🙌";
  $("#activeDo").classList.toggle("done", !next1);
  $("#activeDo").dataset.mid = next1 ? next1.id : "";
  const xpDay = Object.values(d.done).reduce((a, r) => a + r.xp, 0);
  $("#xpToday").textContent = `${xpDay} XP`;
  const st = streaks();
  $("#streakDays").textContent = `${st.cur} ${st.cur === 1 ? "Dia" : "Dias"}`;
  $("#bestStreak").textContent = st.best;
  $("#dayRing").innerHTML = ringSvg(pct, 96, 8, "#2d8cff", "#07112b") + `<div class="lbl-in">Progresso<b>${Math.round(pct * 100)}%</b></div>`;
  $("#dayCount").textContent = `${done}/${ms.length}`;
  const bucket = pct === 0 ? "zero" : pct === 1 ? "all" : pct >= 0.6 ? "most" : "some";
  const pool = MOTIVATION[bucket];
  $("#dayMsg").textContent = pool[(dayOfYear() + done) % pool.length];

  // lista de missões
  const groups = {};
  for (const m of ms) (groups[m.p] = groups[m.p] || []).push(m);
  $("#missions").innerHTML = Object.keys(PILLARS).filter((p) => groups[p]).map((p) =>
    `<div class="mgroup-title">${ic(PILLAR_IC[p])} ${PILLARS[p].name}</div>` +
    groups[p].map((m) => `
      <button class="mission glass ${d.done[m.id] ? "done" : ""}" data-mid="${esc(m.id)}">
        <span class="circle glass">${ic(d.done[m.id] ? "check" : PILLAR_IC[p])}</span>
        <span class="mtext"><span class="mname">${esc(m.name)}</span>${m.hint ? `<span class="mhint">${esc(m.hint)}${m.auto ? " · automática" : ""}</span>` : ""}</span>
        <span class="mxp">+${m.xp} XP</span>
      </button>`).join("")
  ).join("");

  // dias anteriores (últimos 20 dias, sem contar hoje)
  let good = 0;
  for (let i = 1; i <= 20; i++) { const t = new Date(); t.setDate(t.getDate() - i); if (dayIsValid(peekDay(dateKey(t)))) good++; }
  $("#prevRing").innerHTML = ringSvg(good / 20, 58, 6, "#2d8cff", "#07112b") + `<div class="lbl-in">${Math.round((good / 20) * 100)}%</div>`;
  $("#prevText").textContent = `${good} dias vitoriosos (3+ missões)`;
  $("#prevNum").textContent = `${good}/20`;

  const total = ms.length || 1;
  const cells = [];
  for (let i = 6; i >= 0; i--) {
    const dt = new Date(); dt.setDate(dt.getDate() - i);
    const c = doneCount(peekDay(dateKey(dt)));
    cells.push(`<div class="wday"><div class="wbar"><div class="wfill" style="height:${Math.min(100, Math.round((c / total) * 100))}%"></div></div><div class="wlbl">${WD_SHORT[dt.getDay()]}</div><div class="wnum">${c}</div></div>`);
  }
  $("#week").innerHTML = cells.join("");

  // água
  $("#waterCups").innerHTML = Array.from({ length: 8 }, (_, i) => `<span class="cup ${i < d.water ? "full" : ""}"></span>`).join("");
  $("#waterText").textContent = `${d.water} / 8`;

  // Bíblia
  const [bk, ch] = bibleAt(Math.min(S.game.bible.pos, 1188));
  $("#bibleNext").textContent = S.game.bible.pos >= 1189 ? "Concluída! 🎉" : `${bk} ${ch}`;
  const bp = (Math.min(S.game.bible.pos, 1189) / 1189) * 100;
  $("#bibleFill").style.width = bp + "%";
  $("#bibleProg").textContent = `${Math.min(S.game.bible.pos, 1189)} de 1189 capítulos (${bp.toFixed(1).replace(".", ",")}%)`;

  if (document.activeElement !== $("#gratitude")) $("#gratitude").value = d.gratitude || "";
  if (document.activeElement !== $("#prayer")) $("#prayer").value = d.prayer || "";

  // atributos (todos)
  $("#pillars").innerHTML = Object.entries(PILLARS).map(([k, P]) => {
    const L = pillarLevel(px[k]);
    const b = 20 * L * (L - 1), n = 20 * (L + 1) * L;
    return `<div class="pillar"><span class="circle glass">${ic(PILLAR_IC[k])}</span>
      <div class="pbody"><div class="row-between"><span class="pname">${P.name}</span><span class="plvl">Nv ${L} · ${px[k]} XP</span></div>
      <div class="bar"><div class="barfill" style="width:${((px[k] - b) / (n - b)) * 100}%"></div></div></div></div>`;
  }).join("");

  // conquistas
  $("#badges").innerHTML = BADGES.map((b) => {
    const got = S.game.badges.includes(b.id);
    return `<div class="badge glass ${got ? "got" : ""}" title="${esc(b.desc)}"><span class="circle glass">${got ? `<span style="font-size:20px">${b.icon}</span>` : ic("lock")}</span><div class="bname">${esc(b.name)}</div><div class="bdesc">${esc(b.desc)}</div></div>`;
  }).join("");

  renderTimer();
}

function bibleAt(pos) {
  let p = pos;
  for (const [name, n] of BIBLE) { if (p < n) return [name, p + 1]; p -= n; }
  return ["Apocalipse", 22];
}
function bibleIndex(bookIdx, chap) {
  let p = 0;
  for (let i = 0; i < bookIdx; i++) p += BIBLE[i][1];
  return p + Math.min(Math.max(1, chap), BIBLE[bookIdx][1]) - 1;
}

// ---------- bloco de foco ----------
const PRESETS = [[15, "hourglass"], [25, "timer"], [45, "flame"], [60, "target"]];
let timerInt = null, wakeLock = null;
const timerLen = () => (S.timer.len || FOCUS_MIN) * 60000;
const timerLeft = () => (S.timer.endAt ? Math.max(0, S.timer.endAt - Date.now()) : S.timer.remaining);

function gaugeSvg(p) {
  const N = 40, cx = 150, cy = 150, ticks = [];
  for (let i = 0; i <= N; i++) {
    const a = Math.PI - (i / N) * Math.PI;
    const long = i % 5 === 0;
    const r1 = long ? 100 : 106, r2 = 128;
    const on = i / N <= p && p > 0;
    ticks.push(`<line x1="${cx + r1 * Math.cos(a)}" y1="${cy - r1 * Math.sin(a)}" x2="${cx + r2 * Math.cos(a)}" y2="${cy - r2 * Math.sin(a)}" stroke="${on ? "#3aa0ff" : "rgba(10,15,29,.85)"}" stroke-width="${long ? 3 : 2.2}" stroke-linecap="round"/>`);
  }
  const a = Math.PI - p * Math.PI;
  const dot = `<circle cx="${cx + 92 * Math.cos(a)}" cy="${cy - 92 * Math.sin(a)}" r="4.5" fill="#3ddc5f"/><line x1="${cx + 92 * Math.cos(a)}" y1="${cy - 92 * Math.sin(a)}" x2="${cx + 112 * Math.cos(a)}" y2="${cy - 112 * Math.sin(a)}" stroke="#3ddc5f" stroke-width="2"/>`;
  return `<svg viewBox="10 10 280 150">${ticks.join("")}${dot}</svg>`;
}
function renderTimer() {
  const left = timerLeft(), len = timerLen();
  const s = Math.ceil(left / 1000);
  const p = 1 - left / len;
  $("#timerText").innerHTML = `${pad(Math.floor(s / 60))}:${pad(s % 60)}<br><small>min</small>`;
  $("#gauge").innerHTML = gaugeSvg(p) + `<div class="g-in"><b>${Math.round(p * 100)}%</b><span>Progresso</span></div>`;
  $("#focusToday").innerHTML = `${day().focusMin}<br><small>min</small>`;
  const on = !!S.timer.endAt;
  $("#timerBtn").classList.toggle("on", on);
  $("#timerBtn").setAttribute("aria-checked", on);
  $("#timerState").textContent = on ? "On" : "Off";
  document.querySelector(".auto-pill").classList.toggle("off", !on);
  $("#focusPresets").innerHTML = PRESETS.map(([m, icn]) =>
    `<button class="sicon ${S.timer.len === m ? "on" : ""}" data-preset="${m}"><span class="circle glass sm">${ic(icn)}</span><small>${m} min</small></button>`).join("");
}
function tick() {
  if (S.timer.endAt && Date.now() >= S.timer.endAt) finishFocus();
  if (!$("#view-jornada").hidden) renderTimer();
}
async function keepAwake(on) {
  try {
    if (on && "wakeLock" in navigator) wakeLock = await navigator.wakeLock.request("screen");
    else if (!on && wakeLock) { await wakeLock.release(); wakeLock = null; }
  } catch (e) { /* sem suporte */ }
}
function finishFocus() {
  const mins = S.timer.len || FOCUS_MIN;
  S.timer = { endAt: null, remaining: mins * 60000, len: mins };
  day().focusMin += mins;
  S.game.focusSessions++;
  save();
  keepAwake(false);
  beep(false);
  toast(`Bloco de ${mins} min concluído! Descanse um pouco.`);
  autoMission("focus", true);
  renderJornada();
}
function toggleTimer() {
  if (S.timer.endAt) { S.timer.remaining = timerLeft(); S.timer.endAt = null; keepAwake(false); }
  else {
    S.timer.endAt = Date.now() + S.timer.remaining;
    keepAwake(true);
    if (audioCtx == null) try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) {}
  }
  save(); renderTimer();
}

// =====================================================================
//  FINANÇAS
// =====================================================================
let curMonth = monthKey();
let selCat = "alimentacao";
const catOf = (id) => EXPENSE_CATS.find((c) => c.id === id) || EXPENSE_CATS[EXPENSE_CATS.length - 1];
const DONUT_COLORS = ["#a6f23a", "#22b83a", "#4f8f14", "#c8ff7a", "#167a2a", "#7fd11b", "#2f5a0c", "#d9ffa8", "#0f5a1e", "#5c6b55"];

function spentOn(k) { return S.fin.expenses.filter((e) => e.date === k).reduce((a, b) => a + b.amount, 0); }

function renderFin() {
  renderHeader();
  const mk = curMonth, now = monthKey(), isNow = mk === now;
  const [y, m] = mk.split("-").map(Number);
  $("#monthLabel").textContent = `${MONTHS[m - 1]} ${y}`;
  const s = monthSummary(mk);
  const goal = S.fin.goal || 0;
  const out = s.fixedTotal + s.spent;

  // visão geral
  $("#sIncome").textContent = moneyR(s.income);
  $("#sOut").textContent = moneyR(out);
  $("#sOutPct").textContent = s.income ? `${Math.round((out / s.income) * 100)}% da renda` : "—";
  $("#balance").textContent = moneyR(s.balance);
  $("#balance").classList.toggle("neg", s.balance < 0);
  const tag = $("#balTag");
  tag.textContent = s.balance < 0 ? "Negativo" : goal && s.balance >= goal ? "Ótimo" : s.balance > 0 ? "Bom" : "—";
  tag.className = s.balance < 0 ? "neg" : "lime";
  $("#finMsg").textContent = !s.income ? "Comece cadastrando seu salário em Renda do Mês. 👇"
    : s.balance < 0 ? "Atenção: os gastos passaram da renda. Hora de ajustar com sabedoria."
    : goal && s.balance >= goal ? "Você está indo muito bem! Continue fiel na mordomia."
    : goal ? `Bom caminho! Faltam ${money(goal - s.balance)} para bater a meta.`
    : "Defina uma meta de economia para acompanhar seu progresso.";

  // anéis
  const p1 = s.income ? out / s.income : 0;
  const p2 = goal ? Math.max(0, s.balance) / goal : 0;
  const p3 = s.fixed.length ? s.paid.size / s.fixed.length : 0;
  const ring = (r, p, col) => { const c = 2 * Math.PI * r; const q = Math.max(0, Math.min(1, p)); return `<circle cx="95" cy="95" r="${r}" fill="none" stroke="#1b2216" stroke-width="13"/><circle cx="95" cy="95" r="${r}" fill="none" stroke="${col}" stroke-width="13" stroke-linecap="round" stroke-dasharray="${c * q} ${c}"/>`; };
  $("#rings").innerHTML = `<svg viewBox="0 0 190 190">${ring(82, p1, p1 > 1 ? "#ff5d5d" : "#a6f23a")}${ring(64, p2, "#7fd11b")}${ring(46, p3, "#3f8a14")}</svg><span class="rc">${ic("wallet")}</span>`;
  $("#r1v").textContent = moneyR(out); $("#r1s").textContent = `/ ${moneyR(s.income)}`;
  $("#r2v").textContent = moneyR(Math.max(0, s.balance)); $("#r2s").textContent = goal ? `/ ${moneyR(goal)}` : "sem meta";
  $("#r3v").textContent = s.paid.size; $("#r3s").textContent = `/ ${s.fixed.length} pagas`;
  if (isNow && s.income > 0) {
    const left = daysInMonth(mk) - new Date().getDate() + 1;
    const free = s.balance - goal;
    $("#dailyAllow").innerHTML = free > 0 ? `Para bater a meta, você pode gastar até <b>${money(free / left)}</b> por dia nos próximos ${left} dias.` : `Para bater a meta, evite novos gastos este mês.`;
  } else $("#dailyAllow").innerHTML = "";

  // donut por categoria
  const byCat = {};
  for (const e of s.expenses) byCat[e.cat] = (byCat[e.cat] || 0) + e.amount;
  const rows = Object.entries(byCat).sort((a, b) => b[1] - a[1]);
  const R = 76, C = 2 * Math.PI * R;
  let acc = 0;
  const segs = rows.map(([cid, v], i) => {
    const len = (v / s.spent) * C;
    const gap = rows.length > 1 ? 3 : 0;
    const seg = `<circle cx="100" cy="100" r="${R}" fill="none" stroke="${DONUT_COLORS[i % DONUT_COLORS.length]}" stroke-width="34" stroke-dasharray="${Math.max(0, len - gap)} ${C}" stroke-dashoffset="${-acc}"/>`;
    acc += len; return seg;
  }).join("");
  $("#donut").innerHTML = `<svg viewBox="0 0 200 200"><circle cx="100" cy="100" r="${R}" fill="none" stroke="#1b2216" stroke-width="34"/>${segs}</svg><div class="dc"><b>${moneyR(s.spent)}</b><small>gastos</small></div>`;
  $("#legend").innerHTML = rows.length ? rows.slice(0, 3).map(([cid, v], i) =>
    `<div><i style="background:${DONUT_COLORS[i]}"></i><b>${Math.round((v / s.spent) * 100)}%</b><small>${esc(catOf(cid).name)}</small><small>${moneyR(v)}</small></div>`).join("")
    : `<div class="empty" style="grid-column:1/-1">Sem gastos registrados neste mês.</div>`;

  // barras: últimos 7 dias (ou fim do mês visto)
  const endD = isNow ? new Date() : new Date(y, m, 0);
  const days7 = [];
  for (let i = 6; i >= 0; i--) { const t = new Date(endD); t.setDate(t.getDate() - i); days7.push(t); }
  const vals = days7.map((t) => spentOn(dateKey(t)));
  const vmax = Math.max(...vals, 1);
  const niceMax = (() => { const p = Math.pow(10, Math.floor(Math.log10(vmax))); return Math.ceil(vmax / p) * p; })();
  const sum7 = vals.reduce((a, b) => a + b, 0);
  $("#wkAvg").textContent = moneyR(sum7 / 7);
  const todayV = vals[6];
  $("#wkToday").textContent = moneyR(todayV);
  const allow = (() => { if (!isNow || !s.income) return null; const left = daysInMonth(mk) - new Date().getDate() + 1; return (s.balance + todayV - goal) / left; })();
  $("#wkTag").textContent = allow == null ? "" : todayV <= allow ? "● Dentro do limite" : "● Acima do limite";
  $("#wkTag").className = allow != null && todayV > allow ? "neg" : "lime";
  const tipIdx = isNow ? 6 : vals.indexOf(Math.max(...vals));
  $("#bars").innerHTML = `<div class="yax"><span>${Math.round(niceMax)}</span><span>${Math.round(niceMax / 2)}</span><span>0</span></div>` +
    days7.map((t, i) => `<div class="bcol ${i === 6 && isNow ? "today" : ""}">
      ${i === tipIdx && vals[i] > 0 ? `<span class="btip" style="bottom:${(vals[i] / niceMax) * 140 + 26}px;top:auto;transform:none">${moneyR(vals[i])}</span>` : ""}
      <div class="btrack"><div class="bfill" style="height:${Math.max(4, (vals[i] / niceMax) * 100)}%;${vals[i] ? "" : "opacity:.25"}"></div></div><small>${WD_SHORT[t.getDay()]}</small></div>`).join("");

  // linha: sobra ao longo do mês
  const lastDay = isNow ? new Date().getDate() : daysInMonth(mk);
  const pts = [];
  let cum = 0;
  for (let dd = 1; dd <= lastDay; dd++) { cum += spentOn(`${mk}-${pad(dd)}`); pts.push(s.income - s.fixedTotal - cum); }
  $("#lnNow").textContent = moneyR(pts[pts.length - 1] ?? s.balance);
  const dailyVals = []; for (let dd = 1; dd <= lastDay; dd++) dailyVals.push(spentOn(`${mk}-${pad(dd)}`));
  const nz = dailyVals.filter((v) => v > 0);
  $("#lnRange").innerHTML = nz.length ? `<b>${moneyR(Math.min(...nz))}–${moneyR(Math.max(...nz))}</b><br>faixa diária` : "";
  // comparação com o mês anterior no mesmo período
  const pm = addMonths(mk, -1);
  let prevSpent = 0; for (let dd = 1; dd <= lastDay; dd++) prevSpent += spentOn(`${pm}-${pad(dd)}`);
  if (prevSpent > 0) {
    const ch = ((s.spent - prevSpent) / prevSpent) * 100;
    $("#lnTrend").innerHTML = `<b class="${ch > 0 ? "neg" : ""}">${ch > 0 ? "↑" : "↓"} ${Math.abs(Math.round(ch))}%</b><br>gastos vs mês<br>passado`;
  } else $("#lnTrend").innerHTML = `<span class="muted">Sem dados do<br>mês anterior</span>`;
  $("#lineChart").innerHTML = lineSvg(pts, lastDay);

  // próximas contas
  const today = new Date().getDate();
  const fixedSorted = [...s.fixed].sort((a, b) => (s.paid.has(a.id) - s.paid.has(b.id)) || a.day - b.day);
  const dueLabel = (f) => {
    if (s.paid.has(f.id)) return "Paga";
    if (!isNow) return `todo dia ${f.day}`;
    if (f.day === today) return "Hoje";
    if (f.day === today + 1) return "Amanhã";
    if (f.day < today) return `<span class="neg">Atrasada</span>`;
    const dt = new Date(y, m - 1, Math.min(f.day, daysInMonth(mk)));
    return `${WD_SHORT[dt.getDay()]}, ${pad(dt.getDate())}/${pad(m)}`;
  };
  $("#fixedList").innerHTML = fixedSorted.length ? fixedSorted.map((f) => {
    const paid = s.paid.has(f.id);
    return `<div class="uitem ${paid ? "paid" : ""}">
      <button class="paybtn ${paid ? "on" : ""}" data-fix-pay="${f.id}" aria-label="Marcar como paga">${ic("check")}</button>
      <div class="uthumb">${catOf(f.cat).icon}</div>
      <div class="utxt"><b>${esc(f.name)}</b><small>${money(f.amount)} · <span class="due">${dueLabel(f)}</span></small></div>
      <button class="ibtn" data-fix-edit="${f.id}" aria-label="Editar">${ic("edit")}</button>
      <button class="ibtn" data-fix-del="${f.id}" aria-label="Remover">${ic("trash")}</button></div>`;
  }).join("") + `<div class="total-row"><span>A pagar</span><b>${money(s.toPay)}</b></div>`
    : `<div class="empty">Cadastre aluguel, luz, internet, celular, academia…</div>`;

  // sequência de registro
  const hasRec = (k) => S.fin.expenses.some((e) => e.date === k) || !!(peekDay(k) && peekDay(k).done["fin_registro"]);
  let streak = 0; const cur = new Date();
  if (!hasRec(dateKey(cur))) cur.setDate(cur.getDate() - 1);
  while (hasRec(dateKey(cur))) { streak++; cur.setDate(cur.getDate() - 1); }
  $("#finStreak").textContent = streak;
  const monday = new Date(); monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  $("#stDays").innerHTML = ["S", "T", "Q", "Q", "S", "S", "D"].map((l, i) => {
    const t = new Date(monday); t.setDate(monday.getDate() + i);
    return `<div>${l}<i class="${hasRec(dateKey(t)) ? "on" : ""}"></i></div>`;
  }).join("");

  // formulário
  $("#expCats").innerHTML = EXPENSE_CATS.map((c) => `<button type="button" class="cat ${c.id === selCat ? "on" : ""}" data-cat="${c.id}">${c.icon} ${c.name}</button>`).join("");
  if (!$("#expDate").value) $("#expDate").value = dateKey();

  // renda
  $("#incomeList").innerHTML = s.incomes.length ? s.incomes.map((i) => `
    <div class="uitem"><div class="uthumb">💵</div><div class="utxt"><b>${esc(i.desc)}</b><small>${i.recurring ? "Todo mês" : "Só este mês"}</small></div>
    <div class="uright"><b class="lime">${money(i.amount)}</b></div>
    <button class="ibtn" data-inc-edit="${i.id}" aria-label="Editar">${ic("edit")}</button><button class="ibtn" data-inc-del="${i.id}" aria-label="Remover">${ic("trash")}</button></div>`).join("")
    : `<div class="empty">Nenhuma renda neste mês. Cadastre seu salário.</div>`;

  // gastos do mês
  const byDay = {};
  for (const e of s.expenses) (byDay[e.date] = byDay[e.date] || []).push(e);
  const dkeys = Object.keys(byDay).sort().reverse();
  $("#expList").innerHTML = dkeys.length ? dkeys.map((k) => {
    const dt = new Date(k + "T12:00:00");
    const tot = byDay[k].reduce((a, b) => a + b.amount, 0);
    return `<div class="dayhead"><span>${WEEKDAYS[dt.getDay()]}, ${dt.getDate()}/${pad(dt.getMonth() + 1)}</span><span>${money(tot)}</span></div>` +
      byDay[k].map((e) => { const c = catOf(e.cat); return `<div class="uitem"><div class="uthumb">${c.icon}</div><div class="utxt"><b>${esc(e.desc || c.name)}</b><small>${esc(c.name)}</small></div>
        <div class="uright"><b>${money(e.amount)}</b></div><button class="ibtn" data-exp-del="${e.id}" aria-label="Remover">${ic("trash")}</button></div>`; }).join("");
  }).join("") : `<div class="empty">Nada por aqui ainda.</div>`;

  $("#finTip").textContent = FIN_TIPS[dayOfYear() % FIN_TIPS.length];
}

function lineSvg(pts, lastDay) {
  const W = 320, H = 170, L = 34, B = 22, T = 10, Rr = 10;
  if (!pts.length) return "";
  let mn = Math.min(...pts, 0), mx = Math.max(...pts, 1);
  if (mx === mn) mx = mn + 1;
  const padv = (mx - mn) * 0.12; mn -= padv; mx += padv;
  const n = Math.max(pts.length, 2);
  const X = (i) => L + (i / (n - 1)) * (W - L - Rr);
  const Y = (v) => T + (1 - (v - mn) / (mx - mn)) * (H - T - B);
  const P = pts.map((v, i) => [X(i), Y(v)]);
  if (P.length === 1) P.push([X(1), P[0][1]]);
  let d = `M${P[0][0]},${P[0][1]}`;
  for (let i = 1; i < P.length; i++) { const [x0, y0] = P[i - 1], [x1, y1] = P[i]; const cx = (x0 + x1) / 2; d += ` C${cx},${y0} ${cx},${y1} ${x1},${y1}`; }
  const area = `${d} L${P[P.length - 1][0]},${H - B} L${P[0][0]},${H - B} Z`;
  const yt = [mx - padv, (mx + mn) / 2, mn + padv];
  const grid = yt.map((v) => `<line x1="${L}" x2="${W - Rr}" y1="${Y(v)}" y2="${Y(v)}" stroke="#1f241e" stroke-dasharray="3 4"/><text x="0" y="${Y(v) + 3}">${Math.abs(v) >= 1000 ? (v / 1000).toFixed(1).replace(".", ",") + "k" : Math.round(v)}</text>`).join("");
  const step = Math.max(1, Math.ceil(pts.length / 6));
  const dots = P.map(([x, y], i) => (i % step === 0 && i < pts.length - 1) ? `<circle cx="${x}" cy="${y}" r="3.5" fill="#a6f23a"/>` : "").join("");
  const [lx, ly] = P[pts.length - 1] || P[0];
  const xl = []; for (let i = 0; i < pts.length; i += Math.max(1, Math.ceil(pts.length / 5))) xl.push(`<text x="${X(i) - 4}" y="${H - 4}">${i + 1}</text>`);
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
    <defs><linearGradient id="lg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#a6f23a" stop-opacity=".28"/><stop offset="1" stop-color="#a6f23a" stop-opacity="0"/></linearGradient></defs>
    ${grid}<path d="${area}" fill="url(#lg)"/><path d="${d}" fill="none" stroke="#a6f23a" stroke-width="2.5" style="filter:drop-shadow(0 0 6px rgba(166,242,58,.6))"/>
    ${dots}<circle cx="${lx}" cy="${ly}" r="9" fill="#a6f23a" opacity=".25"/><circle cx="${lx}" cy="${ly}" r="5.5" fill="#a6f23a"/>${xl.join("")}</svg>`;
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
function missionDialog() {
  openDialog("Nova missão diária", [
    { name: "name", label: "Missão", required: true, placeholder: "ex: Jejum até meio-dia" },
    { name: "p", label: "Atributo", type: "select", value: "fe", options: Object.entries(PILLARS).map(([k, P]) => [k, P.name]) },
    { name: "xp", label: "XP", type: "select", value: "10", options: [["5", "5 · fácil"], ["10", "10 · médio"], ["15", "15 · difícil"], ["20", "20 · desafio"]] },
    { name: "hint", label: "Detalhe (opcional)", placeholder: "ex: só água e café" },
  ], (v) => {
    if (!v.name.trim()) return;
    S.game.custom.push({ id: "c_" + uid(), p: v.p, xp: parseInt(v.xp), name: v.name.trim().slice(0, 50), hint: v.hint.trim().slice(0, 80) });
    save(); renderSettings(); renderJornada(); toast("Missão criada");
  });
}

// =====================================================================
//  AJUSTES
// =====================================================================
function renderSettings() {
  if (document.activeElement !== $("#nameInput")) $("#nameInput").value = S.name || "";
  $("#pinInput").placeholder = S.pin ? "PIN ativo · digite um novo ou deixe vazio" : "4 a 8 números";
  $("#welcomeToggle").checked = !S.remember;
  const off = new Set(S.game.disabled);
  $("#misList").innerHTML = allMissionDefs().map((m) => {
    const custom = S.game.custom.some((c) => c.id === m.id);
    return `<div class="uitem"><label class="switch"><input type="checkbox" data-mis-toggle="${esc(m.id)}" ${off.has(m.id) ? "" : "checked"}><span></span></label>
      <div class="utxt"><b>${esc(m.name)}</b><small>${PILLARS[m.p].name} · +${m.xp} XP${m.auto ? " · automática" : ""}</small></div>
      ${custom ? `<button class="ibtn" data-mis-del="${esc(m.id)}" aria-label="Remover">${ic("trash")}</button>` : ""}</div>`;
  }).join("");
}

// =====================================================================
//  BOAS-VINDAS / PIN
// =====================================================================
async function hashPin(pin) {
  try {
    const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("proposito:" + pin));
    return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
  } catch (e) { return "p:" + btoa(pin); }
}
function showWelcome() {
  $("#wName").value = S.name || "";
  $("#wPin").value = "";
  $("#wPin").placeholder = S.pin ? "PIN" : "Criar PIN (opcional)";
  $("#wRemember").checked = !!S.remember;
  $("#wFoot").innerHTML = S.pin ? "Protegido por PIN 🔒" : `Não tem PIN? <button type="button" id="wCreate">Criar agora</button>`;
  $("#welcome").hidden = false;
  document.body.style.overflow = "hidden";
}
function hideWelcome() { $("#welcome").hidden = true; document.body.style.overflow = ""; }

// =====================================================================
//  NAVEGAÇÃO
// =====================================================================
function showView(v) {
  document.querySelectorAll(".view").forEach((el) => (el.hidden = el.id !== "view-" + v));
  document.querySelectorAll(".tabbar button").forEach((b) => b.classList.toggle("active", b.dataset.view === v));
  document.body.className = v === "jornada" ? "t-fit" : "t-fin";
  document.querySelector('meta[name="theme-color"]').content = v === "jornada" ? "#0b1736" : "#070807";
  try { localStorage.setItem("proposito.tab", v); } catch (e) {}
  if (v === "financas") renderFin();
  if (v === "ajustes") renderSettings();
  if (v === "jornada") renderJornada();
  window.scrollTo(0, 0);
}

// =====================================================================
//  EVENTOS
// =====================================================================
function bind() {
  document.querySelectorAll(".tabbar button").forEach((b) => b.addEventListener("click", () => showView(b.dataset.view)));

  // jornada
  $("#missions").addEventListener("click", (e) => {
    const b = e.target.closest("[data-mid]"); if (!b) return;
    setMission(b.dataset.mid, !day().done[b.dataset.mid]);
  });
  $("#activeDo").addEventListener("click", (e) => {
    const id = e.currentTarget.dataset.mid;
    if (id) setMission(id, true); else toast("Todas as missões de hoje concluídas! 🙌");
  });
  $("#statIcons").addEventListener("click", (e) => {
    const p = e.target.closest("[data-pillar]")?.dataset.pillar; if (!p) return;
    const xp = pillarXp()[p];
    toast(`${PILLARS[p].name}: nível ${pillarLevel(xp)} · ${xp} XP`);
  });
  $("#misAddQuick").addEventListener("click", missionDialog);
  const toTop = () => window.scrollTo({ top: 0, behavior: "smooth" });
  $("#homeBtn").addEventListener("click", () => { if (window.scrollY < 50) showWelcome(); else toTop(); });
  $("#homeBtn2").addEventListener("click", toTop);
  $("#backBtn").addEventListener("click", toTop);
  $("#weekToggle").addEventListener("click", () => {
    const box = $("#weekBox"); box.hidden = !box.hidden;
    $("#weekToggle").textContent = box.hidden ? "Ver Tudo" : "Ocultar";
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

  $("#timerBtn").addEventListener("click", toggleTimer);
  $("#timerBtn").addEventListener("keydown", (e) => { if (e.key === " " || e.key === "Enter") { e.preventDefault(); toggleTimer(); } });
  $("#timerReset").addEventListener("click", () => { S.timer = { endAt: null, remaining: timerLen(), len: S.timer.len || FOCUS_MIN }; keepAwake(false); save(); renderTimer(); });
  $("#focusPresets").addEventListener("click", (e) => {
    const m = parseInt(e.target.closest("[data-preset]")?.dataset.preset); if (!m) return;
    if (S.timer.endAt) return toast("Pause o timer para mudar a duração");
    S.timer = { endAt: null, remaining: m * 60000, len: m }; save(); renderTimer();
  });
  $("#fullBtn").addEventListener("click", () => {
    if (document.fullscreenElement) document.exitFullscreen?.();
    else document.documentElement.requestFullscreen?.().catch(() => {});
  });

  $("#bibleRead").addEventListener("click", () => {
    if (S.game.bible.pos >= 1189) return toast("Você já concluiu a Bíblia! Recomece pelo seletor.");
    const [bk, ch] = bibleAt(S.game.bible.pos);
    S.game.bible.pos++; S.game.bible.read++;
    save();
    toast(`${bk} ${ch} lido!`);
    if (!day().done["fe_biblia"]) autoMission("bible", true); else afterProgress();
  });
  $("#bibleBook").innerHTML = BIBLE.map(([n], i) => `<option value="${i}">${n}</option>`).join("");
  $("#bibleSet").addEventListener("click", () => {
    S.game.bible.pos = bibleIndex(parseInt($("#bibleBook").value), parseInt($("#bibleChap").value) || 1);
    save(); renderJornada(); toast("Ponto de leitura atualizado");
  });

  let jt;
  const saveJournal = () => {
    const d = day();
    d.gratitude = $("#gratitude").value; d.prayer = $("#prayer").value;
    save();
    $("#journalSaved").textContent = "Salvo ✓";
    const has = d.gratitude.trim().length >= 3;
    if (has !== !!d.done["fe_gratidao"]) autoMission("gratitude", has);
  };
  ["#gratitude", "#prayer"].forEach((s) => $(s).addEventListener("input", () => {
    $("#journalSaved").textContent = "…"; clearTimeout(jt); jt = setTimeout(saveJournal, 700);
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
    curMonth = date.slice(0, 7);
    if (date === dateKey()) autoMission("expense", true); else afterProgress();
    renderFin();
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
      endRecurring(S.fin.fixed, it.id, curMonth); save(); renderFin();
    }
    if (ds.expDel) {
      if (!confirm("Remover este gasto?")) return;
      S.fin.expenses = S.fin.expenses.filter((x) => x.id !== ds.expDel); save(); renderFin();
    }
  });

  // ajustes
  $("#nameInput").addEventListener("input", (e) => { S.name = e.target.value.trim().slice(0, 30); save(); renderHeader(); });
  $("#pinSave").addEventListener("click", async () => {
    const v = $("#pinInput").value.trim();
    if (!v) {
      if (S.pin && confirm("Remover o PIN da tela de entrada?")) { S.pin = ""; save(); toast("PIN removido"); }
    } else if (!/^\d{4,8}$/.test(v)) return toast("O PIN deve ter de 4 a 8 números");
    else { S.pin = await hashPin(v); save(); toast("PIN salvo 🔒"); }
    $("#pinInput").value = ""; renderSettings();
  });
  $("#welcomeToggle").addEventListener("change", (e) => { S.remember = !e.target.checked; save(); });
  $("#misList").addEventListener("change", (e) => {
    const id = e.target.dataset.misToggle; if (!id) return;
    S.game.disabled = S.game.disabled.filter((x) => x !== id);
    if (!e.target.checked) S.game.disabled.push(id);
    save();
  });
  $("#misList").addEventListener("click", (e) => {
    const id = e.target.closest("[data-mis-del]")?.dataset.misDel; if (!id) return;
    if (!confirm("Remover esta missão? O XP já ganho com ela continua.")) return;
    S.game.custom = S.game.custom.filter((m) => m.id !== id); save(); renderSettings();
  });
  $("#misAdd").addEventListener("click", missionDialog);

  $("#exportBtn").addEventListener("click", () => {
    const blob = new Blob([JSON.stringify(S, null, 2)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob); a.download = `proposito-backup-${dateKey()}.json`;
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

  // boas-vindas
  $("#wEye").addEventListener("click", () => {
    const inp = $("#wPin"), show = inp.type === "password";
    inp.type = show ? "text" : "password";
    $("#wEye").innerHTML = ic(show ? "eye" : "eyeOff");
  });
  $("#wForgot").addEventListener("click", () => toast(S.pin ? "Restaure um backup ou limpe os dados do site para redefinir o PIN." : "Você ainda não criou um PIN."));
  $("#wFoot").addEventListener("click", (e) => { if (e.target.id === "wCreate") { $("#wPin").focus(); toast("Digite de 4 a 8 números no campo PIN"); } });
  $("#welcomeForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const name = $("#wName").value.trim(), pin = $("#wPin").value.trim();
    if (S.pin) {
      if ((await hashPin(pin)) !== S.pin) {
        const f = $("#welcomeForm"); f.classList.remove("shake"); void f.offsetWidth; f.classList.add("shake");
        return toast("PIN incorreto");
      }
    } else if (pin) {
      if (!/^\d{4,8}$/.test(pin)) return toast("O PIN deve ter de 4 a 8 números");
      S.pin = await hashPin(pin); toast("PIN criado 🔒");
    }
    if (name) S.name = name.slice(0, 30);
    S.remember = $("#wRemember").checked;
    save(); hideWelcome(); renderAll();
  });

  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) { tick(); renderAll(); if (S.timer.endAt) keepAwake(true); }
  });
}

function renderAll() {
  renderHeader();
  if (!$("#view-jornada").hidden) renderJornada();
  if (!$("#view-financas").hidden) renderFin();
  if (!$("#view-ajustes").hidden) renderSettings();
}

// =====================================================================
//  INÍCIO
// =====================================================================
if (!S.timer.len) S.timer.len = FOCUS_MIN;
hydrateIcons();
bind();
tick();
timerInt = setInterval(tick, 1000);
let startTab = "jornada";
try { startTab = localStorage.getItem("proposito.tab") || "jornada"; } catch (e) {}
showView(["jornada", "financas", "ajustes"].includes(startTab) ? startTab : "jornada");
if (S.pin || !S.remember) showWelcome();

if ("serviceWorker" in navigator && location.protocol !== "file:") {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}
