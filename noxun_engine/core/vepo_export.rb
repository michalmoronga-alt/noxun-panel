# frozen_string_literal: true
# Noxun Engine — V0.5 C: VEPO CSV export PRIAMO z BOM riadkov (bez OCL medzikroku).
# Zdroj pravdy formatu: SYSTEM/VEPO_KONTRAKT.md (reverz funkcneho vepo_exporter).
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
# hrubky ABS, dekory dosiek a pasok) dostava ako mapy, cas/verziu ako parametre.
# Zapis na disk robi VepoExport.write s atomickou vymenou celej davky (Codex audit B5).
#
# KONTRAKT v1.1 (D-112, 3.9.2026): CSV ma DEVIATY stlpec `poznamka`. Je VZDY
# pritomny (prazdny retazec, ked riadok poznamku nema) a nesie ABS pasky, ktorych
# DEKOR sa lisi od dekoru dosky — presne ten udaj, ktory sa do objednavky VEPO
# prepisuje rucne do pola "Poznamka pre VEPO" (Michal na nom pri zakazke KLINIKA
# zabudol). Overene importom 3.9.2026: VEPO 9-stlpcovy subor prijal a poznamku
# zobrazilo pri riadku (na nalepky nejde). Vsetko ostatne bajtovo ako v1.0.
#
# D-113 (3.9.2026): nazov riadku nesie SKRATKY dielcov + skrinky (`Bok LP s1 s2`).
# Dielec prichadza z VEPO oznaceny nazvom z CSV a bez skrinky sa pri skladani
# nedalo povedat, kam patri. Nalepky VEPO tlacia ~20 znakov bez interpunkcie,
# preto skratky a skrinky hned za nazvom. Plati LEN pre VEPO CSV a LOG —
# kusovnik Studia ostava s plnymi nazvami.
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
      EDGE_CODES  = %w[L1 L2 W1 W2].freeze
      # Windows si tieto mena rezervuje ako zariadenia — nesmu byt nazvom priecinka.
      RESERVED = /\A(con|prn|aux|nul|com[1-9]|lpt[1-9])\z/.freeze

      # D-113: skratky nazvov dielcov. Kluce su PRESNE dnesne retazce builderov
      # (construction.rb, zone_tree.rb, fronts.rb) — neznamy nazov ide bez zmeny.
      SHORT_NAMES = {
        'Bok lavy'           => 'Bok L',
        'Bok pravy'          => 'Bok P',
        'Vystuha predna'     => 'Vyst P',
        'Vystuha zadna'      => 'Vyst Z',
        'Sokel predny'       => 'Sokel',
        'Priecka zvisla'     => 'Priecka Z',
        'Priecka vodorovna'  => 'Priecka V'
      }.freeze
      DOOR_SIDE = /\ADvierka (\d+) (lave|prave)\z/.freeze
      DOOR_WING = /\ADvierka (\d+) kridlo (\d+)\/\d+\z/.freeze
      DOOR_ONE  = /\ADvierka (\d+)\z/.freeze
      DRAWER    = /\AZasuvkove celo (\d+)\z/.freeze
      # Dvojice, ktore sa v jednom riadku zluia do jedneho tokenu (zrkadlove
      # dielce sa v kusovniku agreguju do JEDNEHO riadku — „Bok L/Bok P" je
      # zbytocne dlhe pre 20-znakovu nalepku).
      NAME_PAIRS = [['Bok L', 'Bok P', 'Bok LP'],
                    ['Vyst P', 'Vyst Z', 'Vyst PZ']].freeze
      DOOR_PAIR = /\ADv(\d+) L\z/.freeze
      # Vlastnici riadku: CAB-001 -> s1, BRD-007 -> d7 (poradie s pred d).
      OWNER_KINDS = { 'CAB' => ['s', 0], 'BRD' => ['d', 1] }.freeze
      OWNER_ID    = /\A([A-Z]+)-(\d+)\z/.freeze

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
      #          material_label, tag, notes}], 'errors' => [{name, reason, owners}],
      #          'log_text', 'total_rows', 'total_pieces' }
      # validation: vysledok Validation.run ({ 'items' => [...], 'counts' => {...} })
      # — sekcia KONTROLA v LOGu vznika z NEHO (nalez 5: ten isty cerstvy vysledok
      # ako status okna). Nahrada za povodny `warnings:` param a sekciu "Upozornenia
      # stavby" (nalez 9: KONTROLA je JEDINY kanonicky zoznam vratane build warnings).
      # D-112: edge_decors {abs_id => {'decor','decor_name','group_id'}} a
      # sheet_decors {material_id => {'decor','group_id'}} su VOLITELNE
      # (default {} = ziadne poznamky, stary volajuci dostane presne dnesny
      # obsah 9. stlpca — prazdny). `group_id` je ZAVAZNA identita vazby
      # doska<->ABS (GH #287 P1) — pozri `same_decor?`.
      def build(rows, project:, materials: {}, edge_thicknesses: {}, validation: nil,
                edge_decors: {}, sheet_decors: {},
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
          b = buckets[key] ||= { rows: [], material_ids: [], label: label, tag: tag,
                                 pieces: 0, displays: [], notes: [] }
          e = row['edges'] || {}
          qty = row['quantity'].to_i
          name = row_name(raw)
          # D-112: poznamka sa cita z ORIENTOVANEHO riadku — poradie hran je to
          # iste, s akym idu kody `—`/`=` do CSV.
          note = abs_note(row, edge_decors, sheet_decors)
          b[:rows] << [name, dims[0].round, edge_code(e['L1'], e['L2']),
                       dims[1].round, edge_code(e['W1'], e['W2']), commercial, qty, label, note]
          b[:notes] << { 'name' => name, 'note' => note } unless note.empty?
          b[:material_ids] << row['material_id'] unless b[:material_ids].include?(row['material_id'])
          # 2A-4b (audit F8): zobrazovaci label so strukturou ide VYHRADNE do
          # LOGu — exportny label (grouping/subor/CSV stlpec) sa NEMENI.
          disp = material_display(row['material_id'], materials)
          b[:displays] << disp if disp && !b[:displays].include?(disp)
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
            'material_ids' => b[:material_ids], 'material_label' => b[:label], 'tag' => b[:tag],
            'display_labels' => b[:displays], 'notes' => b[:notes] }
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

      # D-113: nazov riadku pre VEPO CSV a LOG = "<kratke nazvy> <skrinky>",
      # napr. "Bok LP s1 s2 s3". Kusovnik Studia sa NEMENI — plne nazvy tam
      # ostavaju (toto je vylucne objednavkovy/nalepkovy tvar).
      def row_name(row)
        names = Array(row['names']).reject { |n| n.to_s.empty? }
        names = [row['name']] if names.empty? && row['name']
        n = join_names(names.compact, row['free_names'])
        n = 'dielec' if n.empty?
        # Samotne nazvy nad limit = dnesny orez; skrinky sa uz nezmestia.
        return "#{n[0, NAME_MAX - 1]}…" if n.length > NAME_MAX
        append_owners(n, owner_tokens(row['kde']))
      end

      # Skratka JEDNEHO nazvu dielca. Neznamy nazov (samostatna doska = volny
      # text pouzivatela, novy builder) ide BEZ ZMENY — nikdy sa nehada.
      def short_name(name)
        n = name.to_s
        return SHORT_NAMES[n] if SHORT_NAMES.key?(n)
        if (m = DOOR_SIDE.match(n))
          return "Dv#{m[1]} #{m[2] == 'lave' ? 'L' : 'P'}"
        end
        if (m = DOOR_WING.match(n))
          return "Dv#{m[1]} k#{m[2]}"
        end
        if (m = DOOR_ONE.match(n))
          return "Dv#{m[1]}"
        end
        if (m = DRAWER.match(n))
          return "Zas celo #{m[1]}"
        end
        n
      end

      # Skratky + zdruzenie dvojic (Bok L+Bok P => Bok LP), zvysok cez '/'.
      # Poradie = poradie v `names` (prvy clen paru drzi poziciu).
      #
      # GH #287 P2: `free_names` su nazvy, ktore do riadku prispela SAMOSTATNA
      # DOSKA — teda VOLNY TEXT pouzivatela, nie nazov z buildera. Tabulka
      # skratiek na ne NESMIE siahnut ani ich parovat: doska pomenovana
      # "Bok lavy" nie je bok skrinky a dvojica (dielec "Bok lavy" + doska
      # "Bok P") nie je par — `Bom.aggregate_rows` vie oba zaznamy zliat do
      # jedneho riadku, takze samotne `names` povod nepovedia. Ak ten isty
      # retazec prispela doska AJ skrinka, plati KONZERVATIVNA cesta:
      # pass-through bez skratky a bez paru.
      def join_names(names, free_names = nil)
        free = Array(free_names).map(&:to_s)
        toks = []
        names.each do |name|
          raw = name.to_s
          is_free = free.include?(raw)
          token = is_free ? raw : short_name(raw)
          at = toks.index { |t, _f| t == token }
          if at
            toks[at][1] ||= is_free
          else
            toks << [token, is_free]
          end
        end
        NAME_PAIRS.each { |a, b, merged| toks = merge_pair(toks, a, b, merged) }
        door_pairs(toks).each { |num| toks = merge_pair(toks, "Dv#{num} L", "Dv#{num} P", "Dv#{num} LP") }
        toks.map { |t, _f| t }.join('/')
      end

      # Cisla dvierok, ktore maju v riadku OBE strany (Dv1 L aj Dv1 P) — obe
      # zo skratky generovaneho nazvu, nikdy z volneho nazvu dosky.
      def door_pairs(toks)
        plain = toks.reject { |_t, f| f }.map { |t, _f| t }
        nums = plain.map { |t| (m = DOOR_PAIR.match(t)) && m[1] }.compact
        nums.select { |num| plain.include?("Dv#{num} P") }
      end

      # Zluci dvojicu tokenov do jedneho. Zdruzuju sa VYHRADNE tokeny zo skratky
      # generovaneho nazvu (`free` == false) — volny nazov dosky sa nepari.
      def merge_pair(toks, first, second, merged)
        at_first = toks.index { |t, f| t == first && !f }
        at_second = toks.index { |t, f| t == second && !f }
        return toks if at_first.nil? || at_second.nil?
        out = toks.each_with_index.map { |(t, f), i| i == at_first ? [merged, false] : [t, f] }
        out.delete_at(at_second)
        out
      end

      # Skratky vlastnikov riadku z `kde` — unikatne, zoradene (skrinky, potom
      # dosky, kazde podla cisla). Neznamy tvar ID ide cely a az za nimi:
      # informaciu o mieste dielca radsej neorezeme, nez by sme ju zahodili.
      def owner_tokens(kde)
        seen = []
        Array(kde).each do |k|
          id = (k.is_a?(Hash) ? k['owner_id'] : k).to_s.strip
          next if id.empty?
          seen << id unless seen.include?(id)
        end
        seen.map { |id| owner_entry(id) }.sort_by { |e| [e[0], e[1], e[2]] }.map { |e| e[3] }
      end

      # [poradie druhu, cislo, ID (stabilny tie-break), token do nazvu]
      def owner_entry(id)
        m = OWNER_ID.match(id)
        kind = m && OWNER_KINDS[m[1]]
        return [2, 0, id, id] unless kind
        [kind[1], m[2].to_i, id, "#{kind[0]}#{m[2].to_i}"]
      end

      # Skrinky sa pridavaju, kym sa zmestia do NAME_MAX; nezmestene zhrnie
      # " +K" (nikdy odseknuta skratka v polovici). Ak sa nezmesti ani " +K",
      # nazov ostava bez neho — limit je tvrdy.
      def append_owners(base, tokens)
        return base if tokens.empty?
        out = base
        used = 0
        tokens.each_with_index do |t, i|
          rest = tokens.length - i - 1
          candidate = "#{out} #{t}#{rest.zero? ? '' : " +#{rest}"}"
          break if candidate.length > NAME_MAX
          out = "#{out} #{t}"
          used = i + 1
        end
        left = tokens.length - used
        return out if left.zero?
        tail = " +#{left}"
        out.length + tail.length <= NAME_MAX ? "#{out}#{tail}" : out
      end

      # D-112: poznamka pre VEPO — pasky, ktorych DEKOR sa lisi od dekoru dosky.
      # VEPO odvodzuje pasku z materialu, takze KAZDU inu musi vidiet (aj
      # `universal` — tie sa nevynimaju). Neznama paska, neznama doska alebo
      # zaznam bez pouzitelnej identity = ZIADNA poznamka: odhad by sa dostal do
      # objednavky a chybu uz aj tak hlasi KONTROLA (ABS mimo katalogu, material
      # mimo katalogu, UNI material) a oddiel "Riadky vyradene z CSV".
      #
      # edge_decors:  { abs_id      => {'decor','decor_name','group_id'} }
      # sheet_decors: { material_id => {'decor','group_id'} }
      def abs_note(row, edge_decors, sheet_decors)
        return '' if edge_decors.nil? || edge_decors.empty?
        sheet = decor_record((sheet_decors || {})[row['material_id']])
        return '' unless identifiable?(sheet)
        e = row['edges'] || {}
        parts = []
        EDGE_CODES.each do |code|
          id = e[code]
          next if id.nil? || id.to_s.empty?
          abs = decor_record(edge_decors[id])
          next unless identifiable?(abs)
          next if same_decor?(abs, sheet)
          decor = abs['decor'].to_s.strip
          dn = abs['decor_name'].to_s.strip
          text = dn.empty? ? "ABS #{decor}" : "ABS #{decor} #{dn}"
          parts << text unless parts.include?(text)
        end
        parts.join(', ')
      end

      # GH #287 P1: ZAVAZNA identita vazby doska<->ABS je `group_id` (D-41 —
      # dekor je kluc SKUPINY, nie globalne unikatny kod). Katalog vedome dovoli
      # dvom vyrobcom rovnaky kod dekoru v ROZNYCH skupinach, takze porovnanie
      # len podla textu by dosku zo skupiny A a pasku zo skupiny B s rovnakym
      # "W1000" vyhlasilo za zhodu — a poznamka by TICHO chybala.
      #   * oba zaznamy maju skupinu -> rozhoduje VYHRADNE `group_id`,
      #   * inak (legacy zaznam bez skupiny) -> VEDOMY fallback na normalizovany
      #     text dekoru; je to jedina informacia, ktoru taky zaznam nesie, a
      #     mlcat by znamenalo stratit poznamku aj tam, kde je preukazatelna.
      def same_decor?(abs_rec, sheet_rec)
        ag = abs_rec['group_id'].to_s.strip
        sg = sheet_rec['group_id'].to_s.strip
        return ag == sg unless ag.empty? || sg.empty?
        decor_key(abs_rec['decor']) == decor_key(sheet_rec['decor'])
      end

      # Zaznam sa da porovnat, ked nesie aspon skupinu ALEBO dekor. Bez oboch je
      # to prazdne miesto v katalogu — poznamka sa z neho nevymysla.
      def identifiable?(rec)
        !rec['group_id'].to_s.strip.empty? || !decor_key(rec['decor']).empty?
      end

      # Tolerancia k legacy volajucemu: holy String sa cita ako samotny dekor
      # (bez skupiny), nil ako prazdny zaznam. Vzdy vracia Hash, takze
      # `same_decor?` aj `identifiable?` su totalne funkcie.
      def decor_record(value)
        return value if value.is_a?(Hash)
        value.nil? ? {} : { 'decor' => value.to_s }
      end

      # Normalizacia dekoru na POROVNANIE — zhodna s Materials.decor_norm_key
      # (medzery uplne von, lowercase). Kopia je vedoma: modul je cisty (bez
      # katalogu), ale porovnanie musi byt to iste, cim je viazany material
      # na ABS (D-41: dekor = kluc skupiny).
      def decor_key(decor)
        decor.to_s.gsub(/\s+/, '').downcase
      end

      # VEPO stlpec material + zaklad nazvu suboru: label z katalogu, fallback id.
      def material_label(material_id, materials)
        rec = materials[material_id]
        label = rec && rec['label'].to_s.strip
        label.nil? || label.empty? ? material_id.to_s : label
      end

      # 2A-4b (audit F8): zobrazovaci label so strukturou — LEN pre LOG.
      # nil = mapa display nema (legacy volajuci / zhodny s exportnym labelom)
      # a LOG riadok ostava bajtovo presne dnesny.
      def material_display(material_id, materials)
        rec = materials[material_id]
        disp = rec && rec['display'].to_s.strip
        disp.nil? || disp.empty? ? nil : disp
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
          # 2A-4b (audit F8): zobrazovaci label so strukturou LEN v LOGu —
          # bez display map (legacy data) je riadok bajtovo presne dnesny.
          disp = Array(g['display_labels'])
          suffix = disp.empty? ? '' : " — #{disp.join('; ')}"
          lines << "  - #{g['filename']} (#{g['rows']} riadkov, #{g['pieces']} ks) [#{ids}]#{suffix}"
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
        log_notes(lines, groups)
        log_control(lines, validation)
        lines.join(CRLF) + CRLF
      end

      # D-112: kontrolny zoznam pred odoslanim objednavky — riadky, ktore maju
      # pasku v INOM dekore, nez je doska. Presne toto sa do formulara VEPO
      # prepisuje rucne do pola "Poznamka pre VEPO" (a presne na to sa da
      # zabudnut — zakazka KLINIKA, 3.9.2026).
      def log_notes(lines, groups)
        rows = groups.flat_map do |g|
          Array(g['notes']).map { |n| "  * #{n['name']} [#{g['filename']}]: #{n['note']}" }
        end
        lines << ('-' * 60)
        lines << "Poznámky pre VEPO (#{rows.length} riadkov):"
        if rows.empty?
          lines << '  (žiadne — všetky pásky v dekore dosky)'
        else
          rows.each { |r| lines << r }
        end
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
