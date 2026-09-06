# V1 debata · bod 2 KONŠTRUKCIA — rozhodnutia (5.–6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 5.–6.9.2026 (okno „V1 plánovanie po KOVANÍ") · auditované proti kódu: ČIASTOČNE (config korpusu
> `CabinetBuilder.normalize`, geometria `construction.rb`, DC „Rohová" prečítaná z modelu cez MCP 5.9.) · task packages vzniknú z tohto checkpointu až po `codex-audit`.
>
> Pred implementáciou platí postup z [README.md](README.md). Nadväzuje na koncept [07_KONSTRUKCIA_V1.md](07_KONSTRUKCIA_V1.md) (K1–K4) — tento dokument ho **rozhoduje**, nie nahrádza.

## 0 · Súhrn rozhodnutí (Michal)

| Téma | Rozhodnutie | V1? |
|---|---|---|
| Odsadenia dielcov (V1-01) | **dva prípady, jedna hodnota per skrinka** (šablónovateľné): komín vzadu + strop zapustený vpredu | **ÁNO** |
| Chrbát z výstuh | nový typ chrbta: **dve vodorovné lišty medzi bokmi**, výška parameter | **ÁNO** |
| Rohová skrinka (dolná, slepá s CR lištou) | nový typ korpusu = dolná skrinka + rohová zostava + 3 parametre, prepínač L/P | **ÁNO, nízka priorita (koniec V1)** |
| Spotrebičová skrinka | chladnička / rúra / mikro = odsadenia + S1 nad bežným builderom; umývačka jednoduchá (neskôr) | **ÁNO, po S1, nízka priorita** |
| Horná rohová skrinka | základ dá dolná | mimo V1 |
| Digestorový korpus | komplikovanejší (kapotáž, komín) | mimo V1 |
| Čelo ako cenová položka s dodávateľom (V1-07) | — | **mimo V1** (pôvodne vo V1 rozsahu — ZMENA) |
| Rohové spoje dna/stropu per strana | asymetria ľavá/pravá sa v praxi nepostráda | mimo V1 |
| Chrbát s poldrážkou | — | mimo V1 |
| „Bez dielca" varianty (bez boku / dna / stropu) | — | mimo V1 |

Dôvod zaradenia rohovej a spotrebičovej: „veľmi často používané, ťažko sa obchádza". Poradie v rámci V1: **odsadenia + chrbát z výstuh → S1 → spotrebičová → rohová (posledná)**.

## 1 · Odsadenia (K1) — dva pomenované prípady

Engine dnes **nemá žiadne odsadenie**: bok, dno aj strop majú vždy konštrukčnú hĺbku korpusu (`carcass_depth`), chrbát sedí na zadnej hrane
(`overlay` za ňou, `inset`/`groove` v nej). Odsadenie je nová konštrukčná voľba korpusu, **nie** per-dielec override a **nie** generický XYZ editor.

**(a) Komín vzadu** — „bok hlbší než dno a strop" (bok 560, dno 500): dno aj strop sú vzadu kratšie o hodnotu `X`, **chrbát sedí na zadnej hrane dna a stropu**, teda `X` pred zadnou
hranou boku. Za chrbtom vzniká vzduchový komín (chladničková, rúrová skriňa). Vnútorná hĺbka zón sa počíta od posunutého chrbta. Jedna hodnota pre skrinku → ide do šablóny „chladničková".

**(b) Strop zapustený vpredu** — strop (alebo horné výstuhy) začína o hodnotu `Y` za prednou hranou boku (miesto pod pracovnú dosku, drez). Dno sa vpredu **neodsadzuje**.
Presahy dielcov cez bok (dno dlhšie než bok) sa **nerobia**.

Otvorené pre package (rozhodne audit proti kódu): názvy polí a znamienková konvencia · ako sa `X` premietne do `interior_dims`, zón, políc a `rail_geometry` (D-80 clampy) · ABS zadnej hrany
dna/stropu pri komíne (hrana ostáva neviditeľná — pravidlo nemeniť) · semafor: `X`/`Y` väčšie než rozumný rozsah, kolízia s `groove` chrbtom · `CONFIG_SCHEMA` bump (nové konštrukčné pole).

## 2 · Chrbát z výstuh (K2) — nový režim `back_mode`

Namiesto plného chrbta **dve vodorovné lišty** z korpusového materiálu, vždy dve (hore + dole), **medzi bokmi** (vnútorná hĺbka sa nemení, rovnako ako dnešné horné výstuhy),
**výška lišty = parameter** (default navrhnúť 100 mm, doladí smoke). ABS: **len hrana viditeľná z vnútra** — horná lišta dolnú hranu, dolná lišta hornú hranu (spodná hrana dolnej sa
opiera o dno, horná hrana hornej o strop alebo stropnú výstuhu). Kombinácia s vrchom „dve výstuhy" ostáva ako je (hore vzadu dve lišty pri sebe, nezlučujú sa).

Otvorené pre package: roly a `part_key` (návrh `back_rail_top` / `back_rail_bottom`, `PartKeys.cabinet('back_rail','top'|'bottom')`) · `back_thickness` pri tomto režime = hrúbka
korpusu, nie HDF · interakcia s D-80 (výška vnútra pri hornej lište vzadu) · VEPO/kusovník názvy · `hardware`: žiadne nové pravidlo · `CONFIG_SCHEMA` bump (nová hodnota enumu).

## 3 · Rohová skrinka (K3) — špecifikácia z DC „Rohová" (prečítané z modelu 5.9.)

Základ = **bežná dolná skrinka** (dno medzi/pod bokmi, vrch plný / dve výstuhy, chrbát HDF / pevný / z výstuh, sokel, nohy, police cez celú šírku medzi bokmi).
Navyše **rohová zostava na prednej rovine** — príklad z DC pri šírke 1100, dverová zóna 450, cr1 = cr2 = 80, medzery L 2 / P 4 / H 5 / D 0:

| Dielec | Materiál | Rozmer (DC) | Význam |
|---|---|---|---|
| Dvere | čelový | 446 × 707 | šírka = dverová zóna − medzera L − medzera P/2; výška ako bežné dvierka; UKW profil možný |
| Blenda korpusová | korpusový | 632 × 676 × 18 | vnútorná čelná výstuha od dverovej zóny po protiľahlý bok, výška vnútra; **vždy korpusová** (v rohu schovaná) |
| Výstuha závesov (Blend2) | korpusový | 18 × 80 × 676 | na hrane dverovej zóny smerom dovnútra; nesie závesy dverí |
| Rohová výstuha (CR blend) | korpusový | 18 × (cr2 + 18) × (výška − sokel) | vonkajšia rohová výstuha, nesie CR 2 |
| CR 1 | čelový | (cr1 − medzera P/2) × 18 × výška dverí | CR lišta na prednej rovine vedľa dverí |
| CR 2 | čelový | 18 × (cr2 − medzera P/2 + 18) × výška dverí | CR lišta do hĺbky, vracia sa k susednému radu |

**Parametre navyše:** šírka dverovej zóny (450) · `cr1` · `cr2` (každý zvlášť — CR **nemusí byť symetrická**, tým sa doladia chýbajúce milimetre v rohu) · **prepínač dvere vľavo / vpravo**
(zrkadlenie celej rohovej zostavy; v DC riešené prevrátením komponentu). Typický rozmer 1100 / 450 sedí.

**Rozhodnuté (Michal 6.9.):** CR lišty v kusovníku a VEPO ako dielce z čelového materiálu s **ABS dookola** (ako čelo) · kovanie: závesy podľa výšky dverí ako bežné dvierka
(vlastník = dvere, sedia na výstuhe závesov), úchytka, nohy podľa šírky — **žiadny rohový mechanizmus vo V1** · horná rohová **mimo V1**.
**Neskôr (po V1, zapísať do zásobníka):** voliteľné vybavenie rohu — polica (už funkčná) **alebo rohový výsuv typu LeMans** (set kovania + geometria/nika).

Otvorené pre package: nový `type` korpusu (`corner_blind`) vs. konštrukčný prepínač na `lower` · roly/`part_key` rohových dielcov (návrh `corner_blind_panel`, `hinge_rail`,
`corner_rail`, `cr_front`, `cr_side`) · front model: dverová zóna ako jediná zóna s čelom, slepá časť bez čiel (Fronts/`direction_slots`) · zrkadlenie = transformácia plánu, nie duplicita
geometrie · kolízia CR 2 so susednou skrinkou = neskôr (zostavy) · `BuildPlan::SCHEMA` + `CONFIG_SCHEMA` bump · outside-in (nový typ korpusu = štart bloku).

## 4 · Spotrebičová skrinka

Hypotéza z konceptu 07 §C2 potvrdená Michalom: **chladnička, vstavaná mikrovlnka, rúra = odsadenia (komín) + S1** (spotrebič v projekte, nika, kontrola) nad bežným builderom,
pravdepodobne ako šablóny. Umývačka je jednoduchá (čelo + doplnkové dielce), rieši sa neskôr, prípadne spolu s rohovou. **Digestor mimo V1.**

## 5 · Dopad na živé dokumenty (zapracuje záverečný docs PR debaty)

- [../../V1_VIZIA.md](../../V1_VIZIA.md): bod 2 prepísať (odsadenia dva prípady · chrbát z výstuh · rohová dolná · spotrebičová po S1); **V1-07 vyškrtnúť z V1** (presun do „Mimo V1");
  z „Mimo V1" **vyňať** rohovú skrinku (ostáva „špeciálne typy" = digestor, horná rohová).
- [../../PLAN.md](../../PLAN.md) blok 4: odrážku „Konštrukcia" nahradiť troma položkami K1 / K2 / K3 s odkazom sem; balík V0.4.8 (rohové spoje, poldrážka, bez dielca) presunúť do „Po V1 — zásobník".
- [../../DOGFOODING.md](../../DOGFOODING.md): bez zmeny (žiadne D-číslo).
- Poradie implementácie (po KOVANÍ, návrh Fable): K1 odsadenia + K2 chrbát (jedna alebo dve dávky, audit-povinné — CONFIG_SCHEMA) → S1 → spotrebičové šablóny → K3 rohová.
