# frozen_string_literal: true
# Noxun Engine — V0.6 E-a: DATA ROZPOCTU V ZAKAZKE (NOXUN dict na MODELI).
# Vsetko, co patri konkretnej zakazke a cestuje so .skp suborom:
#   budget_mode                — cenovy rezim (nizky|standard|vysoky)
#   budget_overrides           — { row_key => suma }  (rucny prepis AUTO riadku)
#   budget_std_multipliers     — { row_key => nasobok } (skala standardnych riadkov)
#   budget_viz_m2              — m2 vizualizacie (RUCNY vstup z meracky)
#   budget_custom_items[]      — vlastne polozky (doprava, subdodavky, LED...)
#   budget_appliances[]        — spotrebice (manualne, S1 z nich urobi katalog)
#   budget_appliances_included — sceituju sa spotrebice do SPOLU? (default NIE)
#   budget_cp_overrides        — { zdrojovy_kluc => "samostatne"|"zostava" }
#                                zaradenie polozky v CENOVEJ PONUKE (E-b2)
#   budget_std                 — VERZIA FORMATU dat rozpoctu (R-14, Integer)
#
# ========================== ZAVAZNE PRAVIDLA ===========================
# 1) MALE MUTACNE METODY — kazda zmena ma vlastnu metodu a vlastnu
#    model.start_operation/commit_operation (jeden Undo krok). UI NIKDY
#    neposiela cely dokument na prepis (audit 10) — len cielenu mutaciu.
# 2) VALIDACIA JE SERVEROVA a bezi PRED otvorenim operacie: chybny vstup
#    neotvori undo krok a nic nezapise.
# 3) CENA nil = "nezadana" a je LEGALNA (riadok dostane warning "chýba cena")
#    — NIKDY sa nenahradi nulou (audit 5/9).
# 4) ID polozky je serverom generovane UUID (audit 9/13) — klient ho pri
#    zakladani nedodava; update/delete adresuju polozku VYHRADNE cez UUID.
# 5) cp_skupina (default "zostava") nesie kazda rucna polozka — je to VOLNY
#    nazov skupiny z E-a, ktory sa len prenasa (rozpocet ho nepouziva).
#    POZOR: AUTORITA zaradenia polozky v CENOVEJ PONUKE je `budget_cp_overrides`
#    nizsie (E-b2) — riesi VSETKY riadky rozpoctu jednotne cez kluc riadku,
#    nielen rucne polozky. cp_skupina ostava kvoli spatnej kompatibilite dat.
require 'json'
require 'securerandom'
require 'uri'

module Noxun
  module Engine
    module BudgetStore
      KEY_MODE        = 'budget_mode'
      KEY_OVERRIDES   = 'budget_overrides'
      KEY_MULTIPLIERS = 'budget_std_multipliers'
      KEY_VIZ_M2      = 'budget_viz_m2'
      KEY_CUSTOM      = 'budget_custom_items'
      KEY_APPLIANCES  = 'budget_appliances'
      KEY_APPL_INCL   = 'budget_appliances_included'
      KEY_CP_OVERRIDES = 'budget_cp_overrides'
      # R-14 (blok 1d): VERZIA FORMATU DAT ROZPOCTU V ZAKAZKE.
      # POZOR na zamenu mien: `budget_std_multipliers` su CENOVE NASOBICE
      # standardnych riadkov, s verziou nemaju nic spolocne.
      KEY_STD = 'budget_std'

      # Cislo, ktoremu TATO verzia pluginu rozumie. Rozpoctove data su uzavrete
      # whitelisty (`build_custom`/`build_appliance`/`numeric_map`), takze
      # zakazka ulozena NOVSIM pluginom by prvym klikom v Rozpocte ticho prisla
      # o polia, ktore tato verzia nepozna.
      #
      # DISCIPLINA BUMPU (SYSTEM/STANDARD.md 11.3, vzor CONFIG_SCHEMA): cislo
      # sa zvysi pri KAZDOM rozsireni whitelistu rozpoctovych dat o pole,
      # ktoreho ticha strata by poskodila CENU alebo objednavku (nove pole
      # vlastnej polozky, vazba spotrebica na katalog v bloku 4, novy kluc
      # zaradenia v ponuke). Cisto odvodene/zobrazovacie pole bump nevyzaduje.
      BUDGET_STD = 1

      # Sentinel pre rozlisenie „atribut NIE JE" od „atribut je a je prazdny".
      # `read_attr` obe splostuje na nil a fail-open `.to_i` by z poskodenej
      # hodnoty spravil legacy (0) — teda povolenie (F3 auditu).
      STD_MISSING = Object.new.freeze

      # Hlasky odmietnutia — JEDINY textovy zdroj pre mutacie, banner v UI aj
      # branu cenovych exportov (vzor `newer_config_message` z R-12).
      STD_MESSAGES = {
        'newer' => 'Rozpočet zákazky je z novšej verzie Noxun — úprava by dáta orezala; aktualizuj plugin.',
        'invalid' => 'Dáta rozpočtu sú poškodené (neplatná verzia formátu) — nahlás problém, needituj.'
      }.freeze

      # Typy spotrebicov (S1 z enumu spravi vazbu na katalog — ID struktura
      # ostava kompatibilna dopredu).
      APPLIANCE_TYPES = %w[chladnicka rura mikrovlnka umyvacka digestor varna_doska ine].freeze
      APPLIANCE_LABELS = {
        'chladnicka' => 'Chladnička', 'rura' => 'Rúra', 'mikrovlnka' => 'Mikrovlnka',
        'umyvacka' => 'Umývačka', 'digestor' => 'Digestor', 'varna_doska' => 'Varná doska',
        'ine' => 'Iné'
      }.freeze
      DEFAULT_APPLIANCE_TYPE = 'ine'

      DEFAULT_CP_GROUP = 'zostava'

      # Kluce riadkov rozpoctu (overridy/nasobky): "service:<sadzba>" pre
      # automaticke sluzby, "std:<riadok>" pre standardne riadky. Nazvy sa
      # NIKDY nepouzivaju ako kluc (audit 6).
      ROW_KEY_RE = /\A(service|std):[a-z0-9_]{1,40}\z/.freeze

      # E-b2: zdrojovy kluc zaradenia v cenovej ponuke = KLUC RIADKU ROZPOCTU
      # ("material:<id>", "hw:<kod>", "custom:<uuid>", "appliance:<uuid>").
      # Nazvy sa ako kluc NIKDY nepouzivaju — kluc riadku je stabilny naprieč
      # prepocitmi a nesie uz aj material_id / kod / uuid.
      #
      # GH #139 P2: za dvojbodkou sa NEOBMEDZUJE znakova sada. Katalog kovania
      # vyzaduje od kodu LEN neprazdny trim (HardwareCatalog.normalize_item),
      # takze kod smie obsahovat MEDZERU — prisnejsi vzor (\S) by prepinac
      # cenovej ponuky na takej polozke natrvalo odmietal. Strazi sa prefix,
      # dlzka a zakaz riadiacich znakov; identitu kluca definuje Budget.
      CP_KEY_RE = /\A(material|hw|custom|appliance):[^[:cntrl:]]{1,120}\z/.freeze
      CP_GROUPS = %w[samostatne zostava].freeze

      MAX_CUSTOM_ITEMS = 200
      MAX_APPLIANCES   = 100

      # Rozsahy (EUR / nasobok / m2). Zaporna cena je pri RUCNEJ polozke
      # legitimna (zlava, dorovnanie ponuky) — auto riadky ju nemaju.
      PRICE_RANGE      = (-100_000.0..1_000_000.0)
      OVERRIDE_RANGE   = (0.0..1_000_000.0)
      MULTIPLIER_RANGE = (0.0..1_000.0)
      VIZ_M2_RANGE     = (0.0..10_000.0)
      QUANTITY_RANGE   = (1..9_999)

      MAX_TEXT = { 'popis' => 200, 'nazov' => 200, 'kod' => 60, 'dodavatel' => 80,
                   'poznamka' => 500, 'url' => 500, 'cp_skupina' => 60 }.freeze

      # R-14: prepinac „prave bezi mutacny blok `write!`". Nizkourovnove zapisy
      # (`write_attr`/`write_json`) mimo neho su ZAKAZANE — inak by budúca
      # mutacia (napr. spotrebice S1) dopredny guard aj zapis markera obisla.
      @in_write = false

      module_function

      # --- verzia formatu dat (R-14) ------------------------------------------

      # Stav markera v zakazke:
      #   :legacy  — atribut NIE JE (zakazka spred R-14) — mutacie PREJDU
      #              a prva z nich marker zapise,
      #   :current — marker <= BUDGET_STD (data rozumieme) — mutacie PREJDU,
      #   :newer   — marker > BUDGET_STD (zakazka z novsieho pluginu),
      #   :invalid — marker JE, ale nie je to cele kladne cislo (poskodene
      #              data), alebo citanie atributu vyhodilo vynimku.
      # Posledne dva stavy mutacie ODMIETAJU — kazdy vlastnou hlaskou.
      def std_state(model)
        kind, raw = read_std(model)
        return :legacy if kind == :missing
        return :invalid unless kind == :present && raw.is_a?(Integer) && raw >= 1

        raw > BUDGET_STD ? :newer : :current
      end

      def std_compatible?(model)
        %i[legacy current].include?(std_state(model))
      end

      # Dovod odmietnutia pre dany stav; '' = stav je kompatibilny.
      # Prijima symbol aj string (payload posiela string).
      def std_block_reason(state)
        STD_MESSAGES[state.to_s] || ''
      end

      # -> [:missing | :present | :error, hodnota]
      # ZAMERNE nejde cez `read_attr`: ten rescue-uje na nil a „atribut nie je"
      # by sa nedalo odlisit od „citanie zlyhalo" ani od ulozeneho prazdna.
      def read_std(model)
        return [:missing, nil] unless model.respond_to?(:get_attribute)

        v = model.get_attribute(Store::DICT, KEY_STD, STD_MISSING)
        v.equal?(STD_MISSING) ? [:missing, nil] : [:present, v]
      rescue StandardError => e
        Engine.log_error(e, 'BudgetStore.read_std') if defined?(Engine)
        [:error, nil]
      end

      # --- citanie -------------------------------------------------------------

      # Cely stav rozpoctu zakazky (normalizovany, string kluce). Poskodene
      # data = prazdny/defaultny tvar (rozpocet sa nikdy nezhodi).
      def state(model)
        {
          'mode' => mode(model),
          'overrides' => overrides(model),
          'std_multipliers' => std_multipliers(model),
          'viz_m2' => viz_m2(model),
          'custom_items' => custom_items(model),
          'appliances' => appliances(model),
          'appliances_included' => appliances_included?(model),
          'cp_overrides' => cp_overrides(model),
          # R-14: kompatibilita dat cestuje SO STAVOM — payload rozpoctu z nej
          # sklada priznak pre obe sekcie okna aj pre branu cenovych exportov.
          'std' => std_state(model).to_s
        }
      end

      def mode(model)
        v = read_attr(model, KEY_MODE).to_s
        SupplierSettings::MODES.include?(v) ? v : SupplierSettings::DEFAULT_MODE
      end

      def overrides(model)
        numeric_map(read_json(model, KEY_OVERRIDES), OVERRIDE_RANGE)
      end

      def std_multipliers(model)
        numeric_map(read_json(model, KEY_MULTIPLIERS), MULTIPLIER_RANGE)
      end

      def viz_m2(model)
        f = num(read_attr(model, KEY_VIZ_M2))
        f.nil? || !VIZ_M2_RANGE.cover?(f) ? nil : f
      end

      def custom_items(model)
        Array(read_json(model, KEY_CUSTOM)).map { |it| normalize_custom(it) }.compact
      end

      def appliances(model)
        Array(read_json(model, KEY_APPLIANCES)).map { |it| normalize_appliance(it) }.compact
      end

      def appliances_included?(model)
        read_attr(model, KEY_APPL_INCL) == true
      end

      # E-b2: zaradenie polozky v cenovej ponuke. Chybajuci zaznam = "necham
      # rozhodnut server" (navrh podla prahu) — preto sa NIKDY nedopĺňa default.
      def cp_overrides(model)
        out = {}
        raw = read_json(model, KEY_CP_OVERRIDES)
        return out unless raw.is_a?(Hash)

        raw.each do |k, v|
          key = k.to_s
          val = v.to_s
          out[key] = val if CP_KEY_RE.match?(key) && CP_GROUPS.include?(val)
        end
        out
      end

      # --- mutacie (kazda = 1 undo krok) --------------------------------------

      # -> [true, []] | [false, [chyby]]
      def set_mode!(model, value)
        v = value.to_s.strip
        return [false, ['neznámy cenový režim']] unless SupplierSettings::MODES.include?(v)
        write!(model, 'Rozpočet — cenový režim') { write_attr(model, KEY_MODE, v) }
      end

      # Rucny prepis AUTO riadku (sluzba/standardny riadok). amount nil =
      # ZRUSENIE overridu (riadok sa vrati na automaticky vypocet).
      def set_override!(model, row_key, amount)
        key = row_key.to_s.strip
        return [false, ['neplatný kľúč riadku']] unless ROW_KEY_RE.match?(key)
        if amount.nil? || amount.to_s.strip.empty?
          return write!(model, 'Rozpočet — zrušenie prepisu') do
            map = overrides(model)
            map.delete(key)
            write_json(model, KEY_OVERRIDES, map)
          end
        end
        f = num(amount)
        return [false, ['suma musí byť číslo']] if f.nil?
        return [false, ['suma je mimo rozsahu']] unless OVERRIDE_RANGE.cover?(f)
        write!(model, 'Rozpočet — prepis sumy') do
          map = overrides(model)
          map[key] = f
          write_json(model, KEY_OVERRIDES, map)
        end
      end

      def clear_override!(model, row_key)
        set_override!(model, row_key, nil)
      end

      # Nasobok standardneho riadku (skala zakazky 0 / 0,2 / 0,5 / 1 / 2 / 4).
      # nil = navrat na default zo settings.
      def set_std_multiplier!(model, row_key, multiplier)
        key = row_key.to_s.strip
        return [false, ['neplatný kľúč riadku']] unless ROW_KEY_RE.match?(key)
        if multiplier.nil? || multiplier.to_s.strip.empty?
          return write!(model, 'Rozpočet — návrat na predvolený násobok') do
            map = std_multipliers(model)
            map.delete(key)
            write_json(model, KEY_MULTIPLIERS, map)
          end
        end
        f = num(multiplier)
        return [false, ['násobok musí byť číslo']] if f.nil?
        return [false, ['násobok je mimo rozsahu']] unless MULTIPLIER_RANGE.cover?(f)
        write!(model, 'Rozpočet — násobok riadku') do
          map = std_multipliers(model)
          map[key] = f
          write_json(model, KEY_MULTIPLIERS, map)
        end
      end

      # m2 vizualizacie — RUCNY vstup (z merackY, nie z dat pluginu). nil = zmazanie.
      def set_viz_m2!(model, value)
        if value.nil? || value.to_s.strip.empty?
          return write!(model, 'Rozpočet — m² vizualizácie') { write_attr(model, KEY_VIZ_M2, '') }
        end
        f = num(value)
        return [false, ['m² musia byť číslo']] if f.nil?
        return [false, ['m² sú mimo rozsahu']] unless VIZ_M2_RANGE.cover?(f)
        write!(model, 'Rozpočet — m² vizualizácie') { write_attr(model, KEY_VIZ_M2, f) }
      end

      def set_appliances_included!(model, included)
        flag = included == true || included.to_s == 'true'
        write!(model, 'Rozpočet — spotrebiče v súčte') { write_attr(model, KEY_APPL_INCL, flag) }
      end

      # E-b2: „samostatne v CP" / „v zostave" per polozka. Prazdna hodnota =
      # ZRUSENIE rozhodnutia (polozka sa vrati na serverovy navrh podla prahu).
      def set_cp_group!(model, source_key, group)
        key = source_key.to_s.strip
        return [false, ['neplatný kľúč položky']] unless CP_KEY_RE.match?(key)

        value = group.to_s.strip
        if value.empty?
          return write!(model, 'Cenová ponuka — návrat na návrh') do
            map = cp_overrides(model)
            map.delete(key)
            write_json(model, KEY_CP_OVERRIDES, map)
          end
        end
        return [false, ['neznáme zaradenie v cenovej ponuke']] unless CP_GROUPS.include?(value)

        write!(model, 'Cenová ponuka — zaradenie položky') do
          map = cp_overrides(model)
          map[key] = value
          write_json(model, KEY_CP_OVERRIDES, map)
        end
      end

      # --- vlastne polozky -----------------------------------------------------

      # -> [polozka, []] | [nil, [chyby]]
      def add_custom_item!(model, attrs)
        item, errors = build_custom(attrs, nil)
        return [nil, errors] unless errors.empty?
        list = custom_items(model)
        return [nil, ['viac položiek sa už nezmestí']] if list.length >= MAX_CUSTOM_ITEMS
        list << item
        ok, errs = write!(model, 'Rozpočet — nová položka') { write_json(model, KEY_CUSTOM, list) }
        ok ? [item, []] : [nil, errs]
      end

      def update_custom_item!(model, id, attrs)
        list = custom_items(model)
        idx = list.index { |it| it['id'] == id.to_s }
        return [nil, ['položka sa nenašla']] if idx.nil?
        item, errors = build_custom(attrs, list[idx])
        return [nil, errors] unless errors.empty?
        list[idx] = item
        ok, errs = write!(model, 'Rozpočet — úprava položky') { write_json(model, KEY_CUSTOM, list) }
        ok ? [item, []] : [nil, errs]
      end

      def remove_custom_item!(model, id)
        list = custom_items(model)
        rest = list.reject { |it| it['id'] == id.to_s }
        return [false, ['položka sa nenašla']] if rest.length == list.length
        write!(model, 'Rozpočet — zmazanie položky') { write_json(model, KEY_CUSTOM, rest) }
      end

      # --- spotrebice ----------------------------------------------------------

      def add_appliance!(model, attrs)
        item, errors = build_appliance(attrs, nil)
        return [nil, errors] unless errors.empty?
        list = appliances(model)
        return [nil, ['viac spotrebičov sa už nezmestí']] if list.length >= MAX_APPLIANCES
        list << item
        ok, errs = write!(model, 'Rozpočet — nový spotrebič') { write_json(model, KEY_APPLIANCES, list) }
        ok ? [item, []] : [nil, errs]
      end

      def update_appliance!(model, id, attrs)
        list = appliances(model)
        idx = list.index { |it| it['id'] == id.to_s }
        return [nil, ['spotrebič sa nenašiel']] if idx.nil?
        item, errors = build_appliance(attrs, list[idx])
        return [nil, errors] unless errors.empty?
        list[idx] = item
        ok, errs = write!(model, 'Rozpočet — úprava spotrebiča') { write_json(model, KEY_APPLIANCES, list) }
        ok ? [item, []] : [nil, errs]
      end

      def remove_appliance!(model, id)
        list = appliances(model)
        rest = list.reject { |it| it['id'] == id.to_s }
        return [false, ['spotrebič sa nenašiel']] if rest.length == list.length
        write!(model, 'Rozpočet — zmazanie spotrebiča') { write_json(model, KEY_APPLIANCES, rest) }
      end

      # --- stavba a validacia zaznamov ----------------------------------------

      # existing = nil pri zakladani (server vygeneruje UUID), inak povodny
      # zaznam (id sa NIKDY nemeni; nedodane polia sa zachovaju).
      # -> [zaznam, chyby]
      def build_custom(attrs, existing)
        a = stringify(attrs.is_a?(Hash) ? attrs : {})
        base = existing.is_a?(Hash) ? existing : {}
        errors = []
        out = { 'id' => (base['id'] || SecureRandom.uuid).to_s }
        out['popis'] = text_field(a, base, 'popis', errors)
        out['pocet'] = quantity_field(a, base, errors)
        cena, cena_err = price_field(a, base, 'cena')
        errors << cena_err if cena_err
        out['cena'] = cena
        put_opt(out, 'kod', text_field(a, base, 'kod', errors))
        put_opt(out, 'poznamka', text_field(a, base, 'poznamka', errors))
        url, url_err = url_field(a, base)
        errors << url_err if url_err
        put_opt(out, 'url', url)
        out['cp_skupina'] = cp_group_field(a, base, errors)
        [out, errors.compact.uniq]
      end

      def build_appliance(attrs, existing)
        a = stringify(attrs.is_a?(Hash) ? attrs : {})
        base = existing.is_a?(Hash) ? existing : {}
        errors = []
        out = { 'id' => (base['id'] || SecureRandom.uuid).to_s }
        typ = a.key?('typ') ? a['typ'].to_s.strip : base['typ'].to_s
        typ = DEFAULT_APPLIANCE_TYPE if typ.empty?
        errors << 'neznámy typ spotrebiča' unless APPLIANCE_TYPES.include?(typ)
        out['typ'] = typ
        out['nazov'] = text_field(a, base, 'nazov', errors)
        cena, cena_err = price_field(a, base, 'cena')
        errors << cena_err if cena_err
        out['cena'] = cena
        put_opt(out, 'dodavatel', text_field(a, base, 'dodavatel', errors))
        url, url_err = url_field(a, base)
        errors << url_err if url_err
        put_opt(out, 'url', url)
        out['cp_skupina'] = cp_group_field(a, base, errors)
        [out, errors.compact.uniq]
      end

      def text_field(attrs, base, key, errors)
        raw = attrs.key?(key) ? attrs[key] : base[key]
        v = raw.to_s.strip
        limit = MAX_TEXT[key] || 200
        if v.length > limit
          errors << "#{key}: text je pridlhý (max #{limit} znakov)"
          v = v[0, limit]
        end
        v
      end

      def quantity_field(attrs, base, errors)
        raw = attrs.key?('pocet') ? attrs['pocet'] : base['pocet']
        return 1 if raw.nil? || raw.to_s.strip.empty?
        f = num(raw)
        if f.nil? || f != f.round || !QUANTITY_RANGE.cover?(f.round)
          errors << 'počet musí byť celé číslo 1 a viac'
          return 1
        end
        f.round
      end

      # Cena nil = "nezadana" (legalna) — do suctu nejde a riadok dostane
      # warning. Necislo = CHYBA (nie ticha 0).
      def price_field(attrs, base, key)
        raw = attrs.key?(key) ? attrs[key] : base[key]
        return [nil, nil] if raw.nil? || raw.to_s.strip.empty?
        f = num(raw)
        return [nil, 'cena musí byť číslo'] if f.nil?
        return [nil, 'cena je mimo rozsahu'] unless PRICE_RANGE.cover?(f)
        [f, nil]
      end

      # URL rucnej polozky smie mierit KAMKOLVEK (drezyonline, flexipanely...),
      # ale VYHRADNE http/https — ziadne javascript:/data:/file: (otvara sa
      # cez UI.openURL). Vzor sanitize: server je autorita, klientske echo nie.
      def url_field(attrs, base)
        raw = attrs.key?('url') ? attrs['url'] : base['url']
        s = raw.to_s.strip
        return ['', nil] if s.empty?
        return [nil, 'adresa je pridlhá'] if s.length > MAX_TEXT['url']
        clean = sanitize_url(s)
        clean.nil? ? [nil, 'adresa musí začínať http:// alebo https://'] : [clean, nil]
      end

      def sanitize_url(raw)
        s = raw.to_s.strip
        return nil if s.empty?
        return nil unless s =~ %r{\Ahttps?://}i
        return nil if s =~ /[\s"'<>\\]/
        uri = begin
          URI.parse(s)
        rescue StandardError
          nil
        end
        return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        return nil if uri.host.to_s.strip.empty?
        uri.to_s
      end

      def cp_group_field(attrs, base, errors)
        raw = attrs.key?('cp_skupina') ? attrs['cp_skupina'] : base['cp_skupina']
        v = raw.to_s.strip
        return DEFAULT_CP_GROUP if v.empty?
        if v.length > MAX_TEXT['cp_skupina']
          errors << 'skupina cenovej ponuky: text je pridlhý'
          v = v[0, MAX_TEXT['cp_skupina']]
        end
        v
      end

      # --- normalizacia citania ------------------------------------------------

      def normalize_custom(raw)
        return nil unless raw.is_a?(Hash)
        id = raw['id'].to_s.strip
        return nil if id.empty?
        item, = build_custom(raw.merge('id' => id), { 'id' => id })
        item
      end

      def normalize_appliance(raw)
        return nil unless raw.is_a?(Hash)
        id = raw['id'].to_s.strip
        return nil if id.empty?
        item, = build_appliance(raw.merge('id' => id), { 'id' => id })
        item
      end

      def numeric_map(raw, range)
        out = {}
        return out unless raw.is_a?(Hash)
        raw.each do |k, v|
          key = k.to_s
          next unless ROW_KEY_RE.match?(key)
          f = num(v)
          out[key] = f if f && range.cover?(f)
        end
        out
      end

      # --- nizkourovnovy pristup k dict ---------------------------------------

      def read_attr(model, key)
        return nil unless model.respond_to?(:get_attribute)
        model.get_attribute(Store::DICT, key)
      rescue StandardError
        nil
      end

      # R-14: zapis JE POVOLENY LEN vnutri `write!`. Volanie mimo neho je chyba
      # programu (obisiel by dopredny guard aj zapis markera) — a vynimka je
      # jediny sposob, ako to zastavit aj v buducej mutacii, ktora by na
      # `write_attr` siahla priamo.
      def write_attr(model, key, value)
        raise 'BudgetStore: zápis mimo write! — mutácia musí ísť cez jediný choke point (R-14)' unless @in_write

        model.set_attribute(Store::DICT, key, value)
        true
      end

      def read_json(model, key)
        raw = read_attr(model, key)
        return nil if raw.nil? || raw.to_s.strip.empty?
        JSON.parse(raw.to_s)
      rescue StandardError => e
        Engine.log_error(e, "BudgetStore.read_json(#{key})") if defined?(Engine)
        nil
      end

      def write_json(model, key, value)
        write_attr(model, key, value.to_json)
      end

      # Jedna mutacia = jeden undo krok. Volat AZ PO validacii (chybny vstup
      # nesmie otvorit operaciu). -> [true, []] | [false, [chyby]]
      #
      # R-14: JEDINY CHOKE POINT vsetkych 12 mutacii, takze dopredny guard
      # stoji TU — tesne pred `start_operation`, aby odmietnuta mutacia
      # nezalozila ziadny krok Spat. Marker sa zapisuje PO mutacnom bloku,
      # ale este PRED `commit_operation`: udaj a marker su tak JEDNA operacia
      # (jeden krok Spat vrati oboje, vynimka pri zapise markera zrusi cely
      # krok — ziadny polovicny zapis).
      def write!(model, operation_name)
        return [false, ['model nie je k dispozícii']] unless model

        reason = std_block_reason(std_state(model))
        return [false, [reason]] unless reason.empty?

        model.start_operation(operation_name, true)
        begin
          @in_write = true
          yield
          stamp_std(model)
        ensure
          @in_write = false
        end
        model.commit_operation
        [true, []]
      rescue StandardError => e
        begin
          model.abort_operation
        rescue StandardError
          nil
        end
        Engine.log_error(e, 'BudgetStore.write!') if defined?(Engine)
        [false, ['zmenu sa nepodarilo uložiť']]
      end

      # R-14: marker sa zapisuje VZDY ako AKTUALNA hodnota (nikdy sa nepreberá
      # z ulozeneho stavu ani z klientskeho payloadu — autorita je verzia,
      # ktora zapis vykonava). Bezi vnutri otvorenej operacie `write!`.
      def stamp_std(model)
        write_attr(model, KEY_STD, BUDGET_STD)
      end

      # --- pomocne -------------------------------------------------------------

      def put_opt(out, key, value)
        v = value.to_s.strip
        out[key] = v unless v.empty?
      end

      def num(v)
        return nil if v.nil?
        return nil if v.is_a?(String) && v.strip.empty?
        f = Float(v.to_s.tr(',', '.'))
        f.finite? ? f : nil
      rescue StandardError
        nil
      end

      def stringify(value)
        case value
        when Hash then value.each_with_object({}) { |(k, v), out| out[k.to_s] = stringify(v) }
        when Array then value.map { |v| stringify(v) }
        else value
        end
      end
    end
  end
end
