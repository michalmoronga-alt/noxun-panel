# Brief — dávka H13 · mapa rozširovacích bodov + jedna tabuľka verzií dát (B-06, B-07) — blok 9 HARDENING

Si implementátor dávky **H13**. Pracuj z **čerstvého `origin/main`** (obsahuje H12a–c: register typov `core/cabinet_types.rb`, JS `NXTypes`). Vetva
**`docs/h13-rozsirovacie-body`**. Dokumentácia + **guard testy** (plugin `noxun_engine/` sa nemení → bez bumpu verzie; ak by guard vyžadoval zmenu kódu
pluginu, STOP a otázka).

## Zdroj
- Triedenie (`SYSTEM/zdroje/bloky/HARDENING/TRIEDENIE_krizovy_audit_v1.html`) B-06, B-07; dôkazy `CROSS_AUDIT_A4_CLAUDE_NOVY_AGENT.md` **CN-02, CN-03, CN-04**.
- Výsledok H12: `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H12.md` (§0 súpis miest vetvenia, §14 „čo odovzdať H13") + odseky `cabinet_types` v
  `docs/architecture/construction.md` a `NXTypes` v `ui-lifecycle.md`. Starý súpis: `SYSTEM/archiv/bloky/ROHOVA/FAKTY_Z_KODU_2026-09-27.md` §1.2, §2.6.

## Čo spraviť
### B-06 · kapitola „Rozširovacie body"
1. Nový súbor `docs/architecture/rozsirovacie-body.md` (nový riadok v rozcestníku `docs/ARCHITEKTURA.md` — guard to stráži; zaradiť do stropu veľkosti
   z H5a) so scenármi: **nový typ skrinky** (po H12: register + čo ešte ostáva mimo registra — over Grepom), **nová rola dielca**, **nový stĺpec Kusovníka**
   (UI20_KONTRAKT Š2, `row_key`, exporty — trieda dávky podľa B-09), **nová sekcia Štúdia**, **nové pravidlo kovania viazané na typ**. Pri každom: zoznam
   miest (súbor + funkcia/konštanta, **nie čísla riadkov**), registre a testy, ktoré stráži.
2. **Pasca závesov (CN-03):** pravidlo „Zavesenie na stenu" v seede `hardware_rules` platí len pre `cabinet_type: ['upper']` — nový visiaci typ (napr. horná
   rohová) by bez úpravy nemal závesné kovanie v nákupe ani cene. Zapíš ako výslovné upozornenie v scenári „nový typ" + **guard test**: každý typ
   s vlastnosťou `hangs` v registri musí byť pokrytý pravidlom zavesenia v seede (alebo byť v explicitnom zozname výnimiek s dôvodom).
3. **Guard test**, že registre menované v kapitole v kóde existujú (mená konštánt/modulov/funkcií — Grep v teste), aby kapitola nezastarala potichu.
### B-07 · jedna tabuľka verzií dát
4. Tabuľka „čo · kde (súbor + konštanta) · aktuálna hodnota · kedy zvýšiť · či je to zmena schémy (audit podľa CLAUDE.md)" — `CONFIG_SCHEMA` (22),
   BuildPlan `SCHEMA` (7), dosky `BOARD_CONFIG_SCHEMA`, ABS seed, šablóny STD, `BUDGET_STD`, katalóg materiálov `SCHEMA`, nastavenia dodávateľa, `Store::STD`,
   `dim_series` std, … (úplný zoznam Grepom). Umiestnenie: `SYSTEM/STANDARD.md` (nová sekcia) alebo `docs/architecture/model-a-identita.md` — vyber jedno
   miesto, ostatné dokumenty (STAV „Kompatibilita", CLAUDE.md) len odkaz. **Guard test** porovná tabuľku s hodnotami konštánt v kóde.
5. Zoznam zmien schém doplň len odkazom na KRONIKU/archív, neprepisuj históriu.

## Testy a uzáver
- `ruby tests/run_all.rb` zelené (nové guardy + navigácia + stropy), každá JS sada zvlášť, encoding guard; `git diff --stat` bez `noxun_engine/`.
- Guardy musia na úmyselne pokazenej kópii padať (negatívne testy).
- KRONIKA odsek navrch · PLAN riadok H13 ✅ + `PR #?` · STAV podľa B-08 (docs PR mení stav bloku; STAV max 80 riadkov — prepisuj, nepridávaj).
- Skopíruj tento brief do `SYSTEM/zdroje/bloky/HARDENING/briefy/BRIEF_H13.md`.
- Docs + testy → predrecenzia sa nerobí → po pushi PR sám (kvótová brána; exit 4 neblokuje), commit s číslom PR (cielene, nie hromadné nahradenie `PR #?` —
  ten reťazec je aj v texte pravidiel), report. **Nemerguj.**
