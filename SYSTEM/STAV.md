# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md).
> Dokumentačné PR ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.16.0 · 29.9.2026 — BLOK 2 · KONTROLA + VÝROBA UZAVRETÝ** (posledný bod — **primitívny nárezový plán**: štart PR #417, dávky PR #418–#421 + uzáver PR #?;
**čaká na Michalov smoke**). **Štúdio → Nárezový plán** ukazuje karty materiálov s počtom platní (horná hranica pri tomto rozložení, plán neotáča), malé platne,
detail platne, upozornenie na poslednú platňu a dielce, ktoré sa nezmestia; prerez, orez a prídavok dupláku sú v Nastaveniach rozpočtu, Kontrola „nezmestí sa"
počíta s orezom. **Rozpočet → Materiál** nesie vetu „plán: N platní" a prepínač **„ceny podľa plánu"** (per zákazka, predvolene vypnutý; zapnutý berie plán len
pri spoľahlivom pláne, ostatné „z odhadu" s dôvodom; porez za platňami, montáž z odhadu; ponuka mení len sumu).
Pod tým **blok 8 · K3 ROHOVÁ** (v0.15.0, smoke **PASS 28.9.**), **blok 7 · KONŠTRUKCIA K1+K2** (v0.14.0, smoke PASS 27.9.) a **SPOTREBIČE S1** (v0.13.0).
Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
so **štrnástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · **Nárezový plán** · Materiály · Kovanie · Spotrebiče · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine. Neaktívna položka navigácie už nie je žiadna.

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
V1 ciele **Konštrukcia** (K1 + K2 blok 7, K3 blok 8), **Materiály, Kovanie, Spotrebiče a Dvaja používatelia** sú odškrtnuté ([V1_VIZIA.md](V1_VIZIA.md)); vo **Výstupoch**
je od bloku 2 hotový aj nárezový plán — ostáva manuálne overenie cien materiálov/ABS a viac URL; **Návrh** čaká na test na kompletnej reálnej zákazke.

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.10.0) · **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) · **blok KONŠTRUKCIA K1+K2** (v0.14.0) · **blok K3 ROHOVÁ**
(v0.15.0) · **blok 2 KONTROLA + VÝROBA** (v0.16.0) — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 22** (typ `corner_blind`), **doska v schéme 2**, **šablóny v STD 7**, výrobný plán v **schéme 7**, ABS pravidlá
v **seede 6** — starší plugin zákazku neprestaví ani nevyexportuje (rohovú by sklopil na dolnú). **Dáta rozpočtu sú od NP-4 v `BUDGET_STD` 3** (prvá úprava rozpočtu
v0.15.4 zapíše 3 — potom v0.15.3 a starší zákazku v Rozpočte needituje a zastaví oba cenové exporty). **Nastavenia dodávateľa sú od NP-2 vo verzii súboru 2** (v0.15.1 a starší pri uložení nové polia zahodí).
**Aktualizovať OBE PC (aj Luciino) na 0.16.0 pred prvou úpravou rozpočtu** — starší plugin rohovú nepozná, knižnicu šablón STD 7 len číta a rozpočet `BUDGET_STD` 3 needituje.

**Testy (uzáver bloku 2, PR #?):** **4842 headless · 142 JS sád** zelené (in-SU netreba — kód len číslom verzie); posledná kódová dávka NP-4 #421: **4842 · 142 · in-SU 3266 PASS**.
**M-R:** 3983 · 114 · 2606 ([plná evidencia](archiv/MR_ZAVER_2026-09-12.md)).

## Robí sa

Žiadny blok nebeží — **ďalší blok vyberie Michal** ([PLAN.md](PLAN.md)); nový blok sa začína až po smoke PASS bloku 2 alebo výslovnom „ideme ďalej". Pri prvej rohovej
v dielni ostáva overiť záves Sensys na výstuhe závesov. **Čakajú na smoke:** **D-132** (#367), **D-133** (#368), **D-134** (#369). **D-141**, **D-142**, **D-145**
a **D-146** sú v zásobníku. **Blok 1d** podľa kapacity — R-18; **R-13 čaká na Michala**.

## Ďalší krok

**Michalov smoke bloku 2** podľa checklistu v [archiv/NAREZ_ZAVER_2026-09-29.md](archiv/NAREZ_ZAVER_2026-09-29.md) (Nastavenia rozpočtu, Kontrola s orezom, Nárezový plán,
poznámka v Rozpočte, ceny podľa plánu, XLSX) — nálezy ako v0.16.x. **Najprv aktualizovať plugin na oboch PC** (Michal aj Lucia). Porovnanie s reálnou objednávkou
VEPO (N10) po V1 na novej zákazke. Nálezy z výroby a cien majú prednosť.

## Posledné uzávery

- **BLOK 2 · KONTROLA + VÝROBA UZAVRETÝ** (**v0.16.0**, 29.9.2026; nárezový plán: štart #417, PR #418–#421 + uzáver PR #?; smoke čaká). Nárezový plán v Štúdiu, nastavenia
  prerezu/orezu/prídavku, Kontrola s orezom, ceny podľa plánu; priečinok bloku v [archiv/bloky/NAREZ/](archiv/bloky/NAREZ/).
  [Výsledok, dávky a checklist](archiv/NAREZ_ZAVER_2026-09-29.md).
- **BLOK 8 · K3 ROHOVÁ SKRINKA UZAVRETÝ** (v0.14.0 → **v0.15.0**, 27.–28.9.2026, podklady #409, PR #410–#413 + uzáver PR #414; smoke **PASS 28.9.**, PR #415). Typ „Rohová" s rohovou zostavou,
  vkladanie, riadok rohovej a prepínač strany, kresba zostavy a karta Čelá rohovej; priečinok bloku je od uzáveru v [archiv/bloky/ROHOVA/](archiv/bloky/ROHOVA/).
  [Plný blok](archiv/ROADMAP_hotove_etapy.md) · [výsledok, dávky a checklist](archiv/ROHOVA_ZAVER_2026-09-28.md) · priebeh v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK 7 · KONŠTRUKCIA K1+K2 UZAVRETÝ** (v0.13.0 → **v0.14.0**, 26.–27.9.2026, PR #401–#404 + uzáver PR #405; smoke **PASS 27.9.**). Chrbát v drážke do nárezu,
  komín vzadu a zapustený strop, oprava D-144, chrbát z líšt, šablóna Chladničková; priečinok bloku v [archiv/bloky/KONSTRUKCIA/](archiv/bloky/KONSTRUKCIA/).
  [Výsledok, dávky a checklist](archiv/KONSTRUKCIA_ZAVER_2026-09-27.md).
- **BLOK SPOTREBIČE S1 UZAVRETÝ** (v0.13.0, 20.–24.9.2026, PR #375–#389 + uzáver #390; smoke PASS 26.9.) — [výsledok, dávky a checklist](archiv/S1_ZAVER_2026-09-24.md).
- **REWORK KONTEXTU ČELÁ** — **D-130b** (v0.12.8, #372) a **D-130a** (v0.12.7, #371) · **D-134** jednotný rozsah hromadných zápisov (v0.12.6, #369) ·
  **D-133** „Nahradiť UNI…" (v0.12.5, #368) · **D-132** dormantný zámok (v0.12.4, #367) · **D-131** Kresba čiel (v0.12.3, #365) — plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK M-R VZHĽAD UZAVRETÝ** (v0.11.1 → **v0.12.0**, 11.–12.9.2026, PR #353–#359) · **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR
  #277–#340; otvorené ostáva **D-109**, R-05 po V1) · **staršie uzávery** (v0.9.x až V0.1) — [archiv/KRONIKA.md](archiv/KRONIKA.md) a [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

## Kam sa pozrieť

| Keď riešiš… | Dokument |
|---|---|
| ktorý dokument je autorita na čo (mapa `SYSTEM/`) | [README.md](README.md) |
| dátový kontrakt — dictionary, roly, identita, plán, mm Float | [STANDARD.md](STANDARD.md) |
| čo sa ide robiť, bloky prác, zaradenie D-čísel | [PLAN.md](PLAN.md) |
| otvorené postrehy z praxe (plné znenie D-čísel) | [DOGFOODING.md](DOGFOODING.md) |
| „prečo je X takto?" — história dávok, etáp a rozhodnutí | [archiv/KRONIKA.md](archiv/KRONIKA.md) · [archiv/](archiv/) |
| plné texty hotových blokov a etáp (vrátane KOVANIA) | [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md) |
| pojmy, stolárska doména, fakty o materiáloch a kovaní | [POJMY.md](POJMY.md) |
| pravidlá písania kódu — SketchUp / DC / UI dizajn | [../docs/SKETCHUP_PRAVIDLA.md](../docs/SKETCHUP_PRAVIDLA.md) · [../docs/DC_PRAVIDLA.md](../docs/DC_PRAVIDLA.md) · [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) |
| architektúra modulov (core / modules / ui) + invarianty | rozcestník [../docs/ARCHITEKTURA.md](../docs/ARCHITEKTURA.md) → mapa v [../docs/architecture/](../docs/architecture/) |
| workflow, verzie, uzáver dávky, testovanie | [../CLAUDE.md](../CLAUDE.md) |
| cieľ — čo znamená „V1 hotové" a nemenné princípy | [V1_VIZIA.md](V1_VIZIA.md) |
| kontrakt výstupu do VEPO | [VEPO_KONTRAKT.md](VEPO_KONTRAKT.md) |
| rešerše, koncepty, prieskumy dodávateľov (nezáväzné) | [zdroje/](zdroje/) |
