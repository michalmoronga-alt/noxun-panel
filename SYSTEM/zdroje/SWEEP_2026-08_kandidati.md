# Kandidáti do registra 1c — výstup post-hoc sweepu #186–#226 (27.8.2026)

> **Stav: ZDROJ — surový zoznam nálezov, NIE zadanie.** Nič z tohto sa neimplementuje priamo odtiaľto.
> Je to **odovzdávka pre blok 1c AUDIT KÓDU**: pri jeho štarte sa tieto položky preleju (s dedupom a s R-číslami)
> do `SYSTEM/AUDIT_REGISTER.md`. Príbeh, metodika a bilancia sweepu sú v [../archiv/KRONIKA.md](../archiv/KRONIKA.md), záznam **1b-E**;
> zaradenie do dávok drží [../PLAN.md](../PLAN.md).
>
> **Prečo je tento súbor v repe:** pracovné výstupy sweepu (plné verdikty, dôkazy `súbor:riadok`, triáž threadov) žili v gitignorovanom
> `_dev/`. V čistom klone repa neexistujú, takže bez tohto zoznamu by sa dala z KRONIKY obnoviť len bilancia, nie samotné nálezy
> (nález review #245 P2). Tu je preto **vecný obsah** všetkých otvorených kandidátov — v skratke, ale s adresou v kóde.
>
> **Čísla riadkov sú stav k `main` @ `0070697` (v0.8.8) — to bola základňa sweepu, nie dnešný `main`.** Platí to hlavne pre
> `ui/production_core.rb`, ktorý PR #244 posunul o ~116 riadkov: v tomto súbore sa orientuj podľa **mena metódy**, nie podľa čísla
> (dnešné pozície kľúčových metód: `fresh_collect` `:591` · `dup_id_suffix` `:661` · `material_label` `:780` · `cp_warnings` `:1461` ·
> `project_name` `:273` · `save_vepo_settings` `:42`). Pri audite treba každý nález **znova overiť proti vtedajšiemu `main`** — presne to
> bola najdrahšia lekcia sweepu (fáza ŠTÚDIO zrušila šesť okien a časť starých ciest fyzicky neexistuje).

---

## A · Stále platné nálezy zo sweepu diffov (spätný Codex pohľad na zmergovaný kód)

Sedem nálezov nižšie je z **hlavnej session** sweepu (34 PR). Bilancia „10 stále platných" v KRONIKE je **7 + 3 z pilotnej session** —
tie tri sú nižšie ako **C4**, **C5** a **C7**, lebo prišli iným kanálom. Nič sa teda nestratilo, len sú v inej sekcii.

| # | Sev. | Nález | Súbor:riadok | Zaradenie |
|---|---|---|---|---|
| A1 | **P2** | Zotavenie z konfliktu (`mdEditRefresh`) preleje do čerstvého katalógového riadku **všetky** editovateľné stĺpce starého formulára — aj tie, ktorých sa používateľ nedotkol. Čerstvý `row_rev` ostáva, `base_rev` sa omladí, takže ďalší Save prejde cez oba zámky a **ticho vráti cenu / kód / formát, ktorý medzitým prišiel zvonku**. Odznak „zmenené mimo editora" neukáže čerstvú hodnotu ani neponúkne „prevziať z katalógu". | `ui/js/proj_materials.js:1205–1219` (dôkaz `:1211–1213`, `:1216`, `:1227`) | dávka **1b-7** |
| A2 | **P2** | Pamäť rozpísaných riadkov (`trimRowsValue`) si po prvej zmene v ktoromkoľvek riadku uloží **všetky editovateľné stĺpce všetkých riadkov**; `mergeRowsMemory` ich pri ďalšom otvorení vlije do čerstvých riadkov a ponechá im čerstvý `row_rev` → uložením sa vráti stará cena, hoci katalóg medzitým dostal novú. **Bez akéhokoľvek varovania.** Pamäť sa maže len pri ÚSPEŠNOM uložení. | `ui/js/nx_modal.js:680–724` (dôkaz `:680–691`, `:698–724`, `:728–747`, `clearMemory` `:609–618`) | dávka **1b-7** |
| A3 | **P2** | Export s duplicitnou identitou **dobehne s podpočítaným kovaním**: expanzia setov deduplikuje členov účtovaných na `owner_id`, takže dva kusy so spoločným ID dostanú jednu sadu. CSV kovania / XLSX rozpočtu / XLSX ponuky sa **zapíšu** a varovanie príde až v statuse PO zápise. Vedomý kompromis dávky 1b-3 (#240), nie regresia. | `ui/production_core.rb` → `fresh_collect` (vtedy `:475`, dnes `:591`; komentár s priznaným kompromisom hneď pod ňou) | **otázka pre audit 1c**: dokončiť export, alebo najprv vyžiadať dedup tik? |
| A4 | P3 | Filtrovaný Kusovník ukazuje pri odfiltrovaných riadkoch celoprojektové súčty — `totalRow` sa síce pri filtri prepne na počítadlo, ale skupinové medzisúčty sú serverové a pohľady **Platne** aj **ABS** tlačia `ST.totals` bez ohľadu na filter (vrátane prázdneho zoznamu). | `ui/js/studio.js:242`, `:1276–1281`, `:1310` | ≡ B6 nižšie (jeden nález, dva zdroje) |
| A5 | P3 | Zelené číslo semaforu Kontroly: menovateľ je skutočný počet skriniek, čitateľ `dirty` sa počíta LEN z ID prítomných v `placements` → skrinka bez placementu (prázdne ID, degenerované rozmery) sa nikdy nezaráta ako špinavá, čiže je vždy „čistá". Komentár rozdiel zdrojov priznáva, ale tento dôsledok nerieši. | `core/validation.rb:708–719` (komentár `:695–700`) | ≡ B10 nižšie |
| A6 | P3 | `BUD_MORE.sent = true` sa nastaví PRED `budSend`, ktorý však zápis môže len **zaradiť do fronty**. Korelácia v `NX.budgetResult` je len podľa názvu operácie, takže **skorší** inline `custom_update` zavrie ⋯ modal ako „uložené" ešte predtým, než sa náš zápis odoslal; odmietnutý zaradený zápis potom stratí hodnoty. Korelovať podľa vlastného tokenu zápisu, nie podľa mena operácie. | `ui/js/budget.js:1394–1396`, fronta `:1447`, korelácia `:1560–1567` | register 1c |
| A7 | P3 | `dup_id_suffix` aj `cp_warnings` zahadzujú `kind` z `Validation.duplicate_identities` a hlásia „kovanie účtované na vlastníka sa započíta len raz" **aj pre duplicitné DOSKY**, ktoré žiadnu expanziu kovania nemajú → falošné varovanie nad korektným nákupom. Riešiť spolu s C6 (zjednotenie znenia do jednej privátnej metódy) a pritom rozlíšiť `kind`. | `ui/production_core.rb` → `dup_id_suffix` (vtedy `:545–553`, dnes `:661–670`) · `cp_warnings` (vtedy `:1349–1356`, dnes `:1461`) | register 1c |

---

## B · Stále platné nálezy z triáže historických review threadov (18 unikátnych)

Zdroj: 54 nezodpovedaných Codex threadov z PR #186–#226 (`isResolved == false`, jeden komentár, autor `chatgpt-codex-connector`).
Rozdelenie po dnešnej severity: **P1 = 0 · P2 = 2 · P3 = 16.**

| # | Sev. | Nález | Súbor:riadok | Vrstva / stav |
|---|---|---|---|---|
| B1 | **P2** | Názov projektu zadaný pred prvým uložením sa po Ctrl+S stratí — všetky štyri exporty spadnú na názov `.skp`. Test to maskoval rovnakým guid. | `ui/production_core.rb` → `project_name` (dnes `:273`) · test `tests/pure/test_st1a_studio.rb` | **VYRIEŠENÉ** dávkou 1b-6a (PR #244, v0.8.9) |
| B2 | **P2** | Hlavičky skupín materiálov sú nerozlíšiteľné pri záznamoch líšiacich sa výrobcom/typom/formátom/rubom; kolízny aparát v repe existuje, ale výstupy ho nepoužívajú. | `ui/production_core.rb` → `material_label` (vtedy `:664–671`) — vs. kolízny aparát `core/materials.rb` → `sheet_label_suffix` (`:991`) | **VYRIEŠENÉ** dávkou 1b-6b (v0.8.11) — zvyšok menoviek v `core/` je nový kandidát **C14** |
| B3 | P3 | Mŕtvy hardware override sa v sekcii Pravidlá kreslí ako aktívne ručné rozhodnutie (zberač kontroluje len existenciu dielca, nie zhodu so živým pravidlom). | `core/bom.rb:197–207` (vs. `core/hardware_rules.rb:562`) | model/výstupy |
| B4 | P3 | UNI katalógová hrúbka sa publikuje ako hrúbka skupiny/nákupného riadku, hoci je len default roly. | `ui/production_core.rb:583` · `ui/js/studio.js:1147`, `:1268` | výstupy |
| B5 | P3 | Zdrojový materiál duplákov (len v `sheet_estimate`) sa v Platniach kreslí ako holé ID bez hrúbky a farby. | `ui/production_core.rb:574–586` · `ui/js/studio.js:1224–1268` | výstupy |
| B6 | P3 | Súhrn Platní a ABS ignoruje filter a hlási celoprojektové čísla (Dielce to robia správne). | `ui/js/studio.js:1276–1282`, `:1310–1313` | UI · ≡ A4 |
| B7 | P3 | Nominálna trieda ABS („jednotka") sa vypisuje ako konkrétna hrúbka „1,0 mm", hoci resolver z nej vyberá 0,8/1,0/1,2. | `ui/rules_dialog.rb:192`, `:195` | UI text |
| B8 | P3 | „Jediná sekcia, ktorá mení model" už neplatí — Pravidlá, Šablóny aj predvoľby setov zapisujú. Nepravda je v kontrakte **aj v hinte, ktorý vidí používateľ**. | `ui/js/studio.js:139` (SEC_META.budget hint) · `zdroje/ui20/UI20_KONTRAKT.md:480` | UI + docs |
| B9 | P3 | Klik na riadok Štúdia zahodí rozpísanú editáciu Inspectora — chýba guard, ktorý majú všetky štyri exportné relaye. | `ui/js/bridge.js:325–329` | UI |
| B10 | P3 | Skrinka bez platného placementu s nálezom padne do zeleného počtu „bez nálezov". | `core/validation.rb:707–719` | výstupy · ≡ A5 |
| B11 | P3 | `GrainCheck.restore!` pri otvorení Štúdia nerozposiela stav → rail Inspectora tvrdí opak reality. | `ui/studio_dialog.rb:161–167` · `core/grain_check.rb:367–373` | UI |
| B12 | P3 | Jantárové override riadky sa po zápise z Inspectora neobnovia (prídu až s plným `push_state`). *Kolízia so zámerným ručným refreshom Štúdia — je to rozhodnutie o kontrakte okna, nie bugfix.* | `ui/panel/actions_parts.rb`, `ui/panel/actions_hardware.rb` | UI |
| B13 | P3 | Poznámka „pravidlo podľa roly sa neuplatní" je pri čiastočnom override nepresná — nemenované hrany pravidlo držia ďalej. | `ui/rules_dialog.rb:226–228` | UI text |
| B14 | P3 | `vepo_settings.json` read-modify-write bez medziprocesového zámku. **VYRIEŠENÉ dávkou 1b-6c** (v0.8.12). | `ui/production_core.rb` → `update_vepo_settings` · `core/json_file_store.rb` | perzistencia · hotové |
| B15 | P3 | Scroll sekcie neprežije prepnutie — kontrakt §67 to vyžaduje (`renderStudio` prepisuje spoločný kontajner bez uloženia `scrollTop`). | `ui/js/studio.js` (žiadny `scrollTop`) · `UI20_KONTRAKT.md:67` | UI |
| B16 | P3 | D-87 nemá vlastný `### ` nadpis, jeho text je vnorený do sekcie D-50. | `archiv/DOGFOODING_vyriesene.md:114–135` | docs |
| B17 | P3 | Odložený XLSX/CSV export kusovníka nemá v PLANe vlastníka (kontrakt sľubuje „vlastnú dávku"). | `SYSTEM/PLAN.md` | plán |
| B18 | P3 | In-SU beh: `run_st1b` nechá zapamätaný prepínač kresby zapnutý, ďalšie sekcie bežia s overlayom. | `tests/sketchup/su_runner.rb:5720–5727` | testy |

---

## C · Ďalší kandidáti zozbieraní počas bloku 1b (mimo hlavnej session sweepu)

**C4, C5 a C7 sú tie tri nálezy z pilotnej session**, ktoré dopĺňajú sekciu A na bilanciu „10 stále platných".
Zvyšok sú postrehy z dávok a review kôl bloku 1b.

| # | Nález | Zdroj |
|---|---|---|
| C1 | `@stable_transforms` v `core/scale_observer.rb` sa nikdy neupratuje — kľúč `[model.object_id, entityID]`, žiadna delete cesta; 115 záznamov v plnom behu. Hygiena/pamäť. | dávka 1b-2 |
| C2 | Beh sady `CHAR` skončí s vymazanými projektovými snapshotmi kovania (`Sketchup.undo` odundoval zápis z CH4b) — neškodné, patrí komentárový riadok do `run_char`. | review #239 |
| C3 | Globálny teardown vo `walk` rescue nepozná `EdgeCheck`/`GrainCheck.disable!` — pri FAIL uprostred CH6 by overlaye ostali zapnuté; pri rozšírení `CHAR` pridať k `d101_teardown`/`stale_teardown`. | review #239 |
| C4 | Historický nezodpovedaný P1 z #186 (21.8.): async edge/material callback môže zapísať po odznačení dielca. **Triáž threadov ho medzitým uzavrela ako VYRIEŠENÝ** — `ui/panel/actions_parts.rb` → `part_target_error` (commit `e83abe4`, PR #187) odmieta obe cesty pri prázdnom výbere. Ostáva len ako záznam, nie ako úloha. | pilotný sweep |
| C5 | Historický nezodpovedaný P2 z #186 (21.8.): výmena náhľadu šablóny prepíše starý súbor pred stagingom. **Triáž ho tiež uzavrela ako VYRIEŠENÝ** — `core/template_previews.rb` → `stage_then_rename` (ten istý commit `e83abe4`): pri zlyhaní ostáva starý náhľad nedotknutý. | pilotný sweep |
| C6 | Znenie varovania o duplicite je v kóde **dvakrát** (`dup_id_suffix` + `cp_warnings`) — pri budúcej zmene wordingu zjednotiť do jednej privátnej metódy. Riešiť spolu s A7. | review #240 |
| C7 | Prechody stavu kresby sa nebroadcastujú pri kombináciách otvorenia/zatvorenia okien (`restore_grain_check` / `GrainCheck.disable!`). **Nález je nad starou hlavou — okno Výroba zaniklo**; overiť, či ekvivalentná cesta existuje v Štúdiu (broadcaster v `main.rb`). | sweep #189 · ≡ B11 |
| C8 | `CH4c`: chýba východiskový assert sondy pred `Sketchup.undo` (vákuové riziko; v behu ho kryje CH1) — doplniť pri najbližšom dotyku `CHAR`. | review #242 |
| C9 | `CH2` fáza 2: `char_copy` dostáva referenciu drženú cez interné Undo bez `valid?` guardu — dofetch podľa `ch2_cid`. | review #242 |
| C10 | **Identita zákazky je trojitá** — normalizovaná cesta + `guid:` kľúč sedenia + most v pamäti procesu. Zvážiť vlastné stabilné ID zákazky v NOXUN dictionary, ktoré by celú kaskádu zrušilo. *Zásah do dátového kontraktu ⇒ vlastná dávka.* | PR #243 |
| C11 | `ProductionCore.project_name` je **čítanie, ktoré v prechode neuložený→uložený zapisuje nastavenia** — vzor „čítacia cesta s vedľajším účinkom", ktorý sa už raz vypomstil (dávka 1b-3). | PR #243 |
| C12 | Migrácia názvu „už pri uložení, nie až pri prvom čítaní" by chcela save lifecycle callback = observer, teda **audit-povinnú** zmenu — vedome neopravené v #243. | PR #243 |
| C13 | `vepo_settings.json` mal **viacero zapisovateľov bez medziprocesového zámku** (`save_merge_18_36`, 4× `last_dir`). **VYRIEŠENÉ dávkou 1b-6c** (v0.8.12, 28.8.): jedny zamknuté dvere `update_vepo_settings` + mapa názvov výhradne cez `update_project_names`; všetky tri nálezy kola 3 z #243 sú zapracované. Ostáva len ako záznam. | PR #243 · ≡ B14 |
| C14 | **Menovky materiálov sú v `core/` ešte dvakrát** — `core/budget.rb` → `sheet_label` (riadok rozpočtu aj XLSX: dekor + typ + hrúbka, bez výrobcu a rubu) a `core/cp_export.rb` → `material_label` (zákaznícka ponuka; `cp_nazov` má prednosť, fallback skladá vlastný text). Dávka **1b-6b** ich vedome nechala: sú v `core/`, kam panelový aparát (`Panel.label_ctx`) nedosiahne — zjednotenie znamená presun kolízneho aparátu do `Materials`. Rozpočet je nákupný dokument, takže dvaja výrobcovia toho istého čísla v ňom majú dodnes identický riadok. | dávka 1b-6b |

---

## Ako sa to prelieva do registra 1c

1. **Dedup najprv, potom R-čísla.** Známe zhody: A4 ≡ B6 · A5 ≡ B10 · A7 ≡ C6 · B11 ≡ C7 · B14 ≡ C13.
2. **Vyradiť to, čo je medzitým hotové** — B1 je vyriešené (1b-6a), **B2 je vyriešené (1b-6b, v0.8.11)**, A1/A2 sú vyriešené (1b-7, v0.8.10), C4 a C5 sú vyriešené (commit `e83abe4`), **B14/C13 je vyriešené (1b-6c, v0.8.12)**. Otvorených z triáže je teda **15 z 18**.
3. **Overiť proti vtedajšiemu `main`** — hlavne C7 (nález nad starým stromom, okno Výroba zaniklo) a všetky citácie do `ui/production_core.rb`.
4. Až potom priradiť **závažnosť, vrstvu a blokovanú funkciu** podľa šablóny registra ([../PLAN.md](../PLAN.md), blok 1c).
