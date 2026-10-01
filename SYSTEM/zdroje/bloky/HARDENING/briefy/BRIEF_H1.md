> Kópia zadania zo scratchpadu orchestrátora, 1.10.2026; package/audity dávky sú v nadradenom priečinku.

# Brief — dávka H1 · pravidlá čítania pre agentov (blok 9 HARDENING PO V1) — dokumentačná dávka

Si implementátor dávky **H1** bloku 9 · HARDENING PO V1. Pracuj z **čerstvého `origin/main`** (obsahuje štart bloku, PR #432 — priečinok
`SYSTEM/zdroje/bloky/HARDENING/`). Vetva **`docs/h1-pravidla-citania`**. **Plugin (`noxun_engine/`) sa NEMENÍ** — VERSION ani `?v=` sa nebumpujú.

## Zdroj a autorita

- Blok: `SYSTEM/PLAN.md` blok 9 (tabuľka dávok) + `SYSTEM/zdroje/bloky/HARDENING/ROZHODNUTIA_MICHALA_2026-10-01.md` (výsledok triedenia, odpovede B-08/B-09).
- Plné znenia položiek: `SYSTEM/zdroje/bloky/HARDENING/TRIEDENIE_krizovy_audit_v1.html` (B-01, B-04, B-08, B-09) a dôkazy so súbor:riadok v
  `CROSS_AUDIT_A4_CLAUDE_NOVY_AGENT.md` (**CN-01, CN-05, CN-06, CN-07, CN-10, CN-11, CN-12**) a `CROSS_AUDIT_A3_CODEX_SOL.md` (**CS-02**). Čísla riadkov
  v audite sú k 1.10. — pred úpravou si ich over.
- Povinné čítanie podľa `CLAUDE.md`: riadok **workflow · pravidlá práce** (`SYSTEM/WORKFLOW.md` — len časti, ktoré meníš/odkazuješ) + `SYSTEM/README.md`
  (mapa autorít). Celé `ui-lifecycle.md` ani celú KRONIKU **nečítaj** — tejto dávky sa netýkajú (Grep stačí).

## Čo spraviť (4 položky)

### B-01 · povinné čítanie po kapitolách (CN-01, CS-02, CN-07, CN-12)
1. Tabuľka „Povinné čítanie" v `CLAUDE.md`: pri každom súbore nad ~50 kB uveď **kapitolu / odsek / kotvu** (a ako ju nájsť Grepom), nie celý súbor.
   Riadok **UI**: „`docs/UI_DIZAJN.md` §1–§3 (norma) + odsek dotknutej sekcie Štúdia alebo kontextu Inspectora v `ui-lifecycle.md` (Grep podľa nadpisu)"
   + cache-bust + vertikálny priestor. **`ui-lifecycle.md` a UI_DIZAJN NEREŠTRUKTURALIZUJ** — to je dávka H5 (B-02/B-05); tu len smerovanie.
2. Do riadku UI doplň **záväzný kontrakt Kusovníka** `SYSTEM/zdroje/ui20/UI20_KONTRAKT.md` (Š2 stĺpce) — pri zmene stĺpcov/sekcií Štúdia (CN-07).
3. Riadok **novú dávku · plánovanie**: „podobná funkcia už bola → `SYSTEM/archiv/bloky/<BLOK>/` (ROZHODNUTIA_*, FAKTY_Z_KODU_*, PACKAGE_*) a
   `SYSTEM/archiv/<BLOK>_ZAVER_*`". Riadok **bugfix / „prečo"**: najprv priečinok bloku, KRONIKA a DOGFOODING_vyriesene **len Grepom** podľa ID dávky/D-čísla (CN-12).
   Rovnako zosúlaď `SYSTEM/README.md` (poradie čítania).
4. Pridaj vetu o **rozpočte čítania**: povinné čítanie jednej dávky orientačne **≤ 150 kB**; keď by bolo viac, orchestrátor dá do briefu výťah/kotvy.

### B-04 · PLAN.md bez hotových blokov (CN-06, CN-10)
1. Hotové bloky a hotové časti (**1b, 1d, 1e, hotové časti bloku 4 a bloku 6** — over, čo je naozaj hotové) presuň **plným textom** do
   `SYSTEM/archiv/ROADMAP_hotove_etapy.md` (vzor existujúcich záznamov v tom súbore). **Nič otvorené sa nesmie stratiť:** každú ešte otvorenú položku
   (D-číslo, R-číslo, odkaz na AUDIT_REGISTER…) ponechaj v PLAN v živom bloku alebo v zásobníku „Po V1". Do PR popisu daj tabuľku
   **presunuté / ponechané (kam)**. R-13, R-37, R-35 sú teraz dávky **H8–H10 bloku 9** — v zásobníku/bloku 4 ich nahraď odkazom na blok 9.
2. Zastarané vety (napr. nadpis 1b „pred blokom KOVANIE", „revízia sa ešte NEKONALA") zmiznú s presunom.
3. **Duplicity zásobníka** zlúč (horná rohová 2×, D-48 3× — over v aktuálnom texte).
4. **Trvalé pravidlá na jednom mieste** (CN-10): „vertikálny priestor panela je vzácny" → autorita **`docs/UI_DIZAJN.md` §1**, ostatné miesta (CLAUDE.md,
   ARCHITEKTURA.md, PLAN, V1_VIZIA) len odkaz. „Hranica TYP vs ŠABLÓNA vs PARAMETER" → autorita **`SYSTEM/STANDARD.md` §4.2** (tam, kde sa typy definujú),
   v PLAN/POJMY len odkaz. „Pravidlo pre postrehy (Michal)" ponechaj v PLAN (je to pravidlo plánovania), ak nemá prirodzenejší domov — rozhodni a uveď.
   Text pravidiel **nemeň významovo** — len presun + odkazy.
5. **Guard test strop veľkosti PLAN** (vzor: guard pre STAV — max riadkov a kB; nájdi ho v `tests/pure/`). Strop nastav na ~2× veľkosti živého PLANu
   po uprataní (zaokrúhlene) a hodnotu + dôvod uveď v PR. Doplň do hlavičky PLAN vetu o strope (ako má STAV).
6. Oprav všetky odkazy na presunuté kotvy/nadpisy (Grep celé repo vrátane `.claude/skills/`, `docs/`, `tests/`); `test_docs_navigacia.rb` a ostatné guardy zelené.

### B-08 · STAV po dokumentačnom PR (CN-05) — Michal SÚHLASIL
1. Nové pravidlo: **dokumentačné PR, ktoré mení stav bloku alebo poradie prác, prepíše v `SYSTEM/STAV.md` sekcie „Robí sa" a „Ďalší krok"**
   (sekcia „Stav" s verziou a VERSION sa nemenia; nahradený text ide ako pri kódovej dávke do KRONIKY — posúď, či stačí záznam dávky). Uprav všade,
   kde je dnešné „dokumentačné PR STAV nemenia": `CLAUDE.md` (Verzia a uzáver + Checklist dokumentačného PR), hlavička `STAV.md`, `SYSTEM/README.md`,
   `SYSTEM/WORKFLOW.md` a skilly v `.claude/skills/`, ak to opakujú (Grep).
2. **Hneď ho aplikuj:** prepíš v STAV „Robí sa" a „Ďalší krok" podľa skutočnosti — smoke bloku CENY **PASS 30.9.** (PR #431), **V1 hotové**, beží
   **blok 9 · HARDENING PO V1** (štart PR #432, dávky H1…H17, H6/H7 čakajú na mockup), R-13/R-37/R-35 = H8–H10, test na reálnej zákazke po V1.
   Oprav aj vetu v sekcii Stav „Pred uzáverom V1 ostávajú… R-13 → R-37 → R-35" a „smoke čaká" v prvom riadku (fakticky: smoke PASS). Verziu v0.17.0 nemeň.
   Limit STAV (80 riadkov / 12 kB) musí platiť.

### B-09 · hranice triedy dávky s príkladmi (CN-11) — Michal SÚHLASIL s doplnením príkladov
K definícii **výrobnej/cenovej dávky** a k hranici **„nový ovládací prvok v UI"** v `CLAUDE.md` (a v skille `predrecenzia`, ak ju opakuje) doplň
krátke príklady hraníc. Znenie príkladov (rozhodnutie orchestrátora v rámci schváleného B-09 — v PR označ, že ich Michal môže upraviť):
- **Výrobná/cenová ÁNO:** zmena vzorca, rozmeru, počtu, hrany; zmena zoskupenia riadkov kusovníka (`row_key`) alebo obsahu/stĺpcov exportu (VEPO,
  CSV/XLSX kusovníka, nákup, ponuka); zmena ceny, sadzby alebo **čísla, podľa ktorého sa v okne objednáva či cenotvorí** (množstvo, počet platní, cena
  položky) — aj keď sa výpočet nemení a mení sa len to, čo okno ukazuje.
- **Výrobná/cenová NIE:** nový **čítací** stĺpec alebo popis v okne bez zmeny `row_key`, zoskupenia a exportov (precedens `rows_with_roles`); preklad
  nadpisov a popiskov bez zmeny čísel a CSV; farba, ikona, rozloženie.
- **Nový ovládací prvok ÁNO:** nové tlačidlo, prepínač, pole, rozbaľovačka alebo položka menu, ktorá niečo **spúšťa alebo zapisuje** (model, súbor,
  nastavenia, katalóg).
- **Nový ovládací prvok NIE:** ďalšia voľba v existujúcom zozname s rovnakým správaním ako susedné (napr. ďalší stĺpec v menu „Stĺpce"); presun
  existujúceho tlačidla alebo jeho zmena na ikonu bez zmeny akcie.
Drž to krátko (pár riadkov), bez duplikovania na viacerých miestach — jedna autorita (CLAUDE.md), inde odkaz.

## Testy a DoD
- `ruby tests/run_all.rb` zelené (guardy dokumentov, navigácia, nový guard PLAN) + encoding guard; JS sady netreba meniť, ale spusti ich (bash:
  `for f in tests/js/test_*.js; do node "$f" || exit 1; done`) — nesmú spadnúť.
- `git diff --stat origin/main...HEAD` **bez `noxun_engine/`**.
- Guard nového stropu PLAN musí na dnešnom (neupratanom) PLANe padať a po uprataní prechádzať — over a uveď v PR.

## Uzáver (dokumentačné PR)
- KRONIKA: odsek navrch „Záznamy dávok" (čo H1 zmenilo, zoznam presunov, nové pravidlá B-08/B-09).
- PLAN blok 9: riadok **H1** s ✅ a `PR #?`.
- STAV podľa B-08 vyššie (verzia bez zmeny).
- Commity selektívne, správa cez súbor, trailer `Co-Authored-By` so skutočným modelom tvojej session.
- **Docs-only → predrecenzia sa nerobí** → po pushi rovno PR (kvótová brána `-Gate codex`; PR popis po slovensky cez `--body-file`: čo sa mení pre
  agentov a Michala, tabuľka presunov, príklady B-09 označené ako návrh orchestrátora) → hneď commit s číslom PR (len číslo) → push → report.
- **Nemerguj.** Michal spí — pri nejasnosti nevymýšľaj pravidlá navyše; bezpečnejšia vratná voľba len ak nemení význam pravidiel (označ v PR a reporte),
  inak otázka v reporte.
