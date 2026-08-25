# 08 · Cenová ponuka, dokumenty a cenová čerstvosť

> Stav: KONCEPT — neimplementovať priamo · zdroj: PR #210 (23.8.2026) · auditované proti kódu: zatiaľ nie
>
> Pred implementáciou platí postup z [README.md](README.md).

## Kontext a aktuálne rozhodnutie

Po dávke E a UI 2.0 už NOXUN vie rozpočet, cenovú ponuku a základné cenové/exportné workflowy v miere, ktorá je pre dnešnú prax **dostačujúca**.

Po ďalšej produktovej diskusii bol scope vedome zúžený: **08 sa nemá rozrásť na generickú dokumentovú platformu ani na množstvo exportných formátov.** Otvorený zostáva najmä zákaznícky grafický výstup cenovej ponuky do PDF a jeho reálna potreba sa má ešte overiť s Luciou.

Aktuálne nie je cieľ automatizovať všetko, čo sa dá. Ak ručná práca nad jednoduchou šablónou zaberá málo času, je prijateľné ponechať časť workflowu manuálnu.

---

# Cieľová malá rodina hlavných výstupov

Michal aktuálne očakáva približne **3–4 hlavné dokumenty/výstupy**, nie desiatky variantov:

1. **Export dielov s ABS** — výrobný výstup.
2. **Rozpočet** — interný/cenový výstup, dnes v Engine už dostatočne pokrytý.
3. **Cenová ponuka** — zákaznícky výstup zviazaný s rozpočtom; hlavný otvorený bod je grafická PDF forma.
4. **Nákupný zoznam** — pravdepodobný ďalší praktický výstup.

Nie je zámer pridávať XLSX/CSV/DOCX/PDF a ďalšie formáty len preto, že sú technicky možné. Každý nový výstup musí mať jasný reálny workflow.

---

# Cenová ponuka — aktuálny smer

Základ exportu cenovej ponuky a cien už v Engine existuje. Chýba najmä **pekný zákaznícky grafický výstup**.

Pracovná predstava je zámerne jednoduchá:

```text
NOXUN offer/budget data
        ↓
jednoduchá firemná šablóna
        ↓
ručné alebo poloautomatické vloženie renderov
        ↓
finálne PDF pre zákazníka
```

Nie je zatiaľ rozhodnuté, či:

- NOXUN bude generovať celý dokument automaticky,
- alebo vytvorí iba základnú šablónu/predvyplnený dokument a Lucia doplní obrázky a text ručne.

Pred implementáciou má Michal s Luciou overiť, koľko času dnes reálne zaberie vytvorenie cenovej ponuky a či plná automatizácia prináša dostatočný úžitok.

Michal pred implementáciou doloží **niekoľko reálnych vzorov cenových ponúk**, aby sa mohol navrhnúť grafický layout podľa skutočnej praxe namiesto odhadu.

---

# Zdroj pravdy

Ak vznikne automatizovaný alebo poloautomatizovaný dokument, musí čítať ten istý výsledok, ktorý používateľ vidí v sekcii Cenová ponuka/Rozpočet.

Document/export vrstva nesmie vytvoriť paralelný výpočet cien.

Pred exportom možno neskôr zobraziť warnings, napríklad:

- staré/neoverené ceny,
- položky bez ceny,
- spotrebič bez konkrétneho modelu/ceny.

Warnings majú primárne informovať; blokovanie exportu sa nesmie zaviesť bez konkrétneho dôvodu.

---

# Vizualizácie

Vizualizácie budú pravdepodobne súčasťou zákazníckej cenovej ponuky, ale V1 workflow má zostať jednoduchý.

Ak sa ukáže, že automatizácia má hodnotu, stačí najprv podporiť napríklad:

- ručne vybrané JPG/PNG/render obrázky,
- 1–N obrázkov vložených do šablóny,
- jednoduché poradie alebo výber používateľom.

Automatické renderovanie, SketchUp scene capture ani render pipeline nie sú podmienkou dokumentového výstupu.

Ak je pre Luciu rýchlejšie doplniť obrázky ručne do pripravenej šablóny, je to pre V1 plne akceptovateľný výsledok.

---

# Cenová čerstvosť a URL

Staršie otvorené úvahy zostávajú dostupné, ale **nie sú teraz prioritou 08**.

Dnešný kontrakt správne rozlišuje cenu ako pohyblivú cache s dátumom overenia. Pri Demos položkách existuje automatická cesta. Pri ostatných položkách možno neskôr doplniť jednoduchý manuálny workflow:

1. položka ukáže „cena stará / neoverená“,
2. používateľ otvorí zdroj URL,
3. po návrate klikne `Cena sedí` alebo `Zmeniť cenu`,
4. až explicitný krok zapíše nové `price_checked_at`.

Samotné otvorenie URL nesmie predstierať overenie ceny.

Viac URL/zdrojov na jednej položke je tiež možný budúci smer, ale viac URL **neznamená automaticky viac paralelných cien**.

Tieto body sa majú implementovať iba vtedy, ak reálny dogfooding ukáže, že dnešný workflow nestačí.

---

# Cenové režimy

Otvorený nápad „na faktúru“ / obchodná prirážka zostáva vedľajší a nemá blokovať dokumenty.

Ak sa k nemu vrátime, treba najprv oddeliť:

```text
nákupná/výrobná cena
→ obchodná prirážka
→ zákaznícka cena
→ DPH/daňový režim
```

Nesmie vzniknúť magický multiplier bez jasného obchodného významu.

---

# Čo vedome nerobíme teraz

- generický „NOXUN Document Platform“,
- 10–12 typov dokumentov,
- export do každého možného formátu,
- automatický render pipeline ako podmienku cenovej ponuky,
- zložitý template designer,
- automatizáciu, ktorá šetrí zanedbateľné množstvo času,
- nový paralelný pricing engine.

---

# Otvorené otázky pred implementáciou

1. Koľko času dnes Lucia reálne strávi vytvorením finálnej cenovej ponuky?
2. Stačí jednoduchá grafická šablóna s ručným doplnením renderov, alebo má hodnotu plná automatizácia?
3. Ako vyzerajú 2–3 reálne NOXUN cenové ponuky, ktoré majú byť vzorom?
4. Má byť cieľom iba PDF, alebo je užitočný aj editovateľný medzikrok (napr. DOCX)?
5. Ako presne má vyzerať nákupný zoznam a z akých existujúcich dát sa skladá?
6. Ktoré existujúce exporty už dnes plne pokrývajú diely+ABS a rozpočet a netreba ich meniť?

---

## Pred implementáciou

Auditovať dnešný budget/offer payload, existujúce exporty, price refresh a Studio offer UI. Pred návrhom PDF/DOCX workflowu si od Michala/Lucie vyžiadať reálne vzory cenových ponúk a reálny časový workflow od hotového rozpočtu po odoslanie zákazníkovi.

**Preferovať najmenšie riešenie, ktoré odstráni reálnu manuálnu bolesť.** Ak jednoduchá šablóna postačuje, nebudovať plný document engine.
