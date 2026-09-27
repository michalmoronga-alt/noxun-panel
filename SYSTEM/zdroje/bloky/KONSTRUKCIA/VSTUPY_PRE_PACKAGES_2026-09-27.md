# Blok 7 · KONŠTRUKCIA K1+K2 — vstupy pre packages KON-A, KON-B, KON-D (27.9.2026)

> **Vstup, nie package.** Prijaté technické požiadavky z krížového auditu bloku, z auditu návrhu KON-0 a z troch kôl review PR #398/#399 pre dávky,
> ktoré ešte nemajú package. Pri písaní package dávky sa každá požiadavka overí proti aktuálnemu kódu a package prejde **auditom návrhu dávky** —
> až package je záväzný. Produktové rozhodnutia: [ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md); KON-0 má hotový package
> [PACKAGE_KON0_D143.md](PACKAGE_KON0_D143.md). Kde sa tento súbor líši od rozhodnutí Michala, platia rozhodnutia Michala.

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
jednorazový seed (neprepíše vlastnú rovnomennú šablónu, neobnoví zmazaný seed); **seed nesie aktuálnu verziu configu skrinky (`config_schema`)** —
inak by ho starší plugin prijal, neznámy komín zahodil a postavil dno hlboké 560 namiesto 510 (review PR #399 kolo 3); na šablóne veta, že vetracie
otvory v sokli a hore rieši stolár.
