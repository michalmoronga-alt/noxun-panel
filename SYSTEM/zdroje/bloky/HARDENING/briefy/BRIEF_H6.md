# Brief — dávka H6 · priestor v Inspectore (D-01, D-02, D-05) — blok 9 HARDENING

Orchestrátor ti povie, ktorú časť robíš (**H6a**, **H6b** alebo **H6c**). Každá časť = samostatný PR z **čerstvého `origin/main`** (po mergi predchodcu).

| Časť | Vetva | Obsah (package §6) | Predrecenzia |
|---|---|---|---|
| **H6a** · nápovedy, spodok, status | `feat/h6a-napovedy-spodok` | O1 (tlačidlá dole vedľa seba, „Uložiť šablónu"), O2 A, O3 B, O4, O5, O8, O13 | podľa pokynu orchestrátora |
| **H6b** · lišty sektorov a súhrny | `feat/h6b-listy-suhrny` | O6, O7, O9, O12, súhrny skupín Kovania | povinná |
| **H6c** · kóty náhľadu | `feat/h6c-koty-nahladu` | O10, O11 (+ ďalšie texty v mm z §0) | povinná |

## Zdroj (autorita v tomto poradí)
1. `C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE\bec8118a-40cf-4c0b-9a3e-af1bf4f85fdf\scratchpad\HARDENING\PACKAGE_H6.md` — **§15 (potvrdenie
   orchestrátora) má prednosť**, potom §6 požiadavky tvojej časti, §7 testy, §11 uzáver. Sonda §0 je z mainu `108c808c` — medzitým mohli zmergovať iné dávky
   (H12d mení `part_card.js`/payload karty dielca) → **krok 0: over čísla riadkov a mená proti aktuálnemu mainu**; rozdiel meniaci zámer → STOP a otázka.
2. Rozhodnutia Michala `…\scratchpad\HARDENING\ROZHODNUTIA_H6_H7_2026-10-02.md` (O1 a O3 sú **odchýlky od mockupu**).
3. Mockup `…\scratchpad\HARDENING\MOCKUP_H6_INSPECTOR.html` — vizuálny cieľ; kde sa líši od rozhodnutí, platia rozhodnutia.

## Len H6a navyše (prenesenie do repa)
- Package `PACKAGE_H6.md` → `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H6.md`; tento brief → `SYSTEM/zdroje/bloky/HARDENING/briefy/BRIEF_H6.md`.
- Obsah `ROZHODNUTIA_H6_H7_2026-10-02.md` ako **nová sekcia na koniec** `SYSTEM/zdroje/bloky/HARDENING/ROZHODNUTIA_MICHALA_2026-10-01.md`.
- Oba mockupy (`MOCKUP_H6_INSPECTOR.html`, `MOCKUP_H7_NAZOV_ZAKAZKY.html`) do `SYSTEM/zdroje/bloky/HARDENING/` s rámčekom **„platí"** hneď pod nadpisom
  (dátum 2.10.2026, odkaz na sekciu rozhodnutí; pri H6 vymenovať odchýlky O1/O2/O3; pri H7 „všetko podľa odporúčania + R-38 áno"). Encoding guard musí prejsť.
- PLAN: riadok H6 rozdeliť na H6a/H6b/H6c (H6a ✅ + `PR #?`).

## Testy, fotky, uzáver (každá časť)
- `ruby tests/run_all.rb`, **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`), encoding guard; mutácie podľa §7 tvojej časti.
- In-SU nie je brána (Ruby sa mení len verziou/komentárom) — ak by si menil Ruby logiku, STOP a otázka.
- **Fotky:** `powershell -NoProfile -File scripts\ui_foto.ps1 -Shoot` pred zásahom aj po ňom (payload sa nemení → `-Record` netreba; ak nie je úspešná nahrávka
  so značkou `NAHRAVKA_OK.txt`, začni `-Record`; `exit 2` = iný beh drží zámok → počkaj a skús znova). Porovnaj Inspector kontexty Korpus/Zóny/Čelá/Kovanie
  pred/po; cesty k fotkám do reportu (do gitu nie).
- Uzáver podľa CLAUDE.md: bump patch (VERSION 2×) + **všetky `?v=`** · docs na mieste (UI_DIZAJN §5.1/§5.2 a dotknuté odseky `ui-lifecycle.md` — prepísať,
  nepridávať na koniec) · Grep tvrdení o odstránených prvkoch (pás `#ctxNote`, „Pripravené.", ghost riadok, „jednotka len pri prvom údaji") · STAV prepísať
  (max 80 riadkov) · KRONIKA odsek navrch · PLAN riadok časti ✅ + `PR #?`.
- Commity selektívne, správa cez súbor, trailer `Co-Authored-By` so **skutočným modelom tvojej session**.
- **Po pushi STOP** — PR neotváraj, vráť report (hlava, riadky kódu bez testov/docs, počty testov, mutácie, cesty k fotkám pred/po, odchýlky od package).
  PR otvoríš na pokyn orchestrátora. **Nemerguj.** Nemeň CLAUDE.md.
