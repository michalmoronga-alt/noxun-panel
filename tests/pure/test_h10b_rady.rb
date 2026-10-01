# frozen_string_literal: true
# Testy H10b/R-35 — DVE OKNA SKETCHUPU A ROZMEROVE RADY.
#
# Do H10b zapisoval panel rozmerove rady (`dim_series.json`, koliesko
# Inspectora) UPLNOU NAHRADOU: „Uložiť rady" posielalo VSETKYCH 5 radov tak,
# ako ich panel dostal pri otvoreni. Dve okna sa prebijali „posledny vyhrava"
# a zmena prveho zanikla bez slova (sonda P2: A prida 700 do sirok, B zmeni
# len hlbky -> 700 je prec).
#
# Co davka garantuje a co tieto testy overuju:
#   C   jedno okno — rady sa zapisu BAJTOVO rovnako ako doteraz;
#   B1  dva klienti — rozne rady sa zlucia, ten isty rad = konflikt a NIC sa
#       nezapise (ani nekonfliktne rady), bez zmeny bez zapisu, starsi DOM
#       (bez povodnych hodnot) = `:stale_client`, degradovany subor = brana;
#   B2  hranice zlucenia (R2.7) — vyprazdneny rad, chybajuci kluc v subore,
#       neznamy kluc od klienta aj v subore (dnesne obmedzenie, nie sluba);
#   B3  `handle_set_dim_series` — kazda vetva = text + prekreslenie editora;
#       strukturalne guardy (panel nevola `set(`, revizia AZ POD zamkom).
#
# MUTACIE overene proti tejto sade + `tests/js/test_h10b_rady.js` su v PR.
require_relative '../helper' unless defined?(NxTest)
require 'fileutils'

module NxH10b
  E     = Noxun::Engine
  DIM   = E::DimSeries
  STORE = E::JsonFileStore

  module_function

  # Ulozi primar aj `.bak` radov, spusti blok a vrati PRESNY povodny stav.
  def with_file
    NxTest.skip!('katalogove/APPDATA testy bezia len headless') unless NxTest.headless?
    paths = [DIM.path, "#{DIM.path}.bak"]
    before = paths.map { |p| [p, (File.binread(p) if File.exist?(p))] }
    paths.each { |p| FileUtils.rm_f(p) }
    STORE.reload!(DIM.path)
    DIM.instance_variable_set(:@write_block_reason, '')
    yield
  ensure
    before&.each do |(p, raw)|
      if raw then File.binwrite(p, raw) else FileUtils.rm_f(p) end
    end
    STORE.reload!(DIM.path)
    DIM.instance_variable_set(:@write_block_reason, '')
  end

  def bytes(path = DIM.path)
    File.exist?(path) ? File.binread(path) : nil
  end

  def defaults
    DIM.normalize(nil)
  end
end

# =============================================================================
# C · charakterizacia
# =============================================================================

NxTest.test('H10b C2: jedno okno — `set` zapise rady presne v dnesnom tvare') do
  r = NxH10b
  r.with_file do
    full = r.defaults.merge('sirka' => [400, 450, 500, 600, 700, 800, 900])
    stored = r::DIM.set(full)
    NxTest.assert_equal(r::DIM.normalize(full), stored, 'set vrati ulozene rady')
    want = JSON.pretty_generate('std' => r::DIM::STD, 'series' => r::DIM.normalize(full))
    NxTest.assert_equal(want, r.bytes, 'bajty = {std, series: normalize(rady)}')
  end
end
