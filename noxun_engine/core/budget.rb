# frozen_string_literal: true
# Noxun Engine — V0.6 E-a: ROZPOCET (cisty vypocet zakazky v peniazoch).
#
# CISTA FUNKCIA: (BOM + katalogy + stav zakazky + nastavenia) -> payload.
# Ziadne SketchUp API, ziadne citanie geometrie, ziadny zapis — headless
# testovatelne. UI (tab Rozpocet, E-b) payload LEN ZOBRAZUJE a XLSX export ho
# cita 1:1; ziadny klient si nic neprepocitava (vzor KONTROLA counts).
#
# ============================= PORADIE SEKCII ==========================
#   materials · abs · hardware · services · standard_rows · custom ·
#   appliances (POSLEDNA — casto sa platia osobitne) · rounding · [totals]
#
# ============================ ZAVAZNE KONTRAKTY ========================
# 1) MONTAZ JE LEN NA JEDNOM MIESTE — automaticka sluzba
#    `platne x montaz_m2_per_plate x sadzba`. Standardne riadky montaz
#    NEOBSAHUJU (audit BLOCKER 1: dva zdroje = dvojite uctovanie).
# 2) DUPLAK sa v odhade platni prelieva do ZDROJOVEHO materialu — cena sa
#    viaze na NAKUPNY material_id, nikdy na duplakovy (audit 3). Sluzba
#    "lepenie duplakov" berie doubled_quantity (POCET zlepenych kusov);
#    doubled_m2 uz nasobitel obsahuje a NIKDY sa nenasobi znova (audit 4).
# 3) NEZNAMA CENA sa NIKDY nenahradi nulou (audit 5): riadok nesie
#    price_missing, sekcia unknown_count + complete=false, medzisucet je LEN
#    zo znamych cien a totals.complete o tom hovori nahlas.
# 4) CHYBAJUCI FORMAT PLATNE = odhad bezi na fallbacku 2800x2070, riadok nesie
#    'estimated' + poznamku (audit 3) — cislo sa nikdy netvari isto.
# 5) ZAOKRUHLUJE SA KONECNA BRUTTO SUMA (firma je neplatca DPH, katalogove
#    ceny su konecne) na `rounding_step` nahor; `total_novat` je LEN
#    informativny prepocet /1,23 (audit 8).
# 6) REZIM (nizky|standard|vysoky) je sada DEFAULTOV, nie zamok: prepocita
#    LEN riadky BEZ overridu — rucny override zakazky prezije zmenu rezimu
#    a zrusi sa VYHRADNE explicitnym resetom (audit 6).
require 'time'

module Noxun
  module Engine
    module Budget
      # MJ enum z realnych rozpoctov (syteza §8.1) — 7 hodnot pokryje vsetko.
      MJ_KS    = 'KS'
      MJ_BM    = 'BM'
      MJ_PLATA = 'PLATŇA'
      MJ_M2    = 'M2'
      MJ_FIX   = 'FIX'

      SRC_AUTO     = 'auto'
      SRC_MANUAL   = 'manual'
      SRC_OVERRIDE = 'override'

      # Firma je NEPLATCA DPH — katalogove ceny su konecne (s DPH). Prepocet
      # "bez DPH" je len zobrazenie (prepinac v UI), nikdy zaklad vypoctu.
      VAT_DIVISOR = 1.23

      SECTION_NAMES = {
        'materials' => 'Materiál', 'abs' => 'ABS hrany', 'hardware' => 'Kovanie',
        'services' => 'Služby', 'standard_rows' => 'Štandardné riadky',
        'custom' => 'Vlastné položky', 'appliances' => 'Spotrebiče',
        'rounding' => 'Zaokrúhlenie ponuky'
      }.freeze

      # Automaticke sluzby v poradi zobrazenia + ich MJ a slovensky nazov.
      SERVICE_DEFS = [
        { 'key' => 'olep',           'name' => 'Olepovanie ABS hrán', 'mj' => MJ_BM },
        { 'key' => 'porez',          'name' => 'Porez platní', 'mj' => MJ_PLATA },
        { 'key' => 'duplaky',        'name' => 'Lepenie duplákov', 'mj' => MJ_KS },
        { 'key' => 'pd_opracovanie', 'name' => 'Opracovanie pracovnej dosky', 'mj' => MJ_FIX },
        { 'key' => 'montaz',         'name' => 'Montáž', 'mj' => MJ_M2 }
      ].freeze

      CAT_BUDGET = 'budget' # kategoria KONTROLY (E-b ju zobrazi vedla semaforu)

      module_function

      # =====================================================================
      # HLAVNY VSTUP
      # bom      — vystup Bom.compute (rows/edging/...; symbol aj string kluce)
      # state    — BudgetStore.state(model) (rezim, overridy, nasobky, polozky)
      # settings — SupplierSettings.active (sadzby, standardne riadky, rezimy)
      # sheets/edges — katalogove mapy {id => zaznam} (ceny, formaty, demos vazba)
      # hardware_expansion — HardwareSets.expand (rows s cenami); nil = sekcia
      #   kovania sa vynecha (vzor Validation edges: — legacy volanie bez zmeny)
      # hardware_catalog — polozky katalogu kovania pre scan veku cien; nil =
      #   kovanie sa do scanu cerstvosti nezapocita
      # sheet_estimate — hotovy odhad platni (okno Vyroba ho uz ma); nil =
      #   Budget si ho spocita sam z TYCH ISTYCH dat (jedna autorita cisel)
      # =====================================================================
      def compute(bom, state, settings, sheets: {}, edges: {}, hardware_expansion: nil,
                  hardware_catalog: nil, sheet_estimate: nil, now: nil)
        b = bom.is_a?(Hash) ? bom : {}
        st = normalize_state(state)
        sup = settings.is_a?(Hash) ? settings : SupplierSettings.seed_supplier
        mode = st['mode']
        smap = sheets.is_a?(Hash) ? sheets : {}
        emap = edges.is_a?(Hash) ? edges : {}
        est = sheet_estimate.is_a?(Array) ? sheet_estimate : estimate_for(b, smap)

        materials = materials_section(est, smap)
        abs = abs_section(list(b, :edging), emap, SupplierSettings.scalar(sup, 'abs_reserve_pct'))
        hardware = hardware_section(hardware_expansion, hardware_catalog)
        services = services_section(est, materials, abs, smap, sup, st, mode)
        standard = standard_section(sup, st, mode)
        custom = custom_section(st)
        appliances = appliances_section(st)

        sections = [materials, abs, hardware, services, standard, custom, appliances].compact
        totals, rounding = totals_and_rounding(sections, sup, st)
        sections << rounding

        payload = {
          'mode' => mode,
          'mode_label' => SupplierSettings::MODE_LABELS[mode] || mode,
          'currency' => 'EUR',
          'vat_divisor' => VAT_DIVISOR,
          'sections' => sections,
          'totals' => totals,
          'stale' => stale_scan(est, list(b, :edging), hardware, smap, emap, hardware_catalog,
                                SupplierSettings.scalar(sup, 'stale_days'), now),
          'settings' => {
            'supplier_id' => sup['id'], 'supplier_name' => sup['name'],
            'rounding_step' => SupplierSettings.scalar(sup, 'rounding_step'),
            'abs_reserve_pct' => SupplierSettings.scalar(sup, 'abs_reserve_pct'),
            'stale_days' => SupplierSettings.scalar(sup, 'stale_days'),
            'montaz_m2_per_plate' => SupplierSettings.scalar(sup, 'montaz_m2_per_plate')
          },
          'viz_m2' => st['viz_m2'],
          'appliances_included' => st['appliances_included']
        }
        payload['budget_check'] = check(payload)
        payload
      end

      # Tenka nadstavba pre SketchUp cestu (E-b): stav zo zakazky + globalne
      # nastavenia. Vypocet samotny ostava CISTY.
      def payload_for(model, bom, sheets: {}, edges: {}, hardware_expansion: nil,
                      hardware_catalog: nil, sheet_estimate: nil)
        compute(bom, BudgetStore.state(model), SupplierSettings.active,
                sheets: sheets, edges: edges, hardware_expansion: hardware_expansion,
                hardware_catalog: hardware_catalog, sheet_estimate: sheet_estimate)
      end

      # --- sekcia MATERIAL -----------------------------------------------------

      # Riadok per NAKUPNY material: cele platne x cena za platnu.
      # Cena katalogu je EUR/m2 -> prepocet na platnu ma JEDINU autoritu
      # (price_per_plate), aby sa €/m2 a €/platna nikdy nerozisli.
      def materials_section(estimate, sheets)
        rows = Array(estimate).map do |g|
          next nil unless g.is_a?(Hash)
          mid = g['material_id'].to_s
          rec = sheets[mid].is_a?(Hash) ? sheets[mid] : {}
          plates = plates_of(g)
          sheet_m2 = num(g['sheet_m2'])
          price_m2 = num(rec['price_per_m2'])
          per_plate = price_per_plate(price_m2, sheet_m2)
          notes = []
          size = g['sheet_size']
          notes << "#{fmt(g['m2'])} m²"
          notes << "formát #{fmt_size(size)}" if size.is_a?(Array)
          notes << 'formát platne nie je v katalógu — odhad podľa 2800×2070' if g['fallback'] == true
          notes << 'materiál neurčený (UNI) — počet platní je orientačný' if g['uni'] == true
          if g['doubled_quantity'].to_i.positive?
            notes << "vrátane #{g['doubled_quantity'].to_i} ks duplákov (#{fmt(g['doubled_m2'])} m²)"
          end
          row = base_row(
            key: "material:#{mid}",
            nazov: sheet_label(rec, mid),
            kod: rec['code'], dodavatel: rec['supplier'],
            mj: MJ_PLATA, mnozstvo: plates, cena_mj: per_plate,
            poznamka: notes.join(' · '), zdroj: SRC_AUTO
          )
          row['material_id'] = mid
          row['m2'] = num(g['m2'])
          row['price_per_m2'] = price_m2
          row['estimated'] = (g['fallback'] == true)
          row['uni'] = true if g['uni'] == true
          row
        end.compact
        section('materials', rows)
      end

      # JEDINA konverzia EUR/m2 -> EUR/platna v celom rozpocte.
      def price_per_plate(price_m2, sheet_m2)
        return nil if price_m2.nil? || sheet_m2.nil? || sheet_m2 <= 0
        (price_m2 * sheet_m2).round(2)
      end

      # Cele platne sa NAKUPUJU — pesimisticky odhad (count_max) nahor.
      # round(6) PRED ceil (vzor SheetEstimate.ceil_tenth): 5.000000000000001 by
      # inak nakupil o platnu viac.
      def plates_of(group)
        v = num(group['count_max']) || 0.0
        v <= 0 ? 0 : v.round(6).ceil
      end

      # --- sekcia ABS ----------------------------------------------------------

      def abs_section(edging, edges, reserve_pct)
        pct = num(reserve_pct) || 0.0
        rows = Array(edging).map do |e|
          next nil unless e.is_a?(Hash)
          abs_id = e['abs_id'].to_s
          rec = edges[abs_id].is_a?(Hash) ? edges[abs_id] : {}
          bm = num(e['bm']) || 0.0
          bm_res = (bm * (1.0 + pct / 100.0)).round(2)
          price = num(rec['price_per_bm'])
          row = base_row(
            key: "abs:#{abs_id}",
            nazov: abs_label(rec, abs_id),
            kod: rec['code'], dodavatel: rec['supplier'],
            mj: MJ_BM, mnozstvo: bm_res, cena_mj: price,
            poznamka: "#{fmt(bm)} bm + rezerva #{fmt(pct)} %", zdroj: SRC_AUTO
          )
          row['abs_id'] = abs_id
          row['bm'] = bm
          row['reserve_pct'] = pct
          row
        end.compact
        section('abs', rows)
      end

      # --- sekcia KOVANIE ------------------------------------------------------

      # Prebera HOTOVU expanziu setov (HardwareSets.expand) — rozpocet kovanie
      # NIKDY neexpanduje sam (jedna autorita poctov aj kodov). Dodavatel sa
      # dojoinuje z katalogu (expanzia ho nenesie) — LEN pre export/zobrazenie.
      def hardware_section(expansion, catalog = nil)
        return section('hardware', []) unless expansion.is_a?(Hash)
        lookup = catalog ? hardware_lookup(catalog) : {}
        rows = list(expansion, :rows).map do |r|
          next nil unless r.is_a?(Hash)
          code = r['code'].to_s
          qty = r['quantity'].to_i
          price = r['missing'] == true ? nil : num(r['price_eur_vat'])
          item = lookup[code.downcase]
          row = base_row(
            key: "hw:#{code.downcase}",
            nazov: (r['name_sk'].to_s.strip.empty? ? code : r['name_sk'].to_s),
            kod: code, dodavatel: (item.is_a?(Hash) ? item['supplier'] : nil),
            mj: unit_label(r['unit']), mnozstvo: qty, cena_mj: price,
            poznamka: (r['missing'] == true ? 'kód nie je v katalógu kovania' : nil),
            zdroj: SRC_AUTO
          )
          row['category'] = r['category']
          row
        end.compact
        section('hardware', rows)
      end

      def unit_label(unit)
        u = unit.to_s.strip.downcase
        case u
        when 'set' then 'SET'
        when 'par', 'pár' then 'PÁR'
        when 'bm' then MJ_BM
        when 'm2' then MJ_M2
        else MJ_KS
        end
      end

      # --- sekcia SLUZBY (AUTO) ------------------------------------------------

      # Mnozstva pocita engine z TYCH ISTYCH cisel ako sekcie vyssie:
      #   olep    = bm ABS VRATANE rezervy
      #   porez   = pocet celych platni (sucet materialovych riadkov)
      #   duplaky = POCET zlepenych kusov (doubled_quantity, audit 4)
      #   pd      = fix, ak zakazka obsahuje pracovnu dosku (inak nulovy riadok)
      #   montaz  = platne x m2_na_platnu x sadzba (JEDINE miesto montaze)
      def services_section(estimate, materials, abs, sheets, sup, state, mode)
        plates_total = materials['rows'].sum { |r| r['mnozstvo'].to_i }
        bm_total = abs['rows'].sum { |r| num(r['mnozstvo']) || 0.0 }.round(2)
        doubled = Array(estimate).sum { |g| g.is_a?(Hash) ? g['doubled_quantity'].to_i : 0 }
        pd_count = pd_present?(estimate, sheets) ? 1 : 0
        m2_per_plate = num(SupplierSettings.scalar(sup, 'montaz_m2_per_plate')) || 5.8
        montaz_m2 = (plates_total * m2_per_plate).round(2)

        quantities = {
          'olep' => bm_total, 'porez' => plates_total, 'duplaky' => doubled,
          'pd_opracovanie' => pd_count, 'montaz' => montaz_m2
        }
        notes = {
          'montaz' => "#{plates_total} platní × #{fmt(m2_per_plate)} m²",
          'olep' => 'bm vrátane rezervy',
          'duplaky' => (doubled.positive? ? "#{doubled} ks zlepených dielcov" : nil),
          'pd_opracovanie' => (pd_count.positive? ? nil : 'zákazka neobsahuje pracovnú dosku')
        }
        rows = SERVICE_DEFS.map do |dfn|
          key = dfn['key']
          rate = SupplierSettings.rate(sup, key, mode)
          qty = quantities[key]
          row = base_row(
            key: "service:#{key}",
            nazov: dfn['name'], mj: dfn['mj'], mnozstvo: qty, cena_mj: rate,
            poznamka: notes[key], zdroj: SRC_AUTO
          )
          apply_override(row, state)
        end
        section('services', rows)
      end

      # Pracovna doska v zakazke = aspon jeden POUZITY material kanonickeho
      # typu PD ('PD' je kluc TYPE_REGISTRY; porovnanie je case-insensitive,
      # aby "pd" z rucne upraveneho katalogu neuniklo).
      def pd_present?(estimate, sheets)
        Array(estimate).any? do |g|
          next false unless g.is_a?(Hash)
          rec = sheets[g['material_id'].to_s]
          rec.is_a?(Hash) && rec['type'].to_s.strip.upcase == 'PD'
        end
      end

      # --- sekcia STANDARDNE RIADKY -------------------------------------------

      # 8 fixnych koncovych riadkov. Nasobok = skala zakazky (0/0,2/0,5/1/2/4),
      # sadzba moze byt rezimova. Riadok s nasobkom 0 OSTAVA VIDITELNY
      # (kontrolny zoznam ~13 % riadkov realnych rozpoctov).
      def standard_section(sup, state, mode)
        rows = SupplierSettings.standard_rows(sup).map do |rdef|
          key = "std:#{rdef['key']}"
          mult = state['std_multipliers'].key?(key) ? state['std_multipliers'][key] : num(rdef['default_multiplier'])
          mult = 0.0 if mult.nil?
          rate = SupplierSettings.row_rate(sup, rdef, mode)
          per_m2 = rdef['kind'] == 'per_m2'
          missing_m2 = false
          if per_m2
            m2 = state['viz_m2']
            if m2.nil?
              # Bez m2 z meracky sa suma NEDA vypocitat — ale len ked sa riadok
              # vobec uctuje (nasobok > 0). Pri nasobku 0 je to cisty nulovy
              # riadok (ostava viditelny ako kontrola).
              missing_m2 = mult.positive?
              qty = missing_m2 ? nil : 0.0
              note = missing_m2 ? 'chýbajú m² z meračky' : 'nepočíta sa (násobok 0)'
            else
              qty = (m2 * mult).round(2)
              note = "#{fmt(m2)} m² × násobok #{fmt(mult)}"
            end
          else
            qty = mult
            note = nil
          end
          row = base_row(
            key: key, nazov: rdef['name'], mj: (per_m2 ? MJ_M2 : MJ_FIX),
            mnozstvo: qty, cena_mj: rate, poznamka: note, zdroj: SRC_AUTO
          )
          row['kind'] = rdef['kind']
          row['multiplier'] = mult
          row['rate'] = rate
          if missing_m2
            row['price_missing'] = true
            row['missing_m2'] = true
          end
          apply_override(row, state)
        end
        section('standard_rows', rows)
      end

      # --- sekcie VLASTNE POLOZKY a SPOTREBICE --------------------------------

      def custom_section(state)
        rows = Array(state['custom_items']).map do |it|
          qty = it['pocet'].to_i
          qty = 1 if qty < 1
          row = base_row(
            key: "custom:#{it['id']}", nazov: it['popis'].to_s, kod: it['kod'],
            mj: MJ_KS, mnozstvo: qty, cena_mj: num(it['cena']),
            poznamka: it['poznamka'], zdroj: SRC_MANUAL, cp_skupina: it['cp_skupina']
          )
          row['id'] = it['id']
          row['url'] = it['url'] if it['url']
          row['missing_name'] = true if it['popis'].to_s.strip.empty?
          row
        end
        section('custom', rows)
      end

      # Spotrebice su POSLEDNA sekcia a do SPOLU vstupuju LEN ked je zapnuty
      # prepinac (default VYPNUTY — casto sa platia osobitne, mock v4).
      def appliances_section(state)
        rows = Array(state['appliances']).map do |it|
          row = base_row(
            key: "appliance:#{it['id']}",
            nazov: appliance_name(it), dodavatel: it['dodavatel'],
            mj: MJ_KS, mnozstvo: 1, cena_mj: num(it['cena']),
            zdroj: SRC_MANUAL, cp_skupina: it['cp_skupina']
          )
          row['id'] = it['id']
          row['typ'] = it['typ']
          row['typ_label'] = BudgetStore::APPLIANCE_LABELS[it['typ']] || it['typ']
          row['url'] = it['url'] if it['url']
          row
        end
        sec = section('appliances', rows)
        sec['counts_in_total'] = state['appliances_included'] == true
        sec['included'] = state['appliances_included'] == true
        sec
      end

      def appliance_name(item)
        name = item['nazov'].to_s.strip
        label = BudgetStore::APPLIANCE_LABELS[item['typ']] || item['typ'].to_s
        name.empty? ? label.to_s : name
      end

      # --- sucty a zaokruhlenie ------------------------------------------------

      # Zaokruhluje sa KONECNA BRUTTO suma (audit 8) — nikdy jednotlive riadky.
      def totals_and_rounding(sections, sup, _state)
        counting = sections.select { |s| s['counts_in_total'] }
        raw = counting.sum { |s| s['subtotal'].to_f }.round(2)
        step = num(SupplierSettings.scalar(sup, 'rounding_step')) || 1.0
        rounded = ceil_to(raw, step)
        diff = (rounded - raw).round(2)
        rounding = section('rounding', [base_row(
          key: 'rounding', nazov: 'Zaokrúhlenie ponuky', mj: MJ_FIX, mnozstvo: 1,
          cena_mj: diff, poznamka: "na #{fmt(step)} € nahor", zdroj: SRC_AUTO
        )])
        unknown_all = sections.sum { |s| s['unknown_count'].to_i }
        unknown_in_total = counting.sum { |s| s['unknown_count'].to_i }
        totals = {
          'raw_total' => raw,
          'rounding' => diff,
          'rounding_step' => step,
          'total' => rounded,
          'total_novat' => (rounded / VAT_DIVISOR).round(2),
          'unknown_count' => unknown_all,
          'unknown_count_in_total' => unknown_in_total,
          'complete' => unknown_in_total.zero?,
          'appliances_included' => sections.any? { |s| s['key'] == 'appliances' && s['included'] },
          'appliances_subtotal' => (sections.find { |s| s['key'] == 'appliances' } || {})['subtotal'].to_f,
          'subtotals' => sections.each_with_object({}) { |s, out| out[s['key']] = s['subtotal'] }
        }
        totals['subtotals']['rounding'] = diff
        [totals, rounding]
      end

      def ceil_to(value, step)
        return value.round(2) if step.nil? || step <= 0
        ((value / step).round(6).ceil * step).round(2)
      end

      # --- vek cien (cenova cerstvost) -----------------------------------------

      # Scan LEN nad polozkami POUZITYMI v tomto rozpocte (audit 11). Tri stavy:
      #   stale      — viazana na Demos, cena overena skor ako pred stale_days
      #   unverified — viazana, ale bez datumu overenia
      #   manual     — neviazana polozka (nikdy nie je "stara", len rucna)
      def stale_scan(estimate, edging, hardware, sheets, edges, hardware_catalog, stale_days, now)
        days = (num(stale_days) || 30).to_i
        ref = now.is_a?(Time) ? now : Time.now.utc
        items = []
        Array(estimate).each do |g|
          mid = g.is_a?(Hash) ? g['material_id'].to_s : ''
          rec = sheets[mid]
          items << freshness_item('sheet', mid, sheet_label(rec, mid), rec, days, ref) if rec.is_a?(Hash)
        end
        Array(edging).each do |e|
          aid = e.is_a?(Hash) ? e['abs_id'].to_s : ''
          rec = edges[aid]
          items << freshness_item('edge', aid, abs_label(rec, aid), rec, days, ref) if rec.is_a?(Hash)
        end
        if hardware_catalog
          lookup = hardware_lookup(hardware_catalog)
          Array(hardware['rows']).each do |r|
            code = r['kod'].to_s.downcase
            rec = lookup[code]
            next unless rec.is_a?(Hash)
            items << freshness_item('hardware', r['kod'].to_s, r['nazov'].to_s, rec, days, ref)
          end
        end
        items.compact!
        counts = { 'stale' => 0, 'unverified' => 0, 'manual' => 0, 'fresh' => 0 }
        items.each { |i| counts[i['state']] = counts[i['state']].to_i + 1 }
        { 'stale_days' => days,
          'items' => items.reject { |i| i['state'] == 'fresh' }
                          .sort_by { |i| [-(i['age_days'] || -1), i['kind'], i['id']] },
          'counts' => counts }
      end

      def freshness_item(kind, id, label, rec, stale_days, ref)
        url = rec['demos_url'].to_s.strip
        checked = rec['price_checked_at'].to_s.strip
        state, age = if url.empty?
                       ['manual', nil]
                     elsif checked.empty?
                       ['unverified', nil]
                     else
                       t = parse_time(checked)
                       if t.nil?
                         ['unverified', nil]
                       else
                         d = ((ref - t) / 86_400.0).floor
                         d = 0 if d.negative?
                         [d >= stale_days ? 'stale' : 'fresh', d]
                       end
                     end
        { 'kind' => kind, 'id' => id, 'label' => label, 'state' => state,
          'checked_at' => (checked.empty? ? nil : checked), 'age_days' => age,
          'demos_url' => (url.empty? ? nil : url) }
      end

      def parse_time(value)
        Time.parse(value.to_s).utc
      rescue StandardError
        nil
      end

      def hardware_lookup(catalog)
        out = {}
        if catalog.is_a?(Hash)
          catalog.each { |k, v| out[k.to_s.strip.downcase] = v if v.is_a?(Hash) }
        else
          Array(catalog).each do |item|
            next unless item.is_a?(Hash)
            code = item['item_code'].to_s.strip.downcase
            out[code] = item unless code.empty?
          end
        end
        out
      end

      # --- KONTROLA ROZPOCTU ---------------------------------------------------

      # Ciste upozornenia nad HOTOVYM payloadom (jedny cisla = jedna pravda).
      # Kazde nesie STABILNU identitu — E-b ich zobrazi v pase Rozpoctu aj ako
      # kategoriu "budget" v tabe KONTROLA. NIKDY neblokuju export.
      #
      # VSTUP JE PAYLOAD, nie (model, settings): warningy musia sedet PRESNE s
      # cislami, ktore pouzivatel vidi. Model+nastavenia su len vstupy payloadu
      # (Budget.payload_for) — keby check pocital vlastnu cestu, vznikli by dve
      # pravdy o tom, ktory riadok je neuplny. compute() vysledok rovno prilepi
      # do payload['budget_check'], takze volajuci nemusi volat nic navyse.
      # Do Validation.run sa NEZASAHUJE — integraciu kategorie do KONTROLA tabu
      # rozhodne E-b (tam sa zoznamy spajaju az na urovni okna).
      def check(payload)
        out = []
        sections = Array(payload['sections'])
        sections.each do |sec|
          case sec['key']
          when 'custom'
            sec['rows'].each do |r|
              if r['missing_name']
                out << warn_item("budget|custom:#{r['id']}|missing_name", 'custom', r['key'],
                                 'Vlastná položka bez popisu — doplň názov.')
              end
              if r['price_missing']
                out << warn_item("budget|custom:#{r['id']}|missing_price", 'custom', r['key'],
                                 "Vlastná položka „#{row_title(r)}“ nemá cenu — do súčtu sa nepočíta.")
              end
            end
          when 'appliances'
            sec['rows'].each do |r|
              next unless r['price_missing']
              out << warn_item("budget|appliance:#{r['id']}|missing_price", 'appliances', r['key'],
                               "Spotrebič „#{row_title(r)}“ nemá cenu — do súčtu sa nepočíta.")
            end
            if !sec['included'] && sec['subtotal'].to_f.positive?
              out << warn_item('budget|appliances|not_included', 'appliances', nil,
                               "Spotrebiče (#{fmt(sec['subtotal'])} €) NIE SÚ v súčte — platia sa osobitne?")
            end
          when 'standard_rows'
            sec['rows'].each do |r|
              next unless r['missing_m2']
              out << warn_item('budget|std:vizualizacia|missing_m2', 'standard_rows', r['key'],
                               "Riadok „#{row_title(r)}“ nemá zadané m² — suma sa nedá vypočítať.")
            end
          end
          next unless sec['unknown_count'].to_i.positive?
          out << warn_item("budget|section:#{sec['key']}|incomplete", sec['key'], nil,
                           "#{sec['name']}: #{rows_sk(sec['unknown_count'])} bez ceny — medzisúčet je neúplný.")
        end
        dedup(out)
      end

      def warn_item(stable_key, section, row_key, message)
        { 'severity' => 'orange', 'category' => CAT_BUDGET, 'stable_key' => stable_key,
          'section' => section, 'row_key' => row_key, 'message' => message }
      end

      def dedup(items)
        seen = {}
        out = []
        items.each do |i|
          key = i['stable_key']
          next if seen[key]
          seen[key] = true
          out << i
        end
        out
      end

      def row_title(row)
        t = row['nazov'].to_s.strip
        t.empty? ? '(bez názvu)' : t
      end

      # Slovenske sklonovanie v hlaskach KONTROLY (1 riadok / 2 riadky / 5 riadkov).
      def rows_sk(count)
        n = count.to_i
        return "#{n} riadok" if n == 1
        return "#{n} riadky" if n >= 2 && n <= 4
        "#{n} riadkov"
      end

      # --- spolocne stavebne kamene -------------------------------------------

      # Kazdy riadok nesie POLIA PRE EXPORT (audit 12) — XLSX/CSV ich cita 1:1
      # a nic si nedopocitava: nazov · kod · dodavatel · mj · mnozstvo ·
      # cena_mj · spolu · poznamka · zdroj · cp_skupina.
      def base_row(key:, nazov:, mj:, mnozstvo:, cena_mj:, kod: nil, dodavatel: nil,
                   poznamka: nil, zdroj: SRC_AUTO, cp_skupina: nil)
        qty = mnozstvo.is_a?(Integer) ? mnozstvo : num(mnozstvo)
        price = num(cena_mj)
        spolu = (qty.nil? || price.nil?) ? nil : (qty * price).round(2)
        {
          'key' => key.to_s,
          'nazov' => nazov.to_s,
          'kod' => opt(kod),
          'dodavatel' => opt(dodavatel),
          'mj' => mj,
          'mnozstvo' => qty,
          'cena_mj' => price,
          'spolu' => spolu,
          'spolu_auto' => spolu,
          'poznamka' => opt(poznamka),
          'zdroj' => zdroj,
          'cp_skupina' => (opt(cp_skupina) || BudgetStore::DEFAULT_CP_GROUP),
          'price_missing' => price.nil?
        }
      end

      # Rucny prepis AUTO riadku: payload nesie OBE sumy (UI ukaze povodnu
      # precarknutu). Override PREZIJE zmenu rezimu — rezim prepocita LEN
      # riadky bez neho (audit 6).
      def apply_override(row, state)
        ov = state['overrides'][row['key']]
        return row if ov.nil?
        row['spolu'] = num(ov)
        row['zdroj'] = SRC_OVERRIDE
        row['override'] = num(ov)
        row['price_missing'] = false
        row['missing_m2'] = false if row.key?('missing_m2')
        row
      end

      # Medzisucet je LEN zo ZNAMYCH cien; neuplnost sa nikdy neskryva.
      def section(key, rows)
        unknown = rows.count { |r| r['price_missing'] }
        subtotal = rows.sum { |r| r['spolu'].nil? ? 0.0 : r['spolu'].to_f }.round(2)
        { 'key' => key, 'name' => SECTION_NAMES[key] || key, 'rows' => rows,
          'subtotal' => subtotal, 'unknown_count' => unknown,
          'complete' => unknown.zero?, 'counts_in_total' => true }
      end

      def normalize_state(state)
        s = state.is_a?(Hash) ? state : {}
        mode = s['mode'].to_s
        mode = SupplierSettings::DEFAULT_MODE unless SupplierSettings::MODES.include?(mode)
        { 'mode' => mode,
          'overrides' => (s['overrides'].is_a?(Hash) ? s['overrides'] : {}),
          'std_multipliers' => (s['std_multipliers'].is_a?(Hash) ? s['std_multipliers'] : {}),
          'viz_m2' => num(s['viz_m2']),
          'custom_items' => Array(s['custom_items']).select { |i| i.is_a?(Hash) },
          'appliances' => Array(s['appliances']).select { |i| i.is_a?(Hash) },
          'appliances_included' => (s['appliances_included'] == true) }
      end

      def estimate_for(bom, sheets)
        sizes = {}
        uni = {}
        sheets.each do |id, rec|
          next unless rec.is_a?(Hash)
          sizes[id] = rec['sheet_size']
          uni[id] = true if rec['uni'] == true
        end
        SheetEstimate.estimate(list(bom, :rows), sheet_sizes: sizes, uni_ids: uni)
      end

      # --- popisky a formatovanie ---------------------------------------------

      def sheet_label(rec, id)
        return id.to_s unless rec.is_a?(Hash)
        parts = [rec['decor'].to_s.strip, rec['type'].to_s.strip]
        th = num(rec['thickness'])
        parts << "#{fmt(th)} mm" if th && th.positive?
        label = parts.reject(&:empty?).join(' ').strip
        label.empty? ? id.to_s : label
      end

      def abs_label(rec, id)
        return id.to_s unless rec.is_a?(Hash)
        parts = ['ABS', rec['decor'].to_s.strip]
        w = num(rec['width'])
        th = num(rec['thickness'])
        dims = [w && w.positive? ? fmt(w) : nil, th && th.positive? ? fmt(th) : nil].compact
        parts << "#{dims.join('×')} mm" unless dims.empty?
        label = parts.reject { |p| p.to_s.strip.empty? }.join(' ').strip
        label.empty? ? id.to_s : label
      end

      def list(hash, key)
        v = hash[key] || hash[key.to_s]
        v.is_a?(Array) ? v : []
      end

      def opt(value)
        v = value.to_s.strip
        v.empty? ? nil : v
      end

      def num(v)
        return nil if v.nil?
        return nil if v.is_a?(String) && v.strip.empty?
        f = Float(v.to_s.tr(',', '.'))
        f.finite? ? f : nil
      rescue StandardError
        nil
      end

      # Cisla do POZNAMOK (nie do vypoctu) — cele cislo bez desatinnej nuly,
      # desatinna CIARKA (slovenske UI).
      def fmt(v)
        f = num(v)
        return '?' if f.nil?
        return f.round.to_s if f == f.round
        format('%.2f', f).sub(/0$/, '').tr('.', ',')
      end

      def fmt_size(size)
        return '?' unless size.is_a?(Array) && size.length == 2
        "#{fmt(size[0])}×#{fmt(size[1])} mm"
      end
    end
  end
end
