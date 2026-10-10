# Grok + OCR (kolo 2) vs. GitHub Codex — vyhodnotenie na 10 PR

Referencia = nálezy GH Codex review na presne tej istej verzii kódu (18 nálezov, z toho 1× P1). Kandidát = Grok Build `grok-4.7`, effort high, OCR v režime delegovania (kolo 2).
Všetky súbory, v ktorých Codex niečo našiel, boli v review Groka zahrnuté (žiadny nebol vylúčený), takže každé „minul“ je skutočné minutie, nie dôsledok filtra.

## Tabuľka po PR

| PR | Codex | Grok | Zhody | Čiastočne | Minul | Grok navyše (pravdivé / sporné / plané) |
|---|---|---|---|---|---|---|
| 466 | 1 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| 457 | 3 | 2 | 1 | 0 | 2 | 1 / 0 / 0 |
| 456 | 1 | 1 | 0 | 0 | 1 | 0 / 1 / 0 |
| 455 | 2 | 2 | 0 | 1 | 1 | 1 / 0 / 0 |
| 454 | 1 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| 438 | 3 | 3 | 2 | 0 | 1 | 1 / 0 / 0 |
| 434 | 4 | 3 | 0 | 0 | 4 | 0 / 1 / 2 |
| 465 | 3 (1× P1) | 4 | 2 | 0 | 1 (P1) | 1 / 1 / 0 |
| 453 | 0 | 1 | 0 | 0 | 0 | 1 / 0 / 0 |
| 437 | 0 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| **Spolu** | **18** | **16** | **5** | **1** | **12** | **5 / 3 / 2** |

## Súhrn

- **Záchyt:** zhody **5 / 18 = 28 %**; zhody + čiastočné **6 / 18 = 33 %**.
- **Presnosť:** potvrdené = zhody + čiastočná zhoda (reálna) + pravdivé navyše = 5 + 1 + 5 = 11 / 16 = **69 % (dolná hranica)**; ak by sa 3 sporné nálezy potvrdili, horná hranica 14 / 16 = **88 %**. Oba plané nálezy (PR 434, `PR #?`) vyvolalo pravidlo kola 2 o zástupnom čísle PR, ktoré bolo na hlave pri otvorení PR chybné (opravené po review #468); bez nich by bola dolná hranica 11 / 14 = 79 %.
- **Plané:** **2** (oba v PR 434 — zástupné „PR #?“, ktoré pravidlá repa v tom momente výslovne predpisujú). Sporné: 3.
- **P1 v PR 465 (duplicitné priradenie modelov mimo tabuľky „Obsadenie rolí“): NEchytil.** Ostatné dva nálezy toho PR chytil plne.
- Tri PR bez nálezu Groka (466, 454, 437) — v dvoch z nich mal Codex reálny P2 v kóde pluginu.

## Podľa oblasti

Codex nálezy sú zaradené podľa súboru, ku ktorému sú ukotvené.

| Oblasť | Codex | Zhody | Čiastočne | Minul | Grok nálezov spolu | Grok navyše (P / S / Pl) |
|---|---|---|---|---|---|---|
| Ruby kód pluginu (`core/`, `ui/*.rb`) | 5 | 1 | 0 | 4 | 2 | 0 / 0 / 0 |
| JS-UI (`ui/js/`) | 5 | 1* | 1 | 3 | 2 | 1 / 0 / 0 |
| Skripty (`scripts/`) | 4 | 0 | 0 | 4 | 0 | 0 / 0 / 0 |
| Dokumentácia (SYSTEM, docs, `.claude/agents`) | 4 | 3 | 0 | 1 (P1) | 12 | 4 / 3 / 2 |
| **Spolu** | **18** | **5** | **1** | **12** | **16** | **5 / 3 / 2** |

\* Codex 438 „direction-toggle status“ je ukotvený v `studio.js`, ale podstata (veta v `production_core.rb`) je Ruby — Grok ho našiel práve v Ruby súbore.

Postreh: 12 zo 16 nálezov Groka je v dokumentácii; v kóde pluginu (Ruby + JS) mal len 4 nálezy, kým Codex 10. Skripty nástroja `ui_foto` (4× P2 u Codexu) Grok neprezrel do hĺbky vôbec.

## Párovania (Codex → Grok)

**PR 466**
- `core/bom.rb:917` stale varovanie nôh pri upravenom pravidle (P2) — **MINUL** (súbor v review); Grok PR vyhodnotil bez nálezu.

**PR 457**
- `production_core.rb:229` nenormalizovaný názov projektu v exportoch (P2) — **MINUL** (súbor v review).
- `production_core.rb:3285` exporty po bráne znova čítajú názov namiesto `gate[:project]` (P2) — **ZHODA** s Grok `production_core.rb:1847`: ten istý problém v CSV kovania, XLSX rozpočtu a ponuky, s rovnakou opravou.
- `studio.js:1413` blur nezmeneného editora prepíše novší názov (P2) — **MINUL** (súbor v review).

**PR 456**
- `export_settings.rb:203` zlý `project_names` sa pri skalárnych zápisoch neopraví (P2) — **MINUL**; Grok sa síce dotkol toho istého scenára, ale v opačnom zmysle (tvrdí, že samooprava funguje, a vytýka len text v STANDARD), takže nejde ani o čiastočnú zhodu.

**PR 455**
- `preview.js:836` vodorovná kóta vnútená do príliš úzkeho úseku → prekrývanie (P2) — **ČIASTOČNE**: Grok `preview.js:856` našiel ten istý mechanizmus (náhradný popis bez kontroly susedov), ale vo zvislých kótach výšok čiel, nie vo vodorovných.
- `preview.js:233` orezaný obrys malej dosky (P2) — **MINUL** (súbor v review).

**PR 454**
- `hardware.js:863` legacy override sa nezapočíta popri compat (P2) — **MINUL** (súbor v review); Grok bez nálezu.

**PR 438**
- `docs/architecture/ui-lifecycle.md:2465` nesprávny opis rozloženia voliteľných stĺpcov (P2) — **ZHODA** s Grok `ui-lifecycle.md:2464` (Grok to dal ako P3, podstata a fakty z kódu rovnaké).
- `studio.js:1106` stavová veta smeru otvárania stále „bez smeru (legacy)“ (P2) — **ZHODA** s Grok `production_core.rb:3303`; Grok navyše presne pomenoval, prečo to nový skener nevidí (`status.call`).
- `materials_dialog.rb:427` žargón „legacy katalóg“ v chybovej vete vrátenia katalógu (P2) — **MINUL** (súbor v review).

**PR 434**
- `scripts/ui_foto/record.rb:110` pri chybe sa SketchUp nezavrie (P2) — **MINUL** (súbor v review).
- `scripts/ui_foto/nx_stub.js:130` neskoré chyby UI po 400 ms sa nezachytia (P2) — **MINUL** (súbor v review).
- `scripts/ui_foto.ps1:290` predvolené prehranie vyberie aj odmietnutú nahrávku (P2) — **MINUL** (súbor v review).
- `scripts/ui_foto.ps1:347` súbežné behy v tej istej sekunde zdieľajú výstupný priečinok (P2) — **MINUL** (súbor v review).

**PR 465**
- `.claude/agents/implementator-stredny.md:24` P1 má opravovať Opus, nie Sonnet (P2) — **ZHODA** s Grok `implementator-lahky.md:24` (Grok pokryl oba súbory aj ďalšie miesta vo WORKFLOW).
- `SYSTEM/WORKFLOW.md:92` triedy Ľ/S/Ť sa prekrývajú bez prednosti (P2) — **ZHODA** s Grok `WORKFLOW.md:88` (rovnaký návrh: Ť > S > Ľ).
- `SYSTEM/WORKFLOW.md:94` **P1** — model a effort duplikované mimo tabuľky „Obsadenie rolí“ — **MINUL** (súbor v review); Grok vytkol len duplicitu definícií tried, nie modelov.

**PR 453, 437** — Codex bez nálezov.

## Nálezy Groka navyše (bez páru v Codexe)

| PR | Nález | Verdikt | Odôvodnenie |
|---|---|---|---|
| 457 | `KRONIKA.md:33` (+ `ui-lifecycle.md:1402`) Q2 „čaká na potvrdenie Michala“, hoci je potvrdené | **PRAVDIVÝ** | KRONIKA r. 32 aj `ui-lifecycle.md:1402` píšu „čaká na potvrdenie“, kým ten istý diff v `ROZHODNUTIA_…:199`, `STAV.md:39` a mockupe píše „potvrdené 2.10.“ (posledný commit PR je práve „Q2 potvrdené“). Nízka závažnosť. |
| 456 | `STANDARD.md:1744` — „bez dobrej zálohy zápis zastavený“ neplatí pre `{}` a zlý `project_names` | **SPORNÝ** | Rozpor STANDARD vs. matica v `outputs.md:1086` je reálny a pre `{}` platí (zápis prejde, súbor sa opraví). Pre zlý `project_names` však Grokovo tvrdenie „samooprava“ nie je pravda (to je presne Codexov nález) — oprava podľa Groka by do štandardu zapísala chybné správanie. |
| 455 | `preview.js:310` kóty šírok v Zónach visia pod nenakresleným čelom | **PRAVDIVÝ** | V Zónach `solid=false` → `sceneSize` berie `frontsExtent()` aj pri vypnutom chipe Čelá; `baseZ: minZ` (nové v tomto PR, r. 377/381) posunie kóty pod spodok čela. Kozmetické, ale reálne. |
| 438 | `KRONIKA.md:26` „Ruby len 5 zobrazovacích reťazcov“ | **PRAVDIVÝ** | Ruby diff mení ~13 reťazcov v 9 súboroch (budget, supplier_settings, tags, appliance_dialog, materials_dialog, actions_board, actions_cabinet, production_core, supplier_settings_dialog); `PACKAGE_H4.md:171` píše „5 súborov“. Faktická chyba v zázname, nízka hodnota. |
| 434 | `PLAN.md:39` STAV stále káže robiť H2 | **SPORNÝ** | STAV naozaj ostal zastaraný (opravil ho až PR #435), ale pravidlo prepisu STAV v tom čase viazalo na zvýšenie VERSION alebo dokumentačné PR — nástrojové PR bez bumpu ho výslovne nepokrýva. Závažnosť P2 nadhodnotená. |
| 434 | `PLAN.md:39` zástupné „PR #?“ | **PLANÝ** | `CLAUDE.md:153` a `PLAN.md:4` predpisujú písať `PR #?` pred `gh pr create` a číslo doplniť samostatným commitom hneď potom (stalo sa v `e6e06a15`). Recenzovaná hlava je presne stav pri otvorení PR. |
| 434 | `KRONIKA.md:20` zástupné „PR #?“ | **PLANÝ** | Rovnaký dôvod ako vyššie. |
| 465 | `WORKFLOW.md:84` tvrdenie „effort sa pri volaní Agent tool nedá nastaviť“ je nepravdivé | **PRAVDIVÝ** | Overené: docs `code.claude.com/docs/en/sub-agents` uvádzajú per-invocation parameter `effort` od v2.1.292 a changelog dáva vydanie 6.10.2026 — teda pred „overené 7.10.2026“ v texte. Silný nález nad rámec Codexu. |
| 465 | `WORKFLOW.md:46` riadok shadow Groka: `bench/<úloha>-grok` a „slepou recenziou“ vs. matica `bench/<úloha>-<model>` a dvaja recenzenti | **SPORNÝ** | Mierny nesúlad textov existuje, ale `-grok` je dosaditeľná podoba `-<model>` a „slepou recenziou“ neudáva počet; reálny dopad malý. |
| 453 | `PLAN.md:46` a `:82` R-38 stále „návrh — potvrdí Michal“ | **PRAVDIVÝ** | Ten istý diff zapisuje „R-38 v H7: áno“ (`ROZHODNUTIA_…:188`, `STAV.md:37`) a „mockupy H6 a H7 schválil Michal 2.10.“ (`PLAN.md:33`), riadok H7 ostal neaktualizovaný. Nízka závažnosť. |

## Záver

Grok + OCR v tomto kole zachytil len 5 z 18 Codex nálezov (6 s čiastočnou zhodou, 33 %) a minul jediný P1 (PR 465), hoci všetky dotknuté súbory mal v review. Jeho presnosť je slušná (potvrdených 69 %, s potvrdením sporných až 88 %; len 2 plané nálezy, oba spôsobené chybným pravidlom o `PR #?`), no sila je posunutá do dokumentácie: 12 zo 16 nálezov sú nesúlady medzi STAV, PLAN, KRONIKA a architektúrou — tie sú väčšinou pravdivé, ale málo závažné, a jeden (effort parameter Agent tool) je reálny prínos, ktorý Codex nemal. V kóde pluginu a skriptoch je slabý: z 10 Codex nálezov v Ruby/JS zachytil 2 a pol, zo 4 P2 v skriptoch `ui_foto` žiadny, v dvoch PR s reálnymi chybami v kóde (466, 454) nenašiel nič a v PR 457 len 1 z 3 nálezov Codexu. Ako náhrada Codexu pre kódové PR preto zatiaľ nevyhovuje; použiteľný je ako lacný doplnkový kontrolór dokumentačných a workflow PR (konzistencia STAV/PLAN/KRONIKA), kde dopĺňa veci, ktoré Codex prehliada.
