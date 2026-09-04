# frozen_string_literal: true
# Noxun Engine - Panel: samostatna doska (V0.4.7c) — vlozenie + editacia karty.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, suspend guard) cez class << self.
#
# GUARD proti oneskorenym zapisom (Codex audit c, blocker A; R-02): kazdy edit
# callback nesie `model_guid` DOKUMENTU aj echo board_id z karty. Zapis prejde
# LEN ked (0) payload patri AKTIVNEMU dokumentu, (1) v Inspectore nevyhrala
# skrinka (find_cabinet nil), (2) vo vybere JE doska a (3) jej Store id sedi
# s echom. Nezhoda dokumentu je HLASKA (prepnutie zakazky je zriedkave a
# uzivatel musi vediet, ze sa zmena neulozila); zvysne tri sa TICHO zahodia
# (len log) — pouzivatel uz medzitym robi nieco ine, hlaska by matla.
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
        # GHOST-D1: „Vložiť dosku" UZ NEVKLADA — pripravi ZMRAZENY `BoardPlan`
        # (`BoardBuilder.prepare_insert`) a zavesi ghost na kurzor; doska
        # vznikne az KLIKOM v modeli (`GhostTool` -> `BoardBuilder.commit_insert`).
        # Synchronna cesta cez `BoardBuilder.build` (`Placement.next_x`) tu
        # ZANIKLA — ostava programatickym volajucim (testy, in-SU, nastroje).
        #
        # PORADIE JE SUCASTOU KONTRAKTU (R-02 + audit 4):
        #   1. `foreign_document?` ako UPLNE PRVY krok — oneskoreny CEF callback
        #      zo stareho Inspectora nesmie pripravit plan nad NOVYM modelom,
        #   2. sablonovy ref + DOWNGRADE BRANA (autoritou je ULOZENY RAW zaznam
        #      sablony, nie payload z CEF — v nom marker uz nemusi byt),
        #   3. `prepare_insert` (ziadna mutacia, ziadne ID, ziadny krok Spat),
        #   4. session (`GhostTool.start` rusi pripadnu STARU session ako prvy krok).
        # E-03: thickness sa LEN prepusti — o tom, ci sa pouzije, rozhoduje
        # BoardBuilder.insert_thickness_for (material je znamy az po doplneni
        # projektoveho defaultu, preto guard sedi v builderi, nie tu).
        def handle_insert_board(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Doska sa nevložila') # R-02
          # UI-C1a: metadata sablony (`template_kind`/`template_name`) su MIMO
          # whitelistu poli, takze sa do buildera nedostanu tak ci tak — vyberu
          # sa vsak vyslovne, aby bolo jasne, ze ide o identitu na peciatku.
          tpl_ref = take_template_ref!(data, 'board')
          if (tpl_msg = newer_template_refusal(tpl_ref, 'vloženie by nastavenia stratilo'))
            return set_status("#{tpl_msg} Nič sa nevložilo.", true)
          end
          params = {}
          # UI-C1c: `orientation` je vo whiteliste vkladania — karta ju posiela
          # pri KAZDEJ materializacii explicitne (default 'leziaca'), takze
          # „Bez šablóny" nikdy nezdedi starý draft. Neznamu hodnotu odmietne
          # BoardBuilder.norm_orientation vynimkou (cb ju ukaze v statuse).
          %w[name length width material_id grain_direction thickness orientation].each do |k|
            v = data[k]
            params[k] = v unless v.nil? || v.to_s.strip.empty?
          end
          begin
            plan = BoardBuilder.prepare_insert(model, params, template_ref: tpl_ref)
          rescue StandardError => e
            Engine.log_error(e, 'Panel.handle_insert_board')
            return set_status("Chyba: #{e.message}", true)
          end
          # Orientacia session pochadza z KARTY (payload), nie z pamate ghostu —
          # karta ju nastavuje pri kazdej materializacii, aj zo sablony.
          if GhostTool.start(model, plan, template_ref: tpl_ref, subject: :board,
                                          orientation: plan.orientation).nil?
            return set_status('Ghost vkladanie sa nepodarilo spustiť — skús to znova.', true)
          end
          set_status('Doska visí na kurzore — klikni, kam ju položiť. ' \
                     'Šípky ←/→ otáčajú, ↑/↓ menia umiestnenie, Alt prepína kotvu, Esc zruší.')
        end

        # GHOST-D1: po USPESNOM commite dosky — vyber, status, refresh panela
        # a peciatka sablony. Bezi MIMO operacie vlozenia; zlyhanie
        # ktorehokolvek kroku nesmie zabranit zatvoreniu committed session.
        def ghost_after_commit_board(model, inst, session)
          select_only(model, inst)
          label = BoardBuilder::ORIENTATION_LABELS[session.orientation.to_s].to_s.downcase
          bid = Store.get(inst, 'id')
          set_status(label.empty? ? "Doska #{bid} vložená." : "Doska #{bid} vložená — #{label}.")
          push_selected(model)
          session.stamp_once! { stamp_template_used(session.template_ref) } # az PO vlozeni
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

        # UI-C1c: prepnutie ORIENTACIE uz vlozenej dosky. Orientacia NIE JE
        # bezne pole karty (BOARD_FIELD_KEYS) — meni TRANSFORMACIU INSTANCIE,
        # takze ma vlastnu cestu s vlastnym guardom:
        #   * neznama POZADOVANA hodnota  -> odmietnutie (ziadna tichá zmena),
        #   * neznama ULOZENA hodnota     -> odmietnutie (config z novsej verzie
        #     pluginu — delta by z neho spravila nezmysel),
        #   * rovnaka hodnota             -> no-op (ziadny prazdny undo krok).
        # Zmena je DELTA (BoardBuilder.orientation_delta) nad SUCASNOU
        # transformaciou, takze rucne otocenie/posun pouzivatela prezije;
        # rebuild + zapis transformacie su JEDNA operacia = JEDEN krok Spat.
        def handle_set_board_orientation(payload)
          data = parse(payload)
          model, board = guarded_board(data)
          return unless board
          want = data['orientation'].to_s
          return set_status('Neznáma orientácia dosky.', true) unless BoardBuilder::ORIENTATIONS.include?(want)

          cfg = Store.config(board) || {}
          # GHOST-D1: dopredna brana schemy PRED akoukolvek zmenou — config
          # z novsej verzie by prestavba ocesala (`normalize` je uzavrety
          # whitelist). Model ostava nedotknuty, ziadny krok Spat.
          if BoardBuilder.newer_config?(cfg)
            return set_status("#{BoardBuilder.newer_config_message('otočenie by nastavenia stratilo')} " \
                              'Doska sa neotočila.', true)
          end
          old = BoardBuilder.stored_orientation(cfg)
          unless BoardBuilder::ORIENTATIONS.include?(old)
            return set_status("Doska má neznámu uloženú orientáciu „#{old}“ — pochádza z novšej verzie pluginu.", true)
          end
          return set_status("Doska je už #{BoardBuilder::ORIENTATION_LABELS[want].to_s.downcase}.") if old == want

          tr = BoardBuilder.orientation_delta(board.transformation, old, want, cfg['thickness'].to_f)
          suspend_selection_sync do
            BoardBuilder.rebuild(model, board, { 'orientation' => want },
                                 transform: tr, op_name: 'NOXUN: Otoč dosku')
          end
          # Codex audit C1c FIX 4: stabilna transformacia v scale observeri musi
          # ist s otocenim. Bez tohto by najblizsi ODMIETNUTY scale vratil dosku
          # do STAREJ polohy, kym config uz nesie novu orientaciu.
          ScaleWatch.remember_transform(board) if defined?(ScaleWatch)
          set_status("Doska — #{BoardBuilder::ORIENTATION_LABELS[want].to_s.downcase}.")
          push_selected(model)
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
          # M-C (GH #118 P1): material, ktory sa NELEPI (kompakt / PD s
          # postformingom) — stare hrany by prezili remap (same-decor = no-op)
          # a snapshot by niesol ABS na materiali bez olepu. Hrany sa vycistia
          # CELE (vratane rucnych — hlaska to hovori; rucne sa daju vratit).
          if defined?(Materials) && Materials.abs_default_suppression(new_sheet) == :all
            params['edges'] = { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil }
            pruned = BoardBuilder.prune_edge_warnings(cfg['warnings'], %w[L1 L2 W1 W2], cfg['name'])
            params['warnings'] = pruned unless pruned.nil?
            msg = 'Materiál dosky nastavený. Hrany zrušené — tento materiál sa neolepuje (kompakt/postforming).'
          end
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
        #
        # R-02: DVE urovne identity, ZAMERNE s roznou hlasnostou.
        #   * DOKUMENT (`model_guid`) — NAHLAS. Prepnutie zakazky je zriedkave,
        #     `board_id` ho nezachyti (BRD-001 je v kazdom projekte) a tichy
        #     zapis by skoncil v cudzej zakazke. Pouzivatel musi vediet, ze sa
        #     zmena neulozila.
        #   * ECHO board_id / vyber — TICHO (len log), ako doteraz: pouzivatel
        #     uz medzitym robi nieco ine a hlaska by ho len mylila.
        def guarded_board(data)
          model = Sketchup.active_model
          return [nil, nil] if foreign_document?(data, model, 'Doska sa nezmenila')

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
