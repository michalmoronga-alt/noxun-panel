# frozen_string_literal: true
# Noxun Engine — V0.5 C: VEPO CSV export PRIAMO z BOM riadkov (bez OCL medzikroku).
# Zdroj pravdy formatu: SYSTEM/03_VYSTUP_vepo_kontrakt.md (reverz funkcneho vepo_exporter).
#
# SEMANTIKA ROZMEROV (oprava 20.7. po smoke teste — Michal, vlastnik VEPO flow):
# CSV nesie HOTOVE rozmery dielca (presne ako BOM). VEPO system si odpocet
# hrubky ABS robi SAM na zaklade kodov hran (—/=) — preto sa hrany posielaju.
# Ziadna rozmerova aritmetika sa tu NESMIE robit (povodny odpocet z prveho
# navrhu bol omyl standardu — stara linka OCL->vepo_exporter tiez posielala
# hotove/finalne rozmery).
# Rotacia dekoru (grain 'width'): swap dlzka<->sirka A ZAROVEN swap dvojic
# hran (L<->W) — VEPO dostane dlzku pozdlz dekoru so spravnymi kodmi.
#
# Byte-kompatibilita so starym exporterom (Codex audit F6): CSV cez CSV.generate
# s force_quotes + ';' + CRLF (stary CSV.open v textovom mode na Windows pisal
# CRLF), UTF-8 BEZ BOM, em-dash "—" ako UTF-8. LOG rovnako CRLF.
#
# Cisty modul: ziadny SketchUp, ziadne cesty — katalogove lookupy (label materialu,
# hrubky ABS) dostava ako mapy, cas/verziu ako parametre. Zapis na disk robi
# VepoExport.write s atomickou vymenou celej davky (Codex audit B5).
require 'csv'
require 'fileutils'

module Noxun
  module Engine
    module VepoExport
      COMMERCIAL_18 = (18.0..19.1)
      COMMERCIAL_36 = (36.0..38.1)
      EDGE_SINGLE = '—' # em-dash: hrana na JEDNEJ strane dvojice
      EDGE_BOTH   = '='
      NAME_MAX    = 60
      CRLF        = "\r\n"
      # Windows si tieto mena rezervuje ako zariadenia — nesmu byt nazvom priecinka.
      RESERVED = /\A(con|prn|aux|nul|com[1-9]|lpt[1-9])\z/.freeze

      module_function

      # --- ciste stavebne funkcie -------------------------------------------

      # Obchodna hrubka pre VEPO (18/36 pasma, inak zaokruhlenie); nil = chybna.
      def commercial_thickness(t)
        v = t.to_f
        return nil if v <= 0
        return 18 if COMMERCIAL_18.cover?(v)
        return 36 if COMMERCIAL_36.cover?(v)
        v.round
      end

      # Kod dvojice hran z PRITOMNOSTI ABS (nie hrubky): ''/—/=.
      def edge_code(a, b)
        n = [a, b].count { |x| !x.nil? && !x.to_s.empty? }
        n.zero? ? '' : (n == 1 ? EDGE_SINGLE : EDGE_BOTH)
      end

      # Rotacia dekoru: grain 'width' = dekor bezi po sirke -> VEPO chce dlzku
      # pozdlz dekoru, cize swap rozmerov AJ dvojic hran. Vrati novy hash.
      def oriented(row)
        e = row['edges'] || {}
        return row.merge('edges' => e.dup) unless row['grain_direction'].to_s == 'width'
        row.merge(
          'length' => row['width'], 'width' => row['length'],
          'grain_direction' => 'length',
          'edges' => { 'L1' => e['W1'], 'L2' => e['W2'], 'W1' => e['L1'], 'W2' => e['L2'] }
        )
      end

      # HOTOVE rozmery [dlzka, sirka] — ziadny odpocet (VEPO si ABS odratava
      # sam z kodov hran). edge_thicknesses sluzi uz LEN ako integrity check:
      # hrana odkazujuca na ABS mimo katalogu = spinave data -> riadok von
      # s dovodom (radsej neobjednat nez objednat s neistym olepenim).
      def finished_dimensions(row, edge_thicknesses)
        e = row['edges'] || {}
        %w[L1 L2 W1 W2].each do |code|
          id = e[code]
          next if id.nil? || id.to_s.empty?
          return [nil, "neznáma ABS #{id}"] unless edge_thicknesses.key?(id)
        end
        [[row['length'].to_f, row['width'].to_f], nil]
      end

      # Lowercase slug pre nazvy suborov (vzor Materials.slug, ale lowercase):
      # diakritika von (NFD), nealfanumericke -> '_', bez krajnych/dvojitych '_'.
      def slug(value)
        s = value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')
        s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
      end

      # Slug projektu — nikdy prazdny, nikdy Windows-rezervovany (Codex F10).
      def project_slug(project)
        s = slug(project)
        return 'projekt' if s.empty?
        RESERVED.match?(s) ? "projekt_#{s}" : s
      end

      # --- hlavny builder ----------------------------------------------------

      # rows: Bom.compute[:rows] (agregovane vyrobne riadky — uzamknute testom, N12).
      # materials: {material_id => {'label' => String}}; edge_thicknesses: {abs_id => Float}.
      # Vrati: { 'project_slug', 'groups' => [{filename, csv, rows, pieces, material_ids,
      #          material_label, tag}], 'errors' => [{name, reason, owners}],
      #          'log_text', 'total_rows', 'total_pieces' }
      # validation: vysledok Validation.run ({ 'items' => [...], 'counts' => {...} })
      # — sekcia KONTROLA v LOGu vznika z NEHO (nalez 5: ten isty cerstvy vysledok
      # ako status okna). Nahrada za povodny `warnings:` param a sekciu "Upozornenia
      # stavby" (nalez 9: KONTROLA je JEDINY kanonicky zoznam vratane build warnings).
      def build(rows, project:, materials: {}, edge_thicknesses: {}, validation: nil,
                version: '', generated_at: nil, merge_18_36: true)
        pslug = project_slug(project)
        errors = []
        buckets = {} # [label, tag] => {rows:[csv polia], material_ids:Set-like pole, label:, tag:}

        Array(rows).each do |raw|
          reason = validate_row(raw)
          if reason
            errors << error_entry(raw, reason)
            next
          end
          row = oriented(raw)
          dims, dim_err = finished_dimensions(row, edge_thicknesses)
          if dim_err
            errors << error_entry(raw, dim_err)
            next
          end
          commercial = commercial_thickness(row['thickness'])
          if commercial.nil?
            errors << error_entry(raw, "chybná hrúbka #{row['thickness']}")
            next
          end

          label = material_label(row['material_id'], materials)
          tag = merge_18_36 && [18, 36].include?(commercial) ? '18_36' : commercial.to_s
          key = [label, tag]
          b = buckets[key] ||= { rows: [], material_ids: [], label: label, tag: tag, pieces: 0 }
          e = row['edges'] || {}
          qty = row['quantity'].to_i
          b[:rows] << [row_name(raw), dims[0].round, edge_code(e['L1'], e['L2']),
                       dims[1].round, edge_code(e['W1'], e['W2']), commercial, qty, label]
          b[:material_ids] << row['material_id'] unless b[:material_ids].include?(row['material_id'])
          b[:pieces] += qty
        end

        groups = buckets.values.map do |b|
          base = slug(b[:label])
          base = slug(b[:material_ids].first) if base.empty?
          base = 'material' if base.empty?
          csv = CSV.generate(col_sep: ';', force_quotes: true, row_sep: CRLF) do |out|
            b[:rows].each { |r| out << r }
          end
          { 'filename' => "#{pslug}_#{base}_#{b[:tag]}.csv", 'csv' => csv,
            'rows' => b[:rows].length, 'pieces' => b[:pieces],
            'material_ids' => b[:material_ids], 'material_label' => b[:label], 'tag' => b[:tag] }
        end.sort_by { |g| g['filename'] }
        dedup_filenames!(groups)

        total_rows = groups.sum { |g| g['rows'] }
        {
          'project_slug' => pslug, 'groups' => groups, 'errors' => errors,
          'total_rows' => total_rows, 'total_pieces' => groups.sum { |g| g['pieces'] },
          'log_text' => log_text(pslug, project, groups, errors, validation,
                                 version, generated_at)
        }
      end

      # --- zapis na disk (atomicka vymena davky, Codex B5) -------------------

      # Zapise CELU davku do staging podpriecinka a vymeni cielovy
      # <dir>/<project_slug> dvojkrokovym swapom (GH P2: stary export prezije,
      # kym novy nie je NA MIESTE — pri zlyhani rename sa stary vrati spat).
      # Cielovy priecinok sa NAHRADI len ak obsahuje vyhradne NASE vystupy
      # (presny vzor <slug>_*.csv/.log — GH P2: cudzi supplier.csv nezhori).
      def write(result, dir)
        pslug = result['project_slug']
        target = File.join(dir, pslug)
        staging = File.join(dir, ".#{pslug}.tmp-#{Process.pid}")
        old = File.join(dir, ".#{pslug}.old-#{Process.pid}")
        ours = /\A#{Regexp.escape(pslug)}_.*\.(csv|log)\z/i
        if File.exist?(target)
          foreign = Dir.children(target).reject do |c|
            File.file?(File.join(target, c)) && c.match?(ours)
          end
          unless foreign.empty?
            raise "Priečinok #{target} obsahuje cudzie súbory (#{foreign.first(3).join(', ')}) — vyber iný cieľ."
          end
        end
        FileUtils.rm_rf(staging)
        FileUtils.mkdir_p(staging)
        result['groups'].each do |g|
          File.open(File.join(staging, g['filename']), 'wb') { |f| f.write(g['csv']) }
        end
        File.open(File.join(staging, "#{pslug}_export.log"), 'wb') do |f|
          f.write(result['log_text'])
        end
        FileUtils.rm_rf(old)
        File.rename(target, old) if File.exist?(target)
        begin
          File.rename(staging, target)
        rescue StandardError
          # rollback: stary export sa vrati na miesto, ak novy nedosadol
          File.rename(old, target) if File.exist?(old) && !File.exist?(target)
          raise
        end
        FileUtils.rm_rf(old)
        target
      ensure
        FileUtils.rm_rf(staging) if staging && File.exist?(staging)
      end

      # Unikatne nazvy suborov aj po slugu (GH P1: 'Dub-A' a 'Dub A' by sa
      # zliali do jedneho suboru a druhy zapis by prepisal prvy).
      def dedup_filenames!(groups)
        used = {}
        groups.each do |g|
          fn = g['filename']
          if used[fn]
            base = fn.sub(/\.csv\z/i, '')
            n = 2
            n += 1 while used["#{base}_#{n}.csv"]
            fn = "#{base}_#{n}.csv"
            g['filename'] = fn
          end
          used[fn] = true
        end
        groups
      end

      # --- pomocne -----------------------------------------------------------

      def validate_row(row)
        return 'chýba materiál' if row['material_id'].to_s.strip.empty?
        return 'nekladná dĺžka' if row['length'].to_f <= 0
        return 'nekladná šírka' if row['width'].to_f <= 0
        return 'chybný počet kusov' if row['quantity'].to_i < 1
        nil
      end

      def error_entry(row, reason)
        owners = Array(row['kde']).map { |k| k['owner_id'] }.compact.uniq
        { 'name' => row_name(row), 'reason' => reason,
          'material_id' => row['material_id'].to_s, 'owners' => owners }
      end

      def row_name(row)
        names = Array(row['names']).reject { |n| n.to_s.empty? }
        names = [row['name']] if names.empty? && row['name']
        n = names.compact.join('/')
        n = 'dielec' if n.empty?
        n.length > NAME_MAX ? "#{n[0, NAME_MAX - 1]}…" : n
      end

      # VEPO stlpec material + zaklad nazvu suboru: label z katalogu, fallback id.
      def material_label(material_id, materials)
        rec = materials[material_id]
        label = rec && rec['label'].to_s.strip
        label.nil? || label.empty? ? material_id.to_s : label
      end

      def log_text(pslug, project, groups, errors, validation, version, generated_at)
        lines = []
        lines << 'Noxun Engine — VEPO export LOG'
        lines << "Projekt: #{project} (#{pslug})"
        lines << "Verzia:  #{version}"
        lines << "Dátum:   #{generated_at}"
        lines << ('-' * 60)
        lines << "Skupiny exportu (#{groups.length}):"
        groups.each do |g|
          ids = g['material_ids'].join(', ')
          lines << "  - #{g['filename']} (#{g['rows']} riadkov, #{g['pieces']} ks) [#{ids}]"
        end
        # Chyby = riadky VYRADENE z CSV (chybny material/neznama ABS/hrubka). Ostavaju
        # samostatne od KONTROLY — su o STRATE riadku v exporte, nie o semafore. Nalez 6:
        # ziadna ticha strata riadku, dovod je tu explicitne pomenovany.
        lines << ('-' * 60)
        lines << "Riadky vyradené z CSV (#{errors.length}):"
        errors.each do |e|
          owners = e['owners'].empty? ? '' : " @ #{e['owners'].join(', ')}"
          lines << "  ! #{e['name']} (#{e['material_id']})#{owners}: #{e['reason']}"
        end
        log_control(lines, validation)
        lines.join(CRLF) + CRLF
      end

      # Sekcia KONTROLA — semafor vyroby (nalez 5/9). Vypisuje TEN ISTY cerstvy
      # vysledok Validation.run ako badge/status okna. RED nikdy neblokuje export.
      def log_control(lines, validation)
        items = validation.is_a?(Hash) ? Array(validation['items']) : []
        counts = (validation.is_a?(Hash) && validation['counts'].is_a?(Hash)) ? validation['counts'] : {}
        lines << ('-' * 60)
        lines << "KONTROLA — #{counts['red'].to_i} kritických (RED), #{counts['orange'].to_i} na kontrolu (ORANGE):"
        if items.empty?
          lines << '  (bez nálezov — dáta výroby čisté)'
          return
        end
        items.each do |it|
          mark = it['severity'] == 'red' ? '[RED]   ' : '[ORANGE]'
          lines << "  #{mark} #{it['message_sk']}"
        end
        lines << '  Pozn.: RED je varovanie, export sa neblokuje.'
      end
    end
  end
end
