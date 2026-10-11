> Kópia zadania zo scratchpadu orchestrátora, 1.10.2026; package/audity dávky sú v nadradenom priečinku.

# Brief — dávka H2 · fotenie okien pre UI dávky (blok 9 HARDENING, položka D-10) — nástroj, plugin sa nemení

Si implementátor dávky **H2** bloku 9 · HARDENING PO V1. Pracuj z **čerstvého `origin/main`** (obsahuje H1). Vetva **`feat/h2-fotenie-okien`**.
**`noxun_engine/` sa NEMENÍ** (ani UI súbory pluginu) → VERSION ani `?v=` sa nebumpujú, STAV sa nemení (len KRONIKA + PLAN riadok).

## Cieľ (D-10, Michal zaradil „Teraz")
Po každej UI dávke má agent jedným príkazom **nafotiť Inspector a všetkých 14 sekcií Štúdia** z reálnych dát pluginu — bez interaktívneho SketchUpu,
aj pri zamknutej obrazovke. Fotky idú orchestrátorovi do reportu a Michalovi (neposielajú sa do gitu). Pri audite 1.10. vznikol funkčný prototyp — z neho
urob udržiavaný nástroj.

## Prototyp (over, čo funguje — nie je v gite)
- Postup: `C:\APP DEV\RUBY\ENGINE\_dev\v1audit_foto_prototyp\POSTUP.md` (prečítaj celý) + `nx_stub.js` (stub `window.sketchup` + prehrávanie
  nahratých Ruby→JS skriptov až po značku `upto`) + `rec_ukazka\` (57 súborov: `NNNN_mark_<sekcia>.txt` a `NNNN_<studio|panel>.js`, v0.17.0).
- Hotová ukážková stránka a nahrávka: `C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE\ff14dba2-41ce-456d-9169-9d0a1abe169b\scratchpad\v1audit\site\`
  (kópia `ui/` so stubom, `rec/`) — použi na rýchly štart režimu fotenia; výsledné fotky z auditu: `C:\APP DEV\RUBY\ENGINE\_dev\v1audit_shots\` (vzor výstupu).
- `_dev/` nie je v tvojom worktree (gitignore) — čítaj ho z hlavného checkoutu cestou vyššie, **nezapisuj doň**.

## Čo dodať (rozhodnutia orchestrátora)
1. **Vstup `scripts\ui_foto.ps1`** (+ pomocné súbory v `scripts\ui_foto\`), dva režimy:
   - **`-Record`** — nahrávka v SketchUpe cez overenú slučku `SketchUp.exe -RubyStartup <skript> <kópia modelu>` (vzor a zámky: `scripts\run_su_tests.ps1`
     — **zdieľaj `%TEMP%\noxun_su_tests\deploy.lock`** a jeho sentinel/ exit-2 logiku, nikdy nezabíjaj proces, `-CloseWhenDone` správanie: po koncovom
     markeri sa inštancia sama zavrie). Model: **kópia `_dev\ENGINEtests.skp`** (z hlavného checkoutu; ak chýba, neuložený nový model) — **nikdy okno so
     zákazkou**. Skript postaví ukážkovú kuchyňu zo šablón (POSTUP bod 1), nahrá `execute_script` payloady cez `UI::HtmlDialog.prepend` **len v tejto
     session** (surové bajty `File.binwrite`, nie `to_json` — diakritika), prejde Inspector (kontexty Korpus/Čelá/Zóny/Kovanie + bez výberu) a 14 sekcií
     Štúdia so značkami. Nasadenie pluginu z worktree rovnako ako runner (deploy). Výstup: `%TEMP%\noxun_ui_foto\rec_<VERSION>_<čas>\` + `index.json`.
   - **`-Shoot`** (predvolený) — vezme **najnovšiu nahrávku** (alebo `-Rec <cesta>`), skopíruje **aktuálne `noxun_engine/ui/` z worktree** do dočasnej
     stránky, vloží stub (nikdy nie do repa), spustí lokálny statický server (Python `http.server` je k dispozícii; alebo iná cesta bez novej závislosti) a
     headless Chrome (`C:\Program Files\Google\Chrome\Application\chrome.exe`, fallback Edge `msedge.exe`) → PNG: Inspector 486 px (každý kontext),
     Štúdio 1280×800 (každá sekcia) + „long" verzia na celú výšku obsahu; nakoniec **`index.html` kontaktný hárok** (miniatúry s názvami, otvoriteľný
     lokálne). Výstup `%TEMP%\noxun_ui_foto\shots_<čas>\`, cestu vypíše na konci. Server a Chrome po sebe upraceš (vlastný `--user-data-dir` v TEMP).
   - Voliteľne `-Only studio_cut,panel_cela` (podmnožina).
2. **Poctivé hranice** (vypíš ich v hlavičke hárku aj v dokumentácii): statický stav (bez modálov a hoveru), Chrome nie CEF (rozbaľovačky/písmo sa môžu
   líšiť), svetlá téma; nahrávka zastará, keď dávka mení **tvar dát z Ruby** — vtedy `-Record` znova (JS/CSS zmeny stačí `-Shoot` nad starou nahrávkou).
   Keď prehrávanie niektorého skriptu padne (JS chyba po zmene UI), hárok to pri sekcii jasne ukáže (nie tichá prázdna fotka).
3. **Testy (headless, bez SketchUpu):** Ruby/JS test, ktorý overí (a) stub sa nedostane do `noxun_engine/ui/*.html` (guard), (b) logiku výberu súborov do
   `upto` (značky, kind) na malej fixtúre v `tests/fixtures/…` (pár bajtov, nie celá nahrávka), (c) parsovanie parametrov skriptu ak je to rozumné.
   Celá headless sada + každá JS sada zelené, encoding guard.
4. **Dôkaz, že to funguje:** spusti **`-Record` naozaj** (SketchUp 2026 je nainštalovaný; MCP bridge netreba) a potom `-Shoot`; do reportu daj cestu
   k hárku a počet fotiek. Ak `-Record` zlyhá na prostredí (SketchUp visí, modal…), nezabíjaj proces, max 2 pokusy, `-Shoot` dokáž nad nahrávkou
   z prototypu a v reporte uveď presne, čo nefunguje.
5. **Dokumentácia:** v `CLAUDE.md` sekcia Testovanie krátky odsek „Fotenie okien (UI dávky)" — kedy (každá UI dávka: po zmene JS/CSS/HTML `-Shoot`, po
   zmene payloadu `-Record` + `-Shoot`), kam idú fotky (report orchestrátorovi → Michal; do gitu nie), hranice. Do riadku **UI** tabuľky povinného čítania
   **nepridávaj** čítanie — len jednu vetu „po zmene UI nafoť okná (`scripts\ui_foto.ps1`)". Ak existuje `docs/architecture/` odsek o testovacích
   nástrojoch/skriptoch, doplň na mieste; inak stačí CLAUDE.md + komentár v hlavičke skriptu.

## Uzáver
- KRONIKA odsek navrch · PLAN blok 9 riadok **H2** ✅ + `PR #?`. Commity selektívne, `-F` súbor, trailer so skutočným modelom tvojej session.
- **Predrecenzia sa nerobí** (plugin sa nemení, nový ovládač v UI nie je) → po pushi rovno PR (kvótová brána `-Gate codex`, popis po slovensky cez
  `--body-file`: čo nástroj robí pre Michala a agentov, ako otestované, hranice) → commit s číslom PR → push → report (priprav 3–4 najzaujímavejšie
  fotky + cestu k hárku, orchestrátor ich pošle Michalovi).
- **Nemerguj.** Pri nejasnosti nevymýšľaj; otázka v reporte.
