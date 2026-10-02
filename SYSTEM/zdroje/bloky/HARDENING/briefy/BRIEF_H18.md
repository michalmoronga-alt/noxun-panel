> Kópia zadania zo scratchpadu (2.10.2026); autorita = súbory v priečinku bloku.

# Brief — dávka H18 · Inspector ukáže skutočne použitý set závesov (D-149) — blok 9 HARDENING

Si implementátor dávky **H18**. Pracuj z **čerstvého `origin/main`** (po mergi predchádzajúcej dávky bloku — over v `git log`). Vetva **`fix/h18-zavesy-v-inspectore`**,
verzia = ďalší patch po aktuálnom maine.

## Zdroj (autorita v tomto poradí)
1. `../PACKAGE_H18.md` — **§15 (audit
   zapracovaný) a potvrdenie orchestrátora na konci majú prednosť**, potom §6 požiadavky (R0 golden PRED zásahom: `source_pred.json`, `cena_zavesy.json`, payload),
   §7 testy (T0–T5, M1–M23), §11 uzáver. Surový audit `../AUDIT_H18_raw.md`; sondy `sonda_h18*.rb/js` sú pomôcka.
2. Rozhodnutie Michala **3A** (2.10.): Inspector ukáže skutočne použitý set — **výroba, nákup, rozpočet, ponuka, VEPO sa NEMENIA** (golden bez regenerácie).
   **Q1/Q2** (vrátenie skrinky „na projekt", F1 výber pri krídle) — ak Michal neodpovedal, H18 nič nemaže a nemení zápis; F1 = samostatná dávka H18b.
   **Potvrdenie orchestrátora 3.10. má prednosť: implementácia H18b čaká na Michalovu odpoveď Q2.**
3. **Krok 0:** package je z mainu `466b8b4c` — over čísla riadkov (`hardware_sets.rb` resolver, `payloads.rb`, `actions_hardware.rb`, `hardware.js`) proti aktuálnemu mainu
   (medzitým H7b, H11a, H15a/b, H16 — H15 presunula seed dáta kovania do `*_seed.rb`). Rozdiel meniaci zámer → STOP a otázka.

## Prenesenie do repa
- `PACKAGE_H18.md` + `../AUDIT_H18_raw.md` → `SYSTEM/zdroje/bloky/HARDENING/`; tento brief → `briefy/BRIEF_H18.md` s úvodným riadkom „> Kópia zadania zo scratchpadu
  (2.10.2026); autorita = súbory v priečinku bloku." a relatívnymi odkazmi. D-149 (tento nález) a D-150 (F1, → H18b) zapíš do `SYSTEM/DOGFOODING.md` (D-149 hneď do
  `SYSTEM/archiv/DOGFOODING_vyriesene.md` ako vyriešené týmto PR — plný text + riadok navrch INDEXU; D-150 ostáva otvorené v DOGFOODING).

## Trieda, testy, uzáver
- Audit-povinná (kontrakt payloadu Ruby↔JS, jadro resolvera) + **výrobná/cenová (konzervatívne)** → **predrecenzia povinná** (recenzent dostane aj
  `--color-moved=zebra` kvôli presunu reťaze resolvera). In-SU **nie je brána, kým sa nemení telo `handle_set_hardware_set` ani iný zápis do modelu** — ak sa mení, beh je brána.
- `ruby tests/run_all.rb`, **každá JS sada zvlášť**, encoding guard; golden v 1. commite na starom kóde, potom bez regenerácie (zmena fixtúry = nález → STOP).
- **Fotky:** `scripts\ui_foto.ps1 -Record` (mení sa payload) — kontext Kovanie; cesty do reportu.
- Uzáver podľa CLAUDE.md: bump patch (VERSION 2×) + všetky `?v=` · odseky `hardware_sets` v `docs/architecture/hardware.md` a Kontext Kovanie v `ui-lifecycle.md` na
  mieste · STAV prepísať (max 80 riadkov / 12 kB) · KRONIKA navrch · PLAN riadok H18 ✅ + `PR #?`.
- Commity selektívne, trailer `Co-Authored-By: Codex <noreply@openai.com>` podľa AGENTS.md. CRLF súbory cez Edit/Python `newline=''`, nie `sed -i`; mutačné behy so
  zálohou a kontrolou čistého stromu na konci; `gh` texty s úvodzovkami cez `-F body=@súbor`.
- **Po pushi STOP** — PR neotváraj; vráť report (hlava, riadky kódu, testy, mutácie, fotky, či sa menil zápis do modelu, odchýlky). PR na pokyn orchestrátora po
  predrecenzii. **Nemerguj.** Nemeň CLAUDE.md.
