# frozen_string_literal: true
# R-02 — GUARD IDENTITY DOKUMENTU v zapisovych handleroch panela.
#
# PRECO to existuje: panel je JEDEN pre vsetky otvorene dokumenty a callback
# HtmlDialogu je asynchronny. ID objektov su jedinecne LEN v ramci modelu
# (CAB-001 aj BRD-001 su v kazdej zakazke), takze echo `cabinet_id`/`board_id`
# prepnutie dokumentu NEZACHYTI — oneskoreny klik by prestaval rovnomennu
# skrinku v CUDZEJ zakazke a pouzivatel by to nasiel az v objednavke.
#
# Sada je zdrojova (Panel sa headless nenacitava — potrebuje SketchUp API),
# rovnaky vzor ako tests/pure/test_uic2_zony.rb a test_d90_ukw_profil.rb:
# strazi sa KONTRAKT (guard je vo VSETKYCH 14 zapisovych handleroch a klient
# metadata naozaj posiela z JEDNEHO miesta), nie vypocet.
require 'json'

R02_PANEL_DIR = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel')
R02_JS_DIR = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js')

R02_SYNC_RB = File.read(File.join(R02_PANEL_DIR, 'sync.rb'), encoding: 'UTF-8')
R02_CAB_RB = File.read(File.join(R02_PANEL_DIR, 'actions_cabinet.rb'), encoding: 'UTF-8')
R02_HW_RB = File.read(File.join(R02_PANEL_DIR, 'actions_hardware.rb'), encoding: 'UTF-8')
R02_BOARD_RB = File.read(File.join(R02_PANEL_DIR, 'actions_board.rb'), encoding: 'UTF-8')

# Telo metody z Panel modulu (rovnaky rez ako pouzivaju ostatne zdrojove sady).
def r02_body(src, name)
  src[/def #{Regexp.escape(name)}\(.*?\n        end\n/m].to_s
end

NxTest.test('R-02: guard identity dokumentu je JEDEN zdielany helper') do
  body = r02_body(R02_SYNC_RB, 'foreign_document?')
  NxTest.refute(body.empty?, 'foreign_document? zije v sync.rb pri model_guid')
  NxTest.assert(body.include?("data['model_guid'].to_s == model_guid(model)"),
                'porovnava sa guid payloadu s guidom AKTIVNEHO dokumentu')
  # PRISNE porovnanie (vzor handle_tag_visible / zone_ctx): prazdny guid nie je
  # starsi klient, je to okno bez dobehnuteho NX.init a to nesmie zapisovat.
  NxTest.refute(body.include?('.empty?'),
                'ziadna volnejsia vetva pre prazdny guid — prisne porovnanie')
  NxTest.assert(body.include?('set_status(') && body.include?('inému dokumentu'),
                'nezhoda je NAHLAS (pouzivatel musi vediet, ze sa zmena neulozila)')
  NxTest.assert(body.include?('Engine.log('), 'nezhoda sa aj loguje (diagnostika)')
  NxTest.assert(body.include?('true'), 'vracia true = volajuci zapis odmietne')
end

NxTest.test('R-02: VSETKYCH 14 zapisovych handlerov panela ma guard dokumentu') do
  {
    R02_CAB_RB => %w[handle_insert handle_insert_copy handle_rename_cabinet
                     handle_apply handle_apply_fronts handle_apply_all],
    R02_HW_RB => %w[handle_set_hardware_override handle_set_hardware_set],
    R02_BOARD_RB => %w[handle_insert_board]
  }.each do |src, names|
    names.each do |name|
      body = r02_body(src, name)
      NxTest.refute(body.empty?, "#{name} sa nasiel")
      NxTest.assert(body.include?('foreign_document?'),
                    "#{name} musi mat guard identity dokumentu")
    end
  end
  # Zvysnych 5 doskovych handlerov (fields/material/edge/edges_all/orientation)
  # ide cez SPOLOCNU branu `guarded_board` — guard je tam, nie 5x skopirovany.
  gb = r02_body(R02_BOARD_RB, 'guarded_board')
  NxTest.refute(gb.empty?, 'guarded_board sa nasiel')
  NxTest.assert(gb.include?('foreign_document?'), 'spolocna brana karty dosky ma guard')
  NxTest.assert(gb.include?('return [nil, nil] if foreign_document?'),
                'nezhoda dokumentu zastavi cestu PRED hladanim dosky')
  %w[handle_set_board_fields handle_set_board_material handle_set_board_edge
     handle_set_board_edges_all handle_set_board_orientation].each do |name|
    body = r02_body(R02_BOARD_RB, name)
    NxTest.refute(body.empty?, "#{name} sa nasiel")
    NxTest.assert(body.include?('guarded_board(data)'),
                  "#{name} musi ist cez spolocnu branu guarded_board")
  end
end

NxTest.test('R-02: guard bezi PRED akymkolvek zapisom aj pred echo identitou') do
  # Poradie je podstata veci: `cabinet_id` echo prepnutie dokumentu nezachyti
  # (CAB-001 je v kazdej zakazke), takze dokument sa musi overit PRVY.
  { R02_CAB_RB => %w[handle_rename_cabinet handle_apply_fronts handle_apply_all],
    R02_HW_RB => %w[handle_set_hardware_override handle_set_hardware_set] }.each do |src, names|
    names.each do |name|
      body = r02_body(src, name)
      doc = body.index('foreign_document?')
      echo = body.index("data['cabinet_id']")
      NxTest.assert(!doc.nil? && !echo.nil? && doc < echo,
                    "#{name}: identita dokumentu sa overuje PRED echom skrinky")
    end
  end
  # Vklad: guard pred builderom (nova geometria v cudzej zakazke je najhorsi
  # pripad — nikto ju tam nehlada).
  ins = r02_body(R02_CAB_RB, 'handle_insert')
  NxTest.assert(ins.index('foreign_document?') < ins.index('CabinetBuilder.build'),
                'handle_insert: guard pred stavbou')
  insb = r02_body(R02_BOARD_RB, 'handle_insert_board')
  NxTest.assert(insb.index('foreign_document?') < insb.index('BoardBuilder.build'),
                'handle_insert_board: guard pred stavbou')
end

NxTest.test('R-02: klient posiela model_guid z JEDNEHO miesta (nxDocPayload)') do
  shell = File.read(File.join(R02_JS_DIR, 'shell.js'), encoding: 'UTF-8')
  NxTest.assert(shell.include?('function nxDocPayload'), 'JS ma jedno miesto pre identitu dokumentu')
  NxTest.assert(shell.include?('o.model_guid'), 'helper doplna model_guid')
  NxTest.assert(shell.include?('return JSON.stringify(o)'), 'helper vracia retazec pre callback')

  js = %w[actions.js bridge.js form.js board_card.js hardware.js].map do |f|
    File.read(File.join(R02_JS_DIR, f), encoding: 'UTF-8')
  end.join("\n")
  # Ziadna z 12 zapisovych ciest nesmie posielat holy JSON.stringify — bez
  # identity dokumentu by ju server (spravne) odmietol a zapis by sa stratil.
  %w[insert_cabinet insert_copy rename_cabinet apply_all insert_board
     set_board_fields set_board_material set_board_edge set_board_edges_all
     set_board_orientation set_hardware_set set_hardware_override].each do |cb|
    NxTest.refute(js.include?("sketchup.#{cb}(JSON.stringify("),
                  "#{cb} sa nesmie posielat bez identity dokumentu (nxDocPayload)")
    NxTest.assert(js.include?("sketchup.#{cb}(nxDocPayload("),
                  "#{cb} posiela payload cez nxDocPayload")
  end
end

NxTest.test('R-02: in-SketchUp runner posiela identitu dokumentu ako panel') do
  # Runner je jediny dalsi klient tychto handlerov — bez guidu by mu prisny
  # guard zahodil kazdy zapis a sada by zlyhala z NESPRAVNEHO dovodu.
  src = File.read(File.join(NxTest::ROOT, 'tests', 'sketchup', 'su_runner.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?("hash.merge('model_guid' => e::Panel.model_guid(model))"),
                'runner ma jedno miesto (pg), ktore identitu doplna')
  %w[handle_insert handle_insert_copy handle_apply_all handle_set_hardware_override
     handle_set_board_fields handle_set_board_material handle_set_board_edge
     handle_set_board_edges_all handle_set_board_orientation].each do |name|
    calls = src.scan(/Panel\.#{Regexp.escape(name)}\(([^\n]*)/)
    next if calls.empty?

    calls.each do |(arg)|
      NxTest.assert(arg.start_with?('pg(model'),
                    "runner vola #{name} cez pg(model, ...) — #{arg[0, 40]}")
    end
  end
end
