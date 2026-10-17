# Delta verifikácia auditov U1–U5 — Codex `gpt-6.1-sol` (17.10.2026)

**A — Uzavretie nálezov**

Hodnotím návrh, nie vykonané testy. „Chýba test“ znamená, že konkrétny scenár nie je doložený v povolenom texte. B = BLOCKER, F = FIX; čísla zodpovedajú pôvodným auditom.

| Nález | Verdikt | Odôvodnenie |
|---|---|---|
| [U1/1 B](SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U1.md:430) | UZAVRETY | Zákaz abortu pokrýva vynútená chyba P6 so zachovaním geometrie. |
| U1/2 F | CIASTOCNE | Volanie je kvalifikované; T9b zostáva odkazom bez opísaného scenára. |
| U1/3 F | UZAVRETY | Autoritu prázdneho názvu preveruje T5c s rozdielnymi mapami dvoch PC. |
| U1/4 F | UZAVRETY | P1–P6 stanovujú merania aj záväzné zamietnutie variantu A. |
| U1/5 F | UZAVRETY | Vetvenie podľa konštanty má overenie oboch variantov sondy. |
| [U2/1 B](SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U2.md:407) | UZAVRETY | Blokovanie zápisov, výpočtov a bootu má scenáre živého vlastníka aj zlyhanej obnovy. |
| U2/2 B | UZAVRETY | Obnova prítomnosti, neprítomnosti a značiek má bajtové porovnanie po zlyhaní. |
| U2/3 B | UZAVRETY | Kontrola pred načítaním má regresiu chýbajúceho primára so starou `.bak`. |
| U2/4 F | UZAVRETY | Samostatný rollback zachováva zálohu a testuje opakovaný pád. |
| U2/5 F | UZAVRETY | Odloženú rotáciu preveruje obnova najstaršej z piatich záloh. |
| U2/6 F | CIASTOCNE | Kontroly leases nezabránia štartu ďalšieho procesu počas exportného snímku. |
| [U3/1 B](SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U3.md:407) | CIASTOCNE | Čerstvý export aj verzia sú rozhodujúce, ale chýba regresný scenár. |
| U3/2 B | CIASTOCNE | Konzervatívne pravidlo existuje, ale chýba test úpravy pred aktualizáciou pluginu. |
| U3/3 B | CIASTOCNE | Odmietnutie starého tiketu existuje, ale chýba test opačného poradia commitov. |
| U3/4 F | CIASTOCNE | Aktivácia a izolácia zdroja sú určené; chýba scenár konfliktu doručeného po lehote T. |
| U3/5 F | CIASTOCNE | `peek_group` má testy U2, ale chýba overenie spracovania `:unknown` v U3. |
| U3/6 F | CIASTOCNE | Porovnanie distribúcie je konkrétne, ale chýba regresný test odmietnutia. |
| U3/7 F | CIASTOCNE | Pracovník má limit, ale chýba test zaseknutého prechecku. |
| U3/8 F | CIASTOCNE | Doklad dokončenia existuje, ale chýba test nadväzujúceho zotavenia evidencie U3. |
| U3/9 F | CIASTOCNE | Pravidlo mazania je opravené; oneskorený ukazovateľ nemá konkrétny regresný scenár. |
| [U4/1 B](SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U4.md:320) | CIASTOCNE | Žurnál aj pádové testy sú konkrétne, ale volanie U3 neodovzdáva `replacements:`. |
| U4/2 B | UZAVRETY | Povinný konflikt zastaví skupinu; oba výsledky rozhodnutia majú test. |
| U4/3 F | UZAVRETY | Presná koncovka má pozitívny aj požadovaný negatívny test. |
| U4/4 F | CIASTOCNE | Nové úpravy sa sledujú, ale prvotné doplnenie digestu môže skryť existujúcu úpravu. |
| [U5/1 B](SYSTEM/zdroje/bloky/UPDATE/PACKAGE_U5.md:452) | CIASTOCNE | Okno dopadov pribudlo; obnova neodovzdáva odtlačok a chýba regresný scenár. |
| U5/2 B | UZAVRETY | Epocha a tokeny majú test oneskorených zápisov aj odpovedí po otvorení. |
| U5/3 F | CIASTOCNE | Väzba na zákazku je konkrétna, ale chýba test prepnutia alebo zmeny zákazky. |
| U5/4 F | CIASTOCNE | Čítanie aj scenáre sú určené; hodnota `:unknown` koliduje s výpočtom U3. |
| U5/5 F | UZAVRETY | Ponuka obnovy má scenár jedinej problémovej skupiny `pending`. |
| U5/6 F | UZAVRETY | Štartovací stav preveruje priame otvorenie Materiálov bez O plugine. |
| U5/7 F | CIASTOCNE | Ručná akcia aj API sú definované, ale chýba test vyriešenia konfliktu. |

**B — Nesúlady rozhraní**

- **U2 R4.8 verzus U3 R-I:** súhrn neuvádza `library_members(g)` ani `pending_block`, hoci ich R-I vyžaduje.
- **Zámok:** U3 R-I:241 deklaruje `with_store_lock(entry_key)`; U2 §15.9 a U4 §15.1 odovzdávajú `row`.
- **Import:** U3 R-J3:253 neposiela `replacements:`, požadované U4 §15.1; parameter chýba aj v R-I.
- **Rozhodnutia:** U4 §15.2 očakáva `decisions[g] = :overwrite`; U3 R-J2 používa `{action:, seen_fingerprint:}`.
- **Obnova:** U5 R-J1:288 volá `restore_backup!` bez `seen_fingerprint:`, napriek D15 a U2 §15.10.
- **Neznáme použitie:** U5 R-D3 posiela `:unknown`; U3 R-N1:292 na hodnote volá `.include?`.
- **Neznámy diff:** U3 R-N1 povoľuje `diff: :unknown`; U5 R-C2 deklaruje iba mapu a neurčuje túto vetvu.
- **Výsledok konfliktu:** U5 R-N:323 stále hlási úspech s ponechaním prílohy; U4 §15.2 predpisuje blokovanie alebo náhradu.

**C — Nové BLOCKERy**

1. **Obnova zálohy nepredpisuje obnovu archivovaných príloh.** U4 §15.1 už povoľuje náhrady, ale obnova podľa U2 §15.2/15.4 vracia dokumenty a značky; starý katalóg môže zostať s novým PDF/SKM.
2. **Potvrdenie nechráni zmeny príloh.** U2 §15.10 výslovne vylučuje prílohy z `seen_fingerprint`, hoci rozhodnutie povoľuje ich prepísanie; neskoršia zmena nezneplatní potvrdenie.
3. **Prvé doplnenie digestu prijme neoverený náhľad ako základ.** U4 §15.4 výslovne potláča varovanie pri chýbajúcom kľúči, čím môže následné prevzatie potichu prepísať vlastný náhľad.

**Verdikt:** Blok zatiaľ nemožno považovať za pripravený do zásoby. Treba zosúladiť rozhrania, doplniť doložené regresné scenáre a uzavrieť uvedené riziká príloh.

