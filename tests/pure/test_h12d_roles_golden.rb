# frozen_string_literal: true
# H12d (blok 9 HARDENING, C-05) — GOLDEN CHARAKTERIZACIA MIEN ROLI PRED
# presunom tabulky mien do `PartKeys` (package H12 §6 R0.6, R4.1–R4.4).
#
# Odtlacok vsetkych dnesnych zobrazovacich mien roli na strane Ruby:
#   * `ProductionCore.role_label` pre kazdu rolu `BuildPlan::ROLES` + neznamu,
#     prazdnu, nil a Symbol,
#   * `rows_with_roles` nad fixturou zaznamov (zrkadlove boky v jednom riadku,
#     dielce zasuvky, neznama a prazdna rola),
#   * `RulesDialog.abs_role_label` (prehlad ABS — neznama rola sa vypise),
#   * `PartKeys.human_label` nad vzorkami klucov (Kovanie, Kontrola) a tabulky
#     `ZONE_PART_LABELS` / `DRAWER_PART_LABELS`,
#   * `Panel.board_payload['role_label']` (karta dosky).
#
# Fixtura `tests/fixtures/h12_golden/roles.json` vznikla na NEZMENENOM kode
# (prvy commit H12d, `generate.rb roles`) a NEREGENERUJE sa — rozdiel je NALEZ.
# Kusovnik, VEPO, nakup ani rozpocet sa H12d nemenia; jedina viditelna zmena
# je hlavicka karty dielca (JS — `tests/js/test_h12d_mena_roli.js`).
require_relative '../helper' unless defined?(NxTest)
require 'json'

if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core') unless defined?(Noxun::Engine::ProductionCore)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog') unless defined?(Noxun::Engine::RulesDialog)
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

module NxH12dGolden
  module_function

  E = Noxun::Engine

  PATH = File.join(NxTest::ROOT, 'tests', 'fixtures', 'h12_golden', 'roles.json')
  # Rola mimo slovnika (napr. z novsieho pluginu) a prazdna rola — obe sa
  # dnes vypisu tak, ako prisli (nova rola sa nestrati, prazdna nevymysla text).
  EXTRA = ['neznama_rola', ''].freeze

  def rt(obj)
    JSON.parse(JSON.generate(obj))
  end

  def roles
    E::BuildPlan::ROLES + EXTRA
  end

  def rec(role, name, len, wid, mat = 'M1')
    { 'name' => name, 'part_key' => "p-#{role}-#{name}", 'owner_id' => 'CAB-1', 'pid' => 1,
      'role' => role, 'length' => len, 'width' => wid, 'thickness' => 18.0,
      'quantity' => 1, 'material_id' => mat, 'grain_direction' => 'length',
      'edges' => { 'L1' => nil, 'L2' => nil, 'W1' => nil, 'W2' => nil } }
  end

  # Zaznamy kusovnika: zrkadlove boky (jeden riadok, dve roly), strop + dno
  # rovnakeho rozmeru (jeden riadok), dielce zasuvky, neznama a prazdna rola.
  def records
    [rec('side_left', 'Bok', 720.0, 560.0), rec('side_right', 'Bok', 720.0, 560.0),
     rec('top', 'Doska', 564.0, 560.0), rec('bottom', 'Doska', 564.0, 560.0),
     rec('divider_v', 'Priecka', 700.0, 540.0), rec('divider_h', 'Priecka', 560.0, 540.0),
     rec('drawer_front', 'Celo', 596.0, 176.0, 'K1'), rec('drawer_bottom', 'Dno zasuvky', 500.0, 450.0),
     rec('drawer_back', 'Chrbat zasuvky', 500.0, 120.0), rec('box_side', 'Bok boxu', 450.0, 120.0),
     rec('drawer_inner_front', 'Vnutorne celo', 500.0, 110.0), rec('free_panel', 'Doska', 800.0, 600.0, 'M2'),
     rec('neznama_rola', 'Nieco', 300.0, 200.0), rec('', 'Bez roly', 310.0, 200.0)]
  end

  def rows_with_roles
    recs = records
    bom = E::Bom.compute(records: recs)
    E::ProductionCore.rows_with_roles(bom[:rows], records: recs).map do |r|
      { 'names' => r['names'], 'role_label' => r['role_label'] }
    end
  end

  HUMAN_KEYS = %w[
    zone:Z1/shelf:1 zone:Z1/divider_v:2 zone:Z1/divider_h:3
    front:F2/drawer_bottom front:F2/drawer_back front:F2/drawer_inner_front
    front:F2/box_side:left front:F2/box_side:right front:F2/panel
    cabinet/side_left cabinet/corner_panel board/main
  ].freeze

  def board_role_label(role)
    inst = NxTest::FakeInstance.new(4242)
    E::Store.write(inst, { std: E::Store::STD, kind: 'board', id: 'BRD-901', role: role, name: '',
                           config: { 'length' => 800.0, 'width' => 600.0, 'thickness' => 18.0, 'edges' => {} } })
    E::Panel.board_payload(inst)['role_label']
  end

  def snapshot
    pc = E::ProductionCore
    {
      'roles' => roles,
      'role_label' => roles.to_h { |r| [r, pc.role_label(r)] }
                           .merge('(nil)' => pc.role_label(nil), '(symbol shelf)' => pc.role_label(:shelf)),
      'rows_with_roles' => rows_with_roles,
      'abs_role_label' => roles.to_h { |r| [r, E::RulesDialog.abs_role_label(r)] },
      'human_label' => HUMAN_KEYS.to_h { |k| [k, E::PartKeys.human_label(k)] },
      'zone_part_labels' => E::PartKeys::ZONE_PART_LABELS,
      'drawer_part_labels' => E::PartKeys::DRAWER_PART_LABELS,
      'board_role_label' => ['free_panel', '', 'neznama_rola'].to_h { |r| [r, board_role_label(r)] }
    }
  end

  def pretty(obj)
    JSON.pretty_generate(rt(obj)) + "\n"
  end
end

if NxTest.headless?
  NxTest.test('H12d golden: mena roli (Kusovnik, prehlad ABS, Kovanie/Kontrola, karta dosky) bez zmeny') do
    path = NxH12dGolden::PATH
    NxTest.assert(File.exist?(path), "chyba fixtura #{path} (generator tests/fixtures/h12_golden/generate.rb roles)")
    want = File.read(path, encoding: 'UTF-8').gsub("\r\n", "\n")
    got = NxH12dGolden.pretty(NxH12dGolden.snapshot)
    unless got == want
      w = JSON.parse(want)
      g = JSON.parse(got)
      diff = (w.keys | g.keys).reject { |k| w[k] == g[k] }
      NxTest.assert(false, "golden mien roli sa rozisiel: #{diff.join(', ')}")
    end
  end
end
