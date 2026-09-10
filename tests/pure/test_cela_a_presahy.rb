# frozen_string_literal: true
require_relative '../helper' unless defined?(NxTest)

module NxCelaA
  E = Noxun::Engine
  F = E::Fronts
  CB = E::CabinetBuilder
  def self.fronts(extra = {})
    { 'gap_left' => -18.0, 'gap_right' => 2.0,
      'items' => [{ 'id' => 'F1', 'type' => 'door', 'wings' => '2', 'mode' => 'auto' }] }.merge(extra)
  end
end

NxTest.test('CELA-A: kazda strana migruje samostatne a explicitna nula vyhrava') do
  f = NxCelaA::F
  [nil, 'none', 'auto', '2', {}].each do |raw|
    cfg = f.normalize_config(raw)
    NxTest.assert_equal([2.0, 2.0], cfg.values_at('gap_left', 'gap_right'))
    NxTest.refute(cfg.key?('gap_sides'))
  end
  [{ 'gap_sides' => -8, 'gap_left' => 0 }, { gap_sides: -8, gap_left: 0 }].each do |raw|
    cfg = f.normalize_config(raw)
    NxTest.assert_equal([0.0, -8.0], cfg.values_at('gap_left', 'gap_right'))
    NxTest.assert_equal(cfg, f.normalize_config(cfg))
  end
  NxTest.assert_equal([-8.0, 0.0], f.normalize_config('gap_sides' => -8, 'gap_right' => 0).values_at('gap_left', 'gap_right'))
  NxTest.assert_equal([-18.0, 2.0], f.normalize_config(NxCelaA.fronts('gap_sides' => 90)).values_at('gap_left', 'gap_right'))
end

NxTest.test('CELA-A: rozhodujuci priklad W600 L-18 R2 a zrkadlo') do
  [[-18, 2, -18.0, 291.5], [2, -18, 2.0, 311.5]].each do |left, right, x1, x2|
    r = NxCelaA::F.layout(NxCelaA.fronts('gap_left' => left, 'gap_right' => right), 600, 720, 0, 18)
    NxTest.assert_equal([x1, x2], r[:parts].map { |p| p[:origin][0] })
    NxTest.assert_equal([306.5, 306.5], r[:parts].map { |p| p[:box][0] })
    NxTest.assert_equal([716.0, 716.0], r[:parts].map { |p| p[:prod][:length] })
    NxTest.assert_equal(2, r[:items][0]['wings_n'])
  end
end

NxTest.test('CELA-A: strany platia pre kazdy typ a automatiku poctu kridiel') do
  %w[door drawer_front lift fall blind].each do |type|
    cfg = NxCelaA.fronts('items' => [{ 'id' => 'F1', 'type' => type, 'wings' => '1' }])
    r = NxCelaA::F.layout(cfg, 600, 720, 0, 18)
    NxTest.assert_close(-18.0, r[:parts][0][:origin][0])
    NxTest.assert_close(616.0, r[:parts][0][:box][0])
  end
  cfg = NxCelaA.fronts('items' => [{ 'type' => 'door', 'wings' => 'auto' }])
  NxTest.assert_equal(2, NxCelaA::F.layout(cfg, 600, 720, 0, 18)[:wings])
  NxTest.assert_equal(1, NxCelaA::F.layout(cfg.merge('gap_left' => 0, 'gap_right' => 0), 600, 720, 0, 18)[:wings])
end

NxTest.test('CELA-A: neplatne a nekonecne strany sa odmietnu aj bez ciel') do
  %w[gap_left gap_right].each do |key|
    [nil, '', 'xyz', '18oops', true, Float::NAN, Float::INFINITY].each do |bad|
      NxTest.assert_raise(/Okraj/) { NxCelaA::F.layout({ key => bad }, 600, 720, 0, 18) }
    end
    [-101, 101, -2001, 2001].each do |bad|
      NxTest.assert_raise(/Okraj/) { NxCelaA::F.layout({ key => bad }, 600, 720, 0, 18) }
    end
    [-2000, 2000].each do |edge|
      NxCelaA::F.layout({ key => edge, 'edge_limit_off' => true }, 600, 720, 0, 18)
    end
  end
end

NxTest.test('CELA-A: config JSON a copy/rebuild params zachovaju asymetriu a schema guard') do
  cb = NxCelaA::CB
  cfg = cb.normalize('width' => 600, 'height' => 720, 'depth' => 510, 'fronts' => NxCelaA.fronts)
  saved = JSON.parse(JSON.generate(cb.cabinet_config(cfg)))
  NxTest.assert_equal(12, saved['config_schema'])
  NxTest.assert_equal(5, NxCelaA::E::BuildPlan::SCHEMA)
  3.times do
    cfg = cb.normalize(cb.config_to_params(saved))
    saved = JSON.parse(JSON.generate(cb.cabinet_config(cfg)))
    NxTest.assert_equal([-18.0, 2.0], saved['fronts'].values_at('gap_left', 'gap_right'))
    NxTest.refute(saved['fronts'].key?('gap_sides'))
    plan = NxCelaA::E::Construction.build_plan(cfg)
    panels = plan[:parts].select { |p| p[:role] == 'front_door' }
    NxTest.assert_equal([306.5, 306.5], panels.map { |p| p[:prod][:width] })
  end
  NxTest.assert(cb.newer_config?('config_schema' => 13))
end
