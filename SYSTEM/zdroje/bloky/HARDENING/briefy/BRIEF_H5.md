> Kópia zadania zo scratchpadu orchestrátora, 1.10.2026; package/audity dávky sú v nadradenom priečinku.

# Brief — dávka H5 · dokumentácia okien a UI dizajnu (blok 9 HARDENING, B-02 · B-03 · B-05) — dokumentačná dávka, rez H5a → H5b

Si implementátor dávky **H5a** alebo **H5b** (orchestrátor ti povie ktorej) bloku 9 · HARDENING PO V1. Pracuj z **čerstvého `origin/main`**.
**Plugin (`noxun_engine/`) sa NEMENÍ** — VERSION, `?v=` ani STAV „Stav" sa nemenia (STAV „Robí sa/Ďalší krok" podľa pravidla B-08 z H1, ak sa mení stav bloku).

## Zdroj
- `SYSTEM/zdroje/bloky/HARDENING/TRIEDENIE_krizovy_audit_v1.html` (B-02, B-03, B-05) + dôkazy: `CROSS_AUDIT_A3_CODEX_SOL.md` **CS-01, CS-04, CS-06, CS-07**
  a `CROSS_AUDIT_A4_CLAUDE_NOVY_AGENT.md` **CN-08, CN-09** (čísla riadkov k 1.10. — over).
- Povinné čítanie: `CLAUDE.md` (riadky workflow + UI — po dávke H1 smerujú na kapitoly), `docs/ARCHITEKTURA.md` (rozcestník), guard `tests/pure/test_docs_navigacia.rb`
  (čo stráži: nadpisy `### <modul>`, odkazy, riadky rozcestníka) a testy, ktoré čítajú UI_DIZAJN (`test_ui01_paleta.rb`, inventár ikon — Grep `UI_DIZAJN` v `tests/`).

## Spoločné zásady (H5a aj H5b)
- **Presun, nie mazanie:** história (priebeh dávok, review kolá, zaniknuté okná a premostenia) ide **plným textom** do archívu
  (`SYSTEM/archiv/` — nový súbor napr. `UI_LIFECYCLE_historia_do_v0.17.md` / `UI_DIZAJN_dennik_do_v0.17.md`, alebo existujúci archívny súbor, ak je vhodnejší);
  v živom dokumente ostane **aktuálny kontrakt/opis** + jedna veta s odkazom do archívu. Obsah, ktorý **ešte platí**, sa nesmie stratiť — pri pochybnosti
  ostáva v živom dokumente.
- Všetky nadpisy, na ktoré ukazujú testy, skilly, CLAUDE.md, README, PLAN a iné dokumenty, zostanú funkčné (Grep celé repo pred aj po; zoznam presmerovaní do PR).
- Nič neopravuj v kóde. Ak narazíš na tvrdenie, ktoré nevieš overiť v kóde, označ ho `NEOVERENÉ` v PR popise (nie v dokumente) a nechaj bez zmeny.

## H5a · `docs/architecture/ui-lifecycle.md` (B-02 + časť B-03)
1. Každá zo **14 sekcií Štúdia** (Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Nárezový plán · Materiály · Kovanie · Spotrebiče · Pravidlá ·
   Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine) a každý kontext Inspectora (Korpus · Zóny · Čelá · Kovanie) má **vlastný krátky nadpis
   s aktuálnym opisom** (čo sekcia robí, odkiaľ berie dáta — Ruby metóda/akcia, hlavné JS funkcie, kľúčové invarianty). Nadpisy modulov, ktoré stráži
   `nx_arch_headings` (`### <modul>`), zostávajú (napr. `studio_dialog.rb`) — sekcie môžu byť podnadpisy.
2. Zaniknuté okná/moduly (CS-07) — v živej mape len jedna veta + odkaz do archívu; guard: zaniknutý súbor nesmie mať živý modulový nadpis (porovnaj
   so zoznamom živých `*.html`/HtmlDialog v kóde).
3. Nadpisy pomenované podľa kola review (napr. „ZÁMOK ODOSLANIA OPEN.busy (review #2)") premenuj podľa funkcie.
4. **Guard rastu (B-03 / CS-04):** limit veľkosti živého `ui-lifecycle.md` (a podľa potreby ostatných `docs/architecture/*.md` — daj rozumný strop na súbor
   ~1,3× veľkosti po uprataní) a/alebo zákaz historických markerov (`PR #`, „ZANIKLO", „review #") mimo vyhradenej sekcie; najprv over reportovacím
   behom, potom tvrdá brána. Hodnoty a dôvod do PR.
5. Cieľ veľkosti: živý `ui-lifecycle.md` výrazne pod dnešných ~530 kB (odhad auditu: aktuálny opis je malý zlomok) — uveď pred/po.

## H5b · `docs/UI_DIZAJN.md` + rozpory (B-05, CN-09, CS-06 + zvyšok B-03)
1. UI_DIZAJN rozdeliť na **normu** (tokeny, typografia, komponenty, ikony, pravidlá rozloženia vrátane „vertikálny priestor je vzácny" — autorita §1 po H1)
   a **denník dávok** → archív. §-čísla, na ktoré ukazujú testy a CLAUDE.md, zachovať alebo presmerovať. Zoradiť §5.12/§5.13, E-b/D-xx pod §5 (CN-08).
2. Opraviť **9 rozporov z CN-09** (každý over v kóde pred opravou; opravuje sa dokument, nie kód): `construction.md` TYPES (4 typy vrátane `corner_blind`),
   hmotnosť „príde vo fáze 3" (UI_DIZAJN, UI20_KONTRAKT), semaforové tokeny sa používajú (Kontrola), výklop AVENTOS vyberateľný, inventár ikon „úplný k v0.7.28",
   BuildPlan SCHEMA (aktuálna hodnota z kódu; história v minulom čase, poradie zmien vzostupne), „návrh, potvrdí Michal" pri rohovej v VEPO_KONTRAKT a STANDARD
   (blok ROHOVÁ smoke PASS 28.9. — over v `SYSTEM/archiv/bloky/ROHOVA/` a ROHOVA_ZAVER, čo Michal potvrdil; čo nepotvrdil, ponechaj), „Architektúra (v0.5.32)",
   „satelitné okná" (zanikli v ŠT-4a), hmotnosť z geometrie vs. z katalógu (vysvetliť kontext snapshot vs. plán).
3. Do **checklistu uzáveru kódovej dávky** v `CLAUDE.md` pridaj krátky bod: „Grepom prehľadaj tvrdenia o zoznamoch, ktoré dávka mení (typy, ikony, schémy, sekcie)".
4. Guard veľkosti UI_DIZAJN (strop ~1,3× po uprataní) — rovnaký mechanizmus ako H5a.

## Testy a uzáver
- `ruby tests/run_all.rb` zelené (guardy dokumentov, navigácia, paleta, ikony, encoding), každá JS sada zvlášť; `git diff --stat` bez `noxun_engine/`.
- KRONIKA odsek navrch · PLAN blok 9 riadok **H5** (pri H5a „H5a ✅ #…", H5 ✅ až po H5b) + `PR #?` → commit s číslom PR.
- Docs-only → **predrecenzia sa nerobí** → PR (kvótová brána, popis po slovensky cez `--body-file`: pred/po veľkosti, kam sa čo presunulo, zoznam presmerovaných
  nadpisov) → commit čísla PR → report. **Nemerguj.** Pri nejasnosti nevymýšľaj; otázka v reporte.

- **Doplnok orchestrátora (po H5a #439):** CLAUDE.md stále píše „celý má 540 kB“ a „47–540 kB“ pri ui-lifecycle — oprav na aktuálny stav (~253 kB) v H5b.
