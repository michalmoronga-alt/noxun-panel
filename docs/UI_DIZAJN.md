# Noxun Engine — UI dizajn (ľahký design system)

Referencia pre vzhľad panela Inspector a satelitných okien. Cieľ: jeden vizuálny
jazyk, žiadne natvrdo písané farby, žiadne emoji v UI chrome.

Zdroj pravdy pre farby je `noxun_engine/ui/css/panel.css` (blok `:root`). Tento
dokument opisuje **prečo** a **ako** — tabuľka tokenov nižšie je zrkadlom `:root`.

---

## 1. Princípy

- **Vertikálny priestor je vzácny** (trvalé pravidlo Michala). Pred každým novým
  riadkom/poľom zváž umiestnenie do existujúceho radu, rohu náhľadu alebo ikony.
- **Žiadne emoji v UI chrome.** Ovládacie prvky (tlačidlá, zámky, akcie) používajú
  ikony zo spritu `icons.js`. Emoji/unicode glyfy sa v ovládaní nepoužívajú.
- **Farba nesie význam.** Zelená = primárna akcia, **teal (firemná NOXUN) = výber/
  aktívny stav**, červená = chyba/mazanie, jantár = upozornenie/override. Významy
  sa nemiešajú.
- **Značka je len vo výberovej rodine.** Firemnú farbu nesie výber/aktívny stav —
  primárna akcia zostáva zelená (O2) a významové farby sa značkou neriadia.
- **Rádius 6 px** na všetkých komponentoch (input, select, tlačidlo, chip, karta
  dielca, náhľad, status, dlaždica). **Medzihodnoty 4 / 5 / 7 px sú zakázané** —
  stráži to guard test (`tests/pure/test_ui01_paleta.rb`). Vedomé výnimky: väčšie
  plochy (karty, modaly, dlaždice katalógu, boxy) **8 px** a badge **9 px** ·
  nekomponentové — farebné štvorčeky 2–3 px, pill 12 px / 99 px, 50 % kruhy.
- **Výstup nikdy nevyzerá ako vstup.** Dopočítaný údaj je **text** (`.inforow`),
  nie readonly pole — inak sa doň používateľ márne pokúša písať.
- **Klikateľné je len to, čo niekam vedie** (N13, dotiahnuté v UI-D3). Informačný
  údaj, ktorý má existujúci cieľ, je `<button>` a otvorí ho **rovno na správnom
  mieste** (deep-link). Údaj bez cieľa ostáva textom — predstierať preklik do
  nikam je horšie než nekliknuteľný riadok. Nedostupná akcia sa hlási cez
  `aria-disabled` s vysvetlením, **nikdy** HTML `disabled` (vzor D-78).
- **Zamknuté ⇔ vypísané.** Pri rozmerových poliach s automatikou (výšky čiel,
  „Prvá zóna") drží **vypísaná hodnota**, prázdne pole je AUTO. Samostatný zámok
  vedel byť zapnutý nad prázdnym poľom a nerobil nič — dve pravdy o tom istom.
  Návrat na automat robí **chip AUTO**, ktorý sa ukazuje len pri vypísanej
  hodnote.
- **Jedna voľba z N je segmentový prepínač** (`.segrow`), nie rada rádií ani
  select: typ vkladaného objektu, umiestnenie dosky, rozsah hromadnej zmeny.
  Aktívny segment nesie **výberovú rodinu** (teal) — je to *stav*, nie akcia.
- **Zbalený sektor musí povedať, čo skrýva** — meta súhrn v lište sektora je
  vidno rovnako zbalený aj rozbalený a skladá sa **až pri kreslení** zo živého
  stavu panela (nikdy sa necachuje ako hotový reťazec).
- **Rozbaľovacie okno je overlay, nie nový riadok** (`position: absolute` —
  warnpanel, `.miniopts` rozmerových radov, nastavenie zvýraznenia hrán):
  vertikálny priestor sa nesmie meniť tým, že si niečo otvoríš.
- **Žiadna vizuálna zmena bez zámeru.** Nová farba sa nepridáva ako hex do súboru —
  pridáva sa token, alebo sa použije existujúci.

---

## 2. Design tokeny

Definované v `:root` (`panel.css`). Mená `--nx-*`. Používaj `var(--nx-…)`, nikdy
natvrdo hex. Nedefinovaný token = zahodená vlastnosť (skontroluj preklepy).

### Povrchy
| Token | Hex | Použitie |
|---|---|---|
| `--nx-bg` | `#f4f5f7` | pozadie panela, sticky hlavička |
| `--nx-surface` | `#ffffff` | karty, `fieldset`, `details` |
| `--nx-surface-sunken` | `#eceff1` | status, ghost tlačidlo, disabled, zámky |
| `--nx-surface-readonly` | `#f4f6f8` | readonly input |
| `--nx-surface-preview` | `#fafcff` | pozadie 2D náhľadu |
| `--nx-surface-th` | `#f5f7f8` | hlavička tabuľky (okno Výroba) |
| `--nx-part-bg` | `#f2fafb` | karta dielca (bledý teal — patrí do výberovej rodiny) |

### Text / ink
| Token | Hex | Použitie |
|---|---|---|
| `--nx-ink` | `#263238` | základný text |
| `--nx-ink-title` | `#1b3a4b` | `h1` (okno Výroba) |
| `--nx-ink-strong` | `#37474f` | nadpisy, legendy |
| `--nx-ink-label` | `#455a64` | labely polí |
| `--nx-ink-muted` | `#607d8b` | sekundárny text |
| `--nx-ink-soft` | `#78909c` | tlmený text, logo |
| `--nx-ink-faint` | `#90a4ae` | placeholder, marker, pätička |

### Borders
| Token | Hex | Použitie |
|---|---|---|
| `--nx-border` | `#cfd8dc` | základný rámik |
| `--nx-border-strong` | `#b0bec5` | rámik inputov |
| `--nx-border-soft` | `#eceff1` | jemný rozdeľovník |

### Akcia (zelená) vs výber (NOXUN teal) — významovo rôzne
| Token | Hex | Použitie |
|---|---|---|
| `--nx-action` | `#2e7d32` | pozadie primárneho tlačidla |
| `--nx-action-hover` | `#1b5e20` | hover primárneho tlačidla |
| `--nx-on-accent` | `#ffffff` | text na akcii/výbere |
| `--nx-select` | `#107787` | aktívny tab, ID, výber |
| `--nx-select-strong` | `#0B5661` | zvýraznenie čela (hover) |
| `--nx-select-accent` | `#0e6b7a` | akcent riadku čela |
| `--nx-select-bg` | `#e0f2f4` | pozadie výberu (zóna, riadok) |
| `--nx-select-bg-soft` | `#f0f9fa` | hover zóny |
| `--nx-select-bg-hover` | `#d6eef1` | hover riadku čela |
| `--nx-part-border` | `#7fc4cf` | rámik karty dielca |

> **Osem tokenov vyššie + `--nx-part-bg` = „výberová rodina"** (od UI-01, rozhodnutie
> O1 z 15.8.2026 — firemný teal loga a webu; predošlá modrá skončila). Je to jediná
> rodina, ktorú smie prepnúť **téma** (sekcia 2.1). Primárna akcia zostáva zelená (O2).
> Kreslené farby 2D náhľadu (`ui/js/preview.js`) sú **zrkadlom** týchto tokenov — SVG
> atribúty nevedia čítať `var()`, takže zmena tokenu znamená zmenu aj tam.

### Stavy (vlastné tokeny — NIE action)
| Token | Hex | Použitie |
|---|---|---|
| `--nx-ok-bg` / `--nx-ok-fg` / `--nx-ok-border` | `#e8f5e9` / `#1b5e20` / `#c8e6c9` | status OK |
| `--nx-err-bg` / `--nx-err-fg` / `--nx-err-border` | `#fdecea` / `#b71c1c` / `#f5c6cb` | status chyba |

### Nebezpečie / mazanie (červená)
| Token | Hex | Použitie |
|---|---|---|
| `--nx-danger` | `#c62828` | text mazacieho tlačidla |
| `--nx-danger-bg` | `#fbe9e7` | pozadie mazacieho tlačidla |
| `--nx-danger-border` | `#ffccbc` | rámik mazacieho tlačidla |
| `--nx-danger-line` | `#e53935` | červený okraj chybného poľa |
| `--nx-danger-bg-soft` | `#fff5f5` | pozadie chybného poľa |

### Upozornenie / override (jantár)
| Token | Hex | Použitie |
|---|---|---|
| `--nx-warn` | `#ffb74d` | rámik override, odomknutý zámok |
| `--nx-warn-bg` | `#fff8ef` | pozadie override |
| `--nx-warn-bg-soft` | `#fff3e0` | warn chip, zapnutý zámok |
| `--nx-warn-fg` | `#e65100` | text odomknutého zámku |
| `--nx-warnchip-fg` | `#b26a00` | text warn chipu |
| `--nx-warnchip-border` | `#ffcc80` | rámik warn chipu / zoznamu |
| `--nx-warnrow-fg` | `#7a5000` | text riadku upozornenia |
| `--nx-warnrow-border` | `#ffe0b2` | rozdeľovník upozornení |
| `--nx-modalwarn-fg` | `#8d5a00` | text upozornenia v modale |
| `--nx-wbadge-fg` | `#4e2e00` | text badge (okno Výroba) |

### ABS hrany (vlastné tokeny — oddelené od stavov)
| Token | Hex | Použitie |
|---|---|---|
| `--nx-abs-1mm` | `#e53935` | ABS 1,0 mm (červená) |
| `--nx-abs-2mm` | `#43a047` | ABS 2,0 mm (zelená) |
| `--nx-abs-none` | `#b0bec5` | bez ABS |
| `--nx-abs-tape-bg` | `#faf6ee` | béžová výplň ikony „olep 4 hrany" |

### Kontrola hrán — tri stavy olepu (D-105, vlastné tokeny)
| Token | Hex | Použitie |
|---|---|---|
| `--nx-edge-missing` | `#e24b4a` | chýba podľa pravidla (červená) |
| `--nx-edge-extra` | `#ff8c00` | neolepené mimo pravidla (oranžová — fialová splývala s modrým výberom SketchUpu) |
| `--nx-edge-taped` | `#1d9e75` | olepené (zelená) |

> Vlastná rodina — **nie** sú to ABS hrúbky (`--nx-abs-*`) ani stavový semafor
> (`--nx-state-*`). Hodnoty sú **záväzným zrkadlom** `EdgeCheck::COLORS`
> (`core/edge_check.rb`): štvorček v okne musí mať presne farbu plôšky v modeli.
> Zhodu stráži test (`tests/pure/test_d105_prepinace_hran.rb`).

### Hľadanie (D-85 combobox)
| Token | Hex | Použitie |
|---|---|---|
| `--nx-mark-bg` | `#fff3b0` | `<mark>` zvýraznenie zhody vo výsledkoch hľadania |

> Vlastný token zámerne — **nie je to stav, výber ani upozornenie**, je to
> „toto si napísal". Preto sa nemieša s `--nx-warn*` ani s výberovou rodinou
> a **téma ho nemení** (žltá musí ostať žltou na oboch počítačoch).

### Prekrytia
| Token | Hex | Použitie |
|---|---|---|
| `--nx-scrim` | `rgba(38,50,56,.45)` | tmavé pozadie modalu |
| `--nx-modal-shadow` | `rgba(0,0,0,.25)` | tieň modalu / overlay (warnpanel, `.miniopts`, split okno) |

### Chróm panela a rozmery kostry (nie sú to „farby významu")
| Token | Hodnota | Použitie |
|---|---|---|
| `--nx-ghost-hover` | `#e0e4e7` | hover neutrálneho (`ghost`) tlačidla |
| `--nx-logo` | `#78909c` | firemné logo v hlavičke — zámerne tlmené |
| `--nx-header-h` | `42px` | orientačná výška sticky hlavičky (`scroll-padding-top`) |
| `--nx-rail-w` | `44px` | šírka railu kontextov (UI-B1) |

> Posledné dva tokeny **nie sú farby** — sú to rozmery kostry a žijú v `:root`
> preto, že ich potrebujú aj pravidlá mimo hlavičky (fokus nesmie skončiť pod
> sticky lištou, obsah nesmie zaliezť pod rail). Téma sa ich netýka.

### Semafor — REZERVOVANÉ (nepoužívať)
| Token | Hex | Poznámka |
|---|---|---|
| `--nx-state-red` | `#d32f2f` | vyhradené pre stavový semafor |
| `--nx-state-orange` | `#f9a825` | vyhradené pre stavový semafor |
| `--nx-state-green` | `#388e3c` | vyhradené pre stavový semafor |

> Semaforové tokeny sú **len zadefinované**. Nikde sa nepoužívajú — sú rezervou pre
> stavový semafor (paralelná dávka). Ich významy sa **nesmú miešať** s ABS farbami
> ani so stavmi OK/chyba, ktoré majú vlastné tokeny.

---

## 2.1 Témy (UI-01, rozhodnutie O4)

Plugin má dve témy: **NOXUN** (firemná teal, základ) a **Lucia** (ružový akcent pre
druhý počítač). Pravidlá sú úzke zámerne:

- **Téma prepína VÝHRADNE výberovú rodinu** (8 tokenov + `--nx-part-bg`). Významové
  farby — danger, warn, ok/chyba, ABS `--nx-abs-*`, hrany `--nx-edge-*`, semafor
  `--nx-state-*` aj zelená akcia — sa témou **nikdy** nemenia. Červená musí zostať
  červenou na oboch počítačoch.
- **Téma je vec POČÍTAČA, nie zákazky** — žije v `%APPDATA%\NOXUN\Engine\ui_theme.json`
  (`{"std":1,"theme":"noxun"|"lucia"}`, zápis atomicky + `.bak` cez `JsonFileStore`),
  **nikdy** v `.skp`: Michal a Lucia otvárajú tie isté zákazky.
- **Tolerantné čítanie:** chýbajúci alebo poškodený súbor aj neznáma hodnota = `noxun`.
  Whitelist je **na strane Ruby** (`Engine.normalize_ui_theme`), rovnaký fallback má
  aj JS (`nxThemeName`) — obe strany musia povedať to isté.
- **Cesta do okna:** okno si tému vypýta po načítaní HTML (`sketchup.nx_theme()` v
  `ui/js/win_fit.js` — jediný skript, ktorý načítavajú všetky okná), Ruby odpovie
  volaním `nxThemeApply(<meno>)`. Registruje sa v spoločnom boot hooku
  `Engine.register_dialog_fit` (main.rb), takže nové okno tému dostane automaticky —
  stačí, že načíta `win_fit.js`.
- **Aplikácia:** `nxThemeApply` najprv zhodí všetky témové prepisy (návrat na `:root`)
  a až potom nasadí svoje — prepnutie späť na NOXUN nesmie nechať ružové zvyšky.
  Koreň dokumentu nesie `data-nx-theme`.
- **UI prepínač témy (UI-B3)** je v koliesku raily → sekcia **Vzhľad**: dve
  tlačidlá so **vzorkami farieb** (NOXUN teal / Lucia ružová). Klik volá Ruby
  (`Engine.apply_ui_theme`), ktoré tému uloží a **rozpošle ju VŠETKÝM otvoreným
  oknám** — prepnutie je vidieť hneď a bez reštartu. Panel si tému **nedrží ani
  nenasadzuje**: farby nasadzuje výhradne `nxThemeApply`, JS len číta
  `data-nx-theme` z koreňa, aby vedel, ktoré tlačidlo je aktívne. **Vzorky sú
  literály** (nie `var(--nx-select)`) — musia ukázať farbu, ktorú *ponúkajú*,
  nie tú, ktorá je práve nasadená; sú preto zrkadlom `:root` a `NX_THEME_TOKENS`
  (stráži test).
- Kreslené farby náhľadu (`preview.js`) tému **zámerne nesledujú** — sú firemné teal.

---

## 3. Typografia

- Rodina: `"Segoe UI", Tahoma, sans-serif`.
- Základ: 13 px. Labely 12–13 px, hinty 10,5 px, ID v hlavičke 14 px (700).
- Nadpisy sekcií (`summary`, `legend`): 12 px, 600.

---

## 4. Ikony

- Zdroj: `noxun_engine/ui/js/icons.js` — inline SVG sprite, štýl **Lucide**
  (24×24, stroke-2, `currentColor`), licencie ISC + MIT (viď `THIRD_PARTY_NOTICES.md`).
- Vloženie: `<svg class="ic" aria-hidden="true"><use href="#i-NÁZOV"/></svg>`
  alebo `NXIcons.svg('názov')` do reťazca. Farbu a hrúbku dáva trieda `.ic`
  (stroke = `currentColor`), takže ikona dedí farbu textu tlačidla.
- Prístupnosť: ikonové tlačidlo má `aria-label`; zámky navyše `aria-pressed`
  synchronizované so stavom; samotné SVG je `aria-hidden="true"`.
- Zmena stavu ikony (napr. zámok): meň `href` v `<use>` cez `NXIcons.set(btn, 'lock-open')`,
  **nie** prepisom `textContent` celého tlačidla.
- **Logo je výnimka** — renderuje sa `fill`-om cez triedu `.nx-logo` (nie stroke).
  Symbol `#i-logo` nesie **zrolovanú značku z originálnych kriviek** webu, teda
  presne tú istú kresbu ako ikona toolbaru `noxun_logo.svg` (líši sa len viewBox
  — toolbar má navyše ~12 % vnútorný okraj). Veľkosti podľa kontraktu UI 2.0:
  **hlavička 24 px**, toolbar 19 px, „O plugine" 28 px. Zhodu kriviek aj veľkosť
  v hlavičke stráži guard test `tests/pure/test_ui02_toolbar.rb`.

Aktuálny set: `maximize` (fit), `alert`, `lock` / `lock-open`, `eye` / `eye-off`,
`copy`, `factory` (Výroba), `settings`, `star`, `rotate-ccw` (reset), `x`, `plus`,
`check`, `chevron-right` (disclosure), `chevron-down` (pravá polovica split
tlačidla — D-105), `link`, `search`, `arrow-left`, `trash`,
`pencil`, `box` (tab Korpus), `layout-grid` (tab Zóny), `columns-2` (tab Čelá),
`layers` (Materiály), `globe` (universal ABS), `info` (banner),
`refresh-cw` (Aktualizovať z Demosu — detail dekoru),
`cloud-download` (Pridať z Demosu; aj badge väzby na dlaždici — D-56),
`external-link` (Otvoriť u dodávateľa — riadok variantu, D-60),
`arrow-left-right` (Nahradiť UNI… — riadok KONTROLY v okne Výroba, D-83),
`more-horizontal` (⋯ ďalšie údaje riadku rozpočtu — kód/adresa/poznámka, E-b),
`download` (⬇ export súboru — XLSX rozpočet, E-b),
`profile` (vlastný symbol — úchytkový profil v riadku čela, D-90),
`wrench` (Kovanie — katalóg kovania), `logo`,
`cabinet` / `front` / `hammer` / `shell` / `slab` (UI-B1 — rail Inspectora:
Korpus · Čelá · Kovanie · ABS kontrola · dočasný dielec/doska),
`camera` (UI-B2 — kamera v spodnom páse náhľadu),
`arr-h` / `arr-v` / `arr-d` / `plinth` (UI-B3 — rozmery v sektore Základné),
`p-top` / `p-bottom` / `p-side` / `p-back` / `brace` (UI-B3 — ikony skupín
Nastavení; `brace` čaká na skupinu Výstuhy z bloku UI-C),
`palette` (UI-B3 — sekcia Vzhľad v koliesku),
`cab-low` / `cab-high` (UI-C1b — typ vkladaného objektu: skrinka na sokli vs.
zavesená; tretí typ „Doska" používa existujúci `slab`),
`ori-lying` / `ori-stand` / `ori-wall` (UI-C1c — umiestnenie dosky; v každej je
**podlaha** ako vodorovná čiara, v `ori-wall` navyše zvislá čiara steny),
`columns-3` / `rows-2` / `rows-3` (UI-C2 — dlaždice delenia zóny; spolu
s existujúcim `columns-2` tvoria štvoricu „2/3 stĺpce · 2/3 riadky“),
`door` (UI-C3 — typ čela v riadku, N27: panel so zvislou osou závesu a
úchytkou pri druhej hrane; zásuvkové čelo používa `rows-2`, výklop `p-top`
a „Bez čela“ `front`),
`edge` (UI-D1 — hrana dielca v karte: plná hrubšia čiara = hrana, o ktorej
riadok hovorí, ostatné tri sú prerušované. **Jedna kresba, štyri rotácie**
cez `data-rot` v CSS — nikdy štyri ikony),
`grain` (K2/D-87 — kontrola smeru kresby: dielec naležato so **šrafovaním**,
teda miniatúra toho, čo overlay kreslí v modeli; čiary nedobiehajú k hrane
rovnako ako v `core/grain_check.rb`. **Jedna kresba pre obe miesta** — rail
Inspectora aj prepínač „Smer kresby" v okne Výroba).

> **Inventár je úplný k v0.7.28** (blok UI-D uzavretý, `grain` doplnený dávkou
> „Kontrola kresby v raile"; dávka „ABS 3-stav v raile" **žiadnu ikonu
> nepridala** — rohový trojuholník je CSS znamienko, nie symbol zo spritu, a
> `shell` ostáva): zoznam vyššie zodpovedá kľúčom v `icons.js` 1:1. Nová ikona sa pridáva **len keď pre ňu neexistuje
> významovo správna existujúca** — UI-D3 napríklad nepridalo žiadnu, oko
> warnpanelu je ten istý `eye` ako „Označiť v modeli" v karte dielca (rovnaký
> význam = rovnaká kresba).

> Okno **Výroba** načítava `icons.js` od v0.5.44 (predtým sprite nemalo) — nové
> ovládacie prvky v ňom používajú sprite, nie glyfy.

### E-b: tab Rozpočet (okno Výroba)
Jediný tab okna Výroba, ktorý model **mení** (dáta rozpočtu v `NOXUN` dict na
modeli). Vzory:
- **Sekcie = `<details>`** s medzisúčtom v hlavičke; stav rozbalenia prežije
  prekreslenie (payload chodí po každom zápise).
- **Inline edit** (Lucia §11): číselné polia sa zapisujú až na `change`
  (blur/Enter), nie pri každom stlačení klávesy; fokus aj rozpísaná hodnota sa
  cez prekreslenie obnovia.
- **Nulové riadky ostávajú viditeľné** (rozpočet je zároveň kontrolný zoznam);
  chýbajúca cena je jantárový riadok so štítkom, NIKDY nula.
- **Veľké tlačidlo plnej šírky** (`.baddbig`) na pridanie ručného riadku —
  jediné miesto, kde sa vedome porušuje šetrenie vertikálnym priestorom
  (sekcia inak nemá viditeľný vstupný bod).
- **Prepínače** (`.bseg`): s DPH / bez DPH je len zobrazenie (localStorage),
  režim €/€€/€€€ je zápis do zákazky; tooltipy nesú názvy režimov.

### D-47 / D-91: hlavička panela — UZAVRETÉ dávkou UI-B1
Dvojradová hlavička s tromi režimovými tabmi a satelitnými akciami
(Materiály · Výroba · Kovanie) **zanikla**. Kontexty prevzal **rail** (sekcia
5.1), Štúdio má v raile vlastnú ikonu, **Materiály projektu** žijú v sektore
Materiály a **Katalóg kovania** v skupine Kovanie. Hlavička je jednoradová:
logo · ID · názov s ceruzkou · ⚠ chip. Tým je odpovedané aj D-91 „finálny domov
satelitných okien" — je ním Štúdio (rail), nie hlavička panela.

### D-92: nákup pod položkou kovania (`.hwitem` / `.hwbuy`)
Položka sekcie Kovanie je **obal `.hwitem`** = pôvodný `.hwrow` (počet, výber
setu, akcie) + **jeden** sekundárny riadok `.hwbuy` drobným písmom:
`Atira biela H176 → 357783 · K-Atira zásuvka 620/50kg`. Riadok je jednoriadkový
s ellipsis, plný text nesie `title`. Nekompletný nákup (chýba set, kód alebo
pásmo) dostane `.hwbuy-warn` = **jantárové upozornenie** (`--nx-warnchip-fg`);
semaforové `--nx-state-*` sa sem **nemiešajú**. Obsah riadku skladá výhradne
server (`HardwareSets.explain` + `PartKeys.human_label`) — JS nerozhoduje, čo
sa kupuje, ani neprekladá dôvody.

### D-102: vyriešená ABS páska v karte dielca a dosky
Rozbaľovačka hrany nesmie skončiť pri „(podľa pravidla)" — voľba nesie **výsledok**
(`(podľa pravidla — 500 SM Biela 23/1 mm)`, `(podľa pravidla — bez ABS)`,
`(podľa pravidla — nelepí sa)`). Karta Dosky nemá vrstvu overridov, preto sa u nej
mení voľba „Bez ABS" na **„Bez ABS (nelepí sa)"** pri nelepiteľnom materiáli.
V 2D náhľade dostal každý farebný pás **`<title>` tooltip** s plným textom a do
**existujúceho** popisku strany pribudla skratka (`Predná · 23/1`) — **žiadny nový
riadok**. Text skladá **výhradne server** (`Panel.edge_rule_results` /
`edge_view_hints`), JS ho len escapuje a vkladá; pri lokálnom prekreslení po zmene
materiálu sa serverový text vedome NEPOUŽIJE (patrí starému materiálu) a ukáže sa
neutrálne „(podľa pravidla)". Farby pásov ostávajú na ABS tokenoch `--nx-abs-*`
(semaforové `--nx-state-*` sa sem nemiešajú).

### D-105: split tlačidlo „Zvýrazniť hrany" (okno Výroba → KONTROLA)

> **Od v0.7.28 je rozbaľovacie okno ZDIEĽANÝ komponent** (`ui/js/edge_menu.js` +
> štýly `.ecmenu`/`.ecopt`/`.ecsw*` v `panel.css`): to isté nastavenie otvára aj
> **rohový trojuholník pri ABS kontrole v raile Inspectora** (§5.11). Pravidlá
> nižšie platia pre obe miesta; líšia sa len polohou okna a menom handlera.
> Nová kópia markupu ani druhý stav vzniknúť nesmie.
Jeden vizuálny celok, dve polovice: **ľavá** = zapnúť/vypnúť (zapnutý stav je
zjavný — pozadie `--nx-select` + ikona `eye-off`; je to **zapnutý stav**, nie
akcia, preto výberová a nie zelená), **pravá** (užšia,
`chevron-down`) = rozbaľovacie okno s nastavením. Vzory:
- **Okno je overlay** (`position: absolute` pod tlačidlom), **nie nový riadok**
  layoutu — vertikálny priestor sa nemení ani keď je otvorené.
- **Lišta žije MIMO scrollovacieho `#prodBody`** (`overflow: auto` by overlay
  orezal — pri „kontrola bez nálezov" je box nízky a z okna by ostal prúžok).
  Mimo tabu Kontrola je jej `div` prázdny a skrytý, takže nič nezaberá.
- Riadok stavu = checkbox + **farebný štvorček** (`--nx-edge-*`, presne farba
  plôšky v modeli) + názov + **živý počet zo servera**. Počet je pravdivý aj pre
  vypnutý stav — inak by sa používateľ nemal podľa čoho rozhodnúť.
- **Podriadený prepínač** (`.ecsub`, odsadený) patrí výhradne jednému nadradenému
  riadku; jeho väzbu hovorí odsadenie, nie text.
- Klient si drží **len** to, či je okno otvorené. Stav prepínačov, počty aj
  zapnutosť sú zo servera; klik posiela iba `kľúč + boolean` (whitelist a striktný
  boolean rozhoduje Ruby — HTML `disabled` nie je ochrana).
- Prázdny výber pri zapnutom „len vybrané" sa **povie nahlas** („označ skrinky
  v modeli"), nikdy sa ticho nezobrazí všetko.

### D-85 / UI-03: zdieľaný combobox materiálov a ABS (`.nxcombo`)

Každý výber materiálu alebo ABS pásky v paneli je **jeden a ten istý komponent**
(`ui/js/nx_combo.js`) — nie päť kópií. Vzhľad je prevzatý 1:1 z mockupu
`SYSTEM/zdroje/ui20/mockup_inspector_c.html`.

**Anatómia:** `.nxcombo` (obal) → `.cbtrigger` (tlačidlo so **štvorčekom farby**,
popisom a `chevron-down`) → `.cbpop` (popup: `.cbsearch` s ikonou `search` a
inputom · `.cblist` so `.cbsec` hlavičkami a `.cbopt` riadkami · `.cbfoot`
s `.kbd` nápovedou). Zvýraznenie zhody je `<mark>` s vlastným tokenom
`--nx-mark-bg` (nie je to stav ani výber — je to „toto si napísal").

**Záväzné pravidlá komponentu:**

- **Natívny `<select>` sa NENAHRÁDZA, len obaľuje.** Ostáva v DOM (skrytý,
  `tabindex="-1"`) a je naďalej **jediným zdrojom pravdy**: možnosti sa čítajú
  z jeho `<option>`/`<optgroup>`, výber zapíše `value` a vystrelí `change`.
  Vďaka tomu platí všetka existujúca logika bez duplikátu (hrúbkové filtre D-45,
  ABS skupiny D-36, texty „(podľa pravidla — …)" D-102, dupláky D-49, `disabled`
  „(nekompatibilné)") a **prežívajú všetky guardy** na `change` ceste
  (E-03 hrúbka, D-86 smer dekoru, D-41 modal chýbajúcej pásky, identity guardy).
  Nový výber materiálu = pridať `data-nx-combo="decor"|"abs"` na `<select>`,
  nič viac.
- **Skrýva ATRIBÚT, nie trieda** (`.nxcombo > select[data-nx-combo]`): panel
  selectom prepisuje `className` (`ovr`), trieda by zmizla. Override `ovr` sa
  z selectu **zrkadlí** na trigger.
- **Popup je `position: fixed` nad `body`** — žiadny predok s `overflow: auto`
  ho neoreže (poučenie D-67 FIX 7 a D-105). Otvára sa **doľava** (pravá hrana
  lícuje s triggerom), šírka `max(trigger, 270 px)`, pri málo mieste dole sa
  preklopí nahor. Scroll **mimo** popupu ho zavrie, scroll v zozname nie.
- **Výber `mousedown`-om** (D-67 FIX 4 — `blur` by popup zavrel skôr, než klik
  dopadne); `<datalist>` v CEF nefunguje vôbec.
- **Poradie sekcií je kontrakt:** fixné voľby (dediť / podľa pravidla / Bez ABS,
  bez hlavičky) → **Použité v projekte** → **Naposledy použité** → zvyšok
  katalógu členený podľa `<optgroup>`. Položka sa objaví **práve raz**; aby sa
  členenie D-36 nestratilo, nesie riadok meno svojej skupiny ako podtitul.
- **Dáta si komponent nedrží.** „Použité v projekte" je odvodený zoznam ID zo
  servera; keďže sa mení pri každom zápise materiálu, ale **číta sa len pri
  otvorení ponuky**, combobox si ho pri otvorení **vypýta** (`nx_used_ids` →
  `NX.setUsedIds` → prekreslenie otvoreného zoznamu). Farbu štvorčeka dáva panel
  resolverom (`nxComboColorOf` v `core.js`: dekor z katalógu — pozor, katalógová
  farba je pole `[r,g,b]`, nie CSS reťazec; ABS **podľa hrúbky** — rovnaká
  legenda ako `.absleg`); do `style` prejde len hex. „Naposledy použité" je
  `localStorage` **tohto počítača** (`nx_recent_decor` / `nx_recent_abs`, max 5,
  len ID) — nikdy nie model ani `%APPDATA%`; fixné voľby sa nepamätajú.
- **Sync zvonka popup ZAVRIE.** Serverový push (iná skrinka, nový katalóg),
  prestavba `<option>`ov aj odchod z okna zatvárajú otvorenú ponuku — drží
  položky z času otvorenia, takže by klik potvrdil voľbu starého kontextu do
  nového. Natívna rozbaľovačka sa pri prestavbe správa rovnako.
- **Klávesnica:** ↑↓ (preskakujú `disabled`), Enter potvrdí, Esc zavrie a vráti
  fokus na trigger, Tab zavrie. Pri otvorení stojí kurzor na **aktuálnej hodnote**
  (Enter nič nezmení omylom), pri písaní skočí na prvú zhodu.
- Filter je **necitlivý na diakritiku** oboma smermi (`modra` nájde „modrá“,
  `modrá` tiež) a hľadá aj v ID (nesie kód dekoru).
- Vedomá výnimka z rádiusu 6: `.sw` štvorčeky a `.kbd` klávesy majú **3 px**
  (nie sú to komponentové rámy — rovnaká trieda ako farebné štvorčeky legiend).

> Okno **Materiály** má vlastný suggest (D-67) nad textovými poľami a komponent
> zámerne **nepreberá** — sú to rôzne veci (voľný text vs. výber z katalógu).
> Projektové predvoľby žijú tiež tam, nie v paneli.

### 4.1 SketchUp toolbar (UI-02)

Toolbar „Noxun Engine" je **jediné miesto, kde značka vystupuje mimo panela**.
Štyri tlačidlá v poradí podľa kontraktu UI 2.0 (N4):

| Tlačidlo | Ikona | Správanie |
|---|---|---|
| Inspector | `noxun_logo.svg` (zrolovaná značka) | prepínač — otvorí panel, druhý klik ho zavrie |
| Štúdio | `noxun_studio.svg` (layers) | dočasne otvára okno Výroba (tooltip to priznáva) |
| ABS kontrola hrán | `noxun_abs.svg` (shell) | prepínač zvýraznenia olepu (to isté ako D-105 v okne Výroba) |
| Vložiť skrinku | `noxun_insert.svg` (skrinka + plus) | otvorí panel vo vkladacom režime (zhodí výber) |

Pravidlá ikon toolbaru (líšia sa od spritu v paneli):

- **Samostatné SVG súbory** v `noxun_engine/ui/icons/`, nie sprite — SketchUp číta
  súbor, nie HTML. Jeden súbor slúži ako `small_icon` aj `large_icon`.
- **Žiadny `currentColor`** — mimo HTML nemá od koho farbu zdediť a vykreslil by
  sa čierny. Kreslia pevnou `#37474f` (hodnota `--nx-ink-strong`). Stráži to guard
  test `tests/pure/test_ui02_toolbar.rb`.
- Kresba je **Lucide** (24×24, stroke 2) rovnako ako sprite; logo je fill-ová
  výnimka s vlastným viewBoxom originálnych kriviek značky.
- **Vnútorný okraj ~12 %** (UI-B1): `viewBox` je o 12 % väčší než kresba, takže
  ikona pri rovnakej ploche tlačidla nelícuje s jeho okrajom. Robí sa to
  **výhradne cez `viewBox`** (nie zmenou súradníc kresby) — pri prekreslení
  ikony tak stačí prekresliť kresbu v pôvodnej 24×24 mriežke.
- **Zapnutý stav musí byť na tlačidle vidno** — prepínače majú validation proc
  (`MF_CHECKED`), nedostupná kontrola hrán je `MF_GRAYED`, nikdy ticho mŕtve tlačidlo.
- Toolbar **nikdy nesiaha na model** (žiadna operácia, žiadne Späť) — len otvára
  okná a prepína zobrazenie.

### Pravidlo: žiadne emoji v UI chrome
Emoji/unicode glyfy (🔒 ✕ ↺ ⚙ 📋 ★ ⧉ ⛶ ⚠ 🔗 …) sa v ovládacích prvkoch panela
nepoužívajú — nahrádza ich ikona zo spritu. Kde SVG nejde (napr. `<option>`,
alebo status v `textContent` ceste do Ruby), použije sa **čistý text**, nie glyf.

---

## 5. Komponentové vzory

### 5.1 Kostra Inspectora — rail + 4 sektory (UI-B1)

Inspector má **ľavú zvislú lištu (rail)** a obsah v **štyroch zrolovateľných
sektoroch**. Vizuálna referencia je `SYSTEM/zdroje/ui20/mockup_inspector_c.html`.

- **Rail (44 px, fixný ľavý stĺpec):** kontexty **Korpus · Zóny · Čelá · Kovanie**
  → pod oddeľovačom **dočasná položka** (označený dielec / doska, prerušovaný
  rámik + krížik) → **funkčná sekcia** (ABS kontrola hrán **s rohovým flyoutom** —
  klik na ikonu prepína zvýraznenie, klik na pravý dolný roh otvorí **3-stavové
  nastavenie**, to isté, aké má okno Výroba (vzor §5.11); pod ňou **Kontrola
  kresby** — obyčajný toggle bez šípky, nie je čo nastavovať) → dole **koliesko**
  (Nastavenia Inspectora) a **Štúdio**. Aktívny kontext je teal, funkčné ikony sú
  tlmené a rozsvietia sa až po zapnutí. **Funkčný prepínač, ktorý má druhý domov
  (okno Výroba), NIKDY nemá druhý stav:** rail aj okno volajú tú istú serverovú
  cestu a zobrazujú ten istý stav, takže zapnutie na jednom mieste je hneď vidieť
  na druhom (ABS kontrola aj Kontrola kresby) — **to isté platí pre ich
  nastavenia**: 3-stavové okno je jeden zdieľaný komponent nad jedným stavom. Rail je úzky, preto názov nesie **bublina
  pri hoveri** (`.railtip`) — nie natívny `title`, aby sa nezobrazovali dva
  tooltipy naraz.
- **Kontexty platia LEN nad označeným korpusom.** Pri dielci, doske aj vkladaní
  sú **neaktívne** — sivé, s bublinou, ktorá povie prečo. Ochranu drží **guard
  v JS** (`setViewContext`), nie CSS; `aria-disabled` namiesto HTML `disabled`,
  aby tlačidlá ostali fokusovateľné (vzor D-78).
- **Sektory:** `S1 Náhľad · S2 Základné · S3 Materiály · S4 Nastavenia`. Sú to
  `<details>` — zbalenie si pamätá `localStorage`, takže **prežije prekreslenie
  aj zatvorenie panela**. Lišta sektora je tmavšia než telo a nesie vpravo
  **meta súhrn** toho, čo je vnútri: S1 názov kreslenej projekcie · S2
  `900 × 720 × 560 · sokel 100` · S3 popisy materiálov (prázdny slot = dedenie
  sa vynechá, všetko dedené povie „dedí z projektu") · S4 otvorená skupina
  menom, inak `4 skupiny · všetko zbalené`. Súhrn je vidno **rovnako zbalený aj
  rozbalený** — zbalený sektor povie, čo skrýva, rozbalený drží ten istý údaj na
  očnom mieste. Text sa skladá **až pri kreslení** zo živého stavu panela
  (`NXShell.sectorMeta`); nikdy sa necachuje ako hotový reťazec a nikdy nelomí
  riadok (ellipsis).
- **S2 a S3 patria kontextu Korpus** (+ Materiály pri vkladaní). V kontextoch
  **Zóny · Čelá · Kovanie** sa skrývajú a namiesto nich stojí **tenký kontextový
  riadok** `#ctxNote` so súhrnom skrinky a preklikom späť („Skrinka 900 × 720 ×
  560 · K2738 MO — rozmery a materiály **upravíš v Korpuse**"). Dôvod je
  vertikálny priestor: inak by každý kontext začínal tromi cudzími sektormi a
  jeho vlastný obsah by ležal pod zlomom. **Jediná autorita pravidla je čistá
  funkcia `NXShell.sectorVis(mode, ctx)`** — CSS pravidlá nad `#secBasic` /
  `#secMat` sú jej **zrkadlom** (zhodu stráži `tests/pure/test_uib1_kostra.rb`,
  maticu `tests/js/test_uib1_kostra.js`). Riadok si viditeľnosť nesie inline
  (vzor `renderPartCard`), text do neho píše `bridge.js` z payloadu skrinky —
  **žiadne nové dáta a žiadny `innerHTML`** (kostra je statická, A4). Pri
  **dielci a doske** sa S2/S3 aj riadok skrývajú (majú vlastnú kartu v S4).
- **Skupiny v S4 sú EXKLUZÍVNE** v rámci jedného kontextu: otvorenie jednej
  zavrie ostatné (aj ich zatvorenie sa uloží). Sektory samotné sú **nezávislé**.
  Výnimka `data-s4-solo` (Štruktúra zón) do exkluzivity nepatrí.
- **Kostra sa NEPREKRESĽUJE.** Prepínanie kontextov a režimov mení iba triedy
  a atribúty na `<body>` (`mode-*`, `data-view-ctx`, `data-insert-kind`).
  `innerHTML` re-render kostry by zabil listenery, otvorené comboboxy, rozpísané
  hodnoty aj fokus.
- **Scroll je dokumentový** (nie vnútorný panel) — sticky hlavička,
  `scroll-padding-top` a `window.scrollTo` logika warn zoznamu ostávajú.
- **CSS je scopnuté pod `.nx-inspector`** (koreňová trieda na `<html>`, lebo
  `body.className` prepisuje `setUiMode`). `panel.css` zdieľajú satelitné okná —
  tie o raile ani sektoroch nesmú vedieť.

### 5.2 Náhľad — kontextové projekcie a spodný pás (UI-B2)

Náhľad **nie je jeden obrázok s vrstvami** — je to **kontextová projekcia**:
kontext railu určuje, ktorý pohľad sa kreslí, a pohľady sa **vymieňajú**.
Vizuálna referencia je `SYSTEM/zdroje/ui20/mockup_inspector_c.html` (`projSvg`).

| Kontext | Projekcia |
|---|---|
| **Korpus** | čelný rez s kótami: šírka dole · výška vpravo · sokel a telo vľavo · hĺbka kótou na náznaku skosenia hornej plochy |
| **Zóny** | zónová schéma (klikateľné zóny, ťahateľné priečky) + kóty šírok stĺpcov |
| **Čelá** | predný pohľad čiel + kóty výšok riadkov vpravo, medzery pri ľavom okraji, celková šírka dole |
| **Kovanie** | korpus s **pozíciami kovania**: záves = krúžok s krížikom na závesovej hrane · **výsuv = koľajnica „L" pri OBOCH bokoch + telo šuflíka** (nižšie) · nohy = obdĺžniky dole; pod projekciou súhrn všetkých položiek |
| **Dielec** | hrany s ABS farbami (`#partSvg`, nezmenené) |

Zásady kreslenia:

- **Kóty sú decentné:** tenká čiara (1,4), tlmená farba `--nx-ink-faint`,
  hodnota bez jednotky (jednotka len tam, kde je to prvý údaj). Kreslené farby
  sú **zrkadlom tokenov** — SVG atribúty nevedia `var()` (rovnaký vzor ako
  ostatné farby náhľadu).
- **Náhľad nikdy nepočíta dáta.** Kreslí sa výhradne z payloadov, ktoré panel
  už má (rozmery formulára, `front_items`, `config.hardware`, strom zón).
  Odvodené hodnoty (pozícia značky, medzera medzi čelami) žijú v JS ako čisté
  funkcie; do dát ani kontraktu nepribudlo nič.
- **Značky kovania sú orientačné** — hovoria *čo, koľko a kde zhruba*, nie
  presné miesto vŕtania (strana závesu jednokrídlových dvierok v dátach nie je).
  Klik na značku vypíše jej popis do statusu; výber vlastníka v modeli patrí
  dávke UI-C4.
- **Výsuv sa kreslí tak, ako ho vidno spredu** (schválené Michalom 20.8. nad mini
  náhľadom — nahradilo pás naprieč čelom): pri **oboch** bokoch **koľajnica ako
  „L" profil** (zvislá nožička na **vnútornom líci boku** + vodorovná pätka smerom
  dovnútra, na úrovni, na ktorej výsuv sedí) a medzi nimi **telo šuflíka** —
  obdĺžnik odsadený **za** pätkami koľajníc, s jemnou teal výplňou ako ostatné
  značky. Všetky rozmery sú **pomer z výšky čela** (telo ~58 %), takže pri
  viacerých zásuvkách nad sebou telá rastú s čelami a žiadna konštanta nerozbije
  vysokú ani nízku zásuvku. **Kotví sa na korpus, nie na čelo:** výsuv drží bok,
  preto sú ankerom **vnútorné líca bokov** (`x = t … W−t`, tie isté, aké kreslí
  korpus) — nie bočná medzera čela; inak by koľajnica pri medzere 2 mm a hrúbke
  18 ležala *na* doske boku a pri zápornom presahu čela až mimo skrinky.
  Koľajnica je **ťah**, nie plocha, preto má navyše
  **priehľadný široký duplikát** (`.hwhit`) — hit-oblasť značky pokrýva koľajnice
  aj telo, aby klik na vlastníka (UI-C4) fungoval rovnako ako pri závese a nohe;
  hover zvýraznenie sa tohto duplikátu **nesmie dotknúť**.

**Spodný pás (`.pvbar`)** je tenký pevný riadok pod SVG:

- **Vľavo chipy vrstiev** `Zóny · Čelá · Kovanie · Olep` (`.lchip`). Chip
  aktuálneho kontextu je **základ** (plná teal výplň, nie je to prepínač —
  je to popis toho, čo sa kreslí). Ostatné sa dajú **prisvietiť ako ghost**:
  tlmené čiarkované linky navrch projekcie, **bez výplní a bez interakcie** —
  ghost nikdy neprebije základný pohľad.
- **Olep** vie náhľad ukázať len pri označenom **dielci** (hranové dáta nesie
  výhradne `part_card`) — inde je chip **neaktívny s vysvetlením**, nie ticho
  mŕtvy. Rovnako je neaktívny každý chip, ktorý nemá čo kresliť.
- **Vpravo nástroje:** **kamera** (zarovná pohľad SketchUpu na označenú skrinku
  — čelný pohľad + doramovanie) a **fit** (reset zoomu). Fit sa sem presunul
  z rohového overlayu — náhľad má **jedno miesto ovládania** a plocha SVG
  ostáva čistá pre pan/zoom/ťah priečky.
- **Stav chipov je per kontext** a žije v pamäti okna: **nová identita výberu ho
  resetuje**, echo push ho nemení (tá istá zásada ako `viewContext` z UI-B1).
- Chipy sú `<button>` s `aria-disabled` (nie HTML `disabled`) — ostávajú
  fokusovateľné a nesú vysvetlenie (vzor D-78 / rail).

> **D-27 (rýchle zobraziť/skryť) tým NIE JE uzavreté:** chipy prepínajú vrstvy
> **náhľadu**, nie tagy modelu. Modelové tagy Čelá/Chrbát ostávajú na neskôr
> (vzor je checkbox „Zobraziť zóny (ghost) v modeli").

### 5.3 Základné — dva stĺpce, rozmerové rady a koliesko (UI-B3)

Sektor **Základné** je rozdelený na **vstupy vľavo a dopočítané údaje vpravo**
(`.basicgrid`). Vizuálna referencia je `SYSTEM/zdroje/ui20/mockup_inspector_c.html`
(`basicgrid` / `rowc` / `dwrap` / `miniopts` / `infocol`).

- **Vľavo kompaktné rozmery** (`.rowc`): Šírka · Výška · Hĺbka · Sokel · Hrúbka,
  každý s ikonou zo spritu. Pole je úzke a hodnota zarovnaná doprava —
  rozmer je číslo, nie veta (UX-03).
- **Vpravo informačný stĺpec** (`.infocol`) — **výstupy nikdy nevyzerajú ako
  vstupy** (trvalá zásada z kôl 15.8.). Dopočítaný údaj je **text**, nie
  readonly pole: Vnút. šírka · Vnút. hĺbka · Úložná výška · Dielcov · Materiál
  m² · Hmotnosť („—" s vysvetlením, že príde s kovaním fáza 3).
- **Klikateľné je len to, čo niekam vedie (N13)** — „Dielcov" označí výrobné
  dielce skrinky v modeli, „Materiál" povie, kam údaj patrí (Štúdio → Kusovník).
  Bez označenej skrinky sú riadky `aria-disabled` s vysvetlením (vzor D-78),
  nikdy ticho mŕtve.
- **Rozmerový rad (N6)** je **ponuka, nie ďalšie pole**: šípka pri poli otvorí
  `.miniopts` s bežnými hodnotami a položkou „Upraviť rad…". Voľba **len dosadí
  hodnotu do poľa** a ohlási ju rovnakou udalosťou ako písanie rukou — všetky
  guardy (výrazy, validácia, debounce apply, zámky D-39) bežia nezmenene.
  Otvorená je vždy najviac **jedna** ponuka a klik mimo nej ju zavrie (rovnaké
  správanie ako natívna rozbaľovačka). Hrúbka rad zámerne nemá — určuje ju
  materiál (D-45).
- **Hodnoty radov sú nastavenie POČÍTAČA** (`%APPDATA%\NOXUN\Engine\dim_series.json`),
  nie zákazky — rovnaký dôvod ako pri téme: Michal a Lucia otvárajú tie isté
  zákazky, ale majú vlastné zvyklosti. V editore **čiarka oddeľuje hodnoty**
  (hodnoty sú celé mm), nezmysel a čísla mimo 10–3000 mm sa **zahodia** — rad
  smie obsahovať len to, čo doň používateľ naozaj napísal.
- **Klik na informačný údaj, ktorý mení výber, má flush handshake:** rozpísaná
  úprava sa najprv odošle a **červené pole akciu zastaví** — inak by ju
  serverový push prepísal a úprava by ticho zmizla (rovnako ako „Vložiť kópiu"
  a exporty okna Výroba).
- **Skupiny v Nastaveniach majú ikony** (N3b) — ikona ukazuje **dielec, o ktorom
  skupina hovorí** (Strop · Dno · Boky · Chrbát) a rozsvieti sa s otvorenou
  skupinou. Ostatné kontexty ikony dostanú s blokom UI-C.
- **Typ korpusu je badge v hlavičke** (readonly): typ sa nastavuje **výhradne
  šablónou alebo vkladaním**, preto mini-modal „Uložiť ako šablónu" nesie
  **Názov + Typ** — je to jediné miesto, kde sa typ šablóny volí.

**Koliesko = Nastavenia Inspectora** otvára **modal** (nie ďalší kontext railu):
sú to nastavenia počítača, musia byť dostupné aj vtedy, keď nie je označené nič,
a stavový stroj kontextov (platných len nad korpusom) sa ich nesmie týkať. Tri
sekcie podľa kontraktu: **Vzhľad** (téma) · **Rozmerové rady** (editor — hodnoty
oddelené čiarkou, čistenie a poradie robí server) · **O plugine** (logo +
verzia z Ruby).

### 5.4 Vkladacia karta — typ, dlaždice šablón (UI-C1b), umiestnenie dosky (UI-C1c)

Vkladanie je **jediné miesto, kde sa objekt vytvára**, preto má vlastný vzor.
Vizuálna referencia je `SYSTEM/zdroje/ui20/mockup_inspector_c.html`
(`insTypeRow` / `sectInsertTpl` / `.segrow` / `.tpltiles`).

- **Typ objektu = tri segmentové tlačidlá** (`.segrow`): Dolná · Horná · Doska.
  Rádiá zanikli — je to jedna voľba z troch, nie dve nezávislé otázky. Aktívne
  tlačidlo nesie **výberovú rodinu** (teal), nie zelenú: je to *stav*, nie akcia.
  Ikona ukazuje, **kde objekt stojí** (`cab-low` na sokli · `cab-high` zavesená ·
  `slab` doska).
- **Šablóny sú dlaždice** (`.tpltiles` / `.tpltile`, 3 stĺpce, výška ~56 px) v
  **zrolovateľnej** sekcii — vertikálny priestor je vzácny a mriežka je aj tak
  vidieť „na jeden pohľad". Dve skupiny: **Naposledy použité** (max 3, N16 — vynechá
  sa, keď ešte nie je čo ukázať) a **Všetky šablóny**.
- **Klik vyberá, dvojklik vkladá (N17).** Obe cesty idú cez **tú istú validovanú**
  insert funkciu ako zelené tlačidlo. Výber **nesmie prestavať mriežku** — mení sa
  len trieda `.on`; prestavba patrí zmene typu a novej knižnici. (Klik, ktorý
  zahodí uzol, by v CEF druhému kliku dvojkliku nenechal cieľ.)
- **Kresba dlaždice nenesie farbu.** Schéma z configu (riadky čiel, krídla, police)
  je len geometria; obrys a výplň dávajú tokeny v CSS.
- **Reálny PNG náhľad má prednosť pred schémou (UI-D2).** Fotka vzniká pri
  UKLADANÍ šablóny (`view.write_image` nad práve postavenou skrinkou) a do
  dlaždice sa doťahuje **na vyžiadanie, raz na revíziu** — data URI nemôže
  cestovať v každom pushi knižnice. Keď fotka nie je (staršia šablóna, zlyhaný
  capture), dlaždica **ostane na schéme** — nikdy prázdne miesto. Obrázok sa
  vkladá `object-fit: contain` (nie `cover`): orezať skrinku, aby vyplnila
  dlaždicu, by z nej spravilo iný nábytok.
- **Akcia patrí tam, kde je na nej čo vykonať.** Ručné „Odfotiť náhľad
  z označenej skrinky" (doplnenie fotiek starým šablónam) sa **nedá** dať na
  dlaždicu panela: dlaždice sú viditeľné výhradne vtedy, keď **nie je označené
  nič**, takže by kamera nikdy nenašla skrinku a bola by to trvalo mŕtva ikona
  (opak zásady „klikateľné je len to, čo niekam vedie"). Žije preto v okne
  **Šablóny**, kde výber v modeli a zoznam šablón existujú súčasne — presne tak,
  ako tam už funguje „Použiť na označený".
- **Primárna akcia je posledná** — zelené „Vložiť" stojí až za rozmermi *aj* za
  materiálom (rovnaký dôvod, prečo tam už stálo „Vložiť dosku").
- **Odhad namiesto ticha:** dopočítané údaje, ktoré pre nevložený návrh nemá kto
  spočítať presne, sa ukazujú so značkou **≈** a s vysvetlením v tooltipe —
  nikdy nie pomlčka a nikdy nie číslo, ktoré sa tvári ako presné.
- **Umiestnenie dosky = ďalší `.segrow`** (Naležato · Nastojato · Na stenu) —
  rovnaký vzor ako typ objektu, **nie select**: sú to tri rovnocenné stavy a
  ikona povie viac než slovo. Stojí **dvakrát**: v karte vkladania a na karte
  označenej dosky, s rovnakými popiskami. Každý segment nesie `aria-label`
  (celá veta) aj `title`; stav je `aria-pressed` + trieda `.on`. Je to **údaj
  umiestnenia, nie výrobný** — kusovník, hrany ani dekor sa ním nemenia, a UI to
  hovorí nahlas (tooltipy aj hint karty). Klik na už zvolenú hodnotu je **no-op**
  (žiadny prázdny krok Späť); na karte vloženej dosky sa pred odoslaním flushne
  čakajúci debounce ostatných polí.

### 5.5 Zóny — štruktúra, dlaždice a presné delenie (UI-C2)

Vizuálna referencia: `SYSTEM/zdroje/ui20/mockup_inspector_c.html` (`s4Zones`).

- **Štruktúra je NAVRCH kontextu** a má **vlastné rozrolovanie** (`data-s4-solo`,
  mimo exkluzivity skupín). Je to mapa, v ktorej sa vyberá — nesmie zmiznúť
  vtedy, keď používateľ otvorí Delenie alebo Police.
- **Strom kreslí spojnice, nie odsadenie.** Každá úroveň má vlastný kontajner
  `.zkids` s ľavou linkou a vodorovným „zubom“ pri uzle; prázdny kontajner
  (listová zóna) sa nekreslí vôbec. Padding by čiaru nakresliť nevedel.
- **Delenie sú 4 dlaždice** — „2 stĺpce · 3 stĺpce · 2 riadky · 3 riadky“.
  Ikona JE odpoveď na otázku „čo sa stane“, text je len potvrdenie.
- **Aktivita ovládača je pravidlo, nie kozmetika.** Dlaždice a pilulky políc
  patria **listovej** zóne; na delenej sú viditeľné, ale neaktívne s vysvetlením
  („Zóna je delená — najprv Vyčistiť zónu“). Pole **„Prvá zóna“ je naopak
  aktívne len na delenej zóne**. Neaktívny stav je vždy `aria-disabled` +
  trieda, **nikdy HTML `disabled`** (vzor D-78) — inak by prvok zhltol hover aj
  tooltip a používateľ by sa dôvod nedozvedel; klik naň dôvod aj vypíše.
- **Jediná deštruktívna cesta je „Vyčistiť zónu“.** Opakované delenie už delenej
  zóny by ticho zmazalo celý podstrom aj s materiálmi a ABS dielcov, preto ho
  odmieta aj server. **Vedomá odchýlka od mockupu**, ktorý dlaždice kreslí
  aktívne aj nad delenou Z1.2 — mockup sa dorovná pri najbližšom 1:1 kole.
- **Zámok = vypísaná hodnota** (rovnaké pravidlo ako výšky čiel): vyplnená
  „Prvá zóna“ pole 1 zamkne, prázdne pole je AUTO a odomyká. Pole je **skratka**
  na pole 1 — úplná cesta so zámkom každého poľa ostáva v zozname pod ním.
- **Presné delenie číslom (N21) radšej ODMIETNE, než by ticho zmenšilo.**
  Nezmestiteľná hodnota vypíše, koľko by ostatným poliam ostalo a koľko treba;
  zvyšok sa dorovná do posledného odomknutého poľa. Presnosť je **0,01 mm** —
  zaokrúhľovanie na celé mm by pri troch poliach z korpusu „zjedlo“ až 2 mm.
- **Zlomky a magnet sú JEDNA geometria.** Oboje hovorí o tom istom: kde má sedieť
  **stred priečky**. Ponúkajú sa 1/4 · 1/3 · 1/2 (magnet ťahania 1/4 · 1/2 · 3/4,
  **Alt ho vypína**), nedosiahnuteľný zlomok sa neponúka. Číslo v poli je rozmer
  vo **svetlom priestore**, takže 1/2 z 864 mm pri hrúbke 18 je 423, nie 432.
- **Police sú pilulky 0–6** — jeden klik, žiadny select s tlačidlom „nastav“.
- **Vnútro je rezervovaný slot** (vnútorné zásuvky, koše, tyče) — prázdna skupina
  s vysvetlením je poctivejšia než chýbajúce miesto: hovorí, že sa naň myslelo.

### 5.6 Ostatné vzory

- **Sticky hlavička (Inspector):** jednoradová, zostáva pri scrollovaní
  (`position: sticky`, `z-index` pod modalom 60): logo + ID + názov s ceruzkou
  + ⚠ chip. Režimové taby aj satelitné tlačidlá (Materiály·Výroba·Kovanie)
  **zanikli v UI-B1** — kontexty prevzal rail, Štúdio je v raile, Materiály
  projektu žijú v sektore Materiály a Katalóg kovania v skupine Kovanie.
  `scroll-padding-top` = výška hlavičky, aby fokusované pole neskončilo pod ňou.
- **Pätička:** v normálnom toku na konci obsahu — `Noxun Engine V<verzia>`.
  Verzia príde z Ruby (`Engine::VERSION`), nikdy sa nedopĺňa prípona cache-bustu.
- **Tlačidlá:** `.primary` (akcia, zelená), `.ghostbtn` (neutrál), `.danger`
  (mazanie, červená). Ikonové akcie sú kompaktné, s `aria-label`.
- **Náhľad:** fixné okno so zoom/pan; ovládanie (kamera + fit) žije v **spodnom
  páse** — viď 5.2.
- **Karty:** `fieldset`/`details` na bielom povrchu, rámik `--nx-border`.
- **Warn chip → warnpanel (N5, UI-D3):** klik na ⚠ chip otvorí **overlay** pod
  hlavičkou — `position: absolute` **vnútri sticky `<header>`**, nie riadok
  layoutu. Blokový zoznam (pôvodné riešenie D-29) otvorením posunul celý obsah
  nadol a musel si pomáhať skokom na začiatok stránky; overlay nerobí ani jedno
  a drží sa pri chipe aj po odscrollovaní. **Každý riadok má oko** — označí
  v modeli to, o čom nález hovorí (dielec, alebo celú skrinku, keď nález patrí
  korpusovej úrovni). Dole **jedna cesta von**: „Otvoriť v Štúdiu → Kontrola".
  Zatvára ho **klik mimo a Escape** (fokus späť na chip); klik vnútri panela aj
  na samotný chip **zastavuje bublanie** — inak by sa panel v tom istom kliku
  otvoril a hneď zavrel. Šírka 300 px, tieň `--nx-modal-shadow`, rámik
  `--nx-warnchip-border` (rovnaká jantárová rodina ako chip; modal ostáva nad
  ním, lebo hlavička je `z-index: 50` a modal 60).
- **Overlay musí mať strop výšky a vlastný scroller.** Prvok mimo dokumentového
  toku sa **scrollom stránky nedá dotiahnuť**: pri dlhom obsahu skončia spodné
  riadky *aj cesta von* pod okrajom okna a používateľ sa k nim nedostane.
  Preto `max-height` viazaná na viewport + `overflow-y: auto` na **zozname**,
  nie na celom paneli — akcia dole musí zostať na očnom mieste. (Vo flexe k
  tomu patrí `min-height: 0`, inak sa položka pod svoj obsah nezmenší.)
- **Overlay, ktorý zastavuje bublanie, vypadne z merača D-25** — preto merač
  počíta klik v **capture fáze**. Nový overlay so zatváraním „klikom mimo" tak
  nemusí na nič pamätať; nezabudni len pridať jeho `data-nx-usage` kľúče do
  allowlistu (`USAGE_KEYS`), inak sa počítajú pod generickým kľúčom.
- **Deep-link namiesto „nájdi si to sám" (UI-D3):** informačný údaj, ktorý na
  niečo ukazuje, otvára cieľ **rovno na správnom mieste** — ⚠ panel na tabe
  KONTROLA, „Materiál" na tabe Kusovník. Kým Štúdio neexistuje, je cieľom okno
  Výroba a **hovorí sa to nahlas** (tooltip aj status). Čo cieľ **nevie**, sa
  nepredstiera: kusovník nemá filter na jednu skrinku, takže sa nevymýšľa — len
  sa povie, že vidno celú zákazku a filter príde so Štúdiom.
- **Veľkosť okna pri otvorení (D-77):** žiadne okno sa nesmie otvoriť odseknuté.
  `width`/`height` v `HtmlDialog.new` platia len pri PRVOM otvorení (potom
  rozhoduje veľkosť zapamätaná pod `preferences_key`), preto každé okno deklaruje
  v HTML svoje **obsahové minimum** `window.NX_FIT_MIN = { w, h }` a načíta
  `js/win_fit.js` — to okno pri otvorení dorovná. Dorovnáva sa **oboma smermi**:
  nahor po deklarované minimum, nadol po dostupnú plochu obrazovky (okno
  zapamätané z väčšieho monitora je inak orezané rovnako). **Plocha má prednosť
  pred minimom**; medzi minimom a plochou sa veľkosti okna nikto nedotkne, takže
  vedome zväčšené okno ostáva. Nové okno = nové `NX_FIT_MIN` (bez neho fit nebeží).

### 5.7 Čelá — riadky, AUTO chip, Úchytky (UI-C3)

Vizuálna referencia: `SYSTEM/zdroje/ui20/mockup_inspector_c.html` (`s4Fronts`).

- **Kontext má tri skupiny v záväznom poradí:** Zoznam čiel · **Úchytky** ·
  Medzery a presahy. Ikony skupín (N3b) ukazujú, o čom skupina hovorí
  (`front` · `profile` · `columns-2`).
- **Riadok začína ikonou typu (N27).** Ikona odpovedá na „čo to je" skôr, než
  sa oko dostane k textu rozbaľovačky — nie je to jej náhrada, obe zostávajú.
- **Rad ovládačov sa NEZALAMUJE** (smoke test 20.8.). Riadok čela je **stĺpec**:
  hore pevný nezalamovací rad `.fmain`, pod ním riadok kovania. Zalamovací rad
  vyzeral bezpečne, kým bola výška prázdna — vypísaná hodnota k nemu pridala
  „mm" aj chip AUTO a krížik ✗ spadol o riadok nižšie. **Pravidlo pre budúce
  ovládače:** v takom rade smie **rásť jediný prvok** (tu `select.ftype`),
  všetko ostatné má pevnú stopu, a súčet stôp + medzier musí sedieť pri šírke
  **470 px** — stráži to guard test, nie oko. **Do rozpočtu patrí aj to, čo sa
  objaví len chvíľu**: živý náhľad výrazu („= 450") sa preto kreslí ako
  **overlay pod poľom**, nie ako ďalšia položka radu — inak by riadok pretiekol
  vždy, keď používateľ píše výraz.
- **Predel medzi položkami je hairline, nie nový riadok.** Jemná linka
  (`--nx-border-soft`) sa platí **presunutím** existujúceho odstupu z `margin`
  do `padding`, nie jeho pripočítaním. Predel patrí pod **celú položku** — pri
  čele teda až pod riadok naviazaného kovania, ktorý k nemu patrí.
- **Zámok pri výške ZANIKOL: zamknuté ⇔ vypísané.** Vypísaná hodnota drží,
  prázdne pole je AUTO. Samostatný checkbox vedel byť zapnutý aj nad prázdnym
  poľom a nerobil nič — dve pravdy o tom istom. Návrat na automat robí **chip
  AUTO**, ktorý sa (spolu s jednotkou „mm") ukazuje **len pri vypísanej
  hodnote**: prázdnemu poľu niet čo vracať a jednotka by patrila k ničomu.
  Pevná výška je aj **vidno** (tučnejšia hodnota, `.frow.fixed`) — zámok
  nesmie zmiznúť tým, že prestal mať vlastnú ikonu. Rovnaké pravidlo má pole
  „Prvá zóna" z UI-C2.
- **Pole výšky je úzke (46 px) a hodnota zarovnaná doprava** — rozmer je číslo,
  nie veta (UX-03). Jednotka stojí **pri hodnote**, nie v hlavičke stĺpca.
- **Rozmerový rad je ponuka, nie ďalšie pole** (N25, rovnaký vzor ako pri
  rozmeroch korpusu). Voľba len **dosadí** hodnotu a ohlási ju rovnakou
  udalosťou ako písanie rukou.
- **Naviazané kovanie je JEDEN drobný riadok pod čelom**, nie tabuľka
  (vertikálny priestor je vzácny): jednoriadkový s ellipsis, plný text v
  `title`, klik vedie **do kontextu Kovanie** a doskočí na položku vlastníka
  (krátke zvýraznenie, aby ju používateľ po skoku nehľadal). Obsah skladajú
  existujúce zdroje — badge z plánu a nákupný set z D-92; panel nič
  nedopočítava.
- **D-84 reč stolára:** „+ pridaj dvere" (krídlové) a „+ pridaj čelo"
  (zásuvkové). Odoberacie tlačidlo **zaniklo** — mazanie ostáva krížikom pri
  konkrétnom riadku (jednoznačné, ktorý mizne) a v rade sa uvoľní miesto.
- **Materiál čiel stojí aj v zozname.** Sektor Materiály patrí kontextu Korpus
  a tu je skrytý — bez druhého ovládača by sa dekor menil inde, než sa čelá
  kreslia. Je to **ten istý údaj v dvoch ovládačoch**, nie nové dáta; synchro
  drží každá cesta, ktorá siaha na materiál čiel.
- **D-96 Úchytky:** profil sa nastavuje **v sekcii pre rozsah čiel**
  (všetky / len zásuvkové / len dvierka), ikona v riadku je už len
  **INDIKÁTOR** (žiaden rám tlačidla, žiaden kurzor akcie). Cyklenie klikom
  bolo použiteľné len pri jednom profile. Rôzne profily v rozsahu ukáže
  **disabled voľba „(rôzne)"** — select nikdy netvrdí zhodu, ktorá neplatí
  (vzor „podľa parametra" zo sekcie Kovanie). **Hrana osadenia sa neponúka**,
  kým ju registry profilov nepozná: ponúkať voľbu, ktorá nemá kam sadnúť, je
  lož.
- **Výklop je v ponuke typov, ale zatiaľ NEvyberateľný** — s upozornením
  „AVENTOS ručne, automatika fáza 3". Vedomá odchýlka: rola `flap` potrebuje
  vlastnú cestu cez builder, ABS a kusovník, čo je samostatná dávka.
  Poctivejšie je povedať, že sa s ním ráta, než ho zamlčať (rovnaký vzor ako
  rezervovaný slot „Vnútro" v Zónach).
- **N26 medzery jantárovo:** pri otvorenej skupine „Medzery a presahy" (alebo
  kurzore v jej poli) sa medzery v projekcii Čelá podfarbia. Je to **len
  zvýraznenie** — pásy vznikajú z toho istého rozkladu, ktorým sa už kótuje.
- **Interaktívne prvky v riadku STOPUJÚ bublanie** (lekcia: rozbaľovačka sa
  zatvárala) — platí pre chip AUTO, šípku radu aj riadok kovania.

### 5.8 D-89a — hover hrany zvýrazní hranu v MODELI

- Kurzor nad hranou **v karte dielca alebo dosky** (riadok zoznamu aj farebný
  pás 2D náhľadu) rozsvieti tú istú hranu priamo v modeli. Rieši
  „ktorá hrana je ktorá strana" bez domýšľania z orientácie.
- **Je to pohľad, nie dáta:** `Sketchup::Overlay` NAD modelom — žiadna
  operácia, žiadny zápis, **žiadny krok Späť**, nič v .skp (lekcia D-103,
  presne vzor D-104/D-105). Zhasína pri odchode kurzora, prekreslení karty,
  zatvorení panela aj prepnutí dokumentu.
- **Farba je výber** (`--nx-select`), zámerne **nie** `--nx-edge-*`: tie tri
  farby hovoria o stave olepu a miešať ich s „toto je hrana pod kurzorom" by
  používateľ čítal ako nález. Plôška leží o kúsok **nad** kontrolou olepu,
  aby bola vidno aj pri zapnutom zvýraznení hrán.
- **Nič sa nehľadá:** zvýrazňuje sa hrana **práve vybratého** dielca (karta je
  jeho zrkadlo) — žiadny scan modelu, jedna plôška. Keď sa osi dielca nedajú
  jednoznačne overiť, **nekreslí sa nič** (tá istá zásada ako D-104).
- **Posiela sa len ZMENA** kódu hrany — pohyb myšou inak zaplaví most do Ruby
  desiatkami volaní na jeden riadok.

### 5.9 Dielec — Základné hore, hranové ikony, rad akcií (UI-D1)

Vizuálna referencia: `SYSTEM/zdroje/ui20/mockup_inspector_c.html` (`s4Part`,
`sectPartBasic`).

- **Poradie karty je kontrakt:** Základné · Materiál · hrany · **rad akcií
  dole**. Rozmery dielca sú **VÝSTUP** — počíta ich korpus — preto sú to
  informačné riadky v tej istej mriežke ako Základné korpusu, **nikdy polia**
  („výstup nikdy nevyzerá ako vstup"). Karta narástla o **jeden** riadok
  (dva a dva údaje), nie o tri.
- **Smer dekoru je VSTUP** (K1 / D-108, v0.7.23). Pôvodná odchýlka UI-D1
  („smer je len informácia") **skončila** — per-dielec override existuje
  (`part_overrides['grain_direction']`, enum `length`/`width`), prešiel
  auditom a zapisuje sa do snapshotu dielca. Je to **segment troch volieb**
  `Podľa materiálu · Pozdĺžna · Priečna` v riadkovom tvare „popisok +
  ovládač" (trieda `.pcgrain`, rovnaká mriežka ako `Materiál`), takže karta
  nenarástla o samostatný riadok. Pravidlá:
  - **dedený stav ukazuje VÝSLEDOK** („Podľa materiálu — pozdĺžna"), nikdy
    prázdne slovo „dedí" — nevidieť, ako kresba ide, bol presne slepý bod
    výrobného incidentu 19.8.2026;
  - **každá voľba nesie v tooltipe výrobný rozmer** (2000×250 vs 250×2000),
    takže otočenie kresby je vidieť pred odoslaním objednávky;
  - **všetky texty skladá server** (`Panel.part_grain_payload`, vzor D-102) —
    JS iba maľuje; chýbajúci payload popisy vráti na neutrálnu zálohu
    z kostry, nikdy nenechá tooltip predošlého dielca;
  - **ručný zásah je jantárový** (`.ovr` — rovnaký jazyk ako `select.ovr` pri
    materiáli a hranách), dedený stav tealový;
  - **materiál bez smeru segment zamkne** cez `aria-disabled` (vzor D-78,
    nikdy HTML `disabled`) + hint; klik vtedy nič nezapisuje, len odvedie na
    materiál. Uložený smer sa **nemaže** — s dekorovým materiálom ožije.
- **Hranový riadok začína ikonou `edge` — jedna kresba, štyri rotácie.**
  Uhol dáva **strana v 2D náhľade** (`AbsRules.edge_sides`), takže ikona
  ukazuje presne tú hranu, ktorú náhľad nad zoznamom farebne kreslí. *Vedomá
  odchýlka od mockupu*, ktorý rotuje podľa pevnej mapy „predná 0° · zadná
  180° · ľavá 90° · pravá 270°": tá by pri ležiacich dielcoch ukázala inú
  stranu než náhľad a pre roly s labelmi „Pozdĺžna/Priečna" (výstuhy, doska)
  by neexistovala. Ikona je tlmená (`--nx-ink-faint`) — je to orientácia,
  nie stav; stav olepu nesie farebný štvorec vedľa nej.
- **Rad akcií je JEDEN riadok dole** (vertikálny priestor je vzácny):
  **„Označiť v modeli"** (`eye`) a **„Použiť na podobné…"** (`copy`).
  Označenie je **zmena pohľadu na model**, nie zápis — žiadny krok Späť
  (rovnaká zásada ako kamera N7, „Dielcov" N13 a box vlastníka UI-C4).
- **„Použiť na podobné…" je mini-modal** (vzor „Uložiť ako šablónu"):
  rozsah ako **segmentový prepínač** (Táto skrinka / Celý projekt) + **živý
  počet** jedným výrazným riadkom. Počet **počíta server** tou istou funkciou,
  ktorou potom aj zapisuje — modal nesmie sľúbiť iné číslo, než sa zapíše.
  Nula sa nezobrazí ako číslo, ale ako **dôvod** („rovnakú rolu a materiál
  nemá v tomto rozsahu nikto iný") a tlačidlo je neaktívne s návodom
  („skús celý projekt") — `aria-disabled`, nikdy HTML `disabled` (vzor D-78).
  Modal vopred hovorí, že prenáša **len olep hrán** a že je to **jeden krok
  Späť**.

### 5.10 Kovanie — boxy vlastníka a značky náhľadu (UI-C4)

Vizuálna referencia: `SYSTEM/zdroje/ui20/mockup_inspector_c.html` (`s4Hw`).

- **Položky sú zoskupené podľa VLASTNÍKA, nie podľa typu** (`.hwbox`): „Skrinka" ·
  box každého čela · spoločný box „Vnútro skrinky". Je to **iba iné zobrazenie
  tých istých dát** — identita položky, zápisové cesty aj nákupný riadok D-92
  ostávajú nedotknuté.
- **Hlavička boxu je `<button>` a SÚRODENEC tela, nie jeho obal.** Klik na select
  setu či pole počtu tak k hlavičke nemá ako dobublať — je to štrukturálne
  silnejšie než `stopPropagation`, na ktorý by musel pamätať každý budúci ovládač.
- **Klik na hlavičku označí vlastníka v modeli** (zmena pohľadu, nie zápis —
  žiadny krok Späť, rovnaká zásada ako „Dielcov" N13 a kamera N7). Cieľ skoku sa
  **krátko prisvieti** (`.hwfocus`): položiek býva viac, než sa zmestí na obraz.
- **Box ↔ značka v náhľade sú prepojené OBOMA smermi** a nasadzuje ich **jedna**
  funkcia, aby sa smery nemohli rozísť. Hover **nikdy nekreslí náhľad nanovo**
  (lekcia D-23) — beží len CSS triedou nad už vykresleným SVG.
- **Box sa nezbaľuje.** Na skrátenie panela stačí exkluzivita skupín S4; druhé
  zbaľovanie v zbaľovaní je klik navyše bez zisku.
- **Dlhý názov sa OREŽE, nikdy nepretečie** (smoke test 20.8.). `.hwname` je
  jednoriadkový s ellipsis a plný popis nesie `title`. Text bez orezu vyzerá
  ako „len sa nezmestí", v skutočnosti **prekryje** susedný ovládač — a to je
  horšie než skrátený názov. Selecty v riadku majú šírku **podľa obsahu
  v medziach** (`flex: 0 1 auto` + min/max, vzor UX-03), nie pevných N px:
  krátke názvy setov inak plytvali miestom a dlhé sa aj tak nezmestili.
- **Rovnaké položky sa zbalia pod JEDEN súhrn** (smoke test 20.8.). Podperky
  políc mali riadok na každú policu, hoci hovoria to isté — teraz je nad nimi
  súhrn **„Podperky políc — 5 políc: 20 ks"** s rozklikom. Zásady:
  **editovateľnosť sa nesmie stratiť** (pod rozklikom sú pôvodné riadky, počet
  per polica sa mení ďalej) · **zbalené je default** a stav rozkliku je vec
  **počítača** (`localStorage`, vzor sektorov) · **neštandard musí byť vidieť aj
  zbalený** — ručne upravená **aj vypnutá** polica rozsvieti v súhrne jantárový
  štítok „upravené" · **súhrn nesmie zamlčať vypnutú položku** (vypnutá polica
  je stále polica: patrí pod ten istý rozklik, ráta sa do počtu a prispieva
  0 ks — inak by súhrn hovoril „4 police" a piata by visela vedľa neho) ·
  **jedna položka sa nezbaľuje** (rozklik nad jediným riadkom je klik navyše
  bez zisku) · dáta sa nemenia, je to **zoskupenie zobrazenia**.

### 5.11 Flyout roh — druhá akcia na ikonovom tlačidle (v0.7.28)

Keď má ikonové tlačidlo (rail, toolbar) okrem svojej hlavnej akcie aj
**nastavenie**, nesie ho **rohový flyout** — vzor prevzatý z nástrojov
SketchUpu a Photoshopu, teda z prostredia, v ktorom stolár denne pracuje.
Prvý výskyt: **ABS kontrola v raile** (toggle + 3-stavové nastavenie kontroly
hrán). Pravidlá vzoru:

- **Znamienko je malý PLNÝ trojuholník** v pravom dolnom rohu ikony (6 px, CSS
  `border` trojuholník ako pseudo-prvok `::after`) — nie chevron, nie druhá
  ikona, nič, čo by pýtalo ďalšie miesto. Farbu dedí od stavu tlačidla
  (tlmená `--nx-ink-faint`, po zapnutí `--nx-select`).
- **Klikacia zóna ≠ znamienko.** Terč je celý **pravý dolný kvadrant** tlačidla
  (pri 34 × 32 px raile 17 × 16 px) — 6 px trojuholník sa myšou netrafí.
- **Roh je SAMOSTATNÉ `<button>`** v spoločnom obale (`.railfly`), ležiace *nad*
  hlavným tlačidlom (`z-index`), nikdy vnorené doň: tlačidlo v tlačidle je
  neplatné HTML a `span` s `role="button"` sa nedá aktivovať klávesnicou
  (rovnaká lekcia ako krížik dočasnej položky). Klik na roh sa tak k hlavnej
  akcii **vôbec nedostane** — netreba naň spoliehať `stopPropagation`.
- **Hlavná akcia sa nemení.** Klik na ikonu robí presne to, čo robil predtým.
- **Dva rôzne `aria-label`** („ABS kontrola hrán" vs. „Nastavenie ABS kontroly")
  + `aria-haspopup`/`aria-expanded` na rohu — čítačka musí vedieť, že sú to dve
  akcie. Roh má **vlastnú bublinu** `.railtip` (rail nepoužíva natívny `title`).
- **Vlastný kľúč merača** (D-25): `rail:abs-nastavenie` vedľa `rail:abs` — inak
  by odpočet nevedel povedať, či sa nastavenie vôbec používa.
- **Okno je overlay pri tlačidle** (`position: absolute`, `left` za railom), nie
  modal v strede obrazovky a nikdy nie nový riadok layoutu. Zatvára ho **klik
  mimo a Escape**, fokus sa vracia na roh (vzor warnpanelu).
- **Ak to isté nastavenie žije aj inde, je to JEDEN komponent, nie kópia.**
  Markup kreslí zdieľaný modul (`ui/js/edge_menu.js`), štýly sú v zdieľanom
  `panel.css` (nescopnuté pod `.nx-inspector` — satelit o raile nevie) a stav
  aj počty nesie výhradne server, ktorý po každom zápise pošle čerstvý stav
  **všetkým oknám**. Dve kópie toho istého okna nesmú stáť na obrazovke naraz:
  otvorenie na jednom mieste ostatné zavrie.
- **Flyout dostane len tlačidlo, ktoré naozaj má čo nastavovať.** „Kontrola
  kresby" ostáva obyčajný toggle bez trojuholníka — prázdny flyout by klamal.
- **Vzor platí aj pre TEXTOVÉ tlačidlo v lište sekcie (ŠT-1b).** „Zvýrazniť
  hrany" v lište sekcie Kontrola (Štúdio) nesie ten istý rohový trojuholník ako
  ikona v raile: znamienko je `::after` pseudo-prvok tlačidla (po zapnutí dedí
  `--nx-on-accent`, aby na farebnom podklade nezmizlo), klikacia zóna je
  samostatný `.cornerzone` v pravom dolnom rohu a text tlačidla má o toľko
  väčší pravý padding, aby sa naň roh nepoložil. **Spúšťač je tvarom per okno,
  samotné okno nastavenia je zdieľaný komponent** — líši sa iba polohovacou
  triedou (`.ecmenu-rail` vs. `.ecmenu-studio`). Split tlačidlo s chevronom
  (pôvodná podoba v okne Výroba) tým **zaniklo** — jeden vzor, nie dva.

### D-51: štandard rozmerov okien (UI-B1)

**Jedna pravda je OBSAHOVÝ viewport** (`NX_FIT_MIN` v HTML). Rozmery
v `HtmlDialog.new` sú **vonkajšie** — obsah + rámik okna (Windows ≈ 16 px šírka,
≈ 40 px výška). Preto sa vždy zapisuje trojica **`NX_FIT_MIN` → `width`/`height`
→ `min_width`/`min_height`** a musí si zodpovedať (stráži guard test
`tests/pure/test_uib1_kostra.rb`).

| Okno | Obsah (`NX_FIT_MIN`) | `width` × `height` | `min_width` × `min_height` |
|---|---|---|---|
| **Inspector** (`panel.html`) | 470 × 810 | 486 × 850 | 486 × 600 |
| **Štúdio** (`studio.html`) | 1060 × 640 | 1076 × 680 | 1076 × 520 |
| Výroba (`production.html`) | podľa deklarácie v HTML | — | — |
| Materiály (`proj_materials.html`) | podľa deklarácie v HTML | 720 × 640 | — |
| ostatné satelity | podľa deklarácie v HTML | — | — |

> **470 px Inspectora** je obsah = rail 44 px + karta. Hodnota je záväzná pre
> celý blok UI 2.0 — mockup, sektory aj šírky polí sa navrhujú na ňu.
> **1060 px Štúdia** je navigácia 208 px + tabuľka Kusovníka so 7 stĺpcami
> a stĺpcom hover akcií; v užšom okne končí pravá časť riadku mimo. Výška 640
> nechá pod lištou sekcie vidieť aspoň dve skupiny materiálu naraz.
> **ŠT-1c PR B1 hodnotu preverila na najširšej tabuľke rozpočtu** (Spotrebiče:
> typ · názov · dodávateľ · cena · stĺpec akcií · medzisúčet, teda editovateľné
> bunky aj akcie vpravo): telo sekcie má pri 1060 px ≈ 828 px, čo je viac než
> šírka, na ktorej tá istá tabuľka žila v okne Výroba (obsah 640 px) aj než
> minimum mockupu (`#stageStudio` 900 px vrátane navigácie). **Hodnota sa preto
> NEMENÍ** — zdvihnúť ju kvôli sekcii, ktorá sa zmestí, by len zbytočne
> zväčšilo okno na malých obrazovkách.
> Satelitné okná dostanú svoje riadky tabuľky, keď ich prevezme Štúdio.

### Vzory okna Štúdio (ŠT-1a)

- **Nemigrovaná položka navigácie NIE JE `disabled` — je to PREMOSTENIE.**
  Klik otvorí okno, kde obsah dnes naozaj je, a tooltip prizná v ktorej dávke
  sa presunie sem. `aria-disabled` (vzor D-78) dostane len to, čo **nikde
  neexistuje** — v ŠT-1a jediný Nárezový plán („fáza 2"). Rozdiel je vecný:
  premostenie vedie tam, kam ukazuje; disabled hovorí, prečo zatiaľ nikam.
- **Neexistujúci export je viditeľné `aria-disabled` tlačidlo s dôvodom,
  nie skryté tlačidlo.** Michal porovnáva panel 1:1 s mockupom — chýbajúci
  ovládač vyzerá ako chyba implementácie, priznaný ovládač ako plán.
- **Výstup sa nikdy netvári ako vstup.** Údaj, ktorý sa edituje inde, je
  v ostatných oknách TEXT (názov projektu: input v Štúdiu → Kusovník,
  text v hlavičke okna Výroba).
- **Voľba zobrazenia je vec POČÍTAČA, nie zákazky.** Voliteľné stĺpce,
  zbalené skupiny a zbalená navigácia žijú v `localStorage` (nikdy v `.skp`
  a nikdy v `%APPDATA%` — nie je to nastavenie pluginu, len tohto okna).
- **Kódy hrán `L1/L2/W1/W2` sa v tabuľkách neprekladajú** na „predná/zadná" —
  ten istý kód znamená pri každej role inú fyzickú hranu. Fyzickú stranu
  ukazuje karta dielca v Inspectore, ktorá ju zároveň kreslí.

### 5.12 D-15 — zdieľaná kostra modalov „pridávačiek" (`ui/js/nx_modal.js`)

Schválený vzor kontraktu UI 2.0 (`SYSTEM/zdroje/ui20/UI20_KONTRAKT.md`, sekcia
„D-15 pridávačky ako modal"). **Každé okno typu „pridaj niečo" je TÁ ISTÁ
kostra, len s inými poľami** — nikdy vlastný formulár. Prvá kódová inštancia
prišla s ŠT-1c PR B2 (drafty rozpočtu); ďalšie sa napájajú bez kopírovania.

**Kostra (mockup `mockup_studio.html`):**

| Časť | Trieda | Obsah |
|---|---|---|
| hlavička | `.mhead` | `<h3>` titulok · `.msub` podtitul (kontext) · `.mx` krížik vpravo |
| telo | `.mbody` | riadky `.mrow` = `<label>` + pole; pod nimi voliteľný `.hint` |
| pätka | `.mfoot` | `.spacer` · **Zrušiť** (`ghostbtn`) · **zelené potvrdenie** (`primary`) |

Scrim je `.nxscrim` (`--nx-scrim`), karta `.nxmcard` (`.sm` = 420 px, inak
560 px). **Pozor:** mockup kreslí kartu ako `.nxmodal`, lenže `panel.css` toto
meno už používa pre SCRIM starších modalov — preto `.nxmcard`.

**Správanie (záväzné pre každú inštanciu):**

- **Esc** aj **klik na scrim** (nie do karty) modal zatvárajú;
- **fokus ide do prvého poľa** pri otvorení a **vracia sa na spúšťač** pri
  zatvorení — inak by klávesnicová cesta skončila na `<body>`;
- **Enter v poli = potvrdenie** (do `<select>` sa nezasahuje);
- **potvrdenie modal NEZATVÁRA.** Odošle hodnoty a zatvorenie je rozhodnutie
  volajúceho: zavrieť ho smie **len potvrdenie servera**. Odmietnutý zápis
  musí používateľ nájsť **s rozpísanými hodnotami na mieste** — má opraviť
  svoje číslo, nie písať celý formulár znova.
- **jedno odoslanie naraz.** Prvý `submit` modal zamkne a potvrdzovacie
  tlačidlo zošedne; ďalšie kliky a Entery sa zahadzujú. Odomyká **volajúci**
  (`NXModal.setBusy(false)`) v **oboch** vetvách výsledku. Dôvod: zápis do
  modelu je asynchrónny, takže druhý Enter by neprepadol — počkal by si vo
  fronte a odišiel s čerstvou generáciou, ktorú server **prijme**. Výsledok by
  bola tá istá položka dvakrát a dva kroky Späť.
- **rozpísané hodnoty prežijú zatvorenie.** Esc ani klik vedľa nesmú byť tichá
  strata — hodnoty sa pamätajú per pridávačka a nasledujúce otvorenie ich
  predvyplní; zmaže ich až úspešný zápis.
- **fokus zostáva v karte.** Tab z posledného prvku cyklí na prvý (Shift+Tab
  naopak) — inak skočí do obsahu za modalom, ktorý sa práve ovládať nedá.
- **Kotva `#nxModalRoot` žije mimo tela sekcie**, takže prekreslenie obsahu
  po zápise modal nezhodí.

**Čo kostra NEPREBERÁ:** okná s **vlastným životným cyklom riadeným serverom** —
napr. fázové okno „Prepočítať ceny" (`#budPrModal`): vo fáze behu sa Escapom
zavrieť nesmie, lebo beh by ostal visieť bez okna. Také okno si markup kreslí
samo a s komponentom nemá nič spoločné.

**Escape v okne, ktoré má vlastný Escape handler** (Štúdio zatvára ním
rozbaľovacie nastavenie hrán) sa rieši **dvoma poistkami naraz**:

1. modal Escape **spotrebuje** — `stopImmediatePropagation()`. Obyčajný
   `stopPropagation` by nestačil: oba listenery visia na tom **istom** uzle
   (`document`) a ten ich nezastaví; zastaví ich až „immediate" variant. Platí
   to preto, že komponent sa načítava **pred** oknom (jeho listener je prvý).
2. okno si napriek tomu podmieni svoj handler `!NXModal.isOpen()` — pre prípad,
   že by sa poradie skriptov niekedy zmenilo.

Bez toho by jedno stlačenie Escape zavrelo **oboje** a používateľ by prišiel
o nastavenie, ktorého sa ani nedotkol.

---

## 6. Cache-busting

CEF cachuje externé CSS/JS. Konvencia od v0.5.0: `?v=` suffix = **presne verzia
pluginu** (VERSION z loadera) na VŠETKÝCH css/js odkazoch vo VŠETKÝCH ui/*.html —
stráži to guard test v `tests/pure/test_guards.rb`. Zmena css/js po vydaní teda
znamená: bump patch VERSION (noxun_engine.rb + main.rb) a prepísať všetky `?v=`
na novú hodnotu (viď pravidlo verzie v CLAUDE.md). Verzia v pätičke ide z Ruby
a s cache-bustom sa nikdy needituje ručne zvlášť.
