# frozen_string_literal: true
# Noxun Engine - Panel: riadok „Spotrebic" (S1-B2).
# Cast modulu Panel (reopen) - zdiela ivary cez class << self. Nacitava
# panel.rb; ziadna logika mimo modulu.
#
# JEDINA akcia: `set_appliance_owner` — priradenie alebo odpojenie spotrebica
# z Inspectora (skrinka, slot, doska). Zapis NEROBI tento subor: deleguje na
# `ApplianceBinding.apply!`, ktory je JEDINY transakcny vstup vazby (polozka
# rozpoctu + `appliance_refs[]` vlastnika + prestavba = JEDNA operacia, JEDEN
# krok Spat). Tu sa rieši len to, co panel vie a jadro nie: KTORA entita je
# prave oznacena.
#
# CIEL VAZBY SKLADA SERVER Z VYBERU, nie z payloadu. Klient posiela LEN
# `item_id` (co priradit) a `cabinet_id`/`board_id` (nad cim bol riadok
# vykresleny). Druh, ID aj `persistent_id` vlastnika sa citaju z OZNACENEJ
# entity — stary DOM tak nemoze poslat cudziu skrinku a recyklovane ID nema
# ako trafit iny kus.
module Noxun
  module Engine
    module Panel
      # Hlasky (jeden textovy zdroj). V TELE MODULU, nie v `class << self` —
      # inak by zili na singleton triede a testy ani iné casti panela by sa na
      # ne nedostali menom `Panel::APPL_MSG_*` (vzor `PARAM_KEYS`).
      APPL_MSG_NO_TARGET = 'Najprv označ skrinku, slot alebo dosku.'
      APPL_MSG_STALE = 'Výber sa medzitým zmenil — panel sa obnovil, skús znova.'
      APPL_MSG_NO_ITEM = 'Vyber spotrebič zo zoznamu.'
      # S1-C: ocakavania (`appliance_expects[]`).
      APPL_MSG_BUSY = 'Model ešte dokončuje predchádzajúcu zmenu — skús to o chvíľu znova.'
      APPL_MSG_DETACH = 'Kus má odpojený dielec — vráť ho späť a skús znova.'
      APPL_MSG_NEWER = 'Kus je z novšej verzie Noxun — zápis by jeho nastavenia stratil.'
      APPL_MSG_AMBIG = 'Dva kusy s tým istým ID — prestav skrinky a skús znova.'
      APPL_MSG_EXPECTS_FAILED = 'Očakávanie sa nepodarilo uložiť — skús znova.'
      APPL_MSG_EXPECTS_SAME = 'Očakávanie sa nezmenilo.'
      APPL_EXPECTS_OP = 'NOXUN: Očakávaný spotrebič'

      class << self
        def handle_set_appliance_owner(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Spotrebič sa nezmenil') # R-02

          target, err = appliance_target(model, data)
          return set_status(err, true) if err

          item_id = data['item_id'].to_s
          unbind = data['unbind'] == true
          return set_status(APPL_MSG_NO_ITEM, true) if item_id.empty?

          appliance_apply(model, data, target, item_id, unbind)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.handle_set_appliance_owner')
          set_status("Spotrebič sa nepodarilo uložiť: #{e.message}", true)
        end

        # OZNACENA entita ako vlastnik: `[{ 'kind', 'id', 'pid' }, nil]` alebo
        # `[nil, hlaska]`. Skrinka ma v Inspectore prednost pred doskou
        # (rovnake poradie ako `push_selected`), takze sa rozhoduje rovnako ako
        # to, co pouzivatel v okne vidi.
        def appliance_target(model, data)
          cab = find_cabinet(model)
          return appliance_cabinet_target(cab, data) if cab

          board = find_board(model)
          return [nil, APPL_MSG_NO_TARGET] if board.nil?

          echo = data['board_id'].to_s
          return [nil, APPL_MSG_STALE] if !echo.empty? && echo != Store.get(board, 'id').to_s

          [{ 'kind' => ApplianceBinding::KIND_BOARD, 'id' => Store.get(board, 'id').to_s,
             'pid' => board.persistent_id }, nil]
        end

        def appliance_cabinet_target(cab, data)
          cid = Store.get(cab, 'cabinet_id').to_s
          echo = data['cabinet_id'].to_s
          # GH #127 P2: payload nesie identitu RENDROVANEJ skrinky — zmena
          # vyberu pred obsluhou callbacku nesmie prepisat inu skrinku.
          return [nil, APPL_MSG_STALE] if !echo.empty? && echo != cid

          cfg = Store.config(cab) || {}
          slot = cfg['type'].to_s == 'dishwasher'
          [{ 'kind' => slot ? ApplianceBinding::KIND_SLOT : ApplianceBinding::KIND_CABINET,
             'id' => cid, 'pid' => cab.persistent_id }, nil]
        end

        # `unbind` = odpojenie (vlastnik -> „len zakazka"), inak presun NA TENTO
        # kus. Obe su operacie jadra a obe su JEDEN krok Spat.
        def appliance_apply(model, data, target, item_id, unbind)
          res = ApplianceBinding.apply!(model, model_guid: data['model_guid'],
                                               op: (unbind ? 'unbind' : 'move'),
                                               item_id: item_id,
                                               owner: (unbind ? nil : target))
          unless res[:ok]
            push_selected(model)
            return set_status(appliance_error(res), true)
          end

          # Karta musi prist CERSTVA (zmenil sa riadok, pri skrinke a slote aj
          # geometria). Otvorene Studio sa o zmene dozvie svojou bezne cestou —
          # transakcny observer zdvihne „Obnoviť" (`on_model_txn`), presne ako
          # pri kazdom inom zapise panela; vlastny push do cudzieho okna by bol
          # druhy kanal k tym istym cislam.
          push_selected(model)
          set_status(appliance_status(res, target, unbind))
        end

        def appliance_error(res)
          msg = Array(res[:errors]).reject { |e| e.to_s.strip.empty? }.first.to_s
          msg.empty? ? 'Spotrebič sa nepodarilo priradiť.' : msg
        end

        def appliance_status(res, target, unbind)
          name = res[:item].is_a?(Hash) ? Bom.appliance_label(res[:item]).to_s : ''
          what = name.empty? ? 'Spotrebič' : "Spotrebič „#{name}“"
          return "#{what} odpojený — ostáva v zákazke." if unbind

          "#{what} priradený: #{target['id']}."
        end

        # === S1-C: OCAKAVANY SPOTREBIC (`appliance_expects[]`) ===============
        #
        # Zapis CONFIGU BEZ PRESTAVBY (ocakavanie nic nekresli) vo VLASTNEJ
        # operacii = JEDEN krok Spat. NEJDE cez `ApplianceBinding.apply!`:
        # ten je transakcnym vstupom VAZBY (polozka rozpoctu + refs + prestavba)
        # a tu sa ziadna polozka zakazky nemeni.
        #
        # PORADIE GUARDOV je zavazne (vzor `ApplianceBinding.plan_for` a D-100):
        #   1. identita DOKUMENTU (R-02),
        #   2. BARIERA OBSERVERA — dedup kopii a presun ghostov moze PRAVE TERAZ
        #      menit `cabinet_id`; bez pokoja by sme zapisovali do configu, ktory
        #      o par milisekund neplati, a transparentna reakcia observera by sa
        #      navyse prilepila na nasu operaciu,
        #   3. CIEL sa cita AZ PO bariere (cerstvy vyber, cerstvy config)
        #      a overuje sa cely: druh + ID + PID, jednoznacnost, nie odpojeny,
        #      nie z novsej verzie,
        #   4. STRIKTNA validacia vstupu proti matici,
        #   5. „viazana kategoria sa odstranit neda",
        #   6. NEZMENENY vysledok = ZIADNA operacia (ziadny prazdny krok Spat).
        # Az potom sa otvara operacia.
        def handle_set_appliance_expects(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Očakávanie sa nezmenilo') # R-02
          return set_status(APPL_MSG_BUSY, true) unless ApplianceBinding.observer_idle?(model)

          inst, target, err = appliance_expects_target(model, data)
          return set_status(err, true) if err

          list, verr = ApplianceBinding.validate_expects(data['expects'], target['kind'])
          return set_status("Očakávanie sa neuložilo — #{verr}", true) if verr

          lock = appliance_expects_locked(model, inst, list)
          return set_status(lock, true) if lock

          appliance_expects_write(model, inst, target, Store.config(inst) || {}, list)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.handle_set_appliance_expects')
          set_status("Očakávanie sa nepodarilo uložiť: #{e.message}", true)
        end

        # OZNACENA entita ako ciel zapisu -> `[instancia, {kind,id,pid}, nil]`
        # alebo `[nil, nil, hlaska]`. Skrinka ma prednost pred doskou (rovnake
        # poradie ako `push_selected`), takze sa rozhoduje rovnako ako to, co
        # pouzivatel v okne vidi.
        #
        # ECHO IDENTITY SA TU NETOLERUJE PRAZDNE (na rozdiel od
        # `set_appliance_owner`): riadok ocakavani sa kresli VZDY aj s `pid`,
        # takze jeho absencia je presne ten stary DOM, proti ktoremu guard stoji.
        def appliance_expects_target(model, data)
          cab = find_cabinet(model)
          return appliance_expects_cabinet(model, cab, data) if cab

          board = find_board(model)
          return [nil, nil, APPL_MSG_NO_TARGET] if board.nil?

          appliance_expects_entity(model, board, ApplianceBinding::KIND_BOARD,
                                   Store.get(board, 'id').to_s, data['board_id'], data)
        end

        def appliance_expects_cabinet(model, cab, data)
          cfg = Store.config(cab) || {}
          kind = cfg['type'].to_s == 'dishwasher' ? ApplianceBinding::KIND_SLOT
                                                  : ApplianceBinding::KIND_CABINET
          appliance_expects_entity(model, cab, kind, Store.get(cab, 'cabinet_id').to_s,
                                   data['cabinet_id'], data)
        end

        def appliance_expects_entity(model, inst, kind, id, echo, data)
          return [nil, nil, APPL_MSG_STALE] if id.empty? || echo.to_s != id
          return [nil, nil, APPL_MSG_STALE] unless appliance_pid_matches?(inst, data['pid'])
          # ID sa recykluju (`Ids.next_id`), takze dva zive kusy s tym istym
          # cislom znamenaju, ze sa neda povedat, komu ocakavanie patri.
          return [nil, nil, APPL_MSG_AMBIG] if ApplianceBinding.instances_of(model, kind, id).length > 1
          if kind != ApplianceBinding::KIND_BOARD &&
             Ids.top_level_scan(model)['detached'][id].to_i.positive?
            return [nil, nil, APPL_MSG_DETACH]
          end

          cfg = Store.config(inst)
          newer = kind == ApplianceBinding::KIND_BOARD ? BoardBuilder.newer_config?(cfg)
                                                       : CabinetBuilder.newer_config?(cfg)
          return [nil, nil, APPL_MSG_NEWER] if newer

          [inst, { 'kind' => kind, 'id' => id, 'pid' => inst.persistent_id }, nil]
        end

        # PID z payloadu musi sediet s instanciou (Astra C6). Chybajuci alebo
        # necitatelny udaj = zastaraly DOM, nie „tolerovat".
        def appliance_pid_matches?(inst, raw)
          pid = raw.is_a?(Numeric) ? raw.to_i : (raw.to_s.strip.match?(/\A\d+\z/) ? raw.to_s.to_i : 0)
          pid.positive? && pid == inst.persistent_id.to_i
        end

        # „Viazanu kategoriu odstranit nedas" — dokaz vazby je TEN ISTY
        # obojsmerny dokaz ako v zbere (`ApplianceBinding.bound_categories`),
        # nie samotna `category` v refs. Inak by osirely zaznam po zmazanej
        # polozke navzdy zamkol ocakavanie, ktore uz nikto neplni.
        # -> hlaska, alebo nil
        def appliance_expects_locked(model, inst, list)
          entry = ApplianceBinding.owner_entry_for(inst)
          bound = ApplianceBinding.bound_categories(entry, appliance_items(model))
          gone = bound.reject { |c| list.include?(c) }
          return nil if gone.empty?

          what = gone.map { |c| ApplianceCatalog.category_label_acc(c) }.join(', ')
          "Tento kus má priradenú #{what} — najprv spotrebič odpoj, potom očakávanie zruš."
        end

        # Zapis. `[]` = kluc z configu ZMIZNE (legacy kus nikdy nedostane
        # prazdne pole, ktore by vyzeralo ako „uz sme to riesili").
        def appliance_expects_write(model, inst, target, cfg, list)
          current = Array(cfg['appliance_expects']).map(&:to_s)
          if current == list
            push_selected(model, dedup: false) # UI resync, model sa nedotkne
            return set_status(APPL_MSG_EXPECTS_SAME)
          end

          value = list.empty? ? nil : list
          begin
            CabinetBuilder.guarded do
              model.start_operation(APPL_EXPECTS_OP, true)
              begin
                appliance_expects_store!(inst, target['kind'], value)
                model.commit_operation
              rescue StandardError => e
                CabinetBuilder.abort_safely(model)
                raise e
              end
            end
          rescue StandardError => e
            Engine.log_error(e, 'Panel.appliance_expects_write')
            push_selected(model, dedup: false)
            return set_status(APPL_MSG_EXPECTS_FAILED, true)
          end

          # Astra C14: zmenili sa DATA KONTROLY (ORANGE „spotrebič nevybraný"),
          # takze cerstve cisla musia dostat OBAJA odberatelia — panel aj
          # otvorene Studio so ZDVIHOM generacie. Bez toho by nalez pribudol
          # az pri najblizsom inom zapise.
          push_selected(model, dedup: false)
          StudioDialog.refresh_if_open(bump: true) if defined?(StudioDialog)
          set_status(appliance_expects_status(target, list))
        end

        def appliance_expects_store!(inst, kind, value)
          keys = { 'appliance_expects' => value }
          if kind == ApplianceBinding::KIND_BOARD
            BoardBuilder.write_config_keys!(inst, keys)
          else
            CabinetBuilder.write_config_keys!(inst, keys)
          end
        end

        def appliance_expects_status(target, list)
          who = target['id'].to_s
          return "#{who} — očakávanie spotrebiča zrušené. Jeden krok Späť to vráti." if list.empty?

          labels = list.map { |c| ApplianceCatalog.category_label_acc(c) }
          "#{who} očakáva #{labels.join(', ')}. Jeden krok Späť to vráti."
        end
      end
    end
  end
end
