# frozen_string_literal: true
# Noxun Engine - Panel: samostatna doska (V0.4.7c) — vlozenie + editacia karty.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, suspend guard) cez class << self.
#
# GUARD proti oneskorenym zapisom (Codex audit c, blocker A): kazdy edit callback
# nesie echo board_id z karty. Zapis prejde LEN ked (1) v Inspectore nevyhrala
# skrinka (find_cabinet nil), (2) vo vybere JE doska a (3) jej Store id sedi
# s echom. Inak sa zapis TICHO zahodi (len log) — pouzivatel uz medzitym robi
# nieco ine, chybova hlaska by matla.
module Noxun
  module Engine
    module Panel
      # Whitelist poli editovatelnych cez set_board_fields (material ma vlastny
      # callback; edges vlastny s read-modify-write).
      BOARD_FIELD_KEYS = %w[name length width quantity grain_direction].freeze

      class << self
        # Vlozenie novej dosky z vkladacej karty. Material doplni BoardBuilder
        # z projektoveho defaultu, ak vo formulari chyba.
        def handle_insert_board(payload)
          model = Sketchup.active_model
          data = parse(payload)
          params = {}
          %w[name length width material_id grain_direction].each do |k|
            v = data[k]
            params[k] = v unless v.nil? || v.to_s.strip.empty?
          end
          inst = BoardBuilder.build(model, params)
          select_only(model, inst)
          set_status("Doska #{Store.get(inst, 'id')} vložená.")
          push_selected(model)
        end

        # Hromadny zapis obycajnych poli karty (name/length/width/quantity/grain).
        # JS akumuluje zmeny v jednom debounce a posiela snapshot {board_id, fields}.
        def handle_set_board_fields(payload)
          data = parse(payload)
          model, board = guarded_board(data)
          return unless board
          fields = data['fields'].is_a?(Hash) ? data['fields'] : {}
          params = {}
          BOARD_FIELD_KEYS.each do |k|
            params[k] = fields[k] if fields.key?(k)
          end
          return if params.empty?
          apply_board(model, board, params, 'Doska upravená.')
        end

        # Zmena materialu — hrubka nasleduje katalog (BoardBuilder.normalize).
        def handle_set_board_material(payload)
          data = parse(payload)
          model, board = guarded_board(data)
          return unless board
          mat = data['material_id'].to_s.strip
          return set_status('Doska potrebuje konkrétny materiál.', true) if mat.empty?
          apply_board(model, board, { 'material_id' => mat }, 'Materiál dosky nastavený.')
        end

        # ABS hrana dosky — server-side read-modify-write (Codex audit c, D):
        # payload nesie LEN jednu hranu; Ruby nacita aktualne edges z configu,
        # zmeni jeden kluc a do rebuildu posle kompletnu 4-klucovu mapu
        # (key?-preserve kontrakt BoardBuilder.norm_edges).
        def handle_set_board_edge(payload)
          data = parse(payload)
          model, board = guarded_board(data)
          return unless board
          code = data['edge'].to_s
          return set_status('Chyba identifikácie hrany.', true) unless %w[L1 L2 W1 W2].include?(code)
          cfg = Store.config(board) || {}
          edges = cfg['edges'].is_a?(Hash) ? cfg['edges'].dup : { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
          edges[code] = present_str(data['abs_id']) # nil = bez ABS
          label = edges[code] ? 'nastavená' : 'bez ABS'
          apply_board(model, board, { 'edges' => edges }, "Hrana #{code} — #{label}.")
        end

        # --- pomocne --------------------------------------------------------

        # Rebuild + resync panela. Vyber sa nemeni (rebuild drzi tu istu instanciu);
        # suspend chrani pred medzi-tickami selection observera pocas operacie.
        def apply_board(model, board, params, msg)
          suspend_selection_sync do
            BoardBuilder.rebuild(model, board, params)
          end
          set_status(msg)
          push_selected(model)
        end

        # Guard identity (viz hlavicka). Vracia [model, board] alebo [nil, nil].
        def guarded_board(data)
          model = Sketchup.active_model
          unless find_cabinet(model).nil?
            Engine.log('board edit zahodeny — v Inspectore vyhrala skrinka')
            return [nil, nil]
          end
          board = find_board(model)
          if board.nil?
            Engine.log('board edit zahodeny — vo vybere nie je doska')
            return [nil, nil]
          end
          echo = data['board_id'].to_s
          unless echo == Store.get(board, 'id').to_s
            Engine.log("board edit zahodeny — echo #{echo} nesedi s vyberom #{Store.get(board, 'id')}")
            return [nil, nil]
          end
          [model, board]
        end

      end
    end
  end
end
