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
R02_MAT_RB = File.read(File.join(R02_PANEL_DIR, 'actions_materials.rb'), encoding: 'UTF-8')
R02_PARTS_RB = File.read(File.join(R02_PANEL_DIR, 'actions_parts.rb'), encoding: 'UTF-8')

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

NxTest.test('R-02: VSETKY zapisove handlery panela maju guard dokumentu') do
  {
    R02_CAB_RB => %w[handle_insert handle_insert_copy handle_rename_cabinet
                     handle_apply handle_apply_fronts handle_apply_all],
    R02_HW_RB => %w[handle_set_hardware_override handle_set_hardware_set],
    R02_BOARD_RB => %w[handle_insert_board],
    # Review #264 P1-2: doplnene cesty, ktore mali len echo `cabinet_id`
    # (to prepnutie dokumentu nezachyti — CAB-001 je v kazdej zakazke).
    R02_MAT_RB => %w[handle_set_cabinet_material],
    R02_PARTS_RB => %w[handle_set_part_material handle_set_part_edge handle_set_part_edges_all]
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
    R02_HW_RB => %w[handle_set_hardware_override handle_set_hardware_set],
    R02_MAT_RB => %w[handle_set_cabinet_material],
    R02_PARTS_RB => %w[handle_set_part_material handle_set_part_edge
                       handle_set_part_edges_all] }.each do |src, names|
    names.each do |name|
      body = r02_body(src, name)
      doc = body.index('foreign_document?')
      # Echo skrinky ma dva tvary: inline porovnanie alebo helper
      # `stale_cabinet_echo?` — pozicia PRVEHO z nich je hranica poradia.
      echo = [body.index("data['cabinet_id']"), body.index('stale_cabinet_echo?')].compact.min
      NxTest.assert(!doc.nil? && !echo.nil? && doc < echo,
                    "#{name}: identita dokumentu sa overuje PRED echom skrinky")
    end
  end
  # Karta dielca: guard dokumentu je aj pred kontrolou CIELA zmeny — tá hľadá
  # dielec v AKTIVNOM dokumente, takže rovnomenný dielec v inej zákazke by jej
  # prešiel (review #264 P1-2).
  %w[handle_set_part_material handle_set_part_edge].each do |name|
    body = r02_body(R02_PARTS_RB, name)
    # Hlada sa VOLANIE (`err = part_target_error(`), nie holy nazov — ten je aj
    # v komentari nad guardom a poradie by potom meralo komentare.
    NxTest.assert(body.index('foreign_document?(') < body.index('= part_target_error('),
                  "#{name}: guard dokumentu pred part_target_error")
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

  js = %w[actions.js bridge.js form.js board_card.js hardware.js materials.js
          part_card.js].map do |f|
    File.read(File.join(R02_JS_DIR, f), encoding: 'UTF-8')
  end.join("\n")
  # Ziadna zapisova cesta nesmie posielat holy JSON.stringify — bez identity
  # dokumentu by ju server (spravne) odmietol a zapis by sa stratil.
  # Zoznam je UPLNY sumar model-zapisovych callbackov panela (sweep review #264
  # P1-2). Vynimka je JEDINA: `set_part_grain` nesie `model_guid` z karty
  # inline uz od K1/D-108 (strazi test_k1_smer_dekoru.rb) — jeho tvar sa
  # zamerne nemenil, aby davka nerozbijala existujuci kontrakt.
  %w[insert_cabinet insert_copy rename_cabinet apply_all insert_board
     set_board_fields set_board_material set_board_edge set_board_edges_all
     set_board_orientation set_hardware_set set_hardware_override
     set_cabinet_material set_part_material set_part_edge set_part_edges_all].each do |cb|
    NxTest.refute(js.include?("sketchup.#{cb}(JSON.stringify("),
                  "#{cb} sa nesmie posielat bez identity dokumentu (nxDocPayload)")
    NxTest.assert(js.include?("sketchup.#{cb}(nxDocPayload("),
                  "#{cb} posiela payload cez nxDocPayload")
  end
  part = File.read(File.join(R02_JS_DIR, 'part_card.js'), encoding: 'UTF-8')
  NxTest.assert(part.scan('partCard.model_guid').length >= 4,
                'karta dielca berie identitu dokumentu z KARTY, nie z globalu')
end

NxTest.test('R-02: debounced edity nesu ZACHYTENY dokument, nie ten pri odoslani') do
  # Review #264 P1: `nxModelGuid` je mutovatelny global, ktory prepise
  # najblizsi push. Bez snapshotu pri NAPLANOVANI by sa zapis odlozeny
  # o 400 ms opeciatkoval NOVYM dokumentom a guard by ho pustil presne tam,
  # kam nema — teda by dokazal presne to, co ma davka zakazat.
  shell = File.read(File.join(R02_JS_DIR, 'shell.js'), encoding: 'UTF-8')
  NxTest.assert(shell.include?('function nxDocGuid'), 'existuje citac aktualnej identity')
  NxTest.assert(shell.include?('function nxDocPayload(obj, guid)'),
                'helper prijima ZACHYTENU identitu')
  NxTest.assert(shell.include?('(guid === undefined || guid === null)'),
                'prazdny retazec je PLATNA zachytena hodnota (server ju odmietne)')

  form = File.read(File.join(R02_JS_DIR, 'form.js'), encoding: 'UTF-8')
  sched = form[/applyTimer = setTimeout.*/].to_s
  NxTest.assert(form.include?('var guidSnapshot = nxDocGuid();'),
                'auto-apply zachytava dokument pri naplanovani')
  NxTest.assert(sched.include?('cabSnapshot, guidSnapshot'),
                'zachyteny dokument ide do odlozeneho flushu')
  NxTest.assert(form.include?('sketchup.apply_all(nxDocPayload(payload, guidSnapshot))'),
                'auto-apply posiela ZACHYTENY dokument')

  board = File.read(File.join(R02_JS_DIR, 'board_card.js'), encoding: 'UTF-8')
  NxTest.assert(board.include?("guid: nxDocGuid()"),
                'pending karty dosky si drzi dokument z casu naplanovania')
  NxTest.assert(board.include?('sketchup.set_board_fields(nxDocPayload(p, g))'),
                'flush posiela ZACHYTENY dokument')
  NxTest.assert(board.include?('delete p.guid'),
                'pracovny kluc pendingu sa do payloadu nedostane')
end

NxTest.test('R-02: in-SketchUp runner posiela identitu dokumentu ako panel') do
  # Runner je jediny dalsi klient tychto handlerov — bez guidu by mu prisny
  # guard zahodil kazdy zapis a sada by zlyhala z NESPRAVNEHO dovodu.
  src = File.read(File.join(NxTest::ROOT, 'tests', 'sketchup', 'su_runner.rb'), encoding: 'UTF-8')
  NxTest.assert(src.include?("hash.merge('model_guid' => e::Panel.model_guid(model))"),
                'runner ma jedno miesto (pg), ktore identitu doplna')
  %w[handle_insert handle_insert_copy handle_apply_all handle_set_hardware_override
     handle_set_board_fields handle_set_board_material handle_set_board_edge
     handle_set_board_edges_all handle_set_board_orientation
     handle_set_cabinet_material handle_set_part_material handle_set_part_edge
     handle_set_part_edges_all].each do |name|
    # Volanie sa berie aj s dvoma nasledujucimi riadkami — vacsina payloadov je
    # viacriadkova a starsie scenare nesu `model_guid` inline (oba tvary su OK,
    # guard kontroluje HODNOTU, nie zapis).
    src.scan(/Panel\.#{Regexp.escape(name)}\((?:[^\n]*\n){0,2}[^\n]*/) do |call|
      NxTest.assert(call.include?('pg(model') || call.include?("'model_guid'"),
                    "runner posiela #{name} s identitou dokumentu — #{call[0, 60]}")
    end
  end
end
