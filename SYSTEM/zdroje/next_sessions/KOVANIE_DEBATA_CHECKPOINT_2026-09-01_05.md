# KOVANIE — checkpoint USER debaty 2026-09-01 · 05

> **Stav:** PRACOVNÝ CHECKPOINT / USER-DEBATA — nie implementačný spec, neimplementovať priamo.
> **Nadväzuje na:** `KOVANIE_DEBATA_CHECKPOINT_2026-09-01_04.md`.
> **Účel:** zachytiť rozhodnutia o výklopných/sklopných zostavách, HK top a univerzálnom pravidle počtu závesov.

---

## 1. AVENTOS HK top a generická výklopná zostava

- Pôvodná úvaha o ownerovi `HK zostava F1` sa zovšeobecnila: pri type čela `Výklop` vzniká generická **`Výklopná zostava F1`**.
- Výklopná zostava vlastní čelo, funkčnú zónu, opening mode, konkrétny mechanický systém, resolved hardware set, technickú validáciu, locky a override-y.
- Konkrétny systém (napr. `AVENTOS HK top`) je až mechanická realizácia tejto zostavy, nie typ ownera.
- Funkčná zóna vzniká okamžite spolu s výklopnou zostavou, ešte pred výberom konkrétneho mechanizmu.
- Pri HK sa šírka/výška funkčnej zóny odvodzuje z geometrie čela a svetlá hĺbka z parent konštrukčnej zóny.
- HK resolver vyberá odporúčaný kompatibilný mechanizmus automaticky podľa geometrie, hmotnosti čela a overených technických limitov; ručne možno zvoliť inú kompatibilnú variantu.
- Bežný Inspector ukazuje hlavne výsledný mechanizmus a kompatibilitu; Power Factor/sila/rozsahy a vstupná hmotnosť sú v rozbalenom technickom detaile.

## 2. HK top Classic / Tip-On

- `Classic / Tip-On` je samostatná os resolvera výklopnej zostavy.
- Pri `Classic -> Tip-On` resolver hľadá najbližší kompatibilný Tip-On ekvivalent a ukáže diff; nemá znovu riešiť celý systém od nuly, ak ostatné osi ostávajú kompatibilné.
- HK top Tip-On resolved set reálne obsahuje aj **TIP-ON piest** ako samostatného člena setu.
- Pre HK Tip-On platí tvrdé pravidlo: **presne 1× TIP-ON piest**.
- Viac piestov sa nepovažuje za platnú konfiguráciu, pretože ich nemožno spoľahlivo synchronizovať.

## 3. Pamäť výklopnej zostavy

- Pri `Výklop -> Dvierka` sa aktívna výklopná zostava a funkčná zóna odstránia, ale posledná kompletná technická konfigurácia sa zapamätá.
- Pamäť obsahuje celý posledný stav: systém (napr. HK top), Classic/Tip-On, konkrétny mechanizmus, resolved set, locky a manuálne override-y.
- Pri návrate `Dvierka -> Výklop` Engine ponúkne `Obnoviť poslednú konfiguráciu / Začať od predvolených`.
- Obnovený stav sa vždy znovu validuje voči aktuálnej geometrii a funkčnej zóne.

## 4. Sklopná zostava

- `Sklop` používa rovnaký generický princíp ako `Výklop`.
- Vzniká **`Sklopná zostava F1`** + funkčná zóna; konkrétny mechanický systém sa vyberá až následne.
- Sklopná zostava má všeobecnú os `Classic / Tip-On`; konkrétny mechanizmus len deklaruje podporované režimy.
- Pri `Sklop -> Dvierka` sa aktívna zostava a funkčná zóna odstránia, posledná kompletná konfigurácia sa zapamätá.
- Pri návrate `Dvierka -> Sklop` sa ponúkne `Obnoviť poslednú konfiguráciu / Začať od predvolených`, s následnou revalidáciou.

## 5. Dvierka ako hardware owner

- Pri dvojkrídlových dvierkach má každé krídlo vlastného hardware ownera (`F1-L`, `F1-R`).
- Medzi krídlami môže existovať jednoduchá logická väzba dvojice kvôli smeru/rozloženiu, ale **V1 nezavádza všeobecný systém symetrických alebo synchronizovaných čiel**.
- Počet závesov sa počíta a validuje pre každé krídlo samostatne.
- Každé krídlo má vo V1 vlastný lock/override počtu závesov; žiadne automatické prenášanie locku na „rovnaké“ alebo symetrické čelá.
- Pri jednokrídlových dvierkach Engine smer neháda, ak ho nevie spoľahlivo odvodiť: stav `Neurčený`.
- `Neurčený smer` je počas návrhu WARNING, pri finálnej kontrole ERROR a blokuje výrobný výstup.

## 6. Univerzálne pravidlo počtu závesov

- Nepoužívať samostatný algoritmus počtu závesov pre každú značku/radu.
- Všetky bežné závesy používajú **jeden spoločný Engine rule**.
- Základná logika: `počet závesov = MAX(podľa výšky, podľa hmotnosti)`.
- Presné prahy sa majú pred implementáciou overiť z technických tabuliek výrobcov a používateľ ich odsúhlasí.
- Šírka dvierok sama automaticky počet závesov nemení; pri prekročení overeného bežného rozsahu Engine iba zobrazí WARNING.
- Vždy existuje ručný override počtu závesov.

## 7. Lock počtu závesov

- Ručne prepísaný počet závesov sa automaticky stáva viditeľným lockom, napr. `🔒 3 závesy`.
- Pri zmene rozmeru, typu, usporiadania alebo materiálu/hmotnosti Engine lock nezmení, iba znovu vypočíta odporúčané minimum a upozorní na rozdiel.
- Zamknutý počet pod vypočítaným minimom: WARNING počas návrhu, ERROR pri finálnej kontrole.
- Zamknutý počet vyšší než odporúčané minimum je platný `OK`; možno jemne ukázať odporúčané minimum, ale bez warningu.

## 8. Mimo scope V1 — symetrické/rovnaké čelá

- Synchronizácia nastavení medzi symetrickými alebo „rovnakými“ čelami je **výslovne mimo V1**.
- V1 nebude mať `Použiť aj na ostatné rovnaké`, skupinové locky ani automatické odpájanie zo synchronizovaných skupín.
- Ak sa neskôr ukáže reálna potreba, táto oblasť sa navrhne samostatne ako bulk/synchronization feature, aby sa nemiešala do základného modelu kovania.

## 9. Dvierkové sety — Classic / Tip-On

- `Classic` používa záves s **integrovaným tlmením**; tlmenie nie je samostatný prepínač.
- `Tip-On` používa P2O záves bez tlmenia + **presne 1× TIP-ON piest na jedno krídlo**.
- Podložky a krytky sú spoločné katalógové komponenty a môžu byť referencované Classic aj Tip-On setmi; netreba ich duplikovať podľa opening mode.
- Defaultná množstvová logika bežného dvierkového setu:
  - záves = podľa vypočítaného/locked počtu závesov,
  - montážna podložka = `1× na záves`,
  - krytka = `1× na záves`,
  - TIP-ON piest = `1× na krídlo` iba pre Tip-On.
- Toto je default, nie hardcode konkrétneho setu: členovia a množstvová logika setu zostávajú editovateľné v definícii konkrétneho setu.

## 10. Jednoduché množstvové pravidlá členov setu

Používateľ zvolil **A**: set member quantity nepoužíva univerzálny voľný formula language. V1 má malý kontrolovaný zoznam jednoduchých pravidiel, minimálne:
- pevný počet,
- `N× na záves`,
- `N× na owner/krídlo/zostavu`,
- jednoduchý násobok základnej veličiny.

Cieľ: sety zostávajú flexibilné a editovateľné bez hardcodovania každého komponentu v Engine, ale pravidlá sú čitateľné, auditovateľné a bezpečné.
