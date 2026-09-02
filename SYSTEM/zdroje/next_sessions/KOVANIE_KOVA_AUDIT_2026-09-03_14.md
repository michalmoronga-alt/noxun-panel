# KOV-A — Codex audit návrhu pred implementáciou (3.9.2026, checkpoint #14)

> Stav: KONCEPT / audit checkpoint — nie implementačný spec. Codex CLI task `task-mtjno9g8-jnkb0j` (gpt-5.6-sol, 14 min) nad package KOV-A v PLAN.md + FINAL §2/§8/§11 + mockup.
> Verdikt: **5 BLOCKER + 7 FIX + 3 NOTE; rez A1/A2 odporučený.** Všetkých 5 blockerov je ROZHODNUTÝCH (B2 Michalom 3.9.2026 — variant a, nižšie); packages KOV-A1/KOV-A2 sú v PLAN.md (autorita dávky).

## BLOCKERY (nálezy Codexu) + rozhodnutie orchestrátora

1. **Legacy „smer neexistuje" vs. nové explicitné `unset`.** Staré configy bez poľa nesmú dostať RED; explicitné `unset` áno. Normalizácia ani JS nesmú chýbajúce pole materializovať.
   → **ROZHODNUTÉ (technické): trojstav** — chýbajúce pole = legacy bez nálezu (nikdy sa nedopĺňa), `unset` = nový RED stav (vzniká LEN používateľskou akciou: nové čelo, prepnutie typu, klik na segrow), `left/right` = vyriešené. Guard test: žiadna cesta (Ruby/JS/preview) nesmie z chýbajúceho spraviť `unset` ani stranu.
2. **Troj- a štvorkrídlové dvierka (`wings 3/4`, `p1…p4`) nemajú smerový kontrakt.** → **PRODUKTOVÁ OTÁZKA PRE MICHALA** (návrh nižšie).
3. **Životnosť uloženého smeru pri `1 ↔ 2 ↔ auto`** (auto mení počet krídel podľa šírky 600 mm). → **ROZHODNUTÉ (technické):** smer sa v configu VŽDY zachová (dormant), aplikovateľnosť sa určuje podľa **efektívneho `wings_n`** z `Fronts.layout` (nie surového `wings`); pri 2+ krídlach sa uložená hodnota nečíta, po návrate na 1 krídlo sa obnoví; `hardware_issues` rozhoduje z `wings_n`.
4. **Legacy zásuvky bez klasifikácie** nesmú dostať `metal + standard` ako vedľajší efekt. → **ROZHODNUTÉ (technické):** chýbajúca klasifikácia = stav **„neklasifikované"** (samostatný, JS round-trip ho nemení); klasifikácia vzniká len explicitnou voľbou; KOV-C/D: neklasifikovaná zásuvka = žiadny recept (ORANGE „zásuvka bez klasifikácie", nie RED, výstupy ako dnes).
5. **Kanonický `part_key` pre flap/false_front.** `front:F#/panel` by kolidoval so zásuvkovým čelom (human_label, hardware_override po prepnutí typu). → **ROZHODNUTÉ (technické):** nové kinds `front:F#/flap` a `front:F#/blind` (`PartKeys.front(id,'flap')`/`('blind')`); overridy sú per kind → pri prepnutí typu ostávajú dormant pod starým kľúčom (vzor migrate_overrides), neprenášajú sa; `human_label` vetvy „výklop/sklop" a „blenda".

## FIX-IN-KOVA (prijaté všetky)

6. Šiesta stratová projekcia: `Fronts.layout → front_items` (cache v configu, číta ho preview) — nové polia (`direction`, `flap_dir`, typ) musia prejsť aj tadiaľ + round-trip test.
7. ABS pre nové roly: `AbsRules::SEED_RULES` + **bump `SEED_VERSION`** (inak merge preskočí) + `EDGE_LABELS`, `edge_sides`, `Validation::FRONT_ROLES`, poradie v prehľade pravidiel.
8. `PartFaces::ROLE_AXES`: `flap`/`false_front` → `AXES_FRONT` (grain_check/edge_check čítajú snapshot bez osí).
9. `part_card.js` považuje za čelo len front_door/drawer_front → 19 mm materiál by bol v pickeri disabled; rozšíriť.
10. `PART_TAGS` (Noxun/Čelá), SK názvy rolí v `production_core` (ROLE_LABELS), preview typov (dnes všetko okrem drawer = „dvierka").
11. Identita `hardware_issues` pri duplicitných `cabinet_id`: niesť identitu výskytu (entityID ako edge_check) alebo pri duplicate-ID potlačiť per-dielec navigáciu; dosky nález netvoria.
12. Overlay = celý lifecycle grain_check: jeden serverový toggle + broadcast do oboch UI, odpojenie pri zmene dokumentu (`ScaleObserver.model_switched` vetva), nový overlay objekt pri zapnutí, sken len pri zapnutí/dirty, nie v každom `draw`.

## NOTE

13. V kóde neexistuje cesta, ktorá by smer automaticky nastavila — guard test musí prehľadať Ruby aj JS vrátane fallbackov `direction || …`.
14. Nemennosť kovania/výstupov platí len pri STRIKTNE aditívnej implementácii — `opening_mode` ani drawer klasifikácia sa v A nesmú dostať do kontextu hardware pravidiel.
15. Druhé PC so starším pluginom = len čítanie/export (guardy R-12) — **D-52 nasadený na oboch PC PRED prvým KOV-A modelom/šablónou** (D-52 je v maine v0.9.14 — zostáva nasadiť u Lucie).

## Minimum testov (z auditu — do package)

Headless: round-trip matica 6 projekcií (5 whitelistov + front_items), string aj symbol kľúče · prepínanie každého typu tam a späť (dormant sa obnoví, neaktívne sa nečíta) ·
smer legacy/unset/left/right × efektívne 1/2/3/4/auto okolo 600 mm · legacy V0.1 string fronts a drawer bez klasifikácie (nič sa nevymyslí) · stabilita/unikátnosť part_key
pri prepínaní typov + staré overridy · ABS čistá inštalácia aj upgrade `abs_rules.json` (používateľské pravidlá nedotknuté) · flap/false_front: materiál, 18/18,6/19, AXES_FRONT,
4 ABS hrany, tag, názvy · `hardware_issues` len pre aktívne jednokrídlo s `unset`; duplicate-ID; `Bom.compute` obsahovo identické · downgrade test (starší plugin: rebuild,
šablóna, kópia, uloženie šablóny). JS: renderFronts→collectFronts (obrátené poradie, všetky polia; editácia iného poľa nematerializuje default) · show/hide matica · klávesnica
typegrid/segrow · nx-combo po rerenderi · preview všetkých typov bez fallbacku na stranu · oba prepínače overlayu = jeden stav. In-SU: build/rebuild/Ctrl+Z lift/fall/blind
s 19 mm · šablóna/kópia/prepnutie typu (dormant prežije) · overlay z oboch vstupov, prepnutie dokumentu, undo/redo, bez Overlay API · výkon na ~254 dielcoch · duplicate-ID
s rozdielnym smerom · **reálna KLINIKA .skp: pred/po obsahovo identické výstupy** (jediná nová informácia = smerový nález, legacy bez poľa vyňaté).

## Rez (prijatý)

**A1 (dátová vrstva, bez UI sprístupnenia nových typov):** kontrakt polí + trojstavy + dormant pravidlo, kanonické part_keys, nové roly + builder + tag + ABS seed bump +
allowlisty (PartFaces, FRONT_ROLES, ROLE_LABELS), CONFIG_SCHEMA bump, `hardware_issues` + Validation RED, obsahová regresia výstupov, downgrade testy.
**A2 (UI + overlay):** karta čela (typegrid, kontextové riadky, part_card), `collectFronts`, preview, sprite ikony, direction overlay (celý lifecycle), broadcast, in-SU výkon.
Schema bump v A1 pristane až po nasadení D-52 na oboch PC.

## Otázka pre Michala (jediná produktová)

**Smer pri 3- a 4-krídlových dvierkach** (dnes `wings 3/4`, krídla `p1…p4`): a) **krajné krídla odvodené** (p1 = pánty vľavo, posledné = pánty vpravo) a **stredné krídla
`unset`** → RED, kým ich neurčíš ručne *(odporúčanie — konzistentné s O1: nič sa neháda, len geometricky jednoznačné krajné krídla)* · b) všetky krídla `unset` · c) 3/4 krídla
smer nemajú (overlay bez symbolu, žiadny nález).

## Rozhodnutie Michala (3.9.2026) — BLOCKER 2

**Variant a):** krajné krídla **odvodené** (ľavé = pánty vľavo, pravé = pánty vpravo), stredné krídla **„neurčené" → RED, kým ich neurčí ručne.**
Tým je zároveň potvrdená sémantika smeru: `direction` = **strana pántov** (Ľavé = pánty vľavo). Kontrakt odvodený orchestrátorom:
`direction` (scalar, trojstav) platí len pri efektívnom `wings_n == 1`; stredné krídla 3/4-krídlových dvierok majú vlastný trojstav v `wing_directions`
`{ 'p2' => …, 'p3' => … }` (p2 pri 3 aj 4 krídlach, p3 len pri 4); krajné krídla a dvojkrídlo nič neukladajú. Jediná definícia aplikovateľnosti =
`Fronts.direction_slots(resolved_item)`. Plné znenie: package **KOV-A1** v `SYSTEM/PLAN.md`.
