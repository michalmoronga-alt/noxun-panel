# ArchiWood & ArchiNest — koncepty ako inšpirácia pre systém Noxun

Web research júl 2026. Čínsky plugin (ArchiWood = návrh, ArchiNest = výroba/nesting), aktívne vyvíjaný, SU 2018–2026, cloud licencia. **Nestojí na dynamických komponentoch** — vlastný parametrický engine + cloudové knižnice. Tu sú koncepty relevantné pre náš plánovaný systém (korpusy + pripájanie childov + kovania + materiál/ABS + výstupy).

## 1. „Vnútorný priestor" — kľúčová abstrakcia pripájania

Childy sa nevkladajú „do skrinky", ale do **zameraného vnútorného poľa** (celý interiér, alebo pole medzi policami/priečkami). Dieťa sa automaticky roztiahne na rozmer zameraného priestoru. Workflow: pravý klik na korpus → „pick interior space" → vlož obsah.
→ **Pre nás:** presne toto je model „pripájania childov do korpusu". Korpus by mal vedieť ponúknuť svoje vnútorné priestory (po rozdelení priečkami/policami rekurzívne), a vkladaný child (šuflík, dvierka, polica) sa nadimenzuje podľa priestoru + vlastných pravidiel (škáry, presahy).

## 2. Kódy s parametrami vo VCB

Zameraný priestor + napísanie kódu do measurements boxu: `202` = rám korpusu, `11` = dvojdvierka naložené, `101` = vsadené; inline parametre `11 18 18 18 18` = presahy hore/dole/vľavo/vpravo; modifikátory `*20`/`+20` = hrúbka. Popri tom „quick design" lišta s ikonami bežných dielcov.
→ **Pre nás:** rýchly vstup pre power-usera (Michal); panel s ikonami pre bežný workflow. Kódová tabuľka sa môže stať „jazykom firmy".

## 3. Quick boards — dielec ako balíček výrobných dát

Preset dielca nesie naraz **materiál + hranovanie + vŕtanie/kovanie**. Firma si presety raz nadefinuje podľa svojich štandardov; odvtedy každý nakreslený dielec automaticky nesie výrobné dáta („design is disassembly").
→ **Pre nás:** child z knižnice by mal prísť s kompletnými metadátami (materiál, hrany, flagy kovania), nie len s geometriou. To je presne princíp KOVANIE auto-template, rozšírený na všetko.

## 4. Kovania — trojvrstvový pravidlový systém

1. **Konektory** — definície kovania s vŕtacími predpismi (trojkomponentná spojka, kolík, Lamello…).
2. **Spôsoby spojenia** — mapujú konektory na styk dielcov; voľba **podľa výšky/rozmeru dielca**.
3. Dielce/korpusy pravidlá **dedia**.

Automatika: otvory sa generujú **z kolízie/dotyku dielcov** + pravidlá (zákaz priechodných otvorov, zákaz vŕtania medzi susednými skrinkami). Pánty: počet **podľa výšky dvierok** (prah ~2000 mm → pravidlo dvojitých pántov), rozostupy globálne, per-dvierka prepísateľné. Úchytky: dávkovo s preddefinovanými pozíciami. **Virtuálne kovanie** — položky bez geometrie (skrutky) počítané do súpisu podľa pravidiel na skrinku. Konverzia ľubovoľného SKP modelu na kovanie s vŕtacími dátami.
→ **Pre nás (jadro auto-cesty):** pravidlá typu „2 dvierka výšky H → N závesov podľa tabuľky" a „šuflíková skrinka s 3 čelami → 3× výsuv" majú byť **deklaratívne dáta (JSON), nie kód** — editovateľné bez programovania. Virtuálne kovanie = spojovací materiál v kusovníku bez modelovania.

## 5. Pravidlové hranovanie (ABS)

Globálne defaulty (ktoré hrany sa hranujú) + **pravidlá výnimiek**: nehranuj, ak názov dielca obsahuje reťazec / hrúbka pod prahom / hrana kratšia než limit. Per-dielec prepisy. Vizuálny materiál a výrobné hranovanie sú **oddelené dáta**.
→ **Pre nás:** ABS ako metadáta na dielci (napr. `hrany: [predná: 2mm, zadná: 0, …]`) + pravidlový default podľa typu dielca. Jediný use-case, ktorý naše rešerše nepokrývali — toto je odpoveď.

## 6. Generátor korpusov s konštrukčnými typmi

Dialóg: rozmery + **3 konštrukčné typy** (boky obaľujú dno/vrch ↔ dno/vrch obaľuje boky ↔ vrch naložený), sokel, varianty chrbta, priečky. Po vložení **živá editácia** — označíš skrinku, zmeníš parameter, prestavia sa. Hierarchia: dielec → korpus → zostava korpusov.
→ **Pre nás:** „niekoľko typov základného korpusu" = konštrukčné typy, nie N samostatných modelov. Živá editácia označeného korpusu cez panel (DC Control už má základ).

## 7. Kontrola a výstupy

- **Smart Inspection** — predvýrobná kontrola: problémové dielce (príliš malé, chýba kovanie, nemožné vŕtanie, zlé hranovanie) **svietia červeno** s vysvetlením.
- **One-click report:** kusovník, súpis materiálu, súpis kovania, výrobná objednávka, **cenová ponuka**, vlastné zostavy, číslovanie zákaziek. Etikety s auto-triedením (miestnosť + skrinka + zákazka), QR kódy na montážne návody.
→ **Pre nás:** výstupná vrstva pre manželku — jeden klik, zrozumiteľný report: dielce + ABS + kovania + ceny + objednávkový sumár. Smart Inspection ako „semafor" pred odovzdaním ponuky.

## Čo NEkopírovať

- Cloud backend a licenčný server — pre interný nástroj zbytočná záťaž; lokálne JSON knižnice stačia (pattern KOVANIE CatalogStore).
- ~~Vlastný parametrický engine mimo DC~~ — pôvodná úvaha o hybride (DC geometria + Ruby riadenie) bola PREKONANÁ: analýza `SYSTEM/02_ANALYZA_korpus_dc_vs_ruby.md` rozhodla o čistom Ruby generovaní (žiadne DC vzorce) — teda rovnaký prístup ako ArchiWood. V tomto bode ArchiWood v skutočnosti kopírujeme, cloud backend nie.
- Desiatky toolbarov s 81 ikonami — náš cieľ je opačný: málo vstupných bodov, automatika namiesto možností.

Zdroje: archiwood.github.io, yooox.net (produktové články), sketchuppro.cn (znalostná báza), YouTube „Archiwood-cabinetdesign".
