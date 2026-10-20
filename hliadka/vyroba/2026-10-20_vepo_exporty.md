# Hliadka výroby 2026-10-20 · VEPO a exporty

- Oblasť: Ut — VEPO a exporty
- Prečítané: SYSTEM/VEPO_KONTRAKT.md, docs/architecture/outputs.md (odsek vepo_export), core/vepo_export.rb (celý), core/cp_export.rb (celý), core/xlsx_writer.rb (celý), ui/export_prep.rb (celý), ui/production_core.rb (do_export, do_hw_csv, do_budget_xlsx, do_cp_xlsx), core/hardware_sets.rb (purchase_csv, súčty), core/bom.rb (aggregate_rows, row_key), core/budget.rb (grep)
- `ruby tests/run_all.rb` (s LANG=C.UTF-8): 5419 passed, 0 failed, 7 skipped. Bez UTF-8 locale padá helper.rb:33 (len prostredie cloudu, nie chyba kódu).

## Nálezy
Žiadne (0).

## Podozrenia (bez dôkazu, nepočítajú sa)
1. `vepo_export.rb:214` `rounded_dims` + `validate_row:380-381` — kladný rozmer pod 0,5 mm prejde validáciou (`to_f <= 0`), ale do CSV ide `0`. Kontrakt hovorí „riadok s nekladným rozmerom ide von z CSV"; outputs.md správanie (0,1 → 0) priznáva. Reálny dielec takto malý nie je, preto len podozrenie.
2. `cp_export.rb:302-308` `int_qty` — zlomkové množstvo kovania (ak by sa objavilo v MJ `bm`) sa v ponuke zaokrúhli na celé, cena riadku ostáva za skutočné množstvo. Nenašiel som cestu, ktorou by sa zlomok do riadka kovania dostal (kovanie má celé `quantity`), takže bez dôkazu.

## Skontrolované bez nálezu
- Rozmery VEPO: hotové rozmery bez odpočtu ABS, zaokrúhlenie `round` (polovica od nuly: 562,5 → 563), rotácia dekoru (`grain width`) vymieňa dĺžku↔šírku aj dvojice hrán (sonda: L1 → W1/W2 správne, kódy `—`/`=`).
- Obchodná hrúbka: 18.0–19.1 → 18, 36.0–38.1 → 36, 17.5 → 18, 19.11 → 19, 38.2 → 38 — podľa kontraktu.
- Názov riadku: skratky, párovanie (Bok LP, Dv1 LP), zlučovanie číslovaných tokenov (`Polica 1 2 3 s1 s2`), orez na 20 znakov po hranici tokenu, nepárovanie voľných názvov dosiek.
- CSV: `;`, force_quotes, CRLF, UTF-8 bez BOM, 9 stĺpcov v poradí podľa kontraktu; dedup názvov súborov; atomický zápis dávky.
- Poznámka pre VEPO (`abs_note`, `same_decor?`): rozhoduje `group_id`, fallback na dekor, normalizácia.
- Kusovník → VEPO: `row_key` obsahuje rozmery, hrúbku, materiál, hrany a vlákno (nemiešajú sa dielce rôznej hrany/vlákna); quantity sa sčítava raz.
- CSV kovania (`purchase_csv`): celé `quantity`, cena prázdna (nie 0) pri neznámej cene, medzisúčet `round(2)`, súčet len známych cien.
- CP (cenová ponuka): suma CP == suma rozpočtu konštrukciou (zostava = zvyšok), nezapočítané spotrebiče sa nedostanú do riadkov ani špecifikácie (`counts_in_total`/`included` konzistentné v budget.rb), firewall interných pojmov.
- XLSX writer: čísla ako hodnoty (nie vzorce), escapovanie XML, unikátne názvy hárkov ≤ 31 znakov, ZIP CRC.
- Brány exportov (`ExportPrep.start`, potvrdenie cien, kit zásuviek, duplicity) idú pred výberom súboru.
