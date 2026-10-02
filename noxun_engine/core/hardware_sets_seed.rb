# frozen_string_literal: true
# Noxun Engine — H15a: SEED DATA setov kovania (LEN data, ziadna logika).
#
# CO TU ZIJE: `SEED_VERSION` (+ historia v2..v8), `SEED_SETS`, `SEED_MAPPING`,
# `LEGACY_SEED_SHAPES`, `MAPPING_MIGRATIONS`, `MAPPING_ADDITIONS`. Mechaniku
# (seed-merge, migracie, zamky, brany, expanzia, nakup) ma `hardware_sets.rb`
# a odvodeniny (`CLASS_MAPPING_KEYS`) ostavaju tam.
#
# PRAVIDLA (guard `tests/pure/test_h15_seed_data.rb`):
#   * subor obsahuje LEN deklaracie konstant s literalmi (retazec, cislo,
#     nil/true/false, pole, hash, `%w[]`), `.freeze` a odkaz na konstantu
#     deklarovanu VYSSIE v tomto subore — ziadne `def`, volania ani odkazy
#     na konstanty logiky;
#   * nacitava sa PRED `hardware_sets.rb` (`main.rb` a `tests/helper.rb`),
#     preto bunka „vedome bez kodu" je literal 'none' (= `HardwareSets::SKIP_CODE`);
#   * ZMENA SEEDU = zmena tu + `SEED_VERSION` + stary tvar zmeneneho setu do
#     `LEGACY_SEED_SHAPES` (v tom istom subore) + VEDOMA regeneracia goldenu
#     `tests/fixtures/h15_golden/generate.rb` zdovodnena v PR. Bez bumpu sa
#     zmena do existujucich instalacii nedostane (STANDARD §13.1).
module Noxun
  module Engine
    module HardwareSets
      # v2 (H1a): +set „Nohy podla vysky sokla" (param_bands) a migracia
      # globalneho defaultu leg z 'nohy-klzak-17' na neho.
      # v3 (KOV-C2a): +8 klasifikovanych drawer setov (Atira 3 vysky x 2 otvarania,
      # Quadro V6 x 2 otvarania) a triedne mapovania cez `MAPPING_ADDITIONS`.
      # v4 (KOV-D1c): +6 setov Atira ANTRACIT (3 vysky x 2 otvarania). LEN sety —
      # `MAPPING_ADDITIONS` sa NEMENI, predvolba ostava biela; antracit si
      # pouzivatel vybera vedome v Pravidlach Studia alebo na karte cela.
      # v5 (D-118b): oprava kodu 348777 -> 357889 (antracit H70/470 NIE JE
      # K-sada) + PTOs modul ako DRUHY clen siestich Tip-On setov + premenovanie
      # legacy setu na „Výsuv (staré zákazky)". Prvy seed, ktory MENI obsah uz
      # existujucich setov — preto k nemu patri `LEGACY_SEED_SHAPES` a krok
      # „nahrad NEDOTKNUTY seed tvar" v `merge_seed`.
      # v6 (KOV-F1): zavesove sety dostali UPLNU klasifikaciu (`use_type door`,
      # `opening_mode classic|tipon`, Hettich Sensys) + triedne mapovania
      # `class:hinge|classic` / `class:hinge|tipon` v `MAPPING_ADDITIONS`.
      # v7 (KOV-E1a): +6 setov vyklopov AVENTOS (HK klasik / HK Tip-On / HL
      # klasik, kazdy v bielej a tmavej) + triedne mapovania
      # `class:lift|classic|hk_top` · `class:lift|tipon|hk_top` ·
      # `class:lift|classic|hl_top` v `MAPPING_ADDITIONS`. Tmave sety triedny
      # kluc NEMAJU — vyberaju sa per celo (E2).
      # v8 (KOV-G1a): NOHY 17-220 mm. Set `nohy-podla-sokla` dostal NOVY TVAR
      # (sedem pasiem nohy + druhy clen „platnička" s pasmom `none` pod 55 mm)
      # a pribudol set `prichyt-sokla-axilo` (`plinth_clip`) s mapovanim.
      # Druhy seed, ktory MENI obsah existujuceho setu — preto je stary tvar
      # v `LEGACY_SEED_SHAPES` a plati „nedotknuty nahradim, upraveny nechavam".
      SEED_VERSION = 8

      # Seed sety = zavery debaty 2.8.2026 (POJMY "Kovanie — sety");
      # kody = SYSTEM/zdroje/SEED_KATALOG_2026-07.md §2. Atira rad nesie LEN
      # dolozene kody (420/470) — ostatne NL = ORANGE, kody doplni Michal/D2.
      SEED_SETS = [
        # KOV-F1: zavesove sety su KLASIFIKOVANE (`use_type: 'door'` +
        # `opening_mode`) — set sa vybera podla SPOSOBU OTVARANIA cela, takze
        # bez klasifikacie by triedny kluc nemal na co ukazat.
        { 'set_id' => 'zaves-klasik', 'name' => 'Záves KLASIK (Sensys 110° SiSy)',
          'generic_type' => 'hinge', 'use_type' => 'door', 'opening_mode' => 'classic',
          'manufacturer' => 'Hettich', 'series' => 'Sensys',
          'members' => [
            { 'code' => '104717', 'per' => 'unit', 'qty' => 1, 'label' => 'záves' },
            { 'code' => '106412', 'per' => 'unit', 'qty' => 1, 'label' => 'platnička' },
            { 'code' => '105408', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka misky' },
            { 'code' => '105425', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka ramienka' }
          ] },
        { 'set_id' => 'zaves-p2o', 'name' => 'Záves P2O + TipOn (bez tlmenia)',
          'generic_type' => 'hinge', 'use_type' => 'door', 'opening_mode' => 'tipon',
          'manufacturer' => 'Hettich', 'series' => 'Sensys',
          'members' => [
            { 'code' => '245723', 'per' => 'unit', 'qty' => 1, 'label' => 'záves P2O' },
            { 'code' => '106412', 'per' => 'unit', 'qty' => 1, 'label' => 'platnička' },
            { 'code' => '105408', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka misky' },
            { 'code' => '105425', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka ramienka' },
            { 'code' => '250831', 'per' => 'owner', 'qty' => 1, 'label' => 'TipOn na dvierka' }
          ] },
        # H1a (smoke test D-79): noha sa vybera podla VYSKY SOKLA — polozka
        # 'leg' nesie params['height'] = floor_height (pravidlo nohy-zakladne).
        # Skrinka so soklom 150 uz nedostane klzak 17. Vyska mimo pasiem =
        # ORANGE „doplnit pasmo", NIKDY najblizsie pasmo.
        #
        # KOV-G1a (rozhodnutia Michal 9.9.2026): set pokryva KAZDU vysku sokla
        # od 17 do 220 mm okrem VEDOME nepokrytej zony 20-55 mm (tam nic
        # rozumne neexistuje -> ORANGE „doplň pásmo"). Dve pasma su dnes dva
        # svety: 17-20 = STRONG klzak s rektifikaciou (272212, Demos),
        # 55-220 = HAFELE AXILO (Quatro LM) — noha podla vysky + PLATNICKA
        # na kazdu nohu. Pasma su CELOCISELNE rozsahy (min/max VRATANE);
        # neceloselna vyska medzi pasmami (90,5) je VEDOME ORANGE — vysky
        # sokla su v praxi z rozmeroveho radu a hadanie susedneho pasma by
        # objednalo inu nohu.
        { 'set_id' => 'nohy-podla-sokla', 'name' => 'Nohy podľa výšky sokla',
          'generic_type' => 'leg',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'noha',
              'param_bands' => { 'param' => 'height',
                                 'bands' => [
                                   { 'min' => 17.0, 'max' => 20.0, 'code' => '272212' },
                                   { 'min' => 55.0, 'max' => 90.0, 'code' => '9069' },
                                   { 'min' => 91.0, 'max' => 115.0, 'code' => '9078' },
                                   { 'min' => 116.0, 'max' => 140.0, 'code' => '9077' },
                                   { 'min' => 141.0, 'max' => 170.0, 'code' => '9076' },
                                   { 'min' => 171.0, 'max' => 190.0, 'code' => '9027' },
                                   { 'min' => 191.0, 'max' => 220.0, 'code' => '9075' }
                                 ] } },
            # Platnicka je SUCASTOU nohy AXILO (skrutkuje sa do dna), takze ide
            # na KAZDU nohu. Klzak 17-20 mm ziadnu nema — pasmo je preto
            # VYPLNENE sentinelom `none` („tu ziadny kod nepatri"), nie
            # vynechane: chybajuce pasmo by hlasilo ORANGE tam, kde je vsetko
            # v poriadku (ta ista uvaha ako PTOs modul pri NL 620, D-118b).
            { 'per' => 'unit', 'qty' => 1, 'label' => 'platnička',
              'param_bands' => { 'param' => 'height',
                                 'bands' => [
                                   { 'min' => 17.0, 'max' => 20.0, 'code' => 'none' }, # = HardwareSets::SKIP_CODE
                                   { 'min' => 55.0, 'max' => 220.0, 'code' => '9079' }
                                 ] } }
          ] },
        # KOV-G1a: PRICHYT SOKLOVEJ LISTY (Häfele 637.38.054). Vznika LEN pri
        # samostatnej soklovej liste (skrinka na nohach) a je 1 ks na zacate
        # 4 nohy — POCET riesi pravidlo v KOV-G1b, tu je len set a mapovanie.
        # Bez pravidla ziadna polozka `plinth_clip` nevznikne, takze set je
        # zatial „pripraveny" (rovnako ako sety vyklopov pred KOV-E1b).
        { 'set_id' => 'prichyt-sokla-axilo', 'name' => 'Príchyt sokla AXILO',
          'generic_type' => 'plinth_clip',
          'use_type' => 'other', 'opening_mode' => 'other',
          'manufacturer' => 'Häfele', 'series' => 'AXILO',
          'members' => [
            { 'code' => '950', 'per' => 'unit', 'qty' => 1, 'label' => 'príchyt sokla' }
          ] },
        # Jednokodove sety nôh OSTAVAJU — pouzivatelia ich mozu mat namapovane
        # (a migracia defaultu nizsie ich vedome respektuje).
        { 'set_id' => 'nohy-klzak-17', 'name' => 'Klzák s rektifikáciou 17 mm',
          'generic_type' => 'leg',
          'members' => [{ 'code' => '82744', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'nohy-axilo-150', 'name' => 'Noha AXILO 150 mm',
          'generic_type' => 'leg',
          'members' => [{ 'code' => '367823', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'vysuv-atira-biela-h70', 'name' => 'Výsuv (staré zákazky)',
          'generic_type' => 'slide',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '420' => '357695', '470' => '357696' } }
          ] },
        # === KOV-C2a: KLASIFIKOVANE SETY ZASUVIEK (recepty v1) ================
        # Kody = draft #13 §1 (Atira SiSy + Tip-On) a §2 (Quadro V6). KAZDA
        # bunka radu prislusneho receptu ma kod — completeness test to strazi
        # a prazdne miesto sa riesi DATOVO (kod alebo NL mimo radu), NIKDY
        # behovym fallbackom na susednu dlzku.
        # Legacy `vysuv-atira-biela-h70` OSTAVA NEDOTKNUTY (drzi legacy
        # mapovanie `slide`) — nove sety maju VLASTNE ID.
        { 'set_id' => 'atira-biela-h70-sisy', 'name' => 'Atira biela H70 — klasické',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'classic',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 70,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '357694', '420' => '357695',
                                '470' => '357696', '520' => '357697' } }
          ] },
        { 'set_id' => 'atira-biela-h144-sisy', 'name' => 'Atira biela H144 — klasické',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'classic',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 144,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              # SiSy H144 konci na NL 470: kit „144 620/50 relingy" (357755) je
              # PTO, teda TIP-ON — pre SiSy H144/620 kit NEEXISTUJE (sonda #12).
              'code_by_nl' => { '350' => '357734', '420' => '357735',
                                '470' => '357736' } }
          ] },
        { 'set_id' => 'atira-biela-h176-sisy', 'name' => 'Atira biela H176 — klasické',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'classic',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 176,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '357773', '420' => '357774', '470' => '357775',
                                '520' => '357777', '620' => '357783' } }
          ] },
        { 'set_id' => 'atira-biela-h70-p2o', 'name' => 'Atira biela H70 — Tip-On',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'tipon',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 70,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '357722', '420' => '357723', '470' => '357724',
                                '520' => '357725', '620' => '357716' } },
            { 'per' => 'unit', 'qty' => 1, 'label' => 'PTOs mechanizmus',
              'code_by_nl' => { '350' => '352908', '420' => '352908', '470' => '352908',
                                '520' => '352908', '620' => 'none' } }
          ] },
        { 'set_id' => 'atira-biela-h144-p2o', 'name' => 'Atira biela H144 — Tip-On',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'tipon',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 144,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '357761', '420' => '357762', '470' => '357763',
                                '520' => '357764', '620' => '357755' } },
            { 'per' => 'unit', 'qty' => 1, 'label' => 'PTOs mechanizmus',
              'code_by_nl' => { '350' => '352908', '420' => '352908', '470' => '352908',
                                '520' => '352908', '620' => 'none' } }
          ] },
        { 'set_id' => 'atira-biela-h176-p2o', 'name' => 'Atira biela H176 — Tip-On',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'tipon',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 176,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '357801', '420' => '357802', '470' => '357803',
                                '520' => '357812', '620' => '357795' } },
            { 'per' => 'unit', 'qty' => 1, 'label' => 'PTOs mechanizmus',
              'code_by_nl' => { '350' => '352908', '420' => '352908', '470' => '352908',
                                '520' => '352909', '620' => 'none' } }
          ] },
        # === KOV-D1c: ATIRA ANTRACIT (alternativna rodina, NIE predvolba) =====
        # Kody = draft #13 §1 tabulka „Antracit kity Atira" (Demos 6.9.2026).
        # Klasifikacia je ZHODNA s bielou rodinou (farbu ani vyhotovenie
        # klasifikacia nenesie) — rodiny odlisi VYHRADNE nazov: `family_stem`
        # zahodi token `H<cislo>`, takze „Atira antracit — klasické" je iny kmen
        # nez „Atira biela — klasické" a selektor Studia ponukne dve rodiny.
        #
        # RODINA NIE JE UPLNA (na rozdiel od bielej): antracit ma kod LEN pre
        # bunky, ktore Demos naozaj predava. Chybajuca bunka = kluc v `code_by_nl`
        # NEPRITOMNY — expanzia da RED `drawer_kit_missing` („nákup nenašiel kit
        # výsuvu k postaveným dielcom"). NIKDY sa sem nepise prazdny retazec ani
        # kod susednej dlzky/farby: ticha zamena by objednala biely kit k
        # antracitovej zakazke. Completeness test (`test_kovc2a_kanal_sety`) preto
        # plati LEN pre predvolenu bielu rodinu.
        # NL 260/300 z tabulky sa NEZAPISUJU — su mimo radov receptov v1.
        { 'set_id' => 'atira-antracit-h70-sisy', 'name' => 'Atira antracit H70 — klasické',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'classic',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 70,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              # 350 = 357887 (Michal overil 6.9. v Demose), 470 = 348777 (kod
              # mimo cislenej rady antracitu — je to tak v katalogu).
              'code_by_nl' => { '350' => '357887', '420' => '357888',
                                '470' => '357889', '520' => '357890' } }
          ] },
        { 'set_id' => 'atira-antracit-h144-sisy', 'name' => 'Atira antracit H144 — klasické',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'classic',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 144,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              # Rad SiSy H144 konci na 470 (rovnako ako biela) — 357929 z tabulky
              # je NL 520, ktora v recepte NIE JE, preto sa nezapisuje.
              'code_by_nl' => { '350' => '357926', '420' => '357927',
                                '470' => '357928' } }
          ] },
        { 'set_id' => 'atira-antracit-h176-sisy', 'name' => 'Atira antracit H176 — klasické',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'classic',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 176,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              # NL 350, 520 a 620 antracit v tejto vyske NEMA -> RED.
              'code_by_nl' => { '420' => '357969', '470' => '357970' } }
          ] },
        { 'set_id' => 'atira-antracit-h70-p2o', 'name' => 'Atira antracit H70 — Tip-On',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'tipon',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 70,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              # NL 620 antracit nema v ziadnej vyske -> RED.
              'code_by_nl' => { '350' => '357914', '420' => '357915',
                                '470' => '357916', '520' => '357917' } },
            { 'per' => 'unit', 'qty' => 1, 'label' => 'PTOs mechanizmus',
              'code_by_nl' => { '350' => '352908', '420' => '352908',
                                '470' => '352908', '520' => '352908' } }
          ] },
        { 'set_id' => 'atira-antracit-h144-p2o', 'name' => 'Atira antracit H144 — Tip-On',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'tipon',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 144,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '357955', '420' => '357956',
                                '470' => '357957', '520' => '357958' } },
            { 'per' => 'unit', 'qty' => 1, 'label' => 'PTOs mechanizmus',
              'code_by_nl' => { '350' => '352908', '420' => '352908',
                                '470' => '352908', '520' => '352908' } }
          ] },
        { 'set_id' => 'atira-antracit-h176-p2o', 'name' => 'Atira antracit H176 — Tip-On',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'tipon',
          'drawer_construction' => 'metal', 'manufacturer' => 'Hettich',
          'series' => 'InnoTech Atira', 'height_variant' => 176,
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '357996', '420' => '357997',
                                '470' => '357998', '520' => '357999' } },
            { 'per' => 'unit', 'qty' => 1, 'label' => 'PTOs mechanizmus',
              'code_by_nl' => { '350' => '352908', '420' => '352908',
                                '470' => '352908', '520' => '352908' } }
          ] },
        # Quadro V6 vyskove varianty NEMA — `height_variant` preto CHYBA
        # (a mapovanie na neho smie ukazovat pevnym `set_id`).
        { 'set_id' => 'vysuv-quadro-v6-sisy', 'name' => 'Quadro V6 EB23 — klasické',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'classic',
          'drawer_construction' => 'wood', 'manufacturer' => 'Hettich', 'series' => 'Quadro',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '317640', '400' => '317641', '450' => '317642',
                                '500' => '317643', '550' => '367919' } }
          ] },
        { 'set_id' => 'vysuv-quadro-v6-p2o', 'name' => 'Quadro V6 EB23 — Tip-On',
          'generic_type' => 'slide', 'use_type' => 'drawer', 'opening_mode' => 'tipon',
          'drawer_construction' => 'wood', 'manufacturer' => 'Hettich', 'series' => 'Quadro',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada',
              'code_by_nl' => { '350' => '343031', '400' => '343033', '450' => '317644' } }
          ] },
        { 'set_id' => 'zavesenie-bystrica', 'name' => 'Zavesenie na stenu „Bystrica"',
          'generic_type' => 'wall_hanger',
          'members' => [{ 'code' => '93240', 'per' => 'unit', 'qty' => 1 }] },
        { 'set_id' => 'podperky-police', 'name' => 'Podperka policová 7/5',
          'generic_type' => 'shelf_pin',
          'members' => [{ 'code' => '306125', 'per' => 'unit', 'qty' => 1 }] },
        # === KOV-E1a: VYKLOPY AVENTOS (seed v7, 9.9.2026) ====================
        #
        # Sest setov = tri triedy (HK klasik · HK Tip-On · HL klasik) x DVE
        # FARBY. Farba NIE JE klasifikacne pole (Demos ju nesie len v nazve
        # polozky), takze tmavy set nema triedny kluc — vybera sa PER CELO
        # (`class:lift|<mode>|<system>@front:<id>/flap` v `config.hardware_sets`).
        #
        # PORADIE CLENOV JE ZAVAZNE: mechanizmus je PRVY. Supis clenov aj
        # nakupny riadok tak zacinaju tym, co vyklop naozaj drzi; krytky
        # a prichyt su prislusenstvo.
        #
        # Mechanizmus a ramena sa vyberaju `code_by_param` (trieda z pravidla
        # `vyklopy-aventos`, ktore pride v E1b) — chybajuci kluc je VZDY chyba
        # (vyklop nema „vedome bez kodu", sentinel `none` sa sem NEDEDI).
        # Stabilizacna tyc a jej predlzovaci diel beru POCET z polozky
        # (`quantity_from`), a to `per: 'owner'` — tyc je na CELO, nie na kus.
        { 'set_id' => 'vyklop-hk-klasik', 'name' => 'Výklop HK top — klasik (biela)',
          'generic_type' => 'lift', 'use_type' => 'lift', 'opening_mode' => 'classic',
          'lift_system' => 'hk_top', 'manufacturer' => 'Blum', 'series' => 'AVENTOS',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'mechanizmus HK top',
              'code_by_param' => { 'param' => 'lift_class',
                                   'codes' => { '22K2300' => '347810', '22K2500' => '347811',
                                                '22K2700' => '347812', '22K2900' => '347813' } } },
            { 'code' => '13781', 'per' => 'unit', 'qty' => 1, 'label' => 'čelný príchyt (pár)' },
            { 'code' => '347834', 'per' => 'unit', 'qty' => 1, 'label' => 'krytky biele' }
          ] },
        { 'set_id' => 'vyklop-hk-klasik-tmavy', 'name' => 'Výklop HK top — klasik (tmavá)',
          'generic_type' => 'lift', 'use_type' => 'lift', 'opening_mode' => 'classic',
          'lift_system' => 'hk_top', 'manufacturer' => 'Blum', 'series' => 'AVENTOS',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'mechanizmus HK top',
              'code_by_param' => { 'param' => 'lift_class',
                                   'codes' => { '22K2300' => '347810', '22K2500' => '347811',
                                                '22K2700' => '347812', '22K2900' => '347813' } } },
            { 'code' => '13781', 'per' => 'unit', 'qty' => 1, 'label' => 'čelný príchyt (pár)' },
            { 'code' => '347835', 'per' => 'unit', 'qty' => 1, 'label' => 'krytky tmavo šedé' }
          ] },
        { 'set_id' => 'vyklop-hk-tipon', 'name' => 'Výklop HK top — Tip-On (biela)',
          'generic_type' => 'lift', 'use_type' => 'lift', 'opening_mode' => 'tipon',
          'lift_system' => 'hk_top', 'manufacturer' => 'Blum', 'series' => 'AVENTOS',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'mechanizmus HK top Tip-On',
              'code_by_param' => { 'param' => 'lift_class',
                                   'codes' => { '22K2300' => '347814', '22K2500' => '347826',
                                                '22K2700' => '347827', '22K2900' => '347828' } } },
            { 'code' => '13781', 'per' => 'unit', 'qty' => 1, 'label' => 'čelný príchyt (pár)' },
            { 'code' => '347834', 'per' => 'unit', 'qty' => 1, 'label' => 'krytky biele' },
            { 'code' => '250831', 'per' => 'owner', 'qty' => 1, 'label' => 'Tip-On jednotka 76 mm' }
          ] },
        { 'set_id' => 'vyklop-hk-tipon-tmavy', 'name' => 'Výklop HK top — Tip-On (tmavá)',
          'generic_type' => 'lift', 'use_type' => 'lift', 'opening_mode' => 'tipon',
          'lift_system' => 'hk_top', 'manufacturer' => 'Blum', 'series' => 'AVENTOS',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'mechanizmus HK top Tip-On',
              'code_by_param' => { 'param' => 'lift_class',
                                   'codes' => { '22K2300' => '347814', '22K2500' => '347826',
                                                '22K2700' => '347827', '22K2900' => '347828' } } },
            { 'code' => '13781', 'per' => 'unit', 'qty' => 1, 'label' => 'čelný príchyt (pár)' },
            { 'code' => '347835', 'per' => 'unit', 'qty' => 1, 'label' => 'krytky tmavo šedé' },
            { 'code' => '497007', 'per' => 'owner', 'qty' => 1,
              'label' => 'Tip-On jednotka 76 mm čierna' }
          ] },
        { 'set_id' => 'vyklop-hl-klasik', 'name' => 'Výklop HL top — klasik (biela)',
          'generic_type' => 'lift', 'use_type' => 'lift', 'opening_mode' => 'classic',
          'lift_system' => 'hl_top', 'manufacturer' => 'Blum', 'series' => 'AVENTOS',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'mechanizmus HL top',
              'code_by_param' => { 'param' => 'lift_class',
                                   'codes' => { '22L2200' => '507351', '22L2500' => '507352' } } },
            { 'per' => 'unit', 'qty' => 1, 'label' => 'ramená HL top',
              'code_by_param' => { 'param' => 'arm_class',
                                   'codes' => { '22L3200' => '507355', '22L3500' => '507356',
                                                '22L3800' => '507357', '22L3900' => '507358' } } },
            { 'code' => '507365', 'per' => 'owner', 'qty' => 1, 'label' => 'stabilizačná tyč',
              'quantity_from' => 'rod_count' },
            { 'code' => '507366', 'per' => 'owner', 'qty' => 1,
              'label' => 'predlžovací diel tyče', 'quantity_from' => 'rod_extension' },
            { 'code' => '13781', 'per' => 'unit', 'qty' => 1, 'label' => 'čelný príchyt (pár)' },
            { 'code' => '507343', 'per' => 'unit', 'qty' => 1, 'label' => 'krytky biele' }
          ] },
        { 'set_id' => 'vyklop-hl-klasik-tmavy', 'name' => 'Výklop HL top — klasik (tmavá)',
          'generic_type' => 'lift', 'use_type' => 'lift', 'opening_mode' => 'classic',
          'lift_system' => 'hl_top', 'manufacturer' => 'Blum', 'series' => 'AVENTOS',
          'members' => [
            { 'per' => 'unit', 'qty' => 1, 'label' => 'mechanizmus HL top',
              'code_by_param' => { 'param' => 'lift_class',
                                   'codes' => { '22L2200' => '507351', '22L2500' => '507352' } } },
            { 'per' => 'unit', 'qty' => 1, 'label' => 'ramená HL top',
              'code_by_param' => { 'param' => 'arm_class',
                                   'codes' => { '22L3200' => '507355', '22L3500' => '507356',
                                                '22L3800' => '507357', '22L3900' => '507358' } } },
            { 'code' => '507365', 'per' => 'owner', 'qty' => 1, 'label' => 'stabilizačná tyč',
              'quantity_from' => 'rod_count' },
            { 'code' => '507366', 'per' => 'owner', 'qty' => 1,
              'label' => 'predlžovací diel tyče', 'quantity_from' => 'rod_extension' },
            { 'code' => '13781', 'per' => 'unit', 'qty' => 1, 'label' => 'čelný príchyt (pár)' },
            { 'code' => '507345', 'per' => 'unit', 'qty' => 1, 'label' => 'krytky tmavo šedé' }
          ] }
      ].freeze

      # Default mapovanie novych projektov: handle/connector vedome BEZ setu
      # (uchytky sa v D neriesia — Michal 2.8.; connector pravidlo neexistuje).
      SEED_MAPPING = {
        'hinge'       => 'zaves-klasik',
        'leg'         => 'nohy-podla-sokla', # H1a: default riadi vyska sokla
        'slide'       => 'vysuv-atira-biela-h70',
        'wall_hanger' => 'zavesenie-bystrica',
        'shelf_pin'   => 'podperky-police',
        # KOV-G1a: pravidlo pride az v G1b, takze polozka `plinth_clip` zatial
        # nevznika — predvolba je tu preto, aby ju v tej davke uz nebolo treba
        # dopĺňať do KAZDEJ existujucej kniznice zvlast (`MAPPING_ADDITIONS`
        # nizsie robi to iste pre uz zalozene kniznice a projekty).
        'plinth_clip' => 'prichyt-sokla-axilo'
      }.freeze

      # --- migracia globalneho defaultu nôh (H1a, audit BLOCKER 3) ------------
      # Povodne (v1) seed tvary setov, ktorych migracia sa TYKA. Vzor
      # HardwareRules::LEGACY_SEED_SHAPES: dotkne sa LEN preukazatelne
      # NEZMENENEHO seed riadku; akykolvek pouzivatelsky zasah = ruky prec.
      # D-118b: seed v5 je PRVY, ktory meni obsah UZ EXISTUJUCICH setov (zly kod
      # 348777, chybajuci PTOs modul, premenovanie legacy setu), preto tu pribudlo
      # OSEM predoslych (v4) tvarov. `replace_untouched_seed_sets` nahradi set LEN
      # vtedy, ked sa jeho normalizovany tvar rovna niektoremu z nich — akakolvek
      # uprava pouzivatela (aj premenovanie) znamena ruky prec.
      LEGACY_SEED_SHAPES = {
        # KOV-F1: v1..v5 tvar zavesovych setov (BEZ klasifikacie). Nedotknuty
        # set sa nahradi klasifikovanym; akakolvek uprava = ruky prec.
        'zaves-klasik' => [
          { 'set_id' => 'zaves-klasik', 'name' => 'Záves KLASIK (Sensys 110° SiSy)',
            'generic_type' => 'hinge',
            'members' => [
              { 'code' => '104717', 'per' => 'unit', 'qty' => 1, 'label' => 'záves' },
              { 'code' => '106412', 'per' => 'unit', 'qty' => 1, 'label' => 'platnička' },
              { 'code' => '105408', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka misky' },
              { 'code' => '105425', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka ramienka' }
            ] }
        ],
        'zaves-p2o' => [
          { 'set_id' => 'zaves-p2o', 'name' => 'Záves P2O + TipOn (bez tlmenia)',
            'generic_type' => 'hinge',
            'members' => [
              { 'code' => '245723', 'per' => 'unit', 'qty' => 1, 'label' => 'záves P2O' },
              { 'code' => '106412', 'per' => 'unit', 'qty' => 1, 'label' => 'platnička' },
              { 'code' => '105408', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka misky' },
              { 'code' => '105425', 'per' => 'unit', 'qty' => 1, 'label' => 'krytka ramienka' },
              { 'code' => '250831', 'per' => 'owner', 'qty' => 1, 'label' => 'TipOn na dvierka' }
            ] }
        ],
        'nohy-klzak-17' => [
          { 'set_id' => 'nohy-klzak-17', 'name' => 'Klzák s rektifikáciou 17 mm',
            'generic_type' => 'leg',
            'members' => [{ 'code' => '82744', 'per' => 'unit', 'qty' => 1 }] }
        ],
        # KOV-G1a: v2..v7 tvar setu nôh (dve pasma, ziadna platnicka). Nedotknuty
        # set sa nahradi novym (17-20 STRONG klzak + 55-220 AXILO + platnicka);
        # akakolvek uprava pouzivatela = ruky prec a info log.
        'nohy-podla-sokla' => [
          { 'set_id' => 'nohy-podla-sokla', 'name' => 'Nohy podľa výšky sokla',
            'generic_type' => 'leg',
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'noha',
                'param_bands' => { 'param' => 'height',
                                   'bands' => [
                                     { 'min' => 17.0, 'max' => 21.0, 'code' => '82744' },
                                     { 'min' => 140.0, 'max' => 160.0, 'code' => '367823' }
                                   ] } }
            ] }
        ],
        'atira-antracit-h70-sisy' => [
          { 'set_id' => 'atira-antracit-h70-sisy',
            'name' => 'Atira antracit H70 — klasické',
            'generic_type' => 'slide',
            'use_type' => 'drawer',
            'opening_mode' => 'classic',
            'drawer_construction' => 'metal',
            'manufacturer' => 'Hettich',
            'series' => 'InnoTech Atira',
            'height_variant' => 70,
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada', 'code_by_nl' => { '350' => '357887', '420' => '357888', '470' => '348777', '520' => '357890' } } ] }
        ],
        'atira-biela-h70-p2o' => [
          { 'set_id' => 'atira-biela-h70-p2o',
            'name' => 'Atira biela H70 — Tip-On',
            'generic_type' => 'slide',
            'use_type' => 'drawer',
            'opening_mode' => 'tipon',
            'drawer_construction' => 'metal',
            'manufacturer' => 'Hettich',
            'series' => 'InnoTech Atira',
            'height_variant' => 70,
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada', 'code_by_nl' => { '350' => '357722', '420' => '357723', '470' => '357724', '520' => '357725', '620' => '357716' } } ] }
        ],
        'atira-biela-h144-p2o' => [
          { 'set_id' => 'atira-biela-h144-p2o',
            'name' => 'Atira biela H144 — Tip-On',
            'generic_type' => 'slide',
            'use_type' => 'drawer',
            'opening_mode' => 'tipon',
            'drawer_construction' => 'metal',
            'manufacturer' => 'Hettich',
            'series' => 'InnoTech Atira',
            'height_variant' => 144,
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada', 'code_by_nl' => { '350' => '357761', '420' => '357762', '470' => '357763', '520' => '357764', '620' => '357755' } } ] }
        ],
        'atira-biela-h176-p2o' => [
          { 'set_id' => 'atira-biela-h176-p2o',
            'name' => 'Atira biela H176 — Tip-On',
            'generic_type' => 'slide',
            'use_type' => 'drawer',
            'opening_mode' => 'tipon',
            'drawer_construction' => 'metal',
            'manufacturer' => 'Hettich',
            'series' => 'InnoTech Atira',
            'height_variant' => 176,
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada', 'code_by_nl' => { '350' => '357801', '420' => '357802', '470' => '357803', '520' => '357812', '620' => '357795' } } ] }
        ],
        'atira-antracit-h70-p2o' => [
          { 'set_id' => 'atira-antracit-h70-p2o',
            'name' => 'Atira antracit H70 — Tip-On',
            'generic_type' => 'slide',
            'use_type' => 'drawer',
            'opening_mode' => 'tipon',
            'drawer_construction' => 'metal',
            'manufacturer' => 'Hettich',
            'series' => 'InnoTech Atira',
            'height_variant' => 70,
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada', 'code_by_nl' => { '350' => '357914', '420' => '357915', '470' => '357916', '520' => '357917' } } ] }
        ],
        'atira-antracit-h144-p2o' => [
          { 'set_id' => 'atira-antracit-h144-p2o',
            'name' => 'Atira antracit H144 — Tip-On',
            'generic_type' => 'slide',
            'use_type' => 'drawer',
            'opening_mode' => 'tipon',
            'drawer_construction' => 'metal',
            'manufacturer' => 'Hettich',
            'series' => 'InnoTech Atira',
            'height_variant' => 144,
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada', 'code_by_nl' => { '350' => '357955', '420' => '357956', '470' => '357957', '520' => '357958' } } ] }
        ],
        'atira-antracit-h176-p2o' => [
          { 'set_id' => 'atira-antracit-h176-p2o',
            'name' => 'Atira antracit H176 — Tip-On',
            'generic_type' => 'slide',
            'use_type' => 'drawer',
            'opening_mode' => 'tipon',
            'drawer_construction' => 'metal',
            'manufacturer' => 'Hettich',
            'series' => 'InnoTech Atira',
            'height_variant' => 176,
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada', 'code_by_nl' => { '350' => '357996', '420' => '357997', '470' => '357998', '520' => '357999' } } ] }
        ],
        'vysuv-atira-biela-h70' => [
          { 'set_id' => 'vysuv-atira-biela-h70',
            'name' => 'Atira biela H70 (rad podľa NL)',
            'generic_type' => 'slide',
            'members' => [
              { 'per' => 'unit', 'qty' => 1, 'label' => 'K-sada', 'code_by_nl' => { '420' => '357695', '470' => '357696' } } ] }
        ]
      }.freeze

      # Migracie mapovania GLOBALNEJ kniznice: { generic_type => [from_set_id,
      # to_set_id] }. Prepis nastane LEN ked (a) mapovanie je dnes presne
      # from_set_id A (b) set from_set_id je v kniznici nezmeneny seed tvar.
      # Jednorazovost strazi seed_version (merge_seed bezi len pri starsom
      # subore) — ked si user leg neskor prehodi spat, uz sa nic neprepise.
      # PROJEKTOVE SNAPSHOTY sa NEMENIA NIKDY samy.
      MAPPING_MIGRATIONS = {
        'leg' => %w[nohy-klzak-17 nohy-podla-sokla]
      }.freeze

      # === KOV-C2a: DOPLNENIE CHYBAJUCICH MAPOVANI (add-if-absent) ============
      #
      # `MAPPING_MIGRATIONS` vie iba NAHRADIT hodnotu pri kluci, ktory uz
      # existuje — chybajuci `class:` kluc nevytvori, takze „Doplniť nové
      # predvoľby" by pri zásuvkach neopravilo NIC (Codex #301 kolo 1 P1,
      # Astra #19 F7). Preto druhy, uzsi kontrakt: `{ kluc => hodnota }` sa
      # do GLOBALNEJ kniznice doplni LEN ked kluc CHYBA. Pouzivatelske
      # mapovanie sa NIKDY neprepise a projektove snapshoty sa nemenia samy —
      # do projektu ich prenesie az VEDOME „Doplniť nové predvoľby"
      # (`merge_project_sets_seed!`, existujuci mechanizmus).
      #
      # Hodnota pre Atiru MUSI byt pasmovy selektor podla `height_variant`:
      # pevny `set_id` by po prerastenii zasuvky H70 -> H176 objednal H70 kit
      # k dielcom H176 (klasifikacia opening/construction je pri oboch rovnaka).
      # Quadro V6 vyskove varianty nema, preto tam pevny set_id staci.
      MAPPING_ADDITIONS = {
        'class:slide|classic|metal' => {
          'param' => 'height_variant',
          'bands' => [{ 'min' => 70.0, 'max' => 70.0, 'set_id' => 'atira-biela-h70-sisy' },
                      { 'min' => 144.0, 'max' => 144.0, 'set_id' => 'atira-biela-h144-sisy' },
                      { 'min' => 176.0, 'max' => 176.0, 'set_id' => 'atira-biela-h176-sisy' }]
        },
        'class:slide|tipon|metal' => {
          'param' => 'height_variant',
          'bands' => [{ 'min' => 70.0, 'max' => 70.0, 'set_id' => 'atira-biela-h70-p2o' },
                      { 'min' => 144.0, 'max' => 144.0, 'set_id' => 'atira-biela-h144-p2o' },
                      { 'min' => 176.0, 'max' => 176.0, 'set_id' => 'atira-biela-h176-p2o' }]
        },
        'class:slide|classic|wood' => 'vysuv-quadro-v6-sisy',
        'class:slide|tipon|wood'   => 'vysuv-quadro-v6-p2o',
        # KOV-F1: zavesy podla SPOSOBU OTVARANIA. Tip-On dvierka potrebuju P2O
        # set (bez tlmenia) s piestom `per: 'owner'` — klasicky set by im dal
        # tlmeny zaves a ziadny piest. Vyskove varianty tu neexistuju, takze
        # PEVNY set_id staci.
        'class:hinge|classic' => 'zaves-klasik',
        'class:hinge|tipon'   => 'zaves-p2o',
        # KOV-E1a: VYKLOPY. Trieda nesie AJ system (`hk_top` / `hl_top`), takze
        # HL set sa na HK celo nedostane. Predvolba je vzdy BIELA — tmavy set
        # (tmavo sede krytky, cierny Tip-On) si pouzivatel vybera VEDOME na
        # konkretnom cele (E2). `class:lift|tipon|hl_top` v zozname NIE JE:
        # HL top Tip-On neexistuje a validacia taky kluc odmietne.
        'class:lift|classic|hk_top' => 'vyklop-hk-klasik',
        'class:lift|tipon|hk_top'   => 'vyklop-hk-tipon',
        'class:lift|classic|hl_top' => 'vyklop-hl-klasik',
        # KOV-G1a: PRICHYT SOKLA je GENERICKY kluc (nie triedny) — trieda by
        # menovala sposob otvarania, ktory prichyt nema. Do uz zalozenej
        # kniznice sa doplni add-if-absent rovnako ako triedne kluce vyssie;
        # do projektu ho prenesie vedome „Doplniť nové predvoľby".
        'plinth_clip' => 'prichyt-sokla-axilo'
      }.freeze
    end
  end
end
