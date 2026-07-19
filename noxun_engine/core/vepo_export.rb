# frozen_string_literal: true
# Noxun Engine — V0.5 C: VEPO CSV export PRIAMO z BOM riadkov (bez OCL medzikroku).
# Zdroj pravdy formatu: SYSTEM/03_VYSTUP_vepo_kontrakt.md (reverz funkcneho vepo_exporter).
#
# SEMANTIKA ROZMEROV (build_plan.rb, zavazne): BOM nesie HOTOVE rozmery dielca
# (s nalepenym ABS). VEPO dostava CISTY PRIREZ — odpocet hrubok ABS pasok:
#   L1/L2 (pozdlzne hrany, lezia na dlzke)  -> odpocet zo SIRKY
#   W1/W2 (priecne hrany, lezia na sirke)   -> odpocet z DLZKY
# Rotacia dekoru (grain 'width') sa robi PRED odpoctom: swap dlzka<->sirka
# A ZAROVEN swap dvojic hran (L<->W) — odpocty ostanu na spravnych stranach.
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

      # Cisty prirez [dlzka, sirka] po odpocte ABS hrubok; [nil, dovod] pri chybe.
      def cut_dimensions(row, edge_thicknesses)
        e = row['edges'] || {}
        take = lambda do |code|
          id = e[code]
          next 0.0 if id.nil? || id.to_s.empty?
          th = edge_thicknesses[id]
          return nil if th.nil?
          th.to_f
        end
        l1 = take.call('L1'); return [nil, "neznáma ABS #{e['L1']}"] if l1.nil?
        l2 = take.call('L2'); return [nil, "neznáma ABS #{e['L2']}"] if l2.nil?
        w1 = take.call('W1'); return [nil, "neznáma ABS #{e['W1']}"] if w1.nil?
        w2 = take.call('W2'); return [nil, "neznáma ABS #{e['W2']}"] if w2.nil?
        len = row['length'].to_f - w1 - w2
        wid = row['width'].to_f - l1 - l2
        return [nil, 'prírez po odpočte ABS vychádza nekladný'] if len <= 0 || wid <= 0
        [[len, wid], nil]
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
      def build(rows, project:, materials: {}, edge_thicknesses: {}, warnings: [],
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
          dims, cut_err = cut_dimensions(row, edge_thicknesses)
          if cut_err
            errors << error_entry(raw, cut_err)
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

        total_rows = groups.sum { |g| g['rows'] }
        {
          'project_slug' => pslug, 'groups' => groups, 'errors' => errors,
          'total_rows' => total_rows, 'total_pieces' => groups.sum { |g| g['pieces'] },
          'log_text' => log_text(pslug, project, groups, errors, Array(warnings),
                                 version, generated_at)
        }
      end

      # --- zapis na disk (atomicka vymena davky, Codex B5) -------------------

      # Zapise CELU davku do staging podpriecinka a atomicky vymeni cielovy
      # <dir>/<project_slug>. Cielovy priecinok sa NAHRADI len ak obsahuje
      # vyhradne nase vystupy (*.csv/*.log) — inak zapis odmietne (ochrana
      # pred zmazanim cudzieho priecinka s rovnakym menom).
      def write(result, dir)
        target = File.join(dir, result['project_slug'])
        staging = File.join(dir, ".#{result['project_slug']}.tmp-#{Process.pid}")
        if File.exist?(target)
          foreign = Dir.children(target).reject do |c|
            File.file?(File.join(target, c)) && c =~ /\.(csv|log)\z/i
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
        File.open(File.join(staging, "#{result['project_slug']}_export.log"), 'wb') do |f|
          f.write(result['log_text'])
        end
        FileUtils.rm_rf(target)
        File.rename(staging, target)
        target
      ensure
        FileUtils.rm_rf(staging) if staging && File.exist?(staging)
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

      def log_text(pslug, project, groups, errors, warnings, version, generated_at)
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
        lines << ('-' * 60)
        lines << "Chyby (#{errors.length}):"
        errors.each do |e|
          owners = e['owners'].empty? ? '' : " @ #{e['owners'].join(', ')}"
          lines << "  ! #{e['name']} (#{e['material_id']})#{owners}: #{e['reason']}"
        end
        unless warnings.empty?
          lines << ('-' * 60)
          lines << "Upozornenia stavby (#{warnings.length}):"
          warnings.each do |w|
            msg = w.is_a?(Hash) ? (w['message'] || w['code']) : w
            owner = w.is_a?(Hash) && w['owner_id'] ? " @ #{w['owner_id']}" : ''
            lines << "  ~ #{msg}#{owner}"
          end
        end
        lines.join(CRLF) + CRLF
      end
    end
  end
end
