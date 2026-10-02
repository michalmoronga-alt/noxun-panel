# frozen_string_literal: true
# H18: spolocne vstupy generatora a testov. Oracle vola resolver stareho kodu
# LEN pri prvom generovani; jeho predzmenovy vystup sa potom nikdy neprepisuje.
require_relative '../../helper' unless defined?(NxTest)
require_relative '../../../noxun_engine/ui/panel/payloads'
require_relative '../../../noxun_engine/ui/panel/actions_hardware'
require_relative '../../../noxun_engine/ui/hardware_catalog_dialog'

module NxH18
  E = Noxun::Engine
  HS = E::HardwareSets
  P = E::Panel
  DIR = __dir__
  BEFORE = '2640f47b33814c5f49562205fc80657f8997bf14'
  OWN_LEVELS = %w[owner owner_class cab_class cab].freeze
  SOURCE_WORDS = { 'cab_class' => 'skrinky', 'cab' => 'staršieho výberu skrinky',
                   'project_class' => 'projektu', 'project' => 'projektu', nil => 'projektu' }.freeze
  module_function

  def copy(value) = Marshal.load(Marshal.dump(value))

  def definitions
    custom = [
      { 'set_id' => 'moj-zaves', 'name' => 'Môj záves (nezaradený)', 'generic_type' => 'hinge',
        'members' => [{ 'code' => 'X1', 'per' => 'unit', 'qty' => 1, 'label' => 'záves' }] },
      { 'set_id' => 'iny-tipon', 'name' => 'Iný Tip-On', 'generic_type' => 'hinge',
        'use_type' => 'door', 'opening_mode' => 'tipon',
        'members' => [{ 'code' => 'X2', 'per' => 'unit', 'qty' => 1, 'label' => 'záves' }] }
    ]
    HS.normalize_sets(copy(HS::SEED_SETS) + custom).to_h { |s| [s['set_id'], s] }
  end

  def seed_mapping
    HS.normalize_mapping(copy(HS::SEED_MAPPING).merge(copy(HS::MAPPING_ADDITIONS)))
  end

  def catalog
    # X1 ostava mimo katalogu; ceny aj poradie dodanych produktov su pripnute H15.
    copy(E::HardwareCatalog::SEED_ITEMS) + [{ 'item_code' => 'X2', 'name_sk' => 'Iný záves',
                                      'unit' => 'ks', 'category' => 'ZAVESY', 'price_eur_vat' => 3.0 }]
  end

  def item(gt, owner, params = {}, quantity = 1)
    { 'owner_id' => 'CAB-1', 'owner_part_key' => owner, 'generic_type' => gt,
      'quantity' => quantity, 'rule_id' => 'h18-fixture', 'source' => 'rule', 'params' => params }
  end

  def door(mode, owner) = item('hinge', owner, { 'use_type' => 'door', 'opening_mode' => mode }, 2)
  def slide(owner, mode = 'classic')
    item('slide', owner, { 'opening_mode' => mode, 'drawer_construction' => 'metal',
                          'system' => 'atira', 'height_variant' => 70.0, 'nominal_length' => 470.0,
                          'load' => 30.0, 'recipe_id' => 'atira_sisy_v1' })
  end

  def item_sets
    {
      'D1t' => [door('tipon', 'front:F1/wing:single')],
      'D2c' => [door('classic', 'front:F2/wing:left'), door('classic', 'front:F2/wing:right')],
      'Dmix' => [door('tipon', 'front:F1/wing:single'), door('classic', 'front:F2/wing:left')],
      'Dleg' => [item('hinge', 'front:F1/wing:single', {}, 2)],
      'Dmixleg' => [door('tipon', 'front:F2/wing:left'), item('hinge', 'front:F1/wing:single', {}, 2)],
      'S1' => [slide('front:F4/panel')],
      'S2' => [slide('front:F4/panel'), slide('front:F5/panel')],
      'Smix' => [slide('front:F4/panel'), slide('front:F5/panel', 'tipon')],
      'Smixleg' => [slide('front:F4/panel'), item('slide', 'front:F6/panel', { 'nominal_length' => 470.0 })],
      'L' => [item('leg', '', {}, 4)],
      'Lf' => [item('lift', 'front:F5/flap', { 'use_type' => 'lift', 'opening_mode' => 'classic', 'lift_system' => 'hk_top' })],
      'Lfx' => [item('lift', 'front:F5/flap', { 'use_type' => 'lift', 'opening_mode' => 'classic' })],
      'Dzero' => [door('tipon', 'front:F1/wing:single').merge('quantity' => 0)],
      'Dallown' => [door('classic', 'front:F2/wing:left'), door('classic', 'front:F2/wing:right')],
      'Dnone' => [], 'Snone' => []
    }
  end

  def override_pools
    ati = copy(HS::MAPPING_ADDITIONS['class:slide|classic|metal'])
    hinge_selector = { 'param' => 'height', 'bands' => [{ 'min' => 0, 'max' => 2000, 'set_id' => 'zaves-p2o' }] }
    {
      'hinge' => [{}, { 'hinge' => 'moj-zaves' }, { 'hinge' => 'zaves-klasik' },
                  { 'class:hinge|tipon' => 'zaves-p2o' }, { 'class:hinge|classic' => 'zaves-klasik' },
                  { 'hinge@front:F1/wing:single' => 'moj-zaves' }, { 'hinge@front:F2/wing:left' => 'zaves-klasik' },
                  { 'hinge' => HS::MAPPING_NONE }, { 'hinge' => 'moj-zaves', 'class:hinge|tipon' => 'zaves-p2o' },
                  { 'hinge' => 'moj-zaves', 'hinge@front:F1/wing:single' => 'zaves-p2o' },
                  { 'class:hinge|tipon' => 'zaves-p2o', 'hinge@front:F1/wing:single' => 'zaves-p2o' },
                  { 'hinge' => '' }, { 'hinge@front:F1/wing:single' => '' }, { 'class:hinge|tipon' => 'nohy-klzak-17' },
                  { 'hinge@front:F1/wing:single' => hinge_selector },
                  { 'hinge' => 'moj-zaves', 'hinge@front:F2/wing:left' => 'zaves-klasik',
                    'hinge@front:F2/wing:right' => 'zaves-klasik' },
                  { 'hinge@front:F9/wing:single' => 'moj-zaves' }, { 'hinge@front:F1/wing:single' => HS::MAPPING_NONE }],
      'slide' => [{}, { 'slide' => 'vysuv-quadro-v6-sisy' }, { 'class:slide|classic|metal' => ati },
                  { 'class:slide|classic|metal@front:F4/panel' => ati }, { 'slide@front:F4/panel' => 'vysuv-quadro-v6-sisy' },
                  { 'slide@front:F6/panel' => 'vysuv-quadro-v6-sisy' },
                  { 'class:slide|classic|metal' => ati, 'class:slide|classic|metal@front:F4/panel' => ati },
                  { 'class:slide|classic|metal@front:F4/panel' => '' }, { 'slide' => '' }, { 'slide@front:F6/panel' => '' }],
      'leg' => [{}, { 'leg' => 'nohy-klzak-17' }, { 'leg' => '' }],
      'lift' => [{}, { 'lift' => 'vyklop-hk-klasik' }, { 'class:lift|classic|hk_top' => 'vyklop-hk-klasik' },
                 { 'class:lift|classic|hk_top@front:F5/flap' => 'vyklop-hk-klasik' }, { 'lift@front:F5/flap' => 'vyklop-hk-klasik' }]
    }
  end

  def cases
    seed = seed_mapping
    projects = { 'seed' => seed, 'legacy_hinge' => seed.reject { |k, _| k.start_with?('class:hinge') }.merge('hinge' => 'moj-zaves'), 'empty' => {} }
    item_sets.flat_map do |name, items|
      gt = items.empty? ? (name.start_with?('D') ? 'hinge' : 'slide') : items.first['generic_type']
      override_pools.fetch(gt).each_with_index.flat_map do |raw, oi|
        projects.flat_map do |pname, mapping|
          %w[ok blocked].map do |status|
            normalized = HS.normalize_mapping(copy(raw), nil, allow_owner: true)
            { 'id' => "#{name}/ov#{oi}/#{pname}/#{status}", 'gt' => gt, 'items' => copy(items),
              'overrides' => normalized, 'status' => status,
              'state' => { 'mapping' => (status == 'blocked' ? {} : copy(mapping)),
                           'sets' => (status == 'blocked' ? {} : definitions) } }
          end
        end
      end
    end
  end

  def effective(c) = c['status'] == 'blocked' ? {} : c['overrides']
  def cfg(c) = { 'cabinet_id' => 'CAB-1', 'hardware' => c['items'], 'hardware_sets' => c['overrides'] }

  def context(c)
    # Vsetky podvrhnutia sa obnovia aj po chybe; globalny test state nesmie uniknut.
    methods = [[P, :hardware_read_state], [HS, :load], [HS, :library_read_only?]]
    originals = methods.to_h { |mod, name| [[mod, name], mod.method(name)] }
    P.define_singleton_method(:hardware_read_state) { [c['status'] == 'blocked' ? :missing : :ok, c['state']] }
    HS.define_singleton_method(:load) { { 'sets' => c['state']['sets'].values, 'mapping' => c['state']['mapping'] } }
    HS.define_singleton_method(:library_read_only?) { c['status'] == 'blocked' }
    yield
  ensure
    originals&.each { |(mod, name), method| mod.define_singleton_method(name, method) }
  end

  def payload(c) = context(c) { P.hardware_set_options(cfg(c), c['items']) }

  def resolver(c)
    ov = effective(c)
    no_set = c['status'] == 'blocked' ? 'library_incompatible' : 'no_set'
    { 'resolved' => c['items'].map { |it| HS.resolve_set_id(it['generic_type'], it, { 'CAB-1' => ov }, c['state']['mapping']) },
      'expansion' => HS.expand(c['items'], c['state'], cabinet_overrides: { 'CAB-1' => ov }, catalog: catalog, no_set_reason: no_set),
      'explain' => c['items'].map { |it| HS.explain(it, c['state'], overrides: ov, catalog: catalog, no_set_reason: no_set) },
      'purchase' => context(c) { P.decorate_hardware_purchase(cfg(c), c['items']) } }
  end

  def tag_map(map, scope)
    tags = {}
    tagged = map.to_h do |k, v|
      tag = "TAG|#{scope}|#{k}"
      tags[tag] = [v, scope, k] if HS.present_mapping_value?(v)
      [k, HS.present_mapping_value?(v) ? tag : v]
    end
    [tagged, tags]
  end

  def oracle(it, overrides, mapping)
    return [nil, nil, nil] if it['generic_type'].to_s.empty? || it['quantity'].to_i < 1
    gt = it['generic_type']
    return [nil, nil, nil] if HS.class_key_for(it, gt).nil? && HS.lift_item?(it)

    ov, tags1 = tag_map(overrides, 'C')
    proj, tags2 = tag_map(mapping, 'P')
    winner = HS.resolve_mapping_value(gt, it, { it['owner_id'].to_s => ov }, proj)
    return [nil, nil, nil] if winner.nil?

    value, scope, key = tags1.merge(tags2).fetch(winner)
    cls = HS.class_mapping_key?(key)
    level = if scope == 'P' then cls ? 'project_class' : 'project'
            elsif key.include?('@') then cls ? 'owner_class' : 'owner'
            else cls ? 'cab_class' : 'cab'
            end
    [value, level, key]
  end

  def sources(c)
    ov = effective(c)
    map = c['state']['mapping']
    normal = c['items'].map { |it| oracle(it, ov, map) }
    active = P.active_class_by_owner(c['items'], c['gt'])
    owners = active.to_h do |owner, ck|
      it = c['items'].find { |h| h['generic_type'] == c['gt'] && h['owner_part_key'].to_s == owner }
      raw, level, key = oracle(it, ov, map)
      reduced = OWN_LEVELS.first(2).include?(level) ? ov.reject { |k, _| k == key } : ov
      winner = oracle(it, c['overrides'], map)
      without = oracle(it, reduced, map)
      [owner, { 'class_key' => ck, 'winner' => [raw, level, key], 'stored_winner' => winner,
                'stored_id' => HS.mapping_option_id(winner[0]), 'stored_text' => HS.mapping_value_text(winner[0], c['state']['sets']),
                'without_own' => without, 'none_label' => source_label(without, c) }]
    end
    classes = active.values.uniq
    cab = if classes.length == 1 && !classes.first.nil?
            ck = classes.first
            it = c['items'].find { |h| HS.class_key_for(h, c['gt']) == ck }.merge('owner_part_key' => '')
            without = oracle(it, ov.reject { |k, _| k == ck }, map)
            { 'class_key' => ck, 'winner' => oracle(it, ov, map),
              'stored_value' => c['overrides'][ck], 'stored_id' => HS.mapping_option_id(c['overrides'][ck]),
              'stored_text' => HS.mapping_value_text(c['overrides'][ck], c['state']['sets']),
              'without_own' => without, 'none_label' => source_label(without, c) }
          end
    { 'gt' => c['gt'], 'status' => c['status'], 'items' => normal, 'owners' => owners, 'cab' => cab,
      'own_keys' => normal.filter_map { |_v, level, key| OWN_LEVELS.include?(level) ? key : nil }.uniq }
  end

  def source_label(source, c)
    "podľa #{SOURCE_WORDS.fetch(source[1])} — #{HS.mapping_value_text(source[0], c['state']['sets'])}"
  end

  def prices
    defs = definitions
    state = { 'mapping' => seed_mapping, 'sets' => defs }
    items = [door('tipon', 'front:F1/wing:single').merge('owner_id' => 'CAB-A'),
             door('classic', 'front:F1/wing:left').merge('owner_id' => 'CAB-B'),
             door('classic', 'front:F1/wing:right').merge('owner_id' => 'CAB-B'),
             door('tipon', 'front:F1/wing:single').merge('owner_id' => 'CAB-C'),
             door('classic', 'front:F2/wing:single').merge('owner_id' => 'CAB-C'),
             door('tipon', 'front:F1/wing:single').merge('owner_id' => 'CAB-D'),
             door('tipon', 'front:F1/wing:single').merge('owner_id' => 'CAB-E')]
    # B: iny nezaradeny set na kridle rozlisi prehodenie owner a cab (M23).
    ov = { 'CAB-A' => { 'hinge' => 'zaves-p2o' },
           'CAB-B' => { 'hinge' => 'zaves-p2o', 'hinge@front:F1/wing:left' => 'zaves-klasik' },
           'CAB-C' => { 'hinge' => 'zaves-klasik' }, 'CAB-E' => { 'hinge' => 'moj-zaves' } }
    cat = catalog
    exp = HS.expand(items, state, cabinet_overrides: ov, catalog: cat)
    budget = E::Budget.compute({}, {}, E::SupplierSettings.seed_supplier, hardware_expansion: exp,
                              hardware_catalog: cat, now: Time.utc(2026, 10, 2))
    { 'expansion' => exp, 'csv' => HS.purchase_csv(exp, project: 'H18 GOLDEN', generated_at: '2026-10-02'),
      'hardware' => budget['sections'].select { |s| s['key'] == 'hardware' }, 'totals' => budget['totals'],
      'cp_rows' => E::CpExport.cp_rows(budget),
      'specification' => E::CpExport.specification([], hardware_expansion: exp, budget: budget) }
  end

  def json(value) = JSON.pretty_generate(value) + "\n"
  def matrix_json(value)
    "{\n" + value.map { |key, row| '  ' + JSON.generate(key) + ': ' + JSON.generate(row) }.join(",\n") + "\n}\n"
  end
  def fixture(name) = JSON.parse(File.read(File.join(DIR, name + '.json')))
end
