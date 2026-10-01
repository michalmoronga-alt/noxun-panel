> Kópia zadania zo scratchpadu orchestrátora, 1.10.2026; package/audity dávky sú v nadradenom priečinku.

# Brief — dávka H4a · jednotný zápis čísel a jednotiek + ABS „dookola" (D-04, D-11) — blok 9 HARDENING

Si implementátor dávky **H4a**. Pracuj z **čerstvého `origin/main`** (obsahuje H3a a H3b). Vetva **`feat/h4a-zapis-cisel`**.

## Zadanie (autorita)
- **Package:** `C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE\0d0c7070-cda8-4433-abd5-db481a11fb59\scratchpad\HARDENING\PACKAGE_H4.md` —
  **len časť H4a** (D-04, D-11) + testy a uzáver pre H4a; D-06/07/08/09 (H4b) **nerob**. Sondy v `…\HARDENING\h4\`.
- **Krok 0 (povinný):** package vznikol pred H3a — zlaď miesta z §5.1 s aktuálnym mainom (H3a zmenila texty Nákupu, Ponuky, Kontroly, Nastavení
  rozpočtu). Ak by zladenie menilo zámer, dáta alebo čísla → zastav a vráť otázku.
- **Hranica:** mení sa **len zápis** v okne (čiarka, celé kusy, € s dvomi desatinnými, jednotky) — rovnaké hodnoty; XLSX, CSV, VEPO a payload z Ruby sa
  nemenia (charakterizácia pred zásahom). Hrúbka „18,6" namiesto „19" a bm „70,94" sú zámerné zmeny zápisu (package) — uveď ich v PR popise.
- Povinné čítanie podľa `CLAUDE.md` (UI riadok po H1: UI_DIZAJN §1–§3, odseky dotknutých sekcií, UI20_KONTRAKT Š2 pri Kusovníku, cache-bust).

## Testy a DoD
- Package §7 pre H4a: JS testy formátovača (tabuľka vstup → výstup), charakterizácia, že payload/CSV/XLSX/VEPO sa nemenia, mutácie. Celá headless sada +
  **každá** JS sada zvlášť + encoding guard. In-SU nie.
- **Fotky okien** `scripts\ui_foto.ps1 -Shoot` (dávka H2) — pred/po pre dotknuté sekcie; cesty k 4–5 fotkám do reportu.

## Uzáver
- Checklist kódovej dávky: bump patch (2×) + všetky `?v=` · architektúra na mieste · STAV prepis · KRONIKA · PLAN blok 9: riadok H4 rozdeľ na **H4a**
  (✅ + `PR #?`) a **H4b** (otvorené). Skopíruj `PACKAGE_H4.md` do `SYSTEM/zdroje/bloky/HARDENING/`.
- Dávka je **výrobná/cenová (zobrazenie čísel, podľa ktorých sa objednáva)** → **predrecenzia povinná: po pushi STOP**, PR neotváraj, vráť report.
- Michal spí — pri nejasnosti bezpečnejšia vratná voľba len ak nemení dáta ani čísla (označ), inak otázka. **Nemerguj.**
