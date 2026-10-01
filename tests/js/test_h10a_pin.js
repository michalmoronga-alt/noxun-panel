// H10a/R-35 — PIN revízie GLOBÁLNYCH pravidiel kovania v sekcii Pravidlá (klient).
//
// Prečo sú to testy a nie klikanie:
//   Server pri uložení „aj ako globálnu predvoľbu" porovná revíziu globálu,
//   ktorú okno VIDELO (`RD_GLOBAL_REV`), s tou na disku. Keby sa pin posunul
//   pri KAŽDOM pushi (pôvodný návrh, audit BLOCKER 1), okno A by po uložení
//   LEN do projektu (alebo po Späť) dostalo push s revíziou globálu, ktorý
//   uložilo okno B — a ďalšie „aj ako globálnu" by B ticho prepísalo. Rozbije
//   sa to jediným riadkom a TICHO (žiadna chyba, len stratená zmena v druhom
//   okne) — preto scenáre z auditu ako regresné testy.
//
// Pin sa posúva LEN: (a) pri prvom naplnení sekcie, (b) pri naplnení, ktoré
// zobrazuje globál (`source: 'global'`), (c) na pokyn servera `RD.setGlobalRev`.
'use strict';
const assert = require('node:assert');
const path = require('node:path');

const JS = path.join(__dirname, '..', '..', 'noxun_engine', 'ui', 'js');

function stubEl(id){
  const n = { id, style: {}, children: [], parentNode: null, _html: '', _attrs: {}, value: '', checked: false };
  Object.defineProperty(n, 'innerHTML', { get(){ return n._html; }, set(v){ n._html = v; n.children = []; } });
  Object.defineProperty(n, 'textContent', { get(){ return n._text || ''; }, set(v){ n._text = v; n.children = []; } });
  n.appendChild = function(c){ c.parentNode = n; n.children.push(c); return c; };
  n.cloneNode = function(){ return stubEl(id + '-clone'); };
  n.setAttribute = function(k, v){ n._attrs[k] = String(v); };
  n.getAttribute = function(k){ return Object.prototype.hasOwnProperty.call(n._attrs, k) ? n._attrs[k] : null; };
  n.focus = function(){}; n.setSelectionRange = function(){};
  n.querySelector = function(){ return null; }; n.querySelectorAll = function(){ return []; };
  return n;
}

// Každý scenár = ČERSTVÉ okno Štúdia (pin žije v uzávere súboru, preto nový require).
function freshWindow(){
  const ELS = {};
  ['snav', 'sechead', 'sectools', 'secbody', 'status', 'studio', 'rulesBox', 'rdSrcLine', 'alsoGlobal',
   'rdAbsBox', 'rdAbsSrc', 'rdAbsHint', 'rdAbsOvr', 'rdHwOvr'].forEach(function(id){ ELS[id] = stubEl(id); });
  ELS.rulesBodyTpl = stubEl('rulesBodyTpl');
  ELS.rulesBodyTpl.content = stubEl('rulesBodyTplContent');
  const SENT = [];
  global.window = { sketchup: new Proxy({}, {
    get(_t, name){ return typeof name === 'string' ? function(p){ SENT.push([name, p]); } : undefined; },
    has(){ return true; } }) };
  global.sketchup = global.window.sketchup;
  global.document = { activeElement: null, addEventListener: function(){},
                      getElementById: function(id){ return ELS[id] || null; },
                      createElement: function(t){ return stubEl('new-' + t); },
                      querySelector: function(){ return null; }, querySelectorAll: function(){ return []; } };
  delete require.cache[path.join(JS, 'studio.js')];
  delete require.cache[path.join(JS, 'rules.js')];
  require(path.join(JS, 'studio.js'));
  global.NX = global.window.NX;
  const R = require(path.join(JS, 'rules.js'));
  return {
    R, ELS, SENT,
    save(alsoGlobal){
      ELS.alsoGlobal.checked = !!alsoGlobal;
      SENT.length = 0;
      R.rdSaveRules();
      assert.strictEqual(SENT.length, 1, 'uloženie odišlo');
      return JSON.parse(SENT[0][1]);
    }
  };
}

function payload(source, qty, rulesRev, globalRev, guid){
  return { version: 't', model_guid: guid || 'DOC-A', source: source, cabinets: 1,
           rules_rev: rulesRev, global_rev: globalRev,
           rules: [{ kind: 'fixed', output: 'leg', enabled: true, quantity: qty, applies_to: { role: 'cabinet' } }],
           abs: { rows: [], source: '', hint: '' },
           overrides: { abs: { total: 0, groups: [] }, hardware: { total: 0, groups: [] } } };
}

let n = 0;
function eq(a, b, msg){ n++; assert.deepStrictEqual(a, b, msg); }

// 1) REGRESIA BLOCKER 1: A-G0 / B-G1 / A uloží len projekt / A „aj ako globálnu".
(function(){
  const w = freshWindow();
  w.R.rdApplyState(payload('project', 4, 'P0', 'G0'));   // otvorenie Štúdia (globál G0)
  w.R.rulesRenderBody();
  eq(w.save(false).global_rev, 'G0', 'uloženie len do projektu nesie pin G0');
  // after_model_write: push so ZMENENÝMI pravidlami projektu a revíziou G1 (B uložilo globál).
  w.R.rdApplyState(payload('project', 5, 'P1', 'G1'));
  eq(w.R.rdGlobalRev(), 'G0', 'projektová obnova formulára pin NEPOSUNIE');
  eq(w.save(true).global_rev, 'G0', '„aj ako globálnu" posiela G0 — server nahlási konflikt, G1 ticho nezanikne');
})();

// 2) To isté po Späť (push so zmenenými projektovými pravidlami).
(function(){
  const w = freshWindow();
  w.R.rdApplyState(payload('project', 4, 'P0', 'G0'));
  w.R.rulesRenderBody();
  w.R.rdApplyState(payload('project', 3, 'Pundo', 'G1'));
  eq(w.save(true).global_rev, 'G0', 'Späť pin neposúva');
})();

// 3) Prepnutie dokumentu (iný model, projektové pravidlá) — pin ostáva.
(function(){
  const w = freshWindow();
  w.R.rdApplyState(payload('project', 4, 'P0', 'G0', 'DOC-A'));
  w.R.rulesRenderBody();
  w.R.rdApplyState(payload('project', 7, 'P9', 'G1', 'DOC-B'));
  eq(w.save(true).global_rev, 'G0', 'prepnutie dokumentu pin neposúva (cudzí globál okno nevidelo)');
  // Vynútené echo (odmietnutý zápis) so zdrojom projekt — tiež nie.
  w.R.RD.setSection(payload('project', 8, 'P10', 'G2', 'DOC-B'), true);
  eq(w.R.rdGlobalRev(), 'G0', 'echo s force a zdrojom projekt pin neposúva');
})();

// 4) Zdroj `global` = formulár ZOBRAZUJE globál — pin ide s obsahom.
(function(){
  const w = freshWindow();
  w.R.rdApplyState(payload('global', 4, 'G0', 'G0'));
  w.R.rulesRenderBody();
  eq(w.R.rdGlobalRev(), 'G0', 'prvé naplnenie');
  w.R.rdApplyState(payload('global', 6, 'G1', 'G1'));
  eq(w.save(true).global_rev, 'G1', 'push, ktorý formulár prekreslí globálom G1, smie pin posunúť');
  w.R.RD.setSection(payload('global', 7, 'G2', 'G2'), true);
  eq(w.R.rdGlobalRev(), 'G2', 'echo so zdrojom global tiež (formulár ukazuje G2)');
})();

// 5) `RD.setRules` (Načítať globálne) pin NEMENÍ — pin nastavuje len `setGlobalRev`.
(function(){
  const w = freshWindow();
  w.R.rdApplyState(payload('project', 4, 'P0', 'G0'));
  w.R.rulesRenderBody();
  w.R.RD.setRules([{ kind: 'fixed', output: 'leg', enabled: true, quantity: 9 }], 'global');
  eq(w.R.rdGlobalRev(), 'G0', 'setRules pin nemení');
  w.R.RD.setGlobalRev('G5');
  eq(w.save(true).global_rev, 'G5', 'Načítať globálne = setRules + setGlobalRev v jednom skripte');
})();

// 6) `setGlobalRev('')` sa ignoruje; poradie setGlobalRev ↔ push je irelevantné.
(function(){
  const w = freshWindow();
  w.R.rdApplyState(payload('project', 4, 'P0', 'G0'));
  w.R.RD.setGlobalRev('');
  eq(w.R.rdGlobalRev(), 'G0', 'prázdna revízia zo servera pin nemení');
  w.R.RD.setGlobalRev(null);
  eq(w.R.rdGlobalRev(), 'G0', 'ani null');
  // server: vlastné úspešné uloženie globálu F, POTOM after_model_write push.
  w.R.RD.setGlobalRev('F');
  w.R.rdApplyState(payload('project', 5, 'P1', 'G-iny'));
  eq(w.save(true).global_rev, 'F', 'setGlobalRev -> push: odchádza F');
})();
(function(){
  const w = freshWindow();
  w.R.rdApplyState(payload('project', 4, 'P0', 'G0'));
  w.R.rdApplyState(payload('project', 5, 'P1', 'G-iny'));
  w.R.RD.setGlobalRev('F');
  eq(w.save(true).global_rev, 'F', 'push -> setGlobalRev: odchádza F');
  // Pokojný push (rovnaké pravidlá) s inou revíziou pin tiež neposunie.
  w.R.rdApplyState(payload('project', 5, 'P1', 'G-dalsi'));
  eq(w.save(true).global_rev, 'F', 'pokojný push pin neposúva');
})();

// 7) Kľúč `global_rev` ide VŽDY — '' pred prvým naplnením; prvé naplnenie s ''.
(function(){
  const w = freshWindow();
  eq(w.R.rdGlobalRev(), null, 'pred prvým naplnením pin nie je');
  const p = w.save(true);
  eq(Object.prototype.hasOwnProperty.call(p, 'global_rev'), true, 'kľúč ide vždy (inak server = starý DOM)');
  eq(p.global_rev, '', 'a pred prvým naplnením je prázdny');
})();
(function(){
  const w = freshWindow();
  w.R.rdApplyState(payload('project', 4, 'P0', ''));
  eq(w.save(true).global_rev, '', 'globál sa pri otvorení nedal prečítať -> prázdny pin (server: H-UNK)');
  w.R.rdApplyState(payload('project', 5, 'P1', 'G1'));
  eq(w.R.rdGlobalRev(), '', 'ani potom ho projektový push „neuhádne"');
  w.R.RD.setGlobalRev('G1');
  eq(w.R.rdGlobalRev(), 'G1', 'až server po H-UNK');
})();
(function(){
  const w = freshWindow();
  const p = payload('project', 4, 'P0', 'G0');
  delete p.global_rev;
  w.R.rdApplyState(p);
  eq(w.R.rdGlobalRev(), '', 'payload bez revízie = prázdny pin, nikdy undefined');
})();

console.log(`OK ${n} kontrol (H10a pin revízie globálnych pravidiel)`);
