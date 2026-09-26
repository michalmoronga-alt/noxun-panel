# Blok 7 · KONŠTRUKCIA K1+K2 — rozhodnutia a vstupy pre packages (27.9.2026)

> **Autorita bloku do vzniku packages.** Drží rozhodnutia Michala a **prijaté požiadavky** z krížového auditu a z review PR #398/#399 — stručne,
> bez implementačných vzorcov (tie vzniknú v package každej dávky a prejdú jej auditom návrhu). Zdroje v tomto priečinku: fakty z kódu
> [FAKTY_Z_KODU_2026-09-26.md](FAKTY_Z_KODU_2026-09-26.md) · zadanie auditu [CROSS_AUDIT_PROMPT_2026-09-27.md](CROSS_AUDIT_PROMPT_2026-09-27.md) ·
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
| M6 | Lišty vo výstupoch | **jeden riadok, 2 ks, „Chrb HD"**, páska na jednej dlhej hrane (kus sa pri montáži len otočí) | 26.9. |
| M7 | Šablóny | blok pridá **len „Chladničkovú"** (komín 50, očakáva chladničku) | 26.9. |
| M8 | **D-143** chrbát v drážke | dnes do nárezu vnútorný rozmer (horná 600 × 720 → 564 × 684); presne by bolo +9 mm na stranu s drážkou, ale pre V1 **do nárezu plný rozmer skrinky** (šírka × výška od spodku dna po vrch — horná **600 × 720**), dielňa zreže; model ukazuje chrbát v drážke | 26.9. |
| M9 | Návrhy orchestrátora bez námietky | nika spotrebiča sa meria **po posunutý chrbát** · výsuvy zásuviek sa pri komíne **skrátia samé** (zamknutý výsuv, ktorý sa nezmestí → RED ako dnes) · stará šablóna bez komína komín skrinky nechá · Inspector **bez nových skupín** + **bokorys v rohu náhľadu** · semafor bez nových prahov (varujú dôsledky) | 26.9. |
| M10 | Mimo bloku | rohové spoje per strana, poldrážka, „bez dielca", K3 rohová, šablóny Rúrová a Drezová, vetranie a výrezy, **rúrové skrinky** (rúra chce iný detail — bez chrbta za rúrou a vetranie, nie komín) | 6.9. + 26.9. |

## 2 · Prijaté požiadavky pre packages (z auditu a review)

**KON-0 · D-143 — rozmer do nárezu** (výrobná, audit-povinná, na mockup nečaká)
- Nové **voliteľné pole „rozmer do nárezu" (`cut_size`)** na dielci; rozmer v modeli a geometria sa **nemenia** (vzhľad, kontrola olepov a smer dekoru
  stoja na rovnosti výrobného rozmeru a geometrie). Chrbát v drážke: plný rozmer skrinky, nikdy menší než geometria.
- Rozmer do nárezu číta **každý výrobný výstup**: kusovník a jeho zlučovanie, kontrola formátu platne, VEPO, plocha a cena, karta dielca; hmotnosť
  ostáva z geometrie; uplatní sa pred otočením podľa dekoru. Chýbajúci údaj = geometria; **poškodený údaj zastaví výrobné výstupy**.
- Chrbát v drážke **s ručným olepením**: rozmer do nárezu sa neuplatní a chrbát **zastaví výrobné výstupy** (RED s dôvodom), kým sa olepenie alebo
  typ chrbta nezmení.
- **Staršia verzia pluginu** nesmie vydať malý chrbát → zvýšenie verzie configu (`CONFIG_SCHEMA` 19).
- **Skrinky postavené pred opravou:** chrbát v drážke v skrinke s configom pod verziou 19 je **zastaraný** (určuje verzia configu, nie prítomnosť
  rozmeru do nárezu) → Kontrola RED s výzvou prestaviť a **výrobné exporty stoja**, kým sa neprestaví; hromadnú prestavbu rozhodne audit KON-0.
- **Odpojený / vytiahnutý chrbát** s rozmerom do nárezu: predvolene odpojenie odmietnuť (starší plugin by ho vydal malý) — rozhodne audit KON-0.
- Rozmer do nárezu zapísať do **STANDARD §8.2**.

**KON-A · K1 odsadenia + D-144** (výrobná, audit-povinná, `CONFIG_SCHEMA` 20)
- Pri **komíne 0** sa nesmie zmeniť nič (golden plány) — okrem opravy D-144; pri komíne > 0 majú boky plnú hĺbku a dno, strop a zadná výstuha
  končia o komín skôr. Pri naloženom chrbte bez komína ostáva dnešné skrátenie tela o hrúbku chrbta.
- **Minimum komína podľa účinného typu chrbta** (v drážke viac než pri naloženom; vložený, lišty a bez chrbta bez minima; skrytá hrúbka chrbta sa
  nepočíta) a **voľný vetrací kanál podľa typu chrbta** (pri bez chrbta sa neukazuje) — presné hodnoty v package.
- **Zapustenie** platí pre plný strop aj prednú výstuhu; výstuhy, ktoré sa nezmestia: orezanie s upozornením len keď výsledok ostane platný, inak
  odmietnutie; rovnako pri zmene hĺbky ťahaním (scale) — s hláškou a jedným krokom Späť.
- Nohy podľa zadnej hrany dna; box niky chladničky sa neorezáva.
- Šablóny: nové zapisujú predvoľby výslovne, „zachovaj hodnotu skrinky" len keď kľúč v starej šablóne chýba. JS zrkadlá a predvoľby v tej istej dávke.
- **D-144:** oprava len pri výstuhách na výšku vyšších než hrúbka korpusu (horná hrana chrbta = nižšia z dnešnej a novej); skrinky postavené pred
  opravou s touto kombináciou sú **zastarané** (RED + výrobné exporty stoja, kým sa neprestavia); **odpojený / vytiahnutý starý chrbát** z takej
  skrinky treba odmietnuť alebo zmigrovať, aby po prestavbe skrinky nešli do VEPO oba chrbty (review #399 kolo 2).

**KON-B · K2 chrbát z líšt** (výrobná, audit-povinná, `CONFIG_SCHEMA` 21, BuildPlan 6, ABS seed 5)
- Dve roly líšt (horná a dolná) kvôli viditeľnej hrane, obe s páskou na jednej dlhej hrane; **jeden spoločný názov v builderi** a VEPO skratka
  mapovaná **priamo na „Chrb HD"** (review #399 kolo 2) — kusovník v Štúdiu aj VEPO tak nesú jeden názov.
- Vnútro pred lištami v celej výške; horná lišta pod stropom alebo výstuhami; zlučovať len výrobne zhodné kusy (lišta 100 a výstuha na výšku 100
  z rovnakého materiálu padnú do jedného riadku).
- Pravidlo olepu pre nové roly sa doplní aj na existujúcich PC (seed); materiál chrbta pri lištách sa správa ako „bez chrbta"; JS zrkadlá v tej istej dávke.

**KON-C · bokorys** (UI, bez auditu) — malý rez zboku v rohu náhľadu pri komíne, zapustení alebo lištách; kóty a voľný kanál podľa typu chrbta.

**KON-D · Chladničková** (audit-povinná — knižnica šablón STD 7) — jednorazový seed (neprepíše vlastnú rovnomennú šablónu, neobnoví zmazaný seed);
rozmery rozhodne Michal (návrh 600 × 2100 × **610**: vnútro 560 pre niku vstavanej chladničky; pri 580 by vnútro bolo 530 < 550); na šablóne veta,
že vetracie otvory v sokli a hore rieši stolár.

## 3 · Zamietnuté a bez akcie

Rozvoľniť rovnosť výrobného rozmeru a geometrie · dopočítať rozmer až pri výstupe (druhý zdroj pravdy) · zväčšiť geometriu chrbta (prerazil by
boky) · prebrať cudziu referenčnú rovinu komína (Mozaik) · tabuľky výsuvov per systém (mimo bloku) · orezávať box niky.

## 4 · Otvorené otázky na Michala (s mockupom)

1. Rozmery Chladničkovej (návrh 600 × 2100 × 610 — vnútro 560, komín 50).
2. D-144: používaš vložený chrbát alebo chrbát v drážke s výstuhami na výšku? Ak áno, oprava ide skôr.
3. Minimum komína podľa typu chrbta (v drážke 10 mm + hrúbka chrbta, pri naloženom hrúbka chrbta, inak bez minima) — v poriadku?
4. Po KON-0 musí mať aj Lucia hneď novú verziu (jej starší plugin zákazky z tvojho PC neprestaví ani nevyexportuje — zámer).
5. Mockup: forma bokorysu, zobrazenie „Do nárezu" na karte dielca, návrhy navyše.
