# frozen_string_literal: true
# Noxun Engine — V0.6 E-b2: CENOVA PONUKA (zakaznicky pohlad na rozpocet).
#
# CISTE FUNKCIE nad HOTOVYM payloadom rozpoctu — ziadne SketchUp API, ziadny
# zapis, ziadny vlastny vypocet cien. CP je VIEW, nie druhy rozpocet.
#
# ======================= ZAVAZNE KONTRAKTY (prieskum 22 dvojic CP↔rozpocet) ===
# 1) SUMA CP == SUMA ROZPOCTU, vzdy a na cent. Riadok "Nábytková zostava" je
#    AUTOMATICKY ZVYSOK (total − Σ ostatnych CP riadkov) — dorovnanie sa nikdy
#    nerobi rucne a nikdy sa nezabudne (v realnych dokumentoch to bola
#    neviditelna rucna operacia).
# 2) FIREWALL: do zakazníckeho dokumentu sa NIKDY nedostane interny pojem
#    (VEPO, POREZ, OLEP, BALNÉ, odvody, duplák, Demos, sadzby, €/bm, €/m²,
#    počty platní), nakupny kod ani material_id. Obrana je TROJITA:
#    (a) do CP idu LEN whitelistovane polia (nazov/cena/mnozstvo/MJ),
#    (b) `clean_label` odstrani kody a ID-podobne tokeny,
#    (c) `firewall_hits` kontroluje VYSLEDNY export (test + status okna).
# 3) Zameranie a Vizualizácie su v CP VZDY 0,00 € (predajny tah — naklad je
#    rozpusteny v zostave). Zvysok kostry kopiruje 39 realnych dokumentov.
# 4) SAMOSTATNY riadok dostane polozka s medzisuctom ≥ `cp_highlight_threshold`
#    — je to NAVRH, nie automat: `cp_overrides` v zakazke ho prebija oboma
#    smermi (zdrojovy kluc = kluc riadku rozpoctu, teda stabilny).
# 5) Do CP smie vstupit LEN riadok, ktory je V SUCTE rozpoctu (`counts_in_total`)
#    — nezapocitane spotrebice sa nikdy nestanu samostatnym riadkom, inak by
#    zostava dorovnavala do zaporu.
require 'time'

module Noxun
  module Engine
    module CpExport
      # --- kostra cenovej tabulky (prieskum §3) --------------------------------
      ASSEMBLY_NAME     = 'Nábytková zostava – plošný a doplnkový materiál'
      ZAMERANIE_NAME    = 'Zameranie'
      VIZUALIZACIE_NAME = 'Vizualizácie a príprava dokumentácie'
      MONTAZ_NAME       = 'Montáž a výroba'
      REZIA_NAME        = 'Prípravné a prevádzkové náklady a kompletačné položky'
      DOPRAVA_NAME      = 'Doprava'
      TOTAL_NAME        = 'SPOLU'

      # Fixny text polozky "Prípravné a prevádzkové náklady" (doslovne z CP).
      REZIA_TEXT = 'Táto položka zahŕňa všetky nevyhnutné náklady súvisiace s realizáciou interiéru, ' \
                   'vrátane prípravných prác, spotrebného a pomocného materiálu, logistiky, konzultácií, ' \
                   'poradenstva, administratívnych prác a ostatných prevádzkových výdavkov potrebných na ' \
                   'zabezpečenie kvalitnej a bezproblémovej realizácie projektu.'

      GROUP_SEPARATE = 'samostatne'
      GROUP_ASSEMBLY = 'zostava'
      GROUPS = [GROUP_SEPARATE, GROUP_ASSEMBLY].freeze

      DEFAULT_THRESHOLD = 150.0

      # Sekcie rozpoctu, z ktorych sa moze stat SAMOSTATNY riadok CP.
      # Sluzby a standardne riadky NIE — tie ma kostra namapovane napevno.
      SEPARABLE_SECTIONS = %w[materials hardware custom appliances].freeze

      # Mapovanie riadkov rozpoctu na fixne riadky kostry (prieskum §4.4).
      MONTAZ_KEYS  = %w[service:montaz].freeze
      REZIA_KEYS   = %w[std:balne std:ostatne std:material_montaz std:odvody].freeze
      DOPRAVA_KEYS = %w[std:doprava_zakaznik std:doprava_vseobecna].freeze

      # MJ pre zakaznika (male pismena ako v realnych dokumentoch). PLATŇA a M2
      # sa VEDOME prekladaju na `set` — pocet platni je interny udaj.
      MJ_LABELS = { 'KS' => 'ks', 'SET' => 'set', 'PÁR' => 'pár', 'BAL' => 'bal',
                    'BM' => 'bm', 'M2' => 'set', 'PLATŇA' => 'set', 'FIX' => 'set' }.freeze

      # Nahradny nazov, ked zaznam v katalogu chyba a ostalo by len ID.
      GENERIC_LABELS = { 'materials' => 'Plošný materiál', 'hardware' => 'Kovanie',
                         'custom' => 'Položka', 'appliances' => 'Spotrebič' }.freeze

      # --- specifikacia (prieskum §2 ② + §7.6) --------------------------------
      CATEGORY_ORDER = %w[
        vnutorne_korpusy chrbty dvierka pracovna_doska zastena dekorativne_panely
        zavesy vysuvy vyklopy uchytky nohy vesiaky osvetlenie ostatne spotrebice
      ].freeze

      CATEGORY_NAMES = {
        'vnutorne_korpusy' => 'VNÚTORNÉ KORPUSY', 'chrbty' => 'CHRBTY SKRINIEK',
        'dvierka' => 'DVIERKA A VIDITEĽNÉ ČASTI', 'pracovna_doska' => 'PRACOVNÁ DOSKA',
        'zastena' => 'ZÁSTENA', 'dekorativne_panely' => 'DEKORATÍVNE PANELY',
        'zavesy' => 'ZÁVESY', 'vysuvy' => 'VÝSUVY', 'vyklopy' => 'VÝKLOPY',
        'uchytky' => 'ÚCHYTKY', 'nohy' => 'REKTIFIKAČNÉ NOHY', 'vesiaky' => 'VEŠIAKY',
        'osvetlenie' => 'LED OSVETLENIE', 'ostatne' => 'OSTATNÉ VYBAVENIE',
        'spotrebice' => 'SPOTREBIČE'
      }.freeze

      # Role dielcov, ktore zakaznik vidi ako "dvierka a viditeľné časti".
      FRONT_ROLES = %w[front_door drawer_front flap cover_panel false_front gola_profile].freeze

      # Kategoria katalogu kovania -> kategoria specifikacie.
      HW_CATEGORY_MAP = {
        'ZAVESY' => 'zavesy', 'VYSUVY' => 'vysuvy', 'VYKLOPY' => 'vyklopy',
        'NOHY' => 'nohy', 'UCHYTKY' => 'uchytky', 'VESIAKY' => 'vesiaky',
        'OSVETLENIE' => 'osvetlenie', 'SPOJOVACI_MATERIAL' => 'ostatne', 'OSTATNE' => 'ostatne'
      }.freeze

      # --- FIREWALL -----------------------------------------------------------
      # Zoznam je zamerne SIROKY: falosny poplach stoji jednu opravu textu,
      # unik interneho pojmu stoji doveryhodnost ponuky. Porovnava sa
      # case-insensitive nad SUROVYM textom bunky.
      BLOCKED_TERMS = [
        'vepo', 'porez', 'olep', 'balné', 'balne', 'odvody', 'duplák', 'duplak',
        'demos', 'sadzb', 'násobok', 'nasobok', 'koeficient', 'marža', 'marza',
        'nákupn', 'nakupn', '€/bm', '€/m²', 'eur/bm', 'eur/m2',
        'spolu celkom', 'doprava všeobecná', 'materiál na montáž', 'ostatné náklady',
        'zaokrúhlenie', 'medzisúčet', 'platň', 'rozpoč'
      ].freeze

      BLOCKED_PATTERNS = [
        /\b\d{6,}\b/,                                        # nakupne kody (6+ cislic)
        /[A-Za-z0-9]{2,}_[A-Za-z0-9]{2,}_[A-Za-z0-9]+/,      # material_id / abs_id token
        /_(?:DTDL|MDF|HDF|PD|KOMPAKT|ZASTENA|ABS)_/i
      ].freeze

      module_function

      # =====================================================================
      # CENOVA TABULKA
      # payload   — vystup Budget.compute (sections + totals)
      # overrides — { zdrojovy_kluc => 'samostatne'|'zostava' } zo zakazky
      # threshold — prah navrhu samostatneho riadku (EUR)
      # =====================================================================
      def cp_rows(payload, overrides: {}, threshold: nil)
        p = payload.is_a?(Hash) ? payload : {}
        sections = Array(p['sections']).select { |s| s.is_a?(Hash) }
        totals = p['totals'].is_a?(Hash) ? p['totals'] : {}
        budget_total = (num(totals['total']) || 0.0).round(2)
        thr = num(threshold)
        thr = DEFAULT_THRESHOLD if thr.nil? || thr.negative?
        ov = normalize_overrides(overrides)

        cands = candidates(sections, ov, thr)
        separate = cands.select { |c| c['state'] == GROUP_SEPARATE }
        fixed = fixed_rows(sections)

        others = (separate.sum { |c| c['amount'].to_f } + fixed.sum { |f| f['cena'].to_f }).round(2)
        assembly = (budget_total - others).round(2)

        rows = [{ 'key' => 'cp:assembly', 'polozka' => ASSEMBLY_NAME, 'cena' => assembly,
                  'mnozstvo' => 1, 'mj' => 'set', 'kind' => 'assembly' }]
        separate.each { |c| rows << item_row(c) }
        rows.concat(fixed)

        cp_total = rows.sum { |r| r['cena'].to_f }.round(2)
        diff = (cp_total - budget_total).round(2)
        { 'rows' => rows,
          'total' => cp_total,
          'total_label' => TOTAL_NAME,
          'budget_total' => budget_total,
          'diff' => diff,
          'consistent' => diff.abs < 0.005,
          'assembly' => assembly,
          'assembly_negative' => assembly < -0.005,
          'threshold' => thr,
          'candidates' => cands,
          'separate_count' => separate.length,
          'rezia_text' => REZIA_TEXT }
      end

      # Tenka nadstavba pre payload rozpoctu — prah vzdy z nastavenia dodavatela.
      def preview(payload, overrides = {}, settings = nil)
        cp_rows(payload, overrides: overrides,
                         threshold: SupplierSettings.scalar(settings, 'cp_highlight_threshold'))
      end

      # Vsetky riadky, ktore SA DAJU zobrazit samostatne (kladna aj zaporna suma —
      # zaporna vlastna polozka je zlava, vzor BELLA). Zoradene od najvacsej sumy.
      def candidates(sections, overrides, threshold)
        out = []
        sections.each do |sec|
          key = sec['key'].to_s
          next unless SEPARABLE_SECTIONS.include?(key)
          next if sec['counts_in_total'] == false # nezapocitane spotrebice do CP nejdu

          Array(sec['rows']).each do |r|
            next unless r.is_a?(Hash)

            amount = num(r['spolu'])
            next if amount.nil? || amount.abs < 0.005

            skey = r['key'].to_s
            next if skey.empty?

            suggested = amount >= threshold
            state = overrides[skey] || (suggested ? GROUP_SEPARATE : GROUP_ASSEMBLY)
            qty, mj = item_units(r, key)
            out << { 'source_key' => skey, 'section' => key, 'label' => item_label(r, key),
                     'amount' => amount.round(2), 'mnozstvo' => qty, 'mj' => mj,
                     'state' => state, 'suggested' => suggested,
                     'overridden' => overrides.key?(skey) }
          end
        end
        out.sort_by { |c| [-c['amount'], c['source_key']] }
      end

      def item_row(cand)
        { 'key' => "cp:item:#{cand['source_key']}", 'polozka' => cand['label'],
          'cena' => cand['amount'], 'mnozstvo' => cand['mnozstvo'], 'mj' => cand['mj'],
          'kind' => 'item', 'source_key' => cand['source_key'], 'suggested' => cand['suggested'] }
      end

      # Kostra: Zameranie a Vizualizácie su VZDY (a vzdy 0), zvysok len ked ma
      # zakazka co ukazat (nulova doprava je v ponuke sum).
      def fixed_rows(sections)
        amounts = row_amounts(sections)
        out = [fixed_row('cp:zameranie', ZAMERANIE_NAME, 0.0, 'set'),
               fixed_row('cp:vizualizacie', VIZUALIZACIE_NAME, 0.0, 'set')]
        [['cp:montaz', MONTAZ_NAME, MONTAZ_KEYS, 'set'],
         ['cp:rezia', REZIA_NAME, REZIA_KEYS, 'set'],
         ['cp:doprava', DOPRAVA_NAME, DOPRAVA_KEYS, 'závoz']].each do |key, name, src, mj|
          value = sum_keys(amounts, src)
          out << fixed_row(key, name, value, mj) unless value.abs < 0.005
        end
        out
      end

      def fixed_row(key, name, amount, mj)
        { 'key' => key, 'polozka' => name, 'cena' => amount.to_f.round(2),
          'mnozstvo' => 1, 'mj' => mj, 'kind' => 'fixed' }
      end

      # Sumy riadkov VSETKYCH zapocitanych sekcii podla kluca riadku rozpoctu.
      def row_amounts(sections)
        out = {}
        sections.each do |sec|
          next if sec['counts_in_total'] == false

          Array(sec['rows']).each do |r|
            next unless r.is_a?(Hash)

            out[r['key'].to_s] = num(r['spolu']) || 0.0
          end
        end
        out
      end

      def sum_keys(amounts, keys)
        keys.sum { |k| amounts[k].to_f }.round(2)
      end

      # Mnozstvo a MJ pre zakaznika. Material ide VZDY ako `1 set` — pocet
      # platni je interny udaj (prieskum §5) a v CP sa nikdy neobjavi.
      def item_units(row, section_key)
        case section_key
        when 'materials'  then [1, 'set']
        when 'appliances' then [1, 'ks']
        when 'hardware'   then [int_qty(row['mnozstvo']), MJ_LABELS[row['mj'].to_s] || 'ks']
        else [int_qty(row['mnozstvo']), 'ks']
        end
      end

      def int_qty(value)
        f = num(value)
        return 1 if f.nil?

        q = f.round
        q < 1 ? 1 : q
      end

      # Obchodny nazov riadku: `cp_nazov` z katalogu > nazov riadku > nahradny
      # nazov sekcie. Cez `clean_label` prejde VZDY (kody a ID sa odstrania).
      def item_label(row, section_key)
        raw = row['cp_nazov'].to_s.strip
        raw = row['nazov'].to_s.strip if raw.empty?
        label = clean_label(raw)
        return label unless label.empty? || id_like?(label)

        GENERIC_LABELS[section_key] || 'Položka'
      end

      # Prazdna hodnota / nezname zaradenie = polozka ostava v zostave.
      def normalize_overrides(raw)
        out = {}
        return out unless raw.is_a?(Hash)

        raw.each do |k, v|
          key = k.to_s.strip
          val = v.to_s.strip
          out[key] = val if !key.empty? && GROUPS.include?(val)
        end
        out
      end

      # =====================================================================
      # SPECIFIKACIA (2. vystup — obchodne nazvy BEZ cien)
      # records — surove zaznamy dielcov z Bom.collect (nesu `role`), nie
      #           agregovane riadky: rola je jediny podklad pre kategoriu.
      # =====================================================================
      def specification(records, sheets: {}, hardware_expansion: nil, budget: nil)
        smap = sheets.is_a?(Hash) ? sheets : {}
        buckets = Hash.new { |h, k| h[k] = [] }

        Array(records).each do |r|
          next unless r.is_a?(Hash)

          mid = r['material_id'].to_s
          next if mid.empty?

          rec = smap[mid]
          buckets[material_category(rec, r['role'])] << material_label(rec, mid)
        end

        Array(hardware_expansion.is_a?(Hash) ? hardware_expansion['rows'] : nil).each do |r|
          next unless r.is_a?(Hash)
          next if r['missing'] == true # bez katalogoveho nazvu ostava len kod — do CP NIKDY

          label = clean_label(r['name_sk'])
          next if label.empty? || id_like?(label)

          buckets[HW_CATEGORY_MAP[r['category'].to_s] || 'ostatne'] << label
        end

        appliance_labels(budget).each { |l| buckets['spotrebice'] << l }

        categories = CATEGORY_ORDER.filter_map do |key|
          items = buckets[key].map { |l| l.to_s.strip }.reject(&:empty?).uniq.sort
          next nil if items.empty?

          { 'key' => key, 'name' => CATEGORY_NAMES[key] || key, 'items' => items }
        end
        { 'categories' => categories, 'item_count' => categories.sum { |c| c['items'].length } }
      end

      # Typ materialu rozhoduje pred rolou (pracovna doska/zastena su nou vzdy),
      # inak rozhoduje rola dielca.
      def material_category(rec, role)
        type = rec.is_a?(Hash) ? rec['type'].to_s.strip.upcase : ''
        return 'pracovna_doska' if %w[PD KOMPAKT].include?(type)
        return 'zastena' if type == 'ZASTENA'

        r = role.to_s.strip
        return 'dvierka' if FRONT_ROLES.include?(r)
        return 'chrbty' if r == 'back'
        return 'dekorativne_panely' if r == 'free_panel'

        'vnutorne_korpusy'
      end

      # Obchodny nazov materialu. `cp_nazov` na zazname ma prednost pred vsetkym
      # (Michal si ho pise sam); fallback sklada dekor · typ · hrubka [· formát].
      def material_label(rec, id)
        return GENERIC_LABELS['materials'] unless rec.is_a?(Hash)

        cp = clean_label(rec['cp_nazov'])
        return cp unless cp.empty?

        decor = [rec['decor'], rec['structure'], rec['decor_name']]
                .map { |v| v.to_s.strip }.reject(&:empty?).join(' ')
        parts = []
        parts << decor unless decor.empty?
        tl = type_label(rec['type'])
        parts << tl unless tl.empty?
        th = num(rec['thickness'])
        parts << "#{fmt(th)} mm" if th && th.positive?
        parts << fmt_size(rec['sheet_size']) if format_in_identity?(rec['type']) && rec['sheet_size'].is_a?(Array)
        label = clean_label(parts.join(' · '))
        label.empty? || id_like?(label) ? GENERIC_LABELS['materials'] : label
      end

      # Ludsky nazov typu z registra materialov (DTDL -> "DTD laminovaná").
      # Neznamy typ ostava tak, ako je zapisany.
      def type_label(type)
        key = type.to_s.strip.upcase
        return '' if key.empty?

        entry = defined?(Materials) ? Materials::TYPE_REGISTRY[key] : nil
        entry.is_a?(Hash) && !entry['label'].to_s.empty? ? entry['label'].to_s : type.to_s.strip
      end

      def format_in_identity?(type)
        entry = defined?(Materials) ? Materials::TYPE_REGISTRY[type.to_s.strip.upcase] : nil
        entry.is_a?(Hash) && entry['format_in_identity'] == true
      end

      # Spotrebice patria do specifikacie LEN ked su sucastou ponuky (rovnaky
      # prepinac ako v sucte rozpoctu — inak by ich zakaznik cakal v cene).
      def appliance_labels(budget)
        return [] unless budget.is_a?(Hash)

        sec = Array(budget['sections']).find { |s| s.is_a?(Hash) && s['key'] == 'appliances' }
        return [] unless sec.is_a?(Hash) && sec['included'] == true

        Array(sec['rows']).filter_map do |r|
          next nil unless r.is_a?(Hash)

          name = clean_label(r['nazov'])
          typ = r['typ_label'].to_s.strip
          label = if name.empty?
                    typ
                  elsif typ.empty? || name.downcase.include?(typ.downcase)
                    name
                  else
                    "#{typ} #{name}"
                  end
          label.strip.empty? ? nil : label.strip
        end
      end

      # =====================================================================
      # FIREWALL
      # =====================================================================

      # Ocisti text pre zakaznika: nakupne kody (6+ cislic) a "Kód …" prefixy
      # prec, biele znaky zjednotene, osamotene oddelovace orezane.
      def clean_label(text)
        s = text.to_s.gsub(/\b\d{6,}\b/, ' ')
        s = s.gsub(/\bk[oó]d\b\s*:?\s*/i, ' ')
        s = s.gsub(/\s+/, ' ').strip
        s.sub(/\A[·\-–—,;:]+\s*/, '').sub(/\s*[·\-–—,;:]+\z/, '').strip
      end

      # "K009_PW_DTDL_18" a spol. — jediny token s podtrznikmi = ID, nie nazov.
      def id_like?(text)
        s = text.to_s.strip
        !s.empty? && !(s =~ /\A[A-Za-z0-9]+(?:_[A-Za-z0-9]+)+\z/).nil?
      end

      # Kontrola HOTOVEHO exportu. -> [{ 'text' =>, 'term' => }]
      def firewall_hits(texts)
        out = []
        Array(texts).each do |raw|
          s = raw.to_s
          next if s.strip.empty?

          low = s.downcase
          BLOCKED_TERMS.each { |t| out << { 'text' => s, 'term' => t } if low.include?(t) }
          BLOCKED_PATTERNS.each { |re| out << { 'text' => s, 'term' => re.source } if s =~ re }
        end
        out
      end

      # --- pomocne -------------------------------------------------------------

      def num(v)
        return nil if v.nil?
        return nil if v.is_a?(String) && v.strip.empty?

        f = Float(v.to_s.tr(',', '.'))
        f.finite? ? f : nil
      rescue StandardError
        nil
      end

      def fmt(v)
        f = num(v)
        return '?' if f.nil?
        return f.round.to_s if f == f.round

        format('%.2f', f).sub(/0$/, '').tr('.', ',')
      end

      def fmt_size(size)
        return '' unless size.is_a?(Array) && size.length == 2

        "#{fmt(size[0])}×#{fmt(size[1])} mm"
      end
    end

    # =======================================================================
    # ZAKAZNICKY XLSX — 2 harky: "Cenová ponuka" + "Špecifikácia"
    # =======================================================================
    # Nepocita NIC: cita hotovy vystup CpExport 1:1 (rovnaky kontrakt ako
    # BudgetXlsx nad payloadom rozpoctu). Ziadne excelovske vzorce — server je
    # jedina autorita cisel.
    module CpXlsx
      PRICE_SHEET = 'Cenová ponuka'
      SPEC_SHEET  = 'Špecifikácia'

      PRICE_HEADERS = ['POLOŽKA', 'CENA (€)', 'MNOŽSTVO', 'MJ'].freeze
      PRICE_COLS = [
        { 'min' => 1, 'max' => 1, 'width' => 52.0 },
        { 'min' => 2, 'max' => 2, 'width' => 14.0 },
        { 'min' => 3, 'max' => 3, 'width' => 11.0 },
        { 'min' => 4, 'max' => 4, 'width' => 9.0 }
      ].freeze

      SPEC_HEADERS = ['KATEGÓRIA', 'ŠPECIFIKÁCIA'].freeze
      SPEC_COLS = [
        { 'min' => 1, 'max' => 1, 'width' => 30.0 },
        { 'min' => 2, 'max' => 2, 'width' => 72.0 }
      ].freeze

      SPEC_INTRO = 'Cenová ponuka zahŕňa nábytkové a technické vybavenie v nasledovnej podobe: ' \
                   'Interiérové vybavenie v dizajne •NOXUN•'

      module_function

      # -> [sheet, sheet] pre XlsxWriter.build_book
      def sheets(cp, spec, project:, now: nil)
        t = now.is_a?(Time) ? now : Time.now
        [price_sheet(cp, project: project, now: t), spec_sheet(spec, project: project, now: t)]
      end

      def price_sheet(cp, project:, now: nil)
        c = cp.is_a?(Hash) ? cp : {}
        t = now.is_a?(Time) ? now : Time.now
        rows = [[XlsxWriter.text(title(project, t), XlsxWriter::S_TITLE)],
                PRICE_HEADERS.map { |h| XlsxWriter.text(h, XlsxWriter::S_HEAD) }]
        Array(c['rows']).each do |r|
          next unless r.is_a?(Hash)

          rows << [XlsxWriter.text(r['polozka'].to_s),
                   XlsxWriter.number(r['cena']),
                   XlsxWriter.number(r['mnozstvo']),
                   XlsxWriter.text(r['mj'].to_s)]
        end
        rows << [XlsxWriter.text(CpExport::TOTAL_NAME, XlsxWriter::S_TEXT_BOLD),
                 XlsxWriter.number(c['total'], XlsxWriter::S_NUM_BOLD)]
        rows << []
        rows << [XlsxWriter.text(CpExport::REZIA_NAME, XlsxWriter::S_TEXT_BOLD)]
        rows << [XlsxWriter.text(c['rezia_text'].to_s.empty? ? CpExport::REZIA_TEXT : c['rezia_text'].to_s)]
        { 'name' => PRICE_SHEET, 'cols' => PRICE_COLS, 'merges' => ['A1:D1'], 'rows' => rows }
      end

      # Kategoria sa pise LEN pri prvej polozke (tak vyzera tabulka v CP).
      def spec_sheet(spec, project:, now: nil)
        s = spec.is_a?(Hash) ? spec : {}
        t = now.is_a?(Time) ? now : Time.now
        rows = [[XlsxWriter.text(title(project, t), XlsxWriter::S_TITLE)],
                [XlsxWriter.text(SPEC_INTRO)],
                SPEC_HEADERS.map { |h| XlsxWriter.text(h, XlsxWriter::S_HEAD) }]
        Array(s['categories']).each do |cat|
          next unless cat.is_a?(Hash)

          Array(cat['items']).each_with_index do |item, i|
            rows << [XlsxWriter.text(i.zero? ? cat['name'].to_s : '', XlsxWriter::S_SECTION),
                     XlsxWriter.text(item.to_s)]
          end
        end
        rows << [XlsxWriter.text('Špecifikácia je zatiaľ prázdna — zákazka neobsahuje dielce ani kovanie.')] if rows.length == 3
        { 'name' => SPEC_SHEET, 'cols' => SPEC_COLS, 'merges' => ['A1:B1'], 'rows' => rows }
      end

      def title(project, now = Time.now)
        name = project.to_s.strip
        name = 'zákazka' if name.empty?
        "CENOVÁ PONUKA #{name} - AKT. #{date_label(now)}"
      end

      def date_label(now = Time.now)
        t = now.is_a?(Time) ? now : Time.now
        "#{t.day}.#{t.month}.#{t.year}"
      end

      def file_name(project, now = Time.now)
        name = project.to_s.strip
        name = 'zakazka' if name.empty?
        safe = "Cenova ponuka #{name} - #{date_label(now)}"
               .gsub(%r{[\\/:*?"<>|]}, '-').gsub(/\s+/, ' ').strip
        "#{safe}.xlsx"
      end

      # Vsetky TEXTOVE bunky harkov — vstup pre firewall (test aj kontrola pred
      # zapisom). Cisla sa nekontroluju (suma nie je interny pojem).
      def text_cells(sheets)
        out = []
        Array(sheets).each do |sh|
          next unless sh.is_a?(Hash)

          out << sh['name'].to_s
          Array(sh['rows']).each do |row|
            Array(row).each do |cell|
              out << cell['v'].to_s if cell.is_a?(Hash) && cell['n'] != true
            end
          end
        end
        out.reject { |t| t.to_s.strip.empty? }
      end
    end
  end
end
