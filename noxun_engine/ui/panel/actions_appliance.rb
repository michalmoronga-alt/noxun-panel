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
      class << self
        # Hlasky (jeden textovy zdroj).
        APPL_MSG_NO_TARGET = 'Najprv označ skrinku, slot alebo dosku.'
        APPL_MSG_STALE = 'Výber sa medzitým zmenil — panel sa obnovil, skús znova.'
        APPL_MSG_NO_ITEM = 'Vyber spotrebič zo zoznamu.'

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
      end
    end
  end
end
