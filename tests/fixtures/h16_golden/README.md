# H16 T0 — pôvod bajtových golden variantov

Oba manifesty charakterizujú **kód pred H16**. Test podľa malej sondy `JSON.pretty_generate` v samostatnom bežci vyberie **celý** manifest
a porovná SHA-256 pôvodných bajtov súborov. Súbory sa neparsujú, nesortujú ani nepreformátujú. Neznámy výsledok sondy test odmietne.

| Manifest | Overený samostatný interpreter | JSON gem | Výsledok sondy s prázdnym objektom a poľom |
|---|---|---|---|
| `first_use.json` (pôvodný, bezo zmeny) | Ruby 3.2.11 a 3.3.12, x64-mingw-ucrt | 2.6.3 / 2.7.2 | kontajnery na viacerých riadkoch |
| `first_use_compact.json` | Ruby 3.4.11, x64-mingw-ucrt | 2.9.1 | `{}` a `[]` na jednom riadku |

Príčina P1 v PR #461: od JSON 2.8 `pretty_generate` vynecháva riadky vo vnútri prázdnych objektov a polí
([zmena upstream](https://github.com/ruby/json/blob/master/CHANGES.md#2024-11-06-280)). Presný úzky H16 príkaz s JSON 2.9.1 pred opravou dal **26 PASS / 1 FAIL**,
rovnako na nezmenenom kóde pred H16. Líšili sa presne SHA `abs_rules.json`, `materials.json`, `templates.json`; CI s Ruby 3.2 / JSON 2.6.3 bol zelený.
Verzia gemu sama variant nevyberá — rozhoduje presný text sondy z procesu, ktorý súbory naozaj zapísal.

## Zdroj a reprodukcia

- Produkčný baseline: **`fe7f5405323eed86fedac8decaa733f2b792ad1d`** (main pred H16).
- Prvý T0 commit: **`c9c4c5123ae9d202198912a834022cc6b14d0033`**. Pridáva len testy, bežec a generátor; jeho plugin aj `tests/helper.rb`
  sú bajtovo totožné s baseline. `git diff fe7f5405 c9c4c512 -- noxun_engine.rb noxun_engine tests/helper.rb` je prázdny.
- Identita Git objektov na oboch commitoch: strom `noxun_engine/` **`295d758db9ac72fc969b01cb0e0182d66382ac7c`**,
  loader **`049c25025a261fdbcbb3570e6ce71f8837dc6e3d`**, helper **`f5e4143f4d615f0e25e9dd3d6d0143c0067dcc4e`**.
- Nový compact manifest vznikol **dvoma behmi pôvodného generátora z T0 commitu** pod Ruby 3.4.11 / JSON 2.9.1,
  v čerstvom `git archive c9c4c512` pod `_dev/`. Generátor z nového kódu H16 ho nevytvoril.

Overenie bez živých katalógov: vytvor izolovaný `git archive c9c4c512` do `_dev/`, v ňom spusti zvoleným samostatným interpreterom
`tests/fixtures/h16_golden/generate.rb`. Helper presmeruje APPDATA do čerstvého sandboxu. Výsledok porovnaj s príslušným manifestom;
generátor nikdy nespúšťaj na novom kóde len kvôli zelenému testu. Presný úzky príkaz:

```text
ruby -e 'require_relative "tests/helper"; require_relative "tests/pure/test_h16_kniznice"; exit(NxTest.run! ? 0 : 1)'
```

Pri oprave boli pre oba formáty všetky **16 deterministických súborov** porovnané bajtovo medzi baseline a H16: zhodné.
Medzi formátmi sa menia len tri SHA; množina **27 súborov**, zámky a ostatných **13 SHA** sú totožné. Porovnanie oboch baseline JSON stromov
zachovalo poradie kľúčov, druhy kontajnerov, skalárne typy aj zápis čísel — rozdiel je výlučne formát prázdnych kontajnerov.

Regresný test odmieta neznámy profil, celý opačný variant, SHA z opačného variantu primiešaný do jedného súboru aj poškodený SHA každého
zo 16 súborov. Poradie kľúčov, čísla, hodnoty a ďalšie formátovanie sú stále súčasťou bajtového kontraktu.

## Vedomé zmeny obsahu prvého behu

Manifest sa mení len pri **vedomej zmene seedu alebo nového súboru**, zdôvodnenej v PR — vždy len dotknuté SHA, nič iné.

| Dávka | Súbor | Prečo | Ako overené |
|---|---|---|---|
| ŠÍRKA 50 (v0.17.28, `feat/sirka-50mm`) | `hardware_rules.json` | seed pravidiel kovania 7 → 8 (pásmo nôh úzkej skrinky `max 199,999 → 2`) | `diff` prvého behu pred/po: len `seed_version` a nové pásmo; SHA v oboch formátoch rovnaký (súbor nemá prázdne kontajnery) |
| ŠÍRKA 50 | `templates.json` | `CONFIG_SCHEMA` 22 → 23 (vstavané šablóny nesú marker) | `diff`: len trikrát `config_schema`; kompaktný SHA odvodený nahradením prázdnych kontajnerov (`[\n\n  ]` → `[]`, `{\n  }` → `{}`) — tá istá transformácia nad behom pôvodného `main` dala presne pôvodné kompaktné SHA `abs_rules.json`, `materials.json` aj `templates.json` |
