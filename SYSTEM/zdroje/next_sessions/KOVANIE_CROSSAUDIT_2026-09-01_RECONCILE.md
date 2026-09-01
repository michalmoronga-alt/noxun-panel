# KOVANIE V1 — CROSS-AUDIT RECONCILE (2026-09-02)

> Syntéza troch nezávislých auditov Round 2 architektúry: **Codex** (implementácia vs kód, UNSAFE-as-written)
> · **GLM** (dátové toky a value-vs-complexity, SOUND WITH CHANGES) · **blind Opus** (tiché zlyhania, SOUND WITH CHANGES).
> Zdroje: `KOVANIE_CROSSAUDIT_2026-09-01_RESULT_{CODEX,GLM,OPUS}.md` nad source packom + checkpoint #10.
> Toto je JEDINÉ reconcile kolo. Výstup: prijaté zmeny architektúry (§2), rozhodnutia pre Michala (§5), dopad na slicing (§6).

## 1. Bilancia verdiktov

Všetci traja: **jadro architektúry drží** (owner=čelo, computed context, recepty ako dáta, reuse setov/expanzie/brán,
žiadny nový BOM/validačný subsystém — každý to nezávisle overil v kóde). Všetci traja: **migračná/kontraktová vrstva
má diery, ktoré by prežili navrhované testy**. Codexov verdikt „UNSAFE" a „SOUND WITH CHANGES" ostatných dvoch je
ten istý obsah s inou nálepkou: bez opráv §2 sa implementácia nesmie začať; s nimi áno. Žiaden nález nevyžaduje
redizajn ani návrat k zavrhnutým konceptom (stavové zóny, assembly owneri, revízne reťazce ostávajú zamietnuté).

## 2. KONSENZUS — prijaté zmeny architektúry (záväzné pre packages)

**R1 · Recepty dostávajú PROJEKTOVÝ SNAPSHOT + verziu** *(Opus F-1 + Codex C5; GLM nenamietal)*.
Zrkadlo `ensure_project_rules!`: recipe dáta sa pri stavbe zmrazia do modelu, `recipe_version` v drawer configu,
snapshot sa NIKDY nemení sám; update len explicitnou akciou s diffom (vzor `merge_project_seed!`). Bez toho prvá
korekcia dát (H70 92→105 už čaká) ticho prereže staré zákazky. Charakterizačný test porovnáva CONTENT riadkov
(nie bajty — `generated_at` v CSV, GLM I3).

**R2 · Exkluzivita `slide`: resolver potláča legacy pravidlo v KÓDE** *(Opus F-2 + GLM C1)*.
Snapshoty sú zmrazené → data-only fix nemožný. Engine potlačí `fit_series`/slide pravidlá pre drawer-klasifikované
čelá s viditeľným build warningom; test „jedno zásuvkové čelo → presne jedna slide položka"; **migrácia D-93 NL
zámkov** (rule_id `vysuvy-nl-podla-hlbky` → resolver identita, alebo hard conflict — nikdy tiché zmiznutie; Opus F-3).
Bonus nález Opus: seed séria obsahuje NL 560 (v Atire neexistuje) a clearance 10 vs oficiálne NL+15 — recepty to opravia.

**R3 · Zámky žijú VÝHRADNE v `hardware_overrides`** *(GLM C2 — nález rozporu §5.1 vs §2 v samotnom source packu)*.
Drawer blok vo fronts confige nesie LEN klasifikáciu (family, system, variant); všetky manuálne osové hodnoty =
rozšírené polia hardware_overrides (D-93 sémantika zámok=existencia poľa, existujúce reset/zber/UI cesty).

**R4 · `code_by_height` sa NEROBÍ** *(3/3: Opus FC-1, Codex C2, GLM C3+F1)*.
Member kontrakt je XOR (code|code_by_nl|param_bands). Kit výber = **mapping selector pásma na height-variant
parame → per-height SETY, vnútri code_by_nl** (GLM konštruktívny dizajn, precedens D-81/nohy-podla-sokla).
MEMBER_KEYS nedotknuté v tejto časti = menšia migračná plocha.

**R5 · `custom` generic type sa NEROBÍ; ad-hoc = vlastný pass-through kanál** *(3/3)*.
`config['hardware_manual'][]` s vlastným poľom, expand vetví podľa PÔVODU pred set rezolúciou; serverová
normalizácia + limity, plný snapshot code/name/mj/price (aj pri katalógovej položke), owner join s odfiltrovaním
mŕtvych kľúčov (vzor collect_manual_overrides), stale kód → `missing` flag (row_join vzor), explicitné template
pravidlo, zahrnutie do duplicate-ID konfliktu (Codex #7 kontrakt). „Save to catalog" bridge odložený.

**R6 · Materiál a hrúbka zásuvky sa riešia PRED plánom ako štvrtý materiálový kanál** *(Codex C1 + Opus F-5 + GLM M5)*.
`:drawer` do material enum validate_part!, 4. PROJECT_KEY + nemazateľný fallback, `eff_drawer` v effective_materials,
D-46 pending-confirmation reuse; hrúbka = VSTUP receptu validovaný proti systému (Atira len 16; Quadro 16/18);
`thickness_ok_for?` + `materialized_part` rozšíriť o VŠETKY nové roly (aj flap/cover_panel/false_front — inak
19 mm čelný materiál zhodí stavbu, Opus F-5a).

**R7 · `context_for` počíta z INTERIÉRU a kontroluje VŠETKY prekážky** *(Opus F-4/TOP-4 + Codex M3 + GLM I4)*.
Zvislý priestor = prienik z-intervalu riadku čela s interiérom (z_lo/z_hi, rail_geometry) A listovou zónou;
16 mm offset riadok-vs-interiér = named test case; kontrola prieniku so shelf + divider_h + divider_v
(divider cez riadok zásuvky = konflikt; Opus žiada hard, GLM/Codex ORANGE — rieši R9 tabuľka). Svetlá šírka
z listovej zóny, nie w−2t. Dôvod tvrdosti: zarga sa nekreslí → vizuálna kontrola túto triedu chýb NEVIDÍ.

**R8 · Tvar recipe dát doplnený** *(GLM I1/I2 + Codex C2 + addendum #10)*.
`min_depth` = (NL × opening) tabuľka (NL260: 279/305 — konštantný vzorec falzifikovaný); **KD→EB/runner-variant
mapa ako PIATY vstup** + orderable-stock flag (EB patrí k SKU); kľúč receptu = (system, runner_variant, mounting,
rear_type) persistovaný per čelo — mounting V1 pin `slide_on`, bez UI (GLM F5); availability matica vrátane
opening×load interakcií; sync tyč P2O trigger `width>600`; `inner_supported` ako JEDNO engine pravidlo
(internal nerezolvuje recept — hard conflict), nie per-system flag (Opus FC-5); sety sa SEEDUJÚ z recipe NL
série + completeness test (GLM M6/I3).

**R9 · Validačný kanál: nový ADITÍVNY collected kľúč pre hard hardware konflikty** *(GLM C4 + Opus I-5 + Codex #5)*.
Build-warning kanál je ORANGE-only — RED stavy zásuviek/setov idú novým aditívnym kľúčom zberu (precedens
identities/cabinet_set_conflicts), jediný čitateľ = Kontrola + brána, prepočet ČERSTVÝ pri exporte (nikdy DOM).
**Fail-closed na geometrii**: nevyriešený recept NEEMITUJE dielce (part_skipped_degenerate vzor; Opus F-6) —
tým je VEPO chránené bez brány. **P2O sync tyč**: kým je za R-06a ORANGE, jej chýbanie v objednávke rieši
brána z R10/O2 (Codex C4).

**R10 · D-109 ratio člen sa vo V1 NEIMPLEMENTUJE** *(GLM F2 + Codex C3 + Opus I-6; podlieha O3 nižšie)*.
V1 výsledok identický cez druhé bands pravidlo na šírku korpusu (klipy 1/2 podľa <1000/≥1000); ratio mechanika
(agregačná fáza + provenance + STD bump) ide s R-05 po V1. Drží D-94 invariant čistý.

**R11 · Whitelisty a std bumpy = atómové dávky s exit testami** *(3/3)*.
Nové front polia musia prežiť 5 ciest (normalize_items, config_to_params, normalize, cabinet_config,
template_config_from) — per-path round-trip charakterizácia = exit kritérium slice A; VŠETKY zmeny schémy
členov/setov (klasifikácia + prípadné nové polia) v JEDNOM std bumpe so snapshot_std detekciou v tej istej
dávke; `hardware_manual` do normalize + CONFIG_SCHEMA bump. Polia direction/opening_mode scopované per
front_type (GLM F4 — blenda bez otvárania, zásuvka bez smeru; „Neurčený" nesmie strieľať kde smer neexistuje).

**R12 · Drobné povinnosti** *(jednotliví audítori, prijaté)*.
`human_label` vetvy pre drawer_* kľúče (Codex I3) · material signals enum rozšíriť (Codex I4) · šablóna vs zámky:
🔧 badge nesmie tvrdiť, čo whitelist nenesie — buď preniesť relevantné overridy, alebo priznať v UI (Opus I-3 /
Codex I2; doriešiť v package slice I) · prune_none_front_overrides vs H4: jedno pravidlo pamäte pri prepnutí typu
(Opus I-4) · ABS rozhodnúť PER rolu — mechanika default-nič je zadarmo (Codex), ale viditeľné bočnice Quadro boxu
= produktová otázka pre Michala v detail fill (Opus I-1) · do_hw_csv blocker pri generic typoch neznámych tomuto
pluginu ALEBO version-pair viditeľnosť ako D-52 akceptácia (GLM I7) · exporty pri blockeri dokazujú PRÁZDNY
cieľový priečinok (Codex risk map).

## 3. NEZHODY a odporúčanie

**N1 · `drawer_no_fit` brána.** Codex: tvrdý nepotvrditeľný blocker HW CSV + cenových. GLM: tvrdý blocker s 3
podmienkami (čerstvý prepočet, nie VEPO, nový kanál). Opus: NIE blocker — fail-closed dielce + RED + unmapped
riadok, nanajvýš confirmations (dôvod: doktrína P0-HF #250 „neber platný výstup rozpracovanej zákazke";
nevyriešená zásuvka je vysvetliteľný design-stav ako riadky bez ceny).
**Odporúčanie (2:1 + syntéza):** fail-closed dielce (R9, nesporné) + **tvrdý blocker** pre nákupný CSV a cenové
exporty podľa GLM podmienok. Dôvod: na rozdiel od riadku bez ceny tu NEchýba číslo v riadku — chýba CELÁ
komponentná sada zásuvky, teda „objednávka, o ktorej vieme, že je podpočítaná" = existujúca definícia tvrdej
vetvy; a priorita produkcie naostro (chyby nákupu = top). Opusov UX argument sa mitiguje presnou hláškou
(ktorá zásuvka, prečo, kam kliknúť). → **rozhodnutie O2 pre Michala.**

**N2 · Tvrdosť kolízie priečky s riadkom zásuvky.** Opus: hard (oko to nevidí — zarga sa nekreslí); GLM/Codex:
ORANGE. **Odporúčanie:** divider (v aj h) pretínajúci riadok zásuvky = RED cez R9 kanál (rovnaká trieda ako
drawer_no_fit — fyzicky nevyrobiteľné); tesné-ale-platné stavy = ORANGE. Nie je to samostatné rozhodnutie
Michala — vyplýva z O2.

## 4. False positives / vzájomné korekcie

- Opusovo „ABS default nič = riziko" vs Codexovo „prázdne ABS pravidlá netreba" NIE JE spor: mechanika je zadarmo
  (nil hrany), produktové rozhodnutie o viditeľných bočniciach ostáva (R12).
- Opusov F-2 tvrdil dvojitý nákup „kitu" — presné je, že dedup kryje len per:'owner'; per:'unit' členy sa duplikujú
  (GLM C1 formulácia je presnejšia). Výsledok rovnaký, prijaté ako R2.
- Codexov C2 („code_by_nl+code_by_height nekompatibilné") a GLM C3 sú ten istý nález; GLM dodal riešenie — prijaté R4.
- Žiadny audítor nespochybnil: computed context bez zón · owner=čelo · Active/Inactive · šablónový freeze ·
  agregáciu s pôvodom · HK+HL/HF-out · Atira+Quadro scope. Tieto časti Round 2 sú potvrdené 3/3.

## 5. ROZHODNUTIA PRE MICHALA (posledné otvorené)

**O1 · Smer dvierok — 3/3 audítori odporúčajú protinávrh:** RED v Kontrole hneď, exportná brána až s prvým
výstupom, ktorý smer reálne nesie (D-95/výrobné zadanie), s tvrdými podmienkami: žiadny default/heuristika
nikde v kóde; legacy configy bez poľa sa negatujú; brána pre-committed v registri a pristane v TEJ ISTEJ dávke
ako direction-consuming výstup. Tvoje pôvodné rozhodnutie (blokovať final output hneď) ostáva platné, kým ho
sám nezmeníš. **a) prijímam protinávrh s podmienkami (odporúčanie 3/3) · b) trvám na okamžitej bráne.**

**O2 · `drawer_no_fit`:** **a) tvrdý blocker** HW CSV + cenové exporty + fail-closed dielce (odporúčanie
reconcile, Codex+GLM) · b) len potvrditeľný dvojklik (Opus) — v oboch prípadoch fail-closed dielce a RED platia.

**O3 · D-109 vo V1:** audit ukázal, že ratio člen = R-05 agregačná fáza (väčší zásah než sa zdalo). Návrh:
V1 dosiahne TVOJ výsledok (1 klip na začaté 4 nohy, per skrinka) druhým pravidlom na šírku; ratio mechanika
príde s R-05 po V1. **a) súhlasím s odkladom mechaniky (odporúčanie) · b) chcem plný ratio člen už vo V1.**

*(ABS viditeľných bočníc Quadro boxu a template-locks správanie = detail fill, nie architektúra — prídu ako
otázky v príslušných packages.)*

## 6. Dopad na slicing a riziká

Poradie slices drží (0→A→B→C→D→E→F→G→H→I; H môže hneď po A). Zmeny: slice A exit = per-path round-trip
charakterizácia + starý-projekt test (3/3) · slice B absorbuje VŠETKY zmeny schémy setov v jednom bumpe
(vrátane klasifikácie; R4 selector dizajn) · slice C nesie R1 (snapshot receptov), R6 (4. kanál), R7 (context),
R8 (tvar dát) — ostáva HIGH, in-SU povinné · slice D nesie R2 (potlačenie+migrácia zámkov s korpusom reálnych
.skp fixtures PRED dávkou), R3, R9/O2 · slice G klesá na LOW (R10) · slice H LOW–MEDIUM s Codex #7 kontraktom ·
slice I musí vyriešiť R12 šablóny/zámky. Risk mapy troch auditov sú zhodné v HIGH bodoch (A/C/D) — žiadny
slice nie je „hotový návrh", každý dostane package s audit-povinnosťou podľa CLAUDE.md pravidiel.

## 7. Ďalšie kroky

1. Michal rozhodne O1–O3.
2. Orchestrátor zapracuje R1–R12 + O rozhodnutia do finálneho architektonického dokumentu (amendment source packu)
   — ten sa stane podkladom pre packages; ŽIADNE ďalšie veľké návrhové kolo.
3. UI mockup (Čelá/Kovanie/Zóny show-hide, per checkpoint #01 §3.2).
4. Detail fill: PDF follow-upy (#10), Demos kit-vs-atomic SKU audit, ABS bočníc, prahy závesov.
5. Task packages per slice (šablóna 1e) → implementácia.
