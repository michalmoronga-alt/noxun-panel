> Kópia zadania zo scratchpadu orchestrátora, 1.10.2026; package/audity dávky sú v nadradenom priečinku.

# Briefy — dávky H8 · H9 · H10a · H10b (blok 9 HARDENING) — spoločná šablóna

Orchestrátor ti povie, ktorú dávku robíš. Pracuj z **čerstvého `origin/main`** (po mergi predchodcu). Scratchpad:
`C:\Users\PC\AppData\Local\Temp\claude\C--APP-DEV-RUBY-ENGINE\0d0c7070-cda8-4433-abd5-db481a11fb59\scratchpad\HARDENING\`

| Dávka | Vetva | Package (autorita) | Zvláštnosti |
|---|---|---|---|
| **H8** · dielec z inej verzie štandardu (R-13) | `fix/h8-std-citanie` | `PACKAGE_H8.md` — **§15 (audit) má prednosť** | **in-SU POVINNÉ** (§15 A1/A3: behaviorálny test skutočného `Bom.collect`; krok 1 pred `cleanup` s nenulovým pokrytím); texty Q1 podľa návrhu |
| **H9** · ochrana nastavení pred seedom (R-37 + ABS + kovanie) | `fix/h9-ochrana-nastaveni` | `PACKAGE_H9.md` — **§15, §15.2 a „Potvrdenie orchestrátora" majú prednosť** | brána `HardwareRules.write_gate` (R15) je autorita aj pre H10; nad ~120 riadkov kódu → STOP a rez H9a/H9b; Q1/Q2 = „nie" |
| **H10a** · pravidlá kovania pri dvoch oknách (R-35, časť pravidlá) | `fix/h10a-pravidla-revizia` | `PACKAGE_H10.md` — **§15, „Potvrdenie orchestrátora" a „Zladenie s H9" majú prednosť** | in-SU brána (handle_save); `library_check` nad `write_gate` z H9; Q1 = konflikt → neuloží sa nič |
| **H10b** · rozmerové rady pri dvoch oknách (R-35, časť rady) | `fix/h10b-rady-po-klucoch` | `PACKAGE_H10.md` (časť H10b) | headless; Q2 = rôzne rady zlúčiť, ten istý rad = hláška |

## Spoločné pravidlá
- **Krok 0:** over čísla riadkov a API z package proti aktuálnemu mainu (predchádzajúce dávky bloku mohli posunúť kód — napr. H3a mení Kontrolu, H9 mení
  `json_file_store`/`hardware_rules`). Ak by rozdiel menil zámer, kontrakt, dáta alebo čísla → **zastav a vráť otázku**.
- Povinné čítanie podľa `CLAUDE.md` (po H1 po kapitolách) — riadky podľa dotknutých modulov.
- Testy: celá headless sada + **každá** JS sada zvlášť + encoding guard; charakterizácia/golden fixtúry sa **nepregenerujú**; mutácie podľa package do PR.
  In-SU runner `scripts\run_su_tests.ps1 -CloseWhenDone` (nikdy nezabíjať, `exit 2` = počkať a znova), PR uvedie hlavu in-SU behu.
- Ak meníš UI (texty, hlášky): `scripts\ui_foto.ps1 -Shoot` (alebo `-Record` pri zmene payloadu) a cesty k fotkám do reportu.
- Uzáver: checklist kódovej dávky (bump patch 2× + všetky `?v=`, architektúra na mieste, STANDARD ak package predpisuje, AUDIT_REGISTER R-číslo ✅, STAV prepis,
  KRONIKA, PLAN riadok dávky ✅ + `PR #?`); package + surové audity skopírovať do `SYSTEM/zdroje/bloky/HARDENING/`.
- Všetky štyri dávky sú **audit-povinné** → **predrecenzia povinná: po pushi vetvy STOP**, PR neotváraj, vráť report (vetva, plný SHA, hranica).
- Michal spí — vratná voľba len ak nemení dáta ani čísla (označ v reporte), inak otázka. **Nemerguj.**
