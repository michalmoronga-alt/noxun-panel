---
paths:
  - "noxun_engine/ui/**"
  - "tests/js/**"
  - "scripts/ui_foto.ps1"
  - "scripts/ui_foto/**"
---

# Oblasť: UI — Inspector, Štúdio, HTML, JS, CSS

> Načíta sa samo pri práci so súbormi UI ([POVINNE_CITANIE.md](../../SYSTEM/pravidla/POVINNE_CITANIE.md)).

**Pred prácou POVINNE prečítaj:**

- [docs/UI_DIZAJN.md](../../docs/UI_DIZAJN.md) **§1–§3** (norma, pri KAŽDEJ UI práci; pri ikone či komponente aj dotknutý §4 / §5.x),
- **odsek dotknutej UI sekcie alebo modulu** v [docs/architecture/ui-lifecycle.md](../../docs/architecture/ui-lifecycle.md)
  (Grep podľa nadpisu; celý má ~257 kB) — napr. sekcia Štúdia `^### Sekcia ROZPOČET`, kontext Inspectora `^### Kontext Čelá`,
  `^### Satelitné okná` a súbor dialógu (`^### <súbor>_dialog.rb`), `^### D-15 modal`, `^### Paleta a téma`,
  `^### Veľkosť okna pri otvorení`,
- pri zmene stĺpcov alebo sekcií Štúdia **záväzný kontrakt Kusovníka**
  [SYSTEM/zdroje/ui20/UI20_KONTRAKT.md](../../SYSTEM/zdroje/ui20/UI20_KONTRAKT.md) (Š2 stĺpce),
- trvalé pravidlo **„vertikálny priestor panela je vzácny"** (autorita UI_DIZAJN §1).

Nový JS modul = nový riadok v rozcestníku `docs/ARCHITEKTURA.md` a odsek v `docs/architecture/ui-lifecycle.md`, nikdy text na koniec súboru.

**Cache-bust:** každý `?v=` v `ui/*.html` = presne VERSION (CEF cachuje css/js; stráži guard test).
Zmena css/js ⇒ bump verzie ⇒ prepíš všetky `?v=`.

**Fotenie okien (každá UI dávka):** po zmene JS/CSS/HTML `powershell -NoProfile -File scripts\ui_foto.ps1` (predvolený `-Shoot`),
po zmene tvaru dát z Ruby (payload okna) `-Record`. Fotky idú do `%TEMP%\noxun_ui_foto\` → report orchestrátorovi → Michal;
do gitu nie. Režimy a hranice: [NASTROJE_TESTOV.md, Fotenie okien](../../SYSTEM/pravidla/NASTROJE_TESTOV.md#foto).
