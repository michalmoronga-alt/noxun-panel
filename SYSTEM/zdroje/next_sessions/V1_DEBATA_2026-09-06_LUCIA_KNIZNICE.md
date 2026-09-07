# V1 debata · bod 7 DVAJA POUŽÍVATELIA — Lucia, zdieľané knižnice (D-48), prílohy (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (okno „V1 plánovanie po KOVANÍ") · auditované proti kódu: ČIASTOČNE (existujúce vzory: revízny
> odtlačok Štúdia, `JsonFileStore` + `.bak`, brány R-11/R-12, updater D-52 s distribučným priečinkom, náhľady šablón cez base64 kanál) · task package vznikne **až po uzávere V1**
> (rozhodnutie Michala nižšie) a po `codex-audit` (nový modul + zápis do všetkých katalógov).
>
> Pred implementáciou platí postup z [README.md](README.md). Nadväzuje na [05_SHARED_LIBRARY_UPDATE.md](05_SHARED_LIBRARY_UPDATE.md) — tento dokument ho **rozhoduje** (tvar D-48).

## 0 · Rozhodnutia (Michal 6.9.)

| Téma | Rozhodnutie | V1? |
|---|---|---|
| Zdieľanie knižníc medzi 2 PC (D-48) | **ÁNO, ale MIMO V1 — prvá funkcia po uzávere V1 („V1.10")**, v tvare §1 (verzie + Odoslať / Aktualizovať + konflikt per katalóg) | po V1 |
| Čo sa zdieľa | **všetko používateľsky editovateľné v `%APPDATA%\NOXUN\Engine`** — katalógy (materiály, kovanie, spotrebiče aj prílohy), šablóny (aj náhľady), sety, výrobcovia/rady, **pravidlá kovania, ABS pravidlá, rozmerové rady** aj nastavenia rozpočtu a dodávateľa; per-PC ostávajú len cesty a technické markery. **Záväzný zoznam store-ov je v návrhu** (§1 nižšie) | po V1 |
| Odoslať / Aktualizovať | **naraz** pre všetky katalógy (riadok per katalóg so stavom), konflikt sa rieši **per katalóg, ručne** (výber verzie) | po V1 |
| Štart pluginu | verzie len **porovná a oznámi**; sťahovanie je vždy klik | po V1 |
| Zdieľaný koreň | **`H:\Môj disk\NoxunENGINE data`** (firemný Google Disk, zrkadlený na oboch PC — Michal vytvoril 6.9.) | pripravené |
| Lucia | **od 6.9. prvýkrát testuje** (plugin nainštalovaný na jej notebooku); po uzávere V1 sa jej plugin preinštaluje **raz**, ďalej updater (D-52) + knižnice cez Odoslať/Aktualizovať | — |
| Prílohy spotrebičov (galéria) | V1 **len lokálne** (`%APPDATA%`), záznam nesie **relatívne cesty**, aby sa priečinok dal po V1 presunúť do zdieľaného koreňa bez migrácie záznamov | V1 (v S1) |

Michalov dôvod: „všetko vo V1 je perfektný balík, po uzávere obaja môžeme naplno používať — a ja už iba doručujem update packy: nové dogfoodingy od Lucie a mňa a naplánované bloky po V1."

## 1 · Mechanizmus, riziká a rezy → samostatný návrh (rozdelenie PR #322 podľa pravidla 3 kôl)

Tvar riešenia (optimistické verzovanie, nemenné artefakty per publikácia, manifest, konflikty, prevzatie cez store API), zoznam store-ov, riziká a rezy SYNC-1..3
žijú v samostatnom návrhovom dokumente **[SYNC_KNIZNICE_NAVRH_2026-09-06.md](SYNC_KNIZNICE_NAVRH_2026-09-06.md)** (vlastný PR a vlastné review kolá). Sú v ňom zapracované nálezy Codex #322 kôl 1–3: bez CAS na Disku
(TOCTOU) → nemenné artefakty + manifest posledný · uuid per publikácia (dve inštancie SketchUpu, opakovanie po páde) · **vyriešené kolízie sa nehlásia donekonečna**
(detekcia len nad najvyššou neprekonanou verziou, manifest nesie `supersedes`) · **produkčné store-y** (`hardware_rules`, `abs_rules`, `dim_series`…) sú súčasťou
synchronizácie. Tento checkpoint drží len **rozhodnutia Michala** (§0) a čo ostáva pre V1 (§2). Orientačný odhad prácnosti (3 PR) platí, potvrdí ho package po audite.

## 2 · Čo ostáva v bode 7 pre V1

- **M-R FOTO** (fotka dekoru z Demosu na dielcoch; package v PLAN blok 5, audit ÁNO) — potvrdiť V1 a poradie (otázka Michalovi).
- **D-51** štandard veľkostí okien — zavrieť ako vyriešené Štúdiom, alebo dodať hodnoty (otázka Michalovi).
- **Lucia testuje od 6.9.** — jej postrehy = D-čísla do [../../DOGFOODING.md](../../DOGFOODING.md) hneď; do V1 idú tie, ktoré blokujú prácu, ostatné do update packov po V1.

## 3 · Dopad na živé dokumenty (zapracuje záverečný docs PR debaty)

- [../../V1_VIZIA.md](../../V1_VIZIA.md) bod 7: „D-48 mimo V1" ostáva, ale doplniť **tvar a poradie** („prvá funkcia po V1: Odoslať/Aktualizovať knižnice s verziami"); Lucia testuje. Mechanizmus: [SYNC_KNIZNICE_NAVRH_2026-09-06.md](SYNC_KNIZNICE_NAVRH_2026-09-06.md).
- [../../PLAN.md](../../PLAN.md): blok 6 INFRA / zásobník Po V1 — D-48 dostane tento tvar + odhad + koreň `H:\Môj disk\NoxunENGINE data`; S1 package: prílohy s relatívnymi cestami.
- [../../DOGFOODING.md](../../DOGFOODING.md) D-48 (Po V1 — zásobník): stav doplniť (rozhodnuté 6.9., tvar §1).
