# frozen_string_literal: true
# H14b — jedna cesta prepnutia sekcie Studia a kreslenie z registra (package
# `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H14.md`, R3, guard R5 d).
#
# Sekciu Studia kresli a prepina `studio.js` VYHRADNE podla riadka registra
# `NXStudioSections` (`tools`, `body`, `leave`, `enter`, `anchor`). Tento guard
# zhodi kazdy navrat vetvy „natvrdo podla id" — teda presne to, co by spravil
# niekto, kto pridava sekciu postaru (13 miest v 4 suboroch):
#   d) v studio.js nie je `studioSec ===|!== '<id>'` (ani `id ===|!== '<id>'`)
#      mimo 4 riadkov ozveny Kontroly (allowlist podla obsahu riadka),
#   d) renderTools, renderBody, studioSwitchSection, studioGoSection, kotvy
#      a `setStudio` (deep-link) neobsahuju literal id sekcie,
#   d) haciky INYCH suborov (`budRenderTools`, `matOnLeaveSection`, `ssOnAboutEnter`,
#      `matOpenAnchor` …) studio.js nevola menom — len cez register.
# Spravanie (poradie haciakov, stav v okamihu volania, kotvy, pocet prekresleni)
# drzia JS sady `test_h14_golden.js` a `test_h14b_prepnutie.js`.
require_relative '../helper' unless defined?(NxTest)
require_relative 'test_h14a_register' unless defined?(NxH14Reg)

module NxH14b
  JS = NxH14Reg.src('noxun_engine', 'ui', 'js', 'studio.js')
  # Ozvena Kontroly (echo prepinacov po zapise) — vlastna sekcia, nie dispatch (D9).
  ALLOW = { "if (studioSec === 'ctrl') renderTools();" => 4 }.freeze

  module_function

  def compare_lines
    out = []
    JS.lines.each_with_index do |l, i|
      next if l.strip.start_with?('//')
      next unless l.match?(/\b(?:studioSec|id)\s*[!=]==\s*'(?:#{NxH14Reg.alt})'/) ||
                  l.match?(/'(?:#{NxH14Reg.alt})'\s*[!=]==\s*(?:studioSec|id)\b/)

      out << [i + 1, l.strip]
    end
    out
  end

  def fn_body(re)
    JS[re].to_s
  end

  def code_only(s)
    s.lines.reject { |l| l.strip.start_with?('//') }.join
  end
end

NxTest.test('H14b R5 d: studio.js nevetvi podla id sekcie (mimo ozveny Kontroly)') do
  lines = NxH14b.compare_lines
  allowed = lines.select { |(_n, t)| NxH14b::ALLOW.key?(t) }
  bad = lines - allowed
  NxTest.assert(bad.empty?,
                'vetva podla id sekcie v studio.js — sekciu kresli/prepina riadok registra ' \
                "(js/studio_sections.js): #{bad.map { |(n, t)| "#{n}: #{t}" }.join(' · ')}")
  NxH14b::ALLOW.each do |txt, max|
    NxTest.assert(allowed.count { |(_n, t)| t == txt } <= max, "allowlist (#{txt}) najviac #{max}×")
  end
end

NxTest.test('H14b R5 d: dispatch, prechod a deep-link neobsahuju literal id sekcie') do
  parts = {
    'renderTools' => /function renderTools\(\)\{.*?\n  \}/m,
    'renderBody' => /function renderBody\(\)\{.*?\n  \}/m,
    'sectionHook' => /function sectionHook\(row, name\)\{.*?\n  \}/m,
    'studioSwitchSection' => /function studioSwitchSection\(id, guid\)\{.*?\n  \}/m,
    'studioGoSection' => /function studioGoSection\(id\)\{.*?\n  \}/m,
    'sectionAnchorBefore' => /function sectionAnchorBefore\(st\)\{.*?\n  \}/m,
    'sectionAnchorOpen' => /function sectionAnchorOpen\(row, a\)\{.*?\n  \}/m,
    'setStudio' => /setStudio: function\(data\)\{.*?\n    \},/m
  }
  parts.each do |name, re|
    body = NxH14b.code_only(NxH14b.fn_body(re))
    NxTest.refute(body.empty?, "#{name} sa nasiel")
    hits = body.scan(/'(#{NxH14Reg.alt})'/).flatten.uniq
    NxTest.assert(hits.empty?, "#{name} nesmie poznat id sekcie (riadok registra): #{hits.inspect}")
  end
  go = NxH14b.fn_body(parts['studioGoSection'])
  NxTest.assert(go.include?('if (!studioSwitchSection(id,'), 'klik ide jednou funkciou prechodu')
  NxTest.assert(go.index('studioSwitchSection(') < go.index('render();'), 'a kresli az PO uspesnom prepnuti')
  set = NxH14b.fn_body(parts['setStudio'])
  NxTest.assert(set.include?('studioSwitchSection(ST.open_section,'), 'deep-link ide tou istou funkciou')
end

NxTest.test('H14b R5 d: haciky inych suborov vola studio.js len cez register') do
  foreign = NxH14Reg.rows.reject { |r| r['module'] == 'studio.js' }.flat_map do |r|
    [r['tools'], r['body'], r['leave'], r['enter'], (r['anchor'] || {})['fn']].compact
  end.uniq
  NxTest.assert(foreign.length >= 20, "haciky z kontraktu (#{foreign.length})")
  code = NxH14b.code_only(NxH14b::JS)
  named = foreign.select { |f| code.match?(/\b#{Regexp.escape(f)}\b/) }
  NxTest.assert(named.empty?, "studio.js vola hacik sekcie menom (patri do registra): #{named.inspect}")
  own = NxH14Reg.rows.select { |r| r['module'] == 'studio.js' }.flat_map do |r|
    [r['tools'], r['body'], (r['anchor'] || {})['fn']].compact
  end
  own.each do |f|
    NxTest.assert(code.match?(/\b#{f}: #{f}\b/), "vlastny hacik #{f} je v OWN_HOOKS (R1.2a)")
    NxTest.assert(code.include?("function #{f}("), "a je to pomenovana funkcia studio.js (#{f})")
  end
end
