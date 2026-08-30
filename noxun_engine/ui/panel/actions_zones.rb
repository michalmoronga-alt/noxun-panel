# frozen_string_literal: true
# Noxun Engine - Panel: akcie zon (split, shelves, clean, field, select + apply_zone_mod).
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
#
# UI-C2 (kontrakt UI 2.0, sekcia Zony) — TRI zasady tejto cesty:
#   1) KAZDY zonovy callback nesie identitu DOKUMENTU (`model_guid`) aj skrinky
#      (`cabinet_id`) a server ich overuje. ID zon sa medzi dokumentmi opakuju
#      (`CAB-001-Z1.2` existuje v kazdom projekte), takze oneskoreny callback
#      z CEF by po prepnuti dokumentu prestaval CUDZI model (vzor sync.rb
#      `model_guid`, `handle_clear_selection`, `handle_camera_focus`).
#   2) Delit a davat police smie VYHRADNE listova zona; delena sa najprv vycisti.
#      Je to serverove pravidlo, nie len HTML `disabled` — tlacidlo v starom
#      paneli, dvojklik pocas rebuildu ani rucny callback nesmu zmazat podstrom.
#      Jedina destruktivna cesta ostava „Vycistit zonu".
#   3) Mutacia stromu vracia true/false a handler NAVRATOVU HODNOTU VETVI.
#      Odmietnuta zmena = chybovy status a ZIADNY rebuild (predtym sa strom
#      neupravil, ale skrinka sa aj tak prestavala a status hlasil uspech).
module Noxun
  module Engine
    module Panel
      class << self
        # --- akcie: zony -----------------------------------------------------
        def handle_split_zone(payload)
          data = parse(payload)
          ctx = zone_ctx(data, 'Zóna sa nerozdelila')
          return unless ctx

          axis = data['axis'].to_s == 'h' ? 'h' : 'v'
          count = data['count'].to_i
          return set_status('Zóna sa nerozdelila — počet polí musí byť 2 až 4.', true) unless (2..4).cover?(count)

          err = split_refusal(ctx)
          return set_status(err, true) if err

          return unless apply_zone_mod(ctx, 'Zóna sa nerozdelila') { |tree, path| ZoneTree.set_split!(tree, path, axis, count) }

          set_status("Zóna #{short_zone(ctx[:zone_id])} rozdelená #{axis == 'h' ? 'vodorovne' : 'zvisle'} na #{count}.")
        end

        # Preco sa delenie odmietne (nil = smie sa). Presna hlaska sa sklada TU,
        # aby pouzivatel nedostal len „nepodarilo sa"; `set_split!` je posledna
        # poistka rovnakych podmienok.
        def split_refusal(ctx)
          node = zone_node(ctx)
          return 'Zóna sa nerozdelila — obnov panel (zóna sa v skrinke nenašla).' if node.nil?
          unless ZoneTree.leaf?(node)
            return 'Zóna je už delená — najprv ju vyčisti („Vyčistiť zónu"), potom rozdeľ nanovo.'
          end
          return nil if ctx[:path].length < ZoneTree::MAX_LEVELS

          "Hlbšie delenie sa nedá — strom zón má najviac #{ZoneTree::MAX_LEVELS} úrovne."
        end

        def handle_set_zone_shelves(payload)
          data = parse(payload)
          ctx = zone_ctx(data, 'Police sa nenastavili')
          return unless ctx

          n = data['count'].to_i
          return set_status("Police sa nenastavili — počet musí byť 0 až #{Shelves::MAX}.", true) unless
            (0..Shelves::MAX).cover?(n)

          node = zone_node(ctx)
          return set_status('Police sa nenastavili — obnov panel (zóna sa v skrinke nenašla).', true) if node.nil?
          unless ZoneTree.leaf?(node)
            return set_status('Zóna je delená — police patria konkrétnemu stĺpcu/riadku. ' \
                              'Označ zónu vnútri, alebo delenie zruš („Vyčistiť zónu").', true)
          end

          return unless apply_zone_mod(ctx, 'Police sa nenastavili') { |tree, path| ZoneTree.set_shelves!(tree, path, n) }

          set_status("Zóna #{short_zone(ctx[:zone_id])}: #{n} #{shelf_word(n)}.")
        end

        def shelf_word(n)
          return 'políc' if n.zero? || n > 4

          n == 1 ? 'polica' : 'police'
        end

        def handle_clean_zone(payload)
          data = parse(payload)
          ctx = zone_ctx(data, 'Zóna sa nevyčistila')
          return unless ctx

          return unless apply_zone_mod(ctx, 'Zóna sa nevyčistila') { |tree, path| ZoneTree.clear_zone!(tree, path) }

          set_status("Zóna #{short_zone(ctx[:zone_id])} vyčistená.")
        end

        # V0.2c: nastav presny rozmer pola v delenej zone + zamok (split lock). zone_id = RODICOVSKA
        # (delena) zona; index = poradie pola (0..count-1); size mm (prazdne = auto), locked bool.
        # fix #5: ak UI posle kompletny 'cuts' layout (rozmery vsetkych poli), ulozime ho naraz —
        # zadany rozmer bez locku sa tak NEstrati (proporcny prepocet az pri resize korpusu).
        #
        # UI-C2 (audit F7/F8): kompletny layout sa PRED zapisom prisne kontroluje —
        # kazde pole musi byt konecne cislo >= MIN_FIELD a sucet musi sediet na
        # svetly priestor zony (tolerancia 0,01 mm). Nezmestitelna hodnota sa
        # ODMIETNE; nikdy sa ticho nezmensi (stolar by vyrobil iny nabytok).
        def handle_set_zone_field(payload)
          data = parse(payload)
          ctx = zone_ctx(data, 'Rozmer poľa sa neuložil')
          return unless ctx

          node = zone_node(ctx)
          return set_status('Rozmer poľa sa neuložil — obnov panel (zóna sa v skrinke nenašla).', true) if node.nil?
          if ZoneTree.leaf?(node)
            return set_status('Rozmer poľa sa neuložil — zóna nie je delená.', true)
          end

          index = data['index'].to_i
          cuts = data['cuts']
          if cuts.is_a?(Array)
            count = node['split']['count'].to_i
            err = ZoneTree.validate_cuts(cuts, count, clear: zone_clear_span(ctx))
            return set_status("Rozmer poľa sa neuložil — #{err}", true) if err

            return unless apply_zone_mod(ctx, 'Rozmer poľa sa neuložil') { |tree, path| ZoneTree.set_field_cuts!(tree, path, cuts) }
          else
            size = ZoneTree.strict_mm(data['size'])
            return set_status('Rozmer poľa sa neuložil — hodnota nie je platné číslo.', true) if size == :invalid

            locked = truthy?(data['locked'])
            return unless apply_zone_mod(ctx, 'Rozmer poľa sa neuložil') { |tree, path| ZoneTree.set_field!(tree, path, index, size, locked) }
          end
          set_status("Pole #{index + 1}: #{field_status(node, data, index)} — prestavané.")
        end

        # Status presnej cesty (audit F12): text sa cita z TOHO, CO SA ULOZILO
        # (`cuts[index]`), nie z prazdneho `size` — inak hlasil „auto" aj vtedy,
        # ked pole dostalo presny rozmer z kompletneho layoutu.
        def field_status(_node, data, index)
          cuts = data['cuts']
          cut = cuts.is_a?(Array) ? cuts[index] : nil
          raw = cut.is_a?(Hash) ? (cut['size'].nil? ? cut[:size] : cut['size']) : data['size']
          locked = cut.is_a?(Hash) ? truthy?(cut['locked'].nil? ? cut[:locked] : cut['locked']) : truthy?(data['locked'])
          v = ZoneTree.strict_mm(raw)
          return 'auto' if v.nil? || v == :invalid

          "#{ZoneTree.fmt(v)} mm#{locked ? ' (zamknuté)' : ''}"
        end

        # V0.2c obojsmerna sync: klik na zonu v 2D nahlade -> zvyrazni jej ghost v modeli.
        # UI-C2: aj tento (necinny) callback nesie identitu dokumentu — pri nezhode
        # sa VYBER nedotkne (ghost cudzieho modelu by prepol aktivnu zonu panela).
        def handle_select_zone(payload)
          model = Sketchup.active_model
          return if model.nil?

          data = parse(payload)
          return if DocKey.foreign?(data['model_guid'], model)

          zid = data['zone_id'].to_s
          if zid.empty?
            @active_zone_id = nil
            return
          end
          return if zone_path(zid).nil? # poskodene ID sa aktivnou zonou nikdy nestane

          @active_zone_id = zid
          cid = cabinet_id_from_zone(zid)
          sub = Zones.find_zone_group(model, cid, zid)
          if sub && sub.valid?
            # Len zvyraznenie ghostu v modeli — panel uz o aktivnej zone vie (poslal ju), preto
            # potlacime observer, nech clear/add nevynuluje selectedCabId ani aktivnu zonu.
            suspend_selection_sync do
              model.selection.clear
              model.selection.add(sub)
            end
          end
        rescue StandardError => e
          Engine.log_error(e, 'handle_select_zone')
        end

        # UI-C2 (B4): LEGACY hlboky strom. Sablona ci zakazka z inej verzie moze
        # mat viac nez MAX_LEVELS urovni zon. Vlozenie sa POVOLI — automaticke
        # orezanie je ZAKAZANE (zmazalo by dielce, ktore uz v zakazke stoja aj
        # s materialmi a ABS). Povie sa to vsak NAHLAS: hlbsie urovne sa uz
        # nedaju delit a panel ich v strome kresli varovnym (neklikatelnym)
        # riadkom. Vrati prazdny retazec, ked je strom v poriadku.
        def zone_depth_note(tree)
          d = ZoneTree.depth(tree)
          return '' if d <= ZoneTree::MAX_LEVELS

          " · POZOR: štruktúra zón má #{d} úrovne (podporované sú #{ZoneTree::MAX_LEVELS}) — " \
            'hlbšie zóny sa už nedajú deliť, ostatné funkcie fungujú.'
        rescue StandardError
          ''
        end

        # --- spolocny vstup zonovych callbackov --------------------------------
        # Vrati { model:, cab:, cabinet_id:, zone_id:, path: } alebo nil (status
        # uz je nastaveny). `what` = zaciatok kazdej hlasky, aby pouzivatel vzdy
        # citoval „co sa NEstalo a preco", nie holy technicky dovod.
        def zone_ctx(data, what)
          model = Sketchup.active_model
          return nil if model.nil?

          # F9: PRISNE porovnanie identity dokumentu (vzor `handle_clear_selection`).
          # Prazdny guid nie je starsi klient — je to okno bez dobehnuteho NX.init,
          # a to nesmie stavat v cudzom modeli.
          if DocKey.foreign?(data['model_guid'], model)
            set_status("#{what} — panel patrí inému dokumentu.", true)
            return nil
          end

          zid = data['zone_id'].to_s
          if zid.empty?
            set_status("#{what} — najprv označ zónu (klik na zónu v náhľade alebo v strome).", true)
            return nil
          end

          path = zone_path(zid)
          if path.nil?
            set_status("#{what} — označenie zóny je poškodené. Klikni na zónu znova.", true)
            return nil
          end

          cid = cabinet_id_from_zone(zid)
          want = data['cabinet_id'].to_s
          if cid.nil? || (!want.empty? && want != cid)
            set_status("#{what} — označenie patrí inej skrinke. Klikni na zónu znova.", true)
            return nil
          end

          cab = find_cabinet_by_id(model, cid)
          if cab.nil?
            set_status("#{what} — skrinka #{cid} sa v dokumente nenašla.", true)
            return nil
          end

          { model: model, cab: cab, cabinet_id: cid, zone_id: zid, path: path }
        end

        # Uzol stromu, na ktory zonove ID ukazuje (nil = cesta v strome neexistuje).
        def zone_node(ctx)
          params = existing_params(ctx[:cab])
          tree = ZoneTree.sanitize(params['zone_tree'] || ZoneTree.default_tree(0))
          ZoneTree.navigate(tree, ctx[:path])
        rescue StandardError => e
          Engine.log_error(e, 'Panel.zone_node')
          nil
        end

        # Svetly priestor delenej zony (mm) pre validaciu poli (F8). Plan je ta
        # ista cesta, akou pocita builder, takze sa kontrola a stavba nemozu
        # rozist. Zlyhanie = nil (kontrola suctu sa preskoci, ostatne pravidla
        # platia — radsej mensia kontrola nez pad).
        #
        # Codex #177 P2: pocita sa z ROZPATIA zony (`width`/`height` mínus
        # priecky), NIE zo suctu jej poli. Kazde pole je v plane zaokruhlene na
        # 2 desatinne miesta (`field_info` -> `r2`), takze styri polia po
        # 201,775 mm sa v plane javia ako 4 × 201,78 = o 0,02 mm viac — a klient,
        # ktory posle sucet zodpovedajuci SKUTOCNEMU rozpatiu, by dostal falosne
        # „nezmestia sa". Rozpatie je zaokruhlene raz (chyba <= 0,005 mm).
        def zone_clear_span(ctx)
          cfg = CabinetBuilder.normalize(existing_params(ctx[:cab]))
          plan = Construction.build_plan(cfg, ctx[:cabinet_id])
          zone = Array(plan[:zones]).find { |z| z[:id].to_s == ctx[:zone_id] }
          return nil unless zone && zone[:split]

          span = zone[:split][:axis].to_s == 'v' ? zone[:width].to_f : zone[:height].to_f
          ZoneTree.clear_space(span, zone[:split][:count].to_i, cfg[:thickness].to_f)
        rescue StandardError => e
          Engine.log_error(e, 'Panel.zone_clear_span')
          nil
        end

        # Spolocny postup: nacitaj korpus zony, uprav strom, rebuild, oznac korpus, pushni.
        # Vrati skrinku (uspech) alebo nil — volajuci NESMIE hlasit uspech bez nej.
        def apply_zone_mod(ctx, what = 'Zmena zóny sa neuložila')
          cab = ctx[:cab]
          model = ctx[:model]
          params = existing_params(cab)
          tree = ZoneTree.sanitize(params['zone_tree'] || ZoneTree.default_tree(0))
          # Mutacia vracia true/false; false = strom sa NEZMENIL (guard listovosti,
          # hlbky alebo neexistujuca cesta) a prestavba by len klamala o uspechu.
          unless yield(tree, ctx[:path])
            set_status("#{what} — zmena nie je v tejto zóne možná. Obnov panel a skús znova.", true)
            return nil
          end
          params['zone_tree'] = tree
          # Cela mutacia je NASA (rebuild + reselect). Observer potlacime, aby medzikroky
          # (clear/add korpusu, erase klik-nuteho ghostu) neposlali NX.clearSelected() a nevynulovali
          # selectedCabId v paneli. Aktivnu zonu drzime cez rebuild -> panel sa jej po resyncu drzi tiez.
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params)
            @active_zone_id = ctx[:zone_id]
            reselect(model, cab) # klik-nuty ghost je po rebuilde zmazany -> vyber korpus nanovo
          end
          push_selected(model) # PRESNE jeden resync panela (loadSelected s aktivnou zonou)
          cab
        rescue StandardError => e
          # Geometricke odmietnutie (ZoneTree.validate_*) ma zmysluplny text —
          # ukaz ho; rebuild uz operaciu zrusil, model ostava nedotknuty.
          Engine.log_error(e, 'Panel.apply_zone_mod')
          set_status("#{what} — #{e.message}", true)
          nil
        end

      end
    end
  end
end
