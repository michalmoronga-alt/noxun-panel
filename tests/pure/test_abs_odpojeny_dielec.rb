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
# DOTIAHNUTIE (Codex #186 P1, v0.7.25): odpojenost sama nestacila. Ked sa vyber
# medzi klikom a callbackom presunie z dielca na SKRINKU, `find_cabinet` ju
# najde, ale `find_selected_part` vrati `nil` — a cesty hrany/materialu potom
# podla stareho `role_key` prestavali VNORENE DVOJCA, teda presne tu skodu,
# ktoru mal PR #185/#186 zastavit. Vsetky tri zapisove cesty karty preto idu
# JEDNOU branou `part_target_error` (dokument · dielec vo vybere · zhoda kluca ·
# odpojenost). Bulk si necha vlastnu TICHU vetvu — tam ide o stale echo.
#
# Co sa tu strazi:
#   1) hlaska aj kontrola ziju na JEDNOM mieste (`detached_part_error`) —
#      ziadna kopia textu po handleroch
#   2) KAZDA zapisova cesta karty (ABS hrana, bulk olep, material dielca,
#      smer dekoru, „Použiť na podobné") sa nan napaja PRED akymkolvek zapisom
#   3) CHYBAJUCI dielec vo vybere je ODMIETNUTIE, nie priepustna cesta
#   4) spravanie samotneho guardu: vnoreny dielec prejde, odpojeny dostane
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

# Guard musi stat PRED prvym zapisom — nie „niekde v tele". Spolocna brana
# zapisovych ciest je `part_target_error`; bulk ma vlastnu (`detached_part_error`),
# lebo chybajuci vyber tam patri do TICHEJ echo vetvy.
def odp_guard_before(body, marker, guard = 'part_target_error')
  g = body.index(guard)
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
  NxTest.assert(body.include?("part_target_error(model, cab, params, rk, 'ABS hrana')"),
                'cesta hrany ide SPOLOCNOU branou')
  NxTest.assert(body.include?('return set_status(err, true) if err'),
                'zamietnutie je hlasne, nie tichy no-op')
  # Brana potrebuje KANONICKY kluc, takze stoji az za jeho dopoctom — ale
  # stale PRED akymkolvek zapisom (params sa dovtedy len citaju).
  NxTest.assert(body.index('canonical_part_key') < body.index('part_target_error'),
                'brana dostane uz kanonicky kluc')
  NxTest.assert(body.index('part_target_error') < body.index('store_override'),
                'brana stoji PRED zapisom overridu')
  NxTest.assert(body.index('part_target_error') < body.index('rebuild_focus_part'),
                'brana stoji PRED prestavbou')
end

NxTest.test('odpojeny dielec: bulk „všetky 4 hrany" sa NEZAPISE') do
  body = odp_body('handle_set_part_edges_all')
  NxTest.assert(body.include?("detached_part_error(cab, part, 'olep hrán')"),
                'bulk ma guard nad SKUTOCNE oznacenym dielcom')
  NxTest.assert(body.include?('return set_status(err, true) if err'),
                'bulk odpojeneho dielca NEKONCI tichym zahodenim ako echo — pouzivatel prave klikol')
  NxTest.assert(odp_guard_before(body, 'ensure_missing_abs', 'detached_part_error'),
                'guard stoji PRED tvorbou pasky v globalnom katalogu')
  NxTest.assert(odp_guard_before(body, 'store_override', 'detached_part_error'),
                'guard stoji PRED zapisom overridu')
end

NxTest.test('odpojeny dielec: material dielca sa NEZAPISE ani do modelu, ani do katalogu') do
  body = odp_body('handle_set_part_material')
  NxTest.assert(body.include?("part_target_error(model, cab, params, rk, 'materiál dielca')"),
                'materialova cesta ide SPOLOCNOU branou')
  NxTest.assert(odp_guard_before(body, 'virtual_duplak_probe'), 'brana stoji PRED katalogovymi kontrolami')
  NxTest.assert(odp_guard_before(body, 'ensure_missing_abs'),
                'brana stoji PRED tvorbou ABS (katalogovy zapis je MIMO undo — nesmie zostat stopa)')
  NxTest.assert(odp_guard_before(body, 'store_override'), 'brana stoji PRED zapisom overridu')
end

NxTest.test('odpojeny dielec: smer dekoru ide TOU ISTOU branou (K1 sa nan napojil)') do
  body = odp_body('handle_set_part_grain')
  NxTest.assert(body.include?("part_target_error(model, cab, params, rk, 'smer dekoru')"),
                'K1 nezdvojuje vlastnu hlasku — pouziva spolocnu branu')
  NxTest.assert(odp_guard_before(body, 'store_override'), 'brana stoji PRED zapisom overridu')
  gate = odp_body('part_target_error')
  NxTest.assert(gate.include?("detached_part_error(cab, part, what)"),
                'brana odpojenost nekopiruje — deleguje na spolocny guard a predava PREDMET zmeny')
  NxTest.refute(ODP_PARTS_RB.include?('def grain_target_error'),
                'stara „len grainova" brana uz neexistuje — inak by vznikli dve rozne prisnosti')
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

NxTest.test('chybajuci dielec vo vybere je ODMIETNUTIE, nie priepustna cesta (Codex #186 P1)') do
  # Vyber sa medzi klikom a callbackom presunie z dielca na SKRINKU:
  # `find_cabinet` ju najde (je oznacena), ale `find_selected_part` vrati nil.
  # Zapis „naslepo" podla `role_key` z payloadu by potom trafil VNORENE DVOJCA
  # — teda presne tu skodu, ktoru mala tato sada zastavit. Puvodne to bola
  # vedoma diera („o odpojenosti sa bez dielca neda tvrdit nic"), lenze brana
  # nema tvrdit o odpojenosti — ma tvrdit o CIELI zmeny.
  gate = odp_body('part_target_error')
  NxTest.assert(!gate.empty?, 'spolocna brana ciela existuje')
  NxTest.assert(gate.include?('Vo výbere nie je dielec'),
                'prazdny vyber dostane hlasku, nie ticho prejde')
  NxTest.assert(gate.include?('canonical_part_key(params, part_identity(cab, part)) != rk'),
                'karta musi patrit dielcu, ktory je NAOZAJ vo vybere')
  NxTest.assert(gate.index('find_selected_part(model)') < gate.index('detached_part_error'),
                'najprv sa zisti, CI vobec je co menit')

  %w[handle_set_part_edge handle_set_part_material handle_set_part_grain].each do |h|
    body = odp_body(h)
    NxTest.assert(body.include?('part_target_error(model, cab, params, rk,'),
                  "#{h} ide spolocnou branou (ziadna „volnejsia\" cesta)")
    NxTest.assert(body.include?('return set_status(err, true) if err'),
                  "#{h} odmietnutie HLASI")
  end

  # Bulk je vynimka SO ZDOVODNENIM: tam chybajuci dielec znamena stale echo
  # z prekliku, nie akciu, ktoru by bolo co hlasit — a zahodi sa TICHO.
  bulk = odp_body('handle_set_part_edges_all')
  NxTest.assert(bulk.include?('if part.nil?'), 'bulk si drzi vlastnu vetvu prazdneho vyberu')
  NxTest.assert(bulk.include?('bulk hrany zahodene — vo vybere nie je dielec'),
                'tiche zahodenie je aspon v logu (nikdy uplne nemy no-op)')
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
  # `part.nil?` sem uz NEDOJDE — chybajuci vyber odmietne kazdy volajuci sam
  # (brana hlaskou, bulk tichym zahodenim). Vetva ostava ako poistka: mlcky
  # prejst je bezpecne jedine vtedy, ked uz niekto pred nou povedal nie.
  NxTest.assert_equal(nil, ODP_PANEL.detached_part_error(cab, nil, 'ABS hrana'),
                      'guard bez dielca NETVRDI nic — o cieli rozhoduje brana nad nim')
end
