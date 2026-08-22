# 03 · Kovanie fáza 3

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

V1 vízia počíta s treťou fázou kovania, ktorá ide za dnešné jednoduchšie sety a pravidlá. Otvorené sú najmä:

- výklopy podľa hmotnosti čela,
- rady nôh podľa výšky sokla,
- bočnice výsuvov podľa výšky čela,
- smer otvárania a typ závesu,
- automatika počtu nôh podľa šírky,
- vyrábané dielce zásuviek (Atira/Quadro/Tandem),
- owner override a „Použiť na podobné“.

Hlavné riziko je implementovať každý nový prípad ako samostatný blok podmienok. Táto session má najprv rozhodnúť, či NOXUN potrebuje všeobecnejší rule/evaluation model.

## Navrhovaná mentálna vrstva

Kovanie fáza 3 sa dá rozdeliť na tri odlišné problémy:

1. **výber vhodného produktu/setu**,
2. **výpočet množstva/konfigurácie**,
3. **generovanie naviazaných výrobných dielcov**.

Tieto tri vrstvy by sa nemali automaticky miešať do jednej funkcie.

## Príklad: výklop

Možný výpočtový reťazec:

```text
čelo
→ rozmery + materiál + density snapshot
→ vypočítaná hmotnosť
→ typ mechanizmu/výklopu
→ výkonová tabuľka výrobcu
→ vhodný rozsah
→ konkrétny set / kombinácia
→ vysvetlenie výsledku
```

Dôležitá vlastnosť: systém by mal vedieť nielen vybrať, ale aj **vysvetliť prečo**. Napr. „set X vybraný pre hmotnosť Y a výšku Z“.

## Kandidát univerzálneho rule modelu

Nie ako schválená schéma, iba smer na audit:

- vstupy: owner typ, rozmery, hmotnosť, sokel, výška čela, typ otvorenia, materiál,
- podmienky: rozsahy/tabuľky/pásma,
- výstup: generic type / catalog item / set / quantity / variant,
- priorita a fallback,
- manuálny override,
- zdroj pravidla (rule/set/manual),
- explainability pre UI a kontrolu.

Taký model môže obslúžiť viac rodín kovania bez kopírovania logiky.

## Vyrábané dielce zásuviek

V1-05 mení charakter problému: kovanie už iba nepridáva virtuálne položky, ale môže viesť k **výrobným dielcom** (dno, chrbát, prípadne celý vnútorný šuflík).

Treba explicitne rozhodnúť:

- kto je owner týchto dielcov,
- stabilné `part_key`,
- ako sa dostanú do BuildPlan/BOM/VEPO,
- čo je fáza A (výrobný snapshot) vs. fáza B (geometria),
- ako template nesie hardware set a ako sa z neho reprodukujú odvodené dielce.

## Manuálny override

Automatika má navrhovať, používateľ rozhoduje. Treba zachovať:

- owner-level override,
- možnosť vynútiť konkrétny set/variant,
- jasné zobrazenie „AUTO vs manuál“,
- návrat späť na pravidlo bez zvyškov starého override.

## Otvorené otázky

1. Potrebuje engine univerzálny rule evaluator alebo stačí rozšíriť dnešný model pravidiel?
2. Aké vstupy musia byť snapshotované do modelu, aby projekt ostal reprodukovateľný aj po zmene katalógu/tabuliek?
3. Ako reprezentovať výrobné tabuľky (napr. Blum) — lokálny katalóg, rule data, samostatné data packy?
4. Kde končí generic type a začína konkrétny catalog item/set?
5. Ako UI vysvetlí, prečo automatika vybrala dané kovanie?
6. Ako sa rieši konflikt manuálneho override s neskoršou zmenou rozmerov/čela?
7. Ako jednotne riešiť „Použiť na podobné“ bez nežiaduceho prenášania owner-specific nastavení?

## Pred implementáciou

Auditovať dnešný hardware catalog, rules, sets, owner model, BuildPlan hardware payload, templates, rozpočet/nákup a existujúce H-dávky. Až potom rozhodnúť, či vzniká nový rule kontrakt alebo iba rozšírenie existujúceho.
