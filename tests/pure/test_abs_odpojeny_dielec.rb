# frozen_string_literal: true
# ABS NA ODPOJENOM DIELCI — guard vsetkych zapisovych ciest karty dielca.
#
# NALEZ (review K1, PR #185): dielec vytiahnuty zo skrinky na najvyssiu uroven
# ostava viazany uz len atributom `cabinet_id`, takze `find_cabinet` jeho
# povodneho vlastnika NAJDE. Zapisova cesta karty potom prestavala korpus a
# zmenila INY, VNORENY dielec toho isteho `part_key`, kym vybrany odpojeny
# dielec si drzal svoj snapshot a do VEPO isiel po starom. Pouzivatel pritom
# dostal hlasku o USPECHU.
#
# Preco to nie je kozmetika: z pluginu sa objednavaju realne zakazky. Taka
# cesta posle do objednavky ABS pasku, ktora sa na obrazovke nikdy neukazala
# — a chyba vyjde najavo az na hotovom nabytku.
#
# Co sa tu strazi:
#   1) hlaska aj kontrola ziju na JEDNOM mieste (`detached_part_error`) —
#      ziadna kopia textu po handleroch
#   2) KAZDA zapisova cesta karty (ABS hrana, bulk olep, material dielca,
#      smer dekoru, „Použiť na podobné") sa nan napaja PRED akymkolvek zapisom
#   3) spravanie samotneho guardu: vnoreny dielec prejde, odpojeny dostane
#      hlasku, chybajuci vyber guard NEROZBIJE
require_relative '../helper' unless defined?(NxTest)

# actions_parts.rb je reopen modulu Panel bez zavislosti na SketchUp API
# (vzor: payloads.rb v test_d88_abs_farby.rb) — guard sa da volat headless.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_parts')

ODP_PARTS_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'actions_parts.rb'),
                         encoding: 'UTF-8')
ODP_PANEL = Noxun::Engine::Panel

def odp_body(name)
  ODP_PARTS_RB[/def #{Regexp.escape(name)}\b.*?\n        end\n/m].to_s
end

# Guard musi stat PRED prvym zapisom — nie „niekde v tele".
def odp_guard_before(body, marker)
  g = body.index('detached_part_error')
  w = body.index(marker)
  g && (w.nil? || g < w)
end

# --- 1) JEDNO miesto pravdy --------------------------------------------------

NxTest.test('odpojeny dielec: hlaska aj kontrola ziju na JEDNOM mieste') do
  shared = odp_body('detached_part_error')
  NxTest.assert(!shared.empty?, 'spolocny guard existuje')
  NxTest.assert(shared.include?('nested_part?(cab, part)'),
                'odpojenost sa pozna podla rodica (vnoreny = definicia skrinky)')
  NxTest.assert(ODP_PARTS_RB.scan('vytiahnutý zo skrinky').length == 1,
                'text hlasky je v subore PRAVE RAZ — ziadna kopia po handleroch')
  NxTest.assert(shared.include?('Vráť ho späť do skrinky'),
                'hlaska povie aj CO ROBIT, nielen ze sa nic nestalo')
end

# --- 2) VSETKY zapisove cesty karty -----------------------------------------

NxTest.test('odpojeny dielec: ABS hrana sa NEZAPISE (a povie sa to nahlas)') do
  body = odp_body('handle_set_part_edge')
  NxTest.assert(body.include?("detached_part_error(cab, find_selected_part(model), 'ABS hrana')"),
                'cesta hrany ma guard')
  NxTest.assert(body.include?('return set_status(err, true) if err'),
                'zamietnutie je hlasne, nie tichy no-op')
  NxTest.assert(odp_guard_before(body, 'existing_params'),
                'guard stoji PRED citanim/zapisom params')
  NxTest.assert(odp_guard_before(body, 'store_override'), 'guard stoji PRED zapisom overridu')
  NxTest.assert(odp_guard_before(body, 'rebuild_focus_part'), 'guard stoji PRED prestavbou')
end

NxTest.test('odpojeny dielec: bulk „všetky 4 hrany" sa NEZAPISE') do
  body = odp_body('handle_set_part_edges_all')
  NxTest.assert(body.include?("detached_part_error(cab, part, 'olep hrán')"),
                'bulk ma guard nad SKUTOCNE oznacenym dielcom')
  NxTest.assert(body.include?('return set_status(err, true) if err'),
                'bulk odpojeneho dielca NEKONCI tichym zahodenim ako echo — pouzivatel prave klikol')
  NxTest.assert(odp_guard_before(body, 'ensure_missing_abs'),
                'guard stoji PRED tvorbou pasky v globalnom katalogu')
  NxTest.assert(odp_guard_before(body, 'store_override'), 'guard stoji PRED zapisom overridu')
end

NxTest.test('odpojeny dielec: material dielca sa NEZAPISE ani do modelu, ani do katalogu') do
  body = odp_body('handle_set_part_material')
  NxTest.assert(body.include?("detached_part_error(cab, find_selected_part(model), 'materiál dielca')"),
                'materialova cesta ma guard')
  NxTest.assert(odp_guard_before(body, 'virtual_duplak_probe'), 'guard stoji PRED katalogovymi kontrolami')
  NxTest.assert(odp_guard_before(body, 'ensure_missing_abs'),
                'guard stoji PRED tvorbou ABS (katalogovy zapis je MIMO undo — nesmie zostat stopa)')
  NxTest.assert(odp_guard_before(body, 'store_override'), 'guard stoji PRED zapisom overridu')
end

NxTest.test('odpojeny dielec: smer dekoru ide TYM ISTYM guardom (K1 sa nan napojil)') do
  body = odp_body('grain_target_error')
  NxTest.assert(body.include?("detached_part_error(cab, part, 'smer dekoru')"),
                'K1 nezdvojuje vlastnu hlasku — pouziva spolocny guard')
end

NxTest.test('odpojeny dielec: „Použiť na podobné" ho odmietne aj ako ZDROJ') do
  # UI-D1 (Codex #180 P1) uz odpojene dielce vylucila z CIELOV cez
  # `regenerated_parts`. Zdroj sa vsak cital podla kluca z params — teda
  # override VNORENEHO dvojcata, nie hrany, ktore ma vybrany dielec naozaj.
  body = odp_body('similar_context')
  NxTest.assert(body.include?("detached_part_error(cab, part, 'olep hrán')"),
                'spolocny kontext oboch ciest ma guard')
  NxTest.assert(body.include?('return [nil, nil, nil, err] if err'),
                'chyba sa vracia kontraktom similar_context (dostane ju zapis AJ zivy pocet)')
  map = odp_body('regenerated_parts')
  NxTest.assert(map.include?('cab.definition.entities'),
                'ciele ostavaju VYHRADNE vnorene dielce (UI-D1 nezmenene)')
end

# --- 3) Spravanie guardu (nie len text v subore) -----------------------------

class OdpDefinition
  def valid?
    true
  end
end

class OdpCabinet
  attr_reader :definition

  def initialize(definition)
    @definition = definition
  end

  def valid?
    true
  end
end

class OdpPart
  attr_reader :parent

  def initialize(parent)
    @parent = parent
  end

  def valid?
    true
  end
end

NxTest.test('odpojeny dielec: vnoreny prejde, odpojeny dostane hlasku, prazdny vyber nerozbije guard') do
  cabdef = OdpDefinition.new
  cab = OdpCabinet.new(cabdef)
  nested = OdpPart.new(cabdef)          # rodic = definicia skrinky
  detached = OdpPart.new(Object.new)    # rodic = model (vytiahnuty dielec)

  NxTest.assert(ODP_PANEL.nested_part?(cab, nested), 'vnoreny dielec ma za rodica definiciu skrinky')
  NxTest.refute(ODP_PANEL.nested_part?(cab, detached), 'odpojeny dielec definiciu za rodica NEMA')

  NxTest.assert_equal(nil, ODP_PANEL.detached_part_error(cab, nested, 'ABS hrana'),
                      'vnoreny dielec sa meni ako doteraz')
  msg = ODP_PANEL.detached_part_error(cab, detached, 'ABS hrana')
  NxTest.assert(msg.to_s.include?('vytiahnutý zo skrinky'), 'odpojeny dielec dostane hlasku')
  NxTest.assert(msg.to_s.include?('ABS hrana'), 'hlaska pomenuje, CO sa nezmenilo')
  NxTest.assert_equal(nil, ODP_PANEL.detached_part_error(cab, nil, 'ABS hrana'),
                      'bez dielca vo vybere guard NETVRDI nic (kontroly cesty ostavaju jej)')
end
