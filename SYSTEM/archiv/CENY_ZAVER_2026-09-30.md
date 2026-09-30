# BLOK CENY — overenie cien materiálov a ABS: výsledok, overenie a smoke (uzáver 30.9.2026, v0.17.0)

Zvyšok V1-03 (V1 bod 6 · Výstupy) — **posledný kódový bod V1**. Michal blok spustil 29.9. večer („poďme na ceny materiálov a ABS"); rozhodnutia C1–C14
(vzor ako kovanie CENY-KOV, **jeden odkaz** namiesto zoznamu, doska **za platňu**, materiál bez formátu podľa m², test na reálnej zákazke po V1) a schválený
mockup (O1–O10) sú v [bloky/CENY/ROZHODNUTIA_MICHALA_2026-09-29.md](bloky/CENY/ROZHODNUTIA_MICHALA_2026-09-29.md) a
[bloky/CENY/MOCKUP_CENY_2026-09-30.html](bloky/CENY/MOCKUP_CENY_2026-09-30.html). Implementácia bežala 30.9. (PR #426–#428); uzáver vo **v0.17.0** mení
len dokumentáciu a verziu. Plný text bloku je v [ROADMAP_hotove_etapy.md](ROADMAP_hotove_etapy.md), celý priečinok bloku (rozhodnutia, mockup, fakty z kódu,
packages M1 a M2 so surovými auditmi návrhu) v [bloky/CENY/](bloky/CENY/). Katalógové kovanie malo odkaz a ručné overenie hotové skôr (CENY-KOV, #345/#346).

## Výsledok pre stolára

- **Odkaz na produkt** pri doske a ABS páske **bez Demosu** (Štúdio → Materiály): ikona „Otvoriť produkt" — sivá otvorí obchod v prehliadači a **nič
  nezapíše**, jantárová znamená, že odkaz chýba (klik otvorí úpravu s kurzorom v poli „Odkaz na produkt"). Pri Demos položke je pole zamknuté a ručný odkaz
  ostáva odložený pre prípad zrušenia väzby. UNI a duplák odkaz nemajú. Ikony majú v riadku pevné miesto, stĺpce sú pod sebou.
- **Ručné overenie ceny** (ikona „Overiť cenu" v Materiáloch aj v Rozpočte): otvorí obchod (ak je odkaz) a formulár — doska **za platňu** s prepočtom
  na €/m², sklo bez formátu za m², ABS za bežný meter; **0 € je platná cena**. **„Potvrdiť cenu k dnešku"** zapíše dnešný dátum a nedotknutú cenu
  **nezmení ani o cent**; Rozpočet ukáže za platňu presne zadanú sumu. Zmena ceny, kódu, dodávateľa, odkazu, dekoru u dodávateľa alebo formátu overenie
  **zruší** (status to povie); názov, farba ani vzhľad nie. **Demos má prednosť** — napojenie na Demos ručné overenie nahradí.
- **D-148:** ručne prepísaná cena pri **Demos** položke už neostáva „overená" — formulár zruší dátum z Demosu a „Prepočítať ceny" ju overí znova.
- **Rozpočet → Materiál a ABS hrany:** doska a páska bez Demosu majú v stĺpci „Overená" stav **„ručne 18.9."** (sivé), **„ručne 45 dní"** alebo
  **„neoverená"** (jantárové); stav je zároveň tlačidlom „Overiť cenu" (formulár, ostáva sa v Rozpočte). Čip **„N cien na kontrolu"** a „Skontrolovať ceny"
  počítajú aj ručné materiály a pásky (UNI a duplák už nie). Pred názvom materiálu aj pásky je ikona odkazu (Demos · obchod · jantárová = doplniť odkaz).
- **Materiál bez formátu podľa m²** (C12 + C14): sklo aj bežná doska, ktorej v katalógu chýba formát platne, sa v Rozpočte počíta podľa **skutočnej plochy
  dielcov × cena za m², bez odpadu** — predtým ako fiktívna platňa 2800 × 2070 (napr. sklo 0,9 m² à 41,50 €: 240,53 → 37,35 €; DTD 1,05 m²: 180,84 →
  32,76 €). Duplák s väzbou ide v ploche zdrojovej dosky, **UNI a duplák bez väzby ostávajú na odhade platní**. MJ „m²", poznámka „formát platne nie je
  v katalógu — počíta sa skutočná plocha dielcov (bez odpadu)" (aj v XLSX); karta Nárezového plánu píše „v rozpočte 0,90 m² podľa plochy". **Porez a montáž
  sa nemenia** (Q1). V ponuke môže taký riadok klesnúť pod prah 150 € do zostavy.
- **Nemení sa:** VEPO CSV, Kusovník, Nákup kovania, kovanie v Rozpočte a ceny materiálov s formátom (overené zlatými testami).

## Dávky

| Dávka | PR | Verzia | Obsah |
|---|---|---|---|
| Štart bloku | #425 | — | rozhodnutia C1–C13, schválený mockup (O1–O9, O10 z review), fakty z kódu; poradie pred V1 (CENY → R-13 → R-37 → R-35) |
| CENY-M1a · odkaz | #426 | 0.16.1 | `product_url` pri doske/ABS bez Demosu, katalóg SCHEMA 11, formulár variantu pod jedným zámkom s `row_rev` z otvorenia |
| CENY-M1b · ručné overenie | #427 | 0.16.2 | formulár „Overiť cenu ručne", `confirm_manual_price`, zneplatnenie, prednosť Demosu, SCHEMA 12, D-148 |
| CENY-M2 · Rozpočet | #428 | 0.16.3 | vek ručných cien, „na kontrolu", „Overiť cenu" a ikona odkazu v Rozpočte, materiál bez formátu podľa m² (C14) |
| Uzáver | #429 | 0.17.0 | dokumentácia a verzia, priečinok bloku do archívu |

## Overenie

Pri poslednej dávke (#428): **4910 headless · 145 JS sád** zelené (M1a 4866 · 143, M1b 4893 · 144, po delte 4894). **In-SU nebol bránou** v žiadnej dávke
(package §8 — nové zápisy idú len do globálneho katalógu, žiadna operácia ani geometria v modeli). Pri uzávere **4910 headless · 145 JS sád** zelené,
encoding guard čistý; kód sa mení len číslom verzie a cestou v hlavičkách dvoch testov.

- **Audit návrhu** (Codex): M1 (Astra) **1 BLOCKER** (R11a — „bez zmeny" = presná zhoda so zobrazenou hodnotou, nie interval ±0,005) + 2× FIX-IN-M1a +
  1× FIX-IN-M1b; **delta audit M1** (Sol) 1 BLOCKER dotiahnutý (bm presne, bez formátu `plate = nil`) + 1 FIX + 3 NOTE · M2 (Astra) **1 BLOCKER** (testy
  a golden v súlade s R1) + 2× FIX + 1 NOTE — **všetko zapracované** pred implementáciou. Rez M1 → M1a / M1b rozhodol orchestrátor (vzor CENY-KOV-A/B).
- **Slepá predrecenzia** pred každým PR: M1a 1× P2 + 2× P3 opravené · M1b PR OK (3× P3 opravené) · M2 PR OK (1× P3 doplnené).
- **GitHub Codex review:**
  - **Štart #425:** kolo 1 = **3× P1 + 5× P2** (mockup predpisoval spôsob uloženia ceny · „cena sedí" by pri zaokrúhlení zmenila cenu o cent · sklo bez
    formátu ako fiktívna platňa → C12/O10 · kruhová podmienka V1 → C13 · …) → opravené, nové plné kolo; kolo 2 = 4× P2 → opravené, interná delta.
  - **M1a #426:** kolo 1 bez nálezov.
  - **M1b #427:** kolo 1 = 2× P2 (náhľad platňa → €/m² nezaokrúhľoval ako server · veta zneplatnenia bez „dekoru u dodávateľa") → `a705e1dd`; slepá delta
    1× P2 + 1× P3 tej istej triedy → `7bb0dd51` — náhľad aj prepnutie jednotky počítajú pravidlami servera, **test parity 10 formátov × 768 vstupov
    (7680 riadkov)** z fixtúry generovanej serverovými funkciami. Uložené ceny boli správne aj predtým — rozdiel bol len v náhľade formulára.
  - **M2 #428:** kolo 1 = 1× P2 (tooltip „ceny podľa plánu" sľuboval viac, než kód robil) → `fcaccf21`, delta OK; po rozhodnutí **C14** (Q2) nové plné
    kolo 2 na `ebbd7c02` bez nálezov; delta 2× P3 v textoch o dupláku → `552732e4`.
- **Mutácie:** M1a M1–M8 + M22 (Ruby aj JS) a 6 mutácií opráv z predrecenzie · M1b M9–M21, M23, M24 · M2 M1–M25 (po C14 9/9 dotknutých, M21R = návrat
  k obmedzenému R1, M25 = plocha aj pre duplák) — **všetky zabité**.
- **Zlaté testy:** M1a a M1b — Rozpočet, XLSX, ponuka aj VEPO bez zmeny (R24, `test_np4_golden.rb` zelený). M2 — **golden B** (odtlačok zákazky so sklom
  a doskou bez formátu spred M2: zmena len na vymenovaných cestách) a **NP-4 golden vedome pregenerovaný po C14** (DTD bez formátu 180,84 → 32,76 €,
  SPOLU 3394 → 3246 €); porez a montáž nikde bez zmeny. **O7 mriežka** M1b: 15 formátov × 0,00–200,00 € po centoch — cena za platňu v Rozpočte 0 chýb.

## Aktualizovať plugin na oboch PC (Michal aj Lucia)

**Aktualizuj plugin na OBOCH PC pred prvým uložením odkazu, ručným overením ceny alebo posielaním ponúk** (updater v Štúdiu → O plugine):
- **Katalóg materiálov je po prvom uloženom odkaze v schéme 11 a po prvom ručnom overení v schéme 12** — starší plugin ho ďalej číta (aj Rozpočet), ale
  **nezapíše doň** (v0.16.0 a starší po prvom odkaze, v0.16.1 po prvom ručnom overení).
- **`BUDGET_STD` sa nemení** — starší plugin (≤ 0.16.2) tú istú zákazku otvorí bez varovania, ale **sklo aj dosku bez formátu ocení po starom** (celá
  platňa) a jeho XLSX ponese inú sumu. Vedome prijaté prevádzkové riziko (STANDARD §11.3).
- Ostatná kompatibilita sa nemení (skrinka schéma 22, BuildPlan 7, `BUDGET_STD` 3, nastavenia dodávateľa verzia 2, ABS seed 6, šablóny STD 7).

## Priznané limity (vedome, nie chyby)

- **Materiál bez formátu sa počíta bez odpadu** (C14) — pri bežnej doske bez formátu to cenu podhodnotí oproti reálnemu nákupu celých platní; riešenie
  je doplniť formát do katalógu. Kontrola ani Materiály na dosku bez formátu zatiaľ neupozornia (F1 M2).
- **Porez a montáž** pri skle a doske bez formátu ostávajú z odhadu platní (Q1 bez odpovede).
- **Kusovník a karta Nárezového plánu** pri skle bez formátu ďalej ukazujú orientačný počet platní 2800 × 2070 (F3 M2).
- **Dátum ručného overenia je v UTC** — po polnoci miestneho času môže tooltip ukázať predošlý deň (F5 M1; kovanie rovnako).
- **Formát dátumu** v Rozpočte: kovanie „ručne 10.09.2026", materiály „ručne 18.9." (F2 M2).
- Vstup jemnejší ako cent (31,038) sa nepovažuje za zobrazenú hodnotu — potvrdenie ho vždy berie ako zmenu ceny.

## Otvorené body

- **Michalov smoke** podľa checklistu nižšie — čaká. Nálezy do dočasnej skupiny „CENY — smoke po uzávere" v [DOGFOODING.md](../DOGFOODING.md) ako opravy
  v0.17.x. **Poistka:** R-13 (ďalší bod pred V1) sa začína až po smoke PASS alebo Michalovom „ideme ďalej".
- **Q2 rozhodnutá (C14, 30.9.2026):** aj bežná doska bez formátu podľa skutočnej plochy dielcov (bez odpadu); UNI a duplák bez väzby na odhade platní.
- **Q1 bez odpovede:** porez a montáž pri skle na mieru — **bez zmeny** (bezpečnejšia vratná voľba; alternatíva „sklo bez porezu" mení jeden riadok R5).
- **Kandidáti na D-čísla** (nálezy mimo scope z packages, rozhoduje Michal): **M1** F3 tri takmer rovnaké sanitizéry odkazu · F4 kovanie pri napojení na Demos
  odkaz maže, materiály ho odkladajú · F5 dátum v UTC. **M2** F1 upozornenie na bežnú dosku bez formátu · F2 jednotný formát dátumu overenia · F3 sklo
  v Kusovníku a Nárezovom pláne ako platne · F4 minimálna plocha kusa a opracovanie hrán skla · F5 `manual_from_budget` bez produkčného volajúceho ·
  F6 typ „Zástena" s diakritikou nie je v registri typov.
- **Test na kompletnej reálnej zákazke** je akceptačný test **po V1** (C10/C13).

## Smoke checklist bloku (v poradí práce)

Zlúčené zo sekcií „Smoke checklist pre Michala" package M1 (§10, body M1a 1–5 a M1b 6–14) a M2 (§10, body 1–10) — bez duplicít, **bod 4 M2 opravený podľa
C14** (bežná doska bez formátu sa už počíta podľa m²). Pri každom bode je dávka, z ktorej pochádza.

**0 · Príprava**
1. **Aktualizuj plugin na 0.17.0 na OBOCH PC** (Michal aj Lucia; updater v Štúdiu → O plugine) **pred prvým uložením odkazu, ručným overením ceny alebo
   posielaním ponúk**; reštartuj SketchUp a over verziu v O plugine. *(celý blok)*
2. Pracuj na **kópii reálnej zákazky**, v ktorej je doska alebo páska **bez Demosu** (napr. DTDL 25 z Drevocentra), **sklo bez formátu** (napr. sklenené
   police) a **doska bez formátu** v katalógu. *(celý blok)*

**1 · Štúdio → Materiály: odkaz na produkt**
1. Otvor dekor s doskou alebo páskou **bez Demosu**: vpravo v riadku je **jantárová** ikona odkazu; stĺpce kód, cena, dodávateľ sú pod sebou aj v riadkoch
   s Demosom. *(M1a)*
2. Klik na jantárovú ikonu → otvorí sa úprava (ceruzka) s kurzorom v poli „Odkaz na produkt". Vlož adresu obchodu a ulož → ikona zosivie; klik na ňu
   otvorí obchod v prehliadači a **nič sa nezmení** (cena, dátum). *(M1a)*
3. Vlož zlú adresu (bez http/https alebo s medzerou) → formulár ostane otvorený s hláškou, nič sa neuloží. *(M1a)*
4. Otvor ceruzku pri **Demos** položke → pole odkazu je zamknuté s vysvetlením. Vymaž Demos URL → pole sa odomkne. *(M1a)*
5. UNI a duplák ikonu odkazu nemajú. *(M1a)*

**2 · Štúdio → Materiály: ručné overenie ceny**
1. Pri položke bez Demosu je druhá ikona **„Overiť cenu"** — jantárová; tooltip „Cena nebola nikdy ručne overená — na kontrolu". *(M1b)*
2. Klik → otvorí sa obchod aj formulár. Doska: cena **za platňu** (napr. 179,90) → vedľa prepočet na €/m²; „Potvrdiť cenu k dnešku" → ikona zosivie,
   tooltip „Cena ručne overená 30.9.2026 (dnes)". *(M1b)*
3. Sklo bez odkazu a bez formátu → formulár sa otvorí **bez prehliadača**, cena **za m²**; potvrď. ABS páska → cena za bm. *(M1b)*
4. Potvrď **0 €** → prejde s vetou „materiál sa do rozpočtu započíta nulou". *(M1b)*
5. Prepíš cenu v bunke (alebo kód, dodávateľa; v ceruzke odkaz alebo formát) → ikona overenia zožltne a status povie, že ručné overenie sa zrušilo. Názov,
   farba ani vzhľad overenie nezrušia. *(M1b)*
6. Bunka ceny ukazuje 2 desatinné; klik do bunky a von bez zmeny nič nezmení (ikona ostane sivá). *(M1b)*
7. Ručne overenú položku napoj na Demos (Aktualizovať z Demosu alebo Demos URL v ceruzke) → ukazuje sa Demos ikona, ručné overenie zmizlo. Vymaž Demos URL
   → vráti sa tvoj ručný odkaz, overenie ostane jantárové (treba overiť znova). *(M1b)*
8. Pri **Demos** položke prepíš v ceruzke cenu a ulož → status povie, že dátum overenia z Demosu sa zrušil (D-148); „Prepočítať ceny" ju znova overí. *(M1b)*

**3 · Rozpočet: ručné ceny**
1. Doska/páska **bez Demosu** v zákazke: stĺpec „Overená" ukazuje jantárové „neoverená"; čip hore „N cien na kontrolu" ju počíta. UNI v čipe nie je. *(M2)*
2. Klik na „neoverená" → otvorí sa formulár „Overiť cenu" (ten istý ako v Štúdiu), Rozpočet ostane otvorený; s odkazom sa otvorí aj obchod, **sklo bez
   odkazu len formulár**. Potvrď → riadok zosivie na „ručne 30.9.", čip klesne. *(M2)*
3. Doska overená za platňu (bod 2.2, napr. 179,90) → Rozpočet ukáže za platňu **presne 179,90 €**. *(M1b)*
4. Rozbaľ čip: položka bez Demosu má ikonu odkazu a „Overiť cenu", Demos položka ikonu a obnovenie. Keď ostanú na kontrolu len ručné ceny, tlačidlo sa
   volá **„Skontrolovať ceny"** a otvorí tento zoznam. *(M2)*
5. Ikona pred názvom materiálu/pásky: pri Demos otvorí Demos, pri ručnej s odkazom obchod; **jantárová** (odkaz chýba) prepne do Štúdia → Materiály
   a otvorí úpravu s kurzorom v poli „Odkaz na produkt". *(M2)*

**4 · Rozpočet: materiál bez formátu podľa m²**
1. Zákazka so **sklom bez formátu**: Rozpočet → Materiál — riadok skla má množstvo v **m²** (napr. 0,90 m²), cenu za m² a medzisúčet = m² × cena; poznámka
   „formát platne nie je v katalógu — počíta sa skutočná plocha dielcov (bez odpadu)". Predtým tu bola 1 celá platňa 2800 × 2070. *(M2)*
2. **Doska (DTD/MDF) bez formátu** v katalógu sa počíta **tiež podľa m²** (C14) — rovnaký tvar riadku ako sklo; **UNI a duplák bez väzby** ostávajú na odhade
   platní, duplák s väzbou ide v ploche svojej zdrojovej dosky. *(M2 po C14)*
3. **Porez a montáž** sú **rovnaké** ako pred aktualizáciou. *(M2)*
4. XLSX rozpočtu: riadok skla MJ „M2", počet 0,90, cena za m², súčet sedí. Cenová ponuka: zmení sa len suma; ak bolo sklo samostatným riadkom len kvôli
   platni a je lacnejšie ako 150 €, presunie sa do zostavy. *(M2)*
5. Zapni „ceny podľa plánu": sklo aj doska bez formátu ostanú podľa plochy (bez značky „z odhadu"); v Nárezovom pláne karta skla píše „v rozpočte 0,90 m²
   podľa plochy". *(M2)*

**5 · Regresia**
1. Zákazka **bez skla a bez dosky bez formátu** — súčet Rozpočtu rovnaký ako predtým. *(M2)*
2. Kovanie v Rozpočte vyzerá ako predtým; VEPO CSV, Kusovník a Nákup kovania sa nemenia. *(celý blok)*
