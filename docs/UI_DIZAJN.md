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
- **Farba nesie význam.** Zelená = primárna akcia, modrá = výber/aktívny stav,
  červená = chyba/mazanie, jantár = upozornenie/override. Významy sa nemiešajú.
- **Žiadna vizuálna zmena bez zámeru.** Tokeny sú 1:1 mapované na doterajšie hex —
  refaktor na premenné nemení vzhľad.

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
| `--nx-part-bg` | `#f5fbff` | karta dielca (bledomodrá) |

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

### Akcia (zelená) vs výber (modrá) — významovo rôzne
| Token | Hex | Použitie |
|---|---|---|
| `--nx-action` | `#2e7d32` | pozadie primárneho tlačidla |
| `--nx-action-hover` | `#1b5e20` | hover primárneho tlačidla |
| `--nx-on-accent` | `#ffffff` | text na akcii/výbere |
| `--nx-select` | `#1565c0` | aktívny tab, ID, výber |
| `--nx-select-strong` | `#01579b` | zvýraznenie čela (hover) |
| `--nx-select-accent` | `#0277bd` | akcent riadku čela |
| `--nx-select-bg` | `#e3f2fd` | pozadie výberu (zóna, riadok) |
| `--nx-select-bg-soft` | `#f1f8ff` | hover zóny |
| `--nx-select-bg-hover` | `#e1f5fe` | hover riadku čela |
| `--nx-part-border` | `#90caf9` | rámik karty dielca |

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
`wrench` (Kovanie — satelitná akcia v hlavičke panela, D-91), `logo`.

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

### D-47 / D-91: hlavička panela (rad 2)
Tri režimové taby (Korpus·Zóny·Čelá) sú **rovnako široké** (`flex: 1 1 0`)
s ikonou + textom; satelitné akcie **Materiály · Výroba · Kovanie** sú rovnako
široké (inline-grid `repeat(3, 1fr)`) a pri šírke panela pod ~480 px sa prepnú
na **icon-only** (media query skryje `.prodbtn span`; `title`/`aria-label`
ostávajú) — žiadny tretí riadok, vertikálny priestor panela sa nemení.
Breakpoint je **vlastný** (nie spoločný s 400 px pravidlom pre `.hwext`):
s treťou akciou musia texty ustúpiť skôr, inak by taby ostali bez miesta.

> **D-91 (Michal 9.8.):** umiestnenie „za Výrobou" je **dočasné** — finálny
> domov satelitných okien (toolbar: hlavná · materiály · výroba · kovanie)
> rozhodne debata UI 2.0.

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
zjavný — modré pozadie `--nx-select` + ikona `eye-off`), **pravá** (užšia,
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

### Pravidlo: žiadne emoji v UI chrome
Emoji/unicode glyfy (🔒 ✕ ↺ ⚙ 📋 ★ ⧉ ⛶ ⚠ 🔗 …) sa v ovládacích prvkoch panela
nepoužívajú — nahrádza ich ikona zo spritu. Kde SVG nejde (napr. `<option>`,
alebo status v `textContent` ceste do Ruby), použije sa **čistý text**, nie glyf.

---

## 5. Komponentové vzory

- **Sticky hlavička (Inspector):** dvojradová, zostáva pri scrollovaní
  (`position: sticky`, `z-index` pod modalom 60). Rad 1 = logo + identita objektu
  + warn chip. Rad 2 = režimové taby (Korpus·Zóny·Čelá) + tlačidlo Výroba
  (vizuálne oddelené, otvára satelit). `scroll-padding-top` = výška hlavičky, aby
  fokusované pole neskončilo pod ňou.
- **Pätička:** v normálnom toku na konci obsahu — `Noxun Engine V<verzia>`.
  Verzia príde z Ruby (`Engine::VERSION`), nikdy sa nedopĺňa prípona cache-bustu.
- **Tlačidlá:** `.primary` (akcia, zelená), `.ghostbtn` (neutrál), `.danger`
  (mazanie, červená). Ikonové akcie sú kompaktné, s `aria-label`.
- **Náhľad:** fixné okno so zoom/pan; **fit/reset (⛶ → ikona `maximize`)** je
  overlay v pravom hornom rohu (`pointer-events` len na tlačidle, nesmie blokovať
  pan/zoom/ťah priečky).
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
  *Jednotný štandard šírok a rozmerov okien je úloha D-51 (UI 2.0).*

---

## 6. Cache-busting

CEF cachuje externé CSS/JS. Konvencia od v0.5.0: `?v=` suffix = **presne verzia
pluginu** (VERSION z loadera) na VŠETKÝCH css/js odkazoch vo VŠETKÝCH ui/*.html —
stráži to guard test v `tests/pure/test_guards.rb`. Zmena css/js po vydaní teda
znamená: bump patch VERSION (noxun_engine.rb + main.rb) a prepísať všetky `?v=`
na novú hodnotu (viď pravidlo verzie v CLAUDE.md). Verzia v pätičke ide z Ruby
a s cache-bustom sa nikdy needituje ručne zvlášť.
