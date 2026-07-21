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
`check`, `chevron-right` (disclosure), `link`, `logo`.

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

---

## 6. Cache-busting

CEF cachuje externé CSS/JS. Pri každej zmene po vydaní verzie bump `?v=` na VŠETKÝCH
odkazoch v `panel.html` jednotne (napr. `0.4.7v` → `0.4.7w`). Prípona cache-bustu
sa NIKDY nepremieta do zobrazenej verzie v pätičke.
