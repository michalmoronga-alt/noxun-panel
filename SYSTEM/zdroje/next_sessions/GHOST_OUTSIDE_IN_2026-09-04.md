# GHOST-D1 / GHOST-D2 — OUTSIDE-IN / prior-art packet (4.9.2026)

> Stav: KONCEPT — research packet + reconcile pre drafty GHOST-D1/D2 (`GHOST_D1_D2_PACKAGE_DRAFT_2026-09-04.md`); nie implementačný spec. **Rozsah: ČIASTOČNÝ** — kanál bol WebFetch
> oficiálnej dokumentácie + fórum (agy kvóta 4.9. vyčerpaná); predpísaný Antigravity beh (skill `antigravity-outside-in`) ani **probe v SketchUpe 2026** ešte NEBEŽALI. Preto sú nálezy rozdelené na
> **VERIFIED** (citované z oficiálnej API dokumentácie) a **UNVERIFIED** (bez probe); tvrdenia ALREADY EXISTS / SIMPLER NATIVE PATH (najmä `Sketchup::Snap`) platia až po probe. Research sa uzavrie
> až agy behom + probe — do vtedy drafty GHOST-D1/D2 do PLANu NEJDÚ.

| Nález | Stav |
|---|---|
| `Sketchup::Tool` callbacky, VCB (`enableVCB?`/`onUserText`), `draw` len v `Tool#draw`, `getExtents`, `onCancel` dôvody | VERIFIED (API docs) |
| `InputPoint#pick` s druhým bodom, `degrees_of_freedom`, `View#lock_inference` | VERIFIED (API docs); správanie v SU 2026 = probe |
| logické pixely od SU 2025.0 pre obrazovkové API | VERIFIED (API docs) |
| `String#to_l` a desatinná čiarka | VERIFIED (fórum + thomthom), presné pravidlá parsovania = UNVERIFIED |
| `Sketchup::Snap` ako SIMPLER NATIVE PATH pre zostavy | **UNVERIFIED — probe v SU 2026 čaká** |
| prior art (Rectangle → Push/Pull, tilda) | VERIFIED (docs/článok) |

## 1 · `Sketchup::Tool` — kontrakt nástroja (nová plocha pre subjekt DOSKA)

- Nástroj je obyčajná trieda s callbackmi (nie podtrieda). Oficiálne: `onKeyDown/onKeyUp` — „Return `true` to prevent SketchUp from processing the event"; `onSetCursor` — vrátiť `true`, ak si
  nástroj kreslí vlastný kurzor; `onCancel(reason, view)` — `reason` 0 = Escape, 1 = nástroj znovu zvolený, 2 = undo; `suspend/resume` pri orbit/pan (ghost skriniek už rieši — `GhostTool`).
- **VCB (Measurements):** `enableVCB?` → `true` zapne vstup (od SU 6.0; „If you do not implement this method, then the vcb is disabled by default"); text príde do **`onUserText(text, view)`** po Enter.
  `Sketchup.vcb_label=`/`vcb_value=` nastavujú popis a hodnotu boxu (rovnaké ako `set_status_text` s `SB_VCB_LABEL`/`SB_VCB_VALUE`).
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

- Natívny **Rectangle → Push/Pull** = presne „bod → rozmer → rozmer" s VCB (`600;18` je natívna syntax obdĺžnika, ale Michal chce **jedno číslo na fázu** — jednoduchšie a bez lokálnych pascí
  oddeľovača zoznamu). Tilda `~` pred hodnotou = približná hodnota (článok „Handling the ~ mark") — v D2 sa nepodporuje (odmietnuť).
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
