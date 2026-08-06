# frozen_string_literal: true
# Noxun Engine — V0.6 E-b: PRAVY .xlsx BEZ GEMOV (minimalny ZIP writer) +
# "Luciin format" rozpoctoveho harku.
#
# ===================== PRECO VLASTNY ZIP =====================
# SketchUp Ruby nema rubyzip ani axlsx a instalovat gemy do pluginu je zakazane.
# .xlsx je ZIP so 6 XML subormi — ZIP zapisany metodou STORE (bez kompresie) je
# ~80 riadkov: local file header + data + central directory + EOCD. CRC32 berieme
# zo stdlib (Zlib); ciste Ruby CRC je fallback, keby Zlib chybal.
#
# ===================== DVE VRSTVY (oddelene) =====================
#   XlsxWriter — GENERICKY zapis harku (cells -> bajty .xlsx). Nevie nic o rozpocte.
#   BudgetXlsx — mapovanie payloadu Budget.compute na Luciin harok (B–G, titulok,
#                sekcie s medzisuctami, SPOLU CELKOM). Cita payload, NIC nepocita.
#
# ===================== AUDIT KONTRAKT EXPORTU =====================
# Bunky SPOLU su HODNOTY z payloadu, NIE excelovske vzorce: server je jedina
# autorita cisel (syteza §7: 4/10 realnych rozpoctov malo rozbity =SUM() a
# ~1 074 EUR nevyfakturovanych — presne to tu vzorce nesmu zopakovat).
require 'time'
begin
  require 'zlib'
rescue LoadError
  nil
end

module Noxun
  module Engine
    module XlsxWriter
      # Stylove indexy do cellXfs (poradie nizsie v styles_xml je ZAVAZNE).
      S_TEXT       = 0 # bezny text
      S_TITLE      = 1 # titulok harku (tucne 14)
      S_HEAD       = 2 # hlavicka tabulky (tucne + vypln + linka)
      S_NUM        = 3 # cislo #,##0.00
      S_NUM_BOLD   = 4 # cislo #,##0.00 tucne (medzisucty, SPOLU CELKOM)
      S_TEXT_BOLD  = 5 # tucny text
      S_SECTION    = 6 # nadpis sekcie (tucne + vypln)

      NUM_FMT = '#,##0.00'

      module_function

      # --- verejne API ---------------------------------------------------------

      # sheet: { 'name' => String,
      #          'cols' => [{ 'min'=>1, 'max'=>1, 'width'=>2.5 }, ...],
      #          'merges' => ['B1:G1'],
      #          'rows' => [ [cell|nil, ...], ... ] }   # index 0 = stlpec A
      # cell:  { 'v' => hodnota, 's' => stylovy index, 'n' => true pre cislo }
      # -> retazec BAJTOV (BINARY) hotoveho .xlsx
      def build(sheet, now: nil)
        build_book([sheet.is_a?(Hash) ? sheet : {}], now: now)
      end

      # V0.6 E-b2: zosit s VIAC harkami (cenova ponuka + specifikacia). Poradie
      # casti v archive ostava rovnake ako pri jednom harku (styles PRED
      # worksheetmi) — harky sa len pridavaju na koniec ako sheetN.xml.
      def build_book(sheets, now: nil)
        list = Array(sheets).select { |s| s.is_a?(Hash) }
        list = [{}] if list.empty?
        names = unique_names(list)
        parts = {
          '[Content_Types].xml'        => content_types_xml(list.length),
          '_rels/.rels'                => root_rels_xml,
          'xl/workbook.xml'            => workbook_xml(names),
          'xl/_rels/workbook.xml.rels' => workbook_rels_xml(list.length),
          'xl/styles.xml'              => styles_xml
        }
        list.each_with_index { |s, i| parts["xl/worksheets/sheet#{i + 1}.xml"] = sheet_xml(s) }
        zip(parts, now: now)
      end

      # Zapis na disk — VZDY binarne ('wb'), inak by Windows prepisal LF na CRLF
      # a rozbil CRC/offsety v ZIPe.
      def write(path, sheet, now: nil)
        write_book(path, [sheet], now: now)
      end

      def write_book(path, sheets, now: nil)
        data = build_book(sheets, now: now)
        File.open(path, 'wb') { |f| f.write(data) }
        path
      end

      # Stavebne kamene buniek (BudgetXlsx ich pouziva namiesto hash literalov).
      def text(value, style = S_TEXT)
        { 'v' => value.to_s, 's' => style, 'n' => false }
      end

      def number(value, style = S_NUM)
        f = to_f_or_nil(value)
        return nil if f.nil?
        { 'v' => f, 's' => style, 'n' => true }
      end

      # --- ZIP (STORE) ---------------------------------------------------------

      # parts: { nazov_v_archive => obsah }. Poradie zapisu = poradie hashu.
      def zip(parts, now: nil)
        t = now.is_a?(Time) ? now : Time.now
        dtime, ddate = dos_time(t)
        out = ''.b
        central = ''.b
        count = 0
        parts.each do |name, content|
          data = content.to_s.dup.force_encoding(Encoding::BINARY)
          nm = name.to_s.dup.force_encoding(Encoding::BINARY)
          crc = crc32(data)
          offset = out.bytesize
          out << [0x04034b50, 20, 0, 0, dtime, ddate, crc,
                  data.bytesize, data.bytesize, nm.bytesize, 0].pack('VvvvvvVVVvv')
          out << nm << data
          central << [0x02014b50, 20, 20, 0, 0, dtime, ddate, crc,
                      data.bytesize, data.bytesize, nm.bytesize, 0, 0, 0, 0, 0,
                      offset].pack('VvvvvvvVVVvvvvvVV')
          central << nm
          count += 1
        end
        cd_offset = out.bytesize
        out << central
        out << [0x06054b50, 0, 0, count, count, central.bytesize, cd_offset, 0].pack('VvvvvVVv')
        out
      end

      # DOS timestamp (ZIP ho drzi v 2+2 bajtoch; sekundy s presnostou 2 s).
      def dos_time(t)
        year = t.year < 1980 ? 1980 : t.year
        [((t.hour << 11) | (t.min << 5) | (t.sec / 2)), (((year - 1980) << 9) | (t.month << 5) | t.day)]
      end

      def crc32(data)
        return Zlib.crc32(data) if defined?(Zlib) && Zlib.respond_to?(:crc32)
        crc32_pure(data)
      end

      # Fallback, keby v hostitelskom Ruby chybal Zlib — ZIP bez spravneho CRC
      # je poskodeny archiv, takze tichy 0 nie je moznost.
      def crc32_pure(data)
        @crc_table ||= (0..255).map do |i|
          c = i
          8.times { c = c.odd? ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
          c
        end
        crc = 0xFFFFFFFF
        data.each_byte { |b| crc = @crc_table[(crc ^ b) & 0xFF] ^ (crc >> 8) }
        crc ^ 0xFFFFFFFF
      end

      # --- XML casti -----------------------------------------------------------

      def content_types_xml(sheet_count = 1)
        n = sheet_count.to_i
        n = 1 if n < 1
        overrides = (1..n).map do |i|
          "<Override PartName=\"/xl/worksheets/sheet#{i}.xml\" " \
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        end.join
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' \
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' \
          '<Default Extension="xml" ContentType="application/xml"/>' \
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
          overrides +
          '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' \
          '</Types>'
      end

      def root_rels_xml
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' \
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' \
          '</Relationships>'
      end

      def workbook_rels_xml(sheet_count = 1)
        n = sheet_count.to_i
        n = 1 if n < 1
        rels = (1..n).map do |i|
          "<Relationship Id=\"rId#{i}\" " \
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" ' \
            "Target=\"worksheets/sheet#{i}.xml\"/>"
        end.join
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
          rels +
          "<Relationship Id=\"rId#{n + 1}\" " \
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" ' \
          'Target="styles.xml"/>' \
          '</Relationships>'
      end

      # name: String (jeden harok) alebo pole UZ UNIKATNYCH nazvov.
      def workbook_xml(name)
        names = name.is_a?(Array) ? name : [sheet_name(name)]
        names = [sheet_name(nil)] if names.empty?
        tags = names.each_with_index.map do |n, i|
          "<sheet name=\"#{esc(n)}\" sheetId=\"#{i + 1}\" r:id=\"rId#{i + 1}\"/>"
        end.join
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' \
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' \
          "<sheets>#{tags}</sheets>" \
          '</workbook>'
      end

      # Excel: max 31 znakov, zakazane : \ / ? * [ ]
      def sheet_name(name)
        v = name.to_s.gsub(%r{[:\\/?*\[\]]}, ' ').strip
        v = 'Rozpočet' if v.empty?
        v[0, 31]
      end

      # Dva harky s rovnakym nazvom = Excel subor neotvori. Duplicita dostane
      # ciselny sufix a stale sa zmesti do 31 znakov.
      def unique_names(sheets)
        seen = {}
        Array(sheets).map do |s|
          base = sheet_name(s.is_a?(Hash) ? s['name'] : s)
          name = base
          i = 1
          while seen[name.downcase]
            i += 1
            suffix = " (#{i})"
            name = base[0, 31 - suffix.length] + suffix
          end
          seen[name.downcase] = true
          name
        end
      end

      def styles_xml
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
          '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' \
          "<numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"#{esc(NUM_FMT)}\"/></numFmts>" \
          '<fonts count="3">' \
          '<font><sz val="11"/><color theme="1"/><name val="Calibri"/></font>' \
          '<font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/></font>' \
          '<font><b/><sz val="14"/><color theme="1"/><name val="Calibri"/></font>' \
          '</fonts>' \
          '<fills count="3">' \
          '<fill><patternFill patternType="none"/></fill>' \
          '<fill><patternFill patternType="gray125"/></fill>' \
          '<fill><patternFill patternType="solid"><fgColor rgb="FFECEFF1"/><bgColor indexed="64"/></patternFill></fill>' \
          '</fills>' \
          '<borders count="2">' \
          '<border><left/><right/><top/><bottom/><diagonal/></border>' \
          '<border><left/><right/><top/><bottom style="thin"><color rgb="FFB0BEC5"/></bottom><diagonal/></border>' \
          '</borders>' \
          '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' \
          '<cellXfs count="7">' \
          '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' \
          '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>' \
          '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>' \
          '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' \
          '<xf numFmtId="164" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>' \
          '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>' \
          '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>' \
          '</cellXfs>' \
          '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' \
          '</styleSheet>'
      end

      # Poradie elementov vo <worksheet> je dane schemou: cols PRED sheetData,
      # mergeCells AZ ZA nim.
      def sheet_xml(sheet)
        xml = ''.dup
        xml << '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        xml << '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        cols = Array(sheet['cols'])
        unless cols.empty?
          xml << '<cols>'
          cols.each do |c|
            xml << format('<col min="%d" max="%d" width="%s" customWidth="1"/>',
                          c['min'].to_i, c['max'].to_i, num_str(c['width']))
          end
          xml << '</cols>'
        end
        xml << '<sheetData>'
        Array(sheet['rows']).each_with_index do |row, ri|
          r = ri + 1
          cells = Array(row)
          next xml << "<row r=\"#{r}\"/>" if cells.compact.empty?
          xml << "<row r=\"#{r}\">"
          cells.each_with_index do |cell, ci|
            next if cell.nil?
            xml << cell_xml(cell, col_letter(ci + 1), r)
          end
          xml << '</row>'
        end
        xml << '</sheetData>'
        merges = Array(sheet['merges'])
        unless merges.empty?
          xml << "<mergeCells count=\"#{merges.length}\">"
          merges.each { |m| xml << "<mergeCell ref=\"#{esc(m)}\"/>" }
          xml << '</mergeCells>'
        end
        xml << '</worksheet>'
        xml
      end

      def cell_xml(cell, col, row)
        ref = "#{col}#{row}"
        style = cell['s'].to_i
        if cell['n']
          "<c r=\"#{ref}\" s=\"#{style}\"><v>#{num_str(cell['v'])}</v></c>"
        else
          v = cell['v'].to_s
          return "<c r=\"#{ref}\" s=\"#{style}\"/>" if v.empty?
          # inlineStr = ziadny sharedStrings.xml (o subor menej, o chybu menej)
          "<c r=\"#{ref}\" s=\"#{style}\" t=\"inlineStr\"><is><t xml:space=\"preserve\">#{esc(v)}</t></is></c>"
        end
      end

      def col_letter(index)
        i = index.to_i
        return 'A' if i < 1
        out = ''.dup
        while i.positive?
          i, rem = (i - 1).divmod(26)
          out.prepend((65 + rem).chr)
        end
        out
      end

      # --- pomocne -------------------------------------------------------------

      # XML 1.0 nepovoluje riadiace znaky (okrem tab/LF/CR) — diakritika ide
      # nedotknuta (subor je UTF-8).
      def esc(value)
        value.to_s
             .gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '')
             .gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
             .gsub('"', '&quot;').gsub("'", '&apos;')
      end

      def num_str(value)
        f = to_f_or_nil(value)
        return '0' if f.nil?
        return f.round.to_s if f == f.round && f.abs < 1e15
        format('%.6f', f).sub(/0+\z/, '').sub(/\.\z/, '')
      end

      def to_f_or_nil(v)
        return nil if v.nil?
        return nil if v.is_a?(String) && v.strip.empty?
        f = Float(v.to_s.tr(',', '.'))
        f.finite? ? f : nil
      rescue StandardError
        nil
      end
    end

    # =======================================================================
    # LUCIIN HAROK — mapovanie payloadu rozpoctu na tabulku B–G
    # =======================================================================
    # Struktura z realnych rozpoctov (SYNTEZA §1): stlpec A je odsadzovac, data
    # su B–G; R1 = zluceny titulok, R2 = hlavicka, R3+ polozky. Michal (§8 F)
    # navyse chce MEDZISUCTY sekcii — v excelovej predlohe boli bloky odlisene
    # len farbou vyplne.
    module BudgetXlsx
      HEADERS = ['MATERIÁL', 'KÓD', 'MJ', 'POČET', 'CENA za 1 MJ (€)', 'SPOLU (€)'].freeze
      COLS = [
        { 'min' => 1, 'max' => 1, 'width' => 2.5 },  # A — odsadzovac
        { 'min' => 2, 'max' => 2, 'width' => 52.0 }, # B — MATERIAL
        { 'min' => 3, 'max' => 3, 'width' => 14.0 }, # C — KOD
        { 'min' => 4, 'max' => 4, 'width' => 9.0 },  # D — MJ
        { 'min' => 5, 'max' => 5, 'width' => 10.0 }, # E — POCET
        { 'min' => 6, 'max' => 6, 'width' => 16.0 }, # F — CENA za 1 MJ
        { 'min' => 7, 'max' => 7, 'width' => 14.0 }  # G — SPOLU
      ].freeze

      SHEET_NAME = 'Cenová ponuka' # rovnaky nazov harku ako v Luciinych suboroch

      module_function

      # payload: vystup Budget.compute / Budget.payload_for
      # -> sheet hash pre XlsxWriter.build
      def sheet(payload, project:, now: nil)
        p = payload.is_a?(Hash) ? payload : {}
        t = now.is_a?(Time) ? now : Time.now
        rows = []
        # Stlpec A je v Luciiných hárkoch PRÁZDNY odsadzovač — všetko začína v B.
        rows << row_at(2, [XlsxWriter.text(title(project, t), XlsxWriter::S_TITLE)])
        rows << row_at(2, HEADERS.map { |h| XlsxWriter.text(h, XlsxWriter::S_HEAD) })
        Array(p['sections']).each { |sec| append_section(rows, sec) }
        append_totals(rows, p)
        { 'name' => SHEET_NAME, 'cols' => COLS, 'merges' => ['B1:G1'], 'rows' => rows }
      end

      def title(project, now = Time.now)
        name = project.to_s.strip
        name = 'zákazka' if name.empty?
        "Rozpočet #{name} - AKT. #{date_label(now)}"
      end

      def date_label(now = Time.now)
        t = now.is_a?(Time) ? now : Time.now
        "#{t.day}.#{t.month}. #{t.year}"
      end

      # Nazov suboru pre savepanel — bez znakov zakazanych vo Windows nazvoch.
      def file_name(project, now = Time.now)
        name = project.to_s.strip
        name = 'zakazka' if name.empty?
        safe = "Rozpocet #{name} - AKT #{date_label(now)}".gsub(%r{[\\/:*?"<>|]}, '-').gsub(/\s+/, ' ').strip
        "#{safe}.xlsx"
      end

      # --- sekcie --------------------------------------------------------------

      def append_section(rows, sec)
        return unless sec.is_a?(Hash)
        list = Array(sec['rows'])
        return if list.empty?
        # Zaokruhlenie nie je "sekcia" v ludskom zmysle — je to jeden dorovnavaci
        # riadok tesne pred SPOLU CELKOM (syteza §7: 6/10 rozpoctov ho malo skryty).
        if sec['key'].to_s == 'rounding'
          list.each { |r| rows << item_row(r) }
          return
        end
        rows << row_at(2, [XlsxWriter.text(section_title(sec), XlsxWriter::S_SECTION)])
        list.each { |r| rows << item_row(r) }
        rows << subtotal_row(sec)
      end

      def section_title(sec)
        name = sec['name'].to_s.strip
        name = sec['key'].to_s if name.empty?
        base = name.upcase
        # Spotrebice mimo suctu MUSIA byt v harku vidno ako "nezapocitane" —
        # inak by sa suma harku nedala zosuladit so SPOLU CELKOM.
        return base if sec['counts_in_total'] != false
        "#{base} — nezapočítané do SPOLU"
      end

      def item_row(r)
        return row_at(2, []) unless r.is_a?(Hash)
        price = r['cena_mj']
        cells = [
          XlsxWriter.text(item_name(r)),
          XlsxWriter.text(r['kod'].to_s),
          XlsxWriter.text(r['mj'].to_s),
          XlsxWriter.number(r['mnozstvo']),
          price.nil? ? XlsxWriter.text('nezadaná') : XlsxWriter.number(price),
          XlsxWriter.number(r['spolu'])
        ]
        row_at(2, cells)
      end

      # Luciin harok NEMA stlpec na poznamku — realne rozpocty ju pisu PRIAMO do
      # nazvu polozky (syteza §7.4 „Poznámky priamo v názve položky"). Cisla sa
      # tym nedotykame: nazov je jediny textovy stlpec, do ktoreho poznamka patri.
      def item_name(r)
        name = r['nazov'].to_s.strip
        name = '(bez názvu)' if name.empty?
        note = r['poznamka'].to_s.strip
        note.empty? ? name : "#{name} · #{note}"
      end

      def subtotal_row(sec)
        label = "Medzisúčet #{sec['name']} (€):"
        cells = [nil, nil, nil, nil,
                 XlsxWriter.text(label, XlsxWriter::S_TEXT_BOLD),
                 XlsxWriter.number(sec['subtotal'], XlsxWriter::S_NUM_BOLD)]
        row_at(2, cells)
      end

      # --- zaver ---------------------------------------------------------------

      def append_totals(rows, payload)
        totals = payload['totals'].is_a?(Hash) ? payload['totals'] : {}
        rows << row_at(2, [])
        rows << row_at(6, [XlsxWriter.text('SPOLU CELKOM (€):', XlsxWriter::S_TEXT_BOLD),
                           XlsxWriter.number(totals['total'], XlsxWriter::S_NUM_BOLD)])
        unknown = totals['unknown_count_in_total'].to_i
        return unless unknown.positive?
        rows << row_at(2, [XlsxWriter.text(
          "Pozor: #{unknown} riadkov bez ceny sa do súčtu nezapočítalo — doplň ceny v tabe Rozpočet.",
          XlsxWriter::S_TEXT_BOLD
        )])
      end

      # Riadok posunuty tak, aby prva bunka zacinala v danom stlpci (1 = A).
      def row_at(start_col, cells)
        Array.new(start_col - 1) + Array(cells)
      end
    end
  end
end
