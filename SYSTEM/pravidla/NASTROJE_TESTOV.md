# Nástroje testov — fotenie okien, export test, diagnostika MCP

> Podrobnosti k nástrojom zo sekcie Testovanie v [roly/IMPLEMENTATOR.md](roly/IMPLEMENTATOR.md#testovanie) — kedy ktorý nástroj platí
> (fotenie: UI dávka, `.claude/rules/ui.md` · export test: brána mergu výstupov, `.claude/rules/vystupy.md` · diagnostika: visiaci MCP).
> Čítaj podľa potreby.

<a id="foto"></a>

## Fotenie okien

- **Fotenie okien (UI dávky):** `powershell -NoProfile -File scripts\ui_foto.ps1` nafotí Inspector (bez výberu + kontexty Korpus, Zóny,
  Čelá, Kovanie) a všetkých 14 sekcií Štúdia z **nahrávky reálnych dát pluginu** prehranej v aktuálnom UI checkoutu (headless Chrome,
  aj pri zamknutej obrazovke) + verzie na celú výšku + kontaktný hárok `index.html`. **Každá UI dávka:** po zmene JS/CSS/HTML `-Shoot`
  (predvolený, nad poslednou **úspešnou** nahrávkou — so značkou `NAHRAVKA_OK.txt`; staršie nahrávky bez značky len cez
  `-Rec <priečinok>`; keď úspešná nahrávka ešte nie je, začni `-Record`); po zmene **tvaru dát z Ruby** (payload okna) `-Record` — nová
  nahrávka v SketchUpe overenou slučkou runnera nad kópiou ENGINEtests.skp, zdieľa jeho zámok (`exit 2` = iný beh beží), inštancia sa
  zavrie sama — a hneď fotí. `-Only studio_cut,panel_cela` = podmnožina. Fotky idú do `%TEMP%\noxun_ui_foto\shots_<čas>_<PID>\` →
  **report orchestrátorovi → Michal; do gitu nie**. **Hranice:** statický stav (bez modálov, hoveru a rozbalených ponúk), Chrome nie CEF
  (písmo a rozbaľovačky sa môžu líšiť), svetlá téma; fotka s červeným pásom = prehranie nahrávky v novom UI zlyhalo (karta v hárku
  CHYBA) — nová nahrávka alebo oprava UI, nie tichá fotka.

<a id="export"></a>

## Export test

- **Export test (výrobné dávky exportov):** `powershell -NoProfile -File scripts\export_test.ps1 [-Base <ref>] [-Model <.skp>] [-KeepWork]`
  sám urobí 4 exporty Štúdia (VEPO, CSV kovania, XLSX rozpočtu, XLSX ponuky) nad kópiou testovacej zákazky **raz na `-Base` (K,
  predvolene `origin/main`) a raz na aktuálnom checkoute (P)** a vypíše `EXPORT-TEST: P == K` / `P != K` + zoznam rozdielov a porovnanie
  viet statusu; exit 0 = zhodné, 1 = rozdiel alebo chyba behu, 2 = zamok (iný beh). Model predvolene `_dev\export_test\zakazka.skp`
  (gitignorované; názov zákazky sa odvodí z mena súboru, preto ho nemeň). Beží pod zámkom `deploy.lock` ako runner a foto okien (nesmie
  kolidovať), profil `%APPDATA%\NOXUN` sa len skopíruje (K aj P dostanú rovnakú čerstvú kópiu, reálny sa nemení), SketchUp sa ukončí sám
  (proces sa nezabíja), na konci ostane nasadený P. **Brána mergu:** dávka, ktorá mení VEPO, CSV kovania, XLSX rozpočtu či ponuky alebo
  ich cestu (`ExportPrep`, `do_*`, zapisovače, `Bom`/rozpočet vo vstupe exportov), musí dať `P == K`, resp. len **vedomé rozdiely uvedené
  v PR**. Povolené rozdiely: riadky `Verzia:`/`Dátum:` vo VEPO LOGu, čas v 1. riadku CSV kovania, dátum v názve; všetko ostatné (aj XLSX
  bajt po bajte po rozbalení) je rozdiel. **Nahrádza ručné exporty R9** — Michal ich už nerobí. Sonda `tests/sketchup/su_export_probe.rb`
  volá `ProductionCore.do_*`; nový export dostane riadok v `ExportPrep::KINDS` aj v sonde (guard `test_export_compare.rb`).

<a id="mcp"></a>

## Interaktívny kanál a diagnostika MCP

- **Interaktívny kanál:** MCP `mcp__vbo-sketchup__execute_ruby` (SketchUp 2026 + VBO SkAgent, port 7891); záloha file-bridge
  (`vbo_sk_agent\bridge\command.rb` → `result.json`, pozor na mtime pascu); overená slučka `-RubyStartup skript + kópia modelu`
  (vzor v `scripts\run_su_tests.ps1`). Deploy pluginu: `INSTALL_noxun_engine.ps1`. Bridge zapínaj len v testovacom okne.
- **Diagnostika MCP:** pri visiacom/zamrznutom porte 7891 spusti `scripts\skagent_doctor.ps1` — zistí držiteľa portu a `/health`, `-Kill`
  odstráni zamrznutý bridge (živú zákazku ani cez `-Force` nezabije). Dump stavu enginu pre bugcatch: `Noxun::Engine::Debug.report` cez
  `execute_ruby` (model + výber + stav panela ako read-only JSON, nikdy nezapisuje).
