# Podklad pre celkový audit kódu (blok 1c, august 2026)

> Vrstva `zdroje/` — podklad, nie autorita. Riadi ho blok **1c · AUDIT KÓDU** v [../PLAN.md](../PLAN.md).
> Určené pre: externý Codex audit (spúšťa Michal) · vlastný prechod Fable · slepý subagent.
> Traja audítori dostávajú TEN ISTÝ podklad; nálezy sa zlejú a dedupujú do `SYSTEM/AUDIT_REGISTER.md`.

## Kontext a cieľ

Noxun Engine v0.8.5 — SketchUp Ruby plugin, parametrický nábytkársky systém. Od 20.8.2026 sa z neho
objednávajú REÁLNE zákazky (chyby vo výrobe/cenách = najvyššia priorita). Fáza ŠTÚDIO je uzavretá
(dve okná: Inspector + Štúdio, šesť satelitov zaniklo). **Cieľ auditu: pripraviť kód na už NAPLÁNOVANÉ
funkcie a pomenovať všetky nedorobky** — nie navrhovať nové funkcie ani prepisovať, čo funguje.

Naplánované funkcie, pre ktoré audit pripravuje pôdu — poradie blokov je AUTORITATÍVNE v [../PLAN.md](../PLAN.md)
(tu len výťah): **GHOST vkladanie** (Tool na kurzore, koncepty `next_sessions/09` + `09A`) → **KOVANIE**
(redizajn setov, D-109 pomer 1:N mení dátový model setu) → **KONTROLA + VÝROBA** (plošná kontrola D-95, exporty) →
**STABILITA** → **V1 DOTIAHNUTIE** (spotrebiče S1, ceny/ponuka) → **RENDER M-R**; priebežne INFRA
(shared library D-48/D-52). Pri konflikte poradia platí PLAN.

## Povinné čítanie pred auditom

[../STANDARD.md](../STANDARD.md) (záväzný dátový kontrakt) · [../../docs/ARCHITEKTURA.md](../../docs/ARCHITEKTURA.md)
→ mapa `docs/architecture/` · [../../docs/SKETCHUP_PRAVIDLA.md](../../docs/SKETCHUP_PRAVIDLA.md) ·
otvorené dlhy: [../DOGFOODING.md](../DOGFOODING.md) a blok 1b v [../PLAN.md](../PLAN.md).

## Prioritné osi (od budúcich funkcií dozadu)

1. **Observery · undo · Tool lifecycle** *(pripravuje GHOST — najcennejšia os)*: `core/scale_observer.rb`,
   dedup tick, disciplína `start_operation/commit`, viac otvorených dokumentov — POZOR na platformu:
   zdieľaný proces s prepínaním dokumentov je **macOS** scenár (guardy v `scale_observer.rb:149-150, 194-200, 382-383`),
   Windows drží jeden dokument na proces — audituj obe vetvy oddelene. Pasce z konceptu `09A`
   (Orbit suspend/resume, onCancel/undo, focus, getExtents). Otázka: čo dnes bráni bezpečne pridať
   `Sketchup::Tool`, ktorý kreslí ghost a zapisuje až na klik?
2. **Dátový model setov kovania** *(pripravuje D-109/KOVANIE)*: `core/hardware_sets.rb`, `hardware_rules.rb`,
   `config.hardware[]` — znesie schéma člena setu pomer „1 ks na N nôh" bez rozbitia výstupov a cien?
   Kde presne treba šev?
3. **`ui/production_core.rb`** *(pripravuje ponuku/DOCX aj plošnú kontrolu)*: jadro výstupov žije v UI vrstve
   (1200+ riadkov). Čo z neho patrí do core? Známy dlh: klamlivý blokový komentár nad `do_cp_xlsx`
   („ide do statusu aj do logu" — log nevzniká; KRONIKA, dávka Docs cleanup C).
4. **Payload kontrakty a identita**: `part_keys`, `build_plan`, `row_key`, `role_key` alias, session token,
   echo vs. plný push — konzistencia naprieč Inspector/Štúdio; čo nie je zdokumentované v `docs/architecture/`.
5. **Perzistencia a migrácie** *(pripravuje shared library)*: JSON store + `.bak`, pole `std` (verzia štandardu
   na entite), otváranie starých zákaziek — kde chýba migračná cesta alebo verzia formátu katalógov v `%APPDATA%`.
6. **UI vzory**: kde ešte žijú inline drafty/ad-hoc modály namiesto `nx_modal`/`nx_combo`; duplicity v JS moduloch.
7. **Dokumentačné diery**: VŠETKY odseky so stub textom „zatiaľ nezdokumentované" v `docs/architecture/` —
   zoznam si odvoď grepom (`grep -rn "zatiaľ nezdokumentované" docs/architecture/`), k 26.8.2026 ich je **19**
   (o. i. budget_store, cp_export, vepo_export, xlsx_writer, sheet_estimate, price_refresh, hardware_sets,
   usage_stats, `ui/panel/sync.rb` a šesť `ui/panel/actions_*`) — pri každom aspoň kostra kontraktu.

## Formát výstupu (záväzný pre všetkých troch audítorov)

Číslované nálezy, každý:

```
R-xx · P1/P2/P3 · vrstva (core/modules/ui/tests/docs) · súbor:riadok
Čo je zle (1–3 vety, s dôkazom z kódu)
Ktorú naplánovanú funkciu to blokuje / ktorý dlh spláca (alebo „hygiena")
Návrh riešenia (1–2 vety) + odhad náročnosti S/M/L
```

**P0 = AKTÍVNA chyba výroby/cien alebo strata dát — nečaká na register:** eskaluje sa okamžite ako samostatná
hotfix dávka (štýl bloku 1b), do registra sa zapíše len pointer s výsledkom · P1 = ohrozuje výrobu/ceny alebo
zablokuje GHOST/KOVANIE · P2 = treba pred príslušnou funkciou · P3 = hygiena, môže počkať.
**Nálezy bez dôkazu z kódu sa nezaraďujú.**

## Mimo záberu (nálezy z týchto oblastí sa NEprijímajú)

- prepisovanie funkčných builderov a zapisovacích ciest „na krajšie" (regenerate pattern je overený produkciou),
- hromadné premenovania/presuny modulov bez konkrétneho dôvodu,
- vizuálny redizajn Inspectora/Štúdia (kontrakt UI 2.0 je schválený 1:1 s mockupom),
- predčasné abstrakcie pre neschválené funkcie (attachment/segmenty — koncept 02 má otvorené otázky),
- výkonové optimalizácie bez merania (merač D-25/usage_stats existuje — najprv čísla),
- návrhy nových funkcií (na to je plánovacia dávka 1e, nie audit).
