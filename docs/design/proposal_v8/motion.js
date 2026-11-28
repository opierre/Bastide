/* Bastide redesign proposal v8 — motion (ticket #366). Loaded before panels.js, which reads MOTION.page and calls MOTION.init after each render.
   Three motion systems play the same scenes side by side. Every figure, merchant and file name is invented. */
const MOTION = (() => {
  /* One table drives both the token lists on the page and the scenes, so what is written is what plays. */
  const T = {
    a: { name: 'Net', in: 120, out: 80, move: 0, measure: 240, moment: 0, ease: 'cubic-bezier(.33,1,.68,1)', curve: 'easeOutCubic' },
    b: { name: 'Repère', in: 120, out: 80, move: 180, measure: 320, moment: 0, ease: 'cubic-bezier(.25,1,.5,1)', curve: 'easeOutQuart' },
    c: { name: 'Atelier', in: 200, out: 120, move: 240, measure: 400, moment: 600, ease: 'cubic-bezier(.16,1,.3,1)', curve: 'easeOutExpo' },
  };
  const HASH = new URLSearchParams(location.hash.slice(1));
  /* #only=<scene>&exit=1 starts a modal or a toast open and plays its exit alone, to capture it. */
  const MO = { exit: HASH.get('exit') === '1', speed: 1, reduced: matchMedia('(prefers-reduced-motion: reduce)').matches, state: {}, run: {} };
  /* Reduced motion. A keeps today's rule, every duration 0. B and C keep the fades at A's pace and drop travel, growth and counting. */
  const tok = m => {
    const t = T[m];
    if (!MO.reduced) return { ...t, travel: true, hold: true };
    return m === 'a' ? { ...t, in: 0, out: 0, move: 0, measure: 0, moment: 0, travel: false, hold: false }
      : { ...t, in: 120, out: 80, move: 0, measure: 0, moment: 0, travel: false, hold: true };
  };
  const ms = n => `${n}&nbsp;ms`;
  const nf = new Intl.NumberFormat('fr-FR');
  const eur = n => `${nf.format(Math.round(n))} €`;

  /* The end state is written to the element first; the animation only plays towards it. A cancelled or skipped animation still lands right. */
  function go(el, frames, d, o = {}) {
    if (!el) return Promise.resolve();
    el.getAnimations().forEach(a => a.cancel());
    const { offset, easing, ...end } = frames[frames.length - 1]; Object.assign(el.style, end);
    const delay = (o.delay || 0) / MO.speed;
    if (d <= 0 && !delay) return Promise.resolve();
    return el.animate(frames, { duration: Math.max(d, 0) / MO.speed, delay, easing: o.ease || 'linear', fill: 'backwards' }).finished.catch(() => {});
  }
  const wait = n => new Promise(r => setTimeout(r, n / MO.speed));
  /* A figure counts on the clock of an animation of its own, so it shares the curve and the timeline of what moves beside it. */
  function count(el, from, to, d, ease, fmt, alive, delay = 0) {
    el.getAnimations().forEach(a => a.cancel());
    if (d <= 0 || from === to) { el.textContent = fmt(to); return; }
    el.textContent = fmt(from);
    const clock = el.animate(null, { duration: d / MO.speed, delay: delay / MO.speed, easing: ease });
    const tick = () => {
      if (!alive() || clock.playState === 'idle') return;
      const k = clock.effect.getComputedTiming().progress;
      if (clock.playState === 'finished') { el.textContent = fmt(to); return; }
      if (k != null) el.textContent = fmt(from + (to - from) * Math.min(1, Math.max(0, k)));
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }
  const q = (el, s) => el.querySelector(s);
  const rise = (t, px) => t.travel ? `translateY(${px}px)` : 'none';

  /* ════════ Scenes: build(m) draws one column, play(col, m, step, alive) plays it ════════ */
  const TX = [['12 mai', 'BC', 'Boulangerie du Cours', '−6,40 €', 'Alimentation', 'c2'], ['11 mai', 'LO', 'Loyer', '−980,00 €', 'Logement', 'c1'], ['10 mai', 'PG', 'Pharmacie de la Gare', '−18,90 €', 'Santé', 'c6'], ['9 mai', 'SA', 'Salaire', '+2 850,00 €', 'Revenus', 'pos']];
  const MONTHS = [['Mai 2026', 1240, [980, 520, 210, 160]], ['Avril 2026', 860, [980, 610, 340, 90]]];
  const CATN = [['Logement', 'c1'], ['Alimentation', 'c2'], ['Transport', 'c3'], ['Loisirs', 'c5']];
  const NAVS = [['layout-dashboard', 'Tableau de bord', 'Mai 2026', '1 240 €', 'épargnés ce mois'], ['wallet', 'Comptes', '3 comptes', '14 620 €', 'au total'], ['arrow-left-right', 'Transactions', '86 ce mois', '12', 'à vérifier'], ['flag', 'Objectifs', '2 objectifs', '62 %', 'du premier atteint']];
  const insp = i => { const [d, mgm, n, a, c, col] = TX[i]; return `<div class="row"><span class="mg lg">${mgm}</span><div class="col"><b style="font-weight:600">${n}</b><span class="t3 sm">${d} 2026</span></div></div><div class="fig md ${a.startsWith('+') ? 'pos' : ''}" style="margin-top:14px">${a}</div><div class="hr" style="margin:12px 0"></div><span class="cat"><span class="dot" style="--c:var(--${col})"></span>${c}</span><div class="t3 sm" style="margin-top:6px">Compte courant</div>`; };
  const page = i => { const [, , sub, fig, lab] = NAVS[i]; return `<div class="t2 sm">${sub}</div><div class="row" style="align-items:baseline;margin-top:2px"><span class="fig md">${fig}</span><span class="t2">${lab}</span></div><div class="hr" style="margin:14px 0 0"></div>${[72, 54, 63].map(w => `<div class="row" style="height:32px;border-bottom:1px solid var(--line)"><span class="sk" style="width:${w}%;height:8px"></span></div>`).join('')}`; };

  const SC = [
    {
      id: 'modal', h: 300, title: 'Modale', now: 'Aujourd’hui : fondu de 120 ms à l’ouverture comme à la fermeture.',
      spec: { a: `Voile et modale en fondu, ${ms(120)}. Sortie plus courte, ${ms(80)}.`, b: `Comme A, plus 4 px de montée, le trajet des popovers d’aujourd’hui.`, c: `La modale vient de la profondeur : échelle 0,97 vers 1 et fondu, ${ms(200)}. Sortie ${ms(120)}.` },
      build: () => `<div style="padding:16px 20px">${TX.slice(0, 4).map(r => `<div class="row" style="height:36px;border-bottom:1px solid var(--line)"><span class="mg">${r[1]}</span>${r[2]}<span class="sp"></span><span class="t2">${r[3]}</span></div>`).join('')}</div>
        <div class="mo-scrim" style="opacity:0"></div>
        <div class="mo-center"><div class="modal" style="width:320px;opacity:0"><header><h2>Supprimer ce compte ?</h2><p>Ses 86 transactions seront supprimées avec lui.</p></header><footer><span class="btn">Annuler</span><span class="btn dsolid">Supprimer</span></footer></div></div>`,
      init(col) { if (MO.exit) { col.dataset.open = 1; q(col, '.mo-scrim').style.opacity = q(col, '.modal').style.opacity = 1; } },
      async play(col, m, step, alive) {
        const t = tok(m), sc = q(col, '.mo-scrim'), md = q(col, '.modal');
        const from = m === 'c' && t.travel ? 'scale(.97)' : m === 'b' ? rise(t, 4) : 'none';
        /* a second click while it is open only restarts the hold: the entrance never replays over a visible modal */
        if (!col.dataset.open) {
          col.dataset.open = 1;
          go(sc, [{ opacity: 0 }, { opacity: 1 }], t.in, { ease: t.ease });
          await go(md, [{ opacity: 0, transform: from }, { opacity: 1, transform: 'none' }], t.in, { ease: t.ease });
        }
        if (!MO.exit) await wait(1100); if (!alive()) return;
        delete col.dataset.open;
        go(sc, [{ opacity: 1 }, { opacity: 0 }], t.out, { ease: t.ease });
        go(md, [{ opacity: 1, transform: 'none' }, { opacity: 0, transform: m === 'c' && t.travel ? 'scale(.985)' : 'none' }], t.out, { ease: t.ease });
      },
    },
    {
      id: 'toast', h: 132, title: 'Toast', now: 'Aujourd’hui : entrée de 120 ms sur 4 px, puis disparition sans transition au bout de 4 s.',
      spec: { a: `Entrée inchangée. Le toast gagne une sortie : fondu, ${ms(80)}.`, b: `Comme A, et la sortie refait les 4 px en sens inverse.`, c: `Entrée sur 12 px, ${ms(200)}. Sortie sur 8 px, ${ms(120)}.` },
      build: () => `<div class="mo-toast" style="opacity:0"><span class="pos row">${I('check', 's14')}</span>Compte supprimé</div>`,
      init(col) { if (MO.exit) { col.dataset.open = 1; q(col, '.mo-toast').style.opacity = 1; } },
      async play(col, m, step, alive) {
        const t = tok(m), el = q(col, '.mo-toast'), d = m === 'c' ? [12, 8] : [4, m === 'b' ? 4 : 0];
        if (!col.dataset.open) { col.dataset.open = 1; await go(el, [{ opacity: 0, transform: rise(t, d[0]) }, { opacity: 1, transform: 'none' }], t.in, { ease: t.ease }); }
        if (!MO.exit) await wait(1400); if (!alive()) return;
        delete col.dataset.open;
        go(el, [{ opacity: 1, transform: 'none' }, { opacity: 0, transform: rise(t, d[1]) }], t.out, { ease: t.ease });
      },
    },
    {
      id: 'controls', h: 168, title: 'Bascule, segments, onglets', now: 'Aujourd’hui : tout change d’un coup. Le bouton de la bascule saute d’un bord à l’autre.',
      spec: { a: `Changement immédiat, comme le veut §13. Rien à construire.`, b: `Ce qui est sélectionné se déplace : bascule ${ms(120)}, segment et soulignement ${ms(180)}.`, c: `Même principe, plus ample : bascule ${ms(200)}, segment et soulignement ${ms(240)}.` },
      build: () => `<div class="col" style="padding:18px 20px;gap:16px">
        <div class="row">Catégoriser avec le modèle local<span class="sp"></span><span class="mo-tog"><i></i></span></div>
        <div class="row"><span class="t2">Période</span><span class="sp"></span><span class="mo-seg"><b></b><span class="on">Mois</span><span>Trimestre</span><span>Année</span></span></div>
        <div class="mo-tabs"><span class="on">Catégories <span class="t3">14</span></span><span>Règles <span class="t3">32</span></span><i></i></div></div>`,
      init(col) { const tab = q(col, '.mo-tabs .on'), u = q(col, '.mo-tabs i'); u.style.left = tab.offsetLeft + 'px'; u.style.width = tab.offsetWidth + 'px'; },
      play(col, m, step) {
        const t = tok(m), on = step % 2 === 1, e = { ease: t.ease };
        const tg = q(col, '.mo-tog'), kn = q(tg, 'i');
        go(tg, [{ background: on ? 'var(--line2)' : 'var(--ac)' }, { background: on ? 'var(--ac)' : 'var(--line2)' }], t.move ? t.in : 0, e);
        go(kn, [{ transform: `translateX(${on ? 0 : 12}px)` }, { transform: `translateX(${on ? 12 : 0}px)` }], t.move ? t.in : 0, e);
        const sg = [...col.querySelectorAll('.mo-seg span')], i = step % 3, prev = (step + 2) % 3;
        sg.forEach((s, k) => s.classList.toggle('on', k === i));
        go(q(col, '.mo-seg b'), [{ transform: `translateX(${prev * 100}%)` }, { transform: `translateX(${i * 100}%)` }], t.move, e);
        const tabs = [...col.querySelectorAll('.mo-tabs>span')], cur = tabs[step % 2], old = tabs[(step + 1) % 2];
        tabs.forEach(s => s.classList.toggle('on', s === cur));
        go(q(col, '.mo-tabs i'), [{ left: old.offsetLeft + 'px', width: old.offsetWidth + 'px' }, { left: cur.offsetLeft + 'px', width: cur.offsetWidth + 'px' }], t.move, e);
      },
    },
    {
      id: 'month', h: 270, title: 'Changer de mois', now: 'Aujourd’hui : le repère glisse en 240 ms, les chiffres et les barres sont remplacés d’un coup.',
      spec: { a: `Inchangé : seul le repère bouge, ${ms(240)}.`, b: `Une seule horloge de ${ms(320)} : le chiffre du haut compte, le repère et les barres vont de l’ancienne valeur à la nouvelle. Les montants des lignes changent d’un coup.`, c: `Comme B en ${ms(400)}, les barres partent l’une après l’autre, à 40 ms d’écart.` },
      build: () => `<div class="col" style="padding:18px 20px">
        <div class="row"><span class="h" data-k="month">${MONTHS[0][0]}</span><span class="sp"></span><span class="t3 row">${I('chevron-left')}${I('chevron-right')}</span></div>
        <div class="t2 sm" style="margin-top:10px">Épargné ce mois</div><div class="fig" data-k="fig">${eur(MONTHS[0][1])}</div>
        <div class="meter" style="--v:62%;--m:50%;margin:26px 0 20px"><i data-k="fill"></i><b data-l="Objectif 1 000 €"></b></div>
        ${CATN.map(([n, c], k) => `<div class="mo-bar"><span class="cat"><span class="dot" style="--c:var(--${c})"></span>${n}</span><span class="mo-track"><i style="--c:var(--${c});width:${MONTHS[0][2][k] / 10}%"></i></span><span class="t2" data-k="amt">${eur(MONTHS[0][2][k])}</span></div>`).join('')}</div>`,
      play(col, m, step, alive) {
        const t = tok(m), [name, saved, cats] = MONTHS[step % 2], [, pSaved, pCats] = MONTHS[(step + 1) % 2], data = m === 'a' ? 0 : t.measure;
        q(col, '[data-k=month]').textContent = name;
        count(q(col, '[data-k=fig]'), pSaved, saved, data, t.ease, eur, alive);
        go(q(col, '[data-k=fill]'), [{ width: pSaved / 20 + '%' }, { width: saved / 20 + '%' }], t.measure, { ease: t.ease });
        col.querySelectorAll('.mo-bar').forEach((row, k) => {
          const delay = m === 'c' && t.travel ? k * 40 : 0;
          go(q(row, '.mo-track i'), [{ width: pCats[k] / 10 + '%' }, { width: cats[k] / 10 + '%' }], data, { ease: t.ease, delay });
          q(row, '[data-k=amt]').textContent = eur(cats[k]);
        });
      },
    },
    {
      id: 'inspector', h: 232, title: 'Sélection et volet', now: 'Aujourd’hui : le nouveau contenu du volet apparaît en 120 ms, l’ancien part aussitôt. Le volet reste donc vide ou pâle pendant environ 70 ms.',
      spec: { a: `Inchangé : fondu du contenu, ${ms(120)}. Le volet passe par le vide à chaque sélection.`, b: `Le contenu est remplacé d’un coup : une autre ligne est un autre objet, et le volet ne se vide jamais. Le fondu reste pour le volet qui s’ouvre.`, c: `Le contenu entre par la droite : 8 px et fondu, ${ms(200)}.` },
      build: () => `<div class="mo-split" style="grid-template-columns:1fr 168px"><div style="padding:14px 0 0 20px">${TX.map((r, k) => `<div class="mo-row${k ? '' : ' cur'}"><span class="mg">${r[1]}</span><span class="el">${r[2]}</span><span class="sp"></span><span class="${r[3].startsWith('+') ? 'pos' : ''}">${r[3]}</span></div>`).join('')}</div>
        <div class="mo-insp"><div data-k="insp">${insp(0)}</div></div></div>`,
      play(col, m, step) {
        const t = tok(m), i = step % TX.length, box = q(col, '[data-k=insp]');
        col.querySelectorAll('.mo-row').forEach((r, k) => r.classList.toggle('cur', k === i));
        box.innerHTML = insp(i);
        if (m !== 'b') go(box, [{ opacity: 0, transform: m === 'c' && t.travel ? 'translateX(8px)' : 'none' }, { opacity: 1, transform: 'none' }], t.in, { ease: t.ease });
      },
    },
    {
      id: 'import', h: 232, title: 'Import terminé', now: 'Aujourd’hui : la ligne apparaît surlignée, puis le surlignage est coupé net au bout de 4 s. La démonstration raccourcit ces 4 s.',
      spec: { a: `La ligne apparaît d’un coup. Le surlignage s’éteint en ${ms(240)} au lieu d’être coupé.`, b: `La ligne ouvre sa place en ${ms(180)} et pousse l’historique. Le surlignage s’estompe sur sa dernière seconde.`, c: `Le moment de l’application : la ligne ouvre sa place en ${ms(240)}, le nombre de transactions compte en ${ms(600)}, le surlignage tient puis décroît de plus en plus vite sur les 4 s.` },
      build: () => `<div class="col" style="padding:14px 20px 0"><div class="row" style="height:28px"><span class="h">Historique</span><span class="sp"></span><span class="t3 sm" data-k="n">3 imports</span></div>
        <div class="mo-new" style="height:0"><div class="mo-tint"></div><div class="mo-row" data-k="line"><span class="mono">releve-mai.ofx</span><span class="sp"></span><span class="t2"><span data-k="tx">42</span> transactions</span><span class="t3 sm" style="width:64px;text-align:right">À l’instant</span></div></div>
        ${[['releve-avril.ofx', '38', '2 mai'], ['releve-mars.ofx', '51', '3 avr.'], ['releve-fevrier.ofx', '44', '1er mars']].map(r => `<div class="mo-row"><span class="mono">${r[0]}</span><span class="sp"></span><span class="t2">${r[1]} transactions</span><span class="t3 sm" style="width:64px;text-align:right">${r[2]}</span></div>`).join('')}</div>`,
      async play(col, m, step, alive) {
        const t = tok(m), box = q(col, '.mo-new'), tint = q(col, '.mo-tint'), line = q(col, '[data-k=line]'), n = q(col, '[data-k=n]'), tx = q(col, '[data-k=tx]');
        [box, tint, line].forEach(e => e.getAnimations().forEach(a => a.cancel()));
        if (step > 1) { box.style.height = '0'; n.textContent = '3 imports'; await wait(260); if (!alive()) return; }
        go(box, [{ height: '0px' }, { height: '36px' }], t.move, { ease: t.ease }).then(() => { if (alive()) n.textContent = '4 imports'; });
        go(line, [{ opacity: 0, transform: m === 'c' ? rise(t, -6) : 'none' }, { opacity: 1, transform: 'none' }], m === 'a' ? 0 : t.in, { ease: t.ease });
        count(tx, 0, 42, t.moment, t.ease, v => String(Math.round(v)), alive);
        const hold = +HASH.get('hold') || 2400, tail = Math.min(1000, hold / 2); /* #hold=<ms> shortens the demo's hold, to capture the opening finely */
        /* B and C: the tint comes in with the line, so a highlighted band is never shown empty */
        if (m === 'c') go(tint, [{ opacity: 0 }, { opacity: 1, offset: t.in / hold, easing: 'cubic-bezier(.6,0,1,1)' }, { opacity: 0 }], hold);
        else if (m === 'b') go(tint, [{ opacity: 0 }, { opacity: 1, offset: t.in / hold }, { opacity: 1, offset: 1 - tail / hold }, { opacity: 0 }], hold);
        else go(tint, [{ opacity: 1 }, { opacity: 0 }], t.measure, { delay: hold - t.measure, ease: t.ease });
      },
    },
    {
      id: 'panel', h: 232, title: 'Changer de panneau', now: 'Aujourd’hui : ni le thème ni le routeur ne règlent la transition, c’est donc celle de Material par défaut qui joue. Lu dans le code, à confirmer à l’écran.',
      spec: { a: `Aucune transition, déclarée dans le routeur. Le panneau est là, comme le veut §13.`, b: `Identique à A. Changer de panneau n’est pas un changement de valeur.`, c: `Le corps du panneau arrive en fondu sur 6 px, ${ms(200)}. La barre latérale et la barre de titre ne bougent pas.` },
      build: () => `<div class="mo-split" style="grid-template-columns:160px 1fr"><div class="mo-rail">${NAVS.map((r, k) => `<div class="nav${k ? '' : ' on'}">${I(r[0])}${r[1]}</div>`).join('')}</div>
        <div class="col"><div class="row" style="height:40px;padding:0 20px;border-bottom:1px solid var(--line)"><span class="h" data-k="title">${NAVS[0][1]}</span></div><div style="padding:16px 20px" data-k="page">${page(0)}</div></div></div>`,
      play(col, m, step) {
        const t = tok(m), i = step % NAVS.length, pg = q(col, '[data-k=page]');
        col.querySelectorAll('.nav').forEach((r, k) => r.classList.toggle('on', k === i));
        q(col, '[data-k=title]').textContent = NAVS[i][1]; pg.innerHTML = page(i);
        if (m === 'c') go(pg, [{ opacity: 0, transform: rise(t, 6) }, { opacity: 1, transform: 'none' }], t.in, { ease: t.ease });
      },
    },
  ];

  /* ════════ The page ════════ */
  const AUDIT = [
    ['Changement de panneau', 'Transition de page Material par défaut : rien ne la règle dans le thème ni dans le routeur.', 'À corriger', 'Contredit §13, « rien ne s’anime au premier affichage ». Durée et courbe hors jetons.'],
    ['Menus et listes déroulantes', 'Animation Material par défaut.', 'À corriger', '§13 demande 120 ms et 4 px pour un popover.'],
    ['Infobulle', 'Attente de 500 ms, puis fondu Material.', 'À corriger', 'Durée du fondu hors jetons.'],
    ['Changement de thème', 'Interpolation Material par défaut, 200 ms.', 'À décider', 'Jamais décidée par §13.'],
    ['Toast', 'Entrée 120 ms sur 4 px. Aucune sortie.', 'À corriger', 'Entrée conforme, disparition sèche.'],
    ['Import récent', 'Surlignage tenu 4 s, puis coupé.', 'À corriger', 'La fin se lit comme un saut.'],
    ['Barre latérale repliée, arbre des catégories', 'Changement immédiat.', 'À décider', 'La largeur saute de 224 à 56 px.'],
    ['Volet', 'Le nouveau contenu apparaît en 120 ms, l’ancien part aussitôt.', 'À décider', 'Conforme à §13, mais le volet se vide un instant à chaque ligne parcourue.'],
    ['Bascule, segments, onglets, case', 'Changement immédiat.', 'Conforme', '§13 : les états changent d’un coup. La bascule saute d’un bord à l’autre.'],
    ['Modale', 'Fondu 120 ms à l’entrée et à la sortie.', 'Conforme', 'La sortie dure autant que l’entrée.'],
    ['Repère', '240 ms quand la valeur change, dessiné sans animation au premier affichage.', 'Conforme', ''],
    ['Silhouette de chargement', 'Pulsation de 1,6 s, arrêtée en mouvement réduit.', 'Conforme', ''],
    ['Indicateur d’attente', 'Rotation Material, dans un bouton, au démarrage et pendant une analyse.', 'Conforme', 'Hors §13, à y inscrire.'],
    ['Courbe', 'Curves.easeOut écrit dans chaque widget.', 'À corriger', 'Les durées sont des jetons, la courbe non.'],
    ['Mouvement réduit', 'Testé à la main dans chaque widget animé, sous deux écritures.', 'À corriger', 'Une seule source à prévoir, que les nouveaux widgets ne puissent pas oublier.'],
  ];
  const TONE = { 'À corriger': 'warn', 'À décider': 'ac', Conforme: 't3' };
  const PROPS = {
    a: ['Le mouvement confirme, il ne décrit pas. On garde §13 tel quel et on ferme ses trous : tout ce qui flotte suit les mêmes 120 ms, tout ce qui part sort plus vite qu’il n’est entré, le reste change d’un coup.',
      'Aucune règle retirée. Ajouts : une durée de sortie, un jeton de courbe, « aucune transition entre panneaux ».',
      'Toutes les durées à 0, comme aujourd’hui.',
      'Faible. Des corrections, aucun nouveau widget animé.'],
    b: ['Ce qui change de valeur va de l’ancienne à la nouvelle ; ce qui est nouveau apparaît, sans trajet. C’est le geste du repère étendu aux chiffres, aux barres et aux contrôles : on voit l’écart entre deux mois au lieu de le déduire.',
      'Tout A. « Les états changent d’un coup » ne vaut plus pour la bascule, les segments et les onglets. « Les graphiques sont dessinés, pas animés » reste vrai au premier affichage, plus au changement de période.',
      'Les fondus restent, à 120 et 80 ms. Trajets, croissances et comptages passent à 0.',
      'Moyen. Un texte de montant animé, en chiffres tabulaires pour que rien ne bouge autour de lui, un pouce de segment, des barres interpolées.'],
    c: ['L’application est un lieu : la modale vient de la profondeur, le volet de la droite, le toast du bas, un panneau se pose. Un seul moment est mis en scène, la fin d’un import, parce que c’est le geste que l’on refait chaque mois.',
      'Tout B. « Rien ne s’anime au premier affichage » est retiré pour le corps d’un panneau. Un jeton de 600 ms est réservé à l’import.',
      'Comme B : seuls les fondus restent.',
      'Élevé. Une transition de route, une liste animée, et une règle de plus à tenir sur onze panneaux.'],
  };
  const propCard = m => {
    const t = T[m], [thesis, rule, reduced, cost] = PROPS[m];
    return `<div class="mo-prop"><h3>${m.toUpperCase()} · ${t.name}</h3><p>${thesis}</p>
      <dl class="kv sm"><dt>Entrée, sortie</dt><dd>${ms(t.in)}, ${ms(t.out)}</dd><dt>Déplacement d’un contrôle</dt><dd>${t.move ? ms(t.move) : 'immédiat'}</dd><dt>Mesure : repère, chiffres, barres</dt><dd>${m === 'a' ? `${ms(t.measure)}, repère seul` : ms(t.measure)}</dd><dt>Moment</dt><dd>${t.moment ? ms(t.moment) : 'aucun'}</dd><dt>Courbe</dt><dd class="mono">${t.curve}</dd></dl>
      <div class="hr"></div><dl class="mo-dl sm"><dt>§13</dt><dd>${rule}</dd><dt>Mouvement réduit</dt><dd>${reduced}</dd><dt>Coût</dt><dd>${cost}</dd></dl></div>`;
  };
  const scene = s => `<section class="mo-scene" data-scene="${s.id}"><div class="mo-cap"><h3>${s.title}</h3><span class="t2">${s.now}</span><span class="sp"></span><button class="btn" data-play>${I('play', 's14')}Jouer</button></div>
    <div class="mo-cols">${['a', 'b', 'c'].map(m => `<div class="mo-col" data-m="${m}"><div class="mo-stage" style="height:${s.h}px">${s.build(m)}</div><p class="mo-spec"><b>${m.toUpperCase()}</b>${s.spec[m]}</p></div>`).join('')}</div></section>`;

  /* #panel=motion&only=<scene id>&bare=1 shows one scene alone, scaled to a small window: used to capture its frames. */
  const only = () => SC.find(s => s.id === HASH.get('only'));
  const pageHtml = theme => only() ? `<div class="app mg-page mo" data-theme="${theme}" data-accent="encre" data-tex="off" style="zoom:.68;padding:16px">${scene(only())}</div>` : `<div class="app mg-page mo" data-theme="${theme}" data-accent="encre" data-tex="off">
  <h2>Mouvement</h2>
  <p>Ticket #366. Les animations de Bastide ont été ajoutées une à une. Cette page fait d’abord l’inventaire de ce qui existe, puis propose trois systèmes complets, joués côte à côte sur les mêmes scènes. Le bouton « Jouer » d’une scène lance les trois colonnes ensemble ; la barre du haut ralentit tout ou montre la version « mouvement réduit ». Rien n’est construit avant qu’un système soit retenu.</p>

  <h2>Ce qui existe</h2>
  <p>Relevé dans le code de l’application, pas à l’écran. Quatre réglages sont laissés aux valeurs de Material, hors de §13.</p>
  <table class="mo-audit"><thead><tr><th>Élément</th><th>Aujourd’hui</th><th>Constat</th><th></th></tr></thead><tbody>
  ${AUDIT.map(([e, now, v, why]) => `<tr><td>${e}</td><td class="wrap t2">${now}</td><td class="${TONE[v]}">${v}</td><td class="wrap t2">${why}</td></tr>`).join('')}</tbody></table>

  <h2>Trois propositions</h2>
  <p>Elles s’emboîtent : B contient les corrections de A, C contient B. Dans les trois, les survols et les appuis restent immédiats, rien ne tourne en boucle hors chargement, et aucune animation ne retarde une action.</p>
  <div class="mo-cols" style="margin-top:20px">${['a', 'b', 'c'].map(propCard).join('')}</div>

  <h2>En situation</h2>
  <p>Chaque colonne applique son système à la même scène. Quand deux colonnes font la même chose, c’est écrit.</p>
  ${SC.map(scene).join('')}

  <h2>Recommandation</h2>
  <p><b>B · Repère.</b> C’est la seule des trois dont le mouvement dit quelque chose que l’écran fixe ne dit pas : de combien une valeur a changé. Elle reste dans le caractère de l’application, calme et sans décor, et ne touche pas à l’affichage d’un panneau. Pour l’import, B garde son propre surlignage, tenu puis estompé. A reste le socle si l’on veut seulement remettre de l’ordre.</p>
  <p>À décider avant de construire : le système retenu, le sort de la barre latérale repliée et du changement de thème, et la règle de mouvement réduit, 0 partout ou fondus conservés. La décision s’écrit ensuite dans 00-design-system.md §13 et dans les jetons.</p>
</div>`;

  function init(fit) {
    MO.state = {}; MO.run = {};
    fit.querySelectorAll('.mo-scene').forEach(sec => {
      const s = SC.find(x => x.id === sec.dataset.scene), cols = [...sec.querySelectorAll('.mo-col')];
      if (s.init) cols.forEach(c => s.init(c));
      q(sec, '[data-play]').onclick = () => {
        const step = MO.state[s.id] = (MO.state[s.id] || 0) + 1, run = MO.run[s.id] = (MO.run[s.id] || 0) + 1;
        cols.forEach(c => s.play(c, c.dataset.m, step, () => run === MO.run[s.id] && c.isConnected));
      };
    });
  }
  /* Viewer controls, in the bar: speed and reduced motion. */
  function controls(bar, rerender) {
    const set = () => bar.querySelectorAll('button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.k === 'speed' ? +b.dataset.v === MO.speed : (b.dataset.v === '1') === MO.reduced)));
    bar.querySelectorAll('button').forEach(b => b.onclick = () => { if (b.dataset.k === 'speed') MO.speed = +b.dataset.v; else { MO.reduced = b.dataset.v === '1'; rerender(); } set(); });
    set();
  }
  return { page: pageHtml, init, controls };
})();
