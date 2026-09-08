# frozen_string_literal: true
# D-121a (8.9.2026, dielna) — DIELCE ZASUVKY MAJU LUDSKE NAZVY.
#
# Vo VEPO exporte vznikali riadky `Dno zasuvky Fmslwqdm2-9-464wsa`: nazov niesol
# INTERNE ID cela (`drawer_part_descriptor`, KOV-C2b) a `short_name` ho nepoznal,
# takze presiel cely. Cloveku id nic nepovie a nalepka VEPO ma ~20 znakov.
#
# Co sa overuje:
#   1) nazvy dielcov zasuvky nesu CISLO CELA — to iste, ake ma „Zasuvkove celo N"
#      (poradie v `front_items`, F1 = spodne), a to aj ked je pred zasuvkou iny
#      typ cela alebo riadok „Bez cela" ('none')
#   2) IDENTITA dielca sa nezmenila: `suffix` a `part_key` dalej stoja na id cela,
#      `prod` a `axes` su bajtovo tie iste ako pri jednocelovom plane
#   3) `VepoExport.short_name` skracuje dielce zasuvky (`Zas dno N`, `Zas chrb N`,
#      `Zas predok N`, `Zas bok L/P N`); LEGACY nazov s id cela ide bez cisla
#   4) dva boky boxu JEDNEJ zasuvky sa v riadku zluia do `Zas bok LP N` — rovnakym
#      mechanizmom ako dvierka, a VYHRADNE z generovanych nazvov (volny nazov
#      dosky sa nikdy nepari ani neskracuje)
#   5) guard pre D-121b (kontrakt v1.2, NAME_MAX 20): najdlhsi kratky tvar dielca
#      zasuvky s dvojcifernym cislom + vlastnik sa do 20 znakov zmesti
#   6) charakterizacia: nazov do `Bom.row_key` NEPATRI — dva dielce s roznym
#      nazvom a rovnakymi vyrobnymi parametrami su dalej JEDEN riadok
#
# MUTACIE, ktore tato sada chyta (kazda by prazdnou sadou presla):
#   M1 `idx` v nazve nahradene `front_id` -> „nazvy nesu cislo cela"
#   M2 chyba legacy fallback (`num_suffix`) -> id cela by preslo do skratky
#   M3 boky boxu sa nezluia do `LP` -> „Zas bok LP 2"
#   M4 `num_suffix` bez `to_i` (`Dno zasuvky 02`) -> „Zas dno 2"
require_relative '../helper' unless defined?(NxTest)

module NxD121
  E  = Noxun::Engine
  CB = E::CabinetBuilder
  CN = E::Construction

  module_function

  def vepo
    E::VepoExport
  end

  # Skrinka 900 x 720 x 500 (vzor `NxD5.cfg`). Id ciel su explicitne, aby asercie
  # citali `part_key` `front:F2/...` bez hadania.
  DRAWER = { 'type' => 'drawer_front', 'mode' => 'fixed', 'height' => 175.0,
             'opening_mode' => 'classic', 'drawer' => { 'construction' => 'metal' } }.freeze
  DOOR   = { 'type' => 'door', 'mode' => 'fixed', 'height' => 300.0 }.freeze

  def cfg(items)
    CB.normalize('width' => 900.0, 'height' => 720.0, 'depth' => 500.0,
                 'fronts' => { 'items' => items })
  end

  def plan(items)
    CN.build_plan(cfg(items), 'CAB-1')
  end

  def drawer_names(pl)
    pl[:parts].select { |p| p[:material] == :drawer }.map { |p| p[:name] }
  end

  def part(pl, key)
    pl[:parts].find { |p| p[:part_key] == key }
  end

  # F1 dvierka + F2 zasuvka; `wood` = Quadro (vyraba aj boky a vnutorne celo).
  def door_then_drawer(construction = 'metal')
    plan([DOOR.merge('id' => 'F1'),
          DRAWER.merge('id' => 'F2', 'drawer' => { 'construction' => construction })])
  end

  def atira_f2
    @atira_f2 ||= door_then_drawer
  end

  def quadro_f2
    @quadro_f2 ||= door_then_drawer('wood')
  end

  # Jedno celo (zasuvka je F1) — referencia pre „identita a vyrobne cisla sa nezmenili".
  def only_drawer
    @only_drawer ||= plan([DRAWER.merge('id' => 'F1')])
  end
end

NxTest.test('D-121a: dielce zasuvky nesu CISLO CELA, nie id (Atira aj Quadro)') do
  d = NxD121
  NxTest.assert_equal(['Dno zasuvky 2', 'Chrbat zasuvky 2'], d.drawer_names(d.atira_f2),
                      'Atira: dno + chrbat druheho cela')
  NxTest.assert_equal(['Bok boxu lavy 2', 'Bok boxu pravy 2', 'Dno zasuvky 2',
                       'Vnutorne celo zasuvky 2', 'Chrbat zasuvky 2'],
                      d.drawer_names(d.quadro_f2), 'Quadro: aj boky a vnutorne celo')
  # Cislo je TO ISTE, ake nesie panel cela — jedna pravda o cislovani.
  panel = d.quadro_f2[:parts].find { |p| p[:part_key] == 'front:F2/panel' }
  NxTest.assert_equal('Zasuvkove celo 2', panel[:name], 'panel cela ma rovnake cislo')
end

NxTest.test('D-121a: cislo drzi poradie v `front_items` — dve zasuvky, aj riadok „Bez cela"') do
  d = NxD121
  dve = d.plan([NxD121::DRAWER.merge('id' => 'F1'), NxD121::DRAWER.merge('id' => 'F2')])
  NxTest.assert_equal(['Dno zasuvky 1', 'Chrbat zasuvky 1', 'Dno zasuvky 2', 'Chrbat zasuvky 2'],
                      d.drawer_names(dve), 'poradie zdola: F1 = 1, F2 = 2')
  # Riadok 'none' (nika) panely negeneruje, ale cislo v zozname DRZI — inak by sa
  # cislovanie rozislo s tym, co pouzivatel vidi v karte Cela.
  nika = d.plan([{ 'type' => 'none', 'mode' => 'fixed', 'height' => 300.0, 'id' => 'F1' },
                 NxD121::DRAWER.merge('id' => 'F2')])
  NxTest.assert_equal(['Dno zasuvky 2', 'Chrbat zasuvky 2'], d.drawer_names(nika),
                      'nika cislo nepreskakuje')
end

NxTest.test('D-121a: IDENTITA dielca na nazve nezavisi (suffix, part_key, prod, axes)') do
  d = NxD121
  bottom = d.part(d.atira_f2, 'front:F2/drawer_bottom')
  NxTest.assert_equal('Dno zasuvky 2', bottom[:name])
  NxTest.assert_equal('DRWBOT-F2-1', bottom[:suffix], 'suffix dalej stoji na ID cela')
  NxTest.assert_equal('front:F2/drawer_bottom', bottom[:part_key])
  back = d.part(d.atira_f2, 'front:F2/drawer_back')
  NxTest.assert_equal('DRWBACK-F2-2', back[:suffix])
  # Vyrobne cisla a osi su PRESNE tie, ktore dava plan s jedinym celom rovnakej
  # vysky — zmena je vylucne retazec nazvu.
  ref = d.part(d.only_drawer, 'front:F1/drawer_bottom')
  NxTest.assert_equal('Dno zasuvky 1', ref[:name])
  NxTest.assert_equal(ref[:prod], bottom[:prod], 'vyrobne rozmery dna nedotknute')
  NxTest.assert_equal(ref[:axes], bottom[:axes], 'osi dna nedotknute')
  NxTest.assert_equal(ref[:role], bottom[:role])
  ref_back = d.part(d.only_drawer, 'front:F1/drawer_back')
  NxTest.assert_equal(ref_back[:prod], back[:prod], 'vyrobne rozmery chrbta nedotknute')
  NxTest.assert_equal(ref_back[:axes], back[:axes], 'osi chrbta nedotknute')
end

NxTest.test('D-121a: `short_name` — dielce zasuvky, vratane LEGACY nazvu s id cela') do
  v = NxD121.vepo
  {
    'Dno zasuvky 2' => 'Zas dno 2',
    'Chrbat zasuvky 12' => 'Zas chrb 12',
    'Vnutorne celo zasuvky 3' => 'Zas predok 3',
    'Bok boxu lavy 2' => 'Zas bok L 2',
    'Bok boxu pravy 2' => 'Zas bok P 2',
    # legacy (zakazka postavena pred D-121a): id cela sa do skratky NEPRENASA
    'Dno zasuvky Fmslwqdm2-9-464wsa' => 'Zas dno',
    'Bok boxu pravy F1' => 'Zas bok P',
    # M4: cislo prejde cez `to_i`
    'Dno zasuvky 02' => 'Zas dno 2',
    # bez tokenu to nas vzor nie je — nazov ide BEZ ZMENY
    'Dno zasuvky' => 'Dno zasuvky',
    'Bok boxu lavy' => 'Bok boxu lavy',
    # D-113 skratky sa nemenia
    'Zasuvkove celo 3' => 'Zas celo 3',
    'Bok lavy' => 'Bok L'
  }.each { |from, to| NxTest.assert_equal(to, v.short_name(from), "skratka #{from.inspect}") }
end

NxTest.test('D-121a: `row_name` — dva boky boxu jednej zasuvky su `Zas bok LP N`') do
  v = NxD121.vepo
  cab = [{ 'owner_id' => 'CAB-001' }]
  NxTest.assert_equal('Zas dno 2 s1', v.row_name('names' => ['Dno zasuvky 2'], 'kde' => cab))
  NxTest.assert_equal('Zas bok LP 2 s1',
                      v.row_name('names' => ['Bok boxu lavy 2', 'Bok boxu pravy 2'], 'kde' => cab))
  # legacy dvojica (obe strany s id) sa zluci tiez — pripona je u oboch prazdna
  NxTest.assert_equal('Zas bok LP s1',
                      v.row_name('names' => ['Bok boxu lavy F1', 'Bok boxu pravy F1'], 'kde' => cab))
  # boky ROZNYCH zasuviek nie su par — cast s nazvami to povie (v1.2 ju uz oreze)
  info = v.row_name_info('names' => ['Bok boxu lavy 1', 'Bok boxu pravy 2'], 'kde' => cab)
  NxTest.assert_equal('Zas bok L 1/Zas bok P 2', info['full'], 'rozne zasuvky sa NEPARUJU')
  # dve zasuvky v jednom riadku: od D-121b sa cisla zluia do jedneho tokenu
  NxTest.assert_equal('Zas dno 1 2 s1',
                      v.row_name('names' => ['Dno zasuvky 1', 'Dno zasuvky 2'], 'kde' => cab))
end

NxTest.test('D-121a: volny nazov dosky sa NESKRACUJE ani nepari (GH #287 zasada)') do
  v = NxD121.vepo
  free = { 'names' => ['Dno zasuvky 3'], 'free_names' => ['Dno zasuvky 3'],
           'kde' => [{ 'owner_id' => 'BRD-001' }] }
  NxTest.assert_equal('Dno zasuvky 3 d1', v.row_name(free), 'volny text pouzivatela ide cely')
  mix = { 'names' => ['Bok boxu lavy 2', 'Bok boxu pravy 2'], 'free_names' => ['Bok boxu lavy 2'],
          'kde' => [{ 'owner_id' => 'CAB-001' }, { 'owner_id' => 'BRD-002' }] }
  # Cast s nazvami sa NEPARUJE (a od D-121b sa ani nezluci cez cislo) — v1.2 ju
  # uz limit 20 oreze, plny tvar ostava v `full` (LOG + Kontrola ho ukazu).
  NxTest.assert_equal('Bok boxu lavy 2/Zas bok P 2', v.row_name_info(mix)['full'],
                      'doska + dielec skrinky nie su par ani zlucene cislo')
end

NxTest.test('D-121a/b: kratky tvar + vlastnik sa zmesti do 20 znakov (kontrakt v1.2)') do
  v = NxD121.vepo
  kde = [{ 'owner_id' => 'CAB-012' }]
  ['Dno zasuvky 12', 'Chrbat zasuvky 12', 'Vnutorne celo zasuvky 12',
   'Bok boxu lavy 12', 'Bok boxu pravy 12'].each do |name|
    got = v.row_name('names' => [name], 'kde' => kde)
    NxTest.assert(got.length <= 20, "#{name.inspect} -> #{got.inspect} (#{got.length} znakov) nad 20")
  end
  # najdlhsi tvar je `Zas predok 12 s12` = 17 znakov
  NxTest.assert_equal('Zas predok 12 s12',
                      v.row_name('names' => ['Vnutorne celo zasuvky 12'], 'kde' => kde))
  NxTest.assert_equal(20, v.const_get(:NAME_MAX), 'kontrakt v1.2 — NAME_MAX je 20 (D-121b)')
end

NxTest.test('D-121a: charakterizacia — nazov do `Bom.row_key` nepatri (agregacia nezmenena)') do
  bom = Noxun::Engine::Bom
  base = { 'length' => 791.5, 'width' => 480.0, 'thickness' => 16.0, 'material_id' => 'M1',
           'grain_direction' => 'none', 'quantity' => 1,
           'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  rows = bom.aggregate_rows([
                              base.merge('name' => 'Dno zasuvky 1', 'owner_id' => 'CAB-001',
                                         'part_key' => 'front:F1/drawer_bottom', 'pid' => 1),
                              base.merge('name' => 'Dno zasuvky 2', 'owner_id' => 'CAB-001',
                                         'part_key' => 'front:F2/drawer_bottom', 'pid' => 2)
                            ])
  NxTest.assert_equal(1, rows.length, 'zhodne vyrobne parametre = JEDEN riadok')
  NxTest.assert_equal(['Dno zasuvky 1', 'Dno zasuvky 2'], rows.first['names'])
  NxTest.assert_equal(2, rows.first['quantity'])
  NxTest.assert_equal('Zas dno 1 2 s1', NxD121.vepo.row_name(rows.first),
                      'cela cesta BOM -> VEPO (D-121b: cisla zlucene)')
end
