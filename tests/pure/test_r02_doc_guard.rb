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
  # R-02b + review #267 P3-2: samotne porovnanie uz nezije TU, ale v JEDNOM
  # porovnavaci `DocKey.foreign?`, ktory pouzivaju VSETKY guardy (predtym mala
  # fail-closed poistku len tato cesta a ~20 priamych porovnani ju obchadzalo).
  NxTest.assert(body.include?('DocKey.foreign?(data[\'model_guid\'], model)'),
                'porovnanie robi zdielany DocKey.foreign? v PRISNOM rezime')
  NxTest.refute(body.include?('tolerate_blank_client'),
                'zapisovy guard panela je PRISNY — payload bez identity nezapisuje')
  # PRISNE porovnanie (vzor handle_tag_visible / zone_ctx): prazdny guid nie je
  # starsi klient, je to okno bez dobehnuteho NX.init a to nesmie zapisovat.
  # Jedina povolena praca s .empty? je FAIL-CLOSED smer (R-02b BLOCKER 1):
  # prazdny kluc SERVERA zapis tiez zastavi — ziadna tolerantna vetva payloadu.
  NxTest.refute(body.include?("data['model_guid'].to_s.empty?"),
                'ziadna volnejsia vetva pre prazdny guid payloadu — prisne porovnanie')
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
  # pripad — nikto ju tam nehlada). Od GHOST vkladania (V1-04) `handle_insert`
  # nestavia — pripravi ZMRAZENY plan a zavesi ghost na kurzor, takze prvym
  # krokom smerom k modelu je `prepare_insert`; guard musi byt pred NIM.
  # (Druha obrana ostava v `commit_insert`, ktory plan z ineho dokumentu
  # odmietne — R-03.)
  ins = r02_body(R02_CAB_RB, 'handle_insert')
  NxTest.assert(ins.index('foreign_document?') < ins.index('CabinetBuilder.prepare_insert'),
                'handle_insert: guard pred pripravou vkladu')
  NxTest.assert(ins.index('foreign_document?') < ins.index('GhostTool.start'),
                'handle_insert: guard pred zalozenim ghost session')
  # GHOST-D1: aj doska ide cez ghost — prvym krokom smerom k modelu je
  # `prepare_insert`, guard musi byt pred NIM aj pred zalozenim session
  # a pred citanim ULOZENEJ sablony (downgrade brana).
  insb = r02_body(R02_BOARD_RB, 'handle_insert_board')
  NxTest.assert(insb.index('foreign_document?') < insb.index('newer_template_refusal'),
                'handle_insert_board: guard pred citanim sablony')
  NxTest.assert(insb.index('foreign_document?') < insb.index('BoardBuilder.prepare_insert'),
                'handle_insert_board: guard pred pripravou vkladu')
  NxTest.assert(insb.index('foreign_document?') < insb.index('GhostTool.start'),
                'handle_insert_board: guard pred zalozenim ghost session')
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
  NxTest.assert(form.include?('applyPendingGuid = nxDocGuid();'),
                'auto-apply zachytava dokument pri naplanovani')
  NxTest.assert(sched.include?('cabSnapshot, applyPendingGuid'),
                'zachyteny dokument ide do odlozeneho flushu')
  NxTest.assert(form.include?('sketchup.apply_all(nxDocPayload(payload, guidSnapshot))'),
                'auto-apply posiela ZACHYTENY dokument')

  board = File.read(File.join(R02_JS_DIR, 'board_card.js'), encoding: 'UTF-8')
  NxTest.assert(board.include?('guid: pendGuid'),
                'pending karty dosky si drzi dokument z casu naplanovania')
  NxTest.assert(board.include?('sketchup.set_board_fields(nxDocPayload(p, g))'),
                'flush posiela ZACHYTENY dokument')
  NxTest.assert(board.include?('delete p.guid'),
                'pracovny kluc pendingu sa do payloadu nedostane')
  # Review #264 kolo 2: OKAMZITY flush musi prevziat zachyteny dokument —
  # inak by stare hodnoty formulara opeciatkoval dnesnym guidom.
  now = form[/function flushCabinetEditsNow\(\).*?\n  \}/m].to_s
  NxTest.refute(now.empty?, 'flushCabinetEditsNow sa nasiel')
  NxTest.assert(now.include?('applyPendingGuid'),
                'okamzity flush berie ZACHYTENY dokument, nie dnesny')
  NxTest.assert(now.include?('flushCabinetEdits(selectedCabId, g)'),
                'zachyteny dokument ide do odoslania')
  # Batch karty dosky je klucovany DVOJICOU dokument+doska (`BRD-001` je
  # v kazdej zakazke — samotne id by zmiesalo edity dvoch dokumentov).
  NxTest.assert(board.include?("boardPending.guid !== pendGuid"),
                'pending dosky sa porovnava aj podla DOKUMENTU')
end

NxTest.test('R-02: zmena dokumentu ZAHODI vsetok rozpracovany stav panela') do
  # Review #264 kolo 2 — rodina nalezov: UI stav, ktory prezije prepnutie
  # dokumentu a pri odoslani dostane NOVY guid. Prva obrana je JEDNO miesto:
  # `nxSetModelGuid` je jediny detektor zmeny dokumentu na klientovi (kazdy
  # push ide cez neho), takze pri zmene hodnoty zahodi vsetky pending buffery,
  # editory a modaly. Echo push tej istej identity nesmie zahodit NIC.
  shell = File.read(File.join(R02_JS_DIR, 'shell.js'), encoding: 'UTF-8')
  setter = shell[/function nxSetModelGuid\(g\)\{.*?\n  \}/m].to_s
  NxTest.refute(setter.empty?, 'nxSetModelGuid sa nasiel')
  NxTest.assert(setter.include?('if (next === nxModelGuid) return;'),
                'echo push tej istej identity NEZAHADZUJE rozpisanu pracu')
  NxTest.assert(setter.include?('nxDropDocState()'),
                'skutocna zmena dokumentu spusti centralne zahodenie')

  drop = shell[/function nxDropDocState\(\)\{.*?\n  \}/m].to_s
  NxTest.refute(drop.empty?, 'nxDropDocState sa nasiel')
  # UPLNY zoznam stavu, ktory drzi data medzi akciou a volanim `sketchup.*`.
  # Kazdy novy pending buffer / editor / modal patri SEM (inak prezije
  # prepnutie dokumentu a jeho zapis skonci v cudzej zakazke).
  %w[cancelCabinetEdits cancelBoardEdits dropCabRename closeCabRenameEditor
     absModalCloseSilent closeSaveTemplateModal closeSimilarModal].each do |fn|
    NxTest.assert(drop.include?("typeof #{fn} === 'function'") && drop.include?("#{fn}();"),
                  "#{fn} sa pri zmene dokumentu vola (a je volany bezpecne cez typeof)")
  end
end

NxTest.test('R-02: kazdy pending buffer nesie VLASTNU zachytenu identitu') do
  # Druha obrana (prva je centralne zahodenie, tretia serverovy guard):
  # keby push zo servera neprisiel, buffer si identitu drzi sam.
  form = File.read(File.join(R02_JS_DIR, 'form.js'), encoding: 'UTF-8')
  board = File.read(File.join(R02_JS_DIR, 'board_card.js'), encoding: 'UTF-8')
  bridge = File.read(File.join(R02_JS_DIR, 'bridge.js'), encoding: 'UTF-8')
  part = File.read(File.join(R02_JS_DIR, 'part_card.js'), encoding: 'UTF-8')
  core = File.read(File.join(R02_JS_DIR, 'core.js'), encoding: 'UTF-8')

  NxTest.assert(core.include?('var applyPendingGuid = null;'),
                'rozpisane edity formulara maju modulovy slot na dokument')
  NxTest.assert(form.include?('function cancelCabinetEdits()'),
                'existuje cesta, ktora rozpisane edity zahodi aj s identitou')

  # Inline premenovanie: editor prezije prepnutie dokumentu na rovnomennu
  # skrinku (setIdbar porovnava len cabinet_id), preto si guid drzi sam.
  NxTest.assert(bridge.include?('renameGuid = nxDocGuid();'),
                'editor nazvu zachytava dokument pri otvoreni')
  NxTest.assert(bridge.include?('guid === nxDocGuid()'),
                'Enter neposle nic, ked sa dokument medzitym zmenil')
  NxTest.assert(bridge.include?('nxDocPayload({ cabinet_id: cid, name: name }, guid)'),
                'premenovanie posiela ZACHYTENY dokument')
  NxTest.assert(bridge.include?('renameGuid = \'\';'),
                'zahodenie editora maze aj zachytenu identitu')

  # Modal chybajucej ABS je asynchronny a karty su mutovatelne globaly —
  # ciel sa preto zachytava pri OTVORENI a pri odoslani sa overuje.
  NxTest.assert(board.include?('function boardTarget()') && board.include?('function boardTargetStale('),
                'karta dosky ma snapshot ciela modalu')
  NxTest.assert(part.include?('function partTarget()') && part.include?('function partTargetStale('),
                'karta dielca ma snapshot ciela modalu')
  %w[sendBoardMaterial sendBoardEdgesAll].each do |fn|
    NxTest.assert(board.include?("function #{fn}(") && board[/function #{fn}\(.*?\n  \}/m].to_s.include?('Stale('),
                  "#{fn} overuje ciel pred odoslanim")
  end
  %w[sendPartMaterial sendEdgesAll].each do |fn|
    NxTest.assert(part[/function #{fn}\(.*?\n  \}/m].to_s.include?('partTargetStale('),
                  "#{fn} overuje ciel pred odoslanim")
  end
  # Modal sa navyse zatvara pri KAZDEJ zmene toho, co je na obrazovke —
  # `loadSelected` to robilo uz predtym, `loadBoard` a `clearSelected` nie.
  NxTest.assert(bridge.scan('absModalCloseSilent()').length >= 3,
                'ABS modal sa zatvara pri vsetkych troch pushoch (selected/board/clear)')
end

NxTest.test('R-02: identita dokumentu sa vyhodnocuje PRVA v celom push flow') do
  # Review #264 kolo 3 (rezidual poradia): centralne zahodenie stavu je uzitocne
  # len vtedy, ked bezi PRED stavovymi rozhodnutiami pushu. `keepGaps` (ci sa
  # zachovaju rozpisane riadky ciel) sa rozhodovalo skor, nez `setUiMode` na
  # konci pushu vobec dosiel k `nxSetModelGuid` — riadky z dokumentu A tak
  # prezili do B a prvy dalsi edit ich odoslal s guidom B.
  bridge = File.read(File.join(R02_JS_DIR, 'bridge.js'), encoding: 'UTF-8')

  sel = bridge[/loadSelected: function\(c\)\{.*?\n    \},\n/m].to_s
  NxTest.refute(sel.empty?, 'loadSelected sa nasiel')
  gu = sel.index('nxSetModelGuid(c.model_guid)')
  NxTest.assert(!gu.nil?, 'loadSelected nastavuje identitu dokumentu sam')
  # Hladaju sa VOLANIA/priradenia, nie hole nazvy — tie su aj v komentari nad
  # guardom a poradie by potom meralo komentare.
  ['cancelBoardEdits();', 'var keepGaps', 'renderFronts(c.fronts',
   'setSelected(c.cabinet_id', 'setUiMode(c.part_card'].each do |later|
    at = sel.index(later)
    NxTest.assert(!at.nil? && gu < at,
                  "identita dokumentu je v loadSelected PRED `#{later}`")
  end
  NxTest.assert(sel.include?('var sameDoc = (String(c.model_guid || \'\') === nxDocGuid());'),
                'zhoda dokumentu sa zachyti PRED prepisom identity')
  NxTest.assert(sel.index('var sameDoc') < gu, 'sameDoc sa cita este pred prepisom')
  NxTest.assert(sel.include?('var keepGaps = sameDoc &&'),
                'identita dokumentu je SUCASTOU podmienky keepGaps')

  brd = bridge[/loadBoard: function\(b\)\{.*?\n    \},\n/m].to_s
  NxTest.refute(brd.empty?, 'loadBoard sa nasiel')
  gb = brd.index('nxSetModelGuid(b && b.model_guid)')
  NxTest.assert(!gb.nil?, 'loadBoard nastavuje identitu dokumentu sam')
  # Ta ista pasca: pending batch sa zahadzuje podla SAMOTNEHO board_id, pritom
  # `BRD-001` je v kazdej zakazke.
  NxTest.assert(gb < brd.index('boardCard.board_id !== b.board_id').to_i,
                'identita dokumentu je v loadBoard PRED testom na inu dosku')

  # `clearSelected` malo identitu prvu uz predtym — nesmie sa to stratit.
  clr = bridge[/clearSelected: function\(guid\)\{.*?\n    \},\n/m].to_s
  NxTest.assert(clr.index('nxSetModelGuid(guid)').to_i < clr.index('cancelBoardEdits()').to_i,
                'clearSelected drzi identitu prvu')

  # Zatvarka „apply odoslany, echo este nedoslo" je DRUHA polovica keepGaps —
  # sama o sebe prezije prepnutie dokumentu, takze ju musi nulovat cleanup.
  # ALE VYHRADNE ten centralny (interne review kola 4, P2): `cancelCabinetEdits`
  # bezi aj v JEDNODOKUMENTOVOM flow (zruseny okamzity flush pri cervenom poli,
  # rozpisany vyraz v poli) a zhodena zatvarka by tam nechala najblizsie echo
  # zmazat prave pridane celo aj rozpisane gap hodnoty.
  form = File.read(File.join(R02_JS_DIR, 'form.js'), encoding: 'UTF-8')
  shell = File.read(File.join(R02_JS_DIR, 'shell.js'), encoding: 'UTF-8')
  cancel = form[/function cancelCabinetEdits\(\)\{.*?\n  \}/m].to_s
  NxTest.refute(cancel.include?('cabEditsInFlight = false'),
                'zrusenie editov NESMIE zhodit zatvarku — rozbilo by jednodokumentove flow')
  drop = shell[/function nxDropDocState\(\)\{.*?\n  \}/m].to_s
  NxTest.assert(drop.include?('cabEditsInFlight = false;'),
                'zatvarku nuluje centralne zahodenie (bezi len pri realnej zmene dokumentu)')
  # Fokus: CEF drzi `activeElement` aj po strate fokusu okna, takze `bset` by
  # pole s kurzorom preskocilo a nechalo v nom hodnotu zo starej zakazky.
  NxTest.assert(drop.include?('document.activeElement.blur()'),
                'centralne zahodenie zhadzuje fokus, aby render prepisal vsetky polia')
  NxTest.assert(drop.include?('try {') && drop.include?('catch (e)'),
                'blur je v try/catch — fokus nesmie zhodit zahodenie stavu')
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
