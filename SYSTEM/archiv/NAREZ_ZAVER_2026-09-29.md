# BLOK 2 · KONTROLA + VÝROBA — Nárezový plán (primitívny): výsledok, overenie a smoke (uzáver 29.9.2026, v0.16.0)

Primitívny nárezový plán rozhodol Michal 6.9.2026 ako posledný otvorený bod bloku 2 (V1 bod 6, výstupy). Blok nárezového plánu spustil 28.9. večer;
rozhodnutia N1–N11 (prerez a orez ako nastavenia, VEPO účtuje celé tabule, orez len pre bežné platne, prídavok dupláku, **plán neotáča**, porovnanie
s VEPO po V1) a schválený mockup (O1–O12, prah poslednej platne 20 %) sú v [bloky/NAREZ/ROZHODNUTIA_MICHALA_2026-09-28.md](bloky/NAREZ/ROZHODNUTIA_MICHALA_2026-09-28.md)
a [bloky/NAREZ/MOCKUP_NAREZ_2026-09-28.html](bloky/NAREZ/MOCKUP_NAREZ_2026-09-28.html). Implementácia bežala 29.9. (PR #418–#421); uzáver vo **v0.16.0** mení
len dokumentáciu a verziu. Plný text bloku je v [ROADMAP_hotove_etapy.md](ROADMAP_hotove_etapy.md), celý priečinok bloku (rozhodnutia, mockup, packages
s auditmi návrhu, fakty z kódu, surová rešerš a surový krížový audit) v [bloky/NAREZ/](bloky/NAREZ/).
Staršie položky bloku 2 boli hotové skôr: **D-94** nákup s pôvodom (#361), **D-112** a **D-113** (#287), **D-121** (#324/#325), **D-122** (#343).

## Výsledok pre stolára

- **Štúdio → Nárezový plán** (nová živá sekcia, predtým neaktívna položka „fáza 2"): pre každý nákupný materiál karta so vzorkou, formátom, **počtom platní**,
  využitím a porovnaním s odhadom z m², pod ňou **malé platne** s rozložením dielcov. Klik na platňu otvorí **detail** (orez, dielce s názvom a rozmerom,
  najväčší zvyšok, zoznam dielcov); **oko** pri dielci označí v modeli všetky rovnaké kusy. Karty sa dajú zbaliť (predvolene otvorená prvá a problémová).
- **Počet platní je horná hranica pri tomto rozložení** — plán skladá dielce do pásov jednoduchým pravidlom, nie optimum. S týmto rozložením stačí N platní;
  VEPO reže vlastnou optimalizáciou a jeho počet sa môže líšiť. Plán je **podklad pre objednávku, objednáva človek**.
- **Upozornenie na poslednú platňu** (jantárové): keď má materiál aspoň 2 platne a posledná má využitie **pod 20 %** alebo **najviac 2 dielce** — veta
  menuje dielec, rada je v „?" (zmenšiť, iný materiál, zvyšok využiť), vedľa tlačidlo na tú platňu.
- **Dielce, ktoré sa nezmestia** alebo ich VEPO odmietne (neznáma ABS páska, chybná hrúbka, nulový rozmer, dielec, ktorý by sa zmestil len otočený), sú
  v **červenom zozname** s okom a ľudským dôvodom; taký plán je **neúplný** („N platní pre zaradené dielce — celkový počet neznámy").
- **Chipy na karte:** duplák ako prírezy s prídavkom (napr. „2 ks (hotový 820 × 580) = 4 prírezy 840 × 600"), **„bez orezu — hrany hotové"** (pracovná doska,
  kompakt, zástena), **formát chýba** a **UNI** (plán len orientačný na pracovnom formáte 2800 × 2070, tlmené platne). Lišta sekcie má chip
  **„prerez · orez · duplák"** s preklikom do Nastavení rozpočtu (jantárový pri predvolených hodnotách).
- **Nastavenia rozpočtu → Výpočet a upozornenia:** **prerez píly** 5 mm (0–10), **orez okraja platne** 10 mm (0–50), **prídavok dupláku na stranu** 10 mm
  (0–30) — raz pre všetky zákazky na tomto počítači, desatinné s čiarkou aj bodkou, „?" s vysvetlením; hodnota mimo rozsahu pole zčervená a „Uložiť" povie
  prečo. Sekcia ukáže stav súboru nastavení (novší, poškodený, nečitateľný súbor = banner a vypnuté „Uložiť").
- **Kontrola „nezmestí sa" počíta s orezom** (jedna pravda s plánom): dielec väčší ako použiteľná plocha platne je červený s vetou o použiteľnej ploche
  a „hotový rozmer vrátane ABS"; duplák sa kontroluje ako prírezy s prídavkom (jeden nález). Dielec bez smeru dekoru Kontrola skúša aj otočený (výroba ho
  otočiť smie). Nové nálezy: červený **„neplatný rozmer"** (napr. 3000 × 0) a jantárový, keď sa súbor nastavení nedá prečítať alebo má poškodenú hodnotu.
- **Rozpočet → Materiál:** poznámka riadku končí vetou **„plán: N platní (horná hranica)"** (pri neúplnom a orientačnom pláne ich vlastné pomenovanie),
  tá istá veta ide do **XLSX rozpočtu**. Karta Nárezového plánu hovorí „v rozpočte N" číslom z hotového rozpočtu.
- **Prepínač „ceny podľa plánu"** v hlavičke sekcie Materiál — **per zákazka, predvolene vypnutý** (vypnutý = presne dnešné čísla). Zapnutý berie **počet platní
  z plánu** len pri materiáli s úplným plánom, formátom z katalógu a spoľahlivými nastaveniami (značka „podľa plánu"); ostatné ostávajú na odhade so značkou
  **„z odhadu"** a vetou prečo („plán neúplný — cena z odhadu", „formát chýba", „materiál neurčený", „duplák bez väzby", „nastavenia …", „plán nedostupný").
  **Porez** ide za počtom platní v Materiáli, **montáž** ostáva z odhadu. XLSX rozpočtu nesie počet aj vetu, **cenová ponuka mení len sumu** (počty platní
  neukáže nikdy; materiál môže preklopiť návrh „samostatne" cez prah 150 €). Nič sa nezastaví; po exporte status vymenuje materiály, ktoré išli na odhad.
- **Oprava bokom (NP-4):** čakajúci zápis rozpočtu po prepnutí zákazky už neodíde do inej zákazky.
- **Nemení sa:** VEPO CSV, Kusovník, Nákup kovania a odhad z m² (ostáva ako porovnanie aj predvolená cena).

## Dávky

| Dávka | PR | Verzia | Obsah |
|---|---|---|---|
| Štart bloku | #417 | — | rozhodnutia N1–N11, schválený mockup, fakty z kódu, surová rešerš (Antigravity) a krížový audit (Codex, Grok) — **re-rez zavretého #416** (pravidlo 3 kôl b: P1 v každom z troch kôl) |
| NP-1 · jadro výpočtu | #418 | 0.15.1 | čistý modul `sheet_layout.rb` (pásové rozloženie, horná hranica, nezaradené dielce), spoločná príprava riadka s VEPO (`prepare_row`, VEPO bajtovo rovnaké) |
| NP-2 · nastavenia + Kontrola | #419 | 0.15.2 | prerez, orez, prídavok dupláku v Nastaveniach rozpočtu; súbor nastavení dodávateľa verzia 2 s doprednou bránou; Kontrola „nezmestí sa" s orezom |
| NP-3 · sekcia Nárezový plán | #420 | 0.15.3 | sekcia Štúdia (karty, malé platne, detail, posledná platňa, nezaradené), jeden výpočet plánu na zber, veta plánu v Rozpočte a XLSX |
| NP-4 · ceny podľa plánu | #421 | 0.15.4 | prepínač per zákazka, cenová spôsobilosť materiálu, porez z plánu, montáž z odhadu, `BUDGET_STD` 3, oprava fronty zápisov rozpočtu |
| Uzáver | #422 | 0.16.0 | dokumentácia a verzia, priečinok bloku do archívu |

## Overenie

Pri poslednej dávke (#421): **4842 headless · 142 JS sád zelené · in-SU 3266 PASS** (predtým NP-1 4765 · 138, NP-2 4796 · 140, NP-3 4817 · 141 — NP-1 až NP-3
bez in-SU, nič nezapisovali do modelu). Pri uzávere **4842 headless · 142 JS sád** zelené; in-SU netreba — kód sa mení len číslom verzie a cestami v komentároch.

- **Krížový audit bloku** (surový, pred packages): Codex 5 BLOCKER · 6 FIX · 3 NOTE, Grok 2 BLOCKER · 4 FIX · 4 NOTE — ako sa naložilo s každým nálezom,
  uvádza package dávky, ktorá ho riešila (sekcie „Nálezy krížového auditu").
- **Audit návrhu každej kódovej dávky** (Codex): NP-1 2 BLOCKER · 7 FIX · NP-2 2 BLOCKER · 2 FIX · 2 NOTE · NP-3 4 BLOCKER · 8 FIX · 2 NOTE · NP-4 3 BLOCKER ·
  2 FIX · 1 NOTE — **všetko prijaté** pred kódom.
- **Slepá predrecenzia** pred každým PR: NP-1 0× P1/P2 (4× P3) · NP-2 2× P2 (4× P3) · NP-3 0× P1/P2 (3× P3) · NP-4 1× P2 (4× P3) — P1/P2 opravené pred PR.
- **GitHub Codex review NP-2:** kolo 1 1× P1 (duplák bez formátu v katalógu vypadol zo zdroja) a 1× P2, kolo 2 2× P2 — opravené s testom a mutáciou.
- **Mutácie:** NP-1 25 (24 zabitých, 1 ekvivalentná) · NP-2 22/22 · NP-3 17/17 · NP-4 21/21.
- **Zlatý test NP-4:** s vypnutým aj chýbajúcim prepínačom sú rozpočet, XLSX rozpočtu aj hárok cien ponuky rovnaké ako vo v0.15.3 (odtlačok z mainu pred dávkou).
- **Výkon** (~2000 dielcov): výpočet plánu + JSON ≈ 35 ms, celý push Štúdia 377 kB (plán 118 kB), render sekcie ≈ 3 ms.
- **In-SU NP-4:** zápis prepínača + marker 3 = jeden krok Späť, porez = súčet Materiálu, montáž = súčet odhadu. Materiály testovacieho modelu sú UNI,
  takže „podľa plánu" v SketchUpe dokazujú len headless testy — **na reálnych materiáloch to overí smoke**.

## Aktualizovať plugin na oboch PC (Michal aj Lucia) pred prvou úpravou rozpočtu

- **Rozpočet zákazky je od v0.15.4 v `BUDGET_STD` 3.** Prvá úprava rozpočtu v novom plugine zapíše 3 — potom plugin v0.15.3 a starší zákazku v Rozpočte
  **needituje a zastaví oba cenové exporty** (banner s dôvodom; VEPO a nákup kovania bežia ďalej).
- **Súbor nastavení dodávateľa je od v0.15.2 vo verzii 2.** Plugin **v0.15.1 a starší** bránu nemá — keby na tom istom počítači uložil Nastavenia rozpočtu,
  **nové polia (prerez, orez, prídavok) zahodí**.
- Preto **aktualizovať obe PC na 0.16.0 skôr, ako sa na nich prvýkrát upraví rozpočet** (updater v Štúdiu → O plugine). Ostatná kompatibilita sa nemení
  (skrinka schéma 22, BuildPlan 7, ABS seed 6, šablóny STD 7).

## Priznané limity (vedome, nie chyby)

- **Plán neotáča žiadny dielec** (N8) — ani bielu W1000, HDF či UNI bez kresby; orientácia je presne ako vo VEPO súbore. Počet je preto opatrnejší (nanajvýš
  o niečo vyšší); dielec bez smeru, ktorý sa zmestí len otočený, ostane v pláne nezaradený („nezmestí sa bez otočenia" → plán neúplný, cena z odhadu).
  Otáčanie sa smie zapnúť, keď porovnanie s reálnou objednávkou ukáže, že VEPO otáča.
- **Horná hranica podľa rozloženia Noxunu** — nie optimum; **počet VEPO sa môže líšiť** (VEPO optimalizuje sám). Plán nie je výrobný dokument.
- **Plugin v0.15.1 a starší zahodí nové nastavenia** pri uložení Nastavení rozpočtu (nemá doprednú bránu súboru verzie 2).
- **Opatrná Kontrola s ABS:** „nezmestí sa" porovnáva hotový rozmer **vrátane ABS** s použiteľnou plochou; VEPO si ABS odpočíta, takže hraničný dielec
  (napr. 2782 mm s 2 mm ABS na oboch koncoch) môže byť červený, hoci by ho VEPO narezal. Veta nálezu to hovorí.
- **Nové červené nálezy v existujúcich zákazkách:** hraničné dielce (2781–2800 mm pri oreze 10) a dupláky nad použiteľnou plochou mínus prídavok; dva
  počítače s iným orezom dajú iný nález.
- **Späť po prepnutí „ceny podľa plánu"** vráti prepínač v modeli, ale okno Štúdia sa zmení až po „Obnoviť" (tooltip prepínača to hovorí).
- **Čakajúci zápis rozpočtu** sa odmietne aj v tej istej zákazke po úprave, ktorá prestavila model (napr. spotrebič s prestavbou) — bezpečný smer, klikne sa znova.
- **Mimo bloku:** optimalizácia na minimum odpadu, výkres a poradie rezov pre pílu, ručné presúvanie dielcov, sklad zvyškov, ABS v pláne, klik do obrázka
  ako výber v 3D, polovičné platne; **D-146 falošný duplák** v zásobníku Po V1.

## Otvorené body

- **Porovnanie s reálnou objednávkou VEPO (N10):** vhodná reálna zákazka teraz nie je (KLINIKA je stará). Porovnanie 1:1 **po V1 na novej zákazke**, ktorá
  sa stane testovacím štandardom; ak bude test nevyhnutný skôr — objednávka z pluginu, Michal ju pošle VEPO **bez potvrdenia** (príde výpis a nacenenie,
  bez objednania). Až to ukáže, či VEPO otáča dielce (N8) a ako ďaleko je horná hranica od reality.
- **Michalov smoke** podľa checklistu nižšie — nálezy idú do dočasnej skupiny v [DOGFOODING.md](../DOGFOODING.md) ako opravy v0.16.x.

## Smoke checklist bloku (v poradí práce)

Zlúčené zo sekcií „Smoke pre Michala" packages NP-2, NP-3 a NP-4 a zo sekcií mockupu (A–E) — bez duplicít, pri každom bode je dávka, z ktorej pochádza
(NP-1 viditeľnú zmenu nemá). Nálezy zapíš do DOGFOODING (skupina „NÁREZOVÝ PLÁN — smoke po uzávere bloku 2") — opravia sa ako v0.16.x.

**0 · Príprava**
1. Aktualizuj plugin na **0.16.0 na oboch PC** (Michal aj Lucia; updater v Štúdiu → O plugine) a reštartuj SketchUp; over verziu v O plugine. **Pred prvou
   úpravou rozpočtu na ktoromkoľvek PC.** *(celý blok)*
2. Pracuj na **kópii reálnej zákazky** s bežnými materiálmi z katalógu (nie UNI) — ideálne s dlhým bokom, pracovnou doskou a duplákom. *(celý blok)*

**1 · Nastavenia rozpočtu**
1. Štúdio → Nastavenia rozpočtu → Výpočet a upozornenia: tri nové polia **prerez 5 · orez 10 · prídavok dupláku 10** s „?"; „?" vysvetlí, čo znamenajú. *(NP-2)*
2. Ulož prerez **4,4** (s čiarkou) — uloží sa. Zadaj orez **60** → pole zčervená a „Uložiť" povie dôvod ľudsky. Vráť hodnoty na 5 / 10 / 10. *(NP-2)*

**2 · Kontrola „nezmestí sa" s orezom**
1. Bok **2790 mm** v DTD → červený nález s použiteľnou plochou a vetou „hotový rozmer vrátane ABS"; klik ho označí v modeli. *(NP-2)*
2. Orez **0** → nález zmizne; orez späť na 10 → vráti sa. *(NP-2)*
3. Pracovná doska **600 široká** (dlhá do formátu) → bez nálezu (pracovná doska je bez orezu). *(NP-2)*
4. Duplák 36 mm dlhý **2770** → jeden červený nález s prírezmi (hotový rozmer + prídavok). *(NP-2)*

**3 · Štúdio → Nárezový plán**
1. Otvor sekciu: súhrnný riadok, karta pre každý materiál s počtom platní, využitím, odhadom z m² a **„v rozpočte N"**; malé platne s rozložením. *(NP-3)*
2. Chip **„prerez · orez · duplák"** v lište → preklik do Nastavení rozpočtu. *(NP-3)*
3. Klik na platňu → **detail** (orez, dielce s rozmerom, najväčší zvyšok); **oko** pri dielci označí v modeli všetky rovnaké kusy; tlačidlo späť. *(NP-3)*
4. Materiál s aspoň 2 platňami a jedným dielcom na poslednej → **jantárové upozornenie na poslednú platňu** s dielcom a využitím, rada v „?". *(NP-3)*
5. Karta pracovnej dosky má chip **„bez orezu — hrany hotové"**; duplák chip s prírezmi; UNI alebo materiál bez formátu = **orientačne** (jantárový chip, tlmené platne). *(NP-3)*
6. Dielec väčší ako platňa → **červený zoznam** s okom a dôvodom, karta povie „celkový počet neznámy". *(NP-3)*
7. Zmeň orez v Nastaveniach rozpočtu a ulož → po uložení (prípadne „Obnoviť") sa plán prepočíta (iný počet alebo rozloženie). Vráť orez na 10. *(NP-3)*
8. Zbaľ a rozbaľ kartu; pri veľkej zákazke sekcia nezamrzne. *(NP-3)*

**4 · Rozpočet — poznámka plánu (prepínač vypnutý)**
1. Rozpočet → Materiál: poznámka riadku končí „plán: N platní (horná hranica)"; **ceny ani počty sa oproti v0.15.3 nezmenili**. *(NP-3)*
2. XLSX rozpočtu nesie tú istú poznámku; XLSX cenovej ponuky počty platní neukáže. *(NP-3)*

**5 · Ceny podľa plánu**
1. Rozpočet → Materiál → zapni **„ceny podľa plánu"** (tooltip povie, čo robí): riadky dostanú značky **„podľa plánu"** / **„z odhadu"** s dôvodom
   (tooltip značky); materiál s neúplným plánom, bez formátu alebo UNI ostane z odhadu. *(NP-4)*
2. **Porez** sa zmení (poznámka „platne z Materiálu (N podľa plánu, M z odhadu)"), **montáž nie** („· z odhadu"). *(NP-4)*
3. **Ctrl+Z** vráti prepínač jedným krokom — okno sa zmení až po **„Obnoviť"**. Znova zapni. *(NP-4)*
4. XLSX rozpočtu nesie počet aj vetu; status exportu vymenuje materiály, ktoré išli na odhad. Cenová ponuka zmení **len sumu**. *(NP-4)*
5. Karta Nárezového plánu hovorí „v rozpočte N" rovnakým číslom ako Rozpočet. *(NP-4)*
6. Vypni prepínač → **dnešné čísla** (rovnaké ako v bode 4). *(NP-4)*

**6 · Regresia**
1. Kópia reálnej zákazky bez zapnutého prepínača: VEPO CSV, Kusovník, Nákup kovania, rozpočet a ponuka sa oproti v0.15.3 nemenia (okrem novej poznámky
   „plán: …" a prípadných nových červených nálezov Kontroly pri hraničných dielcoch). *(celý blok)*

**7 · Porovnanie s VEPO (N10) — nie je súčasť smoke v SketchUpe**
1. Po V1 na novej zákazke (alebo skôr cez nepotvrdenú objednávku): počet platní z plánu vs. výpis VEPO per materiál; zapísať, či VEPO otáča dielce bez smeru.

## Mimo bloku

Optimalizácia na minimum odpadu a otáčanie dielcov (až po porovnaní s VEPO) · výkres a poradie rezov · sklad zvyškov · ABS v pláne · D-146 falošný duplák ·
EN DANIELI textový export (Po V1).
