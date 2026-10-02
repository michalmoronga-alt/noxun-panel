# Pravidlá písania SketchUp Ruby pluginov

Destilát z „Výskumná správa pre kódera SketchUp pluginov" (deep research, júl 2026) + praktické skúsenosti z pluginov Noxun. Platí pre všetok nový kód v tomto workspace.

## Štruktúra extensionu

- **Jeden top-level namespace** na plugin: `module Noxun::<Plugin>`. Žiadne globálne premenné, žiadne monkey-patchovanie SketchUp API. Všetky extensiony zdieľajú jeden Ruby proces — kolízia mien rozbije cudzí plugin.
- **Loader (root `.rb`) robí len registráciu** `SketchupExtension` — žiadna logika. Logika v rovnomennom podpriečinku. Umožňuje disable/enable bez načítania kódu.
- **Súbory pluginu (Noxun Engine) výhradne cez `AppLifecycle.require_part 'noxun_engine/…'`** — Ruby `require` s absolútnou cestou, rovnaká semantika na
  SketchUpe 2026.0 aj 2026.2 (`Sketchup.require` chyby do 2026.1 prehltne, od 2026.2 ich prepustí). Chyba súboru = jedna hláška, plugin v tom okne vypnutý,
  obnova **reštartom SketchUpu**. Plugin sa **nešifruje** (`.rbe`/`.rbs` Ruby `require` nenačíta; guard test). Prvý súbor (`core/app_lifecycle.rb`) načíta
  bootstrap v `main.rb` s vlastnou chybovou vetvou. Ostatné pluginy rodiny Noxun: `Sketchup.require` namiesto `require_relative`.
- Po inštalácii **nezapisovať do priečinka pluginu** — užívateľské dáta do `%APPDATA%` (u nás `%APPDATA%\NOXUN\<Plugin>\`).

## Geometria

- **Každá užívateľská akcia = jedna undo operácia:** `model.start_operation("Názov", true)` … `commit_operation`; pri chybe `abort_operation`. MR-3B Apply používa v tej istej normálnej operácii `disable_ui=false`, aby vnorený `make_unique` s DC atribútmi nevypol selection eventy (D-40). Výnimka: `redraw_with_undo` dynamických komponentov NIKDY vnútri otvorenej operácie (viď DC_PRAVIDLA).
- **Rozmery vždy ako `Length`:** `600.mm`, nikdy holé číslo (SketchUp interne počíta v palcoch — `600` znamená 600″).
- **Kontrola normály pred pushpull:** `face.reverse! unless face.normal.samedirection?(Z_AXIS)` — `add_face` negarantuje smer.
- **Group-first:** najprv vytvoriť group/komponent, potom kresliť do jeho `entities` (nie dodatočne zoskupovať).
- **Bulk geometria cez `Sketchup::EntitiesBuilder`** (SU 2022+) — rádovo rýchlejšie pri generovaní celých korpusov.
- **Pri modifikácii kolekcie počas iterácie** iterovať cez `to_a` kópiu.
- Selection meniť hromadne (`selection.add(pole)`), nie po jednom.

## Dáta a perzistencia

- **`AttributeDictionary` podporuje len:** Boolean, Integer, Float, Length, nil, String, Time, Array, Point3d, Vector3d. Zložitejšie štruktúry ukladať ako JSON String (tak to robí KOVANIE — `NOXUN_KOVANIE/items`).
- Pozor: Point3d/Vector3d na vertexoch sa transformujú s geometriou — surové súradnice ukladať ako obyčajné pole čísel.
- **`Sketchup.write_default`/`read_default`** pre malé nastavenia — ukladať Float (Length nefunguje spoľahlivo), pri čítaní previesť `.mm`.
- Konvencia slovníkov v modeli: **v Noxun Engine výhradne jediný dictionary `NOXUN`** (záväzné — [SYSTEM/STANDARD.md](../SYSTEM/STANDARD.md) §2.1, vrátane jedinej výnimky `dynamic_attributes/scaletool`). Prefix `NOXUN_*` je konvencia starších pluginov mimo tohto repa (KOVANIE) — v Engine nezakladať nové slovníky.

## HtmlDialog

- **`set_on_closed` beží aj pri UKONČENÍ aplikácie** a na 26.0.429 príde **pred** `AppObserver#onQuit` (quit test H11a); v 2026.2 `pop_tool` z hooku
  padá (api-issue-tracker #1117). Riešenie (záložný návrh Z1) je dávka H11c — do hooku zatiaľ nepridávať nové volania SketchUp API.
- **Referenciu na dialóg držať** v modulovej/inštančnej premennej — inak ho GC zavrie „záhadne".
- Unikátny `preferences_key`; **callbacky (`add_action_callback`) registrovať pred `show`**.
- **Ruby → JS výhradne cez `to_json`** (`dialog.execute_script("app.update(#{data.to_json})")`), nikdy interpoláciou stringu.
- V `add_action_callback` blokoch **nikdy `return`** — v Ruby bloku ukončí nadradenú metódu; použiť `next`.
- Front-end cieliť na CEF (Chromium) najstaršej podporovanej verzie SketchUp — dnes **CEF 137 (SketchUp 2026.0)**, nie na „moderný browser". Žiadne CDN — všetko lokálne v jednom súbore/priečinku.
- `UI::Command` zdieľať medzi menu a toolbarom; po vytvorení toolbaru `toolbar.restore`.

## Sieť a systém

- **`Sketchup::Http`** namiesto `Net::HTTP` (asynchrónne, Net::HTTP je v SketchUp problémový); request objekt držať v referencii, inak ho GC zabije a request ticho zlyhá. (Poznámka: `demos_client.rb` v KOVANIE používa Net::HTTP — funguje, ale pri problémoch migrovať.)
- **Všetky volania SketchUp API len z main threadu** — inak pády.
- `Sketchup.platform` (`:platform_win`), nie `RUBY_PLATFORM`.
- `UI::Notification` a `Sketchup::Tool` objekty držať v referencii (GC).

## Chyby a logovanie

- **Tichý `rescue` je zakázaný** — chytať len to, čo vieme spracovať; logovať cez jednotný helper (`log_error` s prefixom `[NOXUN::<Plugin>]`).
- **`Sketchup::Tool` callbacky výnimky ticho prehltnú** — každý callback obaliť begin/rescue s logom, inak nástroj „záhadne" prestane kresliť.
- Pred releasom odstrániť `puts`/`p`; debug výpisy za `DEBUG_MODE` guardom.

## Zakázané patterny

`eval` a stringové `instance_eval`/`class_eval` • `Marshal.load` na cudzích dátach • inštalácia gemov za behu • úpravy `$LOAD_PATH`/`ENV` • monkey patching API • `UI::WebDialog` (deprecated) • API mimo main threadu • `return` v add_action_callback bloku • tichý rescue • zápis do priečinka pluginu.

## Tooling

- **rubocop-sketchup** (lint so SketchUp pravidlami), **ruby-api-stubs** (autocomplete), **TestUp 2** (Minitest v SketchUpe), **YARD** komentáre (`@param [Length] width`) — dôležité, kód číta ďalší AI agent.
- Referenčné repá: `SketchUp/sketchup-ruby-api-tutorials`, `SketchUp/htmldialog-examples`, `SketchUp/sketchup-attribute-helper`.
- Kompatibilita: **minimum SketchUp 2026** (Ruby 3.2, CEF 137) — loader starší SketchUp odmietne jednou hláškou (`MIN_SKETCHUP_MAJOR` v `noxun_engine.rb`, inštalátor rovnako). API z 2023.0 a staršie sa volá priamo, bez `respond_to?` poistiek; **API z 2026.1/2026.2 len za `respond_to?`** (2026.0 ho nemá). Overovať pri každej novej API funkcii.
