# Blok 7 · KONŠTRUKCIA K1+K2 — rozhodnutia a vstupy pre packages (27.9.2026)

> **Autorita bloku do vzniku packages.** Drží rozhodnutia Michala a **prijaté požiadavky** z krížového auditu, z auditu návrhu KON-0 a z review
> PR #398/#399 — stručne, bez implementačných vzorcov (tie vzniknú v package každej dávky a prejdú jej auditom návrhu). Zdroje v tomto priečinku:
> fakty z kódu [FAKTY_Z_KODU_2026-09-26.md](FAKTY_Z_KODU_2026-09-26.md) · zadanie auditu [CROSS_AUDIT_PROMPT_2026-09-27.md](CROSS_AUDIT_PROMPT_2026-09-27.md) ·
> surové výsledky [CROSS_AUDIT_GROK_2026-09-27.md](CROSS_AUDIT_GROK_2026-09-27.md) a [CROSS_AUDIT_CODEX_2026-09-27.md](CROSS_AUDIT_CODEX_2026-09-27.md).
> Pracovný koncept so vzorcami a podrobné tabuľky reconcile (tri kolá review PR #398 + kolo 1 PR #399) sú v histórii PR #399 (commit `b870179b`)
> a na vetve `docs/blok-konstrukcia` ako pracovné poznámky — **nie sú autoritou**; kde sa líšia od tohto súboru, platí tento súbor.

## 1 · Rozhodnutia Michala

| # | Téma | Rozhodnutie | Kedy |
|---|---|---|---|
| M1 | Komín vzadu (K1) | komín = o koľko sú dno a strop vzadu kratšie ako bok; **bežne ~50 mm**; jedna hodnota na skrinku, predvolene 0 | 6.9. + 26.9. |
| M2 | Komín + chrbát v drážke | drážka **len v bokoch**, na úrovni zadnej hrany dna a stropu; na dne a strope chrbát **presahuje** (je naložený na ich zadné hrany) | 26.9. |
| M3 | Zapustený strop (K1) | strop alebo predná výstuha začína za prednou hranou boku; dno sa neodsadzuje; **dolná aj horná** skrinka | 6.9. + 26.9. |
| M4 | Chrbát z líšt (K2) | dve vodorovné lišty z korpusu medzi bokmi (hore + dole), výška = parameter (návrh 100), ABS len na hrane viditeľnej zvnútra | 6.9. |
| M5 | Vnútro pri lištách | police, priečky a zásuvky končia pred lištami **v celej výške** skrinky | 26.9. |
| M6 | Lišty vo výstupoch | **jeden riadok, 2 ks, „Chrb HD"**, páska na jednej dlhej hrane (kus sa pri montáži len otočí); ak má skrinka aj výstuhy na výšku rovnakého rozmeru a materiálu, zlúčia sa s nimi do jedného riadku (výrobne ten istý kus) | 26.9. |
| M7 | Šablóna | blok pridá **len „Chladničkovú": 600 × 2100 × 560, komín 50 (dno 510), bez chrbta**, očakáva chladničku — tak ju Michal v praxi vyrába | 26.9. + 27.9. |
| M8 | **D-143** chrbát v drážke | dnes do nárezu vnútorný rozmer (horná 600 × 720 → 564 × 684); presne by bolo +9 mm na stranu s drážkou, ale pre V1 **do nárezu plný rozmer skrinky** (šírka × výška od spodku dna po vrch — horná **600 × 720**), dielňa zreže; model ukazuje chrbát v drážke | 26.9. |
| M9 | **Nika spotrebiča pri komíne** | **hĺbka niky sa pri komíne ráta z hĺbky boku**, nie po chrbát — technické listy kótujú min. hĺbku boku (napr. ≥ 550), chladnička zasahuje aj do priestoru komína (nohy sú ponorené hlbšie od zadnej hrany); overené praxou | 27.9. |
| M10 | Ostatné návrhy orchestrátora | výsuvy zásuviek sa pri komíne **skrátia samé** (zamknutý výsuv, ktorý sa nezmestí → RED ako dnes) · stará šablóna bez komína komín skrinky nechá · Inspector **bez nových skupín** · semafor bez nových prahov (varujú dôsledky) · **minimum komína podľa typu chrbta** (v drážke 10 mm + hrúbka chrbta, pri naloženom hrúbka chrbta, inak bez minima) | 26.9. + 27.9. |
| M11 | Mockup | **schválený 27.9.** — riadky v Inspectore, výstupy a karta dielca („Do nárezu 600 × 720" pod Hrúbkou), šablóna; **bokorys v náhľade NIE** (priestor panela) — neskôr lepší 3D náhľad (**D-145**, zásobník) | 27.9. |
| M12 | Mimo bloku | rohové spoje per strana, poldrážka, „bez dielca", K3 rohová, šablóny Rúrová a Drezová, vetranie a výrezy, **rúrové skrinky** (rúra chce iný detail — bez chrbta za rúrou a vetranie, nie komín), bokorys | 6.9. – 27.9. |

## 2 · Prijaté požiadavky pre packages (z auditov a review)

**KON-0 · D-143 — rozmer do nárezu** (výrobná, audit-povinná, `CONFIG_SCHEMA` 19; na mockup nečaká)
- Nové **voliteľné pole „rozmer do nárezu" (`cut_size`)** na dielci; rozmer v modeli a geometria sa **nemenia** (vzhľad, kontrola olepov a smer dekoru
  stoja na rovnosti výrobného rozmeru a geometrie). Chrbát v drážke: plný rozmer skrinky (dĺžka = šírka skrinky, šírka = výška od spodku dna po vrch).
- Rozmer do nárezu číta **každý výrobný výstup**: kusovník a jeho zlučovanie, kontrola formátu platne, VEPO, plocha a cena (aj plocha skrinky
  v Inspectore), karta dielca vrátane textov smeru dekoru, ktoré hovoria „výrobne"; hmotnosť ostáva z geometrie; uplatní sa pred otočením podľa dekoru.
  Chýbajúci údaj = geometria; **poškodený údaj zastaví výrobné výstupy**.
- Chrbát v drážke **s účinným olepením** (ručným alebo z pravidla olepu): rozmer do nárezu sa neuplatní a chrbát **zastaví výrobné výstupy**.
- **Jedna výrobná brána D-143:** všetky blokujúce dôvody idú jedným zoznamom do Kontroly (RED) **aj do tvrdého stopu vo všetkých štyroch exportoch**
  (VEPO, nákupný CSV, rozpočet XLSX, ponuka XLSX) — nestačí RED v Kontrole; test každý dôvod × každý export.
- **Staršia verzia pluginu** nesmie vydať malý chrbát → `CONFIG_SCHEMA` 19 (dopredná brána zastaví staršie PC).
- **Skrinky postavené pred opravou:** chrbát v drážke v skrinke s configom pod verziou 19 je **zastaraný** (určuje verzia configu, nie prítomnosť
  rozmeru do nárezu; čítať aj starý zápis režimu chrbta) → RED s výzvou prestaviť a výrobné exporty stoja; **hromadná prestavba** existujúcim
  mechanizmom (jedna operácia, jeden krok Späť), skrinky s odpojenými dielcami vymenovať a nechať blokované.
- **Samostatné chrbty** (odpojené, vytiahnuté, skopírované): nový chrbát v drážke nesie značku pôvodu a neolepený bez rozmeru do nárezu je chyba;
  **starý samostatný chrbát bez značky → ORANGE „over rozmer do nárezu"** (Michal 27.9.: samostatné chrbty nepoužíva). **Priznaný limit:** starší plugin
  rozmer do nárezu nepozná → pred prvým použitím aktualizovať obe PC.
- Rozmer do nárezu zapísať do **STANDARD §8.2**.

**KON-A · K1 odsadenia + D-144** (výrobná, audit-povinná, `CONFIG_SCHEMA` 20 — čísla schém podľa poradia mergov)
- Pri **komíne 0** sa nesmie zmeniť nič (golden plány) — okrem opravy D-144; pri komíne > 0 majú boky plnú hĺbku a dno, strop a zadná výstuha
  končia o komín skôr. Pri naloženom chrbte bez komína ostáva dnešné skrátenie tela o hrúbku chrbta.
- **Nika spotrebiča pri komíne = hĺbka boku** (M9); bez komína ostáva dnešné meranie po chrbát.
- **Minimum komína podľa účinného typu chrbta** (M10; skrytá hrúbka chrbta sa nepočíta) a **voľný vetrací kanál podľa typu chrbta** (pri bez chrbta sa neukazuje).
- **Zapustenie** platí pre plný strop aj prednú výstuhu; výstuhy, ktoré sa nezmestia: orezanie s upozornením len keď výsledok ostane platný, inak
  odmietnutie; rovnako pri zmene hĺbky ťahaním (scale) — s hláškou a jedným krokom Späť.
- Nohy podľa zadnej hrany dna; box niky chladničky sa neorezáva.
- Šablóny: nové zapisujú predvoľby výslovne, „zachovaj hodnotu skrinky" len keď kľúč v starej šablóne chýba. JS zrkadlá a predvoľby v tej istej dávke.
- **D-144** (Michal kombináciu nepoužíva — ostáva v KON-A): oprava len pri výstuhách na výšku vyšších než hrúbka korpusu (horná hrana chrbta = nižšia
  z dnešnej a novej); skrinky postavené pred opravou s touto kombináciou sú zastarané (RED + výrobné exporty stoja, kým sa neprestavia); starý
  samostatný chrbát z takej skrinky rovnako ako pri KON-0. **Rozmer do nárezu chrbta v drážke pri D-144** sleduje hornú hranu pod výstuhami — presne
  v package KON-A; do KON-A platí pravidlo KON-0 (plný rozmer), chrbát teda vyjde väčší a dielňa ho zreže, nie menší.

**KON-B · K2 chrbát z líšt** (výrobná, audit-povinná, `CONFIG_SCHEMA` 21 — podľa poradia mergov, BuildPlan 6, ABS seed 5)
- Dve roly líšt (horná a dolná) kvôli viditeľnej hrane, obe s páskou na jednej dlhej hrane; **jeden spoločný názov v builderi** a VEPO skratka
  mapovaná **priamo na „Chrb HD"** — kusovník v Štúdiu aj VEPO tak nesú jeden názov.
- Vnútro pred lištami v celej výške; horná lišta pod stropom alebo výstuhami; zlučovať len výrobne zhodné kusy (M6).
- Pravidlo olepu pre nové roly sa doplní aj na existujúcich PC (seed); materiál chrbta pri lištách sa správa ako „bez chrbta"; JS zrkadlá v tej istej dávke.

**KON-C · bokorys — VYPADLO** (Michal 27.9.: náhľad zatiaľ vôbec neimplementovať kvôli priestoru; neskôr lepší 3D náhľad — D-145 v zásobníku).

**KON-D · Chladničková** (audit-povinná — knižnica šablón STD 7) — **600 × 2100 × 560, komín 50 (dno 510), bez chrbta**, očakáva chladničku;
jednorazový seed (neprepíše vlastnú rovnomennú šablónu, neobnoví zmazaný seed); na šablóne veta, že vetracie otvory v sokli a hore rieši stolár.

## 3 · Zamietnuté a bez akcie

Rozvoľniť rovnosť výrobného rozmeru a geometrie · dopočítať rozmer až pri výstupe (druhý zdroj pravdy) · zväčšiť geometriu chrbta (prerazil by
boky) · prebrať cudziu referenčnú rovinu komína (Mozaik) · tabuľky výsuvov per systém (mimo bloku) · orezávať box niky · bokorys v náhľade (M11).

## 4 · Zodpovedané otázky (Michal 27.9.2026)

Rozmery Chladničkovej: 560 / 510, bez chrbta, nika z hĺbky boku (M7, M9) · bokorys nie (M11) · karta dielca „Do nárezu" pod Hrúbkou — áno (M11) ·
starý samostatný chrbát → ORANGE, samostatné chrbty nepoužíva (KON-0) · D-144 kombináciu nepoužíva → ostáva v KON-A · minimum komína podľa typu
chrbta — áno (M10). **Pripomienka:** po KON-0 musí mať aj Lucia hneď novú verziu (jej starší plugin zákazky z Michalovho PC neprestaví ani nevyexportuje — zámer).
