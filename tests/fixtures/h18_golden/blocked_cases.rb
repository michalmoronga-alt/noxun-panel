# frozen_string_literal: true
# P2 predrecenzia: input a pravda nezavisla od aktualneho payloadu / helpera zdroja.
require_relative 'old_resolver'
module NxH18Blocked
  H = NxH18
  HS = H::HS
  module_function

  def cases
    values = { 'string' => 'moj-zaves', 'known_string' => 'zaves-p2o',
               'selector' => { 'param' => 'height', 'bands' => [{ 'min' => 0, 'max' => 2000, 'set_id' => 'zaves-p2o' }] },
               'invalid' => { 'invalid' => true }, 'none' => HS::MAPPING_NONE }
    %w[classified legacy].flat_map do |kind|
      item = kind == 'classified' ? H.door('tipon', 'front:F1/wing:single') : H.item('hinge', 'front:F1/wing:single', {}, 2)
      scopes = kind == 'classified' ? %w[cab class owner cab_owner class_owner] : %w[cab owner cab_owner]
      values.flat_map do |name, value|
        scopes.flat_map do |scope|
          raw = {}
          raw['hinge'] = H.copy(value) if %w[cab cab_owner].include?(scope)
          raw['class:hinge|tipon'] = H.copy(value) if %w[class class_owner].include?(scope)
          raw['hinge@front:F1/wing:single'] = H.copy(value) if scope.include?('owner')
          # Trieda prebija odlisny generic cab aj v pritomnosti ownera.
          raw['hinge'] = 'zaves-klasik' if scope.start_with?('class')
          %w[ok missing invalid blocked].map do |status|
            empty = %w[invalid blocked].include?(status)
            { 'id' => "P2/#{kind}/#{name}/#{scope}/#{status}", 'gt' => 'hinge', 'items' => [H.copy(item)],
              'overrides' => HS.normalize_mapping(H.copy(raw), nil, allow_owner: true),
              'status' => status, 'library_read_only' => status == 'invalid',
              'state' => { 'mapping' => empty ? {} : H.seed_mapping, 'sets' => empty ? {} : H.definitions } }
          end
        end
      end
    end
  end

  def source(item, overrides, mapping)
    return [nil, nil, nil] if item['quantity'].to_i < 1 || item['generic_type'].to_s.empty?
    return [nil, nil, nil] if HS.class_key_for(item, item['generic_type']).nil? && HS.lift_item?(item)

    ov, tags1 = H.tag_map(overrides, 'C')
    proj, tags2 = H.tag_map(mapping, 'P')
    tag = NxH18OldResolver.resolve_mapping_value(item['generic_type'], item, { item['owner_id'].to_s => ov }, proj)
    return [nil, nil, nil] if tag.nil?

    raw, scope, key = tags1.merge(tags2).fetch(tag)
    cls = HS.class_mapping_key?(key)
    level = if scope == 'P' then cls ? 'project_class' : 'project'
            elsif key.include?('@') then cls ? 'owner_class' : 'owner'
            else cls ? 'cab_class' : 'cab'
            end
    [raw, level, key]
  end

  def label(src, defs)
    "podľa #{H::SOURCE_WORDS.fetch(src[1])} — #{HS.mapping_value_text(src[0], defs)}"
  end

  def flat_active_text(raw, defs)
    return nil if raw.nil?
    return 'neplatný výber (uložený výber)' if HS.invalid_mapping_value?(raw)
    return HS.param_by(raw['param']) if raw.is_a?(Hash)

    (defs[raw] || {})['name'] || "#{raw} (chýba)"
  end

  def truth(c)
    blocked = c['status'] == 'blocked'
    saved = c['overrides']
    effective = blocked ? {} : saved
    mapping, defs = c['state'].values_at('mapping', 'sets')
    active = H::P.active_class_by_owner(c['items'], c['gt'])
    owners = active.to_h do |owner, ck|
      item = c['items'].find { |it| it['owner_part_key'] == owner }
      winner = source(item, effective, mapping)
      stored = source(item, saved, mapping)
      reduced = %w[owner owner_class].include?(winner[1]) ? effective.reject { |k, _| k == winner[2] } : effective
      inherited = source(item, reduced, mapping)
      raw = %w[owner owner_class].include?(stored[1]) ? stored[0] : nil
      # Plochy select zobrazuje ulozeny owner kluc aj ak resolver preskoci
      # napr. vyklop bez systemu. Ulozene nie je to iste ako ucinny vitaz.
      flat_raw = ck ? raw : saved["#{c['gt']}@#{owner}"]
      [owner, { 'class_key' => ck, 'winner' => winner, 'stored_winner' => stored,
                'stored_id' => HS.mapping_option_id(stored[0]), 'stored_text' => HS.mapping_value_text(stored[0], defs),
                'without_own' => inherited, 'none_label' => label(inherited, defs),
                'flat_raw' => flat_raw, 'flat_text' => flat_raw.nil? ? nil : HS.mapping_value_text(flat_raw, defs),
                'flat_active_text' => flat_active_text(flat_raw, defs) }]
    end
    classes = active.values.uniq
    cab = if classes.length == 1 && classes.first
            ck = classes.first
            item = c['items'].find { |it| HS.class_key_for(it, c['gt']) == ck }.merge('owner_part_key' => '')
            stored = source(item, saved, mapping)
            # Blocked: ukaz vsetky skutocne ulozene cab urovne; bez ownera.
            raw = blocked ? (%w[cab_class cab].include?(stored[1]) ? stored[0] : nil) : saved[ck]
            inherited = source(item, effective.reject { |k, _| k == ck }, mapping)
            { 'class_key' => ck, 'winner' => source(item, effective, mapping),
              'stored_value' => raw, 'stored_id' => HS.mapping_option_id(raw), 'stored_text' => HS.mapping_value_text(raw, defs),
              'without_own' => inherited, 'none_label' => label(inherited, defs) }
          end
    items = c['items'].map { |it| source(it, effective, mapping) }
    raw = saved[c['gt']]
    proj = mapping[c['gt']]
    project_label = if proj.is_a?(Hash) then "podľa projektu — #{HS.param_by(proj['param'])}"
                    elsif proj.is_a?(String) then "podľa projektu — #{(defs[proj] || {})['name'] || proj}"
                    else 'podľa projektu — bez setu'
                    end
    { 'gt' => c['gt'], 'status' => c['status'], 'items' => items, 'owners' => owners, 'cab' => cab,
      'own_keys' => items.filter_map { |_v, level, key| H::OWN_LEVELS.include?(level) ? key : nil }.uniq,
      'flat_cab_raw' => raw, 'flat_cab_text' => raw.nil? ? nil : HS.mapping_value_text(raw, defs),
      'flat_cab_active_text' => flat_active_text(raw, defs),
      'flat_none_label' => project_label }
  end
end
