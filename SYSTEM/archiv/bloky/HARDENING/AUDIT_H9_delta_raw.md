1. **RESOLVED** — `read_valid` číta `.bak` cez `fallback: false`; `.bak.bak` sa nepoužije a T7/M10 tento prípad výslovne strážia (`_dev/audit_h9/PACKAGE_H9_v2.md:104-108`, `:211-215`).

2. **RESOLVED** — chyby predikátu obaľuje samostatný `ShapeCheckError`, mimo parser rescue; T9 zahŕňa aj `JSON::ParserError` a systémové výnimky (`_dev/audit_h9/PACKAGE_H9_v2.md:97-102`, `:216-218`).

3. **RESOLVED** — `abs_rules` aj `hardware_rules` sú už v scope s predikátmi, shape-aware čítaním, zápisovou bránou a úplnou maticou T13 (`_dev/audit_h9/PACKAGE_H9_v2.md:168-189`, `:225-227`).

4. **RESOLVED** — T0b teraz charakterizuje skutočný `SheetLayout` aj `Budget` s parametrami načítanými zo zdravého súboru, vrátane pripnutých výsledných čísel (`_dev/audit_h9/PACKAGE_H9_v2.md:199-203`).

1. **FIX-IN-H9 — H9 a H10 nemajú zjednotený kontrakt zápisovej brány `hardware_rules`.** H9 vyžaduje shape-aware `degraded?(path, shape:)`, ale H10 navrhuje jednu „čistú“ autoritu `write_gate_reason(doc)`; samotný dokument načítaný zo zálohy nedokáže rozlíšiť zdravý primár od shape-degraded primára. H10 tak môže pri refaktore obísť novú H9 bránu. Package musí záväzne určiť, že H10 `library_check` aj `write` používajú rovnakú H9 filesystemovú/shape-aware klasifikáciu po `reload!`, nie iba posúdenie načítaného dokumentu (`_dev/audit_h9/PACKAGE_H9_v2.md:172-181`; `_dev/audit_h10/PACKAGE_H10_v2.md:136-146`; `noxun_engine/core/hardware_rules.rb:684-745`).

2. **FIX-IN-H9 — Golden dôkaz pre zdravé vlastné ABS a kovanie nepokrýva deklarované výrobné výstupy.** T0c overuje len výsledok `AbsRules.load`/`HardwareRules.load_state` a bajty súborov; existujúce golden testy ostávajú na seede. Chýba end-to-end charakterizácia hrán/VEPO a nákupu kovania nad zdravými vlastnými súbormi, hoci package sľubuje nezmenené výrobné čísla (`_dev/audit_h9/PACKAGE_H9_v2.md:88-91`, `:204-205`, `:222-224`; `noxun_engine/core/abs_rules.rb:224-250`; `noxun_engine/core/hardware_rules.rb:491-528`).

3. **NOTE — T13 neoveruje skutočný UI priebeh po degradovanom načítaní.** Pri „aj ako globálnu predvoľbu“ dnešné okno najprv uloží a prestavia projekt a až potom odmietne globálny zápis; formulácia matice „Uloženie z okna odmietnuté“ preto neznamená, že sa neuložilo nič. Doplniť test alebo presne uviesť, že odmietnutý je iba globálny súbor; H10 na tomto správaní priamo stavia (`_dev/audit_h9/PACKAGE_H9_v2.md:185-189`, `:225-227`; `noxun_engine/ui/rules_dialog.rb:638-660`; `_dev/audit_h10/PACKAGE_H10_v2.md:154-172`).


Codex session ID: 01a0f4e2-6ff2-7e12-baf8-694ba2f76ea0
Resume in Codex: codex resume 01a0f4e2-6ff2-7e12-baf8-694ba2f76ea0
