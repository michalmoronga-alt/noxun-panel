# frozen_string_literal: true
# H18 T0/T1/T2/T5/T9: oracle a goldeny boli pripnute PRED zasahom (76ba4035).
require_relative '../fixtures/h18_golden/cases'
require_relative '../fixtures/h18_golden/blocked_cases'
require 'digest'

module NxH18Checks
  module_function

  # Jedine povolene rozdiely R2.6: dve vetvy textu pri klasifikovanych dvierkach.
  # Set, clenovia, pocet a vsetky ostatne dovody ostavaju zo stareho goldenu.
  def display_problem(old, item)
    out = NxH18.copy(old)
    entry = out['unmapped'].first
    if NxH18::HS.door_item?(item) && entry && %w[set_type_mismatch set_incompatible].include?(entry['reason'])
      entry['detail'] = 'generic_type' if entry['reason'] == 'set_type_mismatch'
      entry['reason'] = 'hinge_set_mismatch'
      out['problems'] = [NxH18::HS.unmapped_reason_sk(entry)]
    end
    out
  end

  def resolver_expected(old, c)
    out = NxH18.copy(old)
    c['items'].each_with_index do |item, i|
      out['explain'][i] = display_problem(out['explain'][i], item)
      out['purchase'][i]['purchase'] = display_problem(out['purchase'][i]['purchase'], item)
    end
    out
  end

  def fixed_payload(value, blocked: false)
    NxH18.copy(value).map do |entry|
      entry.delete('own_count')
      if NxH18::HS.invalid_mapping_value?(entry['override_selector'])
        entry.delete('override_label')
        entry.delete('owner_default_label')
      end
      entry['owner_overrides'].each_value { |ov| ov.delete('label') if ov['invalid'] }
      if entry['generic_type'] == 'hinge' && entry['compat']
        ([entry['compat']['cab']] + entry['compat']['owners'].values).compact.each do |scope|
          %w[none_label current stored value_text].each { |key| scope.delete(key) }
        end
      end
      # A4 z auditu plati aj pre vysuv/vyklop: ulozeny vyber zostava viditelny,
      # ale text prvej volby v blocked stave musi vychadzat z ucinnych overridov.
      if blocked && entry['compat']
        ([entry['compat']['cab']] + entry['compat']['owners'].values).compact.each do |scope|
          scope.delete('none_label')
        end
      end
      # P2 predrecenzie: LEN blocked dostal explicitne ulozene-neucinne
      # texty a dedenie z effective mapy. T10 kontroluje kazde nove pole aj
      # zmeneny owner_default_label proti nezavislej starej retazi.
      if blocked
        entry.delete('blocked')
        entry.delete('override_value_text')
        entry.delete('owner_default_label')
        entry['owner_overrides'].each_value { |ov| ov.delete('value_text') }
      end
      entry
    end
  end
end

NxTest.test('H18 T10: blocked ulozeny cab/owner, classified/legacy, string/selector/invalid aj unblocked stavy') do
  NxTest.skip!('headless fixture context') unless NxTest.headless?
  expected = NxH18.fixture('blocked_pred')
  after = NxH18.fixture('blocked_payload_po')
  # Predzmenova retaz je pripnuta bajtovo, nezavisi od noveho helpera.
  path = File.join(NxH18::DIR, 'old_resolver.rb')
  chain = File.read(path).gsub("\r\n", "\n")[/^  def resolve_mapping_value\b.*?^  end\n/m]
  restored = chain.lines.map { |line| line == "\n" ? line : '    ' + line }.join
  NxTest.assert_equal('ad8ebb4f2cfbfcdb8ac97371c2547e59550e84bbb5790e7156c91014427ebd67', Digest::SHA256.hexdigest(restored))
  NxTest.assert(!chain.include?('resolve_mapping_source') && !chain.include?('item_mapping_source'))
  (NxH18.cases + NxH18Blocked.cases).each do |c|
    truth = expected.fetch(c['id'])
    NxTest.assert_equal(truth, NxH18Blocked.truth(c), c['id'] + ' stary oracle immutable')
    entry = NxH18.payload(c).find { |e| e['generic_type'] == c['gt'] }
    next unless entry

    blocked = c['status'] == 'blocked'
    NxTest.assert_equal(blocked, entry.fetch('blocked', false), c['id'] + ' brana iba blocked')
    NxTest.assert_equal(truth['own_keys'].length, entry['own_count'], c['id'] + ' effective count')
    if blocked
      NxTest.assert_equal(truth['flat_none_label'], entry['owner_default_label'], c['id'] + ' effective owner dedenie')
      NxTest.assert_equal(truth['flat_cab_text'], entry['override_value_text'], c['id'] + ' ulozena cab hodnota')
      truth['owners'].each do |owner, scope|
        next if scope['class_key'] || scope['flat_raw'].nil?

        NxTest.assert_equal(scope['flat_text'], entry['owner_overrides'].fetch(owner)['value_text'], c['id'] + ' ulozena owner hodnota')
      end
    else
      NxTest.assert(!entry.key?('blocked') && !entry.key?('override_value_text'), c['id'] + ' ziadny novy flat stav')
      NxTest.assert(entry['owner_overrides'].values.none? { |ov| ov.key?('value_text') }, c['id'] + ' ziadny novy owner stav')
    end
    compat = entry['compat']
    if compat
      scopes = compat['owners'].map { |owner, sc| [sc, truth['owners'].fetch(owner), true] }
      scopes << [compat['cab'], truth.fetch('cab'), false] if compat['cab']
      scopes.each do |scope, oracle, owner|
        raw = if owner
                saved = oracle['stored_winner']
                %w[owner owner_class].include?(saved[1]) ? saved[0] : nil
              else oracle['stored_value']
              end
        id = NxH18::HS.mapping_option_id(raw)
        known = !blocked && id && scope['options'].any? { |o| o['id'] == id }
        NxTest.assert_equal(known ? id : nil, scope['current'], c['id'] + ' current')
        NxTest.assert_equal(!raw.nil? && !known, scope['stored'], c['id'] + ' stored')
        NxTest.assert_equal(NxH18::HS.mapping_value_text(raw, c['state']['sets']), scope['value_text'], c['id'] + ' stored text')
        NxTest.assert_equal(oracle['none_label'], scope['none_label'], c['id'] + ' effective inherited')
      end
    end
    if c['id'].start_with?('P2/')
      NxTest.assert_equal(after.fetch(c['id']), NxH18.payload(c), c['id'] + ' post aktualnost')
    end
  end
end

NxTest.test('H18 T11: Dmix a Dmixleg nesu ulozeny-neucinny text bez zapisoveho cab rozsahu') do
  NxTest.skip!('headless fixture context') unless NxTest.headless?
  truth = NxH18.fixture('blocked_pred')
  NxH18.cases.select { |c| c['id'].match?(/\A(?:Dmix|Dmixleg)\//) }.each do |c|
    oracle = truth.fetch(c['id'])
    entry = NxH18.payload(c).first
    NxTest.assert_equal(nil, entry.fetch('compat').fetch('cab'), c['id'] + ' zmiesana trieda nema zapisovy cab rozsah')
    NxTest.assert_equal(oracle['own_keys'].length, entry['own_count'], c['id'] + ' iba ucinne vybery')
    if c['status'] == 'blocked'
      NxTest.assert_equal(oracle['flat_cab_text'], entry['override_value_text'], c['id'] + ' text ulozeneho generic cab')
      NxTest.assert_equal({}, NxH18.effective(c), c['id'] + ' ulozene neplati v nakupe')
      entry['compat']['owners'].each do |owner, scope|
        NxTest.assert_equal(oracle['owners'].fetch(owner)['none_label'], scope['none_label'], c['id'] + ' effective dedenie ownera')
      end
    else
      NxTest.assert(!entry.key?('override_value_text') && !entry.key?('blocked'), c['id'] + ' odblokovany payload nema novy stav')
    end
  end
end

NxTest.test('H18 T0: resolver, nakup a povolene polia payloadu bajtovo == PRED') do
  NxTest.skip!('headless fixture context') unless NxTest.headless?
  expected = NxH18.fixture('resolver')
  payload = NxH18.fixture('payload_pred')
  after = NxH18.fixture('payload_po')
  NxH18.cases.each do |c|
    NxTest.assert_equal(JSON.generate(NxH18Checks.resolver_expected(expected.fetch(c['id']), c)),
                        JSON.generate(NxH18.resolver(c)), c['id'] + ' resolver/purchase R2.6 iba')
    actual = NxH18.payload(c)
    NxTest.assert_equal(JSON.generate(after.fetch(c['id'])), JSON.generate(actual), c['id'] + ' aktualnost PO')
    blocked = c['status'] == 'blocked'
    NxTest.assert_equal(JSON.generate(NxH18Checks.fixed_payload(payload.fetch(c['id']), blocked: blocked)),
                        JSON.generate(NxH18Checks.fixed_payload(actual, blocked: blocked)), c['id'] + ' povoleny rozsah payloadu')
  end
end

NxTest.test('H18 T0: klasifikovane zavesy expand + CSV + rozpocet + ponuka bajtovo') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  expected = File.read(File.join(NxH18::DIR, 'cena_zavesy.json'))
  NxTest.assert_equal(expected, NxH18.json(NxH18.prices))
end

NxTest.test('H18 T1: zdroj aj hodnota == nezavisly predzmenovy oracle vo vsetkych vetvach') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  source = NxH18.fixture('source_pred')
  NxH18.cases.each do |c|
    c['items'].each_with_index do |item, i|
      expected = source.fetch(c['id'])['items'][i]
      ov = NxH18.effective(c)
      map = c['state']['mapping']
      NxTest.assert_equal(expected, NxH18::HS.item_mapping_source(item, map, ov), c['id'] + ' item source')
      next unless NxH18::HS.expandable_hardware_item?(item)
      next if NxH18::HS.mapping_skipped?(item, NxH18::HS.class_key_for(item, item['generic_type']))

      NxTest.assert_equal(expected, NxH18::HS.resolve_mapping_source(item['generic_type'], item, { 'CAB-1' => ov }, map), c['id'] + ' source')
      NxTest.assert_equal(expected.first, NxH18::HS.resolve_mapping_value(item['generic_type'], item, { 'CAB-1' => ov }, map), c['id'] + ' value')
    end
  end
end

NxTest.test('H18 T2: own_count su rozne UČINNE vitazne kluce (nie ulozene ani zatienene)') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  source = NxH18.fixture('source_pred')
  NxH18.cases.each do |c|
    NxH18.payload(c).each do |entry|
      NxTest.assert_equal(source.fetch(c['id'])['own_keys'].length, entry['own_count'], c['id'])
      NxTest.assert(entry['own_count'].is_a?(Integer), 'server vzdy posle cele cislo')
    end
  end
  # Presun povodnych T4 :236 a :239: anonymna legacy polozka aktivuje kluc
  # svojho typu; legacy polozka INEHO typu klasifikovany vysuv neaktivuje.
  base = NxH18.copy(NxH18.cases.find { |c| c['id'] == 'S2/ov1/seed/ok' })
  anonymous = NxH18.copy(base)
  anonymous['items'] << NxH18.item('slide', '')
  NxTest.assert_equal(1, NxH18.payload(anonymous).find { |e| e['generic_type'] == 'slide' }['own_count'])
  other_type = NxH18.copy(base)
  other_type['items'] << NxH18.item('hinge', 'front:F3/wing:single', {}, 2)
  NxTest.assert_equal(0, NxH18.payload(other_type).find { |e| e['generic_type'] == 'slide' }['own_count'])
end

NxTest.test('H18 T2: riadok nakupu a ponuka zdieľaju pravidlo blocked') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine/ui/panel/payloads.rb'))
  NxTest.assert(src[/def decorate_hardware_purchase.*?^        end/m].include?('hw_purchase_overrides(cfg, status)'))
  NxTest.assert(src[/def hardware_set_options.*?^        end/m].include?('hw_purchase_overrides(cfg, status, overrides)'))
  NxTest.assert_equal(1, src.scan('status == :missing && HardwareSets.library_read_only?').length)
end

NxTest.test('H18 izolacia: kontext vrati vsetky metody aj po vynimke, Time a ENV nemení') do
  NxTest.skip!('headless context') unless NxTest.headless?
  methods = [[NxH18::P, :hardware_read_state], [NxH18::HS, :load],
             [NxH18::HS, :library_read_only?], [NxH18::E::HardwareCatalog, :items]]
  original = methods.map { |mod, name| mod.method(name).source_location }
  env = ENV.to_h
  clock = Time.method(:now).source_location
  begin
    NxH18.context(NxH18.cases.first) do
      NxTest.assert_equal(NxH18::E::HardwareCatalog::SEED_ITEMS, NxH18::E::HardwareCatalog.items)
      raise 'h18 context restore probe'
    end
  rescue RuntimeError => e
    raise unless e.message == 'h18 context restore probe'
  end
  NxTest.assert_equal(original, methods.map { |mod, name| mod.method(name).source_location })
  NxTest.assert_equal(env, ENV.to_h)
  NxTest.assert_equal(clock, Time.method(:now).source_location)
end

NxTest.test('H18 T5: explain a nakup sa zhoduju pri OBOCH nesuladoch zavesu') do
  NxTest.skip!('headless fixture') unless NxTest.headless?
  base = NxH18.cases.find { |c| c['id'] == 'D1t/ov2/seed/ok' }
  %w[zaves-klasik nohy-klzak-17].each do |sid|
    c = NxH18.copy(base)
    c['overrides'] = { 'hinge' => sid }
    r = NxH18.resolver(c)
    expected = r['expansion']['unmapped'].first.merge('cabinet_id' => NxH18::HS::EXPLAIN_OWNER)
    NxTest.assert_equal([expected], r['explain'].first['unmapped'])
    NxTest.assert_equal('hinge_set_mismatch', expected['reason'])
    NxTest.assert_equal([NxH18::HS.unmapped_reason_sk(expected)], r['explain'].first['problems'])
  end
end

NxTest.test('H18 T9: zrusenie vyberu neslubuje projekt ani skrinku; vyber ostava rovnaký') do
  p = NxH18::P
  NxTest.assert_equal('Závesy: výber zrušený.', p.hw_set_status_msg('hinge', nil, nil, []))
  NxTest.assert_equal('Závesy pre dielec front:F1/wing:single: výber zrušený.', p.hw_set_status_msg('hinge', 'front:F1/wing:single', nil, []))
  NxTest.assert_equal('Závesy: set „Pánt“.', p.hw_set_status_msg('hinge', nil, 'x', [{ 'name' => 'Pánt' }]))
  NxTest.assert_equal('Závesy: podľa: parameter „height_variant“ (1 pásmo).', p.hw_set_status_msg('hinge', nil, { 'param' => 'height_variant', 'bands' => [{}] }, []))
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine/ui/panel/actions_hardware.rb')).gsub("\r\n", "\n")
  handler = src[/^        def handle_set_hardware_set\b.*?^        end\n/m]
  NxTest.assert_equal('1c595ace9e2ee2d2ec03e7a166823a39cd458adb78723d9a91a018673c910f82',
                      Digest::SHA256.hexdigest(handler), 'cele telo handlera == main 2640f47b')
  NxTest.assert(handler.include?('status_with_warnings(cab, hw_set_status_msg(gt, owner, value, set_defs))'),
                'argumenty statusu bez zmeny')
end
