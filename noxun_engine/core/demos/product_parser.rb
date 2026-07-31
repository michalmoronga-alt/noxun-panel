# frozen_string_literal: true
# Noxun Engine — V0.6-B: parser produktovej stranky demos-trade.sk.
#
# CISTY modul (ziadny SketchUp, ziadna siet) — testuje sa headless nad HTML
# fixtures (tests/fixtures/demos/*.html). Server-rendered Shopsys HTML sa
# parsuje regexmi (nokogiri v SketchUp Ruby nie je); parser je TOLERANTNY na
# chybajuce bloky (pole nil + warning), ale PRISNY na zapis: volajuci smie
# cenu/kod pouzit len pri overenej identite (audit B5/F9 — identity_match?).
#
# Ceny: PRIMARNA je hodnota S DPH (rozhodnutie Michal 31.7. — katalog eviduje
# ceny s DPH ako Demos). Stranka uvadza obe ("106,31 EUR" + "130,76 EUR s DPH");
# ak by s DPH chybala, prepocet z bez DPH sa NEROBI potichu — vrati sa
# no-vat hodnota s warningom a volajuci ju smie ponuknut len vypnutu (F9).
#
# Jednotky (audit B3): "Zakladna cena za ks/m/m2/bal" — parser vracia RAW cenu
# + jednotku; prepocet na katalogove EUR/m2 (dosky) / EUR/bm (ABS) robi
# price_for_catalog s plochou z formatu. Neznama jednotka => nil (nezapisovat).

module Noxun
  module Engine
    module DemosProductParser
      # Unicode medzery, ktore Demos HTML realne miesa (NBSP, thin space,
      # narrow NBSP) — explicitne escapy, ziadne neviditelne znaky v kode.
      UNICODE_SPACES = "   ".freeze

      module_function

      # HTML -> {ok:, code:, title:, brand:, unit:, price_vat:, price_no_vat:,
      #          params: {decor:, structure:, format:, thickness:, pd_type:,
      #          decor_name:}, related: [{name:, code:, url:, price_vat:,
      #          price_no_vat:}], warnings: []}
      # ok = stranka vyzera ako produktovy detail (ma kod sortimentu) — NIE
      # "identita sedi" (to posudzuje volajuci cez identity_match?).
      def parse(raw_html)
        html = normalize_html(raw_html)
        out = { 'ok' => false, 'warnings' => [] }
        code = capture(html, /Kód sortimentu\s*<\/span>\s*<strong[^>]*>\s*(\d+)\s*</m)
        out['code'] = code
        unless code
          out['warnings'] << 'stránka nemá Kód sortimentu — nie je to produktový detail'
          return out
        end
        out['ok'] = true
        out['title'] = capture(html, /<h1[^>]*>\s*([^<]+?)\s*<\/h1>/m)
        parse_main_price(html, out)
        out['params'] = parse_params(html)
        out['brand'] = capture(html, /Značka\s*<\/t[dh]>\s*<td[^>]*>\s*([^<]+?)\s*</m) ||
                       capture(html, /Značka<\/dt>\s*<dd[^>]*>\s*([^<]+?)\s*</m)
        out['related'] = parse_related(html, out['warnings'])
        out
      end

      # "Zakladna cena za ks" blok: prva suma = bez DPH, druha (pri "s DPH") = s DPH.
      def parse_main_price(html, out)
        m = html.match(%r{Základná cena za\s*(\S+)\s*</dt>\s*<dd>(.*?)</dd>}m)
        unless m
          out['warnings'] << 'cenový blok sa nenašiel'
          return
        end
        out['unit'] = m[1].to_s.strip
        prices = m[2].scan(/(\d[\d ]*,\d+|\d[\d ]*)\s*EUR/).flatten.map { |v| num(v) }.compact
        vat_flag = m[2].include?('s DPH')
        case prices.length
        when 0
          out['warnings'] << 'cenový blok bez čísel'
        when 1
          if vat_flag
            out['price_vat'] = prices[0]
          else
            out['price_no_vat'] = prices[0]
            out['warnings'] << 'cena s DPH chýba — k dispozícii len základ bez DPH'
          end
        else
          out['price_no_vat'] = prices[0]
          out['price_vat'] = prices[1]
        end
      end

      # Tabulka Parameter/Hodnota -> normalizovane kluce identity.
      def parse_params(html)
        pairs = html.scan(%r{<tr>\s*<td>\s*(.*?)\s*</td>\s*<td>\s*(.*?)\s*</td>\s*</tr>}m)
        map = {}
        pairs.each do |k, v|
          key = strip_tags(k)
          val = strip_tags(v)
          next if key.empty? || val.empty?
          map[key] = val unless map.key?(key) # desktop kopia vyhrava, mobil duplikat sa ignoruje
        end
        {
          'decor' => map['Číslo dekoru'],
          'decor_name' => map['Názov dekoru'],
          'structure' => map['Štruktúra materiálu'],
          'format' => parse_format(map['Formát materiálu (mm)']),
          'thickness' => num(map['Hrúbka materiálu (mm)']),
          'pd_type' => map['Typ pracovnej dosky']
        }
      end

      # "4100 x 600" -> [4100.0, 600.0] (aj x/unicode krizik, aj medzery v cislach).
      def parse_format(text)
        return nil unless text
        m = text.match(/(\d[\d ]*(?:,\d+)?)\s*[x×]\s*(\d[\d ]*(?:,\d+)?)/)
        return nil unless m
        l = num(m[1])
        w = num(m[2])
        l && w ? [l, w] : nil
      end

      # "Suvisiaci sortiment": riadky <tr class="list-products-line__item">
      # s bunkou kodu <a href=URL class="in-code">KOD</a> — kod sa cita VYHRADNE
      # z in-code linku (ziadne volne cisla zo stranky). Stranka ma DESKTOP aj
      # MOBILNU kopiu tych istych riadkov (audit F8) — dedup podla kod+URL;
      # ten isty kod s ROZNOU cenou / na roznych URL = warning + vyradenie.
      def parse_related(html, warnings)
        rows = {}
        conflicted = {}
        html.scan(%r{<tr[^>]*class="[^"]*list-products-line__item(?!--heading)[^"]*"[^>]*>(.*?)</tr>}m) do |(row)|
          next if row.include?('list-products-line__item__cell--title">') && !row.include?('in-code')
          code_m = row.match(%r{<a\s+href="(https?://www\.demos-trade\.sk/[^"]+)"[^>]*class="in-code"[^>]*>\s*(\d{3,8})\s*</a>})
          next unless code_m
          name_m = row.match(%r{__cell--title[^>]*>\s*(?:<a[^>]*>)?\s*([^<]{3,180}?)\s*<}m)
          prices = row.scan(/(\d[\d ]*,\d+|\d[\d ]*)\s*EUR/).flatten.map { |v| num(v) }.compact
          vat_flag = row.include?('s DPH')
          # Desktop kopia riadku ma OBE ceny (bez + s DPH), mobilna len jednu
          # (s DPH) — jedina cena s priznakom s DPH NEsmie skoncit v no_vat.
          no_vat, vat = if prices.length >= 2
                          [prices[0], (prices[1] if vat_flag)]
                        elsif vat_flag
                          [nil, prices[0]]
                        else
                          [prices[0], nil]
                        end
          name = name_m ? strip_tags(name_m[1]) : ''
          url = code_m[1].split('?').first
          # Title bunka byva graficky link — citatelny nazov sa vezme zo slugu.
          name = url.split('/').reject(&:empty?).last.to_s.tr('-', ' ') if name.empty?
          rec = { 'name' => name, 'code' => code_m[2], 'url' => url,
                  'price_no_vat' => no_vat, 'price_vat' => vat }
          key = "#{rec['code']}|#{rec['url']}"
          if (prev = rows[key])
            # Kopie sa MERGUJU: desktop nesie obe ceny, mobil len s DPH — nil sa
            # doplna; konflikt je LEN realne rozdielna vyplnena hodnota.
            %w[price_no_vat price_vat].each do |f|
              if rec[f] && prev[f] && (rec[f] - prev[f]).abs > 0.005
                conflicted[key] = true
              elsif rec[f] && prev[f].nil?
                prev[f] = rec[f]
              end
            end
          else
            rows[key] = rec
          end
        end
        conflicted.each_key do |key|
          warnings << "položka #{rows[key]['code']} má na stránke dve rôzne ceny — vyradená z ponuky"
          rows.delete(key)
        end
        # Jeden kod = jedna URL; kolizia znamena necakany tvar stranky (F8).
        rows.values.group_by { |r| r['code'] }.select { |_, v| v.length > 1 }.each do |code, v|
          warnings << "kód #{code} sa objavil pri #{v.length} rôznych URL — vyradený"
          v.each { |r| rows.delete("#{r['code']}|#{r['url']}") }
        end
        rows.values
      end

      # --- identity verify (audit B5): parsovana stranka vs katalogovy zaznam --
      # PLNA identita: cislo dekoru (povinne), struktura, hrubka, format (pri
      # typoch s formatom v identite) — cez kanonicke normalizacie Materials.
      # Zastena rub a ABS strukturu nad RELATED polozkami riesi B-2 apply; TU
      # sa overuje HLAVNY produkt stranky proti cielovemu zaznamu.
      def identity_match?(parsed, sheet_record)
        p = parsed['params'] || {}
        return false unless p['decor'] &&
                            Materials.identity_norm(p['decor']) == Materials.identity_norm(sheet_record['decor'])
        if p['structure'] && !sheet_record['structure'].to_s.strip.empty? &&
           Materials.identity_norm(p['structure']) != Materials.identity_norm(sheet_record['structure'])
          return false
        end
        if p['thickness'] && sheet_record['thickness'] &&
           (Materials.thickness_key(p['thickness']) - Materials.thickness_key(sheet_record['thickness'])).abs > 0.011
          return false
        end
        if Materials.format_in_identity?(sheet_record['type']) && p['format'] &&
           (want = Materials.size_key(sheet_record['sheet_size']))
          return false unless Materials.size_key(p['format']) == want
        end
        true
      end

      # --- jednotkova konverzia na katalogovu cenu (audit B3) ------------------
      # kind: 'sheet' (EUR/m2) | 'edge' (EUR/bm). price je S DPH (primarna mena
      # katalogu). Vrati Float alebo nil (neznama jednotka / chybajuce data —
      # cena sa NEPONUKA na zapis).
      def price_for_catalog(price, unit, kind, format_mm)
        return nil unless price.is_a?(Numeric) && price.positive?
        u = unit.to_s.strip.downcase.sub("²", '2')
        case kind
        when 'edge'
          # ABS sa predava na metre — EUR/m == EUR/bm.
          %w[m bm].include?(u) ? price.round(4) : nil
        when 'sheet'
          case u
          when 'm2' then price.round(4)
          when 'ks'
            return nil unless format_mm.is_a?(Array) && format_mm.length == 2
            area = format_mm[0].to_f * format_mm[1].to_f / 1_000_000.0
            area.positive? ? (price / area).round(4) : nil
          when 'm'
            # cena za bezny meter dosky => / sirka v metroch
            return nil unless format_mm.is_a?(Array) && format_mm.length == 2
            width_m = format_mm[1].to_f / 1000.0
            width_m.positive? ? (price / width_m).round(4) : nil
          end
        end
      end

      # --- normalizacia (audit F10) --------------------------------------------

      # Encoding fix + HTML entity + zjednotenie unicode medzier na obycajne.
      def normalize_html(raw)
        html = raw.to_s.dup.force_encoding('UTF-8')
        html = html.encode('UTF-8', invalid: :replace, undef: :replace, replace: '') unless html.valid_encoding?
        html = html.gsub('&nbsp;', ' ').gsub('&amp;', '&').gsub('&quot;', '"')
                   .gsub('&#39;', "'").gsub('&lt;', '<').gsub('&gt;', '>')
        html.tr(UNICODE_SPACES, '   ')
      end

      def strip_tags(text)
        text.to_s.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip
      end

      def capture(html, regex)
        m = html.match(regex)
        m && m[1] ? m[1].strip : nil
      end

      # "1 234,56" (aj s medzerami v tisicoch) -> Float; nil pri necisle.
      def num(text)
        return nil if text.nil?
        s = text.to_s.tr(UNICODE_SPACES, '').delete(' ').tr(',', '.')
        return nil unless s.match?(/\A\d+(\.\d+)?\z/)
        s.to_f
      end
    end
  end
end
