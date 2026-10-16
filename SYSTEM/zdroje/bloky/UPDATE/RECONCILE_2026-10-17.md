# Blok UPDATE — reconcile krížového auditu (17.10.2026)

> Syntéza orchestrátora z A2 Grok ([CROSS_AUDIT_A2_GROK.md](CROSS_AUDIT_A2_GROK.md)), A3 rešeršér web ([CROSS_AUDIT_A3_RESERS_WEB.md](CROSS_AUDIT_A3_RESERS_WEB.md)),
> A4 Claude kód ([CROSS_AUDIT_A4_CLAUDE_KOD.md](CROSS_AUDIT_A4_CLAUDE_KOD.md)); **A1 Codex** — 1. beh `gpt-6-astra` skončil limitom bez výstupu, znova na
> `gpt-6.1-sol` s úzkym zadaním (R12) → doplní sa sekcia „A1" nižšie. Rozhodnutia: [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md) (R1–R15).
> **Sonda na kóde (orchestrátor, 17.10., bez zápisu):** overené `materials_appearance.rb:182-184` (vzhľad sa pri zápise berie z disku, nie z payloadu — A4 B1),
> `appliance_catalog.rb:1411-1413` (seed spotrebičov = `SecureRandom.uuid` na každom PC — A4 B5), `demos/image_cache.rb:33-37` (meno fotky z URL deterministické),
> `cabinet_builder.rb:1770-1776` (neznámy materiál → UNI 16), `updater.rb:23,168,614-641` (leases bežiacich procesov). Všetko platí.

## 1 · Zhoda všetkých audítorov

- **Tvar je správny:** jeden správca + nemenné verzie + ukazovateľ zapísaný posledný; konfliktná vetva dvoch zapisovateľov zo 6.9. (`parent`, `supersedes`, rekonštrukcia manifestu) **odpadá**.
- **Disk nič nezaručuje** (poradie, atomický rename, zámky, mená konfliktných kópií — oficiálne nepopísané): verzia sa prevezme až keď je **celá a overená odtlačkami**; inak „synchronizácia ešte beží, skús neskôr", nie chyba.
- **Žiadna jednoduchšia natívna cesta** (Trimble Connect zdieľa `.skp`, nie AppData; Drive API = OAuth).
- **Prevzatie môže zmeniť čísla zákazky:** ceny a sadzby hneď pri prepočte Rozpočtu; ABS a hrúbka pri prestavbe; pravidlá a sety kovania sú chránené snapshotom; geometria sa sama neprepíše.

## 2 · Zapracované do konceptu (smer pre packages)

| Nález | Zdroj | Riešenie (smer, technické detaily až v package) | Dávka |
|---|---|---|---|
| Import cez bežný zápis Materiálov zahodí vzhľady | A4 B1 **BLOCKER** | per-store **prevzatie celého dokumentu** s bránami (posúdenie, dupláky, schéma), vrátane vzhľadov; `.skm` musí byť pred JSON | U2 |
| Zápis a čítanie samo pečiatkuje `std`, seed, normalizuje | A4 B2 | per-store kanonický export + prevzatie bez pečiatok a seed-merge | U2 |
| Falošné „lokálne zmeny" | A4 B3 | **R14 rovnaká verzia pluginu**; hash nad kanonickým exportom | U2/U3 |
| Prepis mení identitu záznamov, na ktoré ukazujú zákazky | A4 B5 **BLOCKER pre R4** | pred prepisom **zoznam zmiznutých a zmenených** záznamov, zvýraznené tie, ktoré používa otvorená zákazka; nič sa nemaže bez zoznamu (párovanie seed spotrebičov pri prvom pripojení **netreba — R16**) | U3/U5 |
| Stav v pamäti modulov a otvorené okná po prevzatí | A4 B6 | po prevzatí reset a nové posúdenie store-u, znovu poslať dáta oknám; **Aktualizovať odmietnuť pri druhom okne SketchUpu** (leases updatera) | U2/U5 |
| Záloha R4 nesmie byť `.bak` | A4 B7, A2 B4 | pomenovaná záloha ako riadok registra (`backup`), mimo synchronizácie | U3 |
| Závislosti katalógov pri preskočení | A4 B8 | skupiny v registri: {materiály, vzhľady, fotky, ABS} · {katalóg kovania, taxonómia, sety, pravidlá} · šablóny závisia od oboch; preskočenie = varovanie o závislých | U2/U5 |
| Prílohy spotrebičov odkazuje snapshot zákazky | A4 B9 | prílohy pri prevzatí **len pribúdajú**, lokálne sa nemažú | U3 |
| Určenie správcu „prvý, kto odošle" je v rozpore s R3 | A2 B1, A4 B11 | správcu založí **len výslovná akcia na Michalovom PC**; bez súboru správcu je Odoslať vypnuté na oboch | U3/U5 |
| Dočasné súbory v zrkadlenej zložke, prepis toho istého ukazovateľa | A2 B2, A3 FIX 2 | do H: len hotové nemenné súbory s jedinečným menom; ukazovateľ nesie číslo verzie; súrodenec s cudzím menom sa len ohlási | U3 |
| Dve okná u Michala odošlú naraz | A2 B3 | lokálny zámok odosielania + po zápise overiť, že ukazovateľ ukazuje na práve odoslaný súbor | U3 |
| Značky UNI | A2 B5, A4 B14 | po prevzatí Materiálov zapísať lokálne obe značky | U2/U3 |
| Okno pred prílohami | A2 B6 | okno (posledná dávka) až po prílohách | poradie |
| Rozlíšiť „H: chýba" / „koreň prázdny alebo sa synchronizuje" / „v poriadku" | A3 FIX 3, A2 B7 | prázdny koreň ≠ zmazaná knižnica; časový limit ostáva (vzor okna O plugine, presunúť do core — A4 B13) | U3 |
| Mená súborov na Disku | A3 FIX 4 | ASCII, krátke (verzia/odtlačok), nie podľa názvu dekoru | U3 |
| Oznámenie pri štarte môže zmiznúť bez reakcie | A3 FIX 5 | stav vždy aj v O plugine; `on_accept` len otvorí okno | U5 |
| Názov zákazky pri otvorení = zápis do modelu + undo | A4 B12, A2 B8 | zapísať pri prvej zmene/uložení alebo transparentne; rieši audit U1 | U1 |
| Fotky dekorov | A4 A6 vs. A2 A6 | **R15: cez Disk** ako prílohy verzie (len fotky, na ktoré katalóg odkazuje); doťahovanie z Demosu ostáva ako doplnok | U4 |
| Správanie Disku overiť empiricky | A3 NOTE 2 | **sonda na oboch PC** pred zmrazením package U3 (sada súborov + ukazovateľ, sledovať poradie, oneskorenie, konfliktné kópie) | pred U3 |

## 3 · Rez dávok po reconcile

| Dávka | Obsah | Trieda / brány |
|---|---|---|
| **U1 · Názov zákazky v .skp** | slovník `NOXUN` v modeli; starý záznam podľa cesty sa prevezme pri prvej zmene/uložení; hlavička Štúdia a exporty čítajú model | Ť · `codex-audit` · predrecenzia · in-SU · export test |
| **U2 · Prevzatie a export per knižnica** | vynútený register, kanonický export + prevzatie celého dokumentu s bránami (vrátane vzhľadov), reset stavu v pamäti, skupiny závislostí, záloha a lokálny stav v registri, rovnosť verzie | Ť · `codex-audit` · predrecenzia (**mení správanie** — nie refaktor) |
| **U3 · Jadro synchronizácie** | čistý modul: verzia ako priečinok s manifestom a odtlačkami, ukazovateľ posledný, celistvosť, história 5 + návrat, správca, lokálne zmeny, prílohy len pribúdajú, zámok odosielania, druhé okno, časový limit v core | Ť · `codex-audit` (nový modul) · predrecenzia · **pred package sonda Disku na oboch PC** |
| **U4 · Prílohy a fotky dekorov** | vzhľady, náhľady (kopírovať podľa obsahu), listy spotrebičov, fotky dekorov ako prílohy verzie; `textures/` → zdieľané podľa R15 (zmena pripnutej zdieľanej množiny) | Ť · `codex-audit` · predrecenzia |
| **U5 · Okno O plugine** | riadky per katalóg, Odoslať / Aktualizovať, R4 so zoznamom zmien a použitých záznamov, história a návrat, správca, oznámenie pri štarte, banner R13 v oknách knižníc | S/Ť · predrecenzia · in-SU · **smoke na oboch PC** |

**Odhad 5 PR** (A2: 5; A4: 4 + 1 pri rozdelení U2). Poradie: U1 kedykoľvek (nezávislá) · U2 → U3 → U4 → U5.

## 4 · Otvorené body pre Michala

O1 (prvé pripojenie Lucie) a O2 (cenník) uzavreté 17.10. — R16, R17. Ďalšie body „návrh — potvrdí Michal" nesie mockup.

## A1 · Codex `gpt-6.1-sol`

*(doplní sa po behu po resete okna 17.10. 05:16)*
