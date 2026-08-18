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
| `--nx-modal-shadow` | `rgba(0,0,0,.25)` | tieň modalu / overlay |

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
`palette` (UI-B3 — sekcia Vzhľad v koliesku).

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
  rámik + krížik) → **funkčná sekcia** (ABS kontrola hrán) → dole **koliesko**
  (Nastavenia Inspectora) a **Štúdio**. Aktívny kontext je teal, funkčné ikony sú
  tlmené a rozsvietia sa až po zapnutí. Rail je úzky, preto názov nesie **bublina
  pri hoveri** (`.railtip`) — nie natívny `title`, aby sa nezobrazovali dva
  tooltipy naraz.
- **Kontexty platia LEN nad označeným korpusom.** Pri dielci, doske aj vkladaní
  sú **neaktívne** — sivé, s bublinou, ktorá povie prečo. Ochranu drží **guard
  v JS** (`setViewContext`), nie CSS; `aria-disabled` namiesto HTML `disabled`,
  aby tlačidlá ostali fokusovateľné (vzor D-78).
- **Sektory:** `S1 Náhľad · S2 Základné · S3 Materiály · S4 Nastavenia`. Sú to
  `<details>` — zbalenie si pamätá `localStorage`, takže **prežije prekreslenie
  aj zatvorenie panela**. Lišta sektora je tmavšia než telo a má miesto na
  **meta súhrn** vpravo (dopĺňa ho UI-B3).
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
| **Kovanie** | korpus s **pozíciami kovania**: záves = krúžok s krížikom na závesovej hrane · výsuv = dvojica koľajníc vo výške zásuvky · nohy = obdĺžniky dole; pod projekciou súhrn všetkých položiek |
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

### 5.4 Ostatné vzory

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
- **Warn chip / warnlist:** klik na chip ukotvený zoznam upozornení hore (pri
  rozbalení návrat na začiatok, aby bol viditeľný aj po odscrollovaní).
- **Veľkosť okna pri otvorení (D-77):** žiadne okno sa nesmie otvoriť odseknuté.
  `width`/`height` v `HtmlDialog.new` platia len pri PRVOM otvorení (potom
  rozhoduje veľkosť zapamätaná pod `preferences_key`), preto každé okno deklaruje
  v HTML svoje **obsahové minimum** `window.NX_FIT_MIN = { w, h }` a načíta
  `js/win_fit.js` — to okno pri otvorení dorovná. Dorovnáva sa **oboma smermi**:
  nahor po deklarované minimum, nadol po dostupnú plochu obrazovky (okno
  zapamätané z väčšieho monitora je inak orezané rovnako). **Plocha má prednosť
  pred minimom**; medzi minimom a plochou sa veľkosti okna nikto nedotkne, takže
  vedome zväčšené okno ostáva. Nové okno = nové `NX_FIT_MIN` (bez neho fit nebeží).

### D-51: štandard rozmerov okien (UI-B1)

**Jedna pravda je OBSAHOVÝ viewport** (`NX_FIT_MIN` v HTML). Rozmery
v `HtmlDialog.new` sú **vonkajšie** — obsah + rámik okna (Windows ≈ 16 px šírka,
≈ 40 px výška). Preto sa vždy zapisuje trojica **`NX_FIT_MIN` → `width`/`height`
→ `min_width`/`min_height`** a musí si zodpovedať (stráži guard test
`tests/pure/test_uib1_kostra.rb`).

| Okno | Obsah (`NX_FIT_MIN`) | `width` × `height` | `min_width` × `min_height` |
|---|---|---|---|
| **Inspector** (`panel.html`) | 470 × 810 | 486 × 850 | 486 × 600 |
| Výroba (`production.html`) | podľa deklarácie v HTML | — | — |
| Materiály (`proj_materials.html`) | podľa deklarácie v HTML | 720 × 640 | — |
| ostatné satelity | podľa deklarácie v HTML | — | — |

> **470 px Inspectora** je obsah = rail 44 px + karta. Hodnota je záväzná pre
> celý blok UI 2.0 — mockup, sektory aj šírky polí sa navrhujú na ňu.
> Satelitné okná dostanú svoje riadky tabuľky, keď ich prevezme Štúdio.

---

## 6. Cache-busting

CEF cachuje externé CSS/JS. Konvencia od v0.5.0: `?v=` suffix = **presne verzia
pluginu** (VERSION z loadera) na VŠETKÝCH css/js odkazoch vo VŠETKÝCH ui/*.html —
stráži to guard test v `tests/pure/test_guards.rb`. Zmena css/js po vydaní teda
znamená: bump patch VERSION (noxun_engine.rb + main.rb) a prepísať všetky `?v=`
na novú hodnotu (viď pravidlo verzie v CLAUDE.md). Verzia v pätičke ide z Ruby
a s cache-bustom sa nikdy needituje ručne zvlášť.
