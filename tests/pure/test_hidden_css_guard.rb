# frozen_string_literal: true
# D-137 guard: element, ktory HTML skryva atributom `hidden`, nesmie CSS
# pravidlom `display: …` znova zobrazit.
#
# Autorske pravidlo (`.nx-inspector .rowc { display: flex }`) VZDY prebije UA
# pravidlo `[hidden] { display: none }` — na specificite nezalezi, UA vrstva
# prehrava s kazdym autorskym `display`. Kazda trieda s vlastnym `display`
# preto potrebuje aj `…[hidden] { display: none }` so specificitou aspon takou
# (pri rovnosti rozhoduje neskorsie poradie). Stalo sa to DVAKRAT: S1-C
# `.row.tplexpects` a S1-E styri polia + pat vystupov slotu umyvacky, ktore od
# v0.12.12 videl KAZDY korpus v Zakladnych (smoke S1 21.9.2026).
#
# Sonda je zamerne jednoducha a KONZERVATIVNA:
#   * POSLEDNY zlozeny selektor sa porovnava s elementom (tag, id, triedy,
#     atributy); pseudo-elementy (`::after`) a vetvy `:not([hidden])` sa
#     neratiaju — stylizuju iny box alebo skryty element vylucuju;
#   * PRVY zlozeny selektor (koren — `.nx-inspector` nastavuje JS na <html>,
#     `body.mode-cab[…]` prepisuje `setUiMode`) a kazdy clanok s `html`/`body`
#     plati VZDY — su to dynamicke stavy okna, nie staticke HTML;
#   * STREDNE clanky musia sediet na niektorom STATICKOM predkovi (tag, id,
#     triedy; atributy a pseudo-triedy predka sa neoveruju — su to stavy).
# Kontroluju sa elementy, ktore su skryte UZ V HTML (tak zacinaju vsetky
# prepinane riadky panela). Trieda predka, ktoru pridava az JS, sonde unikne
# — guard chyta bezny vzor (display na triede samotneho elementu), nie vsetko.
require_relative '../helper' unless defined?(NxTest)

module NxTest
  module HiddenCss
    ATTR_RE = /\[([\w-]+)(?:([~|^$*]?=)"?([^"\]]*)"?)?\]/.freeze
    TAG_RE = %r{<(/?)([a-zA-Z][\w-]*)((?:\s+[^\s=>/]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(/?)>}m.freeze
    VOID = %w[area base br col embed hr img input link meta source track wbr].freeze

    module_function

    # -> [{sel:, decl:, order:}] pre kazde najvnutornejsie pravidlo (@media
    # sa rozbali — jeho obsah su obycajne pravidla).
    def rules(css, base_order = 0)
      out = []
      css.gsub(%r{/\*.*?\*/}m, '').scan(/([^{}]+)\{([^{}]*)\}/m).each_with_index do |(sel, decl), i|
        sel = sel.strip
        next if sel.start_with?('@')

        sel.split(',').each { |s| out << { sel: s.strip, decl: decl, order: base_order + i } }
      end
      out
    end

    # Zlozene selektory zlava doprava; kombinatory `>`, `+`, `~` sa beru ako
    # potomok (konzervativne — sonda radsej nahlasi, nez prehliadne).
    def compounds(sel)
      sel.gsub(/\s*([>+~])\s*/, ' ').split(/\s+/).reject(&:empty?)
    end

    def last_compound(sel)
      compounds(sel).last.to_s
    end

    # Element HTML ako hash: tag, id, triedy, atributy a STATICKI predkovia
    # (od korena). Komentare, <script> a <style> sa preskakuju — ich obsah
    # nie su elementy.
    def elements(html)
      src = html.gsub(/<!--.*?-->/m, '').gsub(%r{<(script|style)\b[^>]*>.*?</\1>}mi, '')
      stack = []
      out = []
      src.scan(TAG_RE) do |close, tag, attrs, self_close|
        tag = tag.downcase
        if close == '/'
          i = stack.rindex { |e| e[:tag] == tag }
          stack.slice!(i..) if i
          next
        end
        ah = {}
        attrs.scan(%r{([^\s=/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?}) do |n, a, b, c|
          ah[n] = (a || b || c).to_s
        end
        el = { tag: tag, id: ah['id'], classes: ah.fetch('class', '').split, attrs: ah,
               ancestors: stack.dup }
        out << el
        stack << el unless self_close == '/' || VOID.include?(tag)
      end
      out
    end

    # Plati STREDNY clanok na tomto predkovi? (triedy, id, tag; stavy nie)
    def ancestor_ok?(comp, anc)
      c = comp.gsub(/:not\([^)]*\)/, '').gsub(/::?[\w-]+(\([^)]*\))?/, '').gsub(ATTR_RE, '')
      tag = c[/\A[a-z][\w-]*/]
      return false if tag && tag != anc[:tag]

      c.scan(/\.([\w-]+)/).flatten.all? { |k| anc[:classes].include?(k) } &&
        c.scan(/#([\w-]+)/).flatten.all? { |k| anc[:id] == k }
    end

    # Plati cely selektor na element? (koren a html/body clanky vzdy)
    def selector_matches?(sel, el)
      comps = compounds(sel)
      return false unless matches?(comps.last.to_s, el)

      middle = comps[1...-1] || []
      ancestors = el[:ancestors]
      idx = ancestors.length - 1
      middle.reverse_each do |comp|
        next if comp =~ /\A(html|body)\b/

        idx -= 1 while idx >= 0 && !ancestor_ok?(comp, ancestors[idx])
        return false if idx.negative?

        idx -= 1
      end
      true
    end

    def specificity(sel)
      nots = sel.scan(/:not\(([^)]*)\)/).flatten
      s = sel.gsub(/:not\([^)]*\)/, '')
      ids = s.scan(/#[\w-]+/).size
      cls = s.scan(/\.[\w-]+/).size + s.scan(/\[[^\]]*\]/).size + s.scan(/:(?!:)[\w-]+/).size
      els = s.gsub(/[#.][\w-]+|\[[^\]]*\]|::?[\w-]+(\([^)]*\))?/, ' ')
             .split(/[\s>+~*]+/).reject(&:empty?).size
      nots.each do |n|
        a = specificity(n)
        ids += a[0]
        cls += a[1]
        els += a[2]
      end
      [ids, cls, els]
    end

    def display_of(decl)
      m = decl.match(/(?:\A|[;\s])display\s*:\s*([^;]+)/)
      m && m[1].strip.sub(/\s*!important\z/, '')
    end

    def matches?(comp, el)
      return false if comp.include?('::') || comp.include?(':not([hidden])')

      c = comp.gsub(/:not\([^)]*\)/, '')
      tag = c[/\A[a-z][\w-]*/]
      return false if tag && tag != el[:tag]
      return false unless c.scan(/\.([\w-]+)/).flatten.all? { |k| el[:classes].include?(k) }
      return false unless c.scan(/#([\w-]+)/).flatten.all? { |k| el[:id] == k }

      c.scan(ATTR_RE).all? do |name, op, val|
        next true if name == 'hidden'

        have = el[:attrs][name]
        next false if have.nil?
        next true if op.nil?

        op == '~=' ? have.split.include?(val) : (op != '=' || have == val)
      end
    end

    # Skryte elementy z HTML, ktore by CSS zobrazilo. `css_sources` = pole
    # textov v poradi nacitania (subor, potom inline <style> stranky).
    def offenders(html, css_sources)
      all = []
      css_sources.each_with_index { |css, i| all.concat(rules(css, i * 1_000_000)) }
      out = []
      elements(html).each do |el|
        next unless el[:attrs].key?('hidden')

        tag = el[:tag]
        ah = el[:attrs]
        label = "<#{tag}#{el[:id] ? " id=#{el[:id]}" : ''}" \
                "#{el[:classes].empty? ? '' : " class=\"#{el[:classes].join(' ')}\""}>"
        inline = ah['style'] && display_of(ah['style'])
        if inline && inline != 'none'
          out << "#{label} ma inline display:#{inline}"
          next
        end
        shows = []
        hides = []
        all.each do |r|
          comp = last_compound(r[:sel])
          next unless selector_matches?(r[:sel], el)

          d = display_of(r[:decl]) or next
          if d == 'none'
            hides << r if comp.include?('[hidden]')
          elsif !comp.include?('[hidden]')
            shows << r
          end
        end
        next if shows.empty?

        key = ->(r) { [specificity(r[:sel]), r[:order]] }
        best_show = shows.max_by(&key)
        best_hide = hides.max_by(&key)
        next if best_hide && (key.call(best_hide) <=> key.call(best_show)).positive?

        out << "#{label} zobrazi `#{best_show[:sel]} { display: #{display_of(best_show[:decl])} }`"
      end
      out
    end
  end
end

NxTest.test('D-137 guard: sonda chyti triedu s `display` bez prebitia `[hidden]`') do
  html = '<div class="rowc" id="a" hidden></div><div class="okc" id="b" hidden></div>' \
         '<div class="rowc" id="c"></div>'
  css = '.nx-inspector .rowc { display: flex; } ' \
        '.nx-inspector .okc { display: flex; } .nx-inspector .okc[hidden] { display: none; }'
  off = NxTest::HiddenCss.offenders(html, [css])
  NxTest.assert_equal(1, off.length, "presne jeden nalez: #{off.inspect}")
  NxTest.assert(off.first.include?('id=a'), 'nalez je skryty riadok bez prebitia')
end

NxTest.test('D-137 guard: slabsie alebo skorsie `[hidden]` pravidlo prehrava') do
  html = '<div class="rowc" id="a" hidden></div>'
  weaker = '.nx-inspector .rowc.x { display: flex; } .rowc[hidden] { display: none; }'
  html1 = '<div class="rowc x" id="a" hidden></div>'
  NxTest.assert_equal(1, NxTest::HiddenCss.offenders(html1, [weaker]).length,
                      '(0,2,0) `.rowc[hidden]` NEPREBIJE (0,3,0) `.nx-inspector .rowc.x`, ' \
                      'hoci je v subore neskor — rozhoduje najprv specificita')
  same = '.nx-inspector .rowc { display: flex; } .rowc[hidden] { display: none; }'
  NxTest.assert_equal(0, NxTest::HiddenCss.offenders(html, [same]).length,
                      'rovnaka specificita (0,2,0) a neskorsie poradie = skryte')
  earlier = '.nx-inspector .rowc[hidden] { display: none; } .nx-inspector .rowc.x { display: flex; }'
  html2 = '<div class="rowc x" id="a" hidden></div>'
  NxTest.assert_equal(1, NxTest::HiddenCss.offenders(html2, [earlier]).length,
                      'zobrazenie (0,3,0) uvedene NESKOR prebije [hidden] (0,3,0)')
  ok = '.nx-inspector .rowc { display: flex; } .nx-inspector .rowc[hidden] { display: none; }'
  NxTest.assert_equal(0, NxTest::HiddenCss.offenders(html, [ok]).length,
                      'silnejsie [hidden] pravidlo = element ostane skryty')
end

NxTest.test('D-137 guard: pseudo-element, `:not([hidden])`, cudzi atribut a inline style') do
  html = '<button class="tip" id="t" hidden></button>'
  css = '.x .tip:hover::after { display: block; } .x .tip:not([hidden]) { display: inline-flex; }'
  NxTest.assert_equal(0, NxTest::HiddenCss.offenders(html, [css]).length,
                      '::after stylizuje iny box a :not([hidden]) skryty element vylucuje')
  css2 = '.x [data-s4="korpus"] { display: block; }'
  NxTest.assert_equal(0, NxTest::HiddenCss.offenders(html, [css2]).length,
                      'pravidlo s atributom, ktory element nema, sa ho netyka')
  inline = '<div id="i" style="display:flex" hidden></div>'
  NxTest.assert_equal(1, NxTest::HiddenCss.offenders(inline, ['']).length,
                      'inline display prebije [hidden] tiez')
end

NxTest.test('D-137 guard: stredne clanky selektora sa overuju na PREDKOCH, koren nie') do
  css = '.nx-inspector .fcard .segrow button { display: inline-flex; }'
  outside = '<div class="row"><button class="tip" id="t" hidden></button></div>'
  NxTest.assert_equal(0, NxTest::HiddenCss.offenders(outside, [css]).length,
                      'tlacidlo mimo `.fcard .segrow` sa pravidla netyka')
  inside = '<div class="fcard"><!-- <b> --><div class="segrow"><input>' \
           '<button class="tip" id="t" hidden></button></div></div>'
  NxTest.assert_equal(1, NxTest::HiddenCss.offenders(inside, [css]).length,
                      'vnutri `.fcard .segrow` ho pravidlo zobrazi (koren `.nx-inspector` ' \
                      'dava JS na <html>, preto sa neoveruje)')
  closed = '<div class="fcard"><div class="segrow"></div></div><button class="tip" id="t" hidden></button>'
  NxTest.assert_equal(0, NxTest::HiddenCss.offenders(closed, [css]).length,
                      'uzavrety predok uz predkom nie je')
end

NxTest.test('D-137 guard: v panel.html ani studio.html NIE JE skryty element, ktory by CSS zobrazilo') do
  ui = File.join(NxTest::ROOT, 'noxun_engine', 'ui')
  panel_css = File.read(File.join(ui, 'css', 'panel.css'), encoding: 'UTF-8')
  bad = []
  %w[panel.html studio.html].each do |name|
    html = File.read(File.join(ui, name), encoding: 'UTF-8')
    inline = html.scan(%r{<style>(.*?)</style>}m).flatten.join("\n")
    NxTest::HiddenCss.offenders(html, [panel_css, inline]).each { |o| bad << "#{name}: #{o}" }
  end
  NxTest.assert(bad.empty?,
                'skryte elementy, ktore CSS aj tak zobrazi (dopln `…[hidden] { display: none; }` ' \
                "s aspon rovnakou specificitou, neskor v subore):\n  #{bad.join("\n  ")}")
end
