# frozen_string_literal: true
# ZRKADLO JEDNOTIEK KOVANIA (H5a, 1.10.2026 — nález kontroly presnosti mapy UI).
#
# Nákup kovania v Štúdiu prekladá jednotku katalógu (`m`, `par`, `sada`…) na kód MJ
# klientskou mapou `NXF_HW_UNIT` (`ui/js/studio.js`, funkcia `nxfHwUnitCode`), aby
# písal jednotku rovnako ako Rozpočet. Autoritou je Ruby `Budget::HW_UNIT_LABELS`
# (`core/budget.rb`). Dovtedy zhodu nestrážilo nič — hodnoty boli len natvrdo
# v `tests/js/test_h4a_format.js`, takže nová jednotka v jadre by v Nákupe ticho
# ostala surová.
#
# Overuje sa MAPA (kľúče aj kódy), nie fallback: pre neznámu jednotku JS vracia
# `null` (vypíše surovo), Ruby počíta `KS` — to je vedomý rozdiel opísaný v mape UI.
require_relative '../helper' unless defined?(NxTest)

module NxHwUnitMirror
  STUDIO_JS = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'studio.js')

  def self.js_map
    src = File.read(STUDIO_JS, encoding: 'UTF-8')
    body = src[/var NXF_HW_UNIT = \{(.*?)\};/m, 1].to_s
    body.scan(/'([^']+)'\s*:\s*'([^']+)'/).to_h
  end
end

NxTest.test('HW jednotky: klientska mapa NXF_HW_UNIT sa nasla a nie je prazdna') do
  map = NxHwUnitMirror.js_map
  NxTest.assert(map.length >= 5, "NXF_HW_UNIT v studio.js sa nenasla alebo je kratka (#{map.length})")
  NxTest.assert(File.read(NxHwUnitMirror::STUDIO_JS, encoding: 'UTF-8').include?('function nxfHwUnitCode('),
                'nxfHwUnitCode zije v studio.js')
end

NxTest.test('HW jednotky: NXF_HW_UNIT (studio.js) = Budget::HW_UNIT_LABELS (kluce aj kody)') do
  ruby = Noxun::Engine::Budget::HW_UNIT_LABELS
  js = NxHwUnitMirror.js_map
  NxTest.assert(js.keys.sort == ruby.keys.sort,
                "kluce sa rozisli — len Ruby: #{(ruby.keys - js.keys).inspect}, len JS: #{(js.keys - ruby.keys).inspect}")
  diff = ruby.reject { |k, v| js[k] == v }
  NxTest.assert(diff.empty?,
                "kody MJ sa rozisli: #{diff.map { |k, v| "#{k}: Ruby #{v} / JS #{js[k]}" }.join(' · ')} — " \
                'uprav NXF_HW_UNIT v studio.js podla core/budget.rb')
end
