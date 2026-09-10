# Balík Čiel — audit návrhu a zapracovanie, 11.9.2026

> Stav: KONCEPT / audit packet — dôkaz kontroly návrhu; záväzné zadanie je v PLAN.md, nejde o review implementácie.

Základ kódu: main `21be151`, v0.10.5. Schválený rozsah D-114/D-119/D-120 vychádza z tohto sedenia s Michalom.
Audit cez lokálny Codex companion, model gpt-6-astra, read-only, bez subagentov a bez runtime testov.

## Prvé kolo

Task `task-mtw4bh68-vq0v0k`, session `01a08d81-99fb-7f52-86a4-82dbbdbfca5e`, trvanie 6m38s.
Výsledok: **0 BLOCKER, 4 FIX-IN-B, 2 NOTE**. Všetkých šesť zapracovaných do znenia packages v PLAN.md.

| Nález | Dôkaz v aktuálnom kóde | Zapracovanie do návrhu |
|---|---|---|
| FIX: skrátené úzke krídlo by zmizlo pred validáciou | `construction.rb:135`, `fronts.rb:221` | Správnu skrátenú os kontroluje Fronts pred emission/filtrovaním, per krídlo; neplatný rozmer odmietne celú prestavbu. |
| FIX: ensure_project_rules! nedoplní starý snapshot | `hardware_rules.rb:760`, `rules_dialog.rb:447` | Starý projekt ostáva reprodukovateľný; vedomé „Doplniť nové predvolené“ cez project_seed_plan a spoločnú prestavbu. |
| FIX: vlastné flap/down nepokrýva flap/up | `hardware_rules.rb:1252`, `hardware_rules.rb:1302` | Samostatný seed pre výklop/sklop, predikát rola+smer v pokrytí aj upozornení. |
| FIX: návrhový režim nemá serverové smerové sloty | `preview.js:319`, `core.js:342` | Jeden čistý Ruby preflight aktuálneho návrhu pre vkladanie aj editáciu; UI dostane count, smerové sloty a resolved hrany. |
| NOTE: uložený profilový konflikt je zbytočný | `fronts.rb:193`, `fronts.rb:355`, `scale_observer.rb:596` | Prijaté zjednodušenie: rozpracovaný formulár a existujúca flush bariéra, posledný platný model, potom jeden atomický apply. Žiadne nové uložené konflikty. |
| NOTE: BuildPlan6 nie je nutnosť | `build_plan.rb:14`, `cabinet_builder.rb:1891` | Prijaté zjednodušenie: pôvodný top profile_band, iba aditívna resolved hrana, spoločný odvodený placement/cut helper; BuildPlan5 zostáva. |

## Kontrola upravenej časti

Task `task-mtw4oguo-qmptd4`, session `01a08d8a-d808-7752-a58b-c3c19ba97e89`, trvanie 3m29s.
Kontrola iba zapracovaných šiestich bodov a existujúcej čítacej/zápisovej/flush cesty.
Výsledok: **SOUND**. Návrhová brána uzavretá; implementácia musí predpísané ochrany a testy ešte preukázať.

## Hranice dôkazu

- Nezmenil sa runtime pluginu, CONFIG_SCHEMA, BuildPlan ani verzia. D-čísla ostávajú otvorené.
- In-SketchUp geometrický probe a implementačné testy neprebehli; patria do ČELÁ-A/B podľa packages.
- Metrážové nacenenie UKW ostáva mimo balíka a existujúca length_unsupported brána sa zachová.
- Lokálny interaktívny mockup `_dev/cela-plan/` je vizuálny podklad, nie ďalší zdroj pravdy pre výpočty pluginu.
