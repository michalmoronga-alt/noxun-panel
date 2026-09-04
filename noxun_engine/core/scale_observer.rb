# frozen_string_literal: true
# Noxun Engine — scale observer. Zachyti zmenu velkosti NOXUN korpusu nastrojom
# Scale a prestavi korpus na nove rozmery so spravnymi hrubkami (absorpcia scale do configu).
#
# Vzor observer managementu prevzaty z KOVANIE (main.rb): AppObserver re-attach na
# open/new/activate model, singleton observery, bezpecny detach pred attach, debounce
# cez UI.start_timer + monotonny generation counter, guard flag proti vlastnym zmenam.
#
# KRITICKE guardy:
#   @rebuilding  — observer ignoruje zmeny, ktore sposobil sam plugin (rebuild/insert).
#   debounce     — rychle tahanie Scale nespusti N rebuildov, prebehne 1 po ustaleni.
#   begin/rescue — vynimka v observeri = ticho mrtvy observer, preto vsetko obalene + log.
module Noxun
  module Engine
    module ScaleWatch
      SCALE_TOL = 0.001  # tolerancia: dlzka osi != 1.0 => scale
      DEBOUNCE  = 0.2    # s — cakanie na ustalenie po poslednej zmene
      MIN = { 'width' => 200.0, 'height' => 200.0, 'depth' => 150.0 }.freeze
      # NASTROJE-1: strop iteracii bariery `flush_pending!`. Pokoj observera
      # nastava spravidla v 1-2 iteraciach (follow-up po dedupe); vyssie cislo
      # by uz znamenalo, ze si observer sam sebe planuje pracu donekonecna.
      FLUSH_MAX_ITERATIONS = 5

      class << self
        # --- instalacia -----------------------------------------------------
        def install
          @entity_observer ||= CabinetEntityObserver.new
          @entities_observer ||= CabinetEntitiesObserver.new
          @app_observer ||= EngineAppObserver.new
          @stable_transforms = {}
          # R-04 (GH review #261 kolo 2, P2): identita dokumentu, s ktorou sa
          # porovnava pri prvom File > New/Open — bez nej by prve prepnutie
          # nemalo s cim porovnavat a zaznamy zaniknuteho dokumentu by prezili.
          @active_doc_guid = doc_guid(safe { Sketchup.active_model })
          safe { Sketchup.remove_observer(@app_observer) }
          Sketchup.add_observer(@app_observer)
          n = attach_all(Sketchup.active_model)
          # KRITICKE: entities observer (zachytava KOPIE) treba pripojit aj pri instale —
          # nie len v AppObserver eventoch (open/new). Bez tohto po starte SketchUpu
          # (alebo ak event nepride) kopie nedostanu nove ID a ich zony nesleduju presun.
          attach_entities(Sketchup.active_model)
          Engine.log("ScaleWatch nainstalovany (attachnute korpusy: #{n})")
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.install')
        end

        # Attach entity observer na vsetky existujuce korpusy A DOSKY v modeli (V0.4.7d)
        # + entities observer na model.entities (zachytenie kopii). Initial scan /
        # re-attach (install, open/new/activate).
        def attach_all(model)
          return 0 unless model
          @entity_observer ||= CabinetEntityObserver.new
          attach_entities(model)
          n = 0
          DEDUP_KINDS.each do |kind|
            Ids.each_of_kind(model, kind) { |inst| attach_one(inst); n += 1 }
          end
          n
        end

        # Attach entities observer na model.entities — zachyti PRIDANIE novych entit, hlavne
        # KOPII korpusu (Ctrl+C/V, Move+Ctrl), ktore nededia per-instancny EntityObserver.
        # Bezpecny re-attach (remove pred add) — idempotentne, reload-safe (bez dvojiteho attachu).
        def attach_entities(model)
          return unless model
          @entities_observer ||= CabinetEntitiesObserver.new
          safe { model.entities.remove_observer(@entities_observer) } # anti-double
          model.entities.add_observer(@entities_observer)
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.attach_entities')
        end

        # Attach na jednu instanciu (korpus/doska; volane aj buildermi po vlozeni).
        # V0.4.7d (Codex audit d, blocker 1): transform sa NEuklada ako stabilny,
        # ak uz nesie scale — cerstvo attachnuta ESTE NEabsorbovana kopia (paste +
        # scale v jednom ticku) by inak pri neskorsom rejecte obnovila skalovany
        # stav. Stabilny transform zapise az uspesna absorpcia / cisty stav.
        # NASTROJE-1 (audit 2 FIX 2 + audit 3 FIX 2): podmienka `unless scaled?`
        # tu ZANIKLA — kontrolovala LEN dlzky osi, takze SIKMA (shear) matica
        # s jednotkovymi, ale nekolmymi osami sa do cache dostala. Rigidita sa
        # od tejto davky vynucuje PRIAMO v `remember_transform` (jedno miesto
        # pre vsetkych volajucich: attach, absorpcia, reject aj nastroje).
        def attach_one(inst)
          return unless inst && inst.valid?
          @entity_observer ||= CabinetEntityObserver.new
          safe { inst.remove_observer(@entity_observer) } # anti-double
          inst.add_observer(@entity_observer)
          remember_transform(inst)
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.attach_one')
        end

        # --- guard (vlastne rebuildy nesmu spustit observer) ---------------
        def guard
          prev = @rebuilding
          @rebuilding = true
          yield
        ensure
          @rebuilding = prev
        end

        def rebuilding?
          @rebuilding ? true : false
        end

        # --- volane z observera --------------------------------------------
        # Zmena korpusu/dosky (V0.4.7d): scale -> absorpcia (rebuild), inak
        # (move/rotate) -> korpus presunie ghost zony, doska si len zapamata transform.
        # Rozlisenie scale/move sa robi az v process_dirty (po ustaleni transformacie).
        # R-01: kluc udalosti nesie AJ dokument. Hole `entityID` je LOKALNE pre model,
        # takze dve instancie z dvoch dokumentov (macOS) s rovnakym ID by si v jednom
        # debounce okne udalost prepisali — jedna by sa stratila. `model.object_id`
        # tu staci (a je lacnejsi nez guid): hodnotou je ZIVA entita, ktora svoj model
        # drzi pri zivote po cely debounce, takze recyklacia object_id po GC nehrozi.
        # Pre TRVALU cache (`@stable_transforms`) to NEPLATI — tam sa kluci `model_key`.
        def event_key(entity, mdl)
          [mdl ? mdl.object_id : nil, entity.entityID]
        end

        def notify_change(entity)
          return if @rebuilding
          return unless entity && entity.valid?
          return unless DEDUP_KINDS.include?(Store.kind(entity).to_s)
          mdl = (entity.model rescue nil)
          @dirty ||= {}
          @dirty[event_key(entity, mdl)] = entity
          @last_model = mdl || @last_model # fix #8: model pre prune
          schedule
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.notify_change')
        end

        # Zmazanie entity (napr. korpusu) -> pri najblizsom tiku upraceme osirotene ghost skupiny.
        # fix #8: model nesieme z eventu (pri erase je Sketchup.active_model v multi-model nespolahlivy).
        # R-01: poziadavky su MNOZINA dokumentov (vzor `@requested`, D-103) — jediny slot
        # `@erase_model` znamenal, ze druhy erase v druhom dokumente ten prvy PREPISE a
        # jeho ghosty ostanu neupratane.
        # ZNAMY ZVYSOK (macOS, priznany v registri): pri erase je entita uz neplatna,
        # takze jej dokument sa NEDA zistit — taka poziadavka ide do mnoziny ako
        # SENTINEL `nil` a v tiku sa rozhodne fallbackom. Dva NEZNAME erasy z dvoch
        # dokumentov teda splynu aj nadalej; tato davka rusi len prepisovanie ZNAMYCH
        # poziadaviek. Spolahlivy povod by vyzadoval per-model observer, ktory by drzal
        # silnu referenciu na kazdy otvoreny dokument — vedome odlozene.
        def notify_erase(model = nil)
          return if @rebuilding
          @prune_models ||= {}
          if model
            @prune_models[model.object_id] = model
          else
            @prune_models[nil] = nil
          end
          schedule
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.notify_erase')
        end

        # Pridanie entity do model.entities — zachyti KOPIU korpusu alebo DOSKY
        # (Ctrl+C/V, Move+Ctrl). Kopia dedi NOXUN atributy (zdielane id) ale NEdedi
        # per-instancny EntityObserver — bez spracovania by ostala so zdielanou identitou.
        # Debounced spracovanie (process_dirty): dedup (nove id; korpus aj vlastne ghosty)
        # + attach per-instancneho observera (len korpusy; dosky ho v b nemaju).
        # Guard: vlastne vlozenie (CabinetBuilder/BoardBuilder.build) je guardnute, takze
        # onElementAdded (davkovany na commit) tu vidi @rebuilding=true a ignoruje ho.
        DEDUP_KINDS = %w[cabinet board].freeze

        def notify_added(entity)
          return if @rebuilding
          return unless entity.is_a?(Sketchup::ComponentInstance) && entity.valid?
          return unless DEDUP_KINDS.include?(Store.kind(entity).to_s)
          mdl = (entity.model rescue nil)
          @added ||= {}
          @added[event_key(entity, mdl)] = entity # R-01: kluc nesie aj dokument
          @last_model = mdl || @last_model # fix #8: model pre dedup/prune
          schedule
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.notify_added')
        end

        # D-103: NEMUTUJUCA ziadost o opravu identity (kopie so zdielanym ID).
        # Volajuci (sync vyberu v paneli) NESMIE spustit vlastnu operaciu — tá by
        # sa stala VRCHOLOM undo stacku a nasledne `*N` nasobenie SketchUpu (Move
        # nastroj svoju operaciu PREPISUJE: interne undo + nove kopie) by odundovalo
        # JU namiesto kopie. Kopia by prezila, nasobenie by k nej pridalo dalsiu na
        # to iste miesto = dva dielce v kusovniku/VEPO/rozpocte (ziva reprodukcia
        # 9.8.2026). Oprava preto vzdy patri debouncovanemu tiku observera, ktory
        # ju vykona TRANSPARENTNE (= splynie s pouzivatelovym krokom).
        # Multi-model (Codex audit BLOCKER 1): ziadosti sa drzia ako MNOZINA modelov
        # — dva dokumenty v jednom debounce okne (macOS) sa nesmu prepisat.
        def request_dedup(model)
          return if @rebuilding
          return unless model
          @requested ||= {}
          @requested[model.object_id] = model
          @last_model = model
          schedule
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.request_dedup')
        end

        # Debounce + generation counter: kazda zmena posunie generaciu a restartuje timer;
        # spusti sa iba posledny naplanovany tick.
        def schedule
          @generation = (@generation || 0) + 1
          gen = @generation
          safe { UI.stop_timer(@timer) } if @timer
          @timer = UI.start_timer(DEBOUNCE, false) do
            begin
              if gen == @generation
                @timer = nil
                process_dirty
              end
            rescue StandardError => e
              Engine.log_error(e, 'ScaleWatch timer')
            end
          end
        end

        # --- NASTROJE-1: BARIERA PRED MUTACIOU NASTROJA ---------------------
        # `guard` zabrani len NOVYM udalostiam. Uz NAPLNENE fronty (`@dirty`,
        # `@added`, `@requested`, `@prune_models`) a BEZIACI debounce timer
        # zostavaju — a ked timer dobehne PO operacii nastroja, jeho
        # TRANSPARENTNA reakcia (dedup kopii, presun ghost zon) sa prilepi na
        # KROK POUZIVATELA, ktory s nou nema nic spolocne. Preto kazdy nastroj
        # pred polohovou mutaciou NOXUN objektu pocka, kym je observer v POKOJI.
        #
        # POKOJ = ziadny naplanovany timer A prazdne fronty VSETKYCH dokumentov
        # (audit 4: multi-model — bariera sa nesmie vyhlasit len podla
        # `@last_model`). Je to BARIERA, nie jedno spracovanie (audit 3):
        # `process_dirty` moze pri cerstvej kopii najst STARSIU duplicitu a
        # naplanovat follow-up — novy timer s prazdnymi frontami by po operacii
        # nastroja spustil transparentny dedup nad `@last_model`.
        #
        # Kazda iteracia najprv timer ZASTAVI (`@timer` na `nil`) a zvysi
        # generaciu, takze ani prezivsi callback uz nic nespusti. Pri dosiahnuti
        # stropu vrati `false` a nastroj operaciu ODMIETNE — fronty ostavaju
        # NEDOTKNUTE (`@requested` aj `@prune_models` prezijú), lebo bariera
        # sama do nich nikdy nesiaha; vyprazdnuje ich vyhradne `process_dirty`.
        #
        # `model` je dokument, ktory sa chysta zmenit volajuci — sluzi na
        # diagnostiku (bariera je zamerne GLOBALNA, viz vyssie).
        def flush_pending!(model = nil)
          return true unless pending?

          iterations = 0
          while pending?
            if iterations >= FLUSH_MAX_ITERATIONS
              Engine.log("ScaleWatch.flush_pending!: pokoj nenastal ani po #{iterations} iteraciach " \
                         "(dokument #{model ? model.object_id : '?'})")
              return false
            end
            iterations += 1
            stop_pending_timer!
            process_dirty
          end
          true
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.flush_pending!')
          false
        end

        # Je este nieco rozrobene? Timer ALEBO neprazdna fronta ktorehokolvek druhu.
        def pending?
          return true unless @timer.nil?

          [@dirty, @added, @requested, @prune_models].any? { |q| q && !q.empty? }
        end

        # Zastavi debounce timer a ZNEPLATNI jeho generaciu — prezivsi callback
        # (SketchUp ho uz mohol zaradit) najde `gen != @generation` a nespravi nic.
        def stop_pending_timer!
          safe { UI.stop_timer(@timer) } if @timer
          @timer = nil
          @generation = (@generation || 0) + 1
        end

        def process_dirty
          dirty = @dirty || {}
          @dirty = {}
          added = @added || {}
          @added = {}
          prune_requests = @prune_models || {} # R-01: MNOZINA dokumentov, nie jediny slot
          @prune_models = {}
          requested = (@requested || {}).values # D-103: modely s ziadostou o opravu identity
          @requested = {}

          # fix #6 + kopie: kopia korpusu (zdielane cabinet_id) -> nove ID + vlastne ghosty, este
          # pred spracovanim dirty. Spusti sa aj z onElementAdded (kopia Ctrl+C/V), nielen z move
          # existujuceho. Multi-model (Codex PR#6): v jednom debounce okne mozu prist instancie
          # z viacerych dokumentov (macOS) — dedup/attach bezi pre KAZDY dotknuty model zvlast.
          touched_models = (dirty.values + added.values)
                           .select { |i| i && i.valid? }.map(&:model).compact.uniq
          # D-103 (Codex audit BLOCKER 1): ziadosti z ineho dokumentu sa NESMU
          # stratit — pridavaju sa k dotknutym modelom, nie ako fallback jedneho.
          touched_models = (touched_models + requested.compact).uniq
          touched_models = prune_requests.values.compact.uniq if touched_models.empty?
          touched_models = [@last_model].compact if touched_models.empty?
          added_models = added.values.select { |i| i && i.valid? }.map(&:model).compact.uniq

          touched_models.each do |mdl|
            # Transparentny dedup LEN pre entity, ktore v TOMTO ticku realne pribudli
            # (onElementAdded) — vtedy je predchadzajuca operacia ich paste/move a 1x undo
            # vrati kopiu celu. V0.4.7b (Codex audit + GH review P2): pri cerstvych
            # entitach sa v tomto ticku spracuju VYHRADNE ony (transparent drzi priamo
            # na paste operacii); pripadne STARE duplicity v tom istom okne sa odlozia
            # na follow-up tick (schedule). D-103: aj ten uz bezi TRANSPARENTNE —
            # samostatny undo krok tesne po kopirovani bol prave ta pasca, ktora
            # rozbijala `*N` nasobenie (viz komentar v nasledujucej vetve).
            fresh_copy = added_models.include?(mdl)
            fresh_ids = added.values.select { |i| i && i.valid? && (i.model rescue nil) == mdl }
                             .map(&:entityID)
            changed = []
            if fresh_ids.empty?
              # D-103 INVARIANT: observer NIKDY nekomituje NETRANSPARENTNU operaciu.
              # Kazda jeho reakcia sa lepi na pouzivatelov krok (rovnako ako absorpcia
              # scale a presun ghostov) — inak by ostala ako samostatny VRCHOL undo
              # stacku a nastroj, ktory svoju operaciu este prepisuje (`*N` nasobenie
              # kopii, zmena VCB), by odundoval JU namiesto svojej. Vysledkom bola
              # prezivsia „zombie" kopia a dvojity dielec vo vystupoch.
              # Cena (vedome, vzor absorpcie na riadku ~320): ak sa oprava STAREJ
              # duplicity prilepi na nesuvisiaci krok, undo toho kroku ju vrati spat —
              # system sa zbiehá sam (dalsi tik ju opravi znova). Radsej rozbita
              # skupina undo krokov nez ticho zdvojeny dielec v cenovej ponuke.
              changed.concat(Array(CabinetBuilder.dedup_copies(mdl, transparent: true))) if defined?(CabinetBuilder)
              changed.concat(Array(BoardBuilder.dedup_copies(mdl, transparent: true))) if defined?(BoardBuilder)
            else
              changed.concat(Array(CabinetBuilder.dedup_copies(mdl, fresh_ids: fresh_ids))) if defined?(CabinetBuilder)
              changed.concat(Array(BoardBuilder.dedup_copies(mdl, fresh_ids: fresh_ids))) if defined?(BoardBuilder)
              stale = defined?(Ids) &&
                      (Ids.duplicate_cabinets(mdl) + Ids.duplicate_boards(mdl))
                      .any? { |i| i && i.valid? }
              # Follow-up bezpecny proti slucke: dalsi tick pride s prazdnym added
              # (fresh_ids prazdne) -> stale sa spracuju vetvou vyssie a schedule
              # sa uz nevola.
              # NASTROJE-1 (audit 4 BLOCKER): follow-up musi niest KONKRETNY
              # dokument. Holy `schedule` planoval len cas — dalsia iteracia by
              # nasla prazdne fronty a spracovala `@last_model`, teda mozno UPLNE
              # INY dokument (dva otvorene subory, macOS). Model ide do
              # `@requested` PRED `schedule`, aby bariera `flush_pending!` videla
              # frontu neprazdnu uz v tej istej iteracii.
              if stale
                @requested ||= {}
                @requested[mdl.object_id] = mdl
                schedule
              end
            end
            # D-103: po skutocnej zmene identity obnov Inspector — sync vyberu uz
            # dedup nespusta, takze bez tohto by karta drzala zdielane (povodne) ID
            # az do dalsieho kliknutia. Citanie, ziadny zasah do modelu.
            refresh_panel(mdl) unless changed.empty?
            # Kopie zachytene cez onElementAdded nemaju vlastny per-instancny EntityObserver
            # (kopia ho nededi). Po dedupe (novy cabinet_id + ghosty cez rebuild->sync_ghost)
            # im observer pripojime, aby ich buduci move/scale spustil ghost sync.
            # attach_all je idempotentne (iteruje len korpusy — dosky observer v b nemaju).
            attach_all(mdl) if fresh_copy
          end

          dirty.each_value do |inst|
            next unless inst && inst.valid?
            m = inst.model # fix #8: model per dirty instancia (nie Sketchup.active_model)
            board = Store.kind(inst) == 'board'
            if scaled?(inst.transformation)
              board ? absorb_board(inst) : absorb(inst) # scale -> rebuild (korpus aj sync ghostov)
            elsif board
              remember_transform(inst) # move/rotate dosky — ziadne ghosty
            else
              move_ghost_op(m, inst) # move/rotate korpusu -> len presun ghost skupin
              remember_transform(inst)
            end
          rescue StandardError => e
            if inst && inst.valid? && scaled?(inst.transformation)
              reject_scale(inst, e)
            else
              Engine.log_error(e, 'ScaleWatch.process_dirty')
            end
          end
          prune_targets(prune_requests, touched_models).each do |pm|
            # R-01 (Codex audit FIX 5): KAZDY ciel vlastny begin/rescue. Fronty su
            # uz vyprazdnene, takze vynimka nad jednym dokumentom (napr. zatvaranym)
            # by inak vzala aj vsetky ostatne poziadavky toho istoho tiku.
            begin
              prune_ghosts(pm)
              forget_dead_transforms(pm) # R-04: cache pusti entity, ktore uz nezijú
              # D-34 (audit B4b): po ustaleni erase VZDY resync panela — zmazanie
              # oznacenej skrinky nemusi vystrelit selection event a Inspector by
              # visel na mrtvych datach. push_selected pri prazdnom/neplatnom vybere
              # posle NX.clearSelected -> rezim vkladania + reset karty (audit B2).
              # Model je zachyteny z eventu PRED invalidaciou entity (fix #8);
              # refresh_panel ma multi-model guard (len aktivny dokument).
              refresh_panel(pm)
            rescue StandardError => e
              Engine.log_error(e, 'ScaleWatch.prune tick')
            end
          end
        end

        # Ciele upratovania po erase. Znamé dokumenty idu KAZDY zvlast; SENTINEL
        # `nil` (erase, ktoreho dokument sa uz nedal zistit) sa rozhodne fallbackom
        # a PRIDA sa k mnozine — nie az vtedy, ked je prazdna (Codex audit BLOCKER 3:
        # inak by kombinacia „znamy A + neznamy B" ticho zahodila B).
        # GH P2: cisty delete (bez predoslych change/add eventov) moze mat vsetky
        # zdroje nil — fallback konci na aktivnom modeli (Windows = jediny dokument;
        # refresh_panel aj prune maju vlastne multi-model guardy).
        def prune_targets(requests, touched_models)
          return [] if requests.nil? || requests.empty?
          targets = requests.reject { |k, _| k.nil? }.values.compact
          if requests.key?(nil)
            fallback = @last_model || touched_models.first || (safe { Sketchup.active_model })
            targets << fallback if fallback
          end
          targets.uniq
        end

        # Presun ghost zon za korpusom (bez rebuildu). TRANSPARENTNA operacia (fix #3): 4. param
        # transparent=true pripoji tento krok k predchadzajucej (user-ovej move) operacii, takze
        # 1x undo vrati korpus AJ ghosty naraz — nie zvlast.
        def move_ghost_op(model, inst)
          return unless defined?(Zones)
          model.start_operation('Noxun: presun zon', true, false, true)
          Zones.move_ghost(model, inst)
          model.commit_operation
        rescue StandardError => e
          model.abort_operation rescue nil
          Engine.log_error(e, 'ScaleWatch.move_ghost_op')
        end

        # Upratanie osirotenych ghostov po zmazani korpusu. TRANSPARENTNA operacia (fix #3):
        # pripoji sa k user-ovej delete operacii -> 1x undo vrati korpus aj ghosty konzistentne.
        def prune_ghosts(model)
          return unless defined?(Zones) && model
          model.start_operation('Noxun: uprac zony', true, false, true)
          Zones.prune_orphans(model)
          model.commit_operation
        rescue StandardError => e
          model.abort_operation rescue nil
          Engine.log_error(e, 'ScaleWatch.prune_ghosts')
        end

        # --- detekcia scale -------------------------------------------------
        # Scale = dlzky STLPCOV matice (to_a) delene w (a[15]) — NEZAVISLE od rotacie.
        # POZOR: tr.xaxis/yaxis/zaxis vracaju NORMALIZOVANY smer (dlzka vzdy 1), scale v nich
        # nie je — preto sa cita priamo z matice, inak by scale nikdy nebol detegovany.
        def scale_factors(tr)
          a = tr.to_a
          w = a[15]
          w = 1.0 if w.nil? || w.abs < 1e-9
          sx = Math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]) / w
          sy = Math.sqrt(a[4] * a[4] + a[5] * a[5] + a[6] * a[6]) / w
          sz = Math.sqrt(a[8] * a[8] + a[9] * a[9] + a[10] * a[10]) / w
          return nil if near_one?(sx) && near_one?(sy) && near_one?(sz)
          [sx, sy, sz]
        end

        def scaled?(tr)
          !scale_factors(tr).nil?
        end

        def near_one?(v)
          (v - 1.0).abs < SCALE_TOL
        end

        # --- absorpcia scale do configu ------------------------------------
        def absorb(inst)
          model = inst.model
          cfg = Store.config(inst)
          return unless cfg
          f = scale_factors(inst.transformation)
          return unless f
          sx, sy, sz = f # X=sirka, Y=hlbka, Z=vyska (lokalne osi korpusu)

          base_w = cfg['width'].to_f
          base_h = cfg['height'].to_f
          base_d = cfg['depth'].to_f
          cid = cfg['cabinet_id'] || Store.get(inst, 'cabinet_id')

          new_w = clamp_min('width',  (base_w * sx).round.to_f, cid)
          new_h = clamp_min('height', (base_h * sz).round.to_f, cid)
          new_d = clamp_min('depth',  (base_d * sy).round.to_f, cid)

          params = CabinetBuilder.config_to_params(cfg)
          params['width']  = new_w
          params['height'] = new_h
          params['depth']  = new_d

          clean = clean_transform(inst.transformation)
          # V0.3.4 undo fix (runner S1): TRANSPARENTNA operacia — absorpcia sa pripoji
          # k pouzivatelovmu Scale kroku. 1x undo vrati scale AJ absorpciu naraz (predtym
          # undo vratil len absorpciu, observer videl scaled transform a absorboval znova
          # — undo "bojoval" s pouzivatelom).
          # ZNAMY okrajovy race (Codex review PR #21): debounce bezi 0.2 s — ak pouzivatel
          # stihne MEDZITYM commitnut inu operaciu, absorpcia sa prilepi na nu (API nevie
          # nahliadnut do undo stacku). Dosledok pri undo tej operacie: vrati sa aj absorpcia,
          # observer scaled stav zdetekuje a znova absorbuje TRANSPARENTNE k povodnemu Scale
          # — system konverguje do spravneho zlucenia sam; obetou je redo historia daneho kroku.
          # Vedome akceptovane: okno 0.2 s, zriedkave; netransparentna alternativa = trvalo
          # rozbite undo po scale (povodny stav pred fixom).
          CabinetBuilder.rebuild(model, inst, params,
                                 transform: clean, op_name: 'Noxun: prepočet po zmene veľkosti',
                                 transparent: true)
          remember_transform(inst)
          refresh_panel(model) # V0.4.7e: karta uz neukazuje stare rozmery do reselect-u

          Engine.log("scale absorb #{cid}: #{base_w.round}x#{base_h.round}x#{base_d.round} -> " \
                     "#{new_w.round}x#{new_h.round}x#{new_d.round} (f=#{sx.round(3)},#{sy.round(3)},#{sz.round(3)})")
        end

        # Panel po absorpcii ukazoval STARE rozmery az do reselect-u (znama medzera
        # od V0.4.5) — obnovi sa standardnym sync tickom; bez otvoreneho panela no-op.
        # Multi-model guard (Codex GH #36): debounced absorpcia na POZADOVOM modeli
        # (macOS viac dokumentov) nesmie prepisat Inspector aktivneho dokumentu.
        # D-103 (Codex audit NOTE 8): VZDY `dedup: false` — refresh z observera je
        # cisté citanie a nesmie spustit dalsi zasah do modelu (ani nekonecny tik).
        def refresh_panel(model)
          return unless model == Sketchup.active_model
          Panel.push_selected(model, dedup: false) if defined?(Panel)
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.refresh_panel')
        end

        def clamp_min(key, val, cid)
          m = MIN[key]
          return val if m.nil? || val >= m
          Engine.log("scale absorb #{cid}: #{key} #{val.round} < min #{m.round} — clampujem na #{m.round}")
          m
        end

        # --- absorpcia scale DOSKY (V0.4.7d) --------------------------------
        # Lokalne osi dosky su vyrobna pravda: X=length, Y=width, Z=thickness.
        # Absorbuju sa LEN X/Y; hrubku RIADI katalogovy material — Z faktor sa
        # zahodi a rebuild vrati geometriu hrubky na config hodnotu (pouzivatel
        # dostane nemodalny status, ziadny messagebox z observera).
        # POZOR (Codex audit d): pri neuniformnom GLOBALNOM scale sikmo natocenej
        # dosky vznika shear — stlpce matice prestanu byt kolme a osi sa miesaju.
        # Taky transform sa NEabsorbuje (reject) — absorpcia by vyrobila nezmysel.
        def absorb_board(inst)
          model = inst.model
          cfg = Store.config(inst)
          return unless cfg
          tr = inst.transformation
          f = scale_factors(tr)
          return unless f
          raise 'Doska je skosena neuniformnym scale — zmena velkosti sa neda prevziat.' if sheared?(tr)
          sx, sy, sz = f
          bid = Store.get(inst, 'id')

          lim = BoardBuilder::LIMITS
          new_l = (cfg['length'].to_f * sx).round.to_f.clamp(lim[:length][0], lim[:length][1])
          new_w = (cfg['width'].to_f * sy).round.to_f.clamp(lim[:width][0], lim[:width][1])
          clamped = ((cfg['length'].to_f * sx).round.to_f != new_l) || ((cfg['width'].to_f * sy).round.to_f != new_w)

          clean = clean_transform(tr)
          # TRANSPARENTNA operacia — absorpcia sa pripoji k pouzivatelovmu Scale
          # kroku (1x undo vrati oboje; rovnaky vzor + debounce kompromis ako
          # korpusova absorb, viz komentar tam).
          BoardBuilder.rebuild(model, inst, { 'length' => new_l, 'width' => new_w },
                               transform: clean, op_name: 'NOXUN: Prepocet dosky po zmene velkosti',
                               transparent: true)
          remember_transform(inst)
          refresh_panel(model) # V0.4.7e: karta dosky sa obnovi hned po absorpcii

          if (sz - 1.0).abs >= SCALE_TOL
            notify_user("Hrúbku dosky #{bid} určuje materiál — ostáva #{cfg['thickness'].to_f.round(1)} mm.")
          elsif clamped
            notify_user("Rozmer dosky #{bid} bol orezaný na povolený rozsah.")
          end
          Engine.log("scale absorb #{bid}: #{cfg['length'].to_f.round}x#{cfg['width'].to_f.round} -> " \
                     "#{new_l.round}x#{new_w.round} (f=#{sx.round(3)},#{sy.round(3)},#{sz.round(3)})")
        end

        # Shear detekcia: ocistene (normalizovane) osi musia byt navzajom kolme.
        def sheared?(tr, tol = 0.001)
          x = tr.xaxis.normalize
          y = tr.yaxis.normalize
          z = tr.zaxis.normalize
          x.dot(y).abs > tol || x.dot(z).abs > tol || y.dot(z).abs > tol
        end

        # Nemodalne oznamenie z observera: SketchUp status bar (vzdy) + panel status
        # (ak je otvoreny). Modal z asynchronneho observera je zle UX.
        def notify_user(msg)
          Sketchup.status_text = msg
          Panel.set_status(msg) if defined?(Panel)
        rescue StandardError
          nil
        end

        # Cisty transform: povodny origin + rotacia, BEZ scale (normalizovane osi).
        def clean_transform(tr)
          Geom::Transformation.axes(tr.origin, tr.xaxis.normalize, tr.yaxis.normalize, tr.zaxis.normalize)
        end

        # Ak validacia rebuildu odmietne Scale, vratime presne poslednu stabilnu
        # polohu/rotaciu/velkost. Transparentna operacia sa pripoji k pouzivatelovmu
        # Scale kroku, takze model ani vyrobne data nezostanu v rozpornom stave.
        # V0.4.7d: typove rozvetvenie \u2014 doska nema ghosty a identita je v 'id';
        # doskova hlaska je NEMODALNA (status), korpusovy messagebox ostava.
        def reject_scale(inst, error)
          model = inst.model
          board = Store.kind(inst) == 'board'
          restore = stable_transform(inst) || clean_transform(inst.transformation)
          guard do
            model.start_operation('Noxun: zrusena neplatna zmena velkosti', true, false, true)
            begin
              inst.transformation = restore
              Zones.move_ghost(model, inst) if !board && defined?(Zones)
              model.commit_operation
            rescue StandardError => restore_error
              model.abort_operation rescue nil
              Engine.log_error(restore_error, 'ScaleWatch.reject_scale restore')
              return false
            end
          end
          remember_transform(inst)
          Engine.log_error(error, 'ScaleWatch.scale rejected')
          if board
            notify_user("Zmena ve\u013ekosti dosky #{Store.get(inst, 'id')} bola zru\u0161en\u00e1: #{error.message}")
          else
            cid = Store.get(inst, 'cabinet_id')
            UI.messagebox("Zmena ve\u013ekosti skrinky #{cid} bola zru\u0161en\u00e1, preto\u017ee by vytvorila neplatn\u00fa kon\u0161trukciu.\n\n#{error.message}")
          end
          true
        rescue StandardError => notify_error
          Engine.log_error(notify_error, 'ScaleWatch.reject_scale notify')
          false
        end

        # NASTROJE-1 (audit 2 FIX 2 + audit 3 FIX 2): RIGIDITA SA VYNUCUJE
        # PRIAMO NA HRANICI CACHE. Predtym sa ukladalo cokolvek, co volajuci
        # podal — vetvy Move/Rotate aj verejny `remember_transform` tak vedeli
        # zapamatat SIKMU (shear) maticu: jej osi maju dlzku 1, takze `scaled?`
        # ju nezachyti. Odmietnuty scale by potom cez `reject_scale` „obnovil"
        # korpus do skoseneho stavu, ktory zodpoveda ziadnej platnej geometrii.
        # Cache preto drzi VYHRADNE rigidne (rotacia + posun) transformacie.
        def remember_transform(inst)
          return unless inst && inst.valid?
          tr = inst.transformation
          return unless rigid?(tr)

          @stable_transforms ||= {}
          @stable_transforms[transform_key(inst)] = tr.to_a.dup
        end

        # Autorita rigidity je `CabinetBuilder.rigid_matrix?` (jednotkove a kolme
        # osi, determinant +1, nulova perspektiva). `scale_observer.rb` sa nacita
        # PRED builderom, preto fallback pre pripad, ze by cache niekto plnil
        # este pred jeho nacitanim — ten kryje aspon mierku a skos.
        def rigid?(tr)
          return false unless tr && tr.respond_to?(:to_a)

          return CabinetBuilder.rigid_matrix?(Array(tr.to_a)) if defined?(CabinetBuilder)

          !scaled?(tr) && !sheared?(tr)
        rescue StandardError
          false
        end

        def stable_transform(inst)
          values = @stable_transforms && @stable_transforms[transform_key(inst)]
          values && Geom::Transformation.new(values)
        end

        def transform_key(inst)
          [model_key(inst.model), inst.entityID]
        end

        # Identita dokumentu pre cache stabilnych transformacii.
        # POZOR — `guid` sa tu pouzit NEDA (GH review #261, P1): SketchUp ho meni
        # PRI KAZDOM ULOZENI dokumentu (zdokumentovane a testom podchytene
        # v `tests/pure/test_st1a_studio.rb` — preto je kluc nazvu zakazky CESTA).
        # Na guid kluci by Ctrl+S zneplatnil vsetky zapamatane polohy naraz:
        # hned nasledujuci odmietnuty Scale by sa vracal len cez `clean_transform`
        # (pri scale okolo pivotu posunuty origin) a `forget_dead_transforms` by
        # stare zaznamy uz ani nenasiel. `object_id` je v ramci behu stabilny.
        # Recyklacia `object_id` po zatvoreni dokumentu je osetrena inde —
        # `forget_detached_models` pri zmene dokumentu cache vyprazdni (Windows/SDI);
        # macOS zvysok je priznany v registri (R-36).
        def model_key(model)
          model && model.object_id
        end

        # `guid` sa tu pouziva VYHRADNE ako DETEKTOR ZMENY dokumentu (nie ako kluc):
        # `model_switched` sa pri ulozeni nespusta, takze zmena guid v tejto ceste
        # znamena naozaj iny dokument.
        def doc_guid(model)
          return nil unless model
          model.respond_to?(:guid) ? model.guid.to_s : nil
        rescue StandardError
          nil
        end

        # R-04, cesta 1 — ERASE TICK: z cache vypadnu zaznamy entit, ktore v TOMTO
        # dokumente uz nezijú. Cudzich dokumentov sa nedotkne (ich entity su zive).
        # Codex audit FIX 7: JEDEN prechod definiciami pre oba kindy (nie 2x
        # `Ids.each_of_kind`) a rovno sa vracia, ked cache pre tento dokument
        # ziadny kluc nema — vtedy sa model vobec neprechadza.
        def forget_dead_transforms(model)
          return unless model && @stable_transforms && !@stable_transforms.empty?
          mid = model_key(model)
          mine = @stable_transforms.keys.select { |k| k.is_a?(Array) && k[0] == mid }
          return if mine.empty?
          live = {}
          model.definitions.each do |dfn|
            next unless dfn.valid?
            next if dfn.image? || dfn.group?
            dfn.instances.each do |inst|
              live[inst.entityID] = true if inst.valid? && DEDUP_KINDS.include?(Store.kind(inst).to_s)
            end
          end
          mine.each { |k| @stable_transforms.delete(k) unless live[k[1]] }
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.forget_dead_transforms')
        end

        # R-04, cesta 2 — ZANIK DOKUMENTU. Spusta sa VYHRADNE na Windows (SDI):
        # tam File > New / Open nahradi jediny dokument procesu, takze zaznamy toho
        # predosleho uz nikto nikdy nepouzije (jeho entity su neplatne).
        # Na macOS sa NECISTI (Codex audit BLOCKER 1): tam dokument A po prepnuti
        # ZIJE DALEJ a moze mat rozbehnuty debounce — zmazanie jeho stabilneho
        # transformu by odmietnutemu scale vzalo presnu polohu (`clean_transform`
        # pri scale okolo pivotu vrati posunuty origin). Zvysok tam upratuje
        # erase tick vyssie; priznane v registri (R-36).
        #
        # Rozhoduje sa podla GUID, nie podla `object_id` (GH review #261, P1
        # a Codex audit FIX 6): keby sa `object_id` zatvoreneho dokumentu
        # recykloval na novy dokument, porovnanie kluca by stare zaznamy
        # PONECHALO a skrinka s rovnakym `entityID` by dostala cudziu polohu.
        # Zmena GUID je tu spolahliva — `model_switched` sa pri ULOZENI nespusta,
        # takze iny guid v tejto ceste znamena naozaj iny dokument. A ked sa
        # dokument zmenil, ide prec CELA cache: zaznamy noveho dokumentu este
        # neexistuju (naplni ich `attach_all` hned za tymto volanim).
        #
        # VEDOMA HRANICA (1d/R-02b, review v2 P3-3): guid je OBSAH .skp SUBORU,
        # takze KOPIA zakazky (a re-open toho isteho suboru) nesie TEN ISTY guid —
        # nad recyklovanym `Model` objektom sa cache vtedy NEVYPRAZDNI. Necha sa
        # to tak (rozhodnutie R-04): stavka je NIZKA. Nejde o identitu ani o zapis
        # — zastarany zaznam znamena nanajvys menej presny navrat po ODMIETNUTOM
        # Scale, a `forget_dead_transforms` mrtve entity aj tak vyhadzuje. Identita
        # dokumentu (`DocKey`) a most nazvu zakazky, kde by taka diera znamenala
        # zapis do cudzej zakazky, na guid NESTOJA — ich cisti tickom ohraniceny
        # `Engine.on_document_replaced`.
        def forget_detached_models(model)
          return unless model
          return unless sdi?
          gid = doc_guid(model)
          prev = @active_doc_guid
          @active_doc_guid = gid
          # POZOR na `prev.nil?` (GH review #261 kolo 2, P2): PRVE File > New/Open
          # po starte pluginu by s ranou vetvou „nevieme, s cim porovnavat" nechalo
          # v cache cely prave zaniknuty dokument. `install` preto guid seeduje —
          # a aj tak sa tu pri neznamom `prev` radsej CISTI: cache noveho dokumentu
          # naplni `attach_all` hned za tymto volanim, takze zahodenie nic nestoji.
          return if prev == gid
          @stable_transforms = {}
        rescue StandardError => e
          Engine.log_error(e, 'ScaleWatch.forget_detached_models')
        end

        # Windows = jeden dokument na proces (SDI). `Sketchup.platform` je predpisany
        # sposob detekcie (docs/SKETCHUP_PRAVIDLA.md), nie `RUBY_PLATFORM`.
        def sdi?
          Sketchup.respond_to?(:platform) && Sketchup.platform == :platform_win
        rescue StandardError
          false
        end

        def safe
          yield
        rescue StandardError
          nil
        end
      end

      # EntityObserver na korpus instancii — onChangeEntity pri kazdej zmene entity (vratane Scale).
      class CabinetEntityObserver < Sketchup::EntityObserver
        def onChangeEntity(entity)
          ScaleWatch.notify_change(entity)
        end

        # Zmazanie korpusu -> upraceme jeho ghost zony (osirotene top-level skupiny).
        # fix #8: nesieme model z eventu. Po erase je entity uz neplatna (entity.model by hodilo),
        # preto len ak je este valid?; inak notify_erase padne na @last_model (posledny znamy model).
        def onEraseEntity(entity)
          m = (entity.valid? ? entity.model : nil) rescue nil
          ScaleWatch.notify_erase(m)
        end
      end

      # EntitiesObserver na model.entities — zachyti PRIDANIE korpusu do modelu (hlavne kopie).
      # Nova instancia z kopie (Ctrl+C/V, Move+Ctrl) nededi per-instancny EntityObserver, takze
      # bez tohto by jej presun nespustil ghost sync a zony by ostali na mieste originalu.
      # onElementAdded je davkovany na commit operacie -> pri vlastnom builde (guardnutom) vidi
      # @rebuilding=true a ignoruje ho (ziadne dvojite spracovanie vlastnych vkladov).
      class CabinetEntitiesObserver < Sketchup::EntitiesObserver
        def onElementAdded(_entities, entity)
          ScaleWatch.notify_added(entity)
        end

        # FALLBACK pre zmeny korpusov (move/rotate/scale) NEZAVISLY od per-instancneho
        # EntityObservera — ten sa na kopiu nemusi stihnut/podarit attachnut (Ctrl+V, undo/redo,
        # reload). notify_change si sam odfiltruje ne-korpusy (kind != cabinet) a ma @rebuilding
        # guard, takze vlastne rebuildy/ghost presuny slucku nespustia.
        def onElementModified(_entities, entity)
          ScaleWatch.notify_change(entity)
        end
      end

      # AppObserver — re-attach entity/entities observerov na korpusy pri zmene modelu.
      # DOLEZITE: okrem per-instancnych observerov (attach_all) treba pripojit aj entities
      # observer (attach_entities) — bez neho nefunguju kopie ani fallback zmien.
      # Navyse notifikuje moduly viazane na model — sekcie Studia sa nad novym
      # aktivnym modelom nacitaju nanovo (Codex review PR #26, P1).
      class EngineAppObserver < Sketchup::AppObserver
        # 1d/R-02b (review #267 P1-1 + delta P2-GLM): pamate viazane na OBJEKT
        # modelu sa pri vymene dokumentu upratuju UDALOSTOU, lebo Windows smie
        # pri File > Open RECYKLOVAT ten isty `Model` objekt (auditovane pri
        # GHOST vkladani, review #268 P2-2) — inak by novy dokument zdedil
        # identitu (DocKey) aj nazov zakazky (SESSION_KEY_BRIDGE) stareho.
        # Jeden zoznam cleanupov je v `Engine.on_document_replaced`; robi to
        # aj `PanelAppObserver`: tento observer je nainstalovany VZDY (aj bez
        # Inspectora, teda kryje Studio a dialogy), ten druhy zas garantuje
        # poradie voci pushu do panela. Ze upratuju DVAJA, nevadi — `invalidate`
        # ma epochu udalosti, takze jeden event vyrobi najviac jeden token
        # (bez nej by Studio dostalo iny token nez panel; review delty P2-N1).
        # Musi bezat PRED notifikaciou okien nizsie, aby uz hlasili CERSTVY stav.
        def onNewModel(model)
          Engine.on_document_replaced(model)
          model_switched(model)
        end

        def onOpenModel(model)
          Engine.on_document_replaced(model)
          model_switched(model)
        end

        # BEZ upratovania — macOS prepnutie medzi UZ otvorenymi dokumentmi;
        # kazdy ma vlastny objekt a svoju identitu aj nazov si drzi.
        def onActivateModel(model)
          model_switched(model)
        end

        private

        def model_switched(model)
          # R-04: NAJPRV pustit zaznamy zaniknuteho dokumentu (Windows/SDI), az potom
          # attach_all — ten cache pre novy dokument rovno naplni (`remember_transform`).
          ScaleWatch.forget_detached_models(model)
          ScaleWatch.attach_all(model)
          ScaleWatch.attach_entities(model)
          # D-104: zvyraznenie hran patri modelu, v ktorom sa zaplo — pri prepnuti
          # dokumentu sa vypne PRED notifikaciou okien (aby uz hlasili cerstvy stav).
          EdgeCheck.on_model_changed(model) if defined?(EdgeCheck)
          # K2/D-87: to iste plati pre kresbu smeru dekoru — overlay patri
          # modelu, v ktorom sa zapol (zapamatany prepinac ostava, je to
          # nastavenie pocitaca).
          GrainCheck.on_model_changed(model) if defined?(GrainCheck)
          # KOV-A2b: a to iste pre symboly smeru otvarania — overlay patri
          # modelu, v ktorom sa zapol.
          DirectionCheck.on_model_changed(model) if defined?(DirectionCheck)
          # ŠT-3b-1: vetva `RulesDialog.on_model_changed` tu ZANIKLA spolu
          # s oknom — modul nema ZIADNY asynchronny beh (na rozdiel od
          # katalogu kovania nizsie), takze po prepnuti dokumentu netreba nic
          # rusit; sekciu `rules` obsluzi PLNY push Studia z toho isteho
          # broadcastu (`rules_payload` dostane PODANY model).
          MaterialsDialog.on_model_changed(model) if defined?(MaterialsDialog)
          # ŠT-1c PR B3: okno Vyroba tu ZANIKLO — jedine okno s vlastnym
          # generacnym tokenom nad cislami zakazky je Studio.
          # ST-1a: okno Studio ma VLASTNY generacny token — bez tohto riadku by
          # po prepnuti dokumentu drzalo cisla starej zakazky a jeho klik by
          # mieril do modelu, ktory uz nie je aktivny.
          StudioDialog.on_model_changed(model) if defined?(StudioDialog)
          # ŠT-3a-2: okno Katalog kovania zaniklo, ale vetva OSTAVA (precedens
          # `MaterialsDialog` vyssie): telo uz nerobi refresh UI (ten robi
          # Studio plnym pushom vyssie), ale MUSI zneplatnit beziaci serverovy
          # beh sekcie — inak by vysledok stiahnutia z Demosu dobehol do
          # NOVEHO dokumentu s datami stareho.
          HardwareCatalogDialog.on_model_changed(model) if defined?(HardwareCatalogDialog)
        end
      end
    end
  end
end
