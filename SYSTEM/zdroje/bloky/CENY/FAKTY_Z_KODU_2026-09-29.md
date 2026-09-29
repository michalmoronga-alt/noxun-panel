# Blok CENY — fakty z kódu a z reálnych dát (29.9.2026, v0.16.0)

> Zber: read-only Explore subagent nad `main` 2a1ff94c + počty z Michalovho lokálneho katalógu (len čísla a názvy kľúčov, obsah sa nekopíroval).
> Riadky kódu sú orientačné — package dávky ich pred auditom overí sondou (skill `codex-audit`, krok 0).

## 1 · Vzor: katalógové kovanie (CENY-KOV, PR #345/#346)

- Jadro `core/hardware_catalog.rb`: schéma rastie **podľa obsahu** (`product_url` → 3, `price_check_method` → 4) a pri zápise sa prepočíta — môže aj klesnúť.
  Starší plugin s vyššou schémou = katalóg len na čítanie (`assess!`).
- `product_url` (http/https, bez medzier a úvodzoviek) je editovateľné pole; `price_checked_at` + `price_check_method: 'manual'` zapisuje **len server**.
  Prednosť odkazu: `demos_url`, inak `product_url`. Klient dostáva len príznak „odkaz existuje", URL otvára server (`UI.openURL`).
- Ručné potvrdenie `confirm_manual_price!`: pod zámkom, čerstvá revízia riadku, bez Demos väzby, cena ≥ 0 (prázdna nie) → cena + serverový dátum + `manual`.
  Zmena ceny, MJ, odkazu alebo dodávateľa ručné overenie zneplatní; potvrdenie z Demosu ručný pôvod nahradí.
- UI: ikona „Otvoriť produkt" (chýbajúci odkaz = jantárová, klik otvorí úpravu s fokusom na odkaze) a akcia „Overiť cenu ručne" (formulár NXModal,
  „Potvrdiť cenu k dnešku", cena s DPH za MJ, predchádzajúce overenie) — v katalógu kovania **aj v Rozpočte**.
- Testy: `tests/pure/test_ceny_kov_*.rb`, `tests/js/test_ceny_kov_*.js`.

## 2 · Materiály (dosky) a ABS dnes

- Jeden globálny katalóg `%APPDATA%\NOXUN\Engine\materials.json` (`sheets` + `edges`), schéma **10**; schéma rastie podľa obsahu, ale **nikdy neklesá**
  (na rozdiel od kovania) — po prvom zápise novej schémy prejde starší plugin celý katalóg materiálov do režimu len na čítanie.
- Cena: doska `price_per_m2` (€ s DPH za m²), ABS `price_per_bm` (€ s DPH za bm); MJ je daná druhom záznamu (pole `unit` neexistuje).
  `demos_url` + `price_checked_at` zapisuje **len Demos cesta** (vyžaduje cenu > 0). `demos_url` prijme len `https` na `demos-trade.sk`.
- **Odkaz na produkt pre materiál/ABS bez Demosu neexistuje**, ručné overenie tiež nie. `product_url` ani `price_check_method` v materiáloch nie sú.
- Štúdio → Materiály: ikona prekliku a dátum overenia (len v tooltipe) **iba pri Demos väzbe**; vek ceny ani upozornenie sa tu neukazujú.
- Rozpočet → Materiál / ABS hrany: stĺpec „Overená" (N dní, jantárovo pri starej cene); **položka bez Demos väzby má napevno stav `manual`, dátum sa ignoruje**,
  čip „N cien starších ako X dní" ju nepočíta a v zozname má len text „bez Demos väzby — over v katalógu ručne" — **prakticky neviditeľná**.
  Tlačidlá overenia a ikona produktu v Rozpočte existujú **len pre kovanie**. Prah veku `stale_days` (predvolene 30) v nastaveniach dodávateľa.
- Rozpočet číta ceny **živo z katalógu**; zákazka nenesie cenu, dátum ani odkaz materiálu (snapshot dielca = len `material_id`). Odkaz nie je výrobný údaj.
- Katalóg spotrebičov už má **zoznam odkazov** (`shop_urls`, strop 20) — precedens zoznamu; kovanie má **jeden** odkaz.

## 3 · Reálne dáta (Michalov katalóg, 29.9.2026)

| | Dosky | ABS |
|---|---|---|
| záznamy spolu | 50 (6 UNI, 9 duplákov) | 41 |
| nákupné záznamy | 35 | 41 |
| s Demos väzbou (všetky s cenou a dátumom) | 31 | 40 |
| — cena staršia ako 30 dní | 23 | 30 |
| **bez Demos väzby** | **4** (2× DTDL, zástena, sklo) | **1** (0,8 mm) |
| — bez ceny | 2 | 1 |

**Záver:** zo 76 nákupných záznamov je bez Demos väzby len **5** (3 bez ceny). Všetkých 53 starých cien je viazaných na Demos — tie rieši „Prepočítať ceny",
nie ručné overenie. Ručné overenie teda pokryje malú, ale typovo špecifickú skupinu (sklo, zástena, dosky mimo Demos).
Katalóg kovania pre porovnanie: 147 položiek, 133 s Demos, 9 s odkazom, 3 ručne overené.

## 4 · Pasce pre packages (technické — riešia packages s auditom)

1. Schéma materiálov neklesá → obe PC musia byť na rovnakej verzii skôr, než sa prvý raz zapíše odkaz alebo ručné overenie.
2. Nové polia musia prejsť všetkými whitelistami (normalizácia dosky a ABS, `save_decor`, odvodenie dupláku — duplák nesmie zdediť odkaz ani pečiatku, UNI bez nákupných polí).
3. Zneplatnenie ručného overenia je rozptýlené na ~6 miestach (úprava riadku, formulár variantu, `save_decor`, Demos väzba vrátane automatického napárovania cez sitemap).
4. Ručný formulár a MJ: obchody uvádzajú cenu často za platňu alebo za rolku; plugin drží €/m² a €/bm (prepočet cez formát platne je možný).
5. Rozpočet má stav `manual` pre materiály zamknutý testami (`test_ceny_kov_budget_manual.rb`, `test_budget.rb`) — zmena musí byť vedomá.
6. Kanál kovania sa nedá použiť priamo (identita `code` vs. `kind + id` v okne Materiálov, iné strážcovia revízií).
