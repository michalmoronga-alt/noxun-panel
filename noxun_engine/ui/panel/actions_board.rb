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
      # V0.6 M-B1 (audit F5): thickness je editovatelna VYHRADNE pri UNI
      # materiali (server guard v handle_set_board_fields) — pri realnom
      # materiali hrubku dalej urcuje katalog (D-45).
      BOARD_FIELD_KEYS = %w[name length width quantity grain_direction thickness].freeze

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
          # V0.6 M-B1 (audit F5): hrubku smie menit LEN doska na UNI materiali
          # — pri realnom ju urcuje katalog (normalize by ju aj tak prepisal,
          # ale payload sa zahadzuje uz tu, nech UI neklame "ulozene").
          if params.key?('thickness')
            cfg = Store.config(board)
            sheet = defined?(Materials) ? Materials.sheet(cfg.is_a?(Hash) ? cfg['material_id'] : nil) : nil
            params.delete('thickness') unless sheet && Materials.uni?(sheet)
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
          # D-49 (audit F4): virtualny duplak rozries PRED ABS kontrolou aj
          # remapom — BoardBuilder dostane vyhradne realny katalogovy zaznam.
          duplak_note = ''
          mat, dnote = resolve_virtual_material(mat)
          unless mat
            set_status(dnote, true)
            return push_selected(model)
          end
          duplak_note = dnote.to_s
          # D-41 C2: modal "Vytvorit a pokracovat" — dovytvorenie pasky pred
          # remapom (hrubka dosky nasleduje novy sheet, kompat kontrola netreba).
          abs_note = ''
          if data['create_missing_abs']
            ok_abs, abs_note = ensure_missing_abs(mat, client_schema: data['catalog_schema'])
            return set_status(abs_note, true) unless ok_abs
          end
          cfg = Store.config(board) || {}
          params = { 'material_id' => mat }
          new_sheet = Materials.sheet(mat)
          remap, lost, remap_issues = remap_edges_for_material(cfg, mat)
          params['edges'] = remap if remap
          # Codex GH #90 P1/P2 (kola 1-4): v SCHEMA 2 stavia hrany + warnings
          # JEDNA kompozicia (BoardBuilder.material_change_outcome): remap ->
          # repick zlyhanych defaultov (nie 0,4 kontraktu) -> zachovanie
          # warnings nespracovanych hran -> cerstve warnings.
          unless remap_issues.nil?
            edges_final, warnings_final = BoardBuilder.material_change_outcome(cfg, remap, remap_issues, new_sheet)
            params['edges'] = edges_final
            params['warnings'] = warnings_final
          end
          params['grain_direction'] = 'none' if new_sheet && new_sheet['grain'].to_s == 'none'
          msg = 'Materiál dosky nastavený.'
          msg += ' ABS hrany prevedené na nový dekor.' if remap
          msg += " Hrany #{lost.join(', ')} bez ABS (nový dekor nemá variant hrúbky)." unless lost.empty?
          apply_board(model, board, params, "#{msg}#{abs_note}#{duplak_note}")
        end

        # Prevod ABS hran stareho dekoru na novy (drzi nominalnu triedu). Vrati
        # [nova_edges_mapa alebo nil (nic na prevod), pole hran bez variantu].
        # D-41 PR C: len tenky obal nad spolocnym jadrom Materials.remap_edges
        # (to iste pouzivaju dielcove overridy — audit FIX 5). Cielova hrubka =
        # hrubka NOVEHO sheetu (hrubka dosky VZDY nasleduje material; FIX 10).
        # 2A-3 (audit F6/F7): pri katalogu SCHEMA 2 ide remap so ZAZNAMAMI
        # (stary aj novy sheet — skupina + struktura + universal, 0,4 do lost
        # s "vyber rucne"); SCHEMA 1 = dnesny textovy remap BEZ ZMENY.
        # Vrati [mapa|nil, lost_texty, issues|nil] — issues (surove z
        # remap_edges_v2, vratane uspesneho 1,5 fallbacku) LEN v SCHEMA 2;
        # nil = legacy rezim, stare warnings sa nemenia. Kompoziciu warnings
        # robi BoardBuilder.material_change_outcome (GH #90 kola 1-4).
        def remap_edges_for_material(cfg, new_mat)
          new_sheet = Materials.sheet(new_mat)
          target_th = new_sheet && new_sheet['thickness'].to_f
          target = target_th && target_th.positive? ? target_th : nil
          edges = cfg['edges'].is_a?(Hash) ? cfg['edges'] : nil
          if Materials.catalog_schema >= Materials::SCHEMA_GROUPS
            map, issues = Materials.remap_edges_v2(edges, Materials.sheet(cfg['material_id']),
                                                   new_sheet, target)
            lost = issues.reject { |n| n[:abs_id] }
                         .map { |n| "#{n[:code]}#{CabinetBuilder.lost_suffix(n[:reason])}" }
            [map, lost, issues]
          else
            map, lost = Materials.remap_edges(edges, Materials.decor_of(cfg['material_id']),
                                              new_sheet && new_sheet['decor'], target)
            [map, lost, nil]
          end
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
          params = { 'edges' => edges }
          # Codex GH #90 P2: vedoma zmena hrany zneplatni ulozene pick warnings
          # LEN tejto hrany (agregat sa deli, zvysne hrany ostavaju — 2. kolo).
          pruned = BoardBuilder.prune_edge_warnings(cfg['warnings'], [code], cfg['name'])
          params['warnings'] = pruned unless pruned.nil?
          apply_board(model, board, params, "Hrana #{code} — #{label}.")
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
          cfgb = Store.config(board) || {}
          abs_note = ''
          # D-41 C2: dovytvorenie pasky pred bulkom (modal flag; server overi znova).
          if data['create_missing_abs'] && cfgb['material_id']
            ok_abs, abs_note = ensure_missing_abs(cfgb['material_id'], client_schema: data['catalog_schema'])
            return set_status(abs_note, true) unless ok_abs
          end
          abs_id, decor = bulk_abs_for(cfgb)
          return set_status(missing_bulk_abs_msg(decor), true) if abs_id.nil?
          params = { 'edges' => AbsRules.uniform_edges(abs_id) }
          # Codex GH #90 P2: bulk vedome prepisuje VSETKY 4 hrany — stare pick
          # warnings hran su neplatne (prune vsetkych EDGE_KEYS polozek).
          pruned = BoardBuilder.prune_edge_warnings(cfgb['warnings'], %w[L1 L2 W1 W2], cfgb['name'])
          params['warnings'] = pruned unless pruned.nil?
          apply_board(model, board, params, "#{bulk_done_msg(abs_id, decor)}#{abs_note}")
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
