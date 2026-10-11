> Kópia zadania zo scratchpadu (2.10.2026); autorita = súbory v priečinku bloku.

# Brief — dávka H7 · názov zákazky na jednom mieste + nastavenia exportu v jadre + ochrana R-38 (A-05, C-07, R-38) — blok 9 HARDENING

Orchestrátor ti povie, ktorú časť robíš (**H7a** alebo **H7b**). Každá časť = samostatný PR z **čerstvého `origin/main`** (po mergi predchodcu).

| Časť | Vetva | Obsah | Trieda a brány |
|---|---|---|---|
| **H7a** · jadro + R-38 | `fix/h7a-nastavenia-exportu` | modul `core/export_settings.rb` (`ExportSettings`), ochrana R-38 (predikát tvaru, `write_gate`, `[status, reason]`), `name_pending?` + `ADOPT_RETRY` (SHA1), hlásenie zlyhania v okne Štúdia, veta nápravy po exportoch; poradie commitov: golden → ochrana na mieste → čistý presun → hlásenia → docs | audit-povinná + **výrobná/cenová** · predrecenzia povinná · **in-SU 1 beh = podmienka mergu** |
| **H7b** · UI hlavička | `feat/h7b-nazov-v-hlavicke` | názov v hlavičke Štúdia s editorom na mieste, pole PROJEKT preč, jantárová bodka + tooltip s menom súboru na 4 exportoch, veta po exporte, **`expect` povinný pri 4 exportoch (fail-closed)**, stav „neuložené k súboru" (Q2 predvolené áno), texty „zákazka" | nový ovládací prvok → predrecenzia povinná · nie výrobná pri parite mien · fotky `-Record` |

## Zdroj (autorita v tomto poradí)
1. [`../PACKAGE_H7.md`](../PACKAGE_H7.md) — **§17 > §16 > §15 > ostatné** (§17 = posledné spresnenia orchestrátora a potvrdenie D-bodov).
   Sonda §0 je z mainu `108c808c`; medzitým zmergovali H12d a H6a (a možno H6b/H6c) → **krok 0: over čísla riadkov a mená proti aktuálnemu mainu**
   (`studio_dialog.rb`, `studio.js`, `?v=`); rozdiel meniaci zámer → STOP a otázka.
2. Mockup [`../MOCKUP_H7_NAZOV_ZAKAZKY.html`](../MOCKUP_H7_NAZOV_ZAKAZKY.html) (s rámčekom PLATÍ) a rozhodnutia Michala
   v [`../ROZHODNUTIA_MICHALA_2026-10-01.md`](../ROZHODNUTIA_MICHALA_2026-10-01.md) (sekcia „Mockupy H6 a H7") — H7 všetko podľa odporúčania + R-38 áno.
3. Vzor ochrany súborov: H9/R-37 (`HardwareRules.write_gate`, `JsonFileStore.degraded?`, `preserve_valid_backup`) — rovnaká rodina, nie vlastný vynález.

## Len H7a navyše (prenesenie do repa)
- `PACKAGE_H7.md` → [`../PACKAGE_H7.md`](../PACKAGE_H7.md); surové audity [`../AUDIT_H7_raw.md`](../AUDIT_H7_raw.md),
  [`../AUDIT_H7_delta_raw.md`](../AUDIT_H7_delta_raw.md), [`../AUDIT_H7_delta2_raw.md`](../AUDIT_H7_delta2_raw.md) do toho istého priečinka; tento brief → `briefy/BRIEF_H7.md`
  s úvodným riadkom „Kópia zadania zo scratchpadu" a **relatívnymi** odkazmi.
- PLAN: riadok H7 rozdeliť na H7a/H7b (H7a ✅ + `PR #?`); AUDIT_REGISTER R-38 stav podľa výsledku.

## Testy, in-SU, fotky, uzáver
- `ruby tests/run_all.rb`, **každá JS sada zvlášť**, encoding guard; mutácie podľa §7 (+ §15–§17 doplnky). Golden mien a obsahu 4 exportov v 1. commite H7a,
  bez regenerácie (zmena fixtúry = nález). Goldeny H14 sa **neregenerujú** (H7b normalizuje presne vymenované fragmenty s počtom náhrad).
- **H7a in-SU:** `scripts\run_su_tests.ps1 -CloseWhenDone` na finálnej hlave (worktree nemá `_dev\ENGINEtests.skp` — skopíruj z hlavného checkoutu `_dev\`;
  `exit 2` = počkaj a znova; nikdy nezabíjaj SketchUp). Testy so súbormi nastavení **len nad sandboxom/kópiou**, nikdy nad živým `%APPDATA%\NOXUN\Engine\`.
- **H7b fotky:** `scripts\ui_foto.ps1 -Record` (mení sa payload) a over hlavičku v sekciách Kusovník, Nákup, Rozpočet, Ponuka; cesty do reportu.
- Uzáver podľa CLAUDE.md: bump patch (VERSION 2×) + všetky `?v=` · nový odsek modulu `export_settings` v správnom súbore `docs/architecture/` + riadok
  v `docs/ARCHITEKTURA.md` (guard) · dotknuté odseky (`outputs.md` production_core, `ui-lifecycle.md` Štúdio, UI_DIZAJN veta o „názov projektu") prepísať na mieste ·
  Grep tvrdení o `vepo_settings`/`project_names` v `docs/` a `SYSTEM/` · STAV prepísať (max 80 riadkov) · KRONIKA odsek navrch · PLAN ✅ + `PR #?`.
- Commity selektívne, správa cez súbor, trailer `Co-Authored-By` so **skutočným modelom tvojej session**.
- **Po pushi STOP** — PR neotváraj; vráť report (hlava, riadky kódu bez testov/docs, počty testov, mutácie, in-SU výsledok a hlava, fotky, odchýlky od package,
  otvorené otázky). PR na pokyn orchestrátora po predrecenzii. **Nemerguj.** Nemeň CLAUDE.md.
