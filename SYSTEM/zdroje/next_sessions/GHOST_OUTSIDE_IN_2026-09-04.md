# GHOST-D1 / GHOST-D2 — OUTSIDE-IN / prior-art packet (4.9.2026)

> Stav: KONCEPT — research packet + reconcile pre drafty GHOST-D1/D2 (`GHOST_D1_D2_PACKAGE_DRAFT_2026-09-04.md`); nie implementačný spec. **Rozsah: ČIASTOČNÝ** — kanál bol WebFetch
> oficiálnej dokumentácie + fórum (agy kvóta 4.9. vyčerpaná); **Antigravity beh PREBEHOL 4.9. večer** (4 packety Gemini 3.8 Flash, sekcia „Antigravity beh" nižšie); **probe v SketchUpe 2026 ešte čaká** (`_dev/probe_ghost_keys.rb`). Preto sú nálezy rozdelené na
> **VERIFIED** (citované z oficiálnej API dokumentácie) a **UNVERIFIED** (bez probe); tvrdenia ALREADY EXISTS / SIMPLER NATIVE PATH (najmä `Sketchup::Snap`) platia až po probe. Research sa uzavrie
> až agy behom + probe — do vtedy drafty GHOST-D1/D2 do PLANu NEJDÚ.

| Nález | Stav |
|---|---|
| `Sketchup::Tool` callbacky, VCB (`enableVCB?`/`onUserText`), `draw` len v `Tool#draw`, `getExtents`, `onCancel` dôvody | VERIFIED (API docs) |
| `InputPoint#pick` s druhým bodom, `degrees_of_freedom`, `View#lock_inference` | VERIFIED (API docs); správanie v SU 2026 = probe |
| logické pixely od SU 2025.0 pre obrazovkové API | VERIFIED (API docs) |
| `String#to_l` a desatinná čiarka | VERIFIED (fórum + thomthom), presné pravidlá parsovania = UNVERIFIED |
| `Sketchup::Snap` ako SIMPLER NATIVE PATH pre zostavy | VERIFIED (agy, docs: perzistentná snap entita `Entities#add_snap` pre natívny Move) → **NO ACTION pre D1/D2**, poznámka pre zostavy po V1 |
| prázdny Enter: `onKeyDown(VK_RETURN)` vs. VCB `onUserText` | VERIFIED (agy, docs): **`VK_RETURN` v API NEEXISTUJE** (kód 13); prázdny Enter = `Tool#onReturn(view)` → správanie pri zapnutom VCB = **probe čaká** |
| prior art (Rectangle → Push/Pull, tilda) | VERIFIED (docs/článok) |

## 1 · `Sketchup::Tool` — kontrakt nástroja (nová plocha pre subjekt DOSKA)

- Nástroj je obyčajná trieda s callbackmi (nie podtrieda). Oficiálne: `onKeyDown/onKeyUp` — „Return `true` to prevent SketchUp from processing the event"; `onSetCursor` — vrátiť `true`, ak si
  nástroj kreslí vlastný kurzor; `onCancel(reason, view)` — `reason` 0 = Escape, 1 = nástroj znovu zvolený, 2 = undo; `suspend/resume` pri orbit/pan (ghost skriniek už rieši — `GhostTool`).
- **VCB (Measurements):** `enableVCB?` → `true` zapne vstup (od SU 6.0; „If you do not implement this method, then the vcb is disabled by default"); text príde do **`onUserText(text, view)`** po Enter.
  `Sketchup.vcb_label=`/`vcb_value=` nastavujú popis a hodnotu boxu (rovnaké ako `set_status_text` s `SB_VCB_LABEL`/`SB_VCB_VALUE`). **Prázdny Enter** (package: prázdny Enter vo fáze = prevezme
  hodnotu karty) cez `onUserText` NEPRÍDE (bez textu sa callback nevolá; archívny Ghost 2.0 nechával `VK_RETURN` prejsť a prázdny text bral ako no-op) — D2 musí prázdny Enter chytiť v **`Tool#onReturn(view)`** (agy 4.9.: konštanta `VK_RETURN` v SketchUp API NEEXISTUJE, Enter = kód 13; `onUserText` sa pri prázdnom poli
  nevolá) a písané hodnoty nechať `onUserText`; **`onReturn` so zapnutým VCB v SU 2026 = probe (`_dev/probe_ghost_keys.rb`)**.
- **Kreslenie:** metódy `View#draw`/`draw2d` fungujú **LEN v `Tool#draw`** („Calling them outside Tool#draw will have no effect"); ak kreslíš mimo obálky modelu, implementuj `getExtents`
  (inak sa časť kresby oreže). `line_stipple=` prijíma `"."`, `"-"`, `"_"`, `"-.-"`, `""`; `line_width=` od SU 2026.0 minimálne 1.0; `set_color_from_line` dá farbu osi (červená/zelená/modrá).
- **Pixely (breaking 2025.0):** LEN obrazovkové API — `x, y` v callbackoch, `View#inputpoint`, `draw2d`, `vpwidth/vpheight/center/corner` — sú od SU 2025 **logické pixely** (Float), predtým fyzické
  (Integer); kód nesmie predpokladať Integer ani miešať oba svety. **Modelová geometria ostáva v modelových jednotkách** (`InputPoint#position` = Point3d v modeli, obálka ghostu do `View#draw`
  a `getExtents` = modelové body; hranica mm ↔ palce enginu sa nemení). `View#invalidate` je preferovaný redraw.
- **Reconcile D1/D2:** ghost dosky zdedí lifecycle klasického ghostu (jeden `Sketchup::Tool` + `PlacementSession` so subjektom), pridá `enableVCB?`/`onUserText` len v D2 (fázy 1–2), `getExtents`
  pri kreslení obálky mimo modelu (prázdny model!); obrazovkové súradnice ako logické pixely, geometria v modelových jednotkách.

## 2 · `Sketchup::InputPoint` + `View#lock_inference` — prichytávanie a osi

- `InputPoint#pick(view, x, y, inputpoint2 = nil)` vráti, či sa našiel platný ZMENENÝ bod; **s druhým InputPointom** „will find additional inferences such as along one of the axis directions from
  the first point" — presne mechanika 2. a 3. bodu pri ťahaní rozmeru od nulového bodu (D2 fázy). `degrees_of_freedom`: 3 voľný priestor · 2 na ploche · 1 na hrane/osi · 0 vrchol/priesečník.
- `position` (Point3d v modelovom priestore), `face/edge/vertex`, `instance_path` (2017+), `transformation`, `draw(view)` (natívna grafika inferencie), `tooltip`, `valid?`, `clear`.
- `View#lock_inference(ip1, ip2 = nil)` + `inference_locked?` — zámok osi „ako natívne nástroje" (Shift v Rectangle). **Dnešný ghost skriniek inferenciu NEZAMYKÁ** — GHOST-FB1 volá len `@ip.draw`
  + tooltip (zobrazenie inferovaného bodu) a nemá Shift lock lifecycle; zámok osi je preto **NOVÁ práca D2** (lock/unlock na Shift, stav v session, test).
- **Reconcile D2:** fáza 1 (dĺžka) = `pick(view, x, y, @ip0)` s inferenciou od nulového bodu, axis snap cez `lock_inference` (Shift) alebo vlastný „axis snap" zo V2fable; fáza 2 (šírka) =
  pick s druhým bodom = koniec dĺžky; orientácia z prvého ťahu; kreslenie obálky v `draw` s `line_stipple "-"` pre ghost.

## 3 · `String#to_l`, `Length`, `RegionalSettings` — vstup čísla z VCB (D2 „jedno číslo na fázu")

- `String#to_l` prevádza reťazec na dĺžku **v jednotkách modelu** (od SU 6.0); dokumentácia NEuvádza podporované prípony ani správanie desatinnej čiarky. Fórum/thomthom: v locale s desatinnou
  čiarkou `"1,5".to_f` = 1.0, `1.5.mm.to_s` = `"1,5mm"`, `.to_l` pri „cudzom" oddeľovači hádže `ArgumentError`; desatinný znak locale dáva `Sketchup::RegionalSettings.decimal_separator`.
- **Reconcile D2 (Michal: jedno číslo na fázu, mm):** VCB vstup parsovať VLASTNOU čistou funkciou s ÚPLNOU zhodou po `strip`: `\A\d+([.,]\d+)?\s*(mm)?\z` (obe desatinné čiarky, prípona `mm` voliteľná), všetko ostatné
  (`abc2400xyz`, `2400mmjunk`, `~600`, `600;18`) = neplatné (fáza ostáva + status); **nikdy** `to_l`/`to_f` priamo na surový text; hodnota = mm Float, do modelu cez `Units` (mm → palce) ako všade v engine; validácia proti `BoardBuilder::LIMITS` PRED
  prijatím (Codex #288). `Sketchup.vcb_value=` ukazovať vždy v mm s desatinným znakom locale (len zobrazenie).

## 4 · `Sketchup::Snap` (2025.0) — ALREADY EXISTS pre skladanie (po V1)

- „A Snap is a custom grip used by SketchUp's Move tool"; `add_snap` na definícii/entities, `position`/`direction`/`up`; pri spojení majú snapy opačné `direction` a rovnaké `up` → Move
  **umiestni aj natočí**. Pre GHOST-D1 nie (ghost nie je Move), pre zostavy po V1 = kandidát SIMPLER NATIVE PATH (korpus so snapmi na bokoch, pracovná doska so snapmi na hranách).

## 5 · Prior art (natívne vzory)

- Natívny **Rectangle → Push/Pull** je NAJBLIŽŠÍ, ale NIE presný precedens: Rectangle berie OBA rovinné rozmery naraz druhým bodom (VCB `600;18`) a Push/Pull dodá tretí rozmer; D2 má **vedome
  iný tok** — dĺžka a šírka ako dva samostatné ťahy/kliky po lokálnych osiach (každý s JEDNÝM číslom, Michal 4.9.) a hrúbku pevne z materiálu. Cena odchýlky = jeden klik navyše oproti Rectangle;
  zisk = šírka sa ťahá/píše samostatne po lokálnej osi bez oddeľovača zoznamu a jeho locale pascí. UX audit má túto odchýlku posúdiť ako vedomú, nie ju prehliadnuť. Tilda `~` pred hodnotou = približná hodnota (článok „Handling the ~ mark") — v D2 sa nepodporuje (odmietnuť).
- **Vlastný archív:** V2fable Ghost 2.0 (`archiv_kod/v2fable_ghost_tool2.rb.txt`) — fázy, `enableVCB?`/`onUserText`, `vcb_value`, axis snap, locks; pasca ľavotočivého 2. ťahu (Codex #288 kolo 2).
- GHOST skriniek (V1-04, PR #265–#271) = domáci vzor lifecycle, snapov, kotiev, klávesov a `push_state` pásiku — subjekt DOSKA ho rozširuje, nekopíruje.

## 6 · Reconcile do draftov GHOST-D1/D2 (pred návratom do PLANu)

1. D1: subjekt DOSKA v existujúcom `GhostTool` (jeden Tool), `getExtents` pri kreslení obálky, logické pixely, `onCancel` reason 2 (undo) = zrušiť session bez zápisu.
2. D2: fázy cez `InputPoint#pick` s druhým bodom + `lock_inference`; `enableVCB?`/`onUserText` len vo fázach 1–2; vlastný parser čísla s ÚPLNOU zhodou po `strip` — `\A\d+([.,]\d+)?\s*(mm)?\z` (bod aj čiarka, `mm` voliteľné; prefix/sufix odpad, tilda a `;` odmietnuté, testy);
   validácia `LIMITS` pred prijatím; `Sketchup.vcb_label=` „Dĺžka (mm)" / „Šírka (mm)".
3. Pravotočivý 2. ťah (kolo 2 P1): posun počiatku o −šírka po lokálnej Y, osi ostávajú pravotočivé (žiadne obrátenie `dir_y`).
4. `Sketchup::Snap` = poznámka do bloku viazaných dielov (po V1), nie do D1/D2.

Zdroje: [Sketchup::Tool](https://ruby.sketchup.com/Sketchup/Tool.html) · [Sketchup::InputPoint](https://ruby.sketchup.com/Sketchup/InputPoint.html) · [Sketchup::View](https://ruby.sketchup.com/Sketchup/View.html) ·
[Sketchup (vcb_label=/vcb_value=)](https://ruby.sketchup.com/Sketchup.html) · [String#to_l](https://ruby.sketchup.com/String.html) · [RegionalSettings](https://ruby.sketchup.com/Sketchup/RegionalSettings.html) ·
[thomthom: Dealing with Units](https://www.thomthom.net/thoughts/2012/08/dealing-with-units-in-sketchup/) · [fórum: comma delimiter to_l](https://forums.sketchup.com/t/htmldialog-users-system-expects-a-comma-delimiter-number-to-l-throws-an-error/193737) ·
[Sketchup::Snap](https://ruby.sketchup.com/Sketchup/Snap.html) · [Handling the ~ mark](https://developer.sketchup.com/article-handlingthemark)

## Antigravity beh (4.9.2026 večer, 4 packety `gemini-3.8-flash-high`, `--mode plan`; surové packety: [GHOST_OUTSIDE_IN_2026-09-04_agy_packety.md](GHOST_OUTSIDE_IN_2026-09-04_agy_packety.md))

Štyri malé behy (1–2 otázky každý): `vcb` (meracie pole, parsovanie) · `infer` (inferencia, zámok osi, `Sketchup::Snap`) · `prec` (CAD precedensy, klávesy) · `life` (lifecycle náhľadu, undo).
Pasca behu: prvý `life` beh skončil prázdny (agent skúsil `command` tool → headless auto-deny, exit 0) — opakovaný s pravidlom „no shell" v prompte.

| # | Kategória | Nález (agy, všetko VERIFIED s URL + probe snippetom) | Dotknuté | Reconcile (orchestrátor) |
|---|---|---|---|---|
| 1 | SIMPLER NATIVE PATH | Prázdny Enter: `onUserText` sa nevolá, SketchUp volá `Tool#onReturn(view)` (Tool.html#onReturn) | D2 prázdny Enter = hodnota karty | **BERIEME** — `onReturn` namiesto `onKeyDown(VK_RETURN)`; správanie so zapnutým VCB v SU 2026 = probe |
| 2 | MISSED CONSTRAINT | Konštanta `VK_RETURN` v SketchUp API neexistuje (top-level-namespace: len VK_UP/DOWN/LEFT/RIGHT/SHIFT/…); Enter = kód 13; agy uvádza regresiu `onKeyDown` pri Enter v 2026.0 (fix 2026.1) | D2, packet r. 43 | **MENÍ NÁVRH** — draft opravený (bod 6 reconcile); regresiu overí probe (`Sketchup.version`) |
| 3 | MISSED CONSTRAINT | `String#to_l` na slovenskom Windows padá pri bodke, bez jednotky berie jednotky šablóny (`RegionalSettings.decimal_separator`) | D2 parser | **BERIEME** — potvrdzuje vlastný parser (už v drafte) |
| 4 | GOOD CUSTOM SOLUTION | Vlastný parser je správny; doplniť `strip`, `/i` pre `MM`, medzery okolo (`\A\s*(\d+(?:[.,]\d+)?)\s*(?:mm)?\s*\z/i`) | D2 parser | **BERIEME** — draft bod 7 |
| 5 | CAD PRECEDENT (MIT) | Trimble `99_sphere_tool`: neplatný VCB vstup = `UI.beep` + fáza ostáva, žiadny pád nástroja | D2 chybový stav | **BERIEME** ako vzor (status + beep) |
| 6 | ALREADY EXISTS | `InputPoint#pick(view, x, y, ip_predošlý)` = inferencia relatívne k predošlému bodu vrátane „on axis from point" | D2 fázy 1–2 | **BERIEME** (už v drafte, bod 2) |
| 7 | MISSED CONSTRAINT | agy: `View#lock_inference` zamkne len globálne osi / nájdené natívne inferencie; lokálna os = projekcia `Point3d#project_to_line` — snippet však `lock_inference` nevolá | D2 lokálne osi | **BERIEME S VÝHRADOU** (Codex #294): API prijíma DVA InputPointy a zamyká líniu medzi nimi → probe so syntetickými bodmi na lokálnej osi (`_dev/probe_ghost_keys.rb`, klik = os); ak zamkne, natívny zámok; projekcia = fallback |
| 8 | CAD PRECEDENT (MIT) | `Eneroth3/inference-lock-lib` v1.0.0 — vzor spracovania Shift/šípok pre zámok inferencie v custom Tool | D2 Shift lock | **BERIEME** ako vzor pre Shift (nie kód) |
| 9 | NO ACTION | `Sketchup::Snap` (2025.0) = perzistentná snap entita (`Entities#add_snap`) pre natívny Move — nie lifecycle pre custom tool | D1 prichytenie | **NEBERIEME pre V1**; poznámka pre viazané diely/zostavy po V1 (snap body na definíciách skriniek) |
| 10 | CAD PRECEDENT | Natívny Rotated Rectangle = jedno číslo na fázu (dĺžka → šírka) s náhľadom; s4u Panel = doska z bodov s hrúbkou z predvoľby | D2 VCB | **BERIEME** — potvrdzuje rozhodnutie Michala (jedno číslo na fázu) |
| 11 | CAD PRECEDENT (GPL) | OpenCutList 7.0.0 (9/2025) Smart Draw Tool — ťahanie dielcov z materiálových šablón s obálkou | D2 obálka | **VZORY ÁNO, KÓD NIE** (GPL) |
| 12 | CAD PRECEDENT (proprietárne) | SketchList 3D definuje dosku 3 diskrétnymi orientáciami (Horizontal / Vertical / Front-to-Back); Polyboard len výplne zón | D1 orientácia | **BERIEME** — potvrdzuje 3 stavy `leziaca/stojaca/na_stenu` |
| 13 | MISSED CONSTRAINT | Šípky ↑←→↓ sú od SU 2016 natívny zámok osí; custom Tool ich v `onKeyDown` pohltí (`true`), ale používateľ stráca natívny zámok; agy navrhuje Tab = orientácia, R/koliesko = rotácia (vzor s4u Panel) | D1/D2 klávesy | **ROZHODNUTÉ (a) — Michal 4.9.:** ako ghost skrinky (←/→ rotácia, ↑/↓ orientácia); natívny zámok osí je v ghoste vedome pohltený, D2 ťahy idú po lokálnych osiach (probe r. 7 / projekcia) |
| 14 | GOOD CUSTOM SOLUTION | Žiadne rozšírenie nemá živý ghost dosky s prepínaním 3 orientácií bez dialógu | D1 | **BERIEME** — staviame (žiadny ALREADY EXISTS) |
| 15 | MISSED CONSTRAINT | `Tool#getExtents` povinný pre náhľad mimo obálky modelu / prázdny model; prekresľovať `View#invalidate` (nie `refresh`) | D1/D2 draw | **BERIEME** (už v drafte) |
| 16 | MISSED CONSTRAINT | Logické pixely od 2025.0: `x,y` callbackov, `draw2d`, `vpwidth/vpheight`, `screen_coords`, vstup `pickray`, `PickHelper`, `InputPoint#pick`; modelové jednotky: `View#draw`, výstup `pickray`, `InputPoint#position` | D1/D2 | **BERIEME** (už v drafte po #292) — zoznam API doplnený sem |
| 17 | MISSED CONSTRAINT | `Tool#onCancel` reason 0 = Esc, 1 = reaktivácia nástroja, 2 = Undo počas nástroja → reset session bez zápisu | D1/D2 session | **BERIEME** (už v drafte, bod 1) |
| 18 | NO ACTION | `Sketchup::Overlay` je pasívna (bez vstupov, mutácia modelu = RuntimeError) — nenahradí Tool + InputPoint/PickHelper | architektúra | **NEBERIEME** — ostáva `Sketchup::Tool` |
| 19 | MISSED CONSTRAINT | 1 krok Späť: `start_operation(name, true, false, false)` bez vnorenia, `rescue → abort_operation` | D1/D2 commit | **BERIEME** — explicitne do package (draft bod 9); zhodné s konvenciou enginu |
| 20 | CAD PRECEDENT (MIT) | Trimble `sketchup-ruby-api-tutorials/02_custom_tool` — kanonická kostra Tool (getExtents, draw, InputPoint v onMouseMove, onCancel reset) | kostra | **BERIEME** ako referenčnú kostru |

**RESEARCH GAP (agy):** žiadna open-source knižnica nahrádzajúca `to_l` VCB parserom (ekosystém: `to_l` + `rescue` alebo inline regex) · žiadne rozšírenie s ghostom dosky + 3 orientácie.

**Čo ešte chýba pred návratom draftov do PLANu:** (1) probe v SU 2026 — `_dev/probe_ghost_keys.rb` (Michal ručne v testovacom okne: prázdny Enter → `onReturn`?, `600 Enter` → `onUserText`,
šípky v `onKeyDown` + či pohltenie zruší natívny zámok, `Sketchup.version` kvôli regresii Enter v 2026.0, prítomnosť `Sketchup::Snap`); (2) šípky ROZHODNUTÉ (a) — Michal 4.9. (r. 13); (1b) probe `lock_inference(ip_a, ip_b)` so syntetickými InputPointmi na lokálnej osi (Codex #294);
(3) prepis draftov podľa reconcile → `codex-audit` → PLAN.

## Probe v SketchUpe 26.0.429 (Michal, 5.9.2026, `_dev/probe_ghost_keys.rb`) — VÝSLEDKY

| Otázka | Výsledok | Dôsledok pre package |
|---|---|---|
| `VK_RETURN` | `defined?(VK_RETURN) = nil` | potvrdené — Enter = kód 13, prázdny Enter cez `Tool#onReturn` |
| prázdny Enter so zapnutým VCB | `onKeyDown key=13` → **`onReturn`** → `onKeyUp 13`; `onUserText` nepríde | D2: prázdny Enter = `onReturn` (hodnota karty) |
| „600 Enter" | číslice prídu aj do `onKeyDown` (numpad 102/96/96), potom `onKeyDown 13` → **`onUserText "600"`**; `onReturn` sa nevolá | D2: písané hodnoty = `onUserText`; regresia Enter v 26.0 (agy) sa NEPOTVRDILA |
| šípky, Shift | `onKeyDown` s `VK_DOWN/RIGHT/LEFT/UP` (40/39/37/38), `VK_SHIFT` (16) | D1/D2 klávesy podľa (a) |
| `lock_inference(ip_a, ip_b)` syntetické body | `inference_locked? = false` (3 pokusy) | **natívny zámok na vlastnú os NEFUNGUJE → projekcia je mechanizmus** (Codex #294 otázka uzavretá) |
| Esc | `onKeyDown 27` → `onCancel reason=0` | potvrdené |
| Ctrl+Z počas nástroja (bez operácie) | prídu len klávesy 17 + 90, `onCancel reason=2` nepotvrdený (nebolo čo vrátiť) | reason 2 ošetriť podľa docs, overí in-SU test D1 |
| `Sketchup::Snap` | existuje (`direction`, `position`, `set`, `up`; `Entities#add_snap = true`) | NO ACTION pre V1, poznámka pre viazané diely |

**Uzáver researchu:** outside-in HOTOVÝ (WebFetch + agy + probe). Packages GHOST-D1/D2 sú od 5.9.2026 v `SYSTEM/PLAN.md` (blok 4) ako autorita; ďalší krok = `codex-audit` pred implementáciou.
