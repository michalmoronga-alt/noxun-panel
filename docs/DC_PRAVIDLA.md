# Dynamické komponenty (DC) — pravidlá a draho zaplatené poznatky

Destilát z „SketchUp Dynamické Komponenty Nábytku.md" + kritické poznatky z praxe V2fable (`STARE\CLAUDE.md`) a Noxun DC Control. **Čítať vždy pred prácou s DC.**

## Draho zaplatené poznatky z praxe (neporušovať!)

1. **Resize DC NEfunguje zápisom `lenx/leny/lenz`** — DC engine funguje ako Scale tool: fyzicky škálovať inštanciu transformáciou + `$dc_observers.get_latest_class.redraw_with_undo(inst)`; engine scale absorbuje a sám aktualizuje `_len*_nominal`. Nelineárne vzorce → iterovať max 3×. Pred resize `make_unique`, ak má definícia viac inštancií — inak sa zmenia VŠETKY kusy.
2. **Rozmery merať z nominálov** (`_lenx_nominal` → `lenx` → bounds až ako fallback) — nie z bounding boxu. Dvierka bývajú PRED korpusom (záporné Y) a bounds by „stlačili" korpus o hrúbku dverí.
3. **`definitions.load` je od SU 2021.1 nebezpečný** — reload-replace ticho prepíše rovnomennú definíciu v modeli (nevratné, mimo Undo). Vždy najprv hľadať už načítanú definíciu (path match + name match); load len keď sa nenájde. Náhľady .skp čítať binárne (skp 2021+ = ZIP, `meta/model_thumbnail.png`) — žiadny load kvôli náhľadu.
4. **`redraw_with_undo` NIKDY vnútri otvorenej operácie** (má vlastné undo kroky) — volať až po `commit_operation`.
5. **DC atribúty sú interne v PALCOCH** — UI vždy mm (×/÷25.4, `Length#to_mm`). Holé číslo bez jednotky vo vzorci/atribúte = palce (18 → ~457 mm!). Pri zápise dĺžky ako string vždy `"600mm"`. VCB vstupy tiež explicitne mm — model môže mať palcovú šablónu.
6. **Redraw hack:** globál `$dc_observers` patrí oficiálnemu Dynamic Components pluginu — pred použitím overiť, že existuje; ak nie, vyzvať na manuálny redraw (tak to robí DC Control `dialog_controller.rb`).
7. **Čítanie/zápis atribútov: inštancia má prednosť pred definíciou** (inštančný override). Skúšať aj `key.downcase` — DC nekonzistentne mieša veľké/malé písmená (pattern z DC Control `presets.rb`).

## Pravidlá písania DC vzorcov

- Atribúty sú **case-sensitive** (`LenX` ≠ `lenx` v referenciách vzorcov); rozmery a pozície sú v **lokálnych osiach** komponentu — po rotáciách skontrolovať osi (Change Axes), inak sa vzorce rozpadnú.
- **`LenX/Y/Z` nikdy presne 0** — kolaps bounding boxu. Na „skrytie" dielca `Hidden=1` alebo 0.001mm.
- **IF vyhodnocuje OBE vetvy vždy** — delenie nulou alebo odkaz na neexistujúci atribút v „mŕtvej" vetve zhodí celý komponent. Viacvariantné konfigurácie cez `CHOOSE(OPTIONINDEX("Atribút"), v1, v2, …)` — a otestovať, či OPTIONINDEX indexuje od 0 alebo 1.
- Užitočné funkcie: `NEAREST(CURRENT("LenX"), 600, 900, 1200)` — snap na normované šírky; `LARGEST/SMALLEST` — min/max limity (napr. minimálny rozmer pre kovanie); `INT/FLOOR/CEILING` — počty kusov a modulové rady; `FACEAREA("materiál")` — výmery.
- **Rotácia je vždy okolo lokálneho počiatku** — pre dvierka musí byť origin na hrane pántu. **Nikdy Flip Along na animovanom komponente** (prepíše rotačnú maticu → „poskakujúce" dvierka) — rotačný komponent baliť do izolovanej skupiny.

## Overený vzor korpusu (prevencia deformácií)

- Rodič = jediný zdroj pravdy: custom atribúty `W`, `H`, `D`, `MatThick` (názvy sa môžu líšiť podľa knižnice — v našej sú slovenské, napr. `e_hrubka`, `b_pocet_polic`; viď whitelist v DC Control `presets.rb`).
- Dielce: `ScaleTool=0` (zamknutý Scale), hrúbka `=Parent!MatThick`, pravý bok `PosX = Parent!W - LenX` — hrúbka dosky sa nikdy nedeformuje.
- Police/polia: `Copies = MAX(0, INT((Parent!H - hrúbka) / (krok)))`, pozícia `PosZ = krok * Copy` (`Copy` = index kusu, 0 = originál).
- Dvierka: varianty (1- aj 2-krídlové) predmodelované, prepínané `Hidden = IF(šírka < 601mm, …)`; šírka krídla počíta so škárami.

## Limity DC — prečo Ruby vrstva

- **DC nevie za behu „pripojiť" nový subkomponent** — všetky varianty musia byť predmodelované vnútri rodiča a prepínané cez `Hidden`/`Copies`; pri väčšom počte kombinácií to degeneruje do vnorených IF. → Plánovaný systém „pripájania childov" musí robiť **Ruby plugin**: programové vkladanie inštancií + zápis DC atribútov + redraw (viď bod 1).
- **Scale Tool bug:** vizuálne škálovanie neprepíše atribúty, ale uloží násobiaci faktor do transformácie inštancie — dialóg hlási iný rozmer než scéna. Prevencia: `ScaleTool=0`; oprava: Ruby normalizácia transformácie.
- DC editor vyžaduje SketchUp Pro/Studio.
- Neimportovať cudzie DC z neoverených zdrojov (XSS vektor cez `ImageURL`/`Summary` v Component Options — CVE-2026-9264).

## CNC / export pipeline

Vždy na **kópii súboru**: Explode DC na skupiny → zmazať `Hidden=1` geometriu (nesting by ju započítal) → voľnú geometriu rozdeliť (Loose To Groups) → materiály pomenovať `hrúbka_dekor` (`18mm_Egger_Biela`) → strážiť smer letokruhov. Referencie: OpenCutList (rezné plány), ABF.

## Referenčné zdroje v workspace

- `STARE\_dev\DC_SCHEMA.md` — schéma atribútov starej knižnice; `STARE\V2fable\core\dc.rb` — hotový kód resize/nominály.
- `AIdebuger\debug_dump.json` — reálna vzorka kompletných DC atribútov skrinky (formuly, enkódované options, jednotky).
- `COMPONENTS V2\1 Nové Dynamicke\` — živá knižnica DC (Master.skp = 700×510(+dvere)×862). READ-ONLY.
- Whitelist DC parametrov našich korpusov: `Noxun Dc Control Plugin\noxun_dc_control\presets.rb` (LenX/Y/Z, b_pocet_polic, c_vSok, e_hrubka, d_chrb, f_dno, f_strop, i_dvere, j_ukw, k_medzD/H/L/P).
