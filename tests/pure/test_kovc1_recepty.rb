# frozen_string_literal: true
# KOV-C1 — nemenne recepty zasuviek: register, validacia schemy, klasifikacia.
#
# Recept je NEMENNY: `Recipes.load` cita VYHRADNE recepty z registra
# `RELEASED.json` a odtlacok suboru musi sediet. Podvrhnuty obsah, chybajuca
# bunka ani neznamy system nesmu nikdy prejst na tichy default — vzdy vynimka.
require_relative '../helper' unless defined?(NxTest)
require 'tmpdir'

module NxKovC1
  module_function

  def r
    Noxun::Engine::Recipes
  end

  def base(id = 'atira_sisy_v1')
    JSON.parse(File.read(File.join(r::DIR, "#{id}.json"), encoding: 'UTF-8'))
  end

  # Docasny priecinok s VLASTNYM registrom (odtlacky sa dopocitaju).
  # files = { recipe_id => Hash (telo receptu) alebo String (surovy JSON) }
  # bad_sha = zoznam ID, ktorym sa do registra zapise NESPRAVNY odtlacok.
  def with_tmp(files, bad_sha: [])
    Dir.mktmpdir('noxun-kovc1-') do |d|
      reg = {}
      files.each do |id, body|
        raw = body.is_a?(String) ? body : "#{JSON.pretty_generate(body)}\n"
        File.write(File.join(d, "#{id}.json"), raw)
        sha = Digest::SHA256.hexdigest(raw.gsub("\r\n", "\n"))
        reg[id] = bad_sha.include?(id) ? ('0' * 64) : sha
      end
      File.write(File.join(d, 'RELEASED.json'), "#{JSON.pretty_generate(reg)}\n")
      yield d
    end
  end

  # Resolved polozka cela (`front_items`) pre `recipe_key_for`.
  def item(type: 'drawer_front', drawer: nil, opening_mode: nil)
    it = { 'id' => 'F1', 'type' => type }
    it['drawer'] = drawer if drawer
    it['opening_mode'] = opening_mode if opening_mode
    it
  end
end

# --- 1. Register a nemennost --------------------------------------------------

NxTest.test('KOV-C1: kazdy kluc registra ma subor so zhodnym odtlackom') do
  reg = NxKovC1.r.released
  NxTest.assert(reg.size >= 4, "register ma len #{reg.size} receptov")
  reg.each_key do |id|
    rec = NxKovC1.r.load(id)
    NxTest.assert_equal(id, rec[:recipe_id], "recipe_id v subore #{id} nesedi")
  end
end

NxTest.test('KOV-C1: inventar suborov receptov == mnozina klucov registra') do
  NxTest.assert_equal(NxKovC1.r.released.keys.sort, NxKovC1.r.inventory,
                      'nezaregistrovany alebo chybajuci subor receptu — vydany recept musi byt v RELEASED.json')
end

NxTest.test('KOV-C1: vsetky styri recepty V1 su vydane') do
  ids = NxKovC1.r.released.keys.sort
  %w[atira_p2o_v1 atira_sisy_v1 quadro_v6_p2o_v1 quadro_v6_sisy_v1].each do |id|
    NxTest.assert(ids.include?(id), "chyba recept #{id}")
  end
end

NxTest.test('KOV-C1: podvrhnuty obsah receptu = odmietnutie (odtlacok nesedi)') do
  NxKovC1.with_tmp({ 'atira_sisy_v1' => NxKovC1.base }, bad_sha: ['atira_sisy_v1']) do |d|
    NxTest.assert_raise('odtlacok') { NxKovC1.r.load('atira_sisy_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: neregistrovany recept sa nenacita ani ked subor existuje') do
  NxKovC1.with_tmp({ 'atira_sisy_v1' => NxKovC1.base }) do |d|
    File.write(File.join(d, 'atira_p2o_v1.json'), JSON.pretty_generate(NxKovC1.base('atira_p2o_v1')))
    NxTest.assert_raise('nie je v registri') { NxKovC1.r.load('atira_p2o_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: latest_for vrati NAJVYSSIU vydanu verziu') do
  v2 = NxKovC1.base.merge('recipe_id' => 'atira_sisy_v2', 'version' => 2)
  NxKovC1.with_tmp({ 'atira_sisy_v1' => NxKovC1.base, 'atira_sisy_v2' => v2 }) do |d|
    NxTest.assert_equal('atira_sisy_v2', NxKovC1.r.latest_for('atira', 'sisy', dir: d))
    NxTest.assert_equal(2, NxKovC1.r.load('atira_sisy_v2', dir: d)[:version])
  end
  NxTest.assert(NxKovC1.r.latest_for('atira', 'sisy').nil? == false)
  NxTest.assert(NxKovC1.r.latest_for('antaro', 'sisy').nil?, 'neznamy system nesmie vratit recept')
end

NxTest.test('KOV-C1: sibling drzi ROVNAKU verziu (prepnutie klasifikacie nepovysi recept)') do
  NxTest.assert_equal('quadro_v6_sisy_v1', NxKovC1.r.sibling('atira_sisy_v1', 'quadro_v6', 'sisy'))
  NxTest.assert_equal('atira_p2o_v1', NxKovC1.r.sibling('atira_sisy_v1', 'atira', 'p2o'))
  v2 = NxKovC1.base.merge('recipe_id' => 'atira_sisy_v2', 'version' => 2)
  NxKovC1.with_tmp({ 'atira_sisy_v1' => NxKovC1.base, 'atira_sisy_v2' => v2,
                     'atira_p2o_v1' => NxKovC1.base('atira_p2o_v1') }) do |d|
    # v2 SiSy nema surodenca P2O vo v2 -> nil (C2 az potom siahne po latest_for)
    NxTest.assert(NxKovC1.r.sibling('atira_sisy_v2', 'atira', 'p2o', dir: d).nil?)
    NxTest.assert_equal('atira_p2o_v1', NxKovC1.r.sibling('atira_sisy_v1', 'atira', 'p2o', dir: d))
  end
end

NxTest.test('KOV-C1: active_ref pozna presne tri stavy') do
  NxTest.assert_equal([:missing, nil], NxKovC1.r.active_ref(nil, 'atira', 'sisy'))
  NxTest.assert_equal([:missing, nil], NxKovC1.r.active_ref({}, 'atira', 'sisy'))
  NxTest.assert_equal([:known, 'atira_sisy_v1'],
                      NxKovC1.r.active_ref({ 'atira|sisy' => 'atira_sisy_v1' }, 'atira', 'sisy'))
  NxTest.assert_equal([:unknown, 'atira_sisy_v9'],
                      NxKovC1.r.active_ref({ 'atira|sisy' => 'atira_sisy_v9' }, 'atira', 'sisy'))
  # zaznam pre INU kombinaciu sa nikdy nepouzije
  NxTest.assert_equal([:missing, nil],
                      NxKovC1.r.active_ref({ 'atira|sisy' => 'atira_sisy_v1' }, 'atira', 'p2o'))
end

# --- 2. Validacia schemy ------------------------------------------------------

NxTest.test('KOV-C1: chybajuca bunka min_depth_by_nl pre NL v rade = odmietnutie') do
  body = NxKovC1.base
  body['min_depth_by_nl'].delete('470')
  NxKovC1.with_tmp({ 'atira_sisy_v1' => body }) do |d|
    NxTest.assert_raise('min_depth_by_nl') { NxKovC1.r.load('atira_sisy_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: zaporne cislo v recepte = odmietnutie') do
  body = NxKovC1.base
  body['eb'] = -10.5
  NxKovC1.with_tmp({ 'atira_sisy_v1' => body }) do |d|
    NxTest.assert_raise('eb') { NxKovC1.r.load('atira_sisy_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: nekonecne cislo (JSON reprezentacia) = odmietnutie') do
  raw = JSON.pretty_generate(NxKovC1.base).sub('"eb": 10.5', '"eb": 1e400')
  NxKovC1.with_tmp({ 'atira_sisy_v1' => raw }) do |d|
    NxTest.assert_raise('eb') { NxKovC1.r.load('atira_sisy_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: Quadro s height_variants = odmietnutie (system bez vyskovych variantov)') do
  body = NxKovC1.base('quadro_v6_sisy_v1')
  body['height_variants'] = { '70' => { 'rear_height' => 65.5, 'min_clear_height' => 105, 'railing' => 0 } }
  NxKovC1.with_tmp({ 'quadro_v6_sisy_v1' => body }) do |d|
    NxTest.assert_raise('height_variants') { NxKovC1.r.load('quadro_v6_sisy_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: Atira bez radu NL pre vysku = odmietnutie') do
  body = NxKovC1.base
  body['nl_series_by_height'].delete('144')
  NxKovC1.with_tmp({ 'atira_sisy_v1' => body }) do |d|
    NxTest.assert_raise('rady NL') { NxKovC1.r.load('atira_sisy_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: thickness_supported musi mat PRESNE roly rodiny (chybajuca rola = odmietnutie)') do
  # metal_box bez `drawer_back` — bez tejto brany by chyba vyplavala az ako
  # `drawer_no_fit` nad hotovou zakazkou.
  body = NxKovC1.base
  body['thickness_supported'].delete('drawer_back')
  NxKovC1.with_tmp({ 'atira_sisy_v1' => body }) do |d|
    NxTest.assert_raise('thickness_supported') { NxKovC1.r.load('atira_sisy_v1', dir: d) }
  end
  # rola NAVYSE je rovnako chyba
  extra = NxKovC1.base
  extra['thickness_supported']['box_side'] = [16]
  NxKovC1.with_tmp({ 'atira_sisy_v1' => extra }) do |d|
    NxTest.assert_raise('PRESNE roly') { NxKovC1.r.load('atira_sisy_v1', dir: d) }
  end
  # wood_undermount potrebuje vsetky styri
  q = NxKovC1.base('quadro_v6_sisy_v1')
  q['thickness_supported'].delete('box_side')
  NxKovC1.with_tmp({ 'quadro_v6_sisy_v1' => q }) do |d|
    NxTest.assert_raise('thickness_supported') { NxKovC1.r.load('quadro_v6_sisy_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: vydane recepty maju presne roly svojej rodiny') do
  NxTest.assert_equal(%w[drawer_back drawer_bottom],
                      NxKovC1.r.load('atira_sisy_v1')[:thickness_supported].keys.sort)
  NxTest.assert_equal(%w[box_side drawer_back drawer_bottom drawer_inner_front],
                      NxKovC1.r.load('quadro_v6_p2o_v1')[:thickness_supported].keys.sort)
end

NxTest.test('KOV-C1: inventar vidi AJ subor s neznamym menom systemu') do
  NxKovC1.with_tmp({ 'atira_sisy_v1' => NxKovC1.base }) do |d|
    File.write(File.join(d, 'antaro_sisy_v1.json'), '{}')
    NxTest.assert_equal(%w[antaro_sisy_v1 atira_sisy_v1], NxKovC1.r.inventory(dir: d),
                        'neregistrovany subor s neparsovatelnym menom sa NESMIE odfiltrovat')
    NxTest.refute(NxKovC1.r.inventory(dir: d) == NxKovC1.r.released(dir: d).keys.sort,
                  'test „inventar == register" musi nad takym priecinkom padnut')
  end
end

NxTest.test('KOV-C1: recipe_id musi sediet s nazvom suboru aj s poliami system/opening/version') do
  body = NxKovC1.base.merge('opening' => 'p2o')
  NxKovC1.with_tmp({ 'atira_sisy_v1' => body }) do |d|
    NxTest.assert_raise('nesedi') { NxKovC1.r.load('atira_sisy_v1', dir: d) }
  end
end

NxTest.test('KOV-C1: recept nesie EB, mounting a rear_type per zasadu 4') do
  a = NxKovC1.r.load('atira_sisy_v1')
  q = NxKovC1.r.load('quadro_v6_p2o_v1')
  NxTest.assert_close(10.5, a[:eb], 0.001)
  NxTest.assert_close(23.0, q[:eb], 0.001)
  [a, q].each do |rec|
    NxTest.assert_equal('slide_on', rec[:mounting])
    NxTest.assert_equal('wooden', rec[:rear_type])
    NxTest.assert_equal([16.0, 18.0, 19.0], rec[:kd_supported])
    NxTest.assert_close(600.0, rec[:sync_min_width], 0.001)
  end
end

NxTest.test('KOV-C1: min_depth_by_nl sedi so vzorcom (Atira NL+15, Quadro NL+13)') do
  { 'atira_sisy_v1' => 15.0, 'atira_p2o_v1' => 15.0,
    'quadro_v6_sisy_v1' => 13.0, 'quadro_v6_p2o_v1' => 13.0 }.each do |id, plus|
    rec = NxKovC1.r.load(id)
    rec[:min_depth_by_nl].each do |nl, v|
      NxTest.assert_close(nl.to_f + plus, v, 0.001, "#{id}: min_depth pre NL #{nl}")
    end
  end
end

NxTest.test('KOV-C1: rady NL sedia s package v2') do
  a = NxKovC1.r.load('atira_sisy_v1')
  NxTest.assert_equal([350.0, 420.0, 470.0, 520.0], a[:nl_series_by_height]['70'])
  # KOV-C2a (sonda #12): SiSy H144 konci na NL 470. Kit „144 620/50 relingy"
  # (357755) je PTO, teda TIP-ON — pre SiSy H144/620 kit NEEXISTUJE, takze rad
  # nesmie ponukat dlzku, ktoru Noxun nevie kupit (zasada v2 c. 3).
  NxTest.assert_equal([350.0, 420.0, 470.0], a[:nl_series_by_height]['144'])
  NxTest.assert_equal([350.0, 420.0, 470.0, 520.0, 620.0], a[:nl_series_by_height]['176'])
  p2o = NxKovC1.r.load('atira_p2o_v1')
  %w[70 144 176].each { |h| NxTest.assert_equal([350.0, 420.0, 470.0, 520.0, 620.0], p2o[:nl_series_by_height][h]) }
  NxTest.assert_equal([350.0, 400.0, 450.0, 500.0, 550.0], NxKovC1.r.load('quadro_v6_sisy_v1')[:nl_series])
  NxTest.assert_equal([350.0, 400.0, 450.0], NxKovC1.r.load('quadro_v6_p2o_v1')[:nl_series])
end

NxTest.test('KOV-C1: Tip-On ma PRISNEJSIU minimalnu svetlu vysku nez SiSy') do
  sisy = NxKovC1.r.load('atira_sisy_v1')[:height_variants]
  p2o = NxKovC1.r.load('atira_p2o_v1')[:height_variants]
  { '70' => [105.0, 108.0], '144' => [189.0, 192.0], '176' => [221.0, 224.0] }.each do |h, (s, p)|
    NxTest.assert_close(s, sisy[h][:min_clear_height], 0.001, "SiSy H#{h}")
    NxTest.assert_close(p, p2o[h][:min_clear_height], 0.001, "Tip-On H#{h}")
  end
end

# --- 3. recipe_key_for (rozhodovacia tabulka) ---------------------------------

NxTest.test('KOV-C1: recipe_key_for legacy — iny typ, ziadne drawer pole, construction other') do
  r = NxKovC1.r
  NxTest.assert_equal([:legacy, nil], r.recipe_key_for(NxKovC1.item(type: 'door')))
  NxTest.assert_equal([:legacy, nil], r.recipe_key_for(NxKovC1.item))
  NxTest.assert_equal([:legacy, nil],
                      r.recipe_key_for(NxKovC1.item(drawer: { 'construction' => 'other' }, opening_mode: 'classic')))
  # dvierka s DORMANT drawer polami sa ignoruju
  NxTest.assert_equal([:legacy, nil],
                      r.recipe_key_for(NxKovC1.item(type: 'door', drawer: { 'construction' => 'metal' },
                                                    opening_mode: 'classic')))
end

NxTest.test('KOV-C1: recipe_key_for ok — metal+classic -> atira|sisy, wood+tipon -> quadro_v6|p2o') do
  r = NxKovC1.r
  NxTest.assert_equal([:ok, { system: 'atira', opening: 'sisy' }],
                      r.recipe_key_for(NxKovC1.item(drawer: { 'construction' => 'metal' }, opening_mode: 'classic')))
  NxTest.assert_equal([:ok, { system: 'quadro_v6', opening: 'p2o' }],
                      r.recipe_key_for(NxKovC1.item(drawer: { 'construction' => 'wood' }, opening_mode: 'tipon')))
end

NxTest.test('KOV-C1: explicitny drawer.system MUSI sediet s konstrukciou (inak konflikt)') do
  r = NxKovC1.r
  # zhodny system je v poriadku (a nic nemeni)
  NxTest.assert_equal([:ok, { system: 'atira', opening: 'sisy' }],
                      r.recipe_key_for(NxKovC1.item(drawer: { 'construction' => 'metal', 'system' => 'atira' },
                                                    opening_mode: 'classic')))
  NxTest.assert_equal([:ok, { system: 'quadro_v6', opening: 'p2o' }],
                      r.recipe_key_for(NxKovC1.item(drawer: { 'construction' => 'wood', 'system' => 'quadro_v6' },
                                                    opening_mode: 'tipon')))
  # stale/podvrhnuty config: kov + Quadro sa NIKDY ticho neprijme
  kind, code, msg = r.recipe_key_for(
    NxKovC1.item(drawer: { 'construction' => 'metal', 'system' => 'quadro_v6' }, opening_mode: 'classic')
  )
  NxTest.assert_equal(:conflict, kind)
  NxTest.assert_equal('drawer_unclassified', code)
  NxTest.assert(msg.to_s.include?('nezodpovedá konštrukcii'), "hlaska musi povedat dovod (#{msg.inspect})")
  # neznamy system rovnako
  NxTest.assert_equal('drawer_unclassified',
                      r.recipe_key_for(NxKovC1.item(drawer: { 'construction' => 'wood', 'system' => 'antaro' },
                                                    opening_mode: 'classic'))[1])
end

NxTest.test('KOV-C1: CIASTOCNA klasifikacia je RED drawer_unclassified (obe strany)') do
  r = NxKovC1.r
  [{ drawer: { 'construction' => 'metal' } },
   { opening_mode: 'classic' },
   # samotny `system` bez klasifikacie tiez nie je legacy
   { drawer: { 'system' => 'atira' } }].each do |args|
    kind, code = r.recipe_key_for(NxKovC1.item(**args))
    NxTest.assert_equal([:conflict, 'drawer_unclassified'], [kind, code], args.inspect)
  end
end

NxTest.test('KOV-C1: vnutorna zasuvka = drawer_internal_unsupported (aj bez inej klasifikacie)') do
  r = NxKovC1.r
  full = r.recipe_key_for(NxKovC1.item(drawer: { 'construction' => 'metal', 'variant' => 'internal' },
                                       opening_mode: 'classic'))
  NxTest.assert_equal([:conflict, 'drawer_internal_unsupported'], full[0, 2])
  # SAMOTNY `variant internal` nesmie prepadnut do legacy cesty
  only = r.recipe_key_for(NxKovC1.item(drawer: { 'variant' => 'internal' }))
  NxTest.assert_equal([:conflict, 'drawer_internal_unsupported'], only[0, 2])
  NxTest.assert(only[2].to_s.include?('Vnútorná'), 'internal ma niest hlasku')
  # `variant standard` sam o sebe je len klasifikacia bez konstrukcie -> unclassified
  NxTest.assert_equal([:conflict, 'drawer_unclassified'],
                      r.recipe_key_for(NxKovC1.item(drawer: { 'variant' => 'standard' }))[0, 2])
end

NxTest.test('KOV-C1: konflikt z recipe_key_for nesie kod z CONFLICT_CODES a slovensku hlasku') do
  r = NxKovC1.r
  [NxKovC1.item(drawer: { 'construction' => 'metal' }),
   NxKovC1.item(drawer: { 'variant' => 'internal' }),
   NxKovC1.item(drawer: { 'construction' => 'metal', 'system' => 'quadro_v6' }, opening_mode: 'classic')].each do |it|
    kind, code, msg = r.recipe_key_for(it)
    NxTest.assert_equal(:conflict, kind)
    NxTest.assert(r::CONFLICT_CODES.include?(code), "neznamy kod #{code.inspect}")
    NxTest.assert(msg.is_a?(String) && !msg.empty?, 'konflikt musi niest hlasku')
  end
end

NxTest.test('KOV-C1: register kodov konfliktov ma presne 10 poloziek z package') do
  NxTest.assert_equal(10, NxKovC1.r::CONFLICT_CODES.size)
  %w[drawer_unclassified drawer_no_fit drawer_obstruction drawer_internal_unsupported
     drawer_thickness_unsupported drawer_kd_unsupported drawer_recipe_unknown
     nl_lock_invalid drawer_override_invalid drawer_kit_missing].each do |code|
    NxTest.assert(NxKovC1.r::CONFLICT_CODES.include?(code), "chyba kod #{code}")
  end
end
