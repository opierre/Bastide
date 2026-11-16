/* Bastide redesign proposal — panel renderers. All figures are invented (persona of docs/design, May 2026). */
const I = (n, c = '') => `<i data-lucide="${n}" class="${c}"></i>`;
let MARK = '';
const CATS = { Logement: ['c1', 'house'], Alimentation: ['c2', 'soup'], Transport: ['c3', 'car'], Abonnements: ['c4', 'refresh-cw'], Loisirs: ['c5', 'star'], Santé: ['c6', 'cross'], Autres: ['c0', 'coins'], Revenus: ['pos', 'arrow-up'] };
const cat = (n, sub) => n ? `<span class="cat"><span class="dot" style="--c:var(--${CATS[n][0]})"></span>${n}${sub ? ` <span class="t3">› ${sub}</span>` : ''}</span>` : `<span class="cat none">Non catégorisé</span>`;
const mg = (t, c = '') => `<span class="mg ${c}">${t}</span>`;
const amt = s => `<span class="${s.startsWith('+') ? 'pos' : s.startsWith('−') ? 'neg' : ''}">${s}</span>`;
const meter = (v, m, l = '', c = '') => `<div class="meter ${c}" style="--v:${v}%${m != null ? `;--m:${m}%` : ''}"><i></i>${m != null ? `<b data-l="${l}"></b>` : ''}</div>`;

const NAV = [
  ['Vue d’ensemble', [['dashboard', 'layout-dashboard', 'Tableau de bord'], ['accounts', 'wallet', 'Comptes'], ['transactions', 'arrow-left-right', 'Transactions', '12']]],
  ['Gestion', [['imports', 'download', 'Imports'], ['categories', 'tags', 'Catégories'], ['subscriptions', 'repeat', 'Abonnements'], ['goals', 'flag', 'Objectifs']]],
  ['Patrimoine', [['loans', 'house', 'Crédits'], ['investments', 'chart-line', 'Placements'], ['simulator', 'calculator', 'Simulateur'], ['networth', 'chart-pie', 'Synthèse']]],
];
function shell(active, title, actions, body, o = {}) {
  const nav = NAV.map(([g, items]) => `<h6>${g}</h6>` + items.map(([id, ic, l, n]) =>
    `<div class="nav ${id === active ? 'on' : ''}">${I(ic)}${l}${n ? `<span class="n">${n}</span>` : ''}</div>`).join('')).join('');
  return `<aside class="rail"><div class="brand">${MARK}Bastide</div>${nav}<div class="grow"></div>
    <div class="nav ${active === 'settings' ? 'on' : ''}">${I('settings')}Paramètres</div>
    <div class="foot"><div class="me"><span class="av">CD</span>Camille Dubois<span class="sp"></span>${I('chevrons-up-down', 's14 t3')}</div>
    <div class="local">${I('lock', 's14')}Données locales</div></div></aside>
  <div class="main"><header class="top">${o.crumb ? `<span class="crumb">${o.crumb} /</span>` : ''}<h1>${title}</h1><span class="sp"></span>${actions || ''}</header>
  <div class="body ${o.flush ? 'flush' : ''}">${body}</div></div>`;
}
const MONTH = `<span class="sel">${I('chevron-left', 's14')}Mai 2026${I('chevron-right', 's14')}</span>`;
const SEARCH = `<span class="inp search">${I('search', 's14')}Rechercher<kbd>Ctrl K</kbd></span>`;

/* ── charts (inline SVG, colours from tokens) ── */
function plot(w, h, min, max, ticks) {
  const L = 52, B = 22, T = 6, y = v => T + (h - T - B) * (1 - (v - min) / (max - min));
  const grid = ticks.map(([v, l]) => `<line x1="${L}" x2="${w}" y1="${y(v)}" y2="${y(v)}" stroke="var(--line)" ${v === 0 && min < 0 ? 'stroke="var(--line2)"' : ''}/><text class="ax" x="${L - 8}" y="${y(v) + 4}" text-anchor="end">${l}</text>`).join('');
  return { L, B, y, grid, pw: w - L };
}
function bars(vals, labels, o) {
  const { w = 600, h = 190, min, max, ticks, open = true, bw = 18 } = o, p = plot(w, h, min, max, ticks), step = p.pw / vals.length;
  const m = vals.map((v, i) => {
    const x = p.L + step * i + (step - bw) / 2, y0 = p.y(0), y1 = p.y(v), last = open && i === vals.length - 1, c = v >= 0 ? 'var(--pos)' : 'var(--neg)';
    return `<rect x="${x}" y="${Math.min(y0, y1)}" width="${bw}" height="${Math.abs(y1 - y0)}" rx="3" ${last ? (TEX ? `fill="url(#hx${v >= 0 ? 'p' : 'n'})" stroke="${c}"` : `fill="none" stroke="${c}" stroke-dasharray="4 3"`) : `fill="${c}"`}><title>${labels[i]} : ${v} €</title></rect>
    <text class="ax" x="${x + bw / 2}" y="${h - 6}" text-anchor="middle">${labels[i]}</text>`;
  }).join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="100%" role="img" aria-label="${o.label}"><defs>${[['p', 'var(--pos)'], ['n', 'var(--neg)']].map(([k, c]) => `<pattern id="hx${k}" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="1.5" height="5" fill="${c}"/></pattern>`).join('')}</defs>${p.grid}${m}</svg>`;
}
function line(vals, labels, o) {
  const { w = 600, h = 190, min, max, ticks, step = false } = o, p = plot(w, h, min, max, ticks), dx = (p.pw - 12) / (vals.length - 1);
  const pt = vals.map((v, i) => [p.L + 6 + dx * i, p.y(v)]);
  let d = `M${pt[0]}`; for (let i = 1; i < pt.length; i++) d += step ? `H${pt[i][0]}V${pt[i][1]}` : `L${pt[i]}`;
  const lx = pt[pt.length - 1];
  const xs = labels.map((l, i) => l ? `<text class="ax" x="${pt[i][0]}" y="${h - 6}" text-anchor="${i === labels.length - 1 ? 'end' : 'middle'}">${l}</text>` : '').join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="100%" role="img" aria-label="${o.label}">${p.grid}
    <path d="${d}V${h - p.B}H${pt[0][0]}Z" fill="var(--ac)" opacity=".1"/><path d="${d}" fill="none" stroke="var(--ac)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
    <circle cx="${lx[0]}" cy="${lx[1]}" r="4" fill="var(--ac)" stroke="var(--bg)" stroke-width="2"/>${o.extra ? o.extra(p, pt) : ''}${xs}</svg>`;
}
function stacked(a, b, labels, o) {
  const { w = 700, h = 180, max, ticks } = o, p = plot(w, h, 0, max, ticks), step = p.pw / a.length, bw = Math.min(16, step - 4);
  const m = a.map((v, i) => {
    const x = p.L + step * i + (step - bw) / 2, y1 = p.y(v), y2 = p.y(v + b[i]);
    return `<rect x="${x}" y="${y1}" width="${bw}" height="${p.y(0) - y1}" fill="var(--ac)"/><rect x="${x}" y="${y2}" width="${bw}" height="${y1 - y2 - 2}" rx="2" fill="var(--tx3)"/>${labels[i] ? `<text class="ax" x="${x + bw / 2}" y="${h - 6}" text-anchor="middle">${labels[i]}</text>` : ''}`;
  }).join('');
  return `<svg viewBox="0 0 ${w} ${h}" width="100%" role="img" aria-label="${o.label}">${p.grid}${m}</svg>`;
}
let TEX = false;
const M12 = ['juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.', 'janv.', 'févr.', 'mars', 'avr.', 'mai'];
const SAV = [310, 420, -85, 265, 390, 180, 95, 455, -118, 540, 737, 636];
const savChart = (w, h) => bars(SAV, M12, { w, h, min: -200, max: 800, ticks: [[800, '800 €'], [400, '400 €'], [0, '0'],], label: 'Épargne mensuelle sur 12 mois' });

/* ── shared fragments ── */
const SPEND = [['Logement', '950,00 €', '42,9 %', 100], ['Alimentation', '486,20 €', '22,0 %', 51], ['Autres', '236,55 €', '10,7 %', 25], ['Transport', '214,90 €', '9,7 %', 23], ['Loisirs', '189,45 €', '8,6 %', 20], ['Abonnements', '74,95 €', '3,4 %', 8], ['Santé', '62,30 €', '2,8 %', 7]];
const spendBars = () => `<table>${SPEND.map(([n, a, p, w]) => `<tr><td style="width:130px;border:0;height:30px">${cat(n)}</td><td style="border:0"><div style="height:6px;border-radius:3px;width:${w}%;background:var(--${CATS[n][0]})"></div></td><td class="c" style="border:0;width:90px">${a}</td><td class="n t3" style="border:0;width:56px">${p}</td></tr>`).join('')}</table>`;
const TX = [
  ['14 mai 2026', [['CA', 'Carrefour', 'BNP Compte courant', 'Alimentation', 'Courses', '−86,42 €'], ['BL', 'Boulangerie Lucas', 'BNP Compte courant', 'Alimentation', 'Courses', '−7,80 €']]],
  ['12 mai 2026', [['?', 'CB NOVATECH SAS 12/05', 'BNP Compte courant', null, null, '−49,90 €']]],
  ['11 mai 2026', [['SC', 'SNCF Connect', 'Revolut', 'Transport', 'Transports en commun', '−47,00 €'], ['MA', 'MAIF Habitation', 'BNP Compte courant', 'Logement', 'Assurance', '−187,44 €']]],
  ['9 mai 2026', [['FM', 'Free Mobile', 'BNP Compte courant', 'Abonnements', null, '−15,99 €'], ['?', 'VIR RECU M. DUBOIS', 'BNP Compte courant', null, null, '+420,00 €']]],
  ['7 mai 2026', [['PP', 'Pharmacie du Parc', 'BNP Compte courant', 'Santé', null, '−23,60 €']]],
  ['5 mai 2026', [['RL', 'Loyer Régie Lyon', 'BNP Compte courant', 'Logement', 'Loyer', '−950,00 €']]],
  ['2 mai 2026', [['NV', 'Salaire Novatech SARL', 'BNP Compte courant', 'Revenus', 'Salaire', '+2 850,00 €']]],
];
const txRows = (days, o = {}) => days.map(([d, rows], di) => `<tr class="grp"><td colspan="4">${d}</td></tr>` + rows.map((r, ri) =>
  `<tr class="${o.sel && di === o.sel[0] && ri === o.sel[1] ? 'cur' : ''}"><td><span class="row">${mg(r[0])}<span class="el ${r[0] === '?' ? 'mono' : ''}">${r[1]}</span></span></td>${o.noAcc ? '' : `<td class="t2">${r[2]}</td>`}<td>${cat(r[3], o.noSub ? null : r[4])}</td><td class="n">${amt(r[5])}</td></tr>`).join('')).join('');
const GOALS = [['Fonds d’urgence', 'Sans échéance', '6 400,00 €', '10 000,00 €', 64], ['Apport immobilier', 'Juin 2028', '12 800,00 €', '30 000,00 €', 43], ['Voyage Japon', 'Atteint en juin 2026', '4 000,00 €', '4 000,00 €', 100], ['Nouvelle cuisine', 'Décembre 2026', '1 250,00 €', '8 000,00 €', 16]];
const reading = () => `<div class="row" style="gap:40px;align-items:flex-end">
  <div class="col" style="gap:8px;width:300px"><span class="t2 sm">Taux d’épargne</span><span class="fig xl">22,3 %</span>
    <div style="padding-top:18px">${meter(55.75, 50, 'objectif 20 %')}</div>
    <span class="st pos">${I('check')}<span>Objectif atteint</span><span class="t2">· +1,9 pt depuis avril</span></span></div>
  <span class="vr"></span>
  ${[['Revenus', '+2 850,00 €', 'trending-up', '2,1 %', 'pos', ''], ['Dépenses', '−2 214,35 €', 'trending-up', '4,8 %', 'neg', ''], ['Net', '+635,65 €', 'trending-down', '6,1 %', 'neg', 'pos']].map(([l, v, ic, p, c, vc]) =>
    `<div class="col" style="gap:6px"><span class="t2 sm">${l}</span><span class="fig ${vc}">${v}</span><span class="st ${c}">${I(ic)}${p}<span class="t3">vs avril</span></span></div>`).join('<span class="vr"></span>')}</div>`;

/* ════════ Panels ════════ */
const P = {};

P.login = () => `<div class="app auth" data-shell="0"><form>
  <div class="brand" style="padding:0 0 8px;font-size:16px">${MARK}Bastide</div>
  <label class="f">Adresse e-mail<span class="inp">camille.dubois@proton.me</span></label>
  <label class="f">Mot de passe<span class="inp focus">••••••••••••<span class="sp"></span>${I('eye', 's14 t3')}</span></label>
  <span class="btn pri lg">Se connecter</span>
  <span class="row sm t2" style="justify-content:space-between"><span class="ac">Créer un compte</span><span class="ac">Mot de passe oublié</span></span>
  <div class="hr" style="margin-top:8px"></div>
  <span class="note">${I('lock', 's14')}Vos données restent sur cet ordinateur.</span></form></div>`;

P.register = () => `<div class="app auth" data-shell="0"><form>
  <div class="brand" style="padding:0 0 8px;font-size:16px">${MARK}Bastide</div>
  <label class="f">Nom affiché<span class="inp">Camille Dubois</span></label>
  <label class="f">Adresse e-mail<span class="inp">camille.dubois@proton.me</span></label>
  <label class="f">Mot de passe<span class="inp focus">••••••••••••••<span class="sp"></span>${I('eye', 's14 t3')}</span><small class="row">${I('check', 's14 pos')}14 caractères. Le minimum est de 12.</small></label>
  <div class="g2" style="gap:12px"><label class="f">Langue<span class="seg" style="justify-self:start"><span class="on">Français</span><span>English</span></span></label>
  <label class="f">Devise<span class="sel" style="height:28px">EUR, euro<span class="sp"></span>${I('chevron-down', 's14')}</span></label></div>
  <small class="xs t3">La langue se change dans les paramètres. La devise est définitive et s’applique à tous vos comptes.</small>
  <span class="btn pri lg">Créer mon compte</span>
  <span class="sm t2">Déjà un compte ? <span class="ac">Se connecter</span></span>
  <div class="hr" style="margin-top:8px"></div>
  <span class="note">${I('lock', 's14')}Vos données restent sur cet ordinateur.</span></form></div>`;

P.dashboard = () => shell('dashboard', 'Tableau de bord', MONTH + SEARCH, `
    ${reading()}<div class="hr"></div>
    <div class="g2"><div class="col" style="gap:12px"><div class="row"><span class="h">Dépenses par catégorie</span><span class="sp"></span><span class="t2">2 214,35 €</span></div>${spendBars()}</div>
      <div class="col" style="gap:12px"><div class="row"><span class="h">Épargne mensuelle</span><span class="sp"></span><span class="t2"><span class="pos">+302,50 €</span> en moyenne sur 12 mois</span></div>${savChart(620, 216)}</div></div>
    <div class="hr"></div>
    <div class="g2"><div class="col" style="gap:8px"><div class="row"><span class="h">Activité récente</span><span class="sp"></span><span class="ac sm">Toutes les transactions</span></div>
      <table>${TX.flatMap(d => d[1]).slice(0, 6).map(r => `<tr><td><span class="row">${mg(r[0])}<span class="el">${r[1]}</span></span></td><td class="t3">${r[2]}</td><td class="n">${amt(r[5])}</td></tr>`).join('')}</table></div>
      <div class="col" style="gap:8px"><div class="row"><span class="h">Objectifs</span><span class="sp"></span><span class="ac sm">Tous les objectifs</span></div>
      <table>${GOALS.slice(0, 4).map(g => `<tr><td style="width:150px">${g[0]}</td><td>${meter(g[4], null, '', g[4] >= 100 ? 'done' : '')}</td><td class="c t2" style="width:190px">${g[2]} <span class="t3">/ ${g[3]}</span></td><td class="n" style="width:44px">${g[4]} %</td></tr>`).join('')}</table></div></div>`);

P.account = () => shell('accounts', 'BNP Compte courant', `<span class="btn">Modifier</span><span class="btn">${I('ellipsis', 's14')}</span>`, `
  <div class="row" style="gap:40px;align-items:flex-end"><div class="col" style="gap:4px"><span class="t2 sm">Solde au 14 mai 2026</span><span class="fig xl pos">+3 486,12 €</span></div><span class="vr"></span>
    ${[['Entrées en mai', '+3 270,00 €'], ['Sorties en mai', '−2 657,95 €'], ['Net', '+612,05 €']].map(([l, v]) => `<div class="col" style="gap:6px"><span class="t2 sm">${l}</span><span class="fig md">${v}</span></div>`).join('')}
    <span class="sp"></span><div class="col sm t2" style="gap:4px;text-align:right"><span>BNP Paribas · compte courant</span><span>Historique depuis le 3 janv. 2025 · <span class="ac">dernier import le 14 mai</span></span></div></div>
  <div class="col" style="gap:12px"><div class="row"><span class="h">Solde en fin de mois</span><span class="sp"></span><span class="seg"><span>6 mois</span><span class="on">12 mois</span><span>Tout</span></span></div>
  ${line([1820, 2140, 1960, 2230, 2600, 2710, 2540, 2990, 2760, 2874, 2874, 3486], M12, { w: 1150, h: 190, min: 1000, max: 4000, ticks: [[4000, '4 000 €'], [2500, '2 500 €'], [1000, '1 000 €']], label: 'Solde du compte sur 12 mois' })}</div>
  <div class="col" style="gap:8px"><div class="row"><span class="h">Opérations</span><span class="sp"></span><span class="ac sm">Ouvrir dans Transactions</span></div>
  <table><tr><th>Opération</th><th>Catégorie</th><th class="c">Date</th><th class="n">Montant</th></tr>${TX.flatMap(d => d[1].filter(r => r[2].startsWith('BNP')).map(r => [d[0], r])).slice(0, 6).map(([d, r]) => `<tr><td><span class="row">${mg(r[0])}<span class="el ${r[0] === '?' ? 'mono' : ''}">${r[1]}</span></span></td><td>${cat(r[3], r[4])}</td><td class="c t2">${d}</td><td class="n">${amt(r[5])}</td></tr>`).join('')}</table></div>`, { crumb: 'Comptes' });

const TXFILTERS = `<div class="row" style="padding:12px 32px;gap:8px"><span class="sel">Tous les comptes${I('chevron-down', 's14')}</span><span class="sel">${I('calendar', 's14')}1 – 31 mai 2026</span><span class="sel">Toutes les catégories${I('chevron-down', 's14')}</span><span class="sp"></span><span class="t3 sm">38 opérations · net <span class="pos">+635,65 €</span></span></div>`;
const TXTABS = on => `<div class="tabs">${['Toutes', 'À vérifier <span class="n">12</span>'].map((t, i) => `<span class="${i === on ? 'on' : ''}">${t}</span>`).join('')}</div>`;
P.transactions = {
  A: ['Toutes', () => shell('transactions', 'Transactions', SEARCH, `${TXTABS(0)}
    <div style="display:grid;grid-template-columns:1fr 380px;flex:1;min-height:0"><div class="col">${TXFILTERS}
      <div class="edge"><table><tr><th>Opération</th><th>Catégorie</th><th class="n">Montant</th></tr>${txRows(TX, { noAcc: 1, noSub: 1, sel: [2, 1] })}</table></div></div>
      <div class="col" style="border-left:1px solid var(--line);padding:24px;gap:16px;background:var(--rail)">
        <div class="row" style="gap:12px">${mg('MA', 'lg')}<div class="col"><span class="h">MAIF Habitation</span><span class="mono t3">PRLV SEPA ASSUR MAIF</span></div></div>
        <span class="fig neg">−187,44 €</span>
        <dl class="kv"><dt>Date</dt><dd>11 mai 2026</dd><dt>Compte</dt><dd>BNP Compte courant</dd><dt>Catégorie</dt><dd><span class="sel">${cat('Logement', 'Assurance')}${I('chevron-down', 's14')}</span></dd><dt>Classée par</dt><dd class="t2">règle « ASSUR MAIF »</dd><dt>Import</dt><dd class="t2">releve-mai.ofx</dd></dl>
        <div class="hr"></div>
        <div class="row">${I('repeat', 's14 t3')}<div class="col"><span>Paiement récurrent</span><span class="t3 sm">Annuel · prochain le 21 nov. 2026</span></div><span class="sp"></span><span class="ac sm">Voir la série</span></div>
        <div class="hr"></div><span class="h">Même marchand</span>
        <table><tr><td class="t2">21 nov. 2025</td><td class="n">${amt('−179,90 €')}</td></tr><tr><td class="t2">21 nov. 2024</td><td class="n">${amt('−172,10 €')}</td></tr></table>
        <span class="sp"></span><div class="row"><span class="btn">Modifier la règle</span><span class="btn">Exclure des totaux</span></div>
      </div></div>`, { flush: 1 })],
  B: ['À vérifier', () => shell('transactions', 'Transactions', SEARCH, `${TXTABS(1)}
    <div class="row" style="padding:16px 32px;gap:16px"><div class="col" style="gap:6px;width:260px"><span><span class="h">4 sur 16</span> <span class="t2">classées aujourd’hui</span></span>${meter(25)}</div><span class="sp"></span>
      <span class="note" style="max-width:420px">${I('cpu', 's14')}L’IA locale propose une catégorie pour 3 opérations. Rien n’est classé sans votre accord.</span></div>
    <div class="edge"><table><tr><th>Libellé du relevé</th><th class="c">Date</th><th>Proposition</th><th></th><th class="n">Montant</th></tr>
    ${[['CB NOVATECH SAS 12/05', '12 mai', 'Loisirs', 'Électronique', '71 %', '−49,90 €'], ['PRLV SEPA ASSUR MAIF', '11 mai', 'Logement', 'Assurance habitation', '78 %', '−187,44 €'], ['VIR RECU M. DUBOIS', '9 mai', null, null, '', '+420,00 €'], ['CB SNCF CONNECT', '7 mai', 'Transport', 'Transports en commun', '74 %', '−86,40 €'], ['PRLV SEPA CAISSE LOC EPARGNE', '5 mai', null, null, '', '−60,00 €'], ['CB LE PETIT BOUCHON LYON', '3 mai', 'Alimentation', 'Restaurants', '66 %', '−42,50 €']].map(r => `<tr><td class="mono">${r[0]}</td><td class="c t2">${r[1]}</td><td>${r[2] ? `${cat(r[2], r[3])} <span class="t3 sm" style="margin-left:8px">confiance ${r[4]}</span>` : '<span class="t3">Aucune proposition</span>'}</td><td><span class="row" style="justify-content:flex-end">${r[2] ? `<span class="btn pri">${I('check', 's14')}Confirmer</span><span class="btn">Corriger</span>` : '<span class="btn">Choisir une catégorie</span>'}<span class="btn ghost" title="Toujours catégoriser ainsi">${I('wand-sparkles', 's14')}Créer une règle</span></span></td><td class="n">${amt(r[5])}</td></tr>`).join('')}</table></div>`, { flush: 1 })],
};

P.imports = () => shell('imports', 'Imports', '', `
  <div class="col" style="gap:10px"><div class="drop">${I('file-up')}<div class="col"><span style="color:var(--tx)">Déposez un relevé OFX ou QFX</span><span class="sm">Le relevé indique son compte. Rien n’est importé avant votre confirmation.</span></div><span class="sp"></span><span class="btn">Parcourir</span></div>
  <div class="banner">${I('file-text', 's14 t3')}<span>releve-mai-2026.ofx</span><span class="t3">84 Ko</span><span class="vr" style="height:16px"></span><span class="st pos">${I('check')}<span>Compte reconnu</span></span><span class="row">${mg('BN')}BNP Compte courant</span><span class="sp"></span><span class="btn ghost">${I('x', 's14')}Retirer</span><span class="btn pri">Importer</span></div></div>
  <div class="col" style="gap:8px"><span class="h">Historique</span>
  <table><tr><th>Fichier</th><th>Compte</th><th>Importé le</th><th>Période couverte</th><th class="c">Nouvelles</th><th class="c">Doublons</th><th class="n">Résultat</th></tr>
  ${[['releve-avril-2026.ofx', 'BN', 'BNP Compte courant', '2 mai 2026', '1 – 30 avr. 2026', '42', '3', 'ok', 'Réussi', ''], ['revolut-avril.qfx', 'RE', 'Revolut', '2 mai 2026', '1 – 30 avr. 2026', '17', '0', 'ok', 'Réussi', ''], ['livret-a-t1.ofx', 'CA', 'Livret A', '4 avr. 2026', '1 janv. – 31 mars 2026', '6', '6', 'warn', 'Partiel', '6 opérations déjà présentes ont été ignorées.'], ['export.ofx', '?', '—', '4 avr. 2026', '—', '0', '0', 'neg', 'Échec', 'Fichier illisible. Rien n’a été modifié.'], ['releve-mars-2026.ofx', 'BN', 'BNP Compte courant', '3 avr. 2026', '1 – 31 mars 2026', '39', '0', 'ok', 'Réussi', '']].map(r => `<tr><td class="wrap"><span class="mono">${r[0]}</span>${r[9] ? `<div class="sm ${r[7]}" style="padding-bottom:6px">${r[9]}</div>` : ''}</td><td><span class="row">${mg(r[1])}${r[2]}</span></td><td class="t2">${r[3]}</td><td class="t2">${r[4]}</td><td class="c">${r[5]}</td><td class="c t2">${r[6]}</td><td class="n"><span class="st ${r[7] === 'ok' ? 't2' : r[7]}">${I(r[7] === 'ok' ? 'check' : r[7] === 'warn' ? 'triangle-alert' : 'circle-x')}${r[8]}</span></td></tr>`).join('')}</table></div>`);

P.categories = () => shell('categories', 'Catégories et règles', `<span class="btn">${I('play', 's14')}Exécuter les règles</span><span class="btn pri">${I('plus', 's14')}Nouvelle règle</span>`, `
  <div style="display:grid;grid-template-columns:340px 1fr;height:100%"><div class="col" style="border-right:1px solid var(--line);padding:16px 12px;gap:2px">
    <div class="row" style="padding:0 8px 8px"><span class="h">Catégories</span><span class="sp"></span><span class="btn ghost">${I('plus', 's14')}</span></div>
    ${[['Logement', 2, 1], ['Alimentation', 4], ['Transport', 3], ['Loisirs', 1], ['Abonnements', 3], ['Santé', 1], ['Revenus', 2]].map(([n, c, open]) => `<div class="nav ${open ? 'on' : ''}">${I(open ? 'chevron-down' : 'chevron-right', 's14 t3')}<span class="dot" style="--c:var(--${CATS[n][0]})"></span>${I(CATS[n][1], 's14')}${n}<span class="n">${c} règle${c > 1 ? 's' : ''}</span></div>${open ? ['Loyer / Prêt', 'Charges', 'Assurance habitation'].map(s => `<div class="nav" style="padding-left:52px">${s}</div>`).join('') + `<div class="nav t3" style="padding-left:52px">${I('plus', 's14')}Sous-catégorie</div>` : ''}`).join('')}
    <div class="nav">${I('chevron-right', 's14 t3')}<span class="dot" style="--c:var(--c0)"></span>${I('piggy-bank', 's14')}Épargne projet<span class="n warn">aucune règle</span></div>
    <span class="sp"></span><span class="note" style="padding:8px">${I('lock', 's14')}Les catégories fournies avec Bastide ne peuvent pas être supprimées.</span></div>
  <div class="col" style="padding:16px 0 0;gap:8px"><div class="row" style="padding:0 32px"><span class="h">Règles</span><span class="sel">${cat('Logement')}${I('x', 's14')}</span><span class="sp"></span><span class="t3 sm">Appliquées dans cet ordre. Une catégorie choisie à la main n’est jamais remplacée.</span></div>
    <div class="edge"><table><tr><th style="width:60px">Ordre</th><th>Champ</th><th>Condition</th><th>Motif</th><th>Catégorie</th><th class="c">Correspondances</th><th class="n">Active</th></tr>
    ${[['1', 'Description', 'contient', 'REGIE LYON', 'Logement', 'Loyer / Prêt', '17', 1], ['2', 'Description', 'contient', 'ASSUR MAIF', 'Logement', 'Assurance habitation', '7', 1], ['3', 'Description', 'contient', 'CARREFOUR', 'Alimentation', 'Courses', '48', 1], ['4', 'Description', 'regex', '^CB (SNCF|RATP|TCL)', 'Transport', 'Transports en commun', '31', 1], ['5', 'Montant', 'plage', '2 800,00 – 2 900,00', 'Revenus', 'Salaire', '17', 1], ['6', 'Description', 'contient', 'AMAZON', 'Loisirs', null, '12', 0]].map(r => `<tr class="${r[7] ? '' : 'dim'}"><td><span class="row t3">${I('grip-vertical', 's14')}${r[0]}</span></td><td class="t2">${r[1]}</td><td class="t2">${r[2]}</td><td class="mono">${r[3]}</td><td>${cat(r[4], r[5])}</td><td class="c t2">${r[6]}</td><td class="n"><span class="tog ${r[7] ? 'on' : ''}" style="display:inline-block"></span></td></tr>`).join('')}</table></div></div></div>`, { flush: 1 });

const SUBS = [['NF', 'Netflix', 'Loisirs', 'Mensuel', '15,49 €', '15 mai', 'warn', 'trending-up', 'Hausse : 13,49 € → 15,49 €'], ['SP', 'Spotify Famille', 'Loisirs', 'Mensuel', '17,99 €', '22 mai', '', '', ''], ['FM', 'Free Mobile', 'Abonnements', 'Mensuel', '19,99 €', '4 juin', '', '', ''], ['ED', 'EDF', 'Logement', 'Mensuel', '89,00 €', '8 juin', '', '', ''], ['BF', 'Basic-Fit', 'Santé', 'Mensuel', '29,99 €', 'attendu le 5 mai', 'warn', 'clock-alert', 'Prélèvement manquant depuis 9 jours'], ['AD', 'Adobe Creative Cloud', 'Autres', 'Trimestriel', '71,99 €', '2 août', '', '', ''], ['MA', 'MAIF Habitation', 'Logement', 'Annuel', '187,44 €', '21 nov.', '', '', ''], ['C+', 'Canal+', 'Loisirs', 'Mensuel', '24,99 €', '—', 'dim', '', 'Résilié, dernier prélèvement le 18 mars']];
const subsHead = `<div class="row" style="gap:40px;align-items:flex-end"><div class="col" style="gap:4px"><span class="t2 sm">Charge mensuelle</span><span class="fig xl">212,08 €</span><span class="t3 sm">Trimestriels et annuels ramenés au mois</span></div><span class="vr"></span>
  <div class="col" style="gap:6px"><span class="t2 sm">Actifs</span><span class="fig md">7</span><span class="t3 sm">5 mensuels · 1 trimestriel · 1 annuel</span></div>
  <div class="col" style="gap:6px"><span class="t2 sm">Prochain prélèvement</span><span class="fig md">Netflix, demain</span><span class="t3 sm">15,49 € · 15 mai 2026</span></div>
  <div class="col" style="gap:6px"><span class="t2 sm">À regarder</span><span class="fig md warn">2</span><span class="t3 sm">1 hausse · 1 prélèvement manquant</span></div></div>`;
P.subscriptions = () => shell('subscriptions', 'Abonnements', `<span class="btn">${I('scan-search', 's14')}Détecter</span>`, `${subsHead}
    <div class="banner">${I('merge', 's14 t3')}<span>« STREAMCO » et « STREAMCO - STREAMCO TV » semblent être le même abonnement, renommé par la banque.</span><span class="sp"></span><span class="btn ghost">Ce sont deux abonnements</span><span class="btn">Fusionner</span></div>
    <table><tr><th>Abonnement</th><th>Catégorie</th><th>Cadence</th><th class="c">Montant</th><th class="c">Prochain</th><th>État</th><th></th></tr>
    ${SUBS.map(s => `<tr class="${s[6] === 'dim' ? 'dim' : ''}"><td><span class="row">${mg(s[0])}${s[1]}</span></td><td>${cat(s[2])}</td><td class="t2">${s[3]}</td><td class="c">${s[4]}</td><td class="c ${s[6] === 'warn' && s[7] === 'clock-alert' ? 'warn' : 't2'}">${s[5]}</td><td>${s[8] ? `<span class="st ${s[6] === 'warn' ? 'warn' : ''}">${s[7] ? I(s[7]) : ''}${s[8]}</span>` : ''}</td><td class="n t3">${I('ellipsis')}</td></tr>`).join('')}</table>`);

P.loans = () => shell('loans', 'Crédits', `<span class="btn pri">${I('plus', 's14')}Nouveau crédit</span>`, `
  <div class="row" style="gap:40px;align-items:flex-end"><div class="col" style="gap:4px"><span class="t2 sm">Charge mensuelle</span><span class="fig xl">1 506,25 €</span><span class="t3 sm">2 échéances le 1 juin 2026, assurance comprise</span></div><span class="vr"></span>
    <div class="col" style="gap:6px"><span class="t2 sm">Capital restant dû</span><span class="fig md">234 129,21 €</span><span class="t3 sm">sur 255 000,00 € · 8,2 % remboursés</span></div><span class="vr"></span>
    <div class="col" style="gap:6px;width:360px"><div class="row" style="align-items:baseline"><span class="t2 sm">Taux d’endettement</span><span class="sp"></span><span class="fig md">32,7 %</span></div>
      <div style="padding-top:18px">${meter(54.5, 58.3, 'repère HCSF 35 %')}</div><span class="t3 sm">1 506,25 € sur un revenu déclaré de 4&nbsp;600,00&nbsp;€. Lecture indicative, qui n’engage aucun prêteur.</span></div></div>
  <table><tr><th>Crédit</th><th>Prêteur</th><th class="c">Taux</th><th class="c">Assurance</th><th style="width:22%">Remboursé</th><th class="c">Capital restant dû</th><th class="c">Fin</th><th class="n">Échéance</th></tr>
  <tr><td style="height:48px"><span class="row">${mg('BN')}<span style="font-weight:500">Appartement Lyon 3e</span></span></td><td class="t2">BNP · 300 mois</td><td class="c">3,45 %</td><td class="c t2">28,80 €</td><td><span class="row">${meter(7.3)}</span><span class="xs t3">7,3 % · 267 échéances restantes</span></td><td class="c">222 542,70 €</td><td class="c t2">août 2048</td><td class="n" style="font-weight:500">1 223,87 €</td></tr>
  <tr><td style="height:48px"><span class="row">${mg('CA')}<span style="font-weight:500">Travaux cuisine</span></span></td><td class="t2">Crédit Agricole · 60 mois</td><td class="c">4,90 %</td><td class="c t3">—</td><td><span class="row">${meter(22.8)}</span><span class="xs t3">22,8 % · 45 échéances restantes</span></td><td class="c">11 586,51 €</td><td class="c t2">févr. 2030</td><td class="n" style="font-weight:500">282,38 €</td></tr></table>
  <div class="col" style="gap:12px"><span class="h">Capital restant dû jusqu’au dernier remboursement</span>
  ${line([240, 255, 234, 226, 217, 208, 198, 194, 185, 175, 165, 154, 143, 131, 119, 106, 93, 79, 65, 50, 35, 19, 12, 6, 0], Array.from({ length: 25 }, (_, i) => i % 4 === 0 ? 2024 + i : ''), { w: 1150, h: 240, min: 0, max: 300, ticks: [[300, '300 k€'], [200, '200 k€'], [100, '100 k€'], [0, '0']], label: 'Capital restant dû', extra: (p, pt) => `<line x1="${pt[2][0]}" x2="${pt[2][0]}" y1="6" y2="${240 - p.B}" stroke="var(--tx3)" stroke-dasharray="4 3"/><text class="ax" x="${pt[2][0] + 6}" y="16" style="fill:var(--tx)">mai 2026 · 234 129,21 €</text><line x1="${pt[6][0]}" x2="${pt[6][0]}" y1="40" y2="${240 - p.B}" stroke="var(--line2)" stroke-dasharray="4 3"/><text class="ax" x="${pt[6][0] + 6}" y="50">fin du prêt travaux</text>` })}</div>`);

P.simulator = () => shell('simulator', 'Simulateur', `<span class="btn">${I('bookmark', 's14')}Enregistrer le scénario</span>`, `
  <div style="display:grid;grid-template-columns:380px 1fr;height:100%"><div class="col" style="border-right:1px solid var(--line);padding:24px;gap:14px">
    <span class="h">Nouveau crédit</span>
    <div class="g2" style="gap:12px"><label class="f">Prix du bien<span class="inp r focus">320 000,00 €</span></label><label class="f">Apport<span class="inp r">40 000,00 €</span></label>
      <label class="f">Frais<span class="inp r">4 500,00 €</span></label><label class="f">Montant emprunté<span class="inp r">284 500,00 €</span><small>calculé : prix − apport + frais</small></label>
      <label class="f">Taux nominal<span class="inp r">3,25 %</span></label><label class="f">Assurance par mois<span class="inp r">32,00 €</span></label></div>
    <label class="f"><span class="row">Durée<span class="sp"></span><span style="color:var(--tx)">25 ans · 300 mois</span></span><div class="range"><i style="width:80%"></i><b style="left:80%"></b></div><span class="row xs t3">5 ans<span class="sp"></span>30 ans</span></label>
    <div class="row"><span class="tog on"></span><div class="col"><span>Inclure mes crédits actuels</span><span class="t3 sm">Ajoute 1 506,25 € par mois à la lecture</span></div></div>
    <div class="hr"></div><div class="row"><span class="h">Scénarios enregistrés</span><span class="sp"></span><span class="btn">Comparer (1/3)</span></div>
    ${[['Lyon 3e, 320 k€', 'en cours · 3,25 % · 25 ans', '1 418,41 €', 1], ['Villeurbanne, 265 k€', '3,25 % · 25 ans', '1 115,45 €', 0], ['Lyon 7e, 350 k€', '3,40 % · 20 ans', '1 845,70 €', 0], ['Lyon 8e, 290 k€', '3,30 % · 25 ans', '1 274,40 €', 0]].map(s => `<div class="row"><span class="chk ${s[3] ? 'on' : ''}">${s[3] ? I('check') : ''}</span><div class="col"><span>${s[0]}</span><span class="t3 sm">${s[1]}</span></div><span class="sp"></span><span class="t2">${s[2]}</span></div>`).join('')}</div>
  <div class="col" style="padding:24px 32px;gap:22px">
    <div class="row" style="gap:40px;align-items:flex-end"><div class="col" style="gap:4px"><span class="t2 sm">Échéance mensuelle</span><span class="fig xl">1 418,41 €</span><span class="t3 sm">1 386,41 € de mensualité + 32,00 € d’assurance · 300 échéances</span></div><span class="vr"></span>
      <div class="col" style="gap:6px"><span class="t2 sm">Coût total</span><span class="fig md">145 523,00 €</span><span class="t3 sm">intérêts 131 423,00 € · assurance 9 600,00 € · frais 4 500,00 €</span></div><span class="vr"></span>
      <div class="col" style="gap:6px"><span class="t2 sm">TAEG indicatif</span><span class="fig md">3,67 %</span><span class="t3 sm">taux, assurance et frais</span></div></div>
    <div class="hr"></div>
    <div class="col" style="gap:14px"><div class="row"><span class="h">Lecture HCSF</span><span class="st warn">${I('triangle-alert')}Au-dessus du repère</span><span class="sp"></span><span class="t3 sm">Lecture indicative, qui n’engage aucun prêteur.</span></div>
    <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:40px">
      <div class="col" style="gap:6px"><div class="row" style="align-items:baseline"><span class="t2 sm">Taux d’endettement</span><span class="sp"></span><span class="fig md">63,6 %</span></div><div style="padding-top:18px">${meter(90.9, 50, 'repère 35 %', 'over')}</div><span class="t3 sm">2 924,66 € sur un revenu déclaré de 4&nbsp;600,00&nbsp;€</span></div>
      <div class="col" style="gap:6px"><div class="row" style="align-items:baseline"><span class="t2 sm">Durée</span><span class="sp"></span><span class="fig md">25 ans</span></div><div style="padding-top:18px">${meter(83.3, 83.3, 'repère 25 ans')}</div><span class="t3 sm">Au repère, pas au-delà</span></div>
      <div class="col" style="gap:6px"><span class="t2 sm">Capacité d’emprunt au repère</span><span class="fig md">20 811,40 €</span><span class="t3 sm" style="padding-top:8px">Vos crédits actuels laissent 103,75 € d’échéance sous 35 %. C’est ce qui limite la capacité, pas le bien visé.</span></div></div></div>
    <div class="hr"></div>
    <div class="col" style="gap:12px"><div class="row"><span class="h">Projection annuelle</span><span class="sp"></span><span class="cat"><span class="dot" style="--c:var(--ac)"></span>Capital</span><span class="cat" style="margin-left:12px"><span class="dot" style="--c:var(--tx3)"></span>Intérêts</span></div>
    ${stacked(Array.from({ length: 25 }, (_, i) => 7.6 * Math.pow(1.0325, i)), Array.from({ length: 25 }, (_, i) => 9.1 - i * 0.36), Array.from({ length: 25 }, (_, i) => i % 4 === 0 || i === 24 ? 2026 + i : ''), { w: 780, h: 220, max: 20, ticks: [[20, '20 k€'], [10, '10 k€'], [0, '0']], label: 'Capital et intérêts par an' })}</div></div></div>`, { flush: 1 });

/* ── v2: Comptes, three ways to separate accounts by type ── */
const ACC = [
  ['Comptes courants', 'landmark', '+3 486,12 €', 24.9, [['BN', 'BNP Compte courant', 'BNP Paribas', '14 mai 2026', '+612,05 €', '+3 486,12 €', '1 carte']]],
  ['Épargne', 'piggy-bank', '+10 840,00 €', 77.4, [['CA', 'Livret A', 'Crédit Agricole', '2 mai 2026', '+300,00 €', '+8 240,00 €'], ['?', 'Compte sur livret', 'Caisse Locale d’Épargne', '2 mai 2026', '0,00 €', '+2 600,00 €']]],
  ['Cartes à débit différé', 'credit-card', '−312,40 €', 2.2, [['RE', 'Revolut', 'Revolut', '11 mai 2026', '−47,00 €', '−312,40 €']]],
];
const accTotal = `<div class="col" style="gap:4px"><span class="t2 sm">Solde total</span><span class="fig xl">14 013,72 €</span></div>`;
const accRow = r => `<tr><td><span class="row">${mg(r[0])}${r[1]}${r[6] ? `<span class="st t3" style="margin-left:8px">${I('credit-card')}${r[6]}</span>` : ''}</span></td><td class="t2">${r[2]}</td><td class="t2">${r[3]}</td><td class="c">${amt(r[4])}</td><td class="n">${amt(r[5]).replace('class="pos"', '')}</td></tr>`;
const accHead = `<tr><th>Compte</th><th>Établissement</th><th>Dernier import</th><th class="c">Variation en mai</th><th class="n">Solde</th></tr>`;
const ADD = `<span class="btn pri">${I('plus', 's14')}Ajouter un compte</span>`;
P.accounts = () => shell('accounts', 'Comptes', `<span class="seg"><span class="on">Par type</span><span>Par établissement</span></span>` + ADD, `
    <div class="row" style="align-items:baseline">${accTotal}<span class="sp"></span><span class="t3 sm">4 comptes · soldes recalculés il y a 2 min</span></div>
    ${ACC.map((t, i) => `<div class="col" style="gap:0"><div class="row" style="padding:10px 12px;background:var(--rail);border:1px solid var(--line);border-radius:var(--r-box) var(--r-box) ${i === 2 ? 'var(--r-box) var(--r-box)' : '0 0'}">${I(i === 2 ? 'chevron-right' : 'chevron-down', 's14 t3')}${I(t[1], 's14')}<span class="h">${t[0]}</span><span class="t3">${t[4].length}</span><span class="sp"></span><span class="t3 sm" style="margin-right:16px">${String(t[3]).replace('.', ',')} % du total</span><span class="h" style="width:120px;text-align:right">${t[2].replace('+', '')}</span></div>
      ${i === 2 ? '' : `<table style="margin-top:10px">${accHead}${t[4].map(accRow).join('')}</table>`}</div>`).join('')}`);

/* ── v2: Objectifs, banner image in the inspector ── */
const FUJI = `<svg viewBox="0 0 440 150" preserveAspectRatio="xMidYMid slice" width="100%" height="100%" role="img" aria-label="Image choisie pour l’objectif : le mont Fuji"><rect width="440" height="150" fill="#f3c9b5"/><rect y="0" width="440" height="60" fill="#f7dccb"/><circle cx="330" cy="52" r="22" fill="#e2573f"/><path d="M90 150L205 38h30L350 150z" fill="#55618f"/><path d="M205 38h30l22 22-12-6-10 10-9-9-11 9-10-10-13 7z" fill="#fbf4ee"/><path d="M0 150V112l60-22 70 30 60-14 70 22 80-26 100 20v38z" fill="#2f3a5c"/><path d="M0 150v-18l90-10 110 14 120-12 120 10v16z" fill="#1f2740"/></svg>`;
const ALLOC = [['1 avr. 2026', 'Dernier versement', '+400,00 €'], ['1 mars 2026', 'Virement mensuel', '+400,00 €'], ['1 févr. 2026', 'Virement mensuel', '+400,00 €'], ['1 janv. 2026', 'Prime de fin d’année', '+800,00 €'], ['1 déc. 2025', 'Virement mensuel', '+400,00 €']];
const goalsPanel = mode => shell('goals', 'Objectifs', `<span class="btn pri">${I('plus', 's14')}Nouvel objectif</span>`, `
  <div style="display:grid;grid-template-columns:minmax(0,1fr) 440px;height:100%"><div class="col" style="padding:24px 32px;gap:16px">
    <div class="row" style="gap:40px;align-items:flex-end"><div class="col" style="gap:4px"><span class="t2 sm">Réservé sur 4 objectifs</span><span class="fig xl">24 450,00 €</span></div><span class="vr"></span><div class="col" style="gap:6px"><span class="t2 sm">Épargne disponible</span><span class="fig md">22 100,00 €</span></div></div>
    <table><tr><th>Objectif</th><th>Échéance</th><th style="width:30%">Avancement</th><th class="c">Réservé</th><th class="n"></th></tr>
    ${GOALS.map((g, i) => `<tr class="${i === 2 ? 'cur' : ''}"><td style="height:48px;font-weight:500"><span class="row">${i === 2 && mode !== 'none' ? `<span style="width:36px;height:24px;border-radius:4px;overflow:hidden;flex:none">${FUJI}</span>` : ''}${g[0]}</span></td><td class="t2">${g[4] >= 100 ? `<span class="st pos">${I('check')}Atteint en avril 2026</span>` : g[1]}</td><td>${meter(g[4], null, '', g[4] >= 100 ? 'done' : '')}</td><td class="c">${g[2]} <span class="t3">/ ${g[3]}</span></td><td class="n">${g[4]} %</td></tr>`).join('')}</table>
    <span class="row t2 sm">${I('archive', 's14')}2 objectifs archivés</span><span class="sp"></span>
    <span class="note">${I('lock', 's14')}Un objectif réserve une somme sur le papier. Vos comptes ne sont pas modifiés. Les images restent sur cet ordinateur.</span></div>
  <div class="col" style="border-left:1px solid var(--line);background:var(--rail)">
    ${mode === 'top' ? `<div style="height:150px;position:relative">${FUJI}<span class="btn" style="position:absolute;right:12px;bottom:12px">${I('image', 's14')}Changer l’image</span></div>` : ''}
    ${mode === 'over' ? `<div style="height:190px;position:relative">${FUJI}<div style="position:absolute;inset:auto 0 0 0;padding:44px 24px 14px;background:linear-gradient(transparent,rgba(12,14,24,.82));color:#fff" class="row"><div class="col"><span style="font:600 18px var(--f)">Voyage Japon</span><span style="font-size:12px;color:#d9dce6">Atteint en avril 2026</span></div><span class="sp"></span><span style="font:600 18px var(--f)">100 %</span></div><span class="btn" style="position:absolute;right:12px;top:12px">${I('image', 's14')}Changer</span></div>` : ''}
    <div class="col" style="padding:${mode === 'none' ? 24 : 18}px 24px 24px;gap:16px;flex:1">
    ${mode === 'over' ? '' : `<div class="row"><span class="h" style="font-size:16px">Voyage Japon</span><span class="sp"></span>${mode === 'none' ? `<span class="btn">${I('image-plus', 's14')}Ajouter une image</span>` : ''}<span class="btn">${I('archive', 's14')}Archiver</span></div>`}
    <div class="row" style="align-items:baseline"><span class="fig">4 000,00 €</span><span class="t2">sur 4 000,00 €</span><span class="sp"></span>${mode === 'over' ? `<span class="btn">${I('archive', 's14')}Archiver</span>` : '<span class="h">100 %</span>'}</div>${meter(100, null, '', 'done')}
    ${mode === 'over' ? '' : `<span class="st pos">${I('check')}Atteint en avril 2026</span>`}<div class="hr"></div>
    <div class="row"><span class="h">Allocations</span><span class="sp"></span><span class="btn">${I('plus', 's14')}Allouer</span></div>
    <table>${ALLOC.map(r => `<tr><td class="t2">${r[0]}</td><td>${r[1]}</td><td class="n">${amt(r[2])}</td></tr>`).join('')}</table></div></div></div>`, { flush: 1 });
P.goals = () => goalsPanel('over');

/* ── v2: Placements (PEA, assurance vie…) ── */
const INV = [['BD', 'PEA', 'Boursorama', 'PEA', 'mars 2023', '27 000,00 €', '31 840,00 €', '+4 840,00 €', '+17,9 %', '30 avr. 2026', 0], ['LX', 'Assurance vie Horizon', 'Linxea', 'Assurance vie', 'sept. 2019', '14 500,00 €', '16 780,00 €', '+2 280,00 €', '+15,7 %', '31 mars 2026', 0], ['NV', 'PEE Novatech', 'Amundi ESR', 'PEE', 'janv. 2022', '5 200,00 €', '5 615,00 €', '+415,00 €', '+8,0 %', '31 déc. 2025', 1]];
P.investments = () => shell('investments', 'Placements', `<span class="btn pri">${I('plus', 's14')}Nouveau placement</span>`, `
  <div style="display:grid;grid-template-columns:minmax(0,1fr) 460px;height:100%"><div class="col" style="padding:24px 32px;gap:20px">
    <div class="row" style="gap:32px;align-items:flex-end"><div class="col" style="gap:4px"><span class="t2 sm">Valeur déclarée</span><span class="fig xl">54 235,00 €</span><span class="t3 sm">3 placements · dernière valeur saisie le 30 avr. 2026</span></div><span class="vr"></span>
      <div class="col" style="gap:6px"><span class="t2 sm">Versements nets</span><span class="fig md">46 700,00 €</span><span class="t3 sm">versé − retiré</span></div>
      <div class="col" style="gap:6px"><span class="t2 sm">Plus-value latente</span><span class="fig md">+7 535,00 €</span><span class="st t2">${I('trending-up')}+16,1 % des versements</span></div></div>
    <table><tr><th>Placement</th><th class="c">Versements nets</th><th class="c">Valeur déclarée</th><th class="c">Plus-value</th><th class="n">Valeur au</th></tr>
    ${INV.map((r, i) => `<tr class="${i === 0 ? 'cur' : ''}"><td style="height:48px"><span class="row">${mg(r[0])}<div class="col"><span style="font-weight:500">${r[1]}</span><span class="t3 xs">${r[3]} · ${r[2]} · ouvert en ${r[4]}</span></div></span></td><td class="c">${r[5]}</td><td class="c" style="font-weight:500">${r[6]}</td><td class="c">${r[7]} <span class="t3">${r[8]}</span></td><td class="n ${r[10] ? '' : 't2'}">${r[10] ? `<span class="st warn">${I('clock-alert')}${r[9]}</span>` : r[9]}</td></tr>`).join('')}</table>
    <div class="banner">${I('clock-alert', 's14 warn')}<span>La valeur du PEE Novatech date de plus de quatre mois.</span><span class="sp"></span><span class="btn">Mettre à jour la valeur</span></div>
    <span class="sp"></span>
    <span class="note">${I('lock', 's14')}Bastide ne se connecte à aucun courtier et ne télécharge aucun cours. La valeur est celle que vous recopiez depuis votre relevé ; la plus-value est calculée, jamais enregistrée.</span></div>
  <div class="col" style="border-left:1px solid var(--line);padding:24px;gap:16px;background:var(--rail)">
    <div class="row" style="gap:12px">${mg('BD', 'lg')}<div class="col"><span class="h" style="font-size:16px">PEA</span><span class="t3 sm">Boursorama · ouvert le 14 mars 2023</span></div><span class="sp"></span><span class="btn">${I('ellipsis', 's14')}</span></div>
    <div class="row" style="align-items:baseline"><span class="fig">31 840,00 €</span><span class="t2">au 30 avr. 2026</span><span class="sp"></span><span>+4 840,00 € <span class="t3">+17,9 %</span></span></div>
    <div class="row"><span class="btn pri">${I('pencil', 's14')}Saisir la valeur</span><span class="btn">${I('plus', 's14')}Versement ou retrait</span></div>
    <div class="row sm" style="gap:14px"><span class="cat"><span class="dot" style="--c:var(--ac)"></span>Valeur déclarée</span><span class="cat"><span class="dot" style="--c:var(--tx3)"></span>Versements nets</span></div>
    ${line([15.2, 17.9, 19.6, 22.4, 24.1, 26.9, 28.3, 30.6, 31.84], ['2023', '', '', '2024', '', '', '2025', '', '2026'], { w: 412, h: 170, min: 10, max: 35, ticks: [[35, '35 k€'], [22.5, '22,5 k€'], [10, '10 k€']], label: 'Valeur déclarée et versements nets du PEA', extra: (p, pt) => `<path d="M${pt[0][0]} ${p.y(15)}H${pt[1][0]}V${p.y(17)}H${pt[3][0]}V${p.y(21)}H${pt[5][0]}V${p.y(24)}H${pt[7][0]}V${p.y(27)}H${pt[8][0]}" fill="none" stroke="var(--tx3)" stroke-width="1.5"/>` })}
    <div class="hr"></div>
    <div class="col" style="gap:6px"><div class="row" style="align-items:baseline"><span class="t2 sm">Plafond de versement</span><span class="sp"></span><span>27 000,00 € <span class="t3">sur 150 000,00 €</span></span></div>${meter(18)}</div>
    <div class="col" style="gap:6px"><div class="row" style="align-items:baseline"><span class="t2 sm">Ancienneté</span><span class="sp"></span><span>3 ans 2 mois</span></div><div style="padding-top:18px">${meter(39.6, 62.5, 'repère 5 ans · mars 2028')}</div><span class="t3 sm">Avant 5 ans, un retrait clôt en principe le plan. Lecture indicative, qui ne vaut pas conseil fiscal.</span></div>
    <div class="hr"></div><div class="row"><span class="h">Mouvements</span><span class="sp"></span><span class="t3 sm">2 rapprochés avec vos transactions</span></div>
    <table>${[['30 avr. 2026', 'Valeur saisie', '31 840,00 €', 't2'], ['5 avr. 2026', 'Versement', '+500,00 €', ''], ['31 janv. 2026', 'Valeur saisie', '30 600,00 €', 't2'], ['5 janv. 2026', 'Versement', '+2 500,00 €', '']].map(r => `<tr><td class="t2">${r[0]}</td><td>${r[1]}</td><td class="n ${r[3]}">${r[2]}</td></tr>`).join('')}</table></div></div>`, { flush: 1 });

/* ── v2: Synthèse, placements counted in the assets ── */
P.networth = () => shell('networth', 'Synthèse', `<span class="btn">${I('plus', 's14')}Nouveau bien</span>`, `
  <div class="row" style="gap:28px;align-items:flex-end">
    <div class="col" style="gap:6px"><span class="t2 sm">Actif</span><span class="fig">571 035,00 €</span><span class="t3 sm">Comptes 24 300,00 € · Placements 54 235,00 € · Biens 492 500,00 €</span></div><span class="fig t3">−</span>
    <div class="col" style="gap:6px"><span class="t2 sm">Passif</span><span class="fig">234 129,21 €</span><span class="t3 sm">2 crédits, capital restant dû</span></div><span class="fig t3">=</span>
    <div class="col" style="gap:4px"><span class="t2 sm">Patrimoine net</span><span class="fig xl">336 905,79 €</span><span class="st t2">${I('trending-up')}+1 977,78 € depuis avril</span></div></div>
  <div class="hr"></div>
  <div style="display:grid;grid-template-columns:440px 1fr;gap:48px"><div class="col" style="gap:12px"><span class="h">Composition de l’actif</span>
    <div class="row" style="gap:2px;height:8px">${[['c1', 73.6], ['c3', 12.7], ['c6', 9.5], ['c2', 2.2], ['c4', 2.1]].map(([c, w]) => `<div style="height:100%;flex:${w};background:var(--${c});border-radius:2px"></div>`).join('')}</div>
    <table>${[['c1', 'Résidence principale', '73,6 %', '420 000,00 €'], ['c3', 'Locatif, part détenue', '12,7 %', '72 500,00 €'], ['c6', 'Placements', '9,5 %', '54 235,00 €'], ['c2', 'Livret A', '2,2 %', '12 500,00 €'], ['c4', 'Comptes courants', '2,1 %', '11 800,00 €']].map(r => `<tr><td><span class="cat" style="color:var(--tx)"><span class="dot" style="--c:var(--${r[0]})"></span>${r[1]}</span></td><td class="c t3">${r[2]}</td><td class="n">${r[3]}</td></tr>`).join('')}</table></div>
  <div class="col" style="gap:12px"><div class="row"><span class="h">Patrimoine net</span><span class="t3 sm">juin 2025 – mai 2026</span><span class="sp"></span><span class="seg"><span>Tout</span><span>3 ans</span><span class="on">12 mois</span></span></div>
    ${line([314.2, 316.0, 317.1, 319.4, 321.0, 323.2, 325.9, 328.4, 329.9, 332.3, 334.9, 336.9], M12, { w: 720, h: 230, min: 305, max: 345, ticks: [[345, '345 k€'], [325, '325 k€'], [305, '305 k€']], label: 'Patrimoine net sur 12 mois' })}</div></div>
  <div class="hr"></div>
  <div class="g2"><div class="col" style="gap:8px"><div class="row"><span class="h">Biens</span><span class="t3">2</span></div><table><tr><th>Bien</th><th>Nature</th><th class="c">Quote-part</th><th class="n">Valeur détenue</th></tr>
    <tr><td>Appartement Lyon 3e</td><td class="t2">Résidence principale</td><td class="c t2">100 %</td><td class="n">420 000,00 €</td></tr><tr><td>Studio Villeurbanne</td><td class="t2">Locatif</td><td class="c t2">50 %</td><td class="n">72 500,00 €</td></tr></table></div>
  <div class="col" style="gap:8px"><span class="h">À savoir</span><span class="note">${I('chart-line', 's14')}Les placements comptent pour leur dernière valeur saisie. Entre deux saisies, la courbe reste plate.</span><span class="note">${I('flag', 's14')}Les objectifs réservent de l’argent déjà présent sur un compte. Ils ne sont pas comptés une seconde fois.</span><span class="note">${I('info', 's14')}Les biens restent à leur valeur déclarée.</span></div></div>`);

/* ── v2: Paramètres, the four sections ── */
const SROW = (t, d, r) => `<div class="row" style="padding:14px 0;border-top:1px solid var(--line);gap:24px;align-items:flex-start"><div class="col" style="width:300px;gap:2px"><span style="font-weight:500">${t}</span><span class="t3 sm">${d}</span></div><div class="col" style="flex:1;gap:8px;align-items:flex-start">${r}</div></div>`;
const SH = (t, first) => `<span class="h" style="font-size:16px;padding:${first ? 0 : 28}px 0 12px">${t}</span>`;
const setPanel = (on, body) => shell('settings', 'Paramètres', '', `
  <div style="display:grid;grid-template-columns:200px 1fr;height:100%"><div class="col" style="border-right:1px solid var(--line);padding:16px 8px;gap:2px">${[['Profil', 'user'], ['Préférences', 'sliders-horizontal'], ['Données', 'database'], ['À propos', 'info']].map(([s, ic], i) => `<div class="nav ${i === on ? 'on' : ''}">${I(ic)}${s}</div>`).join('')}</div>
  <div class="col" style="padding:24px 40px;max-width:900px">${body}</div></div>`, { flush: 1 });
P.settings = {
  A: ['Profil', () => setPanel(0, `${SH('Profil', 1)}
    ${SROW('Avatar', 'Un monogramme, une pastille de couleur ou une photo. La photo reste sur cet ordinateur.', `<div class="row" style="gap:12px"><span class="av" style="width:48px;height:48px;font-size:16px;border-width:2px;border-color:var(--ac)">CD</span>${['c1', 'c3', 'c5', 'c4', 'c6'].map(c => `<span style="width:32px;height:32px;border-radius:50%;background:var(--${c})"></span>`).join('')}</div><div class="row"><span class="btn">${I('image', 's14')}Choisir une photo</span></div>`)}
    ${SROW('Nom d’utilisateur', 'Vous pouvez vous connecter avec ce nom ou avec votre e-mail.', `<div class="row"><span>Camille Dubois</span><span class="btn">Modifier</span></div>`)}
    ${SROW('Adresse e-mail', 'Sert uniquement à vous connecter. Bastide n’envoie aucun message.', `<span class="t2">camille.dubois@proton.me</span>`)}
    ${SH('Sécurité')}
    ${SROW('Mot de passe', 'Modifié le 3 janv. 2025.', `<span class="btn">Changer le mot de passe</span>`)}
    ${SROW('Code de récupération', 'Permet de réinitialiser votre mot de passe si vous l’oubliez. En générer un nouveau invalide l’ancien.', `<span class="btn">Générer un nouveau code</span><span class="t3 sm">Dernier code généré le 3 janv. 2025</span>`)}
    ${SH('Session')}
    ${SROW('Se déconnecter', 'Vos données restent sur cet ordinateur, protégées par votre mot de passe.', `<span class="btn">${I('log-out', 's14')}Se déconnecter</span>`)}`)],
  B: ['Préférences', () => setPanel(1, `${SH('Affichage', 1)}
    ${SROW('Thème', 'Sombre, clair, ou celui de votre système.', `<span class="seg"><span class="on">Système</span><span>Sombre</span><span>Clair</span></span>`)}
    ${SROW('Langue', 'S’applique immédiatement à toute l’interface.', `<span class="seg"><span class="on">Français</span><span>English</span></span>`)}
    ${SROW('Formats', 'Dates et montants suivent la langue choisie.', `<dl class="kv" style="gap:6px 32px"><dt>Date</dt><dd style="text-align:left">14 mai 2026 · 14/05/2026</dd><dt>Montant</dt><dd style="text-align:left">−1 234,56 €</dd></dl>`)}
    ${SROW('Barre latérale', 'Réduite, elle ne garde que les icônes.', `<span class="seg"><span class="on">Étendue</span><span>Réduite</span></span>`)}
    ${SH('Argent')}
    ${SROW('Devise', 'Choisie à l’inscription et appliquée à tous vos comptes. Elle ne peut pas être modifiée dans cette version.', `<span class="row t2">${I('lock', 's14')}EUR, euro (€)</span>`)}
    ${SROW('Objectif de taux d’épargne', 'Le repère affiché sur le tableau de bord.', `<div class="row" style="width:320px"><div class="range" style="flex:1"><i style="width:50%"></i><b style="left:50%"></b></div><span style="width:40px;text-align:right">20 %</span></div>`)}
    ${SROW('Revenu déclaré', 'Sert au taux d’endettement des panneaux Crédits et Simulateur. Sans lui, Bastide prend le revenu médian constaté.', `<div class="row"><span class="inp r" style="width:140px">4 600,00 €</span><span class="t3 sm">par mois</span></div>`)}`)],
  C: ['Données', () => setPanel(2, `${SH('IA locale', 1)}
    ${SROW('Catégorisation par IA', 'Les libellés de vos opérations sont envoyés à un modèle qui s’exécute sur cet ordinateur. Rien ne quitte votre machine.', `<span class="tog on"></span>`)}
    ${SROW('Moteur', 'Adresse locale uniquement : 127.0.0.1 ou localhost.', `<div class="row" style="width:100%"><span class="inp mono" style="flex:1.3">http://127.0.0.1:11434/v1</span><span class="sel mono" style="flex:1;height:32px">gemma3n:e4b<span class="sp"></span>${I('chevron-down', 's14')}</span><span class="btn" style="height:32px">Tester</span></div><span class="st pos">${I('check')}<span>Connecté</span><span class="t3">· 3 modèles disponibles</span></span>`)}
    ${SROW('Seuil de confiance', 'En dessous, l’opération vous est proposée pour vérification au lieu d’être classée.', `<div class="row" style="width:320px"><div class="range" style="flex:1"><i style="width:80%"></i><b style="left:80%"></b></div><span style="width:40px;text-align:right">80 %</span></div>`)}
    ${SH('Sauvegarde')}
    ${SROW('Exporter toutes les données', 'Un fichier .bastide, non chiffré, avec tout votre historique. Conservez-le en lieu sûr.', `<span class="btn pri">${I('download', 's14')}Exporter</span><span class="t3 sm">Dernière sauvegarde le 11 mai 2026 à 14:32</span>`)}
    ${SROW('Restaurer une sauvegarde', 'Remplace toutes les données actuelles, après confirmation.', `<span class="btn">${I('upload', 's14')}Importer un fichier</span>`)}
    ${SH('Réinitialisation')}
    ${SROW('Réinitialiser la base de données', 'Supprime opérations, comptes, règles, catégories personnalisées, objectifs, abonnements, crédits, biens, placements et simulations de ce profil. Les sauvegardes exportées ne sont pas touchées.', `<span class="btn danger">${I('trash-2', 's14')}Réinitialiser…</span>`)}`)],
  D: ['À propos', () => setPanel(3, `<div class="row tex" style="gap:14px;padding:20px;margin-bottom:8px;border:1px solid var(--line);border-radius:var(--r-box)"><span style="width:44px;height:44px;display:block">${MARK.replace('<svg ', '<svg width="44" height="44" ')}</span><div class="col"><span class="h" style="font-size:16px">Bastide</span><span class="t2">Version 0.1.3 · Windows</span></div></div>
    ${SROW('Mises à jour', 'Une fois par jour au plus, Bastide demande à GitHub le numéro de la dernière version publiée. Rien d’autre n’est envoyé, et rien n’est installé sans vous.', `<div class="row"><span class="tog on"></span>Me prévenir d’une nouvelle version</div><span class="st t2">${I('check')}Vous utilisez la dernière version.</span><span class="btn">Vérifier maintenant</span>`)}
    ${SROW('Confidentialité', 'Ce que Bastide fait de vos données.', `<span>Toutes vos données restent sur cet ordinateur. Bastide ne se connecte à aucune banque et n’envoie rien sur Internet, hormis la vérification des mises à jour si vous l’activez.</span>`)}
    ${SROW('Emplacement des données', 'Le fichier qui contient tout votre historique.', `<span class="mono t2">C:\\Users\\camille\\AppData\\Roaming\\Bastide\\bastide.db</span><span class="btn">${I('folder-open', 's14')}Ouvrir le dossier</span>`)}
    ${SROW('Licence', 'Bastide est un logiciel libre. Son nom et son logo ne sont pas couverts par la licence.', `<span>GNU Affero General Public License v3.0</span><div class="row"><span class="btn">${I('external-link', 's14')}Code source</span><span class="btn">Guide d’installation</span></div>`)}
    ${SROW('Crédits', 'Les composants tiers fournis avec l’application.', `<dl class="kv" style="gap:6px 32px"><dt>Icônes</dt><dd style="text-align:left">Lucide, licence ISC</dd><dt>Police</dt><dd style="text-align:left">Geist, licence SIL OFL</dd></dl><span class="btn ghost" style="padding:0">Toutes les licences</span>`)}`)],
};

/* ── v3: logo candidates ── */
const GLYPHS = {
  plan: ['Plan', (fg, ac) => [4.5, 10, 15.5].flatMap((y, r) => [4.5, 10, 15.5].map((x, c) => `<rect x="${x}" y="${y}" width="4" height="4" rx=".8" fill="${r === 1 && c === 1 ? ac : fg}"/>`)).join('')],
  couverts: ['Couverts', (fg, ac) => `<path fill="${fg}" fill-rule="evenodd" d="M3 5.5h18v1.7H3zM4 8.4h16v10.1H4zM5.2 18.5v-5a1.8 1.8 0 0 1 3.6 0v5zM10.2 18.5v-5a1.8 1.8 0 0 1 3.6 0v5zM15.2 18.5v-5a1.8 1.8 0 0 1 3.6 0v5z"/><path fill="${ac}" d="M10.2 18.5v-5a1.8 1.8 0 0 1 3.6 0v5z"/>`],
  maison: ['Maison', (fg, ac) => `<path fill="${fg}" fill-rule="evenodd" d="M2.4 11.1 12 4.8l9.6 6.3-.95 1.45L19 11.5V19H5v-7.5l-1.65 1.05zM10 19v-3.6a2 2 0 0 1 4 0V19z"/><path fill="${ac}" d="M10 19v-3.6a2 2 0 0 1 4 0V19z"/>`],
  creneaux: ['Créneaux', (fg, ac) => `<path fill="${fg}" d="M3 21V14H5V16H7V14H9V9H11V11H13V9H14.4V21Z"/><path fill="${ac}" d="M15.6 21V4H17V6H19V4H21V21Z"/>`],
  porte: ['Porte', (fg, ac) => `<path fill="${fg}" fill-rule="evenodd" d="M4.5 19.5V6h3v2.2h3V6h3v2.2h3V6h3v13.5zM9.4 19.5v-5.2a2.6 2.6 0 0 1 5.2 0v5.2z"/><path fill="${ac}" d="M9.4 19.5v-5.2a2.6 2.6 0 0 1 5.2 0v5.2z"/>`],
  lettre: ['Lettre B', (fg, ac) => `<path fill="${fg}" fill-rule="evenodd" d="M6 4.5h7a4 4 0 0 1 2.9 6.75A4.4 4.4 0 0 1 13.6 19.5H6zM9.2 7.5h3.5a1.45 1.45 0 0 1 0 2.9H9.2zM9.2 13.1h4.1a1.75 1.75 0 0 1 0 3.5H9.2z"/><path fill="${ac}" d="M9.2 13.1h4.1a1.75 1.75 0 0 1 0 3.5H9.2z"/>`],
  volets: ['Volets', (fg, ac) => `<path fill="${fg}" d="M4 6.2a1 1 0 0 1 1-1h3.4v14.3H5a1 1 0 0 1-1-1zM15.6 5.2H19a1 1 0 0 1 1 1v12.3a1 1 0 0 1-1 1h-3.4z"/><path fill="${ac}" d="M9.8 19.5V8.2a2.2 2.2 0 0 1 4.4 0v11.3z"/>`],
  voute: ['Clé de voûte', (fg, ac) => `<path fill="${fg}" d="M4.2 19.5v-6.8a7.8 7.8 0 0 1 5.3-7.4l1 3.4a4.2 4.2 0 0 0-2.7 4v6.8zM19.8 19.5v-6.8a7.8 7.8 0 0 0-5.3-7.4l-1 3.4a4.2 4.2 0 0 1 2.7 4v6.8z"/><path fill="${ac}" d="M10.4 4.6h3.2l-1 3.9h-1.2z"/>`],
};
const markSvg = (id, bg = 'var(--btn)', fg = 'var(--btn-on)', ac = 'var(--ac)', size = '') => `<svg ${size ? `width="${size}" height="${size}" ` : ''}viewBox="0 0 24 24" aria-hidden="true"><rect width="24" height="24" rx="5.3" fill="${bg}"/>${GLYPHS[id][1](fg, ac)}</svg>`;
const LOGO_TXT = {
  plan: ['Le plan en damier d’une bastide, ville neuve du Sud-Ouest : des îlots réguliers autour d’une place centrale. La place, seule case en couleur, est ce qui reste chez vous. La grille évoque aussi un registre.', 'Le plus abstrait des huit : sans le nom à côté, on peut y lire une simple grille.'],
  couverts: ['Les couverts, la galerie d’arcades qui borde la place d’une bastide. Trois arches sous un linteau : un abri, et un rythme régulier comme des mois.', 'Proche du pictogramme « banque » à colonnes ; à 16 px les arches se resserrent.'],
  maison: ['La bastide provençale : une maison de campagne large, au toit à faible pente, avec sa porte cintrée. Dit « chez vous » sans détour.', 'Une maison est le signe le plus courant qui soit ; il se distingue surtout par ses proportions basses.'],
  porte: ['La porte fortifiée par laquelle on entre dans une bastide : un mur crénelé, une ouverture cintrée. La porte en couleur est l’accès à vos comptes, que vous seul ouvrez.', 'Les créneaux tirent vers le château fort ; à 16 px ils se lisent comme de simples dents.'],
  lettre: ['L’initiale, construite comme une façade : un fût droit et deux travées. La travée basse, en couleur, reprend l’arche des couverts.', 'Un monogramme dit le nom, pas l’idée. C’est le plus sûr en petite taille et le moins parlant.'],
  volets: ['La fenêtre d’une maison provençale, volets ouverts : la lumière au centre, en couleur. Ce qui est à l’intérieur vous appartient.', 'Trois formes verticales : sans le nom, on peut y voir des colonnes ou un graphique.'],
  voute: ['Une arche et sa clé de voûte, la pierre qui tient tout l’ouvrage. La clé en couleur est l’épargne : la pièce qui fait tenir le reste.', 'Une arche seule peut évoquer un pont ou un aimant ; la clé est petite à 16 px.'],
  creneaux: ['Le signe actuel, simplement mis à plat : des créneaux qui montent comme un graphique. Garde la continuité avec l’icône déjà installée.', 'Tient plus du château fort que de la bastide, et le graphique en barres est un lieu commun des applications de finance.'],
};
P.logos = (theme) => `<div class="app sys" data-theme="${theme}" data-accent="encre">
  <h2>Le signe : Plan</h2>
  <p>« Bastide » désigne deux choses : dans le Sud-Ouest, une ville neuve médiévale au plan en damier autour d’une place à arcades ; en Provence, une maison de campagne. Les deux disent ce que fait l’application : vos comptes restent à l’abri, chez vous. Le signe retenu est le plan en damier, avec la place centrale au bleu d’accent.</p>
  ${['plan'].map(id => `<div class="row" style="gap:32px;padding:24px 0;border-top:1px solid var(--line);align-items:flex-start">
    <div class="row" style="gap:12px">${markSvg(id, '#17181a', '#ffffff', '#7fa6ff', 96)}<span style="border:1px solid var(--line2);border-radius:22px;display:block;height:96px">${markSvg(id, '#ffffff', '#17181a', '#2b5cd0', 96)}</span></div>
    <div class="col" style="gap:14px;width:230px"><div class="row" style="gap:10px;align-items:flex-end">${[32, 20, 16].map(s => markSvg(id, undefined, undefined, undefined, s)).join('')}<span class="t3 xs">32 · 20 · 16 px</span></div>
      <div class="row" style="gap:10px;font:600 22px var(--f);letter-spacing:-.02em">${markSvg(id, undefined, undefined, undefined, 30)}Bastide</div></div>
    <div class="col" style="gap:8px;flex:1"><span class="h" style="font-size:16px">${GLYPHS[id][0]}${id === 'plan' ? '' : ''}</span><span style="max-width:62ch">${LOGO_TXT[id][0]}</span><span class="note" style="max-width:62ch">${I('triangle-alert', 's14')}${LOGO_TXT[id][1]}</span></div></div>`).join('')}
  <h2>Le nom</h2>
  <p>Geist 600, interlettrage resserré, capitale initiale. Le signe est une tuile à l’encre, sans dégradé. Seule la place centrale prend le bleu d’accent. En petit (barre des tâches, 16 px), la tuile seule.</p>
  </div>`;

/* ── v3: textures ── */
const emptySpec = `<div class="col tex-fade" style="height:260px;align-items:center;justify-content:center;gap:10px;position:relative"><span class="h" style="font-size:16px;position:relative">Aucune donnée pour ce mois</span><span class="t2" style="position:relative;max-width:44ch;text-align:center">Importez un relevé OFX ou QFX pour voir vos revenus, vos dépenses et votre taux d’épargne.</span><span class="btn pri" style="position:relative">Aller aux imports</span></div>`;
const texSpec = (theme, tex) => `<div class="app" data-theme="${theme}" data-accent="encre" data-tex="${tex}" style="padding:0!important;overflow:hidden">
  <div style="display:grid;grid-template-columns:190px 1fr"><div class="rail" style="padding:12px 8px;min-height:260px"><div class="brand">${MARK}Bastide</div><div class="nav on">${I('layout-dashboard')}Tableau de bord</div><div class="nav">${I('wallet')}Comptes</div><div class="grow"></div><div class="local">${I('lock', 's14')}Données locales</div></div>${emptySpec}</div></div>`;
const goalSpec = (t, tex) => `<div class="app" data-theme="${t}" data-accent="encre" data-tex="${tex}" style="padding:0!important;overflow:hidden;background:var(--rail)"><div class="tex" style="height:120px;position:relative;border-bottom:1px solid var(--line)"><span class="btn" style="position:absolute;right:12px;top:12px">${I('image-plus', 's14')}Ajouter une image</span><div style="position:absolute;left:24px;bottom:14px" class="col"><span style="font:600 18px var(--f)">Fonds d’urgence</span><span class="t2 sm">Sans échéance</span></div></div><div class="col" style="padding:18px 24px;gap:12px"><div class="row" style="align-items:baseline"><span class="fig">6 400,00 €</span><span class="t2">sur 10 000,00 €</span><span class="sp"></span><span class="h">64 %</span></div>${meter(64)}</div></div>`;
const TEXS = [['tomettes', 'Tomettes', 'Le carreau hexagonal en terre cuite des sols de Provence. Le plus reconnaissable des trois, et le plus présent : un nid d’abeilles se remarque.'],
  ['tuiles', 'Tuiles', 'Les rangs de tuiles canal d’un toit provençal, vus de face. Plus doux et plus horizontal ; il suggère l’abri, le toit au-dessus des comptes.'],
  ['damier', 'Damier', 'Les îlots du plan d’une bastide, la même grille que le logo « Plan ». Le plus discret et le plus cohérent si ce logo est retenu ; le moins singulier sinon.']];
P.textures = (theme) => `<div class="app sys" data-theme="${theme}" data-accent="encre" data-tex="${S.tex === 'off' ? 'tomettes' : S.tex}">
  <h2>La matière : tomettes</h2>
  <p>Un motif au trait fin, à faible opacité : net sur un écran, valable dans les deux thèmes, et tiré du monde d’une bastide.</p>
  <p>La règle ne change pas : la matière habite les vides, jamais les chiffres. Elle ne passe ni derrière une table, ni derrière un graphique, ni dans un volet d’inspection.</p>
  ${TEXS.slice(0, 1).map(([id, n, d]) => `<div class="row" style="align-items:baseline;gap:12px;margin:28px 0 10px"><span class="h" style="font-size:16px">${n}</span><span class="t2" style="max-width:90ch">${d}</span></div><div class="pair">${texSpec('dark', id)}${texSpec('light', id)}</div>`).join('')}
  <h2>Où elle a sa place</h2>
  <table style="max-width:1000px"><tr><th>Endroit</th><th>Pourquoi</th><th>Comment</th></tr>
    ${[['Connexion et inscription', 'Le plus grand vide de l’application, et le premier écran vu.', 'Plein cadre, effacée en halo derrière le formulaire.'],
      ['États vides', 'Un panneau sans donnée est une page blanche ; la matière dit que c’est voulu.', 'Derrière la phrase et le bouton, effacée vers les bords.'],
      ['Bas de la barre latérale', 'L’espace entre le menu et « Données locales » ne sert à rien d’autre.', 'Fondue en haut et en bas, jamais sous un libellé.'],
      ['Objectif sans image', 'Le bandeau garde sa hauteur même sans photo.', 'La matière à la place de l’image, avec « Ajouter une image ».'],
      ['À propos', 'Le seul écran où l’application parle d’elle-même.', 'Bandeau derrière le logo et la version.']].map(r => `<tr><td style="font-weight:500">${r[0]}</td><td class="t2 wrap">${r[1]}</td><td class="t2 wrap">${r[2]}</td></tr>`).join('')}</table>
  <h2>Objectif sans image</h2>
  <div class="pair">${['dark', 'light'].map(t => goalSpec(t, 'tomettes')).join('')}</div>
  <h2>Une matière utile : la hachure</h2>
  <p>Dans les graphiques, une hachure marque ce qui n’est pas encore un fait : le mois en cours, une valeur de placement entre deux saisies, une projection. Elle remplace le contour en pointillés, se lit sans la couleur.</p>
  <div style="max-width:640px">${savChart(620, 200)}</div>
  <h2>Ce que je laisse de côté</h2>
  <p>Le grain photographique et le bruit sur toute la fenêtre : c’est l’effet retiré dans SLOP.md, et il salit les aplats. Les textures de papier ou de pierre en image : elles pèsent, vieillissent mal et ne suivent pas les deux thèmes.</p>
  </div>`;

/* ── v5: installer splash, 560 × 320 like frontend/windows/installer/splash.png ── */
const HEX = (stroke, op) => `<pattern id="tm${op}" width="24.25" height="42" patternUnits="userSpaceOnUse"><path d="M0 7 12.125 0l12.125 7M0 7v14M24.25 7v14M0 21l12.125 7 12.125-7M12.125 28v14" fill="none" stroke="${stroke}" stroke-opacity="${op}"/></pattern>`;
const splashSvg = (dark, pct = 62, w = 560) => {
  const c = dark ? { bg: '#111214', tx: '#ecedef', t2: '#a3a7ae', tile: '#ecedef', on: '#111214', ac: '#7fa6ff', tr: '#25272b', st: '#fff' } : { bg: '#ffffff', tx: '#17181a', t2: '#5a5e65', tile: '#17181a', on: '#ffffff', ac: '#2b5cd0', tr: '#e6e7e9', st: '#000' };
  const k = dark ? 'd' : 'l';
  return `<svg width="${w}" viewBox="0 0 560 320" role="img" aria-label="Écran d’installation de Bastide" style="display:block;border-radius:${w > 560 ? 0 : 0}px">
    <defs>${HEX(c.st, dark ? '.09' : '.08').replace('id="tm', 'id="tm' + k)}<radialGradient id="fd${k}" cx="50%" cy="46%" r="62%"><stop offset=".28" stop-color="${c.bg}"/><stop offset="1" stop-color="${c.bg}" stop-opacity="0"/></radialGradient></defs>
    <rect width="560" height="320" fill="${c.bg}"/><rect width="560" height="320" fill="url(#tm${k}${dark ? '.09' : '.08'})"/><rect width="560" height="320" fill="url(#fd${k})"/>
    <g transform="translate(248 84) scale(2.667)"><rect width="24" height="24" rx="5.3" fill="${c.tile}"/>${GLYPHS.plan[1](c.on, c.ac)}</g>
    <text x="280" y="190" text-anchor="middle" style="font:600 26px Geist,system-ui,sans-serif;letter-spacing:-.02em" fill="${c.tx}">Bastide</text>
    <text x="280" y="216" text-anchor="middle" style="font:400 13px Geist,system-ui,sans-serif" fill="${c.t2}">Vos données restent sur cet ordinateur.</text>
    <rect y="308" width="560" height="12" fill="${c.tr}"/><rect y="308" width="${5.6 * pct}" height="12" fill="${c.ac}"/></svg>`;
};
P.splash = (theme) => `<div class="app sys" data-theme="${theme}" data-accent="encre">
  <h2>Écran d’installation</h2>
  <p>L’installeur Windows (Velopack) affiche une image fixe de <b>560 × 320 px</b>, à l’échelle de l’écran, pendant qu’il copie l’application. Il dessine lui-même la progression : une bande de 12 px sur le bord bas de l’image. L’image ne peut donc porter ni texte qui change ni animation.</p>
  <div class="row" style="gap:32px;align-items:flex-start;flex-wrap:wrap">
    <div class="col" style="gap:8px"><div style="box-shadow:var(--shadow);border:1px solid var(--line2)">${splashSvg(true)}</div><span class="h">Sombre · recommandé</span><span class="t2 sm" style="max-width:560px">Le thème de référence. La bande de progression est au bleu d’accent sombre, #7FA6FF.</span></div>
    <div class="col" style="gap:8px"><div style="box-shadow:var(--shadow);border:1px solid var(--line2)">${splashSvg(false)}</div><span class="h">Clair · variante</span><span class="t2 sm" style="max-width:560px">Même composition. Bande de progression #2B5CD0. Une seule des deux images est livrée.</span></div></div>
  <h2>Composition</h2>
  <table style="max-width:1000px"><tr><th>Élément</th><th>Valeur</th></tr>
  ${[['Format', 'PNG 560 × 320 px, source SVG à côté (frontend/windows/installer/splash.svg), sans transparence'],
    ['Fond', 'Fond du thème (#111214), tomettes à 9 % d’opacité, effacées par un halo centré derrière le signe'],
    ['Signe', 'Plan, tuile de 64 px, centrée, bord haut à 84 px'],
    ['Nom', '« Bastide », Geist 600, 26 px, interlettrage −0,02 em, ligne de base à 190 px'],
    ['Phrase', '« Vos données restent sur cet ordinateur. », Geist 400, 13 px, ton secondaire, ligne de base à 216 px ; la seule phrase, identique dans toutes les langues de l’installeur faute de traduction possible'],
    ['Zone réservée', 'Les 12 px du bas : piste #25272B dans l’image, remplissage dessiné par l’installeur (--splashProgressColor #7FA6FF)'],
    ['Interdits', 'Dégradé, halo coloré, numéro de version, slogan, texte « Installation… » (l’installeur ne le traduit pas)']].map(r => `<tr><td style="font-weight:500;width:160px">${r[0]}</td><td class="t2 wrap">${r[1]}</td></tr>`).join('')}</table>
  <h2>Progression</h2>
  <div class="row" style="gap:24px;flex-wrap:wrap">${[8, 40, 100].map(n => `<div class="col" style="gap:6px"><div style="border:1px solid var(--line2)">${splashSvg(true, n, 280)}</div><span class="t3 sm">${n} %</span></div>`).join('')}</div>
  <h2>Au lancement de l’application</h2>
  <p>L’écran de démarrage de l’application (attente du moteur local) reprend la même composition dans la fenêtre : signe, nom, phrase, sur tomettes. La bande est remplacée par une ligne d’état sous la phrase (« Démarrage du moteur local… »), car là le texte peut être traduit.</p>
  </div>`;

/* ── design system page ── */
function sample() {
  return `<div class="col" style="gap:18px">
    <div class="row" style="gap:32px;align-items:flex-end"><div class="col" style="gap:8px;width:240px"><span class="t2 sm">Taux d’épargne</span><span class="fig xl">22,3 %</span><div style="padding-top:18px">${meter(55.75, 50, 'objectif 20 %')}</div></div>
      <div class="col" style="gap:6px"><span class="t2 sm">Net</span><span class="fig pos">+635,65 €</span><span class="st neg">${I('trending-down')}6,1 %<span class="t3">vs avril</span></span></div></div>
    <div class="row"><span class="btn pri">${I('plus', 's14')}Nouvel objectif</span><span class="btn">Modifier</span><span class="btn ghost">Annuler</span><span class="btn danger">Réinitialiser…</span><span class="seg"><span class="on">12 mois</span><span>Tout</span></span><span class="tog on"></span><span class="chk on">${I('check')}</span></div>
    <div class="row"><span class="inp focus" style="width:200px">320 000,00 €</span><span class="sel">Toutes les catégories${I('chevron-down', 's14')}</span><span class="inp search">${I('search', 's14')}Rechercher<kbd>Ctrl K</kbd></span></div>
    <table><tr><th>Opération</th><th>Catégorie</th><th class="n">Montant</th></tr>
      <tr><td><span class="row">${mg('CA')}Carrefour</span></td><td>${cat('Alimentation', 'Courses')}</td><td class="n">${amt('−86,42 €')}</td></tr>
      <tr class="cur"><td><span class="row">${mg('NV')}Salaire Novatech SARL</span></td><td>${cat('Revenus', 'Salaire')}</td><td class="n">${amt('+2 850,00 €')}</td></tr>
      <tr><td><span class="row">${mg('?')}<span class="mono">CB NOVATECH SAS 12/05</span></span></td><td>${cat(null)}</td><td class="n">${amt('−49,90 €')}</td></tr></table>
    <div class="row"><span class="st pos">${I('check')}Objectif atteint</span><span class="st warn">${I('triangle-alert')}Au-dessus du repère</span><span class="st neg">${I('circle-x')}Échec</span><span class="st t2">${I('lock')}Données locales</span></div>
    <div style="max-width:420px">${savChart(420, 150)}</div></div>`;
}
P.system = (theme, accent) => {
  const sw = (list) => `<div class="sw">${list.map(([v, n]) => `<div><i style="background:var(--${v})"></i>${n}<br><span class="t3 mono">--${v}</span></div>`).join('')}</div>`;
  return `<div class="app sys" data-theme="${theme}" data-accent="${accent}">
  <h2>Principes</h2>
  <p>Trois références fixent le niveau : la densité et la discipline de Linear et Raycast, le calme de Things, les chiffres assurés de Mercury et Qonto. Le système ne fournit que quatre choses : une typographie, une palette, une densité et un geste propre à Bastide.</p>
  <p><b>Le geste : le repère.</b> Bastide compare sans cesse une valeur à une référence : le taux d’épargne à son objectif, le taux d’endettement au repère HCSF de 35 %, un objectif à sa cible, un crédit à son capital. Une seule forme le dit partout : une barre fine et un trait vertical étiqueté. Elle remplace les anneaux, les jauges teintées et les cartes « héros ».</p>
  <p><b>Ce qui disparaît :</b> dégradés, halos, grain, liseré lumineux, cartes teintées, pastilles, plaques d’icône, majuscules espacées, Space Grotesk. <b>Ce qui reste :</b> Geist, Lucide, les montants signés en chiffres tabulaires, les monogrammes.</p>
  <h2>Deux thèmes, même structure</h2>
  <p>Sombre : graphite neutre, pour le soir à la maison. Clair : blanc et gris froid, pour la journée près d’une fenêtre. Le thème suit le réglage du système et se change dans Paramètres. Chaque couleur est choisie pour son thème, pas inversée.</p>
  <div class="pair"><div class="app" data-theme="dark" data-accent="${accent}">${sample()}</div><div class="app" data-theme="light" data-accent="${accent}">${sample()}</div></div>
  <h2>Surfaces et encres (thème affiché)</h2>
  ${sw([['bg', 'Fond'], ['rail', 'Barre latérale, volets'], ['surface', 'Popover, carte'], ['hover', 'Survol, sélection neutre'], ['line', 'Filet'], ['line2', 'Bord de contrôle'], ['tx', 'Texte'], ['tx2', 'Texte secondaire']])}
  <h2>Accent et sens</h2>
  <p>Accent retenu : <b>encre + bleu</b>. Les boutons principaux sont à l’encre, le bleu sert la sélection, les liens, le focus et les barres. Vert et rouge sont réservés au signe de l’argent, l’ambre à ce qui mérite un regard.</p>
  ${sw([['btn', 'Bouton principal'], ['ac', 'Accent'], ['pos', 'Entrée, atteint'], ['neg', 'Sortie, échec'], ['warn', 'À regarder'], ['tx3', 'Texte discret']])}
  <h2>Catégories</h2>
  <p>Six teintes fixes dans cet ordre, plus un gris pour « Autres ». Une teinte suit sa catégorie partout, toujours à côté de son nom.</p>
  ${sw([['c1', 'Logement'], ['c2', 'Alimentation'], ['c3', 'Transport'], ['c4', 'Abonnements'], ['c5', 'Loisirs'], ['c6', 'Santé'], ['c0', 'Autres']])}
  <h2>Typographie</h2>
  <p>Geist seul, trois graisses (400, 500, 600). Geist Mono pour les libellés bruts de la banque, les motifs de règle et les adresses. Six tailles.</p>
  <div class="col" style="gap:10px"><span class="fig xl">40 · 22,3 % <span class="t3 sm" style="letter-spacing:0;font-weight:400">chiffre principal du panneau, 600</span></span><span class="fig">28 · +2 850,00 € <span class="t3 sm" style="letter-spacing:0;font-weight:400">chiffres secondaires, 600</span></span><span class="fig md">20 · 234 129,21 € <span class="t3 sm" style="font-weight:400">chiffres d’appoint, 600</span></span><span style="font:600 14px var(--f)">14 · Titre de panneau, 600</span><span>13 · Texte courant et lignes de table, 400. Titres de section en 600.</span><span class="sm t2">12 · Libellés, en-têtes de colonne, légendes, 400</span><span class="xs t3">11,5 · Notes et axes de graphique. Rien en dessous.</span></div>
  <h2>Forme et densité</h2>
  <p>Rayon 6 sur les contrôles, 8 sur les conteneurs. Barre latérale 224 px, barre de titre 48 px, lignes de table 36 px, contrôles 28 px, champs 32 px. Espacements sur une grille de 4 : 8 dans un groupe, 24 entre sections, 32 de marge de page. Une carte ne sert qu’à ce qui flotte (popover, modale, toast) ; les sections d’une page se séparent par l’espace et un filet. L’élévation n’existe que pour ce qui flotte.</p>
  <h2>Mouvement</h2>
  <p>Survols immédiats. 120 ms en sortie douce pour l’ouverture d’un popover ou d’un volet. Une barre de repère se remplit une fois, en 240 ms, quand sa valeur change. Tout s’arrête avec le réglage « réduire les animations ».</p>
  </div>`;
};

/* ════════ Viewer ════════ */
const LIST = [['Système', [['system', 'Système de design'], ['logos', 'Logo'], ['textures', 'Texture'], ['splash', 'Écran d’installation']]], ['Accès', [['login', 'Connexion'], ['register', 'Inscription']]],
  ['Vue d’ensemble', [['dashboard', 'Tableau de bord'], ['accounts', 'Comptes'], ['account', 'Détail d’un compte'], ['transactions', 'Transactions']]],
  ['Gestion', [['imports', 'Imports'], ['categories', 'Catégories et règles'], ['subscriptions', 'Abonnements'], ['goals', 'Objectifs']]],
  ['Patrimoine', [['loans', 'Crédits'], ['investments', 'Placements'], ['simulator', 'Simulateur'], ['networth', 'Synthèse']]], ['Réglages', [['settings', 'Paramètres']]]];
const S = Object.assign({ panel: 'dashboard', variant: 'A', theme: 'dark', accent: 'encre', bare: '' }, Object.fromEntries(new URLSearchParams(location.hash.slice(1))));
S.accent = 'encre';
const DOCS = ['system', 'logos', 'textures', 'splash'];
S.logo = 'plan'; S.tex = 'tomettes';
const $ = s => document.querySelector(s);
function render() {
  MARK = markSvg(S.logo); TEX = S.tex !== 'off' || S.panel === 'textures';
  const p = P[S.panel], fit = $('#fit'), multi = typeof p === 'object';
  if (multi && !p[S.variant]) S.variant = 'A';
  let html = DOCS.includes(S.panel) ? p(S.theme, S.accent) : multi ? p[S.variant][1]() : p();
  if (!DOCS.includes(S.panel)) html = html.startsWith('<div class="app') ? html.replace('<div class="app', `<div data-theme="${S.theme}" data-accent="${S.accent}" data-tex="${S.tex}" class="app`) : `<div class="app" data-theme="${S.theme}" data-accent="${S.accent}" data-tex="${S.tex}">${html}</div>`;
  fit.innerHTML = html; fit.classList.toggle('doc', DOCS.includes(S.panel));
  $('#g-var').style.display = multi ? '' : 'none';
  $('#s-var').innerHTML = multi ? Object.entries(p).map(([k, v]) => `<button data-v="${k}">${v[0]}</button>`).join('') : '';
  for (const [id, key] of [['#s-var', 'variant'], ['#s-theme', 'theme']]) document.querySelectorAll(id + ' button').forEach(b => { b.setAttribute('aria-pressed', b.dataset.v === S[key]); b.onclick = () => { S[key] = b.dataset.v; render(); }; });
  document.querySelectorAll('#v-nav button').forEach(b => b.setAttribute('aria-current', b.dataset.v === S.panel));
  history.replaceState(null, '', '#' + new URLSearchParams(S));
  if (window.lucide) lucide.createIcons();
  scale();
}
function scale() {
  if (S.bare) return; const st = $('.v-stage'), fit = $('#fit'), k = Math.min(1, (st.clientWidth - 40) / 1440);
  fit.style.transform = `scale(${k})`; fit.style.marginBottom = `${-(fit.offsetHeight * (1 - k))}px`; fit.style.marginRight = `${-(1440 * (1 - k))}px`;
}
if (S.bare) document.body.classList.add('bare');
$('#v-nav').innerHTML = LIST.map(([g, items]) => `<p>${g}</p>` + items.map(([id, l]) => `<button data-v="${id}">${l}</button>`).join('')).join('');
document.querySelectorAll('#v-nav button').forEach(b => b.onclick = () => { S.panel = b.dataset.v; render(); });
addEventListener('resize', scale); render();
