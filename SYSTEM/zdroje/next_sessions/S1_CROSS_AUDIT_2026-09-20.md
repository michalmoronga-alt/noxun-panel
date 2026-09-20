# S1 cross outside-in audit ×3 — syntéza a reconcile (20.9.2026)

> Stav: KONCEPT — research packet + reconcile, neimplementovať priamo · zdroj: tri nezávislé outside-in audity s rovnakým promptom (Codex Astra · Grok 4.6 · Gemini Flash cez
> Antigravity), 20.9.2026 01:30–01:50 · auditovaný návrh: [V1_DEBATA_2026-09-20_SPOTREBICE_POLIA.md](V1_DEBATA_2026-09-20_SPOTREBICE_POLIA.md) (D1 katalóg · D2 spotrebič v zákazke
> · D3 slot umývačky · D4 telo chladničky + kontroly · D5 expects · D6 UI) · surové packety: [S1_CROSS_AUDIT_2026-09-20_packety.md](S1_CROSS_AUDIT_2026-09-20_packety.md) ·
> **reconcile robí orchestrátor, rozhodnutia potvrdzuje Michal (§4)** · probe snippety v SketchUpe (§5) sú podmienkou prijatia nálezov SIMPLER NATIVE PATH / ALREADY EXISTS.
>
> Pred implementáciou platí postup z [README.md](README.md).

## 0 · Metóda a kvalita dôkazov

- **Rovnaký prompt** (kontext enginu, návrh D1–D6, non-goals, 7 otázok, formát tabuľky s kategóriami ALREADY EXISTS · SIMPLER NATIVE PATH · CAD PRECEDENT · MISSED CONSTRAINT ·
  GOOD CUSTOM SOLUTION · RESEARCH GAP · NO ACTION, VERIFIED/UNVERIFIED, licencia). Codex navyše smel čítať repo (potvrdil proxy kontrakt `cabinet_builder.rb:2024`, layout čiel
  `fronts.rb:139/198` a rozpočtový spotrebič `budget_store.rb:412`).
- **Behy:** Codex Astra 8 min (+1 % Codex weekly) · Grok 4.6 xhigh headless, len `web_search`+`web_fetch`, 23 otvorených zdrojov · Gemini 4 malé behy (3.8 Flash high; jeden beh
  zdegeneroval do nezmyselného textu → všetky otázky zopakované na 3.7 Flash high). Pasce nástrojov: §6.
- **Váha dôkazov (orchestrátor):** Grok a Codex citujú **konkrétne dokumenty s číslami** (Bosch FR stránka dvierok, All-in+ 14.4.2026, Nobilia XL 2026, Beko 7690661671, Bosch
  SBT8ZD801A/KIV38X20, Miele G 7000/G 7672, Liebherr Design Guide/FAQ, Winner help články s dátumami, OCL docs, ETIM EC011315, SU API). Gemini označuje VERIFIED aj pri
  homepage URL (bosch-home.com, dcc-moebel.org) a jeho ETIM kódy si protirečia s Grokom → Gemini beriem ako **smerový hlas**, čísla len tam, kde ich potvrdí Grok alebo Codex.

## 1 · Súhrn

**Potvrdené (zhoda 3/3):** D3 slot umývačky ako typ skrinky je dobré vlastné riešenie s funkčným precedensom (Winner „Dishwasher with whole door", IKEA čelá + VÅGLIG, Cabinet
Planner len 3D) · proxy kontrakt referenčného tela cez atribúty je správny, tagy/skrytie sú závislé od scén (OCL GPL: vzory áno, kód nie) · `UI.openpanel` = jeden súbor, HTML
file input nedá cestu, drag-and-drop = RESEARCH GAP · vzor „nika najprv, spotrebič neskôr" (Winner Skip / generic / „32767 Anything", katalóg filtrovaný na niku, žiadny hard block)
sedí s D5/D6 · IDM/ETIM sa nezrkadlia 1:1, vlastný JSON ostáva, preberá sa význam polí.

**Mení návrh (zhoda 3/3, najdôležitejší nález auditu):** **čelo umývačky 826 mm nie je bežná odchýlka od listu.** Výrobcovia viažu výšku čela na **typ uchytenia**: Bosch pevný
pánt 655–725 (81,5 cm) / 705–775 (XXL 86,5), VarioHinge 655–765 / 705–815; Whirlpool WIO max 720; Beko SlideFit do 800 (sokel 60, čelo ≤ 9 kg); Nobilia 864 XL len s posuvným
mechanizmom FSM + sokel od 61–70 + **dištančná lišta 110/65** (= zrejme Michalova „blenda 115"); Electrolux PerfectFit 667–825. **Hmotnosť čela je bezpečnostný limit:** Bosch
2,5–8,5 kg (60/81,5), 3–10 (86,5), 4,5–11 (VarioHinge); Miele 3–10 / 4–11 kg; sokel ≥ 90 štandard, 50–90 len VarioHinge. → D1 dostane typ uchytenia, max výšku čela, hmotnosť
min–max a sokel min–max; D3 dostane **mäkké ORANGE** kontroly (výška čela vs max pre daný typ uchytenia, hmotnosť čela z KOV-W vs max, sokel vs min) — **len keď je model
priradený**, nikdy neblokuje. Rozhodnutie z 6.9. „výška čela a sokel sa nekontrolujú" sa tým mení → **Michal (§4 ot. 1–2)**.

**Mení návrh (chladnička):** pravidlo presah ≥ 10 mm / škára 2 mm je **stolárska prax, nie číslo výrobcu** (Grok RESEARCH GAP, Codex UNVERIFIED) → v Inspectore písať
„odporúčané delenie (prax)", škára `s` z configu čiel (Bosch KIV38X20 počíta nábytkové dvere pre škáru 4 mm, prípustné do 14; Liebherr 3–4 mm). Keď výrobca dá **výkres
nábytkových dverí** (Bosch KIV38X20), jeho rozsah má prednosť → D1 chladnička dostane voliteľné „nábytkové dvere z výkresu: dolné V min–max + referenčná škára". Limity hmotnosti
a hrúbky dverí pre posuvné lišty existujú (Beko US 16,2 / 9 kg, hrúbka 19, > 38 mm limiter; Liebherr overlay ≤ 11,3 kg) → voliteľné polia, V1 len evidencia; door-on-door limity
sa **neprenášajú** na lišty (Liebherr FAQ) → door-on-door ostáva mimo V1.

**Rozpory:** ETIM triedy spotrebičov — Gemini „EC000628 chladničky / EC011270 umývačky / skupina EG000039" (UNVERIFIED), Grok negatívne (EC000625 = car audio), Codex overil len
drezy **EC011315** → ETIM kódy spotrebičov = RESEARCH GAP, pre V1 nepotrebné. Škára chladničky 2 vs 4 mm — vyriešené vyššie (`s` z configu + výkres výrobcu má prednosť).
Blenda 115 — Gemini ju viaže na parozábranu, Grok na Bosch „accordion trim" (max 143), Codex na Nobilia dištančnú lištu (110/65) → **blenda = stolárska/dištančná lišta**,
voliteľný výrobný dielec; parozábranný plech pod PD je len **montážna poznámka**, nie dielec.

## 2 · Nálezy per otázka (Gemini · Grok · Codex → verdikt)

| Q | Nález | Gemini | Grok | Codex | Najlepší dôkaz | Verdikt |
|---|---|---|---|---|---|---|
| Q1 | Slot ako typ skrinky = vlastné riešenie s precedensom; sales-CAD umývačku nerežú | CAD PRECEDENT (Nobilia GSBD, KitchenDraw — generické URL) | GOOD CUSTOM: Winner „whole door" = kód spotrebiča + samostatný kód čela, filler kreslený voľne; IKEA čelá + VÅGLIG; Cabinet Planner len 3D | CAD PRECEDENT: Winner „Dishwasher with whole door" (11.7.2024), nika-first (9.6.2026); kusovník nepotvrdený | Winner články | **berieme — D3 ostáva** |
| Q1 | Delené čelo (2 čelá + spojovacia lišta) je bežná alternatíva k jednému vysokému | — | IKEA VÅGLIG (2+ čelá), Bosch „special solution" split front | Bosch SGZ8BI00 príslušenstvo pre delené čelo | IKEA, Bosch AU datasheet | **mení návrh: slot má 1 alebo 2 čelá** (cez modul čiel, lacné) |
| Q2 | 826 mm > max listu = nie bežná odchýlka; výška čela viazaná na typ uchytenia | MISSED (VarioHinge, PerfectFit, adapt-r; kolízia so soklom ~45–60°) | MISSED: Bosch 655–725/705–775, Vario 655–765/705–815, WIO 720, sokel ≥ 90 / 50–90 Vario | MISSED+CAD: Beko SlideFit ≤ 800, Nobilia 864 XL + FSM + sokel ≥ 61–70 + lišta 110/65, Bosch/Siemens 815 + FSM, Whirlpool/Electrolux 820 + FSM | Bosch FR, All-in+, Nobilia 2026, Beko 7690661671 | **mení návrh: D1 typ uchytenia + max V čela; D3 ORANGE ak model priradený** |
| Q2 | Hmotnosť čela je limit (pružiny/pánt), D1 ju nemá | MISSED (Bosch 2,5–8,5 / max 10, Miele 10–12, WIO 2–10) | MISSED: Bosch 2,5–7,5 / 2,5–8,5 / 3–10 / Vario 4,5–11; Miele 3–10 | MISSED: Beko ≤ 9 kg; Miele G 7672 4–11 (7–14 po servisnej úprave) | Bosch FR, Miele | **mení návrh: D1 hmotnosť min–max; D3 ORANGE z KOV-W `weight_kg`** |
| Q2 | Blenda / dištančná lišta / parozábrana | parozábranný plech (Wrasenschutz) — evidovať ako poznámku | Bosch accordion trim max 143; blenda = stolárska prax, zaznamenať, nevarovať | Nobilia „spacer strip" 110/65 nie je dôkaz polohy tvojej 115 | Nobilia, All-in+ | **berieme: blenda ostáva voliteľný dielec; parozábrana = poznámka v šablóne** |
| Q3 | Pásma dverí spotrebiča → rozsah rezu; presah ≥ 10 je prax, nie výrobca | GOOD CUSTOM (vzorec sedí; „IDM Frontteilung" UNVERIFIED) | CAD: Liebherr publikuje pásy (663→669, +19, medzera 67 → ~3 mm); ≥ 10 = RESEARCH GAP | MISSED: Bosch KIV38X20 dáva výkres nábytkových dverí pre škáru 4 (max 14) → 2 mm nie je štandard | Liebherr Design Guide, Bosch KIV38X20 | **mení návrh: wording „prax", `s` z configu, výkres výrobcu má prednosť (voliteľné pole)** |
| Q3 | Hmotnosť/hrúbka nábytkových dverí pre lišty | MISSED (Blum 91K9550 16–22 mm; Liebherr 10–17,5 kg door-on-door) | MISSED: Beko US 16,2 / 9 kg, 19 mm, > 38 limiter; Liebherr overlay ≤ 11,3 | NO ACTION: door-on-door limity nemožno preniesť na lišty (Liebherr FAQ) | Beko US install PDF, Liebherr FAQ | **berieme čiastočne: voliteľné polia (evidencia), door-on-door mimo V1 ostáva** |
| Q4 | Proxy kontrakt (atribúty) správny; tagy/hidden závislé od scén; OCL filtruje viditeľnosť + materiál Hardware | GOOD CUSTOM (AttributeDictionary, Undo) + MISSED „siroty definícií" | SIMPLER NATIVE PATH = NIE; OCL: len viditeľné komponenty aktuálnej scény, Hardware = počítaný diel; GPL | GOOD CUSTOM; MISSED: SU nemá vnorené undo operácie, meno definície sa pri kolízii uniqnuje, `ComponentDefinition#hidden?` ≠ skrytie inštancie | SU API, OCL docs | **NO ACTION na kontrakte**; siroty už rieši recyklácia definícií podľa mena (`render_hardware`), telo vzniká vnútri regenerácie (1 undo) |
| Q4 | `UI.openpanel` priamo v HtmlDialog callbacku je modálny a láme CEF kanál | — | MISSED: SU fórum 2022 → obaliť `UI.start_timer(0)` | — | forums.sketchup.com/t/212380 | **PROBE P2** (§5); dnešný picker textúr volá openpanel v callbacku — overiť, či cez timer |
| Q5 | Vlastný JSON ostáva; IDM/ETIM sa nezrkadlia 1:1, preberá sa význam polí | CAD: IDM bloky Gerätemaße · Nischenmaße · Überstände · Lüftung/Anschlüsse; ALREADY EXISTS ETIM EG000039 (UNVERIFIED kódy) | CAD: IDM 3.1.0 = katalóg nábytku, nie datasheet; DCC priznáva neúplné niky (Zentra/Furnitec); ETIM kódy RESEARCH GAP | NO ACTION: BMEcat/ETIM xChange = výmenné formáty; import teraz nepridávať | DCC download, ETIM viewer | **berieme: JSON ostáva, polia zoskupiť do blokov telo · nika · čelo a presahy · montáž** |
| Q5 | Chýbajúce polia | MISSED: drez min šírka skrinky 600 (Legra XL 6 S), chladnička door_system + hinge_side, umývačka hmotnosť + posuvný pánt, vetranie cm² | MISSED: hmotnosť čela min/max, typ pántu, max V čela, sokel min/max, strana pántu, vetranie cm², prípojky, hĺbka niky max | MISSED: ETIM **EC011315** drez v8: Min. Schrankbreite EF019412, Einbauhöhe EF000332, Montageart EF000003, Befestigungsart EF002442 | ETIM EC011315, Bosch FR | **mení návrh: D1 doplniť (§3)** |
| Q6 | openpanel 1 súbor, filter `názov\|*.pdf;*.jpg\|\|`, select_directory len adresáre, openURL `file:///`, temp_dir | ALREADY EXISTS + MISSED (openURL s medzerami/diakritikou bez encodingu zlyhá — tvrdenie) | ALREADY EXISTS (SU 2014/2015/2019.3 poznámky) | SIMPLER NATIVE PATH = natívna cesta stačí; MAX_PATH 260; temp_dir nie na trvalé súbory | SU API UI.html | **berieme; PROBE P1** (openURL s diakritikou a medzerami) |
| Q6 | HTML file input = `C:\fakepath`, drag-and-drop bez cesty | MISSED (CEF 137) | SIMPLER NATIVE PATH = NIE; drag-and-drop RESEARCH GAP | MISSED (WHATWG 17.9.2026, CEF 137) | WHATWG, SU HtmlDialog | **berieme: výber len cez Ruby openpanel; drag-and-drop mimo** |
| Q6 | Kopírovanie: zámky súborov (EACCES), dlhé cesty, Unicode | MISSED | — | MISSED: overiť v SU 2026, priznať zlyhanie | Microsoft MAX_PATH | **berieme: rescue + krátke uložené názvy + hláška; PROBE P3** |
| Q7 | Winner Skip → prázdna nika / generic / „32767 Anything"; katalóg filtrovaný na niku; bez hard blocku | CAD (Winner, 2020 „ROOM_APP" — UNVERIFIED) + SIMPLER: „Dimension Search" filter | CAD (články 6.6.2023 / 12.3.2026); stavy nika OK / nevybraný / dáta prázdne / nezmestí sa; „spotrebič nevybraný", nie „chyba" | CAD (12.3.2026): šírka a výška obmedzujú ponuku katalógu | Winner články | **berieme: výber v Inspectore filtrovaný podľa niky (prepínač „všetky"), 4 stavy** |
| Q7 | Predobjednávková kontrola nevyriešených spotrebičov v CAD | CAD (2020 „Design Validation" — homepage) | RESEARCH GAP (2020 len fórum) | UNVERIFIED | — | **NO ACTION navyše: naša Kontrola ORANGE `appliance_missing` to pokrýva** |

## 3 · Zmeny návrhu (delta voči V1_DEBATA_2026-09-20 — po potvrdení Michalom sa prepíšu tam)

1. **D1 štruktúra polí:** každá kategória v štyroch blokoch **telo · nika · čelo a presahy · montáž** (Bosch/IDM jazyk), nie plochý zoznam.
2. **D1 umývačka +:** ~~typ uchytenia čela~~ (Michal: nerieši sa) · max výška čela z listu (dnešné „V max", **len evidencia**) · hmotnosť čela min–max (**len evidencia**,
   Michal: okrajovo) · sokel min–max (evidencia) · poznámka „parozábrana pod PD". Limity z Q2 ostávajú v tomto packete ako podklad pre V1+.
3. **D1 chladnička +:** systém dverí (`posuvné lišty` · `door-on-door` — druhé mimo V1, len evidencia) · strana pántu (L / P / otočné) · max hmotnosť a hrúbka nábytkových dverí
   (voliteľné) · **nábytkové dvere z výkresu výrobcu** (dolné V min–max + referenčná škára) — keď je vyplnené, má prednosť pred vzorcom pásiem.
4. **D1 drez +:** min šírka skrinky (Legra XL 6 S = 600) · hĺbka vane / montážna výška.
5. **D3 slot (po Michalovi §4 + screeny ~02:30):** **jedno čelo** (delené = po V1) · **presah čela hore neobmedzený** · telo na minimálnej výške z rozsahu listu
   (referencia: telo + fixná základňa 200) · **výplň hore sa negeneruje** — ručne korpus alebo doska (→ fix S1-E0: min výška korpusu 200 → 80) · **ŽIADNE ORANGE pre
   výšku čela, hmotnosť ani sokel** (rozhodnutie 6.9. platí); riadok/karta môže informatívne ukázať „list: čelo max 720, 2–10 kg". Kontroly slotu: trieda šírky, telo vs
   šírka slotu, min výška tela ≤ výška linky. Michal: „audit to viac skomplikoval ako doplnil" — Q2 limity ostávajú len ako podklad pre V1+.
6. **D4 chladnička:** hláška a riadok Inspectora hovoria „odporúčané delenie podľa praxe (presah ≥ 10, škára s)"; škára `s` z configu čiel; výkres výrobcu (bod 3) má prednosť.
7. **D6 výber spotrebiča v Inspectore:** filtrovaný podľa vnútra skrinky (nika Š/V/H), prepínač „zobraziť všetky"; **4 stavy** riadku aj Kontroly: OK · nevybraný (ORANGE
   `appliance_missing`) · chýbajú údaje (ORANGE `appliance_specs_missing`) · nezmestí sa (ORANGE `appliance_niche_clash`, per os).
8. **D1/D6 prílohy:** výber cez Ruby `UI.openpanel` spúšťaný cez `UI.start_timer(0)` z callbacku (P2) · otvorenie cez `UI.openURL("file:///…")` s URI-kódovaním (P1) ·
   kopírovanie s `rescue` (zámok, EACCES), krátke uložené názvy `<id>/<n>_<sanitized>` (P3) · drag-and-drop a HTML file input sa neponúkajú.
9. **Non-goals potvrdené:** door-on-door · ETIM/IDM import-export · drag-and-drop · OCL kompatibilita proxy tela (pri prípadnom exporte overiť zvlášť).

## 4 · Otázky pre Michala — ZODPOVEDANÉ (20.9. ~02:00; plné znenie v [V1_DEBATA_2026-09-20_SPOTREBICE_POLIA.md](V1_DEBATA_2026-09-20_SPOTREBICE_POLIA.md) §1b)

1. **Čelo 826 v praxi:** pracovná doska dnes 900–950, spotrebiče ~900 → umývačka na takmer minimálnej výške, zvyšok vyplní blenda (korpus/výplň z rezaných dielov, materiál
   korpusu); sokel nedotknutý; hmotnosť nikdy nebola problém ani pri 950 a veľkom presahu. → **presah čela hore sa neobmedzuje, typ uchytenia sa nerieši, hmotnosť len okrajovo.**
   Nálezy Q2 (Bosch/Nobilia/Beko limity) sa **neberú ako kontrola** — ostávajú v katalógu ako evidencia (čelo V max, hmotnosť min–max) a v tomto packete ako podklad pre V1+.
2. **Mäkké kontroly umývačky:** **NIE** — len evidencia výšky čela a hmotnosti z listu; §3 bod 5 sa mení na „bez ORANGE pre čelo/hmotnosť/sokel".
3. **Delené čelo v slote:** otázka bola nezrozumiteľná; vysvetlené (dve čelá nad sebou + spojovacia lišta, IKEA VÅGLIG) — **V1 = jedno čelo**, delené po V1, ak Michal nepovie inak.
4. **Chladnička — nábytkové dvere z výkresu výrobcu s prednosťou:** **ÁNO.**
5. **Výber filtrovaný podľa niky:** podľa náročnosti → **do S1-B ako malá položka** (lacné porovnanie vnútra s nikou); pri komplikácii vypadne.

## 5 · Probes v SketchUpe pred package (SkAgent bridge; testovacie okno)

- **P1** `UI.openURL` na lokálny súbor s medzerami a diakritikou v ceste: holá cesta vs `file:///` + URI-kódovanie → čo otvorí systémový prehliadač (SU 2026, Windows 11).
- **P2** `UI.openpanel` volaný priamo v HtmlDialog callbacku vs cez `UI.start_timer(0)` → ostane kanál dialógu živý po zatvorení pickeru? **Dnešný picker textúr
  (`materials_appearance_dialog.rb:163` → `appearance_pick_image`) volá `UI.openpanel` PRIAMO v callbacku a v praxi funguje (M-R smoke PASS 12.9.)** → Grokov nález je
  pravdepodobne NO ACTION pre SU 2026; probe len potvrdí, že po zrušení pickeru (nil) kanál žije. Prílohy pôjdu rovnakou cestou ako textúry.
- **P3** `FileUtils.cp` do `%APPDATA%\NOXUN\Engine\appliances\<id>\` pri zamknutom zdroji (PDF otvorený v prehliadači) a pri názve s diakritikou → aká výnimka, aká hláška.

## 6 · Pasce nástrojov (pre skill `antigravity-outside-in` a memory)

- **Grok CLI headless:** `web_fetch` je predvolene vypnutý (`GROK_WEB_FETCH=1`), v `--permission-mode plan` sa fetch „User cancelled" a beh skončí po prvej vete. Funkčná
  kombinácia: `GROK_WEB_FETCH=1 grok -p "<prompt>" --no-plan --permission-mode dontAsk --allow "WebFetch(*)" --tools "web_search,web_fetch,todo_write" -m grok-4.6
  --reasoning-effort xhigh --max-turns 80` (tools allowlist = žiadny shell ani zápis; `bypassPermissions` nepoužívať — blokuje ho aj Claude Code classifier). Prompt ~16 kB ako
  argv prešiel. Beh ~7 min, 23 zdrojov.
- **Gemini 3.8 Flash high:** jeden zo štyroch behov zdegeneroval (109 kB „shame shame…" a cudzí HTML text) — 3.7 Flash high dal konzistentné packety; 3.8 ostatné dva behy OK.
  Headless auto-deny `command` permission zhodí beh bez výstupu → do promptu písať „no shell, only search_web/read_url_content".
- **Codex Astra cez companion:** 8 min, „Kontrola voči repu" je lacná a užitočná (potvrdí, že prompt opisuje kód pravdivo).
- Všetky tri: **VERIFIED pri homepage URL nie je dôkaz** — orchestrátor váži podľa konkrétnosti dokumentu.
