# Noxun Engine — roadmapa (živý dokument, aktualizované 15.7.2026)

> Princíp: **najprv všeobecný základ pre všetko, potom vyostrovanie.** Regenerate pattern robí konštrukčné zmeny lacnými — drahé je len meniť DÁTOVÝ MODEL (atribúty, identita, hrany), preto ten je uzamknutý štandardom vopred a detaily geometrie sa doladia iteráciami z klikania.

## Etapy

- ✅ **V0.1 — Klikateľný základ** (hotové 15.7.): panel, dolný korpus (Ruby regenerácia), police 0–4, dvierka 1/2/auto, ghost zóny, rebuild označeného, 1-krok Undo
- ✅ **V0.2a — Jadro korpusu** (hotové 16.7.): scale→automatická prestavba (celé mm, čistá transformácia, funguje aj na rotovanom) · konštrukčné varianty: dno pod bokmi (EU default) vs. medzi bokmi, vrch plný/2 výstuhy (orientácia flat/upright + offset — drezová/varná)/žiadny, chrbát naložený/vložený/drážka, sokel žiadny(nohy)/predný · **horná skrinka** (Z=1400) · spätná kompatibilita V0.1 · 18/18 kombinácií otestovaných
- ✅ **V0.2b — Členenie, čelá, šablóny** (hotové 16.7., v0.2.1): strom zón s klikateľnými ghost boxmi + priečky divider_v/h (rekurzívne, reálne dielce) · police = modul v zóne · čelá odspodu s fixed/auto + 🔒 locky, zásuvkové čelá, konverzia starých · šablóny (4 preddefinované + vlastné, %APPDATA% + .bak) · hrúbka chrbta HDF 3/pevný 18 · panel: základné/pokročilé skladacie sekcie
- 🔨 **V0.2c — UX panela a zón + opravy** (beží 16.7.): BUG teleport skrinky pri zmene z výberu v modeli · ghost zóny na 1 klik (top-level, bez dvojkliku do komponentu) · **2D náhľad skrinky v paneli** (čelný pohľad: klik na zónu, ťahanie priečok, presné rozmery + zámky — atypy) · auto-apply namiesto potvrdzovacích tlačidiel (rebuild je ms) · šablóny filtrované podľa typu korpusu · tagy dielov (Korpus/Čelá/Chrbát/Vnútro — hromadné hide) · scale handles len X/Y/Z (scaletool) · čitateľné názvy zón + zvýraznenie v modeli · panel per-dielec štruktúra (SYSTEM\06)
- **V0.3 — Materiály a ABS (dáta)**: materiálový katalóg (rodina/variant, JSON) · dedenie projekt→skrinka→modul→dielec · ABS hrany per strana (L1/L2/W1/W2) s pravidlovými defaultmi podľa roly · tri stavy materiálu (zaradený/ignorovaný/nezaradený)
- **V0.4 — Kovanie fáza 1 (pravidlá a flagy)**: JSON pravidlá + editačný panel · generické flagy (pánty podľa hmotnosti čela — Blum tabuľky, výsuvy podľa hĺbky NL+3, nohy podľa šírky) · generický fyzický objekt na kategóriu
- **V0.5 — Výstupy v0**: interný kusovník dielov · kusovník podľa materiálov (m²) · súpis ABS (bm) a kovania (ks) · celkový sumár · **VEPO CSV priamo** (podľa 03 kontraktu) · krížová validácia s OCL na reálnej zákazke · validačný semafor v0
- **V0.6 — Kovanie fáza 2 (katalóg a ceny)**: prevzatie CatalogStore/search/Demos import z KOVANIE · mapovanie flagov na konkrétne kódy (pamätá sa) · ceny v sumári
- **V1.0 — Zostavy a stabilizácia**: spájanie/zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, rohové situácie — snaper logika) · **soklová lišta v celku pre celý segment** · **obklady a krycie prvky segmentu**: pilastre (priznaný/skrytý + rýchly nástroj), pracovné dosky a horné krycie dosky na pár klikov na označený segment · ABS vizuálny režim (farebné hrany, klik-edit) · migrácia/oprava starých modelov · test na kompletnej reálnej zákazke
- **Neskôr (po V1)**: zásuvkové bloky (dočasne DC Atira most) · vnútorné vybavenie (koše, tyče…) · doplnky (LED, gola) · dĺžkové materiály naplno · odpojený režim UI · výkresy/etikety · CNC

## Pravidlo pre postrehy (Michal)

**Píš postrehy HNEĎ, keď ich vidíš — hocikedy, hociktorú tému.** Nemusíš strážiť, čo je kedy v pláne — ja každý postreh zaradím: buď do bežiacej etapy (ak sa týka), alebo do backlogu nižšie s označením etapy. Nič sa nestratí. Krátka veta stačí („boky majú stáť na dne, nohy pod tým") — doplňujúce otázky si vyžiadam sám.

## Hranica: TYP vs. ŠABLÓNA vs. PARAMETER (rozhodnuté 15.7.2026)

Tri úrovne — odpoveď na otázku „kedy nový typ korpusu":
1. **TYP (builder)** = iná **topológia**: iná množina dielcov a vzťahov, iné zóny, parametre ktoré inde nedávajú zmysel. Vlastný generovací kód. → dolná, horná; neskôr **rohová** (L-pôdorys, 2 čelné roviny — určite typ), vysoká/potravinová veža.
2. **ŠABLÓNA (template, čisté dáta)** = pomenovaná sada nastavení TYPU — žiadny nový kód. → **drezová** (= dolná + výstuhy na výšku), **varná** (= dolná + výstuhy −20 mm), klasik, zásuvková… Používateľ si tvorí vlastné (Blum „My Library" princíp).
3. **PARAMETER** = individuálna hodnota konkrétnej skrinky.
Pravidlo: kým sa dá vec vyjadriť hodnotou/variantom existujúceho dielca → parameter/šablóna. Nový typ až keď sa mení topológia.

## Backlog postrehov

| Dátum | Postreh | Zaradenie |
|---|---|---|
| 15.7. | EU konštrukcia: boky NA dne (váha na dno), nohy pod dnom, soklová lišta v celku pre segment; dno medzi boky = horné skrinky a špeciálne | ✅ poslané do V0.2a (default) + lišta segmentu → V1.0 zostavy |
| 15.7. | Spájanie korpusov: zarovnanie čelných hrán (default), voliteľne zadných; pripájacie body; rohová sa nepája na rohový styk | V1.0 zostavy (štandard otvorený bod 7) |
| 15.7. | Scale nástroj → automatická prestavba s korektnými hrúbkami | ✅ V0.2a (beží) |
| 15.7. | Drezová: horné výstuhy NA VÝŠKU (max priestor pre umývadlo) | ✅ poslané do V0.2a (rails_orientation) |
| 15.7. | Varná doska: výstuhy 20 mm pod hornou hranou (zapustenie dosky) | ✅ poslané do V0.2a (rails_top_offset) |
| 15.7. | 3–4 typy pokryjú väčšinu projektov; rohová = určite samostatný typ; šatníky/atypy mimo | **Šablónový systém korpusov → V0.2b** (uložiteľné predvoľby: drezová, varná, klasik); rohová+vysoká → po V1.0 |
| 16.7. | **Pilaster** (bočná krycia/obkladová doska): skrutkuje sa zvnútra ako pohľadová, zakrýva biely korpus a vonkajšie spoje. Variant **priznaný** (z čelnej hrany viditeľný) vs. **skrytý** (čelá ho presahujú). Ideálne inteligentný rýchly nástroj. | V1.0 zostavy — obklady segmentu; rola `pilaster` do štandardu pri implementácii |
| 16.7. | **Pracovné dosky + horné krycie dosky** („priznaná horná doska"): vloženie na pár klikov na OZNAČENÝ SEGMENT (cez viac skriniek — zostavová úroveň, ako soklová lišta) | V1.0 zostavy — obklady segmentu; production_class sheet, dĺžka zo segmentu |
| 16.7. | Scale test rukou: funguje super, prestavba presne na mm | ✅ V0.2a potvrdená používateľom |
| 16.7. | Hrúbka chrbta ako nastavenie (HDF 3 / pevný 18) | ✅ poslané do V0.2b |
| 16.7. | Panel: len relevantné pre typ + rozmery označeného (sedí); pokročilé skrývať, nastavenia budú pribúdať | ✅ V0.2b (skladacie sekcie) + trvalá zásada |
| 16.7. | **DILEMA UI:** rozdeliť na A) Vkladanie (Picker 2.0 — dedič Noxun Pick, ktorý už nebude použiteľný — vyoperovať: thumby, ghost, draw-to-size, obľúbené) vs. B) Nastavenia („Component Options 2.0") — ako logicky? | Zapísané v **05_DILEMA_ui_architektura.md** (návrh Fable: Vkladač+Inspector+neskôr Výstupy) — rozobrať s GPT, rozhodnúť pred V0.3 UI |
| 16.7. | Test V0.2b: funkčnosť super, ale UI „džungľa" — veľa potvrdzovacích tlačidiel, zlá orientácia v zónach, chaos šablón (horná ponúka drezovú), BUG: teleport skrinky pri zmene z výberu v modeli | ✅ V0.2c (beží) |
| 16.7. | Zóny vízia: A) 2D náhľad v paneli (klik, drag priečok, rozmery+zámky, aj PRED vložením) vs. B) priamo vo viewporte | Hodnotenie: A najprv (SVG náhľad — nižšie riziko, funguje aj pred vložením), B neskôr ako nadstavba; 1-klik ghosty ako rýchly medzikrok → V0.2c |
| 16.7. | **Stráž kolízií** — diely sa prekrývajú / vyskočia mimo box → upozorniť kde a prečo | Validačná vrstva → V0.5 semafor (základný bbox check možno skôr) |
| 16.7. | **Tagy dielov** (korpus/čelá/chrbty/PD a zásteny…) — hromadné operácie, dočasné HIDE dverí | ✅ V0.2c |
| 16.7. | **Scale len čisté osi X/Y/Z** (bez kombinácií) — DC malo ScaleTool behavior | ✅ V0.2c (scaletool atribút test) |
| 16.7. | **Zložka pluginu** — konsolidovať súbory „rozliate" po RUBY zložke pod jednu strechu | Návrh: SYSTEM\ + docs\ presunúť do ENGINE\ (= GitHub repo „všetko na jednom mieste") — samostatný PR po V0.2c |
| 16.7. | **Interact pre čelá** (na neskôr): dráhy otvárania dvierok/šuflíkov, klik = otvorenie, merač kolízií pri otvorení — prezentácia, kontrola, pohľad dnu | Po V1.0 (dáta máme: origin čiel na hrane pántu; premyslieť pri kovaní — typ pántu = dráha) |
| 16.7. | **Vyhradený testovací projekt `ENGINEtests.skp`** (Michal vytvorí prázdny) — agenti v ňom testujú/mažú podľa uváženia; oddelenie od zákaziek (incident: 2 okná + zombie proces na porte 7891) | Umiestniť do `ENGINE\_dev\` · pridať `_dev/` do .gitignore · pravidlo do ENGINE\CLAUDE.md (bridge len v test okne/projekte) → docs PR po V0.2c |
| 16.7. | **BUG: drag priečky funguje len raz** — ďalšie ťahy vyžadujú re-klik na objekt (objekt pritom ostáva označený) | 🔨 fix beží (vetva fix/preview-drag-state → PR) |
| 16.7. | **Náhľad povýšiť na „otvárací náhľad"** panela + zobrazovanie zvolených elementov (dvere, korpus, dielec) | Neskoršie verzie — SYSTEM\07 |
| 16.7. | **UI mockup „NOXUN Furniture Engine"** — taby MODEL/VÝROBA/MATERIÁLY/KOVANIE, strom so stavmi, info karta dielca, ABS editor s „Použiť na podobné diely", katalóg podľa výrobných tried, kusovníky, kontrola, exporty lišta | Rozpísané v **SYSTEM\07_UI_VIZIA.md** (čo preberáme a kedy); syntéza s dilemou 05: kompaktný Inspector pri kreslení + veľké okno „Výroba" na kontrolu/výstupy |
