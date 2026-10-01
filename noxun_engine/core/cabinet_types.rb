# frozen_string_literal: true
# Noxun Engine — REGISTER TYPOV SKRINKY (H12a, C-01; STANDARD §4.2).
#
# JEDINE miesto, ktore vie, ake typy skrinky existuju a ake maju VLASTNOSTI
# („visi", „stoji na podlahe", „ma korpus", „vlastnik spotrebica", „rohova
# zostava", „typ sablony sa neda prepnut", vlastne limity, nazvy). Jadro sa
# pyta VLASTNOSTI, nie mena typu — novy typ = riadok registra + vlastny kod
# buildera, nie desat zoznamov v siestich suboroch (guard
# `tests/pure/test_h12a_register.rb` zhodi nove `== 'upper'` mimo registra).
#
# CO REGISTER NIE JE: predvolby (`*_DEFAULTS`), polia typu (`DW_KEYS`,
# `CORNER_KEYS`) a kod typov (`appliance_slot_plan`, `corner_parts`…) ostavaju
# v builderi — register hovori, KTORA vetva plati, nie AKO sa stavia.
#
# NEZNAMY TYP (aj z novsieho pluginu) sa cita ako DOLNA (`norm` -> `FALLBACK`)
# — dnesne spravanie; config z novsej verzie zastavi dopredny guard
# `newer_config?` este PRED normalizaciou. Miesta, ktore porovnavaju IDENTITU
# (vstup pravidiel kovania `cabinet_type`, typ sablony vs. skrinky, kluc pamate
# ghostu), si ponechavaju SUROVY retazec — `id_or_default` (nil/'' -> dolna,
# neznamy ostava).
#
# CISTY modul: ziadne IO, ziadny SketchUp. Nacitava sa hned za `build_plan`
# (pred `construction` — `CORNER_TYPE`, `scale_observer` — `MIN_BY_TYPE`
# a `cabinet_builder` — `TYPES`, `CORNER_TYPE`, `UPPER_HANG_Z`, `DW_*_RANGE`;
# tie z neho beru aliasy uz pri nacitani; poradie strazi guard).
module Noxun
  module Engine
    module CabinetTypes
      # Texty zamku typu sablony a dovodu „nema zony" su DOSLOVNE prevzate
      # z niekdajsich JS tabuliek (`form.js` TPL_TYPE_LOCK, `shell.js`
      # NX_CTX_LOCK) — od H12c ich JS cita LEN odtialto (`client_payload`).
      DW_LOCK = {
        title: 'Typ určuje sám slot umývačky — prepnúť sa nedá.',
        tip: 'Typ určuje sám slot umývačky — nemá korpus, takže sa na dolnú ani hornú skrinku prepnúť nedá.'
      }.freeze
      CORNER_LOCK = {
        title: 'Typ určuje rohová skrinka — prepnúť sa nedá.',
        tip: 'Rohová skrinka nesie rohovú zostavu (blenda, výstuhy, CR lišty) — šablóna z nej je vždy ' \
             'rohová, na dolnú ani hornú sa prepnúť nedá.'
      }.freeze

      # Kluce a hodnoty: package H12 §0.4 (vlastnosti odvodene zo supisu 75
      # rozhodovacich miest). Dve „podlahove" vlastnosti su ZAMERNE dve:
      #   * `hang_z > 0` = VISI (dnes „len horna": vyska vlozenia, stary V0.1
      #     sokel, seed pravidla zavesov — pasca CN-03),
      #   * `on_floor` = STOJI NA PODLAHE (dnes „horna ALEBO slot": nohy/sokel
      #     v `normalize`, `support_type`, nahlad noh).
      # Jedna vlastnost by v okrajovom pripade zmenila spravanie slotu.
      REGISTRY = {
        'lower' => {
          id: 'lower', label: 'Dolná', word: 'dolná',
          auto_name: 'Spodná skrinka %{w}', auto_name_typed: false,
          preset: 'noxun-lower-18', template_id: 'base-lower-18',
          builder: 'carcass', hang_z: 0.0, on_floor: true, limits: nil,
          appliance_owner: 'cabinet', fronts: 'free', front_opening: 'full',
          zones: 'tree', zones_reason: nil,
          template_type: 'switchable', template_lock: nil, type_locked: false,
          assembly: nil, ui_order: 1
        }.freeze,
        'upper' => {
          id: 'upper', label: 'Horná', word: 'horná',
          auto_name: 'Horná skrinka %{w}', auto_name_typed: false,
          preset: 'noxun-upper-18', template_id: 'base-upper-18',
          builder: 'carcass', hang_z: 1400.0, on_floor: false, limits: nil,
          appliance_owner: 'cabinet', fronts: 'free', front_opening: 'full',
          zones: 'tree', zones_reason: nil,
          template_type: 'switchable', template_lock: nil, type_locked: false,
          assembly: nil, ui_order: 2
        }.freeze,
        'dishwasher' => {
          id: 'dishwasher', label: 'Umývačka', word: 'umývačka',
          auto_name: 'Umývačka %{dw} (slot)', auto_name_typed: false,
          preset: 'noxun-dishwasher', template_id: 'dishwasher-slot-18',
          builder: 'appliance_slot', hang_z: 0.0, on_floor: false,
          limits: { width: [300.0, 1200.0].freeze, height: [500.0, 1200.0].freeze }.freeze,
          appliance_owner: 'slot', fronts: 'slot_fixed', front_opening: 'slot',
          zones: 'none', zones_reason: 'slot umývačky zóny nemá',
          template_type: 'locked', template_lock: DW_LOCK, type_locked: false,
          assembly: nil, ui_order: 4
        }.freeze,
        'corner_blind' => {
          id: 'corner_blind', label: 'Rohová', word: 'rohová',
          auto_name: 'Rohová skrinka %{w}', auto_name_typed: true,
          preset: 'noxun-corner-blind', template_id: 'corner-blind-18',
          builder: 'carcass', hang_z: 0.0, on_floor: true, limits: nil,
          appliance_owner: 'cabinet', fronts: 'corner_one_door', front_opening: 'corner_door',
          zones: 'shelves_only', zones_reason: nil,
          template_type: 'locked', template_lock: CORNER_LOCK, type_locked: true,
          assembly: 'corner_blind', ui_order: 3
        }.freeze
      }.freeze

      # Poradie = dnesne `CabinetBuilder::TYPES` (poradie klucov JSON aj UI).
      IDS = REGISTRY.keys.freeze
      FALLBACK = 'lower'
      # Identifikator rohovej zostavy (alias `CabinetBuilder::CORNER_TYPE`
      # aj `Construction::CORNER_TYPE` — do H12a dvakrat definovany, S14).
      CORNER = 'corner_blind'
      # Kluce, ktore ma KAZDY typ (invariant registra, test T1).
      KEYS = REGISTRY[FALLBACK].keys.freeze

      module_function

      # Prijme String / Symbol / nil (a cokolvek s `to_s`).
      def known?(type)
        REGISTRY.key?(type.to_s)
      end

      # Znamy typ -> sam; neznamy, nil aj '' -> `FALLBACK` (profil dolnej).
      def norm(type)
        known?(type) ? type.to_s : FALLBACK
      end

      # IDENTITA s predvolbou: nil/'' -> `FALLBACK`, NEZNAMY typ OSTAVA (vzor
      # ghost kluca `t.empty? ? 'lower' : t`). Nenahradza porovnanie identity
      # sablon (`|| 'lower'` tam '' zachovava — audit H12 A2).
      def id_or_default(type)
        s = type.to_s
        s.empty? ? FALLBACK : s
      end

      def get(type)
        REGISTRY[norm(type)]
      end

      def prop(type, key)
        get(type)[key]
      end

      def hangs?(type)
        prop(type, :hang_z).to_f.positive?
      end

      def on_floor?(type)
        prop(type, :on_floor) == true
      end

      def carcass?(type)
        prop(type, :builder) == 'carcass'
      end

      def corner?(type)
        prop(type, :assembly) == CORNER
      end

      def ids_where(key, value)
        IDS.select { |id| REGISTRY[id][key] == value }
      end

      # Kontrakt pre JS (`NX.init` -> `NXTypes` v core.js, H12b/H12c): pole
      # hashov v poradi `IDS`, kluce ako STRINGY (tie iste mena ako `KEYS`),
      # hodnoty len JSON typy — ziadne symboly ani lambdy. Fixtura
      # `tests/fixtures/h12_cabinet_types.json` je jeho zmluva.
      def client_payload
        IDS.map { |id| plain(REGISTRY[id]) }
      end

      def plain(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), out| out[k.to_s] = plain(v) }
        when Array then obj.map { |v| plain(v) }
        else obj
        end
      end
    end
  end
end
