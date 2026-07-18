# Dogfooding zápisník (živý dokument)

> **Ako s ním pracujeme:** Michal pri reálnej práci sype surové poznámky (chat/tu). Agent ich triedi do sekcií podľa závažnosti, dopĺňa technické zistenia a stav. Vyriešené body sa presúvajú dole do „Vyriešené" s odkazom na PR. Číslovanie `D-xx` je trvalé (nerecykluje sa).
>
> Začaté 19.7.2026 — prvé veľké testovanie po sérii V0.4.7 (samostatná doska + výrazové polia).

## Blokery (bránia dokončeniu zákazky)

- **D-05 · Vlastný materiál sa nedá pridať** — katalóg má len seed (K009 18/16, HDF 3, W1000 18); pracovná doska (28/38 mm) neexistuje a UI na pridanie nie je (okno „Materiály projektu" iba vyberá z existujúcich; CRUD bol plánovaný až s V0.5). Reálna zákazka bez vlastných materiálov nejde. **Návrh:** rozšíriť okno Materiály projektu o správu katalógu — pridať/upraviť/zmazať doskový materiál (názov, dekor, typ, hrúbka, smer dekoru, cena, farba) aj ABS pásku; mazanie s guardom (materiál použitý v modeli sa nemaže potichu). *Stav: čaká na potvrdenie rozsahu, potom implementácia (najbližšia dávka).*

## Spomaľovače (vysoká priorita)

- **D-06 · Scale úchopy fungujú opačne** — zámer: nechať IBA čisté osi X/Y/Z; realita: prvý Scale na objekte ukáže všetky úchopy, druhý Scale zablokuje presne osové a nechá rohové/hranové kombinácie. Technicky: DC `scaletool` maska je bitová mapa úchopov na SKRYTIE — hodnota 7 (v kóde od V0.2c, s poznámkou „Michal potvrdí vizuálne") skrýva osové; správne je **120** (8+16+32+64 = roviny+rohy preč, osi ostávajú). Rozdiel prvý/druhý beh naznačuje, že atribút treba písať aj na definíciu, nie len inštanciu. *Stav: fix pripravený do dávky 1.*
- **D-02 · Náhľad prepočítava pri každom písmene** — pri písaní rozmeru sa 2D náhľad trhá s každým znakom; výrazy (`950-28`) už majú pokojný režim (aplikujú až Enterom), čisté čísla nie. **Návrh:** debounce prekreslenia náhľadu (~0,5–1 s) alebo prepočet až na Enter/odklik. *Stav: fix pripravený do dávky 1 (debounce).*
- **D-07 · Medzery/presahy čiel sa nedajú nastaviť** — gap hodnoty (3 mm medzi čelami, 2 mm okraje) sú natvrdo; pri reálnych dvierkach treba kontrolu. Plánované vo V0.4.8 (konštrukčné možnosti z 06) — dogfooding potvrdzuje vysokú prioritu. *Stav: evidované, priorita ↑.*
- **D-01 · Náhľad je malý / nečitateľný** — zoom pomáha, ale pracovne to nestačí. Okno panela JE rozťahovateľné, náhľad má však fixnú výšku 210 px — nerastie s oknom. **Možnosti:** (a) náhľad rastie s výškou/šírkou okna, (b) tlačidlo „veľký náhľad" = samostatné satelitné okno, (c) nastaviteľná výška náhľadu. *Stav: otázka na preferenciu (viď Otvorené otázky).*

## UX drobnosti (nízka priorita)

- **D-03 · Police sa hľadajú ťažko** — funkcia EXISTUJE (klik na zónu v 2D náhľade alebo na ghost v modeli → karta „Zóna" pod náhľadom → „Police v zóne" → nastav), ale pri prvom použití ju Michal nenašiel = discoverability problém. **Nápady:** pri jednozónovej skrinke zobraziť kartu zóny rovno; hint „klikni na zónu pre police/delenie" v prázdnom stave; police spomenúť v akordeóne Štruktúra zón. *Stav: nápady, nie blok (howto odovzdané).*

## Nápady na zváženie (nerozhodnuté)

- **D-04 · Ghost zóny vo viewporte zavadzajú** — neustále omylom klikané, dielce sa na ne prichytávajú. Rozmer ghostu je menší než skrinka ZÁMERNE (ghost = vnútorný svetlý priestor zóny, nie obrys korpusu). **Nápad Michal:** v SketchUp viewporte ghost len viditeľný, ale neklikateľný; klikanie na zóny nechať na 2D náhľad v paneli. **Technická poznámka:** SketchUp nevie „viditeľné ale nepreklikateľné" čisto (locked skupina sa stále vyberá); reálne možnosti: (a) predvolene ghosty vypnúť (checkbox „Zobraziť zóny" už existuje — stačí zmeniť default a klik na zónu ostáva v 2D náhľade), (b) nechať ako je, (c) locked ghost (klik ho vyberie, ale nič nerozbije — prichytávanie však ostáva). Súvisí s D-01/D-03 (2D náhľad musí byť dosť dobrý, aby zónové klikanie unieslo). *Stav: otázka na rozhodnutie.*

## Otvorené otázky (čakajú na Michala)

1. **D-05 materiály:** stačí navrhnutý rozsah (dosky + ABS pásky, pridať/upraviť/zmazať v okne Materiály projektu)? Alebo len rýchle „pridať dosku" a zvyšok neskôr?
2. **D-01 náhľad:** preferuješ (a) náhľad rastúci s oknom, (b) samostatné veľké okno náhľadu, alebo (c) nastaviteľnú výšku?
3. **D-04 ghosty:** vypnúť predvolene (klik na zóny primárne cez 2D náhľad) — áno/nie?

## Vyriešené

- **D-03 (čiastočne)** — police fungujú cez kartu zóny; howto odovzdané 19.7., ostáva UX discoverability (viď vyššie).

## Postrehy, ktoré potešili (nechávame tak)

- Výrazy v poliach: „650-36 → super, nemusím rátať z pamäti a preklikávať kalkulačku — bomba." Medzivýpočet 950-28=922 prehľadný, Enter potvrdenie sedí.
- Blokovanie nezmyselnej hrúbky materiálu (20 mm bez katalógového materiálu → červený blok) funguje.
- Police: vygenerovanie, presun dovnútra, ABS preklik aj S5 scale — bez problémov.
- UI: „začína pôsobiť veľmi konzistentne a zrozumiteľne — už to nie je zhluk, ale pre každé označenie jasné kroky."
