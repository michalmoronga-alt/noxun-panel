# UI 2.0 — koncepčný podklad a záväzný kontrakt (13.–18.8.2026)

> **Toto je ZDROJ PRAVDY** pre blok UI 2.0 (presunuté do repa dávkou UI-01, 18.8.) —
> pracovná kópia v `_dev/UI20_PODKLAD.md` už autoritou nie je. Mockupy k nemu patriace
> sú vedľa: [mockup_inspector_c.html](mockup_inspector_c.html) (finálny koncept Inspectora,
> v16) · [mockup_ui20.html](mockup_ui20.html) (štúdio okno) · [dizajnovy_listok.html](dizajnovy_listok.html)
> (paleta, logo, dizajnové rozhodnutia).
>
> Podklad pre klikateľný mockup a večernú debatu. Vstupy: [UI_VIZIA](../../UI_VIZIA.md) ·
> merač D-25 ([odpočet](../MERAC_D25_odpocet_2026-08.md)) · V1_VIZIA §6 ·
> PLAN blok UI 2.0 · [UI_DIZAJN](../../../docs/UI_DIZAJN.md). Rozsah schválil Michal 13.8.:
> **štúdio okno so VŠETKÝMI satelitmi + PLNÝ redizajn Inspectora**; D-26 (režimy) sa rozhodne
> až nad mockupom; OCL vzory navrhuje agent, Michal škrtá/dopĺňa.

## 1 · Ťažisko z merača (čo musí byť na 1 klik)

1. **Výber materiálu/ABS** — 400+ interakcií (výber pri vkladaní 112×, ABS selecty 117×,
   otvorenie Materiálov 115×). → D-85 zdieľaný combobox s hľadaním je NAJVYŠŠIA priorita;
   musí byť v mockupe živý (dá sa doň písať).
2. **Prepínanie kontextu** — taby 287×, satelity 234×. → jedno štúdio okno + deep-linky
   z Inspectora (klik otvorí štúdio PRIAMO v cieľovej sekcii, nie „otvor a hľadaj").
3. Takmer nepoužité (1–2×): orientácia/odsadenie výstuh, vodorovné delenia, režim sokla,
   reset kovania → kandidáti na zbalenie (rozhodnutie D-26 až nad mockupom — mockup ich
   ukazuje v plnej podobe, ale vizuálne ODDELENÉ v sekcii „Menej časté").

## 2 · OCL vzory — NÁVRH na prevzatie (Michal škrtá/dopĺňa)

**Prevziať:**
- **Jedno okno, ľavá zvislá navigácia** (ikona + text) namiesto 5 satelitov — presne náš cieľ.
- **Skupiny kusovníka podľa materiálu** so zbaliteľnými hlavičkami a medzisúčtami
  (m² / počet kusov v hlavičke skupiny) + súčtový riadok celku.
- **Klik na riadok dielca = zvýraznenie v modeli** (obojsmerná navigácia; u nás už čiastočne
  v KONTROLE — povýšiť na štandard všetkých tabuliek: kusovník, nákup, traceability D-94).
- **Hover akcie riadku** (ikony vpravo pri hoveri: označ v modeli · uprav · detail) — šetria
  stĺpce, tabuľka ostáva čistá.
- **Voliteľné stĺpce tabuľky** (prepínač stĺpcov v rohu — Lucia nepotrebuje vidieť to, čo Michal).
- **ABS kompakt v stĺpci** („P:1 · L:2" štýl z UI_VIZIA riadok 15) s tooltipom plného znenia.
- **Tlačiteľné etikety dielcov** — v mockupe len ako položka exportov (placeholder, po V1).
- **Sekcia = vlastný obsah + vlastné nástroje hore** (OCL má per-tab toolbar) — náš vzor:
  lišta sekcie s primárnou akciou vľavo a exportmi vpravo.

**NEPREVZIAŤ (a prečo):**
- **Generate/Refresh tlačidlo** — OCL prepočítava na klik; Noxun má živý server push, tabuľky
  sú vždy čerstvé. Refresh vzor by bol krok späť.
- **Materiály cez SketchUp Materials** — náš katalóg je vlastný (Demos väzby, ABS rodiny).
- **Nárezový plán UI** — fáza 2 (PLAN blok KONTROLA+VÝROBA); v mockupe len sekcia
  s placeholderom, nech je v navigácii vidieť, kam patrí.

## 3 · Štúdio okno — architektúra

**Jedno okno `studio.html`** (dlhodobo nahradí materials/production/hardware_catalog/rules/
templates/supplier_settings). Layout: ľavá navigácia (ikony+text, zbaliteľná na ikony) ·
obsah sekcie · hlavička okna s identitou zákazky.

Navigácia (zoskupená oddeľovačmi, poradie podľa frekvencie merača):

- **ZÁKAZKA:** Kusovník (layers/list) · Kontrola (semafor badge s počtom RED/ORANGE priamo
  v navigácii) · Nákup kovania · Rozpočet · Cenová ponuka · Nárezový plán *(placeholder)*
- **KATALÓGY:** Materiály (dnešné okno Materiály — dlaždice dekorov, detail skupiny) ·
  Kovanie (katalóg + sety) · Pravidlá (ABS + kovanie) · Šablóny
- **NASTAVENIA:** Dodávateľ/Demos · Nastavenia rozpočtu · O plugine (verzia)

Zásady:
- **Deep-link kontrakt:** `NX.studioOpen(section, anchor)` — z Inspectora sa dá skočiť rovno
  na „Materiály → dekor K2738" alebo „Kontrola → nález X". Ruší dnešné „otvor okno a hľadaj".
- **Stav sekcie prežije prepnutie** (scroll, rozbalené skupiny, filter) — v rámci otvoreného okna.
- **Kontrola badge:** navigácia ukazuje živé počty semaforu — dôvod otvoriť štúdio je vidieť
  ešte pred otvorením sekcie.
- **Exporty patria sekcii** (kusovník má VEPO/XLSX/CSV, rozpočet má XLSX/ponuku…) — žiadna
  globálna lišta exportov (lišta z UI_VIZIA sa realizuje per-sekcia).
- Migračná poznámka pre implementáciu: sekcie sa budú presúvať do štúdia PO JEDNEJ dávke,
  satelity zanikajú postupne (mockup ukazuje cieľ, nie prvý krok).

## 4 · Inspector — plný redizajn (pri kreslení, kompaktný ostáva)

Rola sa nemení (syntéza dilemy 05: kreslenie = Inspector, kontrola/výstupy = štúdio), mení sa
vnútro:

- **Hlavička = prístup ku všetkému (UX-02):** rad 1 logo + identita + warn chip (ostáva);
  rad 2 = režimové taby Korpus·Zóny·Čelá + JEDNO tlačidlo **Štúdio** (nahrádza tri satelitné
  akcie Materiály/Výroba/Kovanie — tie sa stanú deep-linkami: dlhé podržanie/šípka pri tlačidle
  ponúkne cieľové sekcie; default klik = naposledy použitá sekcia). Rieši D-91 „finálny domov".
- **Náhľad ako hlavný vizuál** (backlog bod z UI_VIZIA §Poznámka): náhľad hore, kontextová
  karta pod ním; fit overlay ostáva. V kontexte Čelá náhľad ukazuje čelá, v kontexte dielca
  hrany (ABS editor vzor).
- **D-85 combobox** vo VŠETKÝCH výberoch materiálu/ABS: písanie s filtrom bez diakritiky,
  sekcia „Použité v projekte" navrchu, naposledy použité; jeden komponent, päť miest
  (telo/dielec/doska/čelá/chrbát + ABS hrany + projektové predvoľby). ŽIVÝ v mockupe.
  **Vedomá odchýlka implementácie (UI-03):** projektové predvoľby a satelitné okná
  combobox **nemajú** — majú vlastný suggest nad voľným textom (D-67); dôvod je
  zapísaný v [docs/UI_DIZAJN.md](../../../docs/UI_DIZAJN.md) (sekcia D-85 / UI-03).
- **D-84 čelá rečou stolára:** „+ pridaj čelo" / „+ pridaj dvere"; „− riadok" zaniká
  (krížik pri riadku).
- **UX-06 karta Zóna:** smerové ikony delenia (zvislé/vodorovné) namiesto textových selectov.
- **D-96 sekcia Úchytky** v karte skrinky: profil + hrana osadenia + rozsah čiel; ikona
  v riadku čela ostáva len indikátor.
- **D-89a hover hrany:** hover na hranu v karte dielca/ABS editore zvýrazní hranu v MODELI
  (mockup: naznačiť tooltipom „zvýrazňujem v modeli").
- **UX-03 polia šírkou podľa obsahu** — mm polia krátke, selecty dlhé; menej zalamovania.
- **„Menej časté" zbaliteľná sekcia** v karte Korpus (výstuhy orientácia/odsadenie, vodorovné
  delenia, režim sokla…) — vizuálny podklad pre rozhodnutie D-26 (prepínač vs. akordeón).
- **Vkladacia karta:** ostáva mode-insert, dostáva D-85 combobox + väčší dôraz na šablóny
  (najčastejší vstup do práce).

## 5 · Mockup — čo sa stavia ([mockup_ui20.html](mockup_ui20.html))

Jeden HTML súbor, klikateľný, **reálne --nx-* tokeny** z UI_DIZAJN (mockup má vyzerať ako
plugin, nie ako koncept — vzor `_dev/mockup.html` (pracovný, mimo repa) je len ŠTRUKTÚRNY vzor,
farby brať z panel.css),
Lucide-štýl inline ikony, žiadne emoji. Obsah:

1. **Prepínač pohľadov hore:** „Inspector" / „Štúdio" (dve hlavné plochy mockupu) + poznámkový
   pruh „mockup — dáta sú vymyslené (zákazka KLINIKA vzor)".
2. **Štúdio:** plne rozpracované sekcie **Kusovník** (skupiny podľa materiálu, hover akcie,
   voliteľné stĺpce, ABS kompakt, exporty), **Materiály** (dlaždice + detail + D-85 combobox),
   **Kontrola** (semafor + badge v navigácii); ostatné sekcie wireframe (šedé bloky s popisom
   obsahu — stačí na debatu).
3. **Inspector:** kontexty Korpus / Zóny / Čelá / dielec + vkladacia karta; hlavička s tlačidlom
   Štúdio a deep-link rozbaľovačkou; živý D-85 combobox (písanie filtruje vymyslený katalóg
   ~15 dekorov vrátane „Použité v projekte"); sekcia „Menej časté" zbaliteľná.
4. **Klik-flow na predvedenie:** z karty dielca klik na dekor → štúdio/Materiály na tom dekore ·
   z Kontroly klik na nález → „zvýraznené v modeli" toast · prepnutie stĺpcov kusovníka.

## SCHVÁLENÉ ROZHODNUTIA (Michal, 15.8. — dizajnový lístok + kolá Inspectora)

- **O1 · Akcent výberu = NOXUN TEAL** (#107787 rodina — select/select-strong/accent/bg/bg-soft/bg-hover/part-border/part-bg) — brand konzistencia s logom a webom. Modrá končí.
- **O2 · Primárna akcia ostáva ZELENÁ** (#2e7d32) — „vykonaj" sa nemení.
- **O3 · Rádius zjednotený na 6 px** (končí mix 4/6/7).
- **O4 · Téma Lucia** = len výberová rodina prepnutá na ružovú, uložená per počítač (%APPDATA%); významové farby (danger/warn/ok/ABS/edge/semafor) sa témou NIKDY nemenia.
- **O5 · Tmavý režim: neskôr** — hex nezabetónovávať, tokeny to riešia.
- **Logo:** zrolovaná značka vypočítaná z originálnych SVG kriviek webu (pracovný skript `scratchpad/logo_collapse.js` mimo repa; postup: písmená do spoločného stredu, X rotované 45°); header 24 px, toolbar 19 px.
- **Trvalé zásady schválené počas kôl:** výstupy nikdy nevyzerajú ako vstupy (dopočítané = text) · všetko informačné je klikateľné a vedie tam, kam ukazuje — dvojnásobne pri semafore/chybách/kontrolách (N13+) · rozmerové rady pri poliach s editáciou v Štúdio→Nastavenia (N6) · šablóny: nedávne prvé (N16), dvojklik = vlož (N17) · šablóny s reálnymi náhľadmi (PNG pri uložení + schéma fallback) · doskové šablóny Diel 18/PD 38/Zástena 10 · toolbar N4: logo·Štúdio·ABS toggle·Vložiť + paleta témy.

## FINÁLNY KONCEPT INSPECTOR C — UZAVRETÉ 18.8. (referencia: [mockup_inspector_c.html](mockup_inspector_c.html), v16)

Mockup je záväzná vizuálna referencia; tento súhrn je záväzný slovný kontrakt. Sektorové kolá
prešli Korpus · Vkladanie · Zóny · Čelá · Kovanie · Dielec, všetko schválené Michalom.

**Kostra:** panel 470 px · rail 44 px (Korpus=skrinka ikona · Zóny=mriežka · Čelá=čelo s úchytkou ·
Kovanie=hammer · dočasný Dielec s krížikom · FUNKČNÁ sekcia: ABS kontrola=shell so stavom a šípkou
na 3-stavové nastavenie (zrkadlo D-105) · dole koliesko=Nastavenia Inspectora · Štúdio=layers) ·
obsah = 4 sektory: Náhľad · Základné · Materiály (len Korpus/Vkladanie) · Nastavenia (skupiny
EXKLUZÍVNE; výnimka: Štruktúra zón má vlastné rozrolovanie). Všetko zrolovateľné, lišty sektorov
tmavšie, meta súhrny v lištách. Iné kontexty: tenký riadok „Skrinka 900×720×560 · K2738 → uprav
v Korpuse". Hlavička: logo 24 px · ID · názov s ceruzkou (JEDINÉ miesto premenovania) · typ badge
(typ sa nastavuje len šablónou/vkladaním; mini-modal „Uložiť ako šablónu" nesie Názov+Typ) · ⚠ chip
s warnpanelom (riadky s okom + „Otvoriť v Štúdiu → Kontrola").

**Náhľad = kontextová projekcia** (výmena, nie vrstvenie): Korpus čelný rez s kótami (sokel živý
N12) · Zóny čistá schéma (klikateľné zóny N18, police živé N19) · Čelá predný pohľad s výškami
(obojsmerný výber, medzery jantárovo pri editácii N26) · Kovanie reálne pozície (záves=kruh s X na
závesovej hrane · **výsuv = koľajnica „L" na VNÚTORNÝCH LÍCACH OBOCH bokov (zvislá nožička +
vodorovná pätka dovnútra; výsuv drží bok, nie čelo) + telo šuflíka medzi nimi**,
výška tela je pomer z výšky čela, takže pri viacerých
zásuvkách nad sebou telá rastú s čelami — *schválené Michalom 20.8. nad mini náhľadom, nahrádza
pôvodné „koľajnice spredu po bokoch"* · nohy=obdĺžniky; klik označí vlastníka) ·
Dielec hrany ABS farbami · Vkladanie šablóna ako bude vložená (čelá zap., vypnutím vidno vnútro;
Doska so šípkami smeru N10). Dolný FIXNÝ pás: vrstvové chipy (Zóny·Čelá·Kovanie·Olep, D-27 ghost)
+ kamera N7 + fit.

**Korpus:** Základné = rozmery zvislo s ikonami (↔↕⤢+sokel ikona: zaoblený obdĺžnik s plným pásom)
+ rozmerové rady N6 pri VŠETKÝCH poliach (s „Upraviť rad…" → Štúdio→Nastavenia) | info stĺpec
(vnút. rozmery, dielcov, m², hmotnosť-odhad; KLIKATEĽNÉ N13). Skupiny Strop·Dno·Boky·Chrbát·Sokel·
Výstuhy s panelovými ikonami (N3b). Dole „Uložiť ako šablónu…" (modal). „Menej časté" NEEXISTUJE.

**Vkladanie:** typ buttony (Dolná=skrinka na sokli · Horná=zavesená · Doska) → Šablóny (nedávne
prvé N16, dvojklik vloží N17, REÁLNE náhľady: PNG pri uložení + schéma fallback; doskové šablóny
Diel 18·800×600·stojaca / PD 38·2600×600·ležiaca / Zástena 10·2600×580·na stenu s hrúbkou v badge)
→ Základné (2-stĺpce, zámky D-39, rady) → Materiály (Doska: materiál + smer dekoru D-86) → zelené
Vložiť (N11 pripravené na vkladanie na klik).

**Kontraktové spresnenia z implementácie UI-C1** *(doplnené pri uzávere dávky, 18.8. — PR #174/#175/C1c;
plné odôvodnenia v [../../archiv/KRONIKA.md](../../archiv/KRONIKA.md) a [../../../docs/ARCHITEKTURA.md](../../../docs/ARCHITEKTURA.md))*
- **Rozmery doskovej šablóny sú KANONICKÉ polia dosky** — `length`/`width`/`thickness`/`grain_direction`
  podľa STANDARD 8.3. Doska nemá „šírku a výšku" ako skrinka; zápis „18·800×600" v koncepte čítaj ako
  hrúbka · dĺžka × šírka.
- **„Nedávne prvé" (N16) je LOKÁLNE POČÍTADLO použití, nie čas.** Poradie žije vo vlastnom súbore
  `template_usage.json` ako monotónne číslo — nezávisí od systémových hodín, je **údaj tohto počítača**
  a do budúcej zdieľanej knižnice šablón (D-48) nepatrí. Súbor šablón ostáva po vložení byte-nezmenený.
- **Orientácia „stojaca" a „na stenu" majú DNES zhodnú maticu.** Je to údaj **umiestnenia so sémantikou**
  (zadná plocha je pri stene, budúce prisatie na stenu / elevácia), nie iný tvar — geometricky sa zatiaľ
  nelíšia a rozlišuje ich pole v configu, nikdy bounding box. Orientácia je transformácia inštancie,
  takže **nemení kusovník, hrany, dekor ani VEPO**.
- **Orientácia je na dlaždici v tooltipe, nie v badge** — badge nesie hrúbku a druhý riadok by dlaždicu
  predĺžil (pravidlo „vertikálny priestor panela je vzácny").
- **REÁLNE PNG náhľady dlaždíc doplnila UI-D2** — schematická kresba z configu ostáva ako fallback.

**Kontraktové spresnenie z implementácie UI-D2** *(19.8., PR náhľady šablón)*
- **Náhľad = KONTEXTOVÁ FOTOGRAFIA, nie izolovaný render — vedomé rozhodnutie.** Pri uložení šablóny sa
  odfotí **aktuálny pohľad dorámovaný na skrinku**. Izolovaný render (samotná skrinka na čistom pozadí)
  by vyžadoval skrývanie zvyšku modelu, teda zápisy do modelu a kroky Späť — a šablóna sa aj tak typicky
  ukladá hneď po postavení skrinky na obrazovke. **Dôsledok, s ktorým sa počíta:** ak skrinku v tej chvíli
  niečo zakrýva alebo je rezaná rovinou, taký bude aj náhľad. Riešenie pre používateľa je triviálne —
  pozrieť sa na skrinku a šablónu uložiť znova.
- **Náhľad nikdy nezasahuje do modelu.** Fotenie nevyrobí ani jeden krok Späť a **kamera sa vráti presne
  tam, kde bola** (perspektíva aj ortogonálny pohľad).
- **Bez náhľadu sa nič nezlomí.** Šablóny uložené pred UI-D2, neúspešné fotenie aj poškodený súbor končia
  pri schematickej kresbe; **výška dlaždice sa nemení** ani v jednom prípade. Pri prepise šablóny, ktorej
  sa fotka nepodarila, sa **starý obrázok zmaže** — obrázok starého tvaru pri novom obsahu klame viac než
  schéma.
- **Doskové šablóny náhľad nemajú** (ukladanie dosky ako šablóny z UI zatiaľ neexistuje).

**Zóny:** Štruktúra NAVRCH so stromovými spojnicami, max 3 úrovne (N22), vlastné rozrolovanie ·
Delenie = 4 dlaždice + pole „Prvá zóna" mm so zlomkami (N21) + drag so snap 1/4·1/2·3/4 (N20) ·
Police = pills 0–6 · Vnútro = rezervovaný slot (po V1).

**Zóny — vedomé odchýlky od mockupu (implementácia UI-C2, 19.8.2026):**
- **Dlaždice delenia a pilulky políc sú aktívne LEN na LISTOVEJ zóne.** Mockup ich kreslí
  aktívne aj nad delenou Z1.2; v skutočnosti by opakované delenie ticho zmazalo celý podstrom
  aj s materiálmi a ABS jeho dielcov. Na delenej zóne sú preto viditeľné, ale neaktívne
  s vysvetlením (`aria-disabled`, vzor D-78) a **jedinou deštruktívnou cestou ostáva
  „Vyčistiť zónu"**. Vynucuje to SERVER, nie len HTML. *Mockup sa dorovná pri 1:1 kole.*
- **Pole „Prvá zóna" je naopak aktívne LEN na DELENEJ zóne** — edituje jej pole 1. Na liste
  ešte žiadne polia neexistujú, takže by nemalo čo meniť.
- **Zámok = vypísaná hodnota** (rovnaké pravidlo ako výšky čiel): vyplnená „Prvá zóna" pole 1
  zamkne, prázdna odomkne. Per-pole zámky v úplnom zozname polí ostávajú — nové pole je
  **skratka**, nie náhrada.
- **Zlomky sa počítajú zo SVETLÉHO priestoru** (rozpätie − priečky) tak, aby **stred priečky**
  sadol na zlomok. Mockupových „432 (1/2)" pri 864 mm a hrúbke 18 je v skutočnosti **423** —
  mockup rátal nahrubo a bok by vyšiel posunutý o 9 mm. Je to tá istá funkcia, akou počíta
  magnet ťahania, takže sa číslo v poli a poloha priečky nemôžu rozísť.
- **Presné delenie nezmestiteľnú hodnotu ODMIETNE** (nikdy ticho nezmenší), presnosť **0,01 mm**.
- **Strop políc 6 je strop, nie fallback** — kto chce viac priehradiek, zónu rozdelí.
- **Legacy strom hlbší než 3 úrovne sa NEOREZÁVA:** vloženie aj šablóna prejdú s ORANGE
  varovaním, hlbšie úrovne sú v strome neklikateľný varovný riadok. Orezanie by zmazalo
  dielce živej zákazky.

**Čelá:** riadky s ikonou typu (N27) · úzke pole 46 px, „mm" pri hodnote, AUTO chip na návrat
(zámok pri výške ZRUŠENÝ — zamknuté ⇔ vypísané) · rady výšok N25 · naviazané kovanie pod riadkom
(klik → Kovanie) · výklop v ponuke s upozornením „AVENTOS ručne, automatika fáza 3" · D-84 reč
stolára · D-96 Úchytky · materiál čiel aj priamo v zozname · interaktívne prvky v riadku STOPUJÚ
bublanie (lekcia: select sa zatváral).

**Čelá — vedomé odchýlky od konceptu (implementácia UI-C3, 19.8.2026):**
- **Výklop je v ponuke typov, ale NEAKTÍVNY** (voľba s vysvetlením „AVENTOS ručne,
  automatika fáza 3"). Koncept ho počítal ako bežný typ; v skutočnosti je rola `flap`
  síce kanonická (STANDARD §2.4), ale **nikde sa nepoužíva** — sprevádzkovať ju znamená
  zásah do **buildera, ABS pravidiel, kusovníka a VEPO**, teda zmenu dátového kontraktu
  s Codex auditom a in-SketchUp behom. To je vlastná dávka, nie prílepok k UI
  reorganizácii. Poctivejšie je povedať, že sa s výklopom ráta, než ho zamlčať (rovnaký
  vzor ako rezervovaný slot „Vnútro" v Zónach). *Otvorené v [../../DOGFOODING.md](../../DOGFOODING.md).*
- **Popis výklopovej voľby je KRÁTKY** („Výklop (fáza 3)"), celá veta žije v tooltipe
  selectu a v hinte skupiny. Dôvod je layout: `flex-basis` selectu je jeho najširšia
  položka, takže dlhý text odtlačí zvyšok riadku na ďalší riadok.
- **Sekcia Úchytky NEPONÚKA hranu osadenia.** Koncept ju uvádza (profil + hrana +
  rozsah); registry profilov (`core/front_profiles.rb`) však dnes pozná len skrátenie
  hornej hrany. Ponúkať voľbu, ktorá nemá kam sadnúť, by bola lož — pribudne s ďalšími
  profilmi, ako plánovala už D-90. Registry sa kvôli UI **nerozširoval**.
- **„Rôzne profily v rozsahu" je neaktívna voľba „(rôzne)"** — v koncepte nebolo
  riešené, čo select ukáže, keď sa čelá rozsahu líšia. Vzor je „podľa parametra" zo
  sekcie Kovanie: select nikdy netvrdí zhodu, ktorá neplatí.
- **Materiál čiel je DRUHÝ ovládač toho istého údaja** (zrkadlí sa so sektorom
  Materiály), nie nové dáta — sektor Materiály patrí kontextu Korpus a v Čelách je
  skrytý (UI-B1).
- **N26 sa spúšťa OTVORENOU skupinou „Medzery a presahy"** (nielen fokusom v poli).
  Stav sa číta z DOM, takže zbalenie skupiny zvýraznenie zhasne bez ďalšej
  synchronizácie; mockup to riešil rovnako (`S.s4.fronts === 'medzery'`).

**Kovanie:** Položky = HORIZONTÁLNE boxy podľa VLASTNÍKA (Skrinka / každé čelo) — v boxe čela
select setu + rad NL s D-93 zámkom + nákupné riadky („UKW 7 → 774519 · Profil UKW 7"…); hlavička
boxu klik=označ v modeli. Sety a Pravidlá bez zmeny.

**Kovanie — vedomé odchýlky od konceptu (implementácia UI-C4, 19.8.2026):**
- **Panel po označení vlastníka NEPUSHA stav.** Identita výberu je autoritou režimu Inspectora,
  takže označený DIELEC by panel prepol na kartu Dielec — a box, z ktorého používateľ práve
  klikol, by mu zmizol pod rukami. Server preto po zmene výberu zámerne nevolá `push_selected`
  (vzor `EdgeSelectionWatch`); panel už zobrazuje TÚ ISTÚ skrinku, takže sa nič nerozchádza vo
  veci, len rail nedostane dočasnú položku. **Cena:** najbližší bežný push (Späť/Znova, zmena
  katalógu, ďalší klik v modeli) panel zosúladí a vtedy sa karta Dielec ukáže.
- **Ostatní vlastníci majú JEDEN spoločný box „Vnútro skrinky".** Koncept vymenúva „Skrinka +
  každé čelo" a o iných vlastníkoch mlčí; podperky sú pritom viazané na JEDNOTLIVÉ police, takže
  doslovné čítanie by pri šiestich policiach vyrobilo šesť boxov s jedným riadkom (proti pravidlu
  „vertikálny priestor panela je vzácny"). V spoločnom boxe si riadok ponecháva **celý** popis
  vlastníka („Podperky · Polica 2") a klik na hlavičku označí všetky police naraz.
- **Sekcia sa rozdelila na TRI skupiny S4** — Položky z pravidiel · Sety · Pravidlá. Koncept ich
  tak kreslí (mockup `s4Hw`), implementácia mala dovtedy jednu skupinu, v ktorej sa na konci
  zoznamu položiek miešali riadky setov celej skrinky.
- **Meta v hlavičke boxu je POČET položiek,** nie výpočet typov („závesy + profil" z mockupu).
  Typy sú vypísané hneď pod hlavičkou — zopakovať ich by bola len redundancia.
- **Trieda boxu je `.hwbox`, nie `.hwown` z mockupu** — `.hwown` už označuje popis vlastníka
  VNÚTRI riadku (V0.4) a dva významy jednej triedy by sa poprali.
- **Hlavička boxu je `<button>` a SÚRODENEC tela,** nie klikateľný obal. Klik na select setu,
  zámok NL či pole počtu k nej preto nemá ako dobublať — štrukturálne silnejšie než
  `stopPropagation`, na ktoré by musel pamätať každý budúci ovládač v boxe. *Mockup rieši to isté
  cez `event.stopPropagation()` na každom ovládači.*
- **Box sa NEZBAĽUJE** (kontrakt to tak žiada) — na skrátenie panela stačí exkluzivita skupín S4.
- **Box vzniká LEN vlastníkovi, ktorý naozaj má položku** (alebo vypnutú kategóriu). Znenie
  „Skrinka / každé čelo" čítame ako **rozdelenie položiek podľa vlastníka**, nie ako povinný
  zoznam všetkých čiel — mockup `s4Hw` kreslí tri boxy pre tri čelá, ktoré kovanie majú.
  Prázdny box by nič nevypísal a zabral dva riadky (pravidlo „vertikálny priestor je vzácny"),
  a pri čele typu **„bez čela" (nika)** by dokonca ponúkal „označ v modeli" bez dielca, ktorý
  by sa dal označiť. Zoznam všetkých čiel žije v kontexte Čelá; preklik odtiaľ už dnes povie
  „Toto čelo zatiaľ nemá naviazané kovanie." *(Nález Codex #179 kolo 4 — vedome neprijatý;
  ak by Michal pri kole 1:1 s mockupom chcel prázdne boxy, je to jednoriadková zmena
  v `hwGroups`: predsiať `cab` + `frontIds`.)*

**Dielec:** Základné hore (Smer dekoru = vstup; Dĺžka/Šírka/Hrúbka = info) · hrany s ikonou
square-dashed-top rotovanou (predná 0°·zadná 180°·ľavá 90°·pravá 270°) + ABS štvorec · hover hrany
zvýrazní v modeli (D-89a) · „Označiť v modeli" · „Použiť na podobné…".

*Zápis dávky UI-D1 (v0.7.17) — definícia a dve vedomé odchýlky:*

- **„Podobný dielec" = rovnaká ROLA + rovnaký VÝSLEDNÝ MATERIÁL** (`material_id` zo snapshotu
  dielca) v zvolenom rozsahu (**táto skrinka** / **celý projekt**), okrem zdroja samotného.
  Samostatné dosky (BRD) do výberu nepatria — nemajú vrstvu overridov ani rolu korpusového dielca.
  Rovnaká rola je **podmienka, nie kozmetika**: kódy hrán `L1/L2/W1/W2` znamenajú pri každej role
  inú fyzickú hranu, takže prenos medzi rolami by olep otočil. Prenáša sa **výhradne olep hrán**
  (materiál, rozmery ani smer dekoru nie); prázdny override zdroja ciele **vráti na pravidlo** —
  je to tiež rozhodnutie, nie „nerob nič". Počet aj zápis počíta **jedna serverová funkcia**
  a celý zápis je **jedna operácia = jeden krok Späť** aj naprieč skrinkami.
- ~~**ODCHÝLKA 1 — `Smer dekoru` je INFO, nie vstup.**~~ — **ZRUŠENÁ, kontrakt SPLNENÝ** dávkou
  **K1 · D-108** (PR #K1, v0.7.23, 21.8.2026). Per-dielec override smeru existuje:
  `part_overrides['grain_direction']` s enumom `length`/`width`, efektívny smer počíta
  `CabinetBuilder.effective_grain` (override → materiál) a materializuje ho do snapshotu dielca.
  Karta má segment **„Podľa materiálu — <výsledok>" / „Pozdĺžna" / „Priečna"** a každá voľba nesie
  v tooltipe **výrobný rozmer** (2000×250 vs 250×2000). Výrobný kontrakt sa pritom nerozšíril o
  žiadnu novú rotáciu — dĺžku/šírku a dvojice hrán vymieňa naďalej len VEPO a kontrola nárezu.
  Materiál bez smeru (UNI, jednofarebný) segment zamkne a override si zapamätá, ale neuplatní.
- **ODCHÝLKA 2 — rotácia hranovej ikony ide podľa 2D náhľadu, nie podľa pevnej mapy.** Uhol dáva
  strana dielca v náhľade (`AbsRules.edge_sides`), takže ikona ukazuje presne tú hranu, ktorú
  karta hneď nad zoznamom farebne kreslí. Pevná mapa „predná 0°…" by pri ležiacich dielcoch
  (police, boky, dná — teda pri väčšine) ukázala **inú stranu než náhľad**, a pre roly s labelmi
  „Pozdĺžna/Priečna" (výstuhy, doska) by neexistovala vôbec.

**Koliesko (Nastavenia Inspectora):** Vzhľad (téma NOXUN/Lucia so vzorkami) · Rozmerové rady
(skratka) · O plugine (logo+verzia). **SketchUp toolbar N4:** logo(panel) · Štúdio · ABS shell
toggle · Vložiť.

## NÁVRH IMPLEMENTAČNÝCH DÁVOK UI 2.0 (na Michalovo schválenie, 18.8.)

Zásady: malé PR · každá dávka funkčná sama o sebe (plugin vždy použiteľný) · risk-based audit ·
zmena builderov/observerov ⇒ in-SU beh povinný · Štúdio okno je SAMOSTATNÁ fáza po sektorovej
debate nad `mockup_ui20.html`.

**BLOK UI-A · Základ značky** *(nízke riziko, okamžite viditeľné)*
- UI-01 (S) Paleta: teal tokeny + rádius 6 v panel.css/oknách + mechanizmus témy Lucia (čítanie
  z %APPDATA%, aplikácia pri načítaní každého okna; UI prepínač príde v UI-B3). Bez auditu.
- UI-02 (S) Logo + SketchUp toolbar: zrolovaná značka (skript hotový) ako ikony, UI::Toolbar
  4 tlačidlá (panel · Štúdio→dočasne okno Výroba · ABS toggle na EdgeCheck · vkladací režim).
  Bez auditu; vizuálna kontrola Michal.
- UI-03 (M) **D-85 zdieľaný combobox** — najväčší úžitok merača: jeden komponent, všetky selecty
  materiálov a ABS (panel+karty+predvoľby). Nové JS sady. Bez auditu (vzor D-67 overený).

**BLOK UI-B · Inspector kostra**
- UI-B1 (L) Kostra: rail + 4 sektory + exkluzivita + presun existujúcich kariet pod sektory +
  šírka 470 + kontextové riadky. Audit DOBROVOĽNE áno (veľký zásah do panel.js, nech Codex
  hľadá diery v lifecycle). In-SU smoke.
- UI-B2 (M) Náhľad: kontextové projekcie s kótami + pvbar (chipy vrstiev D-27 + Olep + kamera N7).
- UI-B3 (M) Korpus obsah: Základné 2-stĺpce + info (server dopočty; hmotnosť zatiaľ „—" do fázy 3)
  + rozmerové rady N6 (config v %APPDATA%) + ikony skupín + šablóna-modal + typ badge + koliesko
  kontext (téma UI prepínač · rady editor · o plugine).

**BLOK UI-C · Kontexty**
- UI-C1 (M) Vkladanie: buttony, šablóny N16/N17, zámky D-39, doskové šablóny — **codex-audit ÁNO**
  (nový dátový útvar šablón dosiek + schéma náhľadov šablón).
- UI-C2 (M) Zóny: strom+spojnice+nezávislé rozrolovanie, delenie dlaždice + **presné delenie mm
  (N21 — zásah do builder parametrov ⇒ in-SU POVINNÉ, codex-audit ÁNO)** + snap N20, police pills,
  Vnútro slot.
- UI-C3 (M) Čelá: všetko z konceptu (riadky, AUTO, rady, naviazané kovanie, N26/N27, výklop hint).
- ~~UI-C4 (M) Kovanie: owner boxy + značky náhľadu.~~ **HOTOVÉ** (v0.7.16) — odchýlky vyššie.
  Plný beh in-SketchUp áno: dávka pridala novú serverovú cestu na zmenu výberu.

**BLOK UI-D · Dotiahnutie**
- ~~UI-D1 (S) Dielec: Základné hore, hranové ikony, Označiť v modeli; **„Použiť na podobné" zapisuje
  do viacerých dielcov ⇒ in-SU povinné.**~~ **HOTOVÉ** (v0.7.17) — definícia „podobné" a dve
  vedomé odchýlky sú zapísané vyššie pri sekcii Dielec. Plný beh in-SketchUp áno.
- ~~UI-D2 (M) Šablónové PNG náhľady (view.write_image pri uložení + fallback schéma) — in-SU beh.~~
  **HOTOVÉ** (v0.7.19) — kontextová fotografia namiesto izolovaného renderu je vedomé rozhodnutie
  (izolácia by musela zapisovať do modelu); zapísané vyššie pri sekcii Vkladanie.
- ~~UI-D3 (S) Klikateľnosť zvyšok: warnpanel N5 deep-linky, N13 kliky, zvyšné prekliky; UI_DIZAJN.md
  aktualizácia (paleta, zásady, nové ikony do icons.js) + D-čísla uzávery.~~ **HOTOVÉ** (v0.7.20) —
  warnpanel je **overlay** v hlavičke (nezaberá vertikálny priestor), oko riadku označuje v modeli
  **existujúcou** cestou UI-C4, deep-link do okna Výroba má whitelist tabov na serveri a spotrebuje
  sa raz. **Preklik sa implementoval LEN tam, kde cieľ existuje** — vnútorné rozmery, hmotnosť,
  hrúbka dielca, odhady vkladania a nákupný riadok kovania ostali textom (nemajú kam viesť) a
  **filter kusovníka na jednu skrinku sa nevymyslel** (kusovník ho nemá; povie sa to nahlas).
  UI_DIZAJN.md doplnený o princípy blokov UI-A…D, chýbajúce tokeny, boxy vlastníka a warnpanel.
  In-SU beh dávka nepotrebovala (žiadny builder/observer/nová zapisovacia cesta).

**SMOKE PACK 1 — VEDOMÉ DOPLNKY PO MICHALOVOM TESTE** (20.8., v0.7.21, PR #183). Hotový panel sa
testoval v praxi a vyšli z toho štyri opravy; dve z nich **menia kontrakt UI 2.0** a preto sú
zapísané tu:

- **DOPLNOK 1 — podperky políc sú v boxe „Vnútro skrinky" ZBALENÉ pod jeden súhrnný riadok**
  („Podperky políc — 5 políc: 20 ks") s rozklikom. Kontrakt UI-C4 hovoril „box Vnútro so
  zoznamom položiek"; pri piatich policiach to bolo päť riadkov, ktoré hovoria to isté.
  **Dáta sa nemenili** — pod rozklikom sú tie isté položky s tou istou identitou, takže počet
  per polica sa edituje ďalej; zbalené je default, stav rozkliku je vec **počítača**
  (localStorage), ručne upravená polica rozsvieti v súhrne štítok **„upravené"** (neštandard
  musí byť vidieť aj zbalený) a **jedna polica sa nezbaľuje**.
- **DOPLNOK 2 — ručné „Odfotiť náhľad z označenej skrinky" žije v okne Šablóny, NIE na dlaždici.**
  UI-D2 fotí náhľad **pri ukladaní** šablóny; staršie šablóny tak fotku nemajú a jediná cesta
  k nej bola uložiť šablónu nanovo (čím sa prepíše aj jej config). Nová akcia pridá k existujúcej
  šablóne **len obrázok**. Umiestnenie na dlaždici (pôvodná predstava) je **nemožné**: dlaždice
  žijú vo vkladacej karte, ktorá je viditeľná výhradne keď **nie je označené nič**, takže by
  kamera nemala ako nájsť skrinku a bola by to trvalo mŕtva ikona. V okne Šablóny existuje výber
  v modeli aj zoznam šablón súčasne. Guardy sú serverové (existujúca korpusová šablóna + **práve
  jedna** označená NOXUN skrinka), fotí sa **tou istou** cestou ako pri ukladaní (kamera sa
  obnoví, **žiadny krok Späť**).
- Zvyšné dve opravy kontrakt nemenia, len ho **dodržali**: riadok zoznamu čiel sa už nezalamuje
  (rad ovládačov je pevný, rastie v ňom jediný prvok — a súčet šírok pri 470 px stráži guard test)
  a názov položky kovania sa **oreže s `title`** namiesto toho, aby pretiekol cez susedný select.
- **NEROBILO SA v tomto packu:** nové zobrazenie výsuvov v projekcii Kovanie (koľajnica „L" + telo
  šuflíka) — návrh sa schvaľoval nad mini náhľadom. **Michal ho 20.8. schválil** a prišiel
  **samostatným PR** (v0.7.22); kontrakt projekcie Kovanie je prepísaný vyššie.

**Tým je INSPECTOR REWORK hotový** (UI-A · UI-B · UI-C · UI-D). Po ňom: **fáza ŠTÚDIO** (sektorová
debata nad mockup_ui20 → vlastné dávky; D-69, D-50 zvyšok, Kusovník/Kontrola/Nákup/Rozpočet
sekcie, presuny satelitov). **D-26** (režimy vs. akordeóny) je **20.8. ZAVRETÉ bez implementácie** —
koncept Inspector C zbalil obsah do exkluzívnych skupín sektorov, „Menej časté" neexistuje
a merač-kandidáti na skrytie sú v zrolovateľných skupinách, takže prepínač
*Jednoduchý / Rozšírený* stratil zmysel (rozhodol Michal nad hotovým panelom).

## 6 · Otvorené otázky na večernú debatu

1. D-26: prepínač Jednoduchý/Rozšírený vs. akordeóny „Menej časté" (mockup ukáže akordeón).
2. Tlačidlo Štúdio: jedno s deep-link šípkou vs. ponechať 2–3 priame tlačidlá? (mockup: jedno)
3. Náhľad ako hlavný vizuál Inspectora — súhlas? (mockup to tak kreslí)
4. D-69 jednotný editor materiálov — v štúdiu ako modal sekcie Materiály (mockup naznačí).
5. Poradie implementačných dávok po schválení mockupu (návrh: D-85 combobox → štúdio skelet
   + presun Výroby → Materiály → Kovanie/Pravidlá/Šablóny → Inspector hlavička/karty → zvyšok).
