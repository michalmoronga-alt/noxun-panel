# frozen_string_literal: true
# Noxun Engine — S1-B1: VAZBA SPOTREBICA NA ZAKAZKU (jediny transakcny vstup).
#
# CO TENTO MODUL RIESI
# Spotrebic v zakazke ma DVE strany: polozku rozpoctu (`budget_appliances[]`
# na modeli) a VLASTNIKA (skrinka, slot umyvacky alebo doska), ktory o vazbe
# vie — nesie ju vo svojom configu v `appliance_refs[]`. Keby sa tie dve strany
# zapisovali kazda vo vlastnej operacii, jedno Spat by vratilo len jednu z nich
# a zakazka by ostala v stave, ktory v realnej kuchyni neexistuje (polozka
# tvrdi, ze rura je v CAB-3, skrinka o nej nevie).
#
# PRETO: KAZDA mutacia polozky spotrebica ide cez `apply!` a `apply!` ma PRAVE
# JEDNU `start_operation` (SketchUp nema vnorene operacie — `start_operation`
# v otvorenej operacii ju TICHO UKONCI, takze dve operacie nie su alternativa).
# V nej sa zapise polozka (`BudgetStore` v rezime `in_operation`), odstrani sa
# zaznam u PREDCHADZAJUCEHO vlastnika, prida sa u NOVEHO a obaja sa prestavaju.
# Vynimka = `abort_operation` CELEJ operacie: bud je zapisane vsetko, alebo nic.
#
# GUARDY BEZIA PRED `start_operation` (odmietnuta mutacia nesmie zalozit krok
# Spat — vzor D-133/D-134): identita dokumentu (`DocKey`), verzia dat rozpoctu
# (`BudgetStore.std_block_reason`), existencia polozky, matica kategoria ->
# vlastnik, identita CIELA (PID + ID + druh, nie odpojeny, nie z novsej verzie),
# stav PREDCHADZAJUCEHO vlastnika a POKOJ OBSERVERA (`ScaleWatch.flush_pending!`).
#
# CO TU NIE JE: cena (rozpocet), katalog (`appliance_catalog`), kreslenie tela
# spotrebica (S1-E slot, S1-F chladnicka) ani UI.
require 'json'

module Noxun
  module Engine
    module ApplianceBinding
      # Druhy vlastnika. `slot` je skrinka typu `dishwasher` (v modeli je to
      # `kind: 'cabinet'`) — v UI aj v matici je to ale VLASTNY druh, lebo
      # umyvacka do beznej skrinky nepatri.
      KIND_CABINET = 'cabinet'
      KIND_SLOT    = 'slot'
      KIND_BOARD   = 'board'
      KIND_JOB     = 'job'
      OWNER_KINDS  = [KIND_CABINET, KIND_SLOT, KIND_BOARD, KIND_JOB].freeze
      JOB_LABEL    = 'len zákazka (bez väzby)'

      # R4 — MATICA KATEGORIA -> FYZICKY VLASTNIK. Obmedzuje VYHRADNE fyzickych
      # vlastnikov; `job` („len zakazka") je legitimny stav KAZDEJ kategorie
      # (B11), preto v matici nie je. Plati v ponuke vlastnikov AJ na serveri —
      # klientsky payload nie je ochrana (stale DOM, cudzi dokument).
      OWNER_MATRIX = {
        'fridge' => [KIND_CABINET].freeze,
        'oven' => [KIND_CABINET].freeze,
        'microwave' => [KIND_CABINET].freeze,
        'dishwasher' => [KIND_SLOT].freeze,
        'hob' => [KIND_BOARD].freeze,
        'sink' => [KIND_BOARD].freeze,
        'hood' => [].freeze,
        'other' => [].freeze
      }.freeze

      # Operacie jedineho vstupu (B2).
      #   create       zalozenie polozky (+ snapshot z katalogu, + pripadna vazba)
      #   patch        textove polia, cena, priznak „dodáva zákazník"
      #   rebind_model vymena MODELU z katalogu (novy snapshot + prepis refs)
      #   move         zmena VLASTNIKA nad ulozenym snapshotom
      #   unbind       vlastnik -> `job` (odstranenie refs)
      #   remove       zmazanie polozky (+ refs u vlastnika)
      OPS = %w[create patch rebind_model move unbind remove].freeze
      # Operacie, ktore smu niest VLASTNIKA. `patch` (cena, nazov, adresa,
      # priznak) a `remove` ho niest NESMU — payload s dvomi vlastnikmi je
      # nejednoznacny a tichy vyber jedneho z nich by spotrebic presunul bez
      # toho, aby o to niekto poziadal (Codex #382 kolo 1 P2).
      OWNER_OPS = %w[create move unbind rebind_model].freeze
      # To iste pre MODEL Z KATALOGU: `catalog_id` meni kategoriu polozky, a tu
      # overuje matica. Pri operacii, ktora snapshot neuklada (`move`, `unbind`,
      # `patch`, `remove`), by matica bezala nad kategoriou katalogu a ulozila
      # by sa stara — chladnicka by presla ako umyvacka na slot
      # (Codex #382 kolo 3 P2).
      CATALOG_OPS = %w[create rebind_model].freeze

      OP_NAME = 'NOXUN: Spotrebič — väzba'

      # Hlasky (jeden textovy zdroj — pouzivatel ma vsade citat to iste).
      MSG_NO_MODEL      = 'model nie je k dispozícii'
      MSG_FOREIGN_DOC   = 'Model sa medzitým prepol — obnovené, skús znova.'
      MSG_UNKNOWN_OP    = 'neznáma operácia spotrebiča'
      MSG_NOT_FOUND     = 'spotrebič sa nenašiel'
      MSG_BUSY          = 'Model ešte dokončuje predchádzajúcu zmenu — skús to o chvíľu znova.'
      MSG_OWNER_GONE    = 'vlastník sa nenašiel — obnov okno a vyber znova'
      MSG_OWNER_AMBIG   = 'nejednoznačná identita vlastníka (dva kusy s tým istým ID) — prestav skrinky'
      MSG_OWNER_OP      = 'zmena vlastníka ide vlastnou akciou — túto úpravu vlastník netýka'
      MSG_OWNER_STALE   = 'zastaraná ponuka vlastníkov — otvor modal znova'
      MSG_CATALOG_OP    = 'zmena modelu z katalógu ide vlastnou akciou — túto úpravu model netýka'
      MSG_TYPE_WITH_OWNER = 'typ sa pri zmene vlastníka nemení — najprv ulož typ, potom vlastníka'
      MSG_UNKNOWN_TYPE  = 'neznámy typ spotrebiča'
      MSG_OWNER_DETACH  = 'vlastník má odpojený dielec — vráť ho do skrinky a skús znova'
      MSG_OWNER_NEWER   = 'vlastník je z novšej verzie Noxun — väzba by jeho nastavenia stratila'
      MSG_PREV_LOCKED   = 'pôvodný vlastník sa nedá prestavať — väzbu treba najprv opraviť na ňom'
      MSG_FAILED        = 'väzbu sa nepodarilo uložiť'
      MSG_REBIND_CAT    = 'model inej kategórie — najprv odpoj spotrebič'
      MSG_NEED_CATALOG  = 'vyber model z katalógu'

      module_function

      # === JEDINY TRANSAKCNY VSTUP =========================================
      # -> { ok:, errors: [..], item: Hash|nil, geometry_changed: true|false }
      #
      # `model_guid` = identita dokumentu, v ktorom vznikla POZIADAVKA (B4).
      # `owner` = `{ 'kind' =>, 'id' =>, 'pid' => }` z ponuky vlastnikov; `nil`
      # znamena „vlastnika nemen" (pri `create` = `job`).
      def apply!(model, model_guid: nil, op:, item_id: nil, attrs: {}, catalog_id: nil, owner: nil)
        plan, errors = plan_for(model, model_guid: model_guid, op: op.to_s, item_id: item_id.to_s,
                                       attrs: attrs, catalog_id: catalog_id, owner: owner)
        return failure(errors) unless plan

        commit(model, plan)
      rescue StandardError => e
        Engine.log_error(e, 'ApplianceBinding.apply!') if defined?(Engine)
        failure([MSG_FAILED])
      end

      def failure(errors)
        { ok: false, errors: Array(errors), item: nil, geometry_changed: false }
      end

      # === PRIPRAVA (VSETKY guardy, ZIADNY zapis) ==========================
      # -> [plan, []] | [nil, [chyby]]
      def plan_for(model, model_guid:, op:, item_id:, attrs:, catalog_id:, owner:)
        return [nil, [MSG_NO_MODEL]] unless model
        return [nil, [MSG_UNKNOWN_OP]] unless OPS.include?(op)
        # Vlastnik v payloade operacie, ktora ho nemeni, sa ODMIETA (nie
        # ignoruje): tichy no-op by klientovi tvrdil, ze zmena presla.
        return [nil, [MSG_OWNER_OP]] if !owner.nil? && !OWNER_OPS.include?(op)
        if !catalog_id.to_s.strip.empty? && !CATALOG_OPS.include?(op)
          return [nil, [MSG_CATALOG_OP]]
        end

        # Identita dokumentu — rovnaka tolerancia ako rozpocet (prazdny udaj
        # zo stareho DOM neblokuje, NEZHODNE ID ano).
        if defined?(DocKey) && DocKey.foreign?(model_guid, model, tolerate_blank_client: true)
          return [nil, [MSG_FOREIGN_DOC]]
        end

        # Verzia dat rozpoctu — brana stoji TU (pred operaciou), nie az
        # v `BudgetStore.write!` (B1).
        reason = BudgetStore.std_block_reason(BudgetStore.std_state(model))
        return [nil, [reason]] unless reason.empty?

        items = BudgetStore.appliances(model)
        current = item_id.empty? ? nil : items.find { |it| it['id'] == item_id }
        return [nil, [MSG_NOT_FOUND]] if current.nil? && op != 'create'
        if op == 'create' && items.length >= BudgetStore::MAX_APPLIANCES
          return [nil, ['viac spotrebičov sa už nezmestí']]
        end

        snapshot, snap_err = snapshot_for(op, catalog_id, current)
        return [nil, [snap_err]] if snap_err

        # KATEGORIA je to, proti comu sa overuje matica — musi sa teda rovnat
        # tomu, co sa NAOZAJ ulozi (Codex #382 kolo 2 P2). Preto:
        #   * pri operaciach MENIACICH VLASTNIKA sa `typ` z formulara ODMIETA
        #     (inak by matica presla nad starou kategoriou a `write_item!` by
        #     ulozil novu — chladnicka by sa dostala do slotu ako umyvacka),
        #   * pri `create` sa neznamy kod odmietne uz tu (nikdy sa ticho
        #     nenahradi defaultom) a ulozeny typ je PRESNE `plan[:category]`.
        type_err = type_attr_error(op, attrs)
        return [nil, [type_err]] if type_err

        category = category_of(op, attrs, snapshot, current)
        target, terr = target_owner(op, owner, current, category)
        return [nil, [terr]] if terr

        # BARIERA OBSERVERA (B6): dedup kopii a presun ghostov moze PRAVE TERAZ
        # menit identitu skriniek. Bez pokoja by sme citali config, ktory o par
        # milisekund neplati — a transparentna reakcia observera by sa navyse
        # prilepila na nasu operaciu.
        return [nil, [MSG_BUSY]] unless observer_idle?(model)

        prev_owner = BudgetStore.owner_field(current ? current['owner'] : nil)
        prev = nil
        if touches_refs?(op)
          prev, perr = resolve_previous(model, prev_owner, item_id)
          return [nil, [perr]] if perr
        end

        # CIEL VAZBY. Dve cesty, zamerne oddelene:
        #   * VYSLOVNE VYBRANY vlastnik sa hlada podla identity (PID + ID + druh)
        #     a musi existovat — inak sa cela operacia odmietne,
        #   * IMPLICITNE NESENY vlastnik (vymena modelu nad uz viazanou polozkou)
        #     sa NEHLADA VOBEC: pouzije sa PRESNE tá entita, ktoru overil
        #     `resolve_previous` (existuje, sedi PID a jej refs nesu tuto
        #     polozku). Hladanie podla ULOZENEHO ID by pri recyklovanom ID
        #     pripojilo spotrebic na CUDZIU skrinku (Codex #382 kolo 1 P2).
        #     Ked povodny vlastnik zanikol, refs sa neprepisuju — aktualizuje sa
        #     len snapshot polozky a Kontrola hlasi sirotu dalej.
        new_entity = nil
        if !owner.nil? && target['kind'].to_s != KIND_JOB
          new_entity, nerr = resolve_target(model, target)
          return [nil, [nerr]] if nerr
        elsif op == 'rebind_model' && target['kind'].to_s != KIND_JOB && prev
          new_entity = prev[:inst]
        end

        [{ op: op, item_id: item_id, attrs: (attrs.is_a?(Hash) ? attrs : {}),
           snapshot: snapshot, category: category, owner: target,
           new_entity: new_entity, prev: prev, current: current,
           owner_changed: owner_changed?(prev_owner, target, owner, prev) }, []]
      end

      # Codex #382 kolo 2 (P2): `typ` z formulara pri operaciach, ktore menia
      # VLASTNIKA. Matica uz bezala nad starou kategoriou, takze novy typ by sa
      # ulozil BEZ kontroly — kategoria a vlastnik by sa rozisli.
      # -> hlaska | nil
      def type_attr_error(op, attrs)
        a = attrs.is_a?(Hash) ? attrs : {}
        raw = a.key?('typ') ? a['typ'] : a[:typ]
        return nil if raw.nil? || raw.to_s.strip.empty?

        return MSG_TYPE_WITH_OWNER if %w[move unbind rebind_model].include?(op.to_s)
        return nil unless op.to_s == 'create'
        # Neznamy kod sa NIKDY ticho nenahradi defaultom — inak by sa matica
        # overila nad „Iné" a polozka by sa ulozila ako nieco ine.
        BudgetStore.canon_appliance_type(raw).nil? ? MSG_UNKNOWN_TYPE : nil
      end

      # Ktore operacie sa vobec dotykaju `appliance_refs[]`? `patch` (cena,
      # nazov, priznak „dodáva zákazník") NIE — a preto ho NESMIE zastavit ani
      # zamknuty, ani zaniknuty vlastnik: cena polozky s mrtvym vlastnikom sa
      # musi dat opravit.
      def touches_refs?(op)
        %w[move unbind remove rebind_model].include?(op.to_s)
      end

      # Meni sa vlastnik? Kind + ID NESTACI (Codex #382 kolo 2 P2): ulozeny
      # vlastnik BEZ platnej vazby (`prev == nil` — entita zanikla alebo jej
      # refs polozku nenesu) NIE JE platny vlastnik, takze VYSLOVNE vybrany
      # fyzicky ciel je vtedy VZDY novy — aj keby mal to iste ID, ktore
      # recykloval po zaniknutej skrinke. Bez toho by sirota presla „bez zmeny"
      # a refs by sa nezapisali.
      def owner_changed?(prev_owner, target, explicit_owner = nil, prev = nil)
        return false if target.nil?
        return true if !explicit_owner.nil? && target['kind'].to_s != KIND_JOB && prev.nil?

        prev_owner['kind'].to_s != target['kind'].to_s ||
          prev_owner['id'].to_s != target['id'].to_s
      end

      # --- snapshot z katalogu ------------------------------------------------

      # `create`/`rebind_model` s `catalog_id` si vypytaju CERSTVY snapshot;
      # ostatne operacie pracuju nad UZ ULOZENYM (zakazka nezavisi od katalogu).
      def snapshot_for(op, catalog_id, current)
        id = catalog_id.to_s.strip
        if id.empty?
          return [nil, MSG_NEED_CATALOG] if op == 'rebind_model'

          return [current.is_a?(Hash) ? current['snapshot'] : nil, nil]
        end
        return [nil, nil] unless defined?(ApplianceCatalog)

        status, info = ApplianceCatalog.snapshot_for(id)
        return [info[:snapshot], nil] if status == :ok

        [nil, (info.is_a?(Hash) ? info[:message].to_s : '').empty? ? MSG_NEED_CATALOG : info[:message].to_s]
      end

      # Kategoria polozky. Model z katalogu je autorita; inak sa berie z toho,
      # co uz polozka ma, a az nakoniec z formulara (zalozenie bez katalogu).
      def category_of(_op, attrs, snapshot, current)
        snap = snapshot.is_a?(Hash) ? BudgetStore.canon_appliance_type(snapshot['category']) : nil
        return snap if snap

        a = attrs.is_a?(Hash) ? attrs : {}
        wanted = BudgetStore.canon_appliance_type(a['typ'] || a[:typ])
        cur = current.is_a?(Hash) ? BudgetStore.canon_appliance_type(current['typ']) : nil
        # Pri zmene vlastnika je autoritou to, co polozka UZ JE — formular by
        # inak mohol maticu obist prilozenym `typ`.
        cur || wanted || BudgetStore::DEFAULT_APPLIANCE_TYPE
      end

      # --- ciel vazby ---------------------------------------------------------

      # -> [owner Hash, nil] | [nil, hlaska]
      # `nil` owner = „nemen vlastnika" (pri `create` = `job`).
      def target_owner(op, owner, current, category)
        return [{ 'kind' => KIND_JOB }, nil] if op == 'unbind'

        if owner.nil?
          return [{ 'kind' => KIND_JOB }, nil] if op == 'create'

          existing = BudgetStore.owner_field(current ? current['owner'] : nil)
          # B12: vymena modelu za INU kategoriu sa ODMIETA, nie ticho odpaja —
          # pouzivatel ma najprv povedat, co sa ma stat s vazbou.
          if op == 'rebind_model' && existing['kind'] != KIND_JOB &&
             !allowed?(category, existing['kind'])
            return [nil, MSG_REBIND_CAT]
          end

          return [existing, nil]
        end

        h = owner.is_a?(Hash) ? stringify(owner) : {}
        kind = h['kind'].to_s
        return [nil, MSG_OWNER_GONE] unless OWNER_KINDS.include?(kind)
        return [{ 'kind' => KIND_JOB }, nil] if kind == KIND_JOB
        return [nil, matrix_message(category, kind)] unless allowed?(category, kind)

        id = h['id'].to_s.strip
        return [nil, MSG_OWNER_GONE] if id.empty?

        [{ 'kind' => kind, 'id' => id, 'pid' => h['pid'] }, nil]
      end

      def allowed?(category, kind)
        return true if kind.to_s == KIND_JOB

        Array(OWNER_MATRIX[category.to_s]).include?(kind.to_s)
      end

      def matrix_message(category, kind)
        label = BudgetStore::APPLIANCE_LABELS[category.to_s] || category.to_s
        "#{label} sa k tomuto vlastníkovi (#{kind_label(kind)}) priradiť nedá"
      end

      def kind_label(kind)
        { KIND_CABINET => 'skrinka', KIND_SLOT => 'slot umývačky',
          KIND_BOARD => 'doska', KIND_JOB => 'len zákazka' }[kind.to_s] || kind.to_s
      end

      # --- identita cieloveho kusu (B5) --------------------------------------

      # Instancia, ktora MA vsetky tri udaje naraz: `persistent_id`, vyrobne ID
      # aj DRUH. Recyklovane ID (`Ids.next_id` ID po zmazani znovu vydava) bez
      # zhody PID = ODMIETNUTIE, nie tiche priradenie k cudzej skrinke.
      # -> [instancia, nil] | [nil, hlaska]
      def resolve_target(model, owner)
        # Codex #382 kolo 2 (P2): FYZICKY ciel BEZ PID sa neprijima. ID sa
        # recykluju (`Ids.next_id`), takze bez PID by sa spotrebic pripojil na
        # entitu, ktora len zdedila cislo po zaniknutej skrinke. Ponuka
        # vlastnikov PID vzdy nesie — jeho absencia znamena zastaraly payload.
        pid = owner['pid']
        return [nil, MSG_OWNER_STALE] unless pid.is_a?(Numeric) ||
                                             (pid.is_a?(String) && pid.strip.match?(/\A\d+\z/))
        return [nil, MSG_OWNER_STALE] unless pid.to_i.positive?

        matches = instances_of(model, owner['kind'], owner['id'])
        return [nil, MSG_OWNER_GONE] if matches.empty?
        return [nil, MSG_OWNER_AMBIG] if matches.length > 1

        inst = matches.first
        return [nil, MSG_OWNER_GONE] unless pid.to_i == inst.persistent_id.to_i
        return [nil, MSG_OWNER_DETACH] if detached?(model, owner)
        return [nil, MSG_OWNER_NEWER] if newer?(owner['kind'], inst)

        [inst, nil]
      end

      # Vsetky top-level instancie daneho DRUHU a ID. `slot` a `cabinet` su
      # v modeli oba `kind: 'cabinet'` — rozlisuje ich typ v configu.
      def instances_of(model, kind, id)
        scan = Ids.top_level_scan(model)
        list = kind.to_s == KIND_BOARD ? scan['boards'] : scan['cabinets']
        Array(list).select do |inst|
          next false unless Store.get(inst, kind.to_s == KIND_BOARD ? 'id' : 'cabinet_id').to_s == id.to_s
          next true if kind.to_s == KIND_BOARD

          slot = cabinet_type(inst) == 'dishwasher'
          kind.to_s == KIND_SLOT ? slot : !slot
        end
      end

      def cabinet_type(inst)
        cfg = Store.config(inst)
        cfg.is_a?(Hash) ? cfg['type'].to_s : ''
      end

      # D-134: skrinka s ODPOJENYM dielcom sa neprestavuje (prestavba by
      # vyrobila duplicitne vyrobne zaznamy). `detached` je mapa ID -> pocet.
      def detached?(model, owner)
        return false if owner['kind'].to_s == KIND_BOARD

        Ids.top_level_scan(model)['detached'][owner['id'].to_s].to_i.positive?
      end

      def newer?(kind, inst)
        cfg = Store.config(inst)
        return false unless cfg.is_a?(Hash)

        if kind.to_s == KIND_BOARD
          defined?(BoardBuilder) && BoardBuilder.newer_config?(cfg)
        else
          defined?(CabinetBuilder) && CabinetBuilder.newer_config?(cfg)
        end
      end

      # --- predchadzajuci vlastnik (B8) --------------------------------------
      #
      # TRI STAVY:
      #   (a) PLATNY   — entita existuje a jej `appliance_refs[]` nesu tuto
      #                  polozku -> pri zmene sa PRESTAVI,
      #   (b) ZAMKNUTY — entita existuje, vazbu nesie, ale zapisat sa neda
      #                  (odpojeny dielec, novsia verzia) -> CELA operacia sa
      #                  odmietne (inak by polozka ukazovala inam a skrinka by
      #                  o rure dalej tvrdila, ze v nej stoji),
      #   (c) ZANIKNUTY — entita neexistuje alebo ID uz patri INEMU kusu, ktory
      #                  vazbu nenesie -> nedotkne sa NIC, polozka len zmeni
      #                  vlastnika (a Kontrola medzitym hlasila sirotu).
      #   (d) NEJEDNOZNACNY — v modeli ZIJE VIAC kusov s tym istym ulozenym ID
      #                  (poskodeny alebo importovany model). Vtedy sa NEDA
      #                  povedat, ktory vazbu drzi: ked ju drzi PRESNE JEDEN,
      #                  je to jednoznacne a pouzije sa on; inak sa CELA
      #                  operacia odmietne PRED otvorenim operacie — tichy
      #                  preskok by nechal stare refs visiet na oboch kusoch
      #                  (Codex #382 kolo 1 P2).
      # -> [{kind:, inst:} | nil, nil] | [nil, hlaska]
      def resolve_previous(model, prev_owner, item_id)
        kind = prev_owner['kind'].to_s
        return [nil, nil] if kind == KIND_JOB || item_id.to_s.empty?

        matches = instances_of(model, kind, prev_owner['id'].to_s)
        return [nil, nil] if matches.empty?

        carriers = matches.select { |i| carries_item?(i, prev_owner, item_id) }
        if matches.length > 1
          return [nil, prev_ambig_message(prev_owner)] unless carriers.length == 1
        elsif carriers.empty?
          return [nil, nil]
        end

        inst = carriers.first
        return [nil, MSG_PREV_LOCKED] if newer?(kind, inst) || detached?(model, prev_owner)

        [{ kind: kind, inst: inst }, nil]
      end

      def prev_ambig_message(prev_owner)
        "nejednoznačná identita vlastníka #{prev_owner['id']} — prestav skrinky"
      end

      def refs_of(inst)
        cfg = Store.config(inst)
        list = cfg.is_a?(Hash) ? cfg['appliance_refs'] : nil
        list.is_a?(Array) ? list.select { |r| r.is_a?(Hash) } : []
      end

      # === DOKAZ VAZBY — JEDNA funkcia pre cely engine =====================
      #
      # Codex #382 kolo 3 (P2): samotne UUID v `appliance_refs[]` dokazom NIE
      # JE. `cabinet_id` zdielaju skrinka aj SLOT (v modeli su oba
      # `kind: 'cabinet'`, rozlisuje ich typ v configu), takze skrinkovy zaznam
      # na entite, ktora je dnes slot s tym istym cislom, by sa tvaril ako
      # platna vazba — a mutacie vlastnika by ju potom nenasli (hladaju podla
      # DRUHU). Dokaz preto vyzaduje ZHODU DRUHU, ZHODU ID a uuid v refs.
      #
      # `entry` = `{ 'kind', 'id', 'refs' }` (zo zberu `Bom` alebo z entity cez
      # `owner_entry_for`), `owner` = ulozeny vlastnik polozky `{ 'kind', 'id' }`.
      def ref_matches?(entry, owner, item_id)
        return false unless entry.is_a?(Hash) && owner.is_a?(Hash)

        id = item_id.to_s
        return false if id.empty?
        return false unless entry['kind'].to_s == owner['kind'].to_s
        return false unless entry['id'].to_s == owner['id'].to_s

        Array(entry['refs']).any? { |r| r.is_a?(Hash) && r['item_id'].to_s == id }
      end

      # Zaznam vlastnika Z ENTITY v tvare, ktory cita `ref_matches?`. Druh aj
      # ID sa citaju z TOHO, CO V MODELI NAOZAJ JE — nikdy z toho, co tvrdi
      # polozka (inak by kontrola druhu nemala co porovnavat).
      def owner_entry_for(inst)
        kind = entity_kind(inst)
        key = kind == KIND_BOARD ? 'id' : 'cabinet_id'
        { 'kind' => kind, 'id' => Store.get(inst, key).to_s, 'refs' => refs_of(inst) }
      end

      def entity_kind(inst)
        return KIND_BOARD if Store.kind(inst).to_s == 'board'

        cabinet_type(inst) == 'dishwasher' ? KIND_SLOT : KIND_CABINET
      end

      # Nesie TATO entita vazbu na TUTO polozku? (Tenky most nad `ref_matches?`.)
      def carries_item?(inst, owner, item_id)
        ref_matches?(owner_entry_for(inst), owner, item_id)
      end

      def observer_idle?(model)
        return true unless defined?(ScaleWatch) && ScaleWatch.respond_to?(:flush_pending!)

        ScaleWatch.flush_pending!(model) == true
      end

      # === ZAPIS (JEDNA operacia) ==========================================

      def commit(model, plan)
        prev = plan[:prev]
        owner = plan[:owner] || { 'kind' => KIND_JOB }
        same_owner = same_target?(plan)

        # R-03/rebuild pravidlo: prestavba musi bezat v ABSOLUTNOM rame —
        # `rebuild_in_operation` to (na rozdiel od `rebuild`) nerobi (B7).
        #
        # Codex #382 kolo 3 (P2): rám sa zatvara LEN ked sa NAOZAJ prestavuje
        # skrinka alebo slot. `ensure_root_context` vyhodi pouzivatela
        # z komponentu, ktory prave edituje — a uprava ceny, priznaku ci vazby
        # na DOSKU (zapis configu bez prestavby) mu to spravit nesmie.
        CabinetBuilder.ensure_root_context(model) if defined?(CabinetBuilder) &&
                                                     rebuilds_cabinet?(plan, same_owner)

        item = nil
        geometry = false
        CabinetBuilder.guarded do
          model.start_operation(OP_NAME, true)
          begin
            item = write_item!(model, plan, owner)
            # Poradie je zamerne: NAJPRV sa vazba u povodneho vlastnika zrusi
            # a az potom zapise u noveho — inak by pri presune tam a spat mohli
            # dve skrinky naraz tvrdit, ze v nich stoji ta ista rura.
            geometry = true if !same_owner && drop_ref!(model, prev, plan[:item_id])
            # Zaznam u noveho vlastnika sa prepisuje LEN ked sa vlastnik zmenil
            # alebo ked sa vymenil MODEL (novy snapshot = nove rozmery). Uprava
            # ceny nad viazanou polozkou nema preco prestavat skrinku.
            geometry = true if rewrite_ref?(plan) && add_ref!(model, plan, owner, item)
            model.commit_operation
          rescue StandardError => e
            abort_safely(model)
            raise e
          end
        end
        { ok: true, errors: [], item: item, geometry_changed: geometry }
      rescue StandardError => e
        Engine.log_error(e, 'ApplianceBinding.commit') if defined?(Engine)
        failure([MSG_FAILED])
      end

      # Polozka rozpoctu. Bezi v UZ OTVORENEJ operacii (`in_operation: true`),
      # takze `BudgetStore` neotvara vlastnu — a vynimka z nej zhodi CELU
      # vazbu, nie len polovicu.
      def write_item!(model, plan, owner)
        attrs = client_attrs(plan[:attrs])
        case plan[:op]
        when 'remove'
          ok, errs = BudgetStore.remove_appliance!(model, plan[:item_id], in_operation: true)
          raise Array(errs).first.to_s unless ok

          return nil
        when 'create'
          attrs = attrs.merge(server_attrs(plan, owner))
          item, errs = BudgetStore.add_appliance!(model, attrs, trusted: true, in_operation: true)
          raise Array(errs).first.to_s if item.nil?

          return item
        end

        attrs = attrs.merge(server_attrs(plan, owner))
        item, errs = BudgetStore.update_appliance!(model, plan[:item_id], attrs,
                                                   trusted: true, in_operation: true)
        raise Array(errs).first.to_s if item.nil?

        item
      end

      # Z KLIENTA sa berie LEN to, co pouzivatel vypisal. `snapshot`, `owner`
      # ani `catalog_id` klient neposiela NIKDY (B3) — a keby poslal, tu
      # vypadnu.
      CLIENT_KEYS = %w[typ nazov dodavatel cena url cp_skupina customer_supplied].freeze

      def client_attrs(attrs)
        a = stringify(attrs.is_a?(Hash) ? attrs : {})
        a.select { |k, _| CLIENT_KEYS.include?(k) }
      end

      # Serverove polia: vlastnik vzdy, snapshot a `catalog_id` len ked ich
      # operacia naozaj meni (inak by sa `patch` snazil prepisat snapshot
      # hodnotou, ktora uz v polozke je).
      def server_attrs(plan, owner)
        out = { 'owner' => owner.reject { |k, _| k.to_s == 'pid' } }
        # Codex #382 kolo 2 (P2): pri ZALOZENI sa uklada PRESNE ta kategoria,
        # proti ktorej bezala matica — nie to, co prislo vo formulari. Legacy
        # kod je uz prevedeny, neznamy sa odmietol vyssie.
        out['typ'] = plan[:category] if plan[:op].to_s == 'create'
        return out unless %w[create rebind_model].include?(plan[:op])

        snap = plan[:snapshot]
        return out unless snap.is_a?(Hash)

        out.merge('snapshot' => snap, 'catalog_id' => snap['catalog_id'].to_s,
                  'typ' => plan[:category])
      end

      # --- zapis `appliance_refs[]` -------------------------------------------

      # Presun NA TOHO ISTEHO vlastnika (vymena modelu) sa nerobi dvomi
      # prestavbami: `add_ref!` zaznam s tym istym `item_id` prepisuje, takze
      # predchadzajuce odstranenie by bolo len prestavba navyse.
      def same_target?(plan)
        prev = plan[:prev]
        !plan[:owner_changed] && !plan[:new_entity].nil? && !prev.nil? && !prev[:inst].nil?
      end

      # Prestavi tato operacia SKRINKU alebo SLOT? (Doska sa zapisuje bez
      # prestavby, cisto rozpoctova uprava sa modelu nedotkne vobec.)
      # Rozhoduje o `ensure_root_context` — jedine miesto, ktore pouzivatelovi
      # zavrie otvoreny komponent.
      def rebuilds_cabinet?(plan, same_owner = nil)
        same_owner = same_target?(plan) if same_owner.nil?
        prev = plan[:prev]
        return true if !same_owner && prev && prev[:kind].to_s != KIND_BOARD

        owner = plan[:owner] || {}
        rewrite_ref?(plan) && !plan[:new_entity].nil? && owner['kind'].to_s != KIND_BOARD
      end

      # Ma sa zaznam u ciela (pre)pisat? Okrem zmeny vlastnika a vymeny modelu
      # aj vtedy, ked OVERENY ciel polozku EST NENESIE — presne to je pripad
      # siroty presunutej na entitu, ktora recyklovala ID po zaniknutom
      # vlastnikovi (Codex #382 kolo 2 P2). Ciel, ktory ju uz nesie, sa
      # zbytocne neprestavuje.
      def rewrite_ref?(plan)
        return true if plan[:owner_changed] == true
        return true if plan[:op].to_s == 'rebind_model'

        ent = plan[:new_entity]
        return false if ent.nil?

        !carries_item?(ent, plan[:owner] || {}, plan[:item_id])
      end

      # Odstranenie vazby u predchadzajuceho vlastnika. -> true = zapisalo sa
      def drop_ref!(model, prev, item_id)
        return false unless prev && prev[:inst]

        rest = refs_of(prev[:inst]).reject { |r| r['item_id'].to_s == item_id.to_s }
        write_refs!(model, prev[:kind], prev[:inst], rest)
      end

      # Zapis vazby u noveho vlastnika. Pri `bind` na UZ VIAZANEJ polozke sa
      # zaznam PREPISE (nove rozmery zo snapshotu), nikdy nezdvoji.
      def add_ref!(model, plan, owner, item)
        return false if owner['kind'].to_s == KIND_JOB || plan[:new_entity].nil?
        return false if item.nil?

        rec = ref_record(item)
        list = refs_of(plan[:new_entity]).reject { |r| r['item_id'].to_s == rec['item_id'] }
        list << rec
        write_refs!(model, owner['kind'].to_s, plan[:new_entity], list)
      end

      # KONTRAKT ZAZNAMU `appliance_refs[]` (cita ho S1-B2 telo slotu, S1-F box
      # chladnicky a S1-C ocakavania). CHYBAJUCE POLE = KLUC CHYBA — nikdy 0:
      # nula je rozmer, „nevieme" nie je.
      def ref_record(item)
        snap = item['snapshot'].is_a?(Hash) ? item['snapshot'] : {}
        dims = snap['dims'].is_a?(Hash) ? snap['dims'] : {}
        front = dims['front'].is_a?(Hash) ? dims['front'] : {}
        rec = { 'item_id' => item['id'].to_s,
                'category' => BudgetStore.canon_appliance_type(item['typ']).to_s }
        put_block(rec, 'body', dims['body'], %w[width height depth])
        put_block(rec, 'niche', dims['niche'],
                  %w[width_min width_max height_min height_max depth_min depth_max])
        put_block(rec, 'bands', front,
                  %w[door_bottom_offset door_lower door_gap door_upper])
        put_block(rec, 'furniture_doors', front['furniture_doors'],
                  %w[lower_min lower_max gap_ref])
        put_block(rec, 'install', dims['install'],
                  %w[dishwasher_class door_system hinge_side])
        at = snap['snapshot_at'].to_s
        rec['snapshot_at'] = at unless at.empty?
        rec
      end

      def put_block(out, key, src, fields)
        return out unless src.is_a?(Hash)

        block = {}
        fields.each do |f|
          v = src[f]
          next if v.nil?
          next if v.is_a?(String) && v.strip.empty?

          block[f] = v.is_a?(Numeric) ? v.to_f : v.to_s
        end
        out[key] = block unless block.empty?
        out
      end

      # JEDEN zapisovac oboch druhov vlastnika. Bezi v UZ OTVORENEJ operacii.
      # -> true = zapisalo sa (geometria sa zmenila len pri skrinke/slote)
      def write_refs!(model, kind, inst, refs)
        return false unless inst

        if kind.to_s == KIND_BOARD
          BoardBuilder.write_appliance_refs!(inst, refs)
          # Doska sa NEPRESTAVUJE (vazba jej geometriu nemeni), takze generacia
          # okna sa kvoli nej nedviha.
          false
        else
          CabinetBuilder.write_appliance_refs!(model, inst, refs)
          true
        end
      end

      # === PONUKA VLASTNIKOV (server je autorita) ==========================

      # Vsetky tri zoznamy naraz — payload rozpoctu ich nesie CELE a klient si
      # z nich podla matice sklada ponuku pre vybranu kategoriu. Ziadny druhy
      # kanal, ziadna fronta: ponuka patri k DOKUMENTU, ktory payload priniesol.
      def owner_options_map(model)
        scan = Ids.top_level_scan(model)
        detached = scan['detached'].is_a?(Hash) ? scan['detached'] : {}
        cabinets = []
        slots = []
        Array(scan['cabinets']).each do |inst|
          id = Store.get(inst, 'cabinet_id').to_s
          next if id.empty?
          # D-134 / R4: odpojene skrinky sa NEPONUKAJU — prestavba by z nich
          # vyrobila duplicitne vyrobne zaznamy.
          next if detached[id].to_i.positive?
          next if newer?(KIND_CABINET, inst)

          slot = cabinet_type(inst) == 'dishwasher'
          (slot ? slots : cabinets) << option(slot ? KIND_SLOT : KIND_CABINET, id, inst)
        end
        boards = Array(scan['boards']).filter_map do |inst|
          id = Store.get(inst, 'id').to_s
          next nil if id.empty? || newer?(KIND_BOARD, inst)

          option(KIND_BOARD, id, inst)
        end
        { KIND_CABINET => sort_options(cabinets), KIND_SLOT => sort_options(slots),
          KIND_BOARD => sort_options(boards) }
      rescue StandardError => e
        Engine.log_error(e, 'ApplianceBinding.owner_options_map') if defined?(Engine)
        { KIND_CABINET => [], KIND_SLOT => [], KIND_BOARD => [] }
      end

      # Ponuka pre KONKRETNU kategoriu (matica + „len zakazka" na konci).
      def owner_options(model, category)
        map = owner_options_map(model)
        out = Array(OWNER_MATRIX[category.to_s]).flat_map { |k| Array(map[k]) }
        out + [{ 'kind' => KIND_JOB, 'id' => '', 'pid' => nil, 'label' => JOB_LABEL }]
      end

      def option(kind, id, inst)
        { 'kind' => kind, 'id' => id, 'pid' => inst.persistent_id,
          'label' => "#{id}#{owner_name(inst)}" }
      end

      def owner_name(inst)
        name = Store.config(inst).is_a?(Hash) ? Store.config(inst)['name'].to_s.strip : ''
        name.empty? ? '' : " · #{name}"
      end

      def sort_options(list)
        list.sort_by { |o| [o['id'].to_s.length, o['id'].to_s] }
      end

      # --- pomocne -------------------------------------------------------------

      def stringify(value)
        case value
        when Hash then value.each_with_object({}) { |(k, v), out| out[k.to_s] = stringify(v) }
        when Array then value.map { |v| stringify(v) }
        else value
        end
      end

      def abort_safely(model)
        model.abort_operation
      rescue StandardError
        nil
      end
    end
  end
end
