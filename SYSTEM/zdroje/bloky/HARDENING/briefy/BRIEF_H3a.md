> Kópia zadania zo scratchpadu orchestrátora, 1.10.2026; package/audity dávky sú v nadradenom priečinku.

# Brief — dávka H3a · zavádzajúce údaje v okne (A-01, A-02, A-03, A-04, A-07) — blok 9 HARDENING

Si implementátor dávky **H3a**. Pracuj z **čerstvého `origin/main`** (po mergi predchádzajúcej dávky). Vetva **`fix/h3a-udaje-v-okne`**.

## Zadanie (autorita)
- **Package:** `C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE\0d0c7070-cda8-4433-abd5-db481a11fb59\scratchpad\HARDENING\PACKAGE_H3.md` —
  celý, **len časť H3a** (§6.1–§6.5 + testy a uzáver pre H3a). **Sekcia „Potvrdenie orchestrátora" na konci má prednosť** (rez, D2/D6/D7/D10/D12/D13).
  Sondy `sonda_h3.rb`, `sonda_h3.js` a výstupy v tom istom priečinku. A-06 (H3b) **nerob**.
- **Krok 0:** over čísla riadkov a tvar payloadov z package proti aktuálnemu mainu (po H1/H2 sa mohli posunúť dokumenty, kód nie). Ak sa niečo líši
  tak, že by sa menil zámer, dáta alebo čísla → zastav a vráť otázku v reporte.
- Povinné čítanie podľa `CLAUDE.md` (po dávke H1 smeruje na kapitoly): UI riadok (UI_DIZAJN §1–§3, odseky dotknutých sekcií v `ui-lifecycle.md`,
  UI20_KONTRAKT Š2 pri Kusovníku), výstupy len odseky dotknutých modulov, cache-bust.

## Testy a DoD
- Package §7 pre H3a: charakterizácia PRED zásahom (payloady, CSV kovania bajtovo, XLSX ponuky, VEPO — golden fixtúry sa **nepregenerujú**), JS testy nových
  textov/formátov, mutácie (zoznam z package, výsledok do PR). Celá headless sada + **každá** JS sada zvlášť + encoding guard. In-SU **nie je brána**.
- **Fotky okien:** ak je v maine `scripts\ui_foto.ps1` (dávka H2), nafoť dotknuté sekcie (Kusovník, Kontrola, Nákup kovania, Cenová ponuka, Nastavenia
  rozpočtu) pred/po (`-Shoot` nad aktuálnou nahrávkou; ak treba, `-Record`) a cesty k 4–5 najlepším fotkám daj do reportu.

## Uzáver
- Checklist kódovej dávky (CLAUDE.md): bump patch (2×) + všetky `?v=` · architektúra na mieste (odseky dotknutých sekcií; výnimka k Š8 pre D7) · STAV prepis ·
  KRONIKA · PLAN blok 9: riadok H3 rozdeľ na **H3a** (✅ + `PR #?`) a **H3b** (otvorené, A-06) · AUDIT/DOGFOODING len ak package hovorí.
- Skopíruj `PACKAGE_H3.md` do `SYSTEM/zdroje/bloky/HARDENING/` (odkazy funkčné).
- Dávka je **výrobná/cenová (zobrazenie)** a pridáva odkaz do Nárezového plánu → **predrecenzia povinná: po pushi vetvy STOP**, PR neotváraj, vráť report
  (vetva, plný SHA, hranica).
- Michal spí — pri nejasnosti bezpečnejšia vratná voľba len ak nemení dáta ani čísla (označ v reporte), inak otázka v reporte. **Nemerguj.**
