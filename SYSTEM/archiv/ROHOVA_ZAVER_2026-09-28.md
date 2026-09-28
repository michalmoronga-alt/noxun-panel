# K3 ROHOVÁ SKRINKA — výsledok, overenie a smoke (uzáver 28.9.2026, v0.15.0)

Blok 8 vybral Michal 27.9.2026 večer po smoke PASS bloku 7 ako nočný blok. Rozhodnutia R1–R9 (špecifikácia z debaty 6.9. podľa DC „Rohová", ktorú dielňa
roky používa, + nové 27.9.: jedny dvierka, pánty predvolene pri rohu) sú v [bloky/ROHOVA/ROZHODNUTIA_MICHALA_2026-09-27.md](bloky/ROHOVA/ROZHODNUTIA_MICHALA_2026-09-27.md);
krížový audit bloku (Codex s repom, Grok s webom) a jeho vyhodnotenie dal podklady (PR #409). Mockup ovládačov
([bloky/ROHOVA/MOCKUP_ROHOVA_2026-09-28.html](bloky/ROHOVA/MOCKUP_ROHOVA_2026-09-28.html)) Michal schválil 28.9. — **O1–O12 podľa návrhu** (rozhodnutie R10).
Implementácia bežala 27.–28.9. (PR #410–#413); uzáver vo **v0.15.0** mení len dokumentáciu a verziu. Plný text bloku je v [ROADMAP_hotove_etapy.md](ROADMAP_hotove_etapy.md),
celý priečinok bloku (rozhodnutia, mockup, packages s auditmi návrhu, krížový audit a jeho vyhodnotenie, presná geometria DC, fakty z kódu) v [bloky/ROHOVA/](bloky/ROHOVA/).

## Výsledok pre stolára

- **Nový typ skrinky „Rohová"** — dolná **slepá rohová skrinka s CR lištou**, ako DC „Rohová": korpus ako bežná dolná (dno, strop alebo výstuhy, chrbát, sokel,
  nohy, police) a na prednej rovine **rohová zostava** — **blenda korpusová** (zakrýva slepú časť), **výstuha závesov**, **CR 1** (lišta vedľa dverí),
  **CR 2** (lišta kolmo k susednému radu) a **rohová výstuha**. CR 2 a rohová výstuha trčia pred korpus (~10 cm pri CR 2 = 80) — tak ako v DC.
- **Predvolená rohová** (O1): 1100 × 720 × 510, sokel 100, dverová časť **450**, CR 1 / CR 2 **80 / 80**, dvere **vľavo**, pánty **pri rohu**. Pri okraji dverí pri rohu
  2 mm sú dvere **446** a CR 1 **78** (O11).
- **Jedny dvierka** v dverovej časti (R6) na celú výšku, vnútri **police cez celú šírku** skrinky (začínajú za blendou); zásuvky, iné čelá ani priečky rohová
  nemá — plugin také zmeny odmietne vetou.
- **Vkladanie:** tlačidlo **„Rohová"** vo vkladacej karte (Dolná · Horná · Rohová · Umývačka · Doska), ikona z mockupu; ghost, klik = rohová ako **jeden krok Späť**.
  Pri vkladaní prepne stranu dverí kláves **D** (pásik ghostu povie „dvere vľavo / vpravo"); rohové šablóny sa ponúkajú len pri type Rohová.
- **Ovládače** (O3, O4): v **Základné → Rozmery** (aj vo vkladacej karte) jeden riadok **Dverová časť · CR 1 · CR 2 · strana dverí**. Rozsahy (O2): dverová časť
  250–800, CR 1 aj CR 2 50–250; skrinka musí byť aspoň dverová časť + CR 1 + hrúbka CR 2 + 2 × korpus (pri 450 / 80 = **584**) — inak pole zčervená a nič sa nepostaví.
- **Prepnutie strany** (O5) zrkadlí celú zostavu aj dvere, skrinka ostane na mieste, pánty ostanú voči rohu, okraje čiel sa prehodia a ručne zmenená hrana
  (ABS) prejde so zrkadlom — **jeden krok Späť**.
- **Náhľad v Inspectore** kreslí celú rohovú zostavu podľa mockupu (blenda šrafovaná, CR 1, CR 2 a rohová výstuha, kóty 450 / 80, obe strany, nezmestenie
  červenou; v Korpuse aj dvere); značky pántov sú na strane podľa smeru (oprava aj pre dolnú — predtým vždy vľavo).
- **Karta Čelá** povie „Rohová skrinka má v dverovej časti jedny dvierka.", pánty volá **„Pri boku / Pri rohu"** (O10); delenie zón pri rohovej zmizlo.
  V pravom stĺpci Základných je **„Šírka dverí 446"** s preklikom do Čiel a lišta Základné povie „dvere vľavo 450" (O12).
- **Zmena šírky** (v Inspectore aj ťahaním) mení len slepú časť — dvere a CR ostanú; ťahanie pod minimum sa zastaví na najmenšej platnej šírke s vetou.
- **Výstupy:** kusovník, VEPO, nákup kovania a cenová ponuka ako pri dolnej. VEPO skratky (O6): **Blenda roh**, **Vyst zav**, **Vyst roh**, **CR 1**, **CR 2**.
  CR lišty sú z **čelového materiálu s ABS dookola** (R4, v ponuke ako „dvierka"), blenda a výstuhy z korpusu s ABS podľa DC (O7: blenda bez ABS, výstuha
  závesov zadná hrana, rohová výstuha predná, spodná a horná). Kovanie (R5): závesy
  podľa výšky dverí (bežne 2), úchytka, nohy podľa šírky (6 pri 1100) — žiadny rohový mechanizmus.

## Dávky

| Dávka | PR | Verzia | Obsah |
|---|---|---|---|
| Podklady | #409 | — | rozhodnutia R1–R9, fakty z kódu, presná geometria DC (sonda), rešerš precedensov, krížový audit a vyhodnotenie (docs) |
| ROH-A1 · jadro | #410 | 0.14.1 | typ `corner_blind`, stavba oboch strán, účinné hrúbky CR, výstupy, ochrany, klamp šírky; `CONFIG_SCHEMA` 22, BuildPlan 7, ABS seed 6 |
| ROH-A2 · vkladanie a náhľad | #411 | 0.14.2 | tlačidlo „Rohová", čelný otvor zo servera, dvere a pánty v náhľade, nohy pri vkladaní, zámok typu v modale šablóny |
| ROH-B1 · ovládače a strana | #412 | 0.14.3 | riadok rohovej (Základné aj vkladanie), minimum šírky z účinných hrúbok, prepínač strany = zrkadlo (1 krok Späť) |
| ROH-B2 · kresba a čelá | #413 | 0.14.4 | kresba zostavy zo servera, karta Čelá rohovej, bez delenia zón, O12 (šírka dverí, súhrn, kláves D), ikona, odhad dielcov |
| Uzáver | #? | 0.15.0 | dokumentácia a verzia, priečinok bloku do archívu |

## Overenie

Pri poslednej dávke (#413): **4721 headless · 138 JS sád · 3260 in-SketchUp PASS / 0 FAIL** (predtým A1 4689 · 135 · 3208, A2 4698 · 136 · 3222,
B1 4710 · 137 · 3244). Pri uzávere headless a všetky JS sady zelené; in-SU netreba — kód sa mení len číslom verzie.

- **Krížový audit bloku** (Codex 3 BLOCKER · 6 FIX · 5 NOTE, Grok 2 BLOCKER · 7 FIX · 2 NOTE) — **5 BLOCKERov** (hrúbky CR pred stavbou, priečky cez blendu,
  záporná medzera pri rohu, panel by sklopil neznámy typ na dolnú) **všetky prijaté** v reconcile a vyriešené v ROH-A1
  ([bloky/ROHOVA/RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md](bloky/ROHOVA/RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md)).
- **Audit návrhu ROH-A1** (Codex): **1 BLOCKER** (polica pri hrubšom korpuse by prešla blendou → odsadenie police `max(20, t)`) · 3 FIX · 1 NOTE — všetko
  zapracované pred kódom. **Dobrovoľný audit ROH-B1:** 0 BLOCKER · 5 FIX · 2 NOTE — všetko zapracované.
- **Slepá predrecenzia** pred každým kódovým PR: A1 0 × P1/P2 (3 × P3) · A2 2 × P2 · B1 2 × P2 · B2 0 × P1/P2 (4 × P3) — P1/P2 opravené pred PR.
- **In-SU brána** pri každej kódovej dávke (plán = model pre obe strany a viac kombinácií, Späť, odmietnutia, šablóny, kópie, scale šírky, prepnutie strany
  s ručnými hranami, kláves D počas vkladania), GitHub Codex review a zelené CI pred mergom.
- **Mutácie:** A1 11 · A2 5 (napojenia vkladania, M4–M8) · B1 19 · B2 13 — každú test chytil.
- Kláves D: in-SU overené, že na Michalovom PC D nemá v SketchUpe skratku (51 skratiek, D žiadna); či ho SketchUp počas ghostu naozaj doručí, overí smoke.

## Aktualizovať plugin na oboch PC (Michal aj Lucia) pred prvou rohovou

Zákazka uložená vo v0.15.0 je pre starší plugin uzamknutá: skrinka je v **schéme 22**, výrobný plán v **BuildPlan 7**, ABS pravidlá v **seede 6**,
knižnica šablón ostáva v **STD 7** (rozpočet `BUDGET_STD` 2). Starší plugin rohovú **nepozná** — neprestaví ju ani nevyexportuje (prestavbou by ju sklopil
na dolnú). **Preto aktualizovať obe PC skôr, ako sa na nich otvorí zákazka s rohovou.**

## Známe obmedzenia (vedome, nie chyby)

- **Obálka prisunutia a ghostu nevidí CR 2 a rohovú výstuhu** (trčia pred korpus) — pri prisúvaní k susednému radu treba roh skontrolovať okom (R9, G10).
- **Výrez police pre výstuhu závesov robí dielňa** — polica ide cez celú šírku (O8); plugin k tomu dáva jantárové (ORANGE) upozornenie — či ostane, rozhodne
  Michal (Otvorené body).
- **CR lišty nejdú s hromadnou „Kresbou čiel"** — kreslia sa zvislo ako doteraz (O9).
- **Priečky v rohovej sú zakázané** (priečka by prešla blendou) a rohová má len jedny dvierka — zásuvky ani iné čelá nie.
- **Strana dverí sa mení len prepínačom** v riadku rohovej; šablóna inej strany sa na existujúcu rohovú odmietne, typ sa nemení ani šablónou, ani úpravou.
- **CR 1 a CR 2 rovnakého rozmeru** sa v kusovníku zlúčia do jedného riadku (správne — výrobne ten istý kus).
- **Mimo V1:** horná rohová skrinka, rohové mechanizmy (LeMans, karusel), kolízie CR 2 so susedným radom (zostavy), sokel okolo rohu, kresba výrezu police.

## Otvorené body

- **O8 — jantárové upozornenie „výrez police × výstuha závesov":** ROH-A1 ho pridal navyše k mockupu ako vratnú voľbu; **čaká na Michalov pokyn**, či ostane
  (keď nie, odstráni ho malá oprava v0.15.x).
- **Overenie v dielni pri prvej rohovej** (C9): záves Sensys 9071205 + podložka D1,5 zo setu KLASIK **na výstuhe závesov**, **prekrytie 16 mm**, dvere sa
  otvoria **bez dotyku CR 1** (medzera 4 mm).

## Smoke checklist bloku (v poradí práce v dielni)

Zlúčené zo sekcií „Smoke pre Michala" packages ROH-A1, A2, B1 a B2 — bez duplicít, pri každom bode je dávka, z ktorej pochádza. Nálezy zo smoke idú do
[DOGFOODING.md](../DOGFOODING.md) (dočasná skupina „K3 ROHOVÁ — smoke po uzávere bloku 8") ako opravy v0.15.x.

**0 · Príprava**
1. Aktualizuj plugin na **0.15.0 na oboch PC** (Michal aj Lucia; updater v Štúdiu → O plugine) a reštartuj SketchUp; over verziu v O plugine. *(celý blok)*

**1 · Vkladanie**
1. Vkladacia karta → **Rohová** → ghost → klik: skrinka 1100 so dverami vľavo, pred skrinkou **CR lišta do tvaru L** (trčí ~10 cm dopredu); náhľad pri
   vkladaní ukazuje celú zostavu. **Ctrl+Z** ju odstráni jedným krokom. *(A2, B2)*
2. Počas ghostu stlač **D** → strana dverí sa prepne a pásik ghostu povie „dvere vpravo"; klik vloží pravú rohovú (jedno Späť). **Over, či SketchUp kláves D
   naozaj doručí** (a nič iné sa nestane). *(B2)*
3. Vkladacia karta: Rohová + prepínač ◨ → vloží sa pravá rohová. *(B1)*

**2 · Inspector a náhľad**
1. Označ rohovú: typ „Rohová", náhľad = mockup C — dvere len v dverovej časti (450), blenda šrafovaná, CR 1, CR 2 a rohová výstuha, kóty 450 / 80; pánty
   na strane pri rohu. To isté pri pravej (zrkadlo). *(A2, B2)*
2. Lišta Základné povie **„dvere vľavo 450"**; v pravom stĺpci **„Šírka dverí 446"** — klik prejde do Čiel. *(B2)*

**3 · Riadok rohovej a prepnutie strany**
1. V Rozmeroch riadok **Dverová časť 450 · CR 80 / 80 · ◧** → prepni na ◨ → skrinka ostane na mieste, dvere a CR lišta sú vpravo, pánty pri rohu;
   **Ctrl+Z** vráti jedným krokom. *(B1)*
2. Dverová časť **500** → dvere 496, slepá časť sa zúži. *(B1)*
3. Šírka **580** → pole zčervená (minimum 584), nič sa nepostaví. *(B1)*
4. Ručne zmeň ABS na ľavej hrane dverí → prepni stranu → páska je na tej istej (teraz pravej) fyzickej hrane pri boku. *(B1)*

**4 · Čelá a obmedzenia**
1. Karta Čelá: veta **„Rohová skrinka má v dverovej časti jedny dvierka."**, pánty **„Pri boku / Pri rohu"**, krížik a typ zamknuté s vysvetlením. *(B2)*
2. Zmeň smer pántov na vonkajší bok („Pri boku") — ide. *(A2, B2)*
3. Skús pridať zásuvku alebo priečku v rohovej — plugin odmietne s vetou; v Zónach nie je delenie zóny. *(A2, B2)*

**5 · Zmena šírky**
1. Šírka **1200** (v Inspectore aj ťahaním) — rastie len slepá časť, dvere a CR ostanú. *(A1, A2)*
2. Potiahni šírku pod minimum → zastaví sa na najmenšej platnej šírke + hláška; jedno Späť vráti všetko. *(A1)*

**6 · Výstupy pre dielňu**
1. Kusovník / Štúdio: blenda, výstuha závesov, rohová výstuha, CR 1, CR 2 (CR z čelového materiálu). *(A1, A2)*
2. VEPO export: nové riadky s krátkymi názvami (Blenda roh, Vyst zav, Vyst roh, CR 1, CR 2; ≤ 20 znakov), CR s ABS dookola. *(A2)*
3. Nákup kovania: **2 závesy, 6 nôh** (pri 1100). Cenová ponuka: CR ako „dvierka". *(A1, A2)*
4. Kontrola: jantárové upozornenie „výrez police × výstuha závesov" — **povedz, či ho chceš nechať** (O8). *(A1)*
5. Regresia: kópia reálnej zákazky bez rohovej — kusovník, VEPO a ponuka sa nemenia. *(celý blok)*

**7 · Overenie v dielni pri prvej rohovej** *(A1, C9)*
1. Záves Sensys 9071205 + podložka D1,5 sedí na **výstuhe závesov**.
2. **Prekrytie 16 mm** zodpovedá skutočnosti.
3. Dvere sa otvoria **bez dotyku CR 1** (medzera 4 mm).

## Mimo bloku

Horná rohová a vysoká/potravinová skrinka ako nové typy (zásobník Po V1) · LeMans / karusel · kolízie so susedným radom a sokel okolo rohu (zostavy) ·
kresba výrezu police · CR v „Kresbe čiel" · D-145 (3D náhľad Inspectora).
