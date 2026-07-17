# Noxun Engine — roadmapa (živý dokument, aktualizované 17.7.2026)

> Princíp: **najprv všeobecný základ pre všetko, potom vyostrovanie.** Regenerate pattern robí konštrukčné zmeny lacnými — drahé je len meniť DÁTOVÝ MODEL (atribúty, identita, hrany), preto ten je uzamknutý štandardom vopred a detaily geometrie sa doladia iteráciami z klikania.

## Etapy

- ✅ **V0.1 — Klikateľný základ** (hotové 15.7.): panel, dolný korpus (Ruby regenerácia), police 0–4, dvierka 1/2/auto, ghost zóny, rebuild označeného, 1-krok Undo
- ✅ **V0.2a — Jadro korpusu** (hotové 16.7.): scale→automatická prestavba (celé mm, čistá transformácia, funguje aj na rotovanom) · konštrukčné varianty: dno pod bokmi (EU default) vs. medzi bokmi, vrch plný/2 výstuhy (orientácia flat/upright + offset — drezová/varná)/žiadny, chrbát naložený/vložený/drážka, sokel žiadny(nohy)/predný · **horná skrinka** (Z=1400) · spätná kompatibilita V0.1 · 18/18 kombinácií otestovaných
- ✅ **V0.2b — Členenie, čelá, šablóny** (hotové 16.7., v0.2.1): strom zón s klikateľnými ghost boxmi + priečky divider_v/h (rekurzívne, reálne dielce) · police = modul v zóne · čelá odspodu s fixed/auto + 🔒 locky, zásuvkové čelá, konverzia starých · šablóny (4 preddefinované + vlastné, %APPDATA% + .bak) · hrúbka chrbta HDF 3/pevný 18 · panel: základné/pokročilé skladacie sekcie
- ✅ **V0.2c — UX panela a zón + opravy** (hotové 16.7., v0.2.2): oprava teleportu · ghost zóny na 1 klik · interaktívny 2D náhľad · auto-apply · filtrovanie šablón · tagy dielov · osové scale handles · čitateľné zóny
- ✅ **V0.3 — Materiály a ABS (dáta)** (hotové 17.7., v0.3.0): materiálový katalóg (rodina/variant, JSON) · dedenie projekt→skrinka→dielec · ABS hrany L1/L2/W1/W2 s pravidlovými defaultmi podľa roly · per-dielec editor
- ✅ **V0.3.1 — stabilizácia dát** (hotové 17.7.): zhoda katalógovej a geometrickej hrúbky · smer dekoru vo výrobných dátach · atomický projektový prepočet s jedným Undo · validácia zón/čiel · bezpečná migrácia starých podlimitných čiel · zrozumiteľné zobrazenie dedenia v karte dielca
- ✅ **V0.3.2 — stabilná identita dielcov** (hotové 17.7.): trvalý `part_key` pre pevné dielce, zóny a čelá · migrácia starých override kľúčov bez straty neznámych údajov · materiál/ABS zostane na správnom čele po zmazaní susedného riadku a na správnej polici po úprave susednej zóny
- ✅ **V0.3.3 — ABS iba 1/2 mm** (hotové 17.7.): samočistenie aktívneho katalógu od nepodporovaných hrúbok · neplatné ABS priradenia sa zahodia bez tichej náhrady · pravidlá akceptujú iba 1 alebo 2 mm
- 🔨 **V0.3.4 — Stabilizácia pred kovaním** (schválené 17.7., beží): docs sync štandardu s kódom · odstránenie „Použiť na podobné" · **PR13** opakovateľné automatické testy (headless sada pre plánovač/identity/zóny/čelá/migrácie + GitHub Actions CI od nuly; testy si presmerujú %APPDATA%) · **PR14a/b/c** rozdelenie panela (CSS+JS von → Ruby split podľa domén → dedup 6× duplikovaných zoznamov polí + verzia z Ruby + re-attach observera po File>New) · **PR15** BuildPlan kontrakt (validátor, `warnings[]`, tvar `hardware[]`, verzia schémy plánu) · **PR16** in-SketchUp runner + undo/redo scenáre v ENGINEtests.skp
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
| 16.7. | **Zložka pluginu** — konsolidovať súbory „rozliate" po RUBY zložke pod jednu strechu | ✅ hotové (PR #4, 16.7. — SYSTEM + docs + zdroje v repe) |
| 16.7. | **Interact pre čelá** (na neskôr): dráhy otvárania dvierok/šuflíkov, klik = otvorenie, merač kolízií pri otvorení — prezentácia, kontrola, pohľad dnu | Po V1.0 (dáta máme: origin čiel na hrane pántu; premyslieť pri kovaní — typ pántu = dráha) |
| 16.7. | **Vyhradený testovací projekt `ENGINEtests.skp`** (Michal vytvorí prázdny) — agenti v ňom testujú/mažú podľa uváženia; oddelenie od zákaziek (incident: 2 okná + zombie proces na porte 7891) | Umiestniť do `ENGINE\_dev\` · pridať `_dev/` do .gitignore · pravidlo do ENGINE\CLAUDE.md (bridge len v test okne/projekte) → docs PR po V0.2c |
| 16.7. | **BUG: drag priečky funguje len raz** — ďalšie ťahy vyžadujú re-klik na objekt (objekt pritom ostáva označený) | ✅ opravené (PR #2 + #3, 16.7. — suspend_selection_sync) |
| 16.7. | **Náhľad povýšiť na „otvárací náhľad"** panela + zobrazovanie zvolených elementov (dvere, korpus, dielec) | Neskoršie verzie — SYSTEM\07 |
| 16.7. | **UI mockup „NOXUN Furniture Engine"** — taby MODEL/VÝROBA/MATERIÁLY/KOVANIE, strom so stavmi, info karta dielca, ABS editor s „Použiť na podobné diely", katalóg podľa výrobných tried, kusovníky, kontrola, exporty lišta | Rozpísané v **SYSTEM\07_UI_VIZIA.md** (čo preberáme a kedy); syntéza s dilemou 05: kompaktný Inspector pri kreslení + veľké okno „Výroba" na kontrolu/výstupy |
| 16.7. | **Materiály: povolené hrúbky na rodine** — vyberať dekor/typ (K009 DTDL), hrúbka je vlastnosť dielca; rodina definuje povolené hrúbky (3/16/18); dielec mimo povolených → okamžitý „!" v kusovníku + preklik na dielec | V0.5 (výroba/validácia) — mení model výberu materiálu v UI |
| 16.7. | **ABS UX v2**: hrúbky stačia 1/2 mm; ABS sa nevyberá osobitne — odvodené od materiálu dielca; **predvolená ABS pre celú skrinku + výnimky per dielec**; v UI zjednotiť (žiadny nekonečný zoznam), interné delenie per hrana ostáva | V0.4/V0.5 — pred kusovníkom |
| 16.7. | Prepínanie typu HORNÁ/DOLNÁ na označenom korpuse občas zle funguje — zatiaľ neriešiť, vyžiada si komplexnejšie riešenie (knižnica/editor typov) | odložené — rieši sa s knižnicou typov |
| 17.7. | **Undo/redo riziká** (audit kódu): po Undo scale sa absorpcia pravdepodobne spustí znova (observer bez undo guardu — Undo „bojuje" s používateľom); kópia skrinky dostáva nové ID mimo undo operácie a spúšťa sa aj z kliknutia (selection event mutuje model); transparentné ghost operácie po Undo mažú Redo stack | ⚠ **POTVRDENÉ runnerom 17.7.** (`tests/sketchup/su_runner.rb`, scenáre S1/S2): undo po absorpcii sa neudrží (re-absorpcia), kópia má po undo nekonzistentný medzistav (nové cid mimo operácie). Fixy = samostatné malé PR po V0.3.4 (kandidát: porovnanie so stable_transform pred absorpciou; dedup zápis + rebuild v jednej operácii) |
| 17.7. | **Zmazanie ABS záznamu z katalógu ticho mení výrobné dáta** — existujúce priradenia sa pri najbližšom rebuilde premenia na explicitné „bez hrany", bez upozornenia | V0.3.4 — PR15 warnings kanál |
| 17.7. | **Tichá migrácia part_key môže ticho zlyhať** — rescue v migrate_legacy_part_keys vráti nemigrované dáta bez hlásenia (strata override mapovania) | V0.3.4 — PR15 warnings + PR16 fixture test starého modelu |
| 17.7. | `SCALE_TOOL_MASK = 7` — bitová maska osových scale úchopov nepotvrdená (alternatíva 120); TODO žije len v komentári kódu | otvorené — Michal potvrdí vizuálne pri testoch |
| 17.7. | **„Použiť na podobné" úplne odstrániť** (rozhodnutie Michala — nefixovať N-undo správanie, funkcia ide von; vráti sa premyslená až s kovaním) | ✅ hotové (PR #14, 17.7.) |
