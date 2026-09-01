# KOVANIE — sonda Gmail/Disk: kit vs. atomic nákup zásuviek (2026-09-02, checkpoint #12)

> Stav: KONCEPT / pracovný checkpoint — nie implementačný spec, neimplementovať priamo; uzavretá architektúra: KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md.

> Zdroj: subagent (read-only) nad 14 objednávkovými hárkami Disku (`OBJEDNÁVKA …`, firemná šablóna ~200 Démos kódov,
> stĺpec MENO = zákazka), 5 rozpočtami XLSX, hárkom `SKLAD NOXUN` a ~20 Gmail vláknami (objednávky na objednavky@vepo-porez.sk).
> Prílohy PDF (FA/CP od VEPO) MCP neotvorí — ceny sú z rozpočtov a z hárku Szebellai 12/2024. Obdobie 2024–2026.
> Vstup pre KOV-B (sety), KOV-C (data packy), KOV-D (mapovanie kit/atomic). Tagy: ✓ = reálne objednané · š = len v šablóne/sklade.

## 1. Konkrétne príklady objednávok

**A · MIX 18.8.2026** (VEPO potvrdilo 20.8.: 3 883,10 € s DPH) — MAJDIAKOVÁ: `357695` K-Atira 420/70 ·5· · `357774` K-Atira 420/70/176 ·1· ·
`357696` K-Atira 470/70 ·20· · `357775` 470/70/176 ·1· · `357795` 620/70/176 50 kg PTO ·6·; MANIKOVÁ: `179254` StrongBox H86/350 ·3 sety· (18 €/set);
sklad: `104717` 1 bal/200, `245723` 100, krytky `105408`/`105425` 200+200, `106412` 300. → **KIT** (36 zásuviek, každá 1 kód).

**B · MEDZIHRADSKY 8.8.2026** — `357775` 470/70/176 ·13· (62 €) · `357819` K-Atira vnútorný biely 470/70 ·3· (50 €). → **KIT**; vnútorné bez čela/príchytu.

**C · SZEBELLAI 1. fáza 10.12.2024** (jediný hárok s cenami) — Legrabox K-sady: `499013` M450 ·1· 66 € · `499049` M500 ·7· · `499072` C Pure 500/70 ·2· 95 € ·
`499249` F500/70 ·19· 130 € · `499165` C Pure 400 Tip-on ·4· 98 € · `499237` F450 Tip-on ·2· · `499241` F500 Tip-on ·5· 142 €; Quadro `317641` K-set V6 400 SiSy ·5· 27 €/ks ·
`343033` K-set V6 400 P2O ·2· 30 €; Atira `357969` K-antracit 420/70/176 ·2·; **zvlášť:** `227606` pastorky ·3· · `227607` synchro hriadeľ ·3·.
→ **KIT (47 zásuviek) + Tip-On mechanika Legrabox ATOMIC** (nikdy nie je v sade).

**D · Gmail „doobjednávka kovaní 28.10." (2025)** — jediná čistá ATOMIC drevená zásuvka: `315830`/`315831` Quadro V6 450 EB23 P2O Ľ/P ·3+3· ·
`104547`/`104548` spojka Quadro L/P ·5+5· · `491339` bočnica Legrabox F 500 ·3· (náhrada). → **ATOMIC** (K-set `317644` existoval, zvolili komponenty).

**E · Szebellai 13.7.2025 + Špirková 18.8.2025** — vnútorná Legrabox: K-sada `499307` + čelný plech `491360` + čelný reling `491359`; vnútorná Atira antracit
`358046` ·2· + čelný profil 2000 `294941` ·1· (reže sa, 1 profil na 2–3 zásuvky); Lucia v maile: „neviem či je k tomu K plech – 491360". → **KIT + doplnky ATOMIC**;
**UI potreba: vidieť „čo je v balení"** (detail členov setu — mockup to má).

**F · JANIGOVÁ/ŠOTIKOVÁ 17.2.2026** — `502978` K-StrongMax 16 121/350 ·2· · `502993` K-StrongMax 16 249/450 ·3· · `317643` K-Quadro V6 500 SiSy ·9· ·
`357755` K-Atira 144, 620/50 relingy PTO ·4·. → **KIT**. (Kaľavský 9/2025: `400343` StrongMax 89/400 čierna, `335029` 185/500 — bez „K-", overiť v Démose, či úplná sada.)

**G · ŽUFA 26.10.2025 + SZEBELLAI 2. časť 14.5.2025 + MOJŠOVÁ 8/2025** — bežné Antaro KIT (`254428` M500 ·3· `254680` D500 ·8· `254554` C500 ·1·); atypy ATOMIC:
„olejová" zásuvka `IN025B` bočnica Antaro 500 P+L + `IN102B` držiak chrbta + `12687` príchyt; Space Step `282114` výsuv TOB 500 + `203083` bočnica + `202540` držiak +
`12689` Inserta; Movento 750 `349941` + `159816`/`159817` čelné uchytenie L/P; Quadro 470 EB10,5 `457551`/`457552` ×3 páry (Cuprová). → **bežné KIT, atypy ATOMIC.**

## 2. Bilancia

| | sady (K-/1 kód) | z komponentov |
|---|---|---|
| objednávkové riadky | ≈ 62 | ≈ 35 (≈ 20 príslušenstvo k sade · ≈ 15 skutočná zásuvka z dielov) |
| **kusy zásuviek (odhad)** | **≈ 300 (≈ 93 %)** | **≈ 20 (≈ 7 %)** |

- **Výhradne KIT:** InnoTech Atira (výnimka Cuprová EB10,5) · StrongBox aj StrongMax (vždy 1 kód, aj bez „K-") · Legrabox (komponenty len doplnok/náhrada/vnútorná) ·
  Quadro V6 pod drevo (K-set `31764x`/`3430xx` dominuje; 2× pár+spojky).
- **Vždy ATOMIC:** Movento a Tandem (K-sada sa nepoužíva) · Space Step · atypické hĺbky/EB · Antaro atypy.
- **Kedy komponenty zvlášť (vzory pre členov setu):**
  1. **Vnútorná Atira** = K-sada vnútorný (`357819`/`358009`/`358010`/`358046`) + čelný profil 2000 (`294940` biela / `294941` antracit; **1 profil na 2–3 zásuvky, reže sa** — dĺžková položka) + príchyt čela pár (`295276`/`295277`).
  2. **Vnútorná Legrabox** = K-sada (`499059`/`499307`) + čelný plech `491360` + čelný reling `491359`.
  3. **Tip-On mechanika Legrabox/Movento** — vždy zvlášť: pastorky `227606`, synchro `227607`/`282277`, moduly TOB-L1/L3/L5 `275344`/`275345`/`275347`, adaptér `275348`,
     stabilizátor čela+dna `12839` (šablóna: „na všetky čelá nad 800 mm"), bočná stabilizácia `227611`.
  4. **Relingy/adaptéry Atira k vysokým:** priečny reling `294812`, adaptér variab. relingu `295318` (4 ks k 4 sadám `357772`), OrgaStore `294816`, príchyt relingu `106881`.
  5. **Drevená zásuvka na Quadro** = pár Ľ/P (`315830`/`315831`) + spojky L/P (`104547`/`104548`).
  6. **Náhrady** (bočnica Legrabox F ×3 + výsuv; „Blum výmena" 3/2024 — omylom 500 namiesto 450).
- Firemná šablóna značí K-kódy stĺpcom „komplet/sada"; rozpočty oceňujú zásuvku **jedným riadkom** (K-kód) — **kit je mentálny model firmy, komponenty výnimka.**

## 3. Démos kódy zásuvkového kovania (dátový základ pre sety / data packy)

**InnoTech Atira — K-sady (bočnice + Quadro výsuv SiSy):** `357694` 350/70 š · `357773` 350/70/176 š · `357695` 420/70 biela ✓ (43 €) · `357774` 420/70/176 ✓ (62 €) ·
`357696` 470/70 ✓ (40–43 €) · `357736` 470/70/144 š · `357775` 470/70/176 ✓ (58–62 €) · `357781` 470/70/176 50 kg ✓ · `357777` 520/70/176 š · `357782` 520/70/176 50 kg š ·
`357716` zás. 70 620/50 PTO š · `357755` zás. 144 620/50 relingy PTO ✓ · `357795` 620/70/176 50 kg PTO ✓ · `357783` zás. 176 620/50 relingy ✓ (77 €) · `357772` zás. 176 300/30 relingy ✓ ·
`357819` vnútorný biely 470/70 ✓ (50 €) · `357887` čelný antracit 350/70 ✓ · `348777` sada 470/70 antracit ✓ · `357970` čelný antracit 470/70/176 ✓ · `357969` antracit 420/70/176 ✓ ·
`358009` vnút. antracit 420/70 ✓ · `358010` vnút. antracit 470/70 ✓ · `358046` vnút. antracit 420/70/144 ✓ · `341609` 176/350 biela š · `341616` 70/470 antracit š · `341626` 176/470 antracit ✓ ·
`486157` Atira flexi sada 350/70 antracit (SKLAD).
**Atira príslušenstvo:** `294940`/`294941` čelo vnút. 2000/70 biela/antracit ✓ · `295276`/`295277` príchyt čela pár ✓ · `294812` priečny reling 2000 ✓ · `295318` adaptér relingu ✓ ·
`294816` OrgaStore 410 adaptér ✓ · `106881` príchyt relingu na čelo š · `226256`/`235128` ArciTech stabilizátor/reling š.

**Quadro V6 — K-sety (pár + príchyty):** `317640` 350 SiSy š · `317641` 400 SiSy ✓ (27–33 €) · `317642` 450 SiSy ✓ · `317643` 500 SiSy ✓ · `367919` 550 SiSy š ·
`343031` 350 P2O ✓ (36 €) · `343033` 400 P2O ✓ (30 €) · `317644` 450 P2O ✓ · `104837` V6/350 EB10,5 sada š.
**Quadro komponenty:** `315830`/`315831` V6 450 EB23 P2O Ľ/P ✓ · `457551`/`457552` V6 470 EB10,5 SiSy L/P ✓ · `104547`/`104548` spojka Quadro 25/V6 L/P ✓ ·
(SKLAD: Hettich 9225739/9225740 V6 400 EB23 P2O bez Démos kódu).

**StrongBox (vždy 1 kód):** `179252` H86/270 ✓ · `179259` H140/270 š · `402576` K-H140/270 reling ✓ · `404258` K-H204/270 1 reling ✓ · `179253` H86/300 š · `179254` H86/350 ✓ (18 €) ·
`402578` K-H140/350 reling ✓ · `179256` H86/450 š · `179263` H140/450 ✓ (19 €) · `179270` H204/450 š · `179257` H86/500 ✓ · `179264` H140/500 ✓ · `179258` H86/550 š ·
`402594` K-H204/450 2 relingy ✓ · `402596` K-H204/550 2 relingy ✓ (35 €) · titan: `400306`,`400300`,`400289`,`402572`,`400308`,`400296`,`400303` (š) · relingy zvlášť `402642`,`402624` (SKLAD) ·
`501014` StrongIn príborník ✓.
**StrongMax 16:** `502978` K-121/350 biela ✓ · `502993` K-249/450 biela ✓ · `400343` 89/400 čierna ✓ · `335029` 185/500 tmavosivá ✓ (+ z DISK sondy 7/2026: 502957, 502972/73, 502986/88, 502995, 503020, 334973, 482262).

**Legrabox — K-sady (karbon čierna CS-M):** `499091` M350 š · `499013` M450 ✓ (66 €) · `499049` M500 ✓ (66 €) · `499071` C Pure 500/40 ✓ · `499072` C Pure 500/70 ✓ (95 €) ·
`499249` F500/70 ✓ (130 €) · `499007` M450 Tip-on ✓ · `499165` C Pure 400 Tip-on ✓ (98 €) · `499237` F450/70 Tip-on ✓ (141 €) · `499241` F500/70 Tip-on ✓ (142 €) ·
`498954`/`499261` C Free 350/500 sklo š · `499059` M500 vnútorná š · `499307` K450 Tip-on vnútorná ✓.
**Legrabox komponenty:** `491339` bočnica F 500 ✓ · `491317` bočnica M 500 (SKLAD) · `349906` výsuv 450/40 TOB pár ✓ · `349907` 500/40 TOB (SKLAD) · `491360` čelný plech vnút. ✓ ·
`491361` čelný plech s drážkou š · `491359` čelný reling vnút. ✓ · `491362` unášač š · `227611` bočná stabilizácia ✓ · `227606` pastorky ✓ · `282277` synchro TOB ✓ · `227607` synchro 1160 ✓ ·
`12839` stabilizátor čela+dna ✓ · `275344`/`275345`/`275347` TOB-L1/L3/L5 ✓(L5) · `275348` synchro adaptér ✓.

**Antaro:** `254428` K-M 500 biela ✓ · `254554` K-C 500 ✓ · `254680` K-D 500 ✓ · `254431` M 500 vnútorná (rozpočet 2024) · `IN025B` bočnica 500 biela P+L ✓ · `IN102B` držiak chrbta M ✓ ·
`12687` čel. príchyt ✓ · `203083` bočnica 500 sivá ✓ · `202540` držiak chrbta sivý ✓ · `12689` príchyt Inserta ✓ · `202509` bočnica 450 sivá š.
**Tandem / Movento (vždy komponenty):** `471895`/`471898`/`471899` Tandem 3/4 Tip-on 350/500/550 · `13523`/`13526`/`13252` celovýsuv 350/500/750 · `13531`/`165333` čiastočný 400/600 ·
`13469`/`13470` čelné kovanie L/P ✓(2023) · `13516` nasúvací držiak · `499867` synchro Tandem · `282123` TOB-L3 · `282114` výsuv Tandembox TOB 500 ✓ · `349941` Movento 750/60 ✓ ·
`349928` Movento 550/40 š · `159816`/`159817` čelné uchytenie Movento L/P ✓ · `402323`/`402313` aretácia policového výsuvu š.
**Guličkové KA 4532:** `133031` 300 SiSy · `132333` 400 SiSy · `133030` 450 P2O · `130802` 500 SiSy (š) · **Space Step:** `389311`/`389313`/`389312`, `130787` (š) · **KES Conero:** `497190`/`497165`/`497203` ✓.

## 4. Čo sa nenašlo / kde hľadať ručne

- Démos priamo neposiela potvrdenia — všetko ide cez VEPO; VEPO e-shop objednávky obsahujú len porez. Presné jednotkové ceny VEPO sú v **PDF prílohách** (FA/CP), ktoré MCP
  neotvorí: `Faktúra_260092.pdf` (31.8.2026, Klinika Kalm), `kovanie + sololity.pdf` (3/2024), CP Szebellai/Mojšová/Maxwell.
- Disk hárky Trochtová 14.10.2025, Žufa, Kaľavský, Jurčo/Cuprová — MCP orezal za sekciou Space Step. **Neotvorené, ale cenné pre data packy:** `výpočet quadro V6 EB 23.xlsx`,
  `Vysuv StrongMax vypocty`, `hettich atira.pdf`, `strongMax 89,121,185.pdf`, `strongMax 249.pdf` (2/2026 — datasheety/výpočty).
- Hárok „OBJEDNÁVKA 29.4.2025 JURČO" má vnútri hlavičku „12.3.2025 CUPROVÁ" (názov súboru nesedí).
- Kľúčové súbory: Disk `OBJEDNÁVKA MIX 18.8. 2026` (id `1zHPa8gAeyOLUW356jty_NYMCNq9kwibM0JzQpVX12rI`) · `OBJEDNÁVKA 10.12. 2024 SZEBELLAI 1. fáza` (`1RQS8E-04b-3J40rKVtg31lhHKgFnLXtTse44AbT-JkI`, s cenami) ·
  `SKLAD NOXUN` (`1XLVX6IhQIQMwjhUOKp0KrPVdIEQirFR8-SbgGZ_b7Pc`).

## 5. Dôsledky pre architektúru (orchestrátor)

- **Procurement model FINAL §7 potvrdený praxou:** kit = set s jedným členom, ktorého kód vyberá NL (`code_by_nl`) — a **výškový variant vyberá SET** (Atira 420/70 = `357695`,
  420/70/176 = `357774`; StrongBox H86 vs H140 vs H204; Legrabox M/C/F) → presne dizajn R4 (per-height sety cez selector pásma, žiadne code_by_height).
- **Opening mode mení kit kód** (Quadro 400 SiSy `317641` vs P2O `343033`; Legrabox F500 vs F500 Tip-on) → sety per (výška × opening), NL vnútri — konzistentné s klasifikáciou setu (jeden opening mode).
- **Doplnky vnútorných zásuviek sú dĺžkové/pomerové** (profil 2000 na 2–3 zásuvky) → potvrdzuje, že `internal` je vo V1 len klasifikovaný (bez automatiky).
- **Ad-hoc kanál (KOV-H) pokryje** náhrady, atypy, Tip-On moduly Legrabox/Movento, stabilizátory — presne prípady, ktoré firma dnes rieši ručne.
- Seed setov pre KOV-B/D: Atira K-sady per (výška × NL × opening × load) z tabuľky §3 — kompletný rad pre biele 70/144/176 + antracit; Quadro K-sety SiSy/P2O 350–550.
