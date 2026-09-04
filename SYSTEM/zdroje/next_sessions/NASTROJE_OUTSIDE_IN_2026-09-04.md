# NÁSTROJE-1 — OUTSIDE-IN / prior-art packet (4.9.2026)

> **Kanál:** Antigravity (agy) mal 4.9. vyčerpanú kvótu, packet vznikol cez WebSearch + WebFetch oficiálnej dokumentácie SketchUp Ruby API (ruby.sketchup.com) a fóra.
> Rozsah je úmyselne úzky — NÁSTROJE-1 je presun vlastných nástrojov (Noxun Mower, Snaper) do balíka enginu; **nové API plochy v repe** sú `Model#drawing_element_visible?`
> a `Entities#transform_entities` (Codex #288 kolo 2 P1). Reconcile je v poslednej sekcii a v package v `PLAN.md`.

## 1 · `Sketchup::Model#drawing_element_visible?(instance_path)` — SIMPLER NATIVE PATH s pascou

- **Od SketchUp 2020.0.** Vstup `Sketchup::InstancePath` alebo pole drawing elementov; vracia, či je prvok v danej ceste viditeľný **vrátane nastavení modelu** („DrawHiddenGeometry", „DrawHiddenObjects") —
  teda skryté objekty, tagy, tag foldery a rodičia v ceste.
- **Pasca (oficiálne):** „Prior to version 2026.0 the method throws an exception when the last element in the instance path is a Group or ComponentInstance." → Snaper prechádza práve
  kontajnery (skupiny/komponenty). **Reconcile:** volať pod `rescue` s fallbackom na dnešnú kontrolu (`hidden?` + `layer.visible?` po celej ceste); na SU 2026 je natívna cesta plnohodnotná.
  Test musí pokryť obe vetvy (natívna aj fallback), nie iba jednu.
- Alternatíva bez novej API plochy: ručný prechod instance path (`hidden?`, `layer.visible?`, `Layer#folder` viditeľnosť). Natívna metóda je presnejšia (rešpektuje aj model options), preto ostáva
  primárna, fallback ju kryje.

## 2 · `Sketchup::Entities#transform_entities(transform, entities)` — kontext rozhoduje o súradniciach

- **Od SketchUp 6.0.** Oficiálne: „If you are transforming entities in the active drawing context or any of its parent drawing contexts, the transformation will be interpreted as relative to the global
  coordinate system. Otherwise the transformation will be interpreted as being on the local coordinate system."
- **Dôsledok pre Mower:** dnešné rotácie/Z fungujú „svetovo" LEN v root kontexte; vo vnútri otvoreného komponentu sa pivot aj os interpretujú inak (Codex CLI FIX 5). **Reconcile:** nástroje pracujú
  výhradne v root kontexte (`model.active_path` prázdny) — inak hláška a žiadna operácia; `edit_transform` (od 7.0) sa v V1 nepoužije (menej plôch, menej rizika).

## 3 · `UI::Toolbar` — `restore` vs `show`, stav medzi sedeniami

- `show` toolbar zobrazí; `restore` „repositions the toolbar to its previous location and show if not hidden"; `get_last_state` → `TB_VISIBLE` (1) / `TB_HIDDEN` (0) / `TB_NEVER_SHOWN` (−1).
- **Reconcile:** registrátor nástrojov použije vzor enginu (`install_toolbar`): pri prvom spustení `show`, inak `restore` podľa `get_last_state` — používateľ, ktorý toolbar skryl, ho po reštarte
  nedostane naspäť nasilu. Jedna sada `UI::Command` pre menu aj toolbar, `file_loaded?` guard (Codex CLI FIX 9).

## 4 · `Sketchup::Snap` (SketchUp 2025.0) — natívne „snaps" pre skladanie objektov — ALREADY EXISTS (pre neskôr)

- „A Snap is a custom grip used by SketchUp's Move tool. Snaps can be added at strategic places such as connectors to help assembling objects." Snap má `position`, `direction`, `up`;
  pri spojení dvoch objektov majú snapy opačné `direction` a zhodné `up` → Move tool objekt **umiestni aj natočí** naraz.
- **Význam:** nie pre NÁSTROJE-1 (Snaper je posun na doraz, nie spájanie), ale **kandidát SIMPLER NATIVE PATH pre zostavy / GHOST** — korpus by mohol niesť snapy na bočných hranách a natívny Move by
  skrinky prikladal k sebe aj s orientáciou. Zapísať do bloku viazaných dielov (po V1) a do outside-in pre GHOST-D1/D2 pred ich návratom do PLANu.

## 5 · Prior art (extensions, fórum)

- **Move extension** (Extension Warehouse): „Copy to Positions" s voľbou zarovnania (Base / Midpoint / Top bbox) — potvrdzuje, že kopírovanie s explicitnou kotvou je bežný vzor; Mower to má cez
  „kópia o šírku po vlastnej osi", čo je pre kuchynský rad presnejšie než bbox kotvy.
- **Snap Connector Tool** (CADMan): konektory pre skladanie, historicky problémy s kompatibilitou pri nových verziách SU — argument pre natívne `Sketchup::Snap` namiesto vlastného konektora.
- Fórum Ruby API: „panel/shelf copying with reference point alignment and array input" — rovnaký problém (kotva + krok); riešenia stavajú na `add_instance` + transformácii — **presne pasca, ktorú
  NÁSTROJE-1 opravuje** (kópia bez identity; u nás ide kópia cez šev enginu).

## 6 · Reconcile do package NÁSTROJE-1

1. `drawing_element_visible?` ostáva (presnejšie než ručná kontrola), ale **s `rescue` fallbackom** pre SU < 2026 a testom oboch vetiev.
2. `transform_entities` len v root kontexte — nástroje mimo root odmietnu (už v package, teraz s oficiálnym dôvodom).
3. Toolbar: `show`/`restore` podľa `get_last_state`, jeden registrátor.
4. `Sketchup::Snap` = poznámka do bloku viazaných dielov a do GHOST outside-in (nie do NÁSTROJE-1).

Zdroje: [Model#drawing_element_visible?](https://ruby.sketchup.com/Sketchup/Model.html#drawing_element_visible%3F-instance_method) · [Entities#transform_entities](https://ruby.sketchup.com/Sketchup/Entities.html#transform_entities-instance_method) ·
[UI::Toolbar](https://ruby.sketchup.com/UI/Toolbar.html) · [Sketchup::Snap](https://ruby.sketchup.com/Sketchup/Snap.html) · [Move extension](https://extensions.sketchup.com/extension/b887368d-36fc-475e-a682-c93725808e4a/move) ·
[Snap Connector Tool](https://forums.sketchup.com/t/snap-connector-tool-sketchup-2024/271253) · [fórum: panel copying with reference point](https://forums.sketchup.com/t/how-to-implement-panel-shelf-copying-with-reference-point-alignment-and-array-input-in-ruby-api/348610)
