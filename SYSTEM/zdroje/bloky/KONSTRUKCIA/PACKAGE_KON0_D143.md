# Package KON-0 · D-143 — chrbát v drážke do nárezu v plnom rozmere

> **Blok 7 · KONŠTRUKCIA K1+K2**, prvá dávka. **Package v2** (27.9.2026) — zapracovaný audit návrhu (NOT SOUND → BLOCKERy vyriešené rozhodnutím
> Michala, FIX 3–6 v Scope IN) a rozhodnutia Michala (`ROZHODNUTIA_MICHALA_2026-09-27.md`). Autorita počas dávky: tento package. Podklady: `SYSTEM/zdroje/bloky/KONSTRUKCIA/`
> — [ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md), [VSTUPY_PRE_PACKAGES_2026-09-27.md](VSTUPY_PRE_PACKAGES_2026-09-27.md), fakty z kódu §2, §5, §6.
> **Trieda:** výrobná + **audit-povinná** (dátový kontrakt snapshotu + `CONFIG_SCHEMA` 18 → 19) → `codex-audit` pred kódom · predrecenzia
> pred PR · **in-SU test je brána mergu** · GH Codex review. Mockup schválený 27.9. (M11); KON-0 ide prvá (výrobná chyba má prednosť).
> Verzia v0.13.0 → **v0.13.1**.

## Cieľ

Chrbát v režime „V drážke" (predvolený pri hornej skrinke) ide do nárezu, do VEPO a do ceny **v plnom rozmere skrinky `w × (h − s)`**
(horná 600 × 720 → **600 × 720**, dnes 564 × 684); **model ho ďalej ukazuje v drážke** (geometria sa nemení). Rozhodnutie Michala 26.9.2026
(presne by bolo +9 mm na stranu s drážkou; pre V1 plný rozmer, dielňa zreže — „zrezať viem, prilepiť je horšie").

## Scope IN

1. **Pole `cut_size: {length, width}`** — voliteľné, aditívne, v deskriptore dielca (BuildPlan) aj v snapshote na entite; **`box` = `prod` =
   geometria ostávajú** (rovnosť stráži `PartFaces`/`AppearanceMapping` — D-88/D-104/MR-3A; nerozvoľňovať). Pre chrbát `groove`:
   `{length, width}` = rozmer `w × (h − s)` **v tých istých osiach, v akých `prod` nesie rozmer chrbta** (implementátor overí mapovanie osí);
   obe hodnoty konečné, kladné a **≥ geometrii**. Osi potvrdené auditom: chrbát `length = X` (šírka skrinky), `width = Z` (výška) →
   `cut_size = {length: w, width: h − s}` (`construction.rb:1486`, `part_faces.rb:56`); prítomné pole potrebuje vlastnú validáciu. Meno `cut_size` (nie `cut` — koliduje s booleanom vo `vepo_export.rb` ~r. 413).
   Aditívny voliteľný kľúč plánu → BuildPlan `SCHEMA` sa **nebumpuje** (precedens `references`, `hardware_conflicts`) — potvrdí audit.
2. **Čitatelia** (každý výrobný výstup číta `cut_size`, keď ho dielec má, inak geometriu): agregácia kusovníka (rozmer v agregačnom kľúči a
   stĺpcoch), **kontrola formátu platne** (väčší polotovar), **VEPO**, **plocha pre rozpočet a cenovú ponuku** (odhad platní ide z riadkov BOM,
   `sheet_estimate.rb:45`), **plocha skrinky v Inspectore** (`Panel.cabinet_stats`, `resolvers.rb:191` — dnes násobí snapshoty), karta dielca vrátane
   **textov smeru dekoru, ktoré hovoria „výrobne"** (`part_grain_payload`, `payloads.rb:2882/2924/2958` — pri priečnom dekore 720 × 600 ako VEPO;
   Dĺžka/Šírka a nákres hrán ostávajú geometrické). `cut_size` sa uplatní
   **pred otočením podľa dekoru**. **Hmotnosť** ostáva z geometrie (odrezok sa neváži). Chýbajúce pole = geometria; **poškodený údaj** (nečíselný,
   ≤ 0, menší než geometria) **zastaví výrobné výstupy** (RED s dôvodom).
3. **Chrbát v drážke s účinným ABS** (ručný override **alebo pravidlo olepu** pre rolu `back`): `cut_size` sa **nezapíše** a taký chrbát
   **zastaví výrobné výstupy** (RED „chrbát v drážke s olepením — zruš olepenie alebo zmeň typ chrbta"), kým sa nevyrieši; override nezmizne.
3a. **Jedna výrobná brána D-143** (audit FIX 3): jeden zoznam blokujúcich dôvodov D-143 (poškodený `cut_size`, olepený chrbát v drážke,
   zastaraná skrinka, neolepený groove chrbát schémy ≥ 19 bez `cut_size` = neúplný snapshot) → RED v Kontrole **a tvrdý stop po čerstvom zbere
   vo všetkých štyroch exportoch** (VEPO, nákupný CSV, rozpočet XLSX, ponuka XLSX). Dnes VEPO výsledok Kontroly len loguje
   (`production_core.rb:1836`) a `BUILD_BLOCKERS` má užší rozsah (`:1285`) — nestačí pridať RED. Poškodený údaj overiť pred agregáciou,
   nezávisle od katalógu a predčasného návratu pre UNI (`validation.rb:330`).
4. **`CONFIG_SCHEMA` 18 → 19** (+ `HISTORIA`: D-143 `cut_size`) — dopredná a exportná brána R-12 zastaví **starší plugin** (inak by vydal 564 × 684).
5. **Zastarané skrinky (aktivačná schéma 19):** skrinka s `back_mode groove` a `config_schema < 19` = zastaraná — **nezávisle od prítomnosti
   `cut_size`** (prestavaný chrbát s ABS ho zámerne nemá). Kontrola ju ukáže (RED s výzvou „prestav skrinku") a **výrobné exporty ju zastavia**,
   kým sa neprestaví. Vzor aktivačných konštánt `DRAWER/HINGE/LIFT_ACTIVATION_SCHEMA`. **Režim chrbta čítať rovnako ako `config_to_params`**
   (`back_mode || legacy_back(cfg)`, `cabinet_builder.rb:3796/3895` — aj starý zápis `back.mode`, audit FIX 4); výrobné rozmery sa pri tejto
   kontrole nanovo nepočítajú. **Hromadná prestavba** (audit NOTE 7): existujúce `CabinetBuilder.rebuild_many` (jedna operácia s rollbackom,
   `cabinet_builder.rb:720`) nad čerstvým výberom zastaraných skriniek po ustálení observera; skrinky s odpojenými dielcami vyradiť a vymenovať
   (vzor `payloads.rb:3075`), ich blokácia ostáva.
6. **Samostatné chrbty** (odpojené, vytiahnuté, skopírované — BOM ich zbiera bez kontroly schémy korpusu, `bom.rb:264`; prestavba vlastníka
   ich nenahradí, `ids.rb:141`): nový chrbát v drážke nesie v snapshote **značku pôvodu** (režim chrbta / verzia stavby), takže samostatný nový chrbát
   ostáva chránený bránou 3a. **Starý samostatný chrbát bez značky → ORANGE „over rozmer do nárezu"** a export prejde — **vedomé rozhodnutie Michala
   27.9.2026** (samostatné chrbty nepoužíva; audit ho navrhoval blokovať). **Priznaný zvyšok:** starší plugin `cut_size` ani značku nepozná a samostatný
   chrbát vydá malý → **pred prvým použitím aktualizovať obe PC** (smoke bod 5, KRONIKA).
7. **Karta dielca v Inspectore:** riadok „**Do nárezu 600 × 720**" pod Hrúbkou (Dĺžka/Šírka ukazujú model 564 × 684) — bez nového riadku navyše
   podľa mockupu (sekcia D); tooltip: „zrezať do drážky v dielni".
8. **STANDARD §8.2:** `cut_size` — rozmer do nárezu vs. rozmer dielca, fallback, poškodený údaj, kto ho zapisuje (builder) a kto číta.

## Scope OUT

komín a zapustenie (KON-A) · D-144 (KON-A) · chrbát z líšt (KON-B) · `cut_size` pre iné dielce · tok „olepiť po zrezaní" · presný prídavok 9 mm ·
geometrická drážka v modeli · ďalšie UI okrem riadku na karte dielca · zmena textúr/vzhľadu.

## Dáta a kontrakt → audit ÁNO

snapshot dielca (nové pole) · BuildPlan deskriptor (voliteľný kľúč) · `CONFIG_SCHEMA` 19 · aktivačná schéma D-143 = 19 · STANDARD §8.2.

## Testy a DoD

- **Headless:** deskriptor a snapshot `cut_size` (groove áno; overlay/inset/none nie) · reťaz snapshot → kusovník (agregácia, stĺpce) → formát
  platne → VEPO → plocha/cena (horná 600 × 720 → 600 × 720, plocha 0,432 m²) · otočenie podľa dekoru · hmotnosť z geometrie · poškodený `cut_size`
  → RED a stop výstupov · chrbát v drážke s ABS (ručný override **aj pravidlo olepu** pre rolu `back`) → RED a bez `cut_size` · zastaraná skrinka (groove, schéma < 19) → RED + stop exportov;
  prestavaná → OK · `CONFIG_SCHEMA` 19 + dopredná brána (novší config) · odpojenie chrbta so `cut_size` odmietnuté. **Golden plány:** geometria
  (box/origin/prod/axes) **bajtovo rovnaká**; `cut_size` overuje nový reťazový test (dnešný golden whitelist ho neporovnáva).
- **JS:** karta dielca — riadok „Do nárezu" pri `cut_size`, bez neho nič.
- **In-SU** (`scripts\run_su_tests.ps1 -CloseWhenDone`, len `_dev\ENGINEtests.skp`): plán ↔ model 1:1 · `cut_size` na entite chrbta v drážke ·
  jeden krok Späť · uloženie a znovuotvorenie · stará skrinka (bez `cut_size`, schéma < 19) → zastaraná → prestavba → OK · hromadná prestavba
  jeden krok Späť · kópia, absorpcia Scale a Undo/Redo obnovujú snapshot aj schému spolu (audit NOTE 7).
- **Brána 3a:** test **každý blokujúci dôvod × každý zo štyroch exportov** — nulové volanie výberu súboru/priečinka aj zápisu (nestačí test farby).
- **Mutačné overenie:** min. 3 mutácie (čitateľ ignoruje `cut_size` · zastaranosť podľa `cut_size` namiesto schémy · ABS výnimka bez RED) musia padať.
- Headless + **každá** JS sada zvlášť zelené; počty do PR a KRONIKY.

## Riziká

zabudnutý čitateľ (výstup ostane na geometrii — reťazový test) · osi `cut_size` vs. otočenie dekoru · staré zákazky blokované, kým sa neprestavia
(zámer — hláška musí byť jasná) · druhé PC so starším pluginom zákazku neprestaví ani nevyexportuje (zámer — **aktualizovať obe PC**) ·
vyššia plocha HDF (+12 %) v rozpočte.

## Smoke pre Michala (po mergi, v0.13.1)

1. Nová horná skrinka 600 × 720 (chrbát v drážke): kusovník aj VEPO „Chrbat" **600 × 720**; karta dielca „Do nárezu 600 × 720", Dĺžka/Šírka 564 × 684.
2. Otvor staršiu zákazku s hornými skrinkami: Kontrola hlási zastarané skrinky, VEPO sa nevyexportuje; prestav ich (Aplikuj zmeny / hromadne) → OK a VEPO ide.
3. Chrbát v drážke + ručné olepenie hrany (a zvlášť pravidlo olepu pre chrbty) → Kontrola RED, VEPO stojí; zruš olepenie → OK.
4. Dolná skrinka s naloženým chrbtom: nič sa nemení.
5. Aktualizuj plugin aj u Lucie (jej starší plugin takú zákazku zastaví).

## Checklist uzáveru

VERSION 0.13.1 (2×) + všetky `?v=` · testy (headless, JS, in-SU) · `docs/architecture/construction.md` (chrbát), `outputs.md` (čitatelia
`cut_size`, brány), `model-a-identita.md` (snapshot) na mieste · STANDARD §8.2 · POJMY (prídavok 9 mm; V1 plný rozmer) · D-143 plným textom do
`archiv/DOGFOODING_vyriesene.md` + riadok INDEXU, z DOGFOODING preč · PLAN blok 7 riadok KON-0 s ✅ a `PR #?` · **STAV prepis** (v0.13.1, D-143;
smoke S1 PASS 26.9.; smoke D-128 a D-131 PASS, D-132/133/134 čakajú; V1_VIZIA body 4 a 7 odškrtnuté; blok 7 beží; kompatibilita: schéma 19,
aktualizovať obe PC) · KRONIKA.

---

## Audit návrhu KON-0 (Codex gpt-6-astra, 27.9.2026 ~03:20, 8 min, +5 % weekly) — **NOT SOUND: 2 BLOCKER · 4 FIX · 2 NOTE**

Surový výsledok: [AUDIT_KON0_2026-09-27.md](AUDIT_KON0_2026-09-27.md). Zmeny package (zapracované v Scope IN vyššie):

- **BLOCKER 1 + 2 — samostatné (odpojené, vytiahnuté, skopírované) chrbty:** zákaz odpojenia v UI nechráni natívne operácie SketchUpu ani starší
  plugin; BOM zbiera samostatný `part` bez kontroly schémy korpusu (`bom.rb:264`), starý snapshot nenesie režim chrbta ani schému stavby
  (`cabinet_builder.rb:2100`) a prestavba vlastníka nechá starý samostatný kus popri novom (`ids.rb:141`). Sonda: `Bom.record → compute →
  VepoExport.build` vydala **564 × 684** aj so vstupom `cut_size 600 × 720`. Návrh audítora: **priznaný limit spätnej kompatibility + aktualizácia
  oboch PC pred prvým použitím + exportná brána samostatných chrbtov v novom plugine** + trvalý stav proveniencie na dielci (nový groove chrbát nesie
  značku; neolepený groove chrbát schémy 19 bez `cut_size` = chyba úplnosti) a **výslovné odmietnutie starých samostatných chrbtov s neoveriteľným
  pôvodom** (pôvod neodvodzovať z rozmerov ani `cabinet_id`). → **OTÁZKA PRE MICHALA (dávka čaká):** starý samostatný chrbát (bez značky) —
  (A) **blokovať výrobné exporty**, kým ho nenahradíš/neodstrániš (bezpečné, ale zablokuje aj samostatný naložený chrbát, ktorý je správny), alebo
  (B) **ORANGE upozornenie „over rozmer do nárezu"** a export pustiť (dnešné správanie, bez regresie). Nové chrbty (so značkou) chránené vždy.
  → **Michal 27.9.2026: (B)** — samostatné chrbty nepoužíva; zapracované v Scope IN bod 6.
- **FIX 3 — jedna výrobná brána D-143:** jeden zoznam problémov D-143 → RED v Kontrole **aj tvrdý stop po čerstvom zbere vo všetkých štyroch
  exportoch** (VEPO, nákupný CSV, rozpočet XLSX, ponuka XLSX) — dnes VEPO výsledok Kontroly len loguje (`production_core.rb:1836`) a `BUILD_BLOCKERS`
  má užší rozsah (`:1285`); poškodený údaj overiť pred agregáciou, nezávisle od katalógu a UNI (`validation.rb:330`). DoD: **každý blokujúci dôvod ×
  každý export**, nulové volanie výberu súboru aj zápisu.
- **FIX 4 — zastaranosť** musí čítať aj legacy `back.mode` (rovnaká sémantika ako `config_to_params`: `back_mode || legacy_back(cfg)`,
  `cabinet_builder.rb:3796/3895`) + test legacy configu bez markera.
- **FIX 5 — UI smeru dekoru:** `part_grain_payload` (`payloads.rb:2882/2924/2958`) ukazuje „výrobne" geometrické rozmery → pri `cut_size` ukázať
  rozmer do nárezu (priečny dekor 720 × 600 ako VEPO); Dĺžka/Šírka a nákres hrán ostávajú geometrické.
- **FIX 6 — plocha v Inspectore:** `Panel.cabinet_stats` (`resolvers.rb:191`) násobí snapshoty — zahrnúť `cut_size` (0,432 m² namiesto 0,386 m²)
  alebo údaj výslovne nazvať geometrickou plochou; hmotnosť z geometrie; odhad platní už ide z BOM (`sheet_estimate.rb:45`).
- **NOTE 7 — hromadná prestavba:** použiť existujúce `CabinetBuilder.rebuild_many` (jedna operácia s rollbackom, `cabinet_builder.rb:720`) nad
  čerstvým výberom zastaraných korpusov; skrinky s odpojenými dielcami vyradiť a vymenovať (vzor `payloads.rb:3075`), blokácia ostáva. In-SU aj
  kópia, absorpcia Scale a Undo/Redo (obnoviť snapshot aj schému spolu).
- **NOTE 8 — potvrdené:** osi `cut_size = {length: w, width: h − s}` (`construction.rb:1486`, `part_faces.rb:56`); BuildPlan `SCHEMA` sa nebumpuje
  (`build_plan.rb:14`), ale prítomné pole potrebuje vlastnú validáciu; R-12 brána pre neporušený korpus schémy 19 funguje aj vo VEPO (`production_core.rb:1784`).
