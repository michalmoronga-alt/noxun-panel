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
        # ABS hrany STAREHO dekoru sa prevedu na novy dekor pri ZACHOVANI hrubky
        # (Codex GH #33 P2): dekor hran nasleduje material dielca — presne ako
        # korpusove pravidlove defaulty. Hrany bez ABS, cudzieho dekoru (vedoma
        # volba) alebo mimo katalogu sa nedotknu; chybajuci variant hrubky -> nil.
        # Smer dekoru: material bez dekoru (grain none) nemoze mat smer.
        def handle_set_board_material(payload)
          data = parse(payload)
          model, board = guarded_board(data)
          return unless board
          mat = data['material_id'].to_s.strip
          return set_status('Doska potrebuje konkrétny materiál.', true) if mat.empty?
          cfg = Store.config(board) || {}
          params = { 'material_id' => mat }
          remap, lost = remap_edges_for_material(cfg, mat)
          params['edges'] = remap if remap
          new_sheet = Materials.sheet(mat)
          params['grain_direction'] = 'none' if new_sheet && new_sheet['grain'].to_s == 'none'
          msg = 'Materiál dosky nastavený.'
          msg += ' ABS hrany prevedené na nový dekor.' if remap
          msg += " Hrany #{lost.join(', ')} bez ABS (nový dekor nemá variant hrúbky)." unless lost.empty?
          apply_board(model, board, params, msg)
        end

        # Prevod ABS hran stareho dekoru na novy (rovnaka hrubka). Vrati
        # [nova_edges_mapa alebo nil (nic na prevod), pole hran bez variantu].
        def remap_edges_for_material(cfg, new_mat)
          old_decor = Materials.decor_of(cfg['material_id'])
          new_decor = Materials.decor_of(new_mat)
          return [nil, []] unless old_decor && new_decor && old_decor != new_decor
          edges = cfg['edges'].is_a?(Hash) ? cfg['edges'].dup : nil
          return [nil, []] unless edges
          changed = false
          lost = []
          %w[L1 L2 W1 W2].each do |code|
            aid = edges[code]
            next if aid.nil?
            rec = Materials.edge(aid)
            next unless rec && rec['decor'] == old_decor # cudzi dekor = vedoma volba, nechaj
            new_aid = Materials.abs_for_decor(new_decor, rec['thickness'])
            lost << code if new_aid.nil?
            edges[code] = new_aid
            changed = true
          end
          [changed ? edges : nil, lost]
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

        # D-35: olepenie VSETKYCH 4 hran dosky jednym klikom — ABS 1.0 mm dekoru
        # materialu dosky, JEDEN rebuild = JEDEN undo krok (audit FIX 7). Echo
        # board_id guard ako ostatne board akcie; JS pred volanim flushuje pending
        # debounce edity (flushBoardEditsNow — audit FIX 6), takze bulk pracuje
        # nad cerstvym configom. Nenajdena ABS = atomicky no-op (audit FIX 5):
        # ziadna zmena configu, ziadny rebuild, ziadny undo krok — NIKDY sa
        # neuklada mapa 4x nil (zmazala by existujuce hrany).
        def handle_set_board_edges_all(payload)
          data = parse(payload)
          model, board = guarded_board(data)
          return unless board
          abs_id, decor = bulk_abs_for(Store.config(board) || {})
          return set_status(missing_bulk_abs_msg(decor), true) if abs_id.nil?
          apply_board(model, board, { 'edges' => AbsRules.uniform_edges(abs_id) },
                      "Všetky 4 hrany — ABS #{decor} 1,0 mm.")
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
