# 08 · Cenová ponuka, dokumenty a cenová čerstvosť

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

Po dávke E a UI 2.0 už NOXUN vie rozpočet, cenovú ponuku a automatické prepočítanie cien pri položkách napojených na Demos. Otvorená V1 vrstva zahŕňa najmä:

- manuálne 1-klik overenie ceny pre položky bez Demos väzby,
- viac URL/zdrojov na jednej položke,
- plný generátor zákazníckej cenovej ponuky do DOCX/PDF,
- vizualizácie v dokumente,
- prípadný režim „na faktúru“ / ďalší cenový režim,
- širšiu rodinu dokumentov (napr. ponuka vizualizácií, preberací protokol).

Téma nie je iba export formátu. Je to obchodný workflow a preto sa musí navrhnúť primárne podľa reálnej práce Michala/Lucie.

## 1. Cenová čerstvosť bez Demos väzby

Dnešný kontrakt správne rozlišuje cenu ako pohyblivú cache s dátumom overenia. Pri Demos položkách existuje automatická cesta. Pre ostatné položky treba navrhnúť manuálny workflow, ktorý je rýchly, ale neklame.

Možný UX smer:

1. položka ukáže „cena stará / neoverená“,
2. používateľ otvorí zdroj URL,
3. po návrate klikne `Cena sedí` alebo `Zmeniť cenu`,
4. až tento explicitný krok zapíše nové `price_checked_at`,
5. samotné otvorenie URL nič nemení.

Tým sa zachová princíp: systém nikdy netvrdí, že cenu overil, keď to používateľ nepotvrdil.

## Viac URL/zdrojov

Treba vyspecifikovať význam viacerých URL:

- alternatívni dodávatelia,
- výrobca + predajca,
- historický vs. primárny zdroj,
- URL konkrétneho variantu.

Cena má podľa V1 vízie zostať **jedna**, takže viac URL nesmie implicitne znamenať viac paralelných cenových záznamov bez nového rozhodnutia.

## 2. Dokument zákazníckej ponuky

DOCX/PDF generátor má z NOXUN dát vytvoriť dokument pripravený na odoslanie zákazníkovi.

Treba oddeliť:

### Obchodné dáta

- zákazka/projekt,
- zákazník,
- položky ponuky,
- ceny/DPH/režim,
- platnosť ponuky,
- poznámky/podmienky.

### Prezentačné dáta

- logo/hlavička NOXUN,
- textové sekcie,
- obrázky/vizualizácie,
- prípadné rozdelenie podľa miestností/sektorov,
- podpis/kontakty.

### Render/export engine

- šablóna,
- DOCX generovanie,
- PDF cesta,
- stabilné rozloženie a fallback pri chýbajúcom obrázku.

Nemá sa miešať business logika výpočtu ceny s layoutom dokumentu.

## Zdroj pravdy

Dokument musí vždy čítať ten istý výsledok, ktorý používateľ vidí v sekcii Cenová ponuka/Rozpočet. Nemá mať vlastný paralelný výpočet súm.

Pred exportom treba jasne ukázať warnings, napríklad:

- staré/neoverené ceny,
- položky bez ceny,
- spotrebič bez konkrétneho modelu/ceny,
- rozdiel medzi rozpočtom a zákazníckou ponukou podľa dnešného kontraktu.

Warnings majú byť transparentné; blokovanie exportu je samostatné rozhodnutie a nemá sa zaviesť implicitne.

## Vizualizácie

Treba rozhodnúť, odkiaľ obrázky prichádzajú:

- ručne vybrané súbory,
- exportované SketchUp scenes,
- budúci render workflow,
- uložené attachments projektu.

V1 môže byť jednoduchší: používateľ vyberie 1–N obrázkov pre dokument. Automatické generovanie renderov nie je podmienka dokumentového engine.

## Cenové režimy

Otvorený nápad „na faktúru“ (napr. ×1,2 podľa existujúcej praxe) sa nesmie pridať ako magický multiplier bez definície.

Treba rozhodnúť:

- čo multiplier znamená obchodne,
- či ovplyvňuje celý projekt alebo iba vybrané kategórie,
- ako sa kombinuje s DPH,
- ako sa zobrazuje zákazníkovi,
- či patrí medzi dnešné režimy € / €€ / €€€ alebo ide o inú os.

## Rodina dokumentov

Po vzniku stabilného document engine sa môže reuse-núť layout infra pre ďalšie dokumenty:

- preberací protokol,
- ponuka vizualizácií,
- interný výrobný dokument,
- iné firemné šablóny.

Nemá sa však v prvej dávke budovať generický „document platform“ bez konkrétneho prvého dokumentu.

## Otvorené otázky

1. Ako dnes reálne vyzerá finálna cenová ponuka NOXUN a ktoré časti sú povinné?
2. DOCX ako editovateľný master + PDF export, alebo generovať oba samostatne?
3. Aký engine/library je bezpečný v SketchUp Ruby prostredí a čo má byť externý helper?
4. Kde sa ukladajú šablóny a firemné assets — shared library?
5. Kde sa ukladajú zákaznícke údaje a vizualizácie projektu?
6. Ako používateľ manuálne overí cenu čo najrýchlejšie pri desiatkach položiek?
7. Ako sa modelujú viaceré URL bez rozbitia existujúceho single-price kontraktu?
8. Je „na faktúru“ cenový režim, daňový režim alebo obchodná prirážka?
9. Ktoré warnings iba upozornia a ktoré, ak vôbec nejaké, blokujú export?

## Pred implementáciou

Auditovať dnešný budget/offer payload, XLSX export, price refresh, `price_checked_at`, Demos/manual položky, Studio offer UI a shared library plán. Pred návrhom DOCX/PDF si od Michala/Lucie vyžiadať reálny vzor dokumentu a reálny workflow od rozpočtu po odoslanie zákazníkovi.
