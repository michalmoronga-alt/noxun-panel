# Merač používania (D-25) — odpočet za tri týždne (11.8.2026)

> **Podklad pre UI 2.0** — dáta, o ktoré sa opiera rozhodnutie, čo musí byť na jeden klik (a stará otázka D-26 „jednoduchý vs. rozšírený režim"). Presunuté zo živého zápisníka [../08_DOGFOODING.md](../08_DOGFOODING.md) pri dávke U2; text je pôvodný.
> **Merač beží ďalej aj počas reworku** — po ňom sa to isté odčíta znova a porovnanie ukáže posun vo frekvencii.

Merač beží od **20.7.** (PR #50) a zbiera výhradne **ktorý prvok bol použitý a koľkokrát** — žiadne hodnoty, žiadny obsah zákazky (`%APPDATA%\NOXUN\Engine\usage_stats.json`). **Meria FREKVENCIU interakcií, NIE čas** (nie sú tam trvania ani hranice úloh) — rovnaký počet môže znamenať rýchle cielené použitie aj dlhé hľadanie. Prvé odčítanie po troch týždňoch reálnej práce:

- **Najviac interakcií pripadá na materiály a ABS — spolu vyše 400:** otvorenie okna Materiály **115×**, výber materiálu pri vkladaní dosky **112×**, ABS selecty dielcov a dosiek **117×**, materiál dosky **32×**, materiály korpusu **34×**.
- **Preklikávanie tabov 287×** a **otváranie satelitných okien 234×** (materiály 115 · výroba 96 · kovanie 17 · pravidlá 6) — teda samotné *hľadanie miesta, kde sa vec nastavuje*, je jedna z najčastejších činností.
- **Takmer nepoužité prvky (1–2× za tri týždne):** orientácia a odsadenie výstuh, počet vodorovných delení, režim sokla, fit náhľadu, reset kovania.

**Záver:** dáta ukazujú, KDE sa práca sústreďuje — materiály, ABS a prepínanie kontextu — a tým dávajú Michalovej sťažnosti na UI merateľné ťažisko (samotný pocit „trápim sa" merač dokázať nevie, na to by musel merať čas a hranice úloh). Sú hotovým podkladom pre **UI 2.0** (čo musí byť na jeden klik) aj pre starú otázku **D-26** „jednoduchý vs. rozšírený režim" (kandidáti na skrytie sú vyššie). **Merač sa cez rework nevypína** — po ňom sa to isté odčíta znova; porovnanie ukáže posun vo FREKVENCII (napr. menej otvorení okien na tú istú prácu), nie ušetrené minúty. Ak by sme chceli tvrdiť úsporu času, merač by musel dostať trvania a hranice úloh — samostatné rozhodnutie, dnes ho nemá.
