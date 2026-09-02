# frozen_string_literal: true
# Noxun Engine - Panel: kovanie (V0.4 faza 1) — rucne zasahy do poctov.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # Jeden zasah do kovania oznacenej skrinky. Identita = (owner_part_key,
        # generic_type, rule_id).
        #
        # D-93 (audit B2): zapis ide PO POLIACH — payload nesie 'field'
        # ('quantity' | 'disabled' | 'nominal_length') a 'value' (null = zrus
        # LEN toto pole). Zaznam identity sa MERGUJE (zmena NL nikdy nezmaze
        # rucny pocet a naopak) a zanikne az vtedy, ked ostane prazdny.
        # Stary tvar payloadu ostava funkcny: quantity N / disabled true /
        # reset true (= zahodi CELY zaznam).
        # Zapis + rebuild v jednej operacii (override zije v configu korpusu).
        OVERRIDE_FIELDS = %w[quantity disabled nominal_length].freeze

        def handle_set_hardware_override(payload)
          model = Sketchup.active_model
          data = parse(payload)
          # R-02: identita DOKUMENTU pred identitou skrinky — `cabinet_id` nizsie
          # prepnutie dokumentu nezachyti (CAB-001 je v kazdej zakazke).
          return if foreign_document?(data, model, 'Kovanie sa nezmenilo')

          cab = find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus.', true) if cab.nil?

          gt = data['generic_type'].to_s
          rid = data['rule_id'].to_s
          return set_status('Neznáma položka kovania.', true) if gt.empty? || rid.empty?

          # F6: payload nesie identitu RENDROVANEJ skrinky — zmena vyberu pred
          # obsluhou callbacku nesmie prepisat inu skrinku (vzor callbacku setov).
          rendered = data['cabinet_id'].to_s
          if !rendered.empty? && rendered != Store.get(cab, 'cabinet_id').to_s
            push_selected(model)
            return set_status('Výber sa medzitým zmenil — panel sa obnovil, skús znova.', true)
          end

          owner = present_str(data['owner_part_key'])
          field, value, err = override_change(data, model, owner, gt, rid)
          return set_status(err, true) if err

          params = existing_params(cab)
          all = params['hardware_overrides'].is_a?(Array) ? params['hardware_overrides'] : []
          list = merge_override(all, owner, gt, rid, field, value)

          params['hardware_overrides'] = list
          suspend_selection_sync do
            CabinetBuilder.rebuild(model, cab, params, op_name: 'NOXUN: kovanie ručne')
            reselect(model, cab)
          end
          status_with_warnings(cab, override_status_msg(cab, field, value))
          push_selected(model)
        end

        # Zisti, ktore POLE sa meni a na aku hodnotu. -> [field, value, error]
        #   field == :all  -> zahodit cely zaznam (stare 'reset')
        #   value == nil   -> zrusit len dane pole
        def override_change(data, model, owner, gt, rid)
          if data.key?('field')
            f = data['field'].to_s
            return [nil, nil, 'Neznáme pole ručného zásahu.'] unless OVERRIDE_FIELDS.include?(f)
            return [f, nil, nil] if data['value'].nil?
            return override_value(f, data['value'], model, owner, gt, rid)
          end
          return [:all, nil, nil] if truthy?(data['reset'])
          return ['disabled', true, nil] if truthy?(data['disabled'])
          return override_value('quantity', data['quantity'], model, owner, gt, rid) if data['quantity']

          [:all, nil, nil]
        end

        # Serverova validacia hodnoty pola (HTML disabled nie je ochrana).
        def override_value(field, raw, model, owner, gt, rid)
          case field
          when 'disabled'
            [field, true, nil]
          when 'quantity'
            q = raw.to_i
            return [nil, nil, 'Počet musí byť aspoň 1 (alebo položku vypni).'] if q < 1
            [field, [q, BuildPlan::MAX_HW_QUANTITY].min, nil]
          when 'nominal_length'
            nl = HardwareRules.override_nl(raw.is_a?(String) ? Float(raw, exception: false) : raw)
            return [nil, nil, 'Neplatná dĺžka výsuvu.'] if nl.nil?
            return [nil, nil, 'Táto dĺžka nie je v rade pravidla — otvor Pravidlá kovania.'] \
              unless series_value?(model, rid, gt, nl)
            [field, nl, nil]
          else
            [nil, nil, 'Neznáme pole ručného zásahu.']
          end
        end

        # F5/F7: SET smie ulozit LEN hodnotu z aktualneho radu pravidla (presna
        # zhoda). Uz ULOZENA hodnota mimo radu sa nikdy nemaze — len sa zobrazi
        # a da sa odomknut (to je cesta 'value' => nil, ktora sem nechodi).
        def series_value?(model, rid, gt, nl)
          rule = Array(panel_hardware_rules(model)).find do |r|
            r.is_a?(Hash) && r['rule_id'].to_s == rid && r['output'].to_s == gt
          end
          return false unless rule && rule['kind'].to_s == 'fit_series'
          Array(rule['series']).any? { |s| (s.to_f - nl).abs < 0.001 }
        end

        # Merge do zaznamu identity: prazdny zaznam zanikne, ostatne polia ostanu.
        def merge_override(all, owner, gt, rid, field, value)
          rec = Array(all).select { |ov| ov_match?(ov, owner, gt, rid) }.last
          rest = Array(all).reject { |ov| ov_match?(ov, owner, gt, rid) }
          return rest if field == :all

          out = { 'owner_part_key' => owner, 'generic_type' => gt, 'rule_id' => rid }
          if rec.is_a?(Hash)
            OVERRIDE_FIELDS.each { |k| out[k] = rec[k] if rec.key?(k) && !rec[k].nil? }
          end
          if value.nil?
            out.delete(field)
          else
            out[field] = value
          end
          return rest unless OVERRIDE_FIELDS.any? { |k| out.key?(k) }

          rest + [out]
        end

        def override_status_msg(cab, field, value)
          cid = Store.get(cab, 'cabinet_id')
          if field == 'nominal_length'
            return "Dĺžka výsuvu odomknutá (platí automat) — #{cid}." if value.nil?

            return "Dĺžka výsuvu zamknutá na #{HardwareRules.fmt_mm(value)} mm — #{cid}."
          end
          "Kovanie upravené — #{cid}."
        end

        def ov_match?(ov, owner, gt, rid)
          return false unless ov.is_a?(Hash)
          ov_owner = present_str(ov['owner_part_key'])
          ov_owner == owner && ov['generic_type'].to_s == gt && ov['rule_id'].to_s == rid
        end

        # V0.6 D1b: vyber setu kovania NA SKRINKE (override projektovej
        # predvolby). set_id prazdne = spat na predvolbu projektu. Zapis
        # overridu + definicia setu do snapshotu (audit B2) + rebuild =
        # JEDNA operacia (rebuild_many yield).
        # H1b (D-81): payload moze niest owner_part_key — potom je override LEN
        # na tom dielci (kluc "generic_type@owner_part_key"). Tvar kluca aj
        # kontrolu, ci dielec take kovanie vobec ma, robi VYHRADNE server
        # (HardwareSets.apply_cabinet_override) — jedna zapisova cesta pre oba
        # pripady, ziadne skladanie klucov v paneli.
        def handle_set_hardware_set(payload)
          model = Sketchup.active_model
          data = parse(payload)
          return if foreign_document?(data, model, 'Set kovania sa nezmenil') # R-02

          cab = find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus.', true) if cab.nil?

          gt = data['generic_type'].to_s
          return set_status('Neznámy typ kovania.', true) unless BuildPlan::GENERIC_TYPES.include?(gt)

          # GH #127 P2: payload nesie identitu RENDROVANEJ skrinky — zmena
          # vyberu pred obsluhou callbacku nesmie prepisat inu skrinku.
          rendered = data['cabinet_id'].to_s
          if !rendered.empty? && rendered != Store.get(cab, 'cabinet_id').to_s
            push_selected(model)
            return set_status('Výber sa medzitým zmenil — panel sa obnovil, skús znova.', true)
          end

          status, = HardwareSets.project_state_status(model)
          if status == :invalid
            return set_status('Sety projektu sú poškodené — obnov ich v Katalógu kovania (Predvoľby projektu).', true)
          end

          sid = present_str(data['set_id'])
          owner = present_str(data['owner_part_key'])
          set_def = nil
          if sid
            # H1a (audit BLOCKER 4): definiciu vybera resolver — pre set_id,
            # ktore projekt uz pouziva, vyhrava SNAPSHOT (podla neho sa
            # nakupuje), global je len fallback pre nereferencovane.
            cand = HardwareSets.resolve_set_def(model, sid)
            set_def = cand if cand && cand['generic_type'] == gt
            if set_def.nil?
              # R-07 (review P3-6): pri nekompatibilnej kniznici resolver
              # zamerne nic nevyda — „otvor Katalóg kovania a skús znova"
              # by pouzivatela poslalo tam, kde sa to opravit NEDA.
              return set_status(HardwareSets.library_read_only? ?
                                  "#{HardwareSets.library_state_reason} — set sa nedá vybrať." :
                                  'Set sa nenašiel — otvor Katalóg kovania a skús znova.', true)
            end
          end

          cfg = Store.config(cab) || {}
          st, map, = HardwareSets.apply_cabinet_override(cfg, gt, owner, sid,
                                                         known_sets: (set_def ? [set_def] : nil))
          return set_status("Výber setu sa nedá uložiť — #{map}.", true) unless st == :ok

          params = existing_params(cab)
          params['hardware_sets'] = map
          suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, [[cab, params]], op_name: 'NOXUN: set kovania') do
              HardwareSets.add_project_set!(model, set_def) if set_def
            end
            reselect(model, cab)
          end
          status_with_warnings(cab, hw_set_status_msg(gt, owner, sid, set_def))
          push_selected(model)
        end

        # --- KOV-H2: hladanie v katalogu pre modal rucnej polozky ------------
        #
        # CITACIA cesta: ziadna operacia, ziadny zapis do modelu, ziadny krok
        # Spat. Preto tu NIE JE guard dokumentu — nic sa nemeni a odpoved
        # obsahuje len to, co je v katalogu (ten je globalny, nie per zakazka).
        #
        # PORADIE SKLADA SERVER (`HardwareCatalog.search_with_total`) — panel
        # ho len kresli, presne ako v Studiu (kontrakt GH #100 P2). `gen` je
        # generacia dotazu: odpovede chodia asynchronne a bez nej by pomalsie
        # kolo prepisalo cerstvejsie vysledky.
        #
        # Vracia sa NAJVIAC `MANUAL_SEARCH_TOP` poloziek + `total`, aby panel
        # vedel priznat orezanie (zasada „no silent caps"). Neaktivne polozky
        # sa neponukaju (default `search`) — do zakazky sa nema dostat kod,
        # ktory uz nikto neobjednava.
        MANUAL_SEARCH_TOP = 20

        def handle_hw_manual_search(payload)
          data = parse(payload)
          js("NX.hwManualSearchResult(#{hw_manual_search_result(data['q'], data['gen']).to_json})")
        end

        # CISTA funkcia (ziadny SketchUp objekt, ziadny dialog) — headless
        # testovatelna. Klientovi ide LEN to, co potrebuje ponuka: kod, nazov,
        # MJ, kategoria a ZIVA cena; nic z toho sa nikdy neuklada do configu.
        def hw_manual_search_result(query, gen)
          items, total = HardwareCatalog.search_with_total(HardwareCatalog.items, query.to_s,
                                                           top: MANUAL_SEARCH_TOP)
          items, total = drop_inactive(items, total)
          { 'gen' => gen.to_i, 'total' => total.to_i,
            'items' => Array(items).map { |i| manual_search_item(i) } }
        rescue StandardError => e
          Engine.log_error(e, 'Panel.hw_manual_search_result')
          { 'gen' => gen.to_i, 'total' => 0, 'items' => [] }
        end

        # Codex #285 kolo 2 (P2-I): `search_with_total` vracia NEAKTIVNU polozku
        # pri PRESNEJ zhode kodu aj bez `include_inactive` — je to vedomy
        # kontrakt katalogu (kto kod pozna, ma pravo ho v katalogu najst).
        # V naseptavaci je to ale pasca: vykreslila by sa ako bezny vyber
        # a pouzivatel, ktory pozna stary kod, by si do zakazky pridal polozku,
        # ktoru katalog vedie ako UZ NEOBJEDNAVANU.
        #
        # ZAPISOVA cesta (`norm_hardware_manual` / `HardwareCatalog.find`) sa
        # VEDOME NEMENI: polozka, ktora v configu uz je (legacy zakazka,
        # sablona), musi prestavbu prezit — zahodit ju by znamenalo ticho
        # odobrat kus z objednavky.
        #
        # `total` sa znizuje o to, co filter zahodil — inak by ponuka slubovala
        # viac, nez sa da vybrat (zasada „no silent caps" plati aj naopak).
        def drop_inactive(items, total)
          list = Array(items)
          kept = list.reject { |i| i.is_a?(Hash) && i['active'] == false }
          [kept, [total.to_i - (list.length - kept.length), kept.length].max]
        end

        def manual_search_item(item)
          { 'code' => item['item_code'].to_s, 'name_sk' => item['name_sk'].to_s,
            'unit' => item['unit'].to_s, 'category' => item['category'],
            'price_eur_vat' => (item['price_eur_vat'].is_a?(Numeric) ? item['price_eur_vat'].to_f : nil) }
        end

        # Hlaska po zmene setu — rozlisi skrinku a konkretny dielec (D-81).
        def hw_set_status_msg(gt, owner, sid, set_def)
          who = "#{HardwareRules.label_for(gt)}#{owner ? " pre dielec #{owner}" : ''}"
          return "#{who}: set „#{set_def['name']}“." if sid

          owner ? "#{who}: platí výber skrinky/projektu." : "#{who}: platí predvoľba projektu."
        end
      end
    end
  end
end
