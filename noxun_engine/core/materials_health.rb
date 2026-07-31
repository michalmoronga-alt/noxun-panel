# frozen_string_literal: true
# Noxun Engine — materialovy katalog: 2A-4a server hardening pred cutoverom
# (audit B1/B2/B4 + F5). Cast modulu Materials (rovnaky module_function vzor ako
# ostatne materials_*.rb) — pozri materials.rb pre prehlad.
#
# Tri celky:
#   1. STAV KATALOGU (B1+B4): assess_catalog! posudi subor a nastavi modulovy
#      stav :ok | :read_only. Pri :read_only su VSETKY katalogove mutacie
#      vypnute (guard priamo v zapisovej ceste write_unlocked + verejne CRUD
#      vstupy); CITANIE bezi dalej — model funguje.
#   2. OBNOVA Z .bak (F5): chybajuci/poskodeny primar s citatelnou .bak zalohou
#      sa NAJPRV bezpecne obnovi (atomicky .tmp+rename pod catalog lockom)
#      a az potom sa posudzuje schema.
#   3. ROLLBACK (B2): restore_pre_schema2! nasadi nemennu predmigracnu zalohu
#      ako primar (aktualny subor sa ODLOZI, nikdy nemaze) + zapise jednorazovy
#      supress flag migration_hold.json, ktory buduci boot auto-run (2A-4b)
#      preskoci a zmaze (2. restart uz migruje normalne).
#
# 2A-4b: OSTRY CUTOVER — boot_cutover! (nizsie) vola main.rb pri kazdom
# starte SketchUpu vo vlastnom chranenom bloku; restore_pre_schema2! spusta
# tlacidlo "Obnovit predmigracnu zalohu" v okne Materialy (read-only banner).

module Noxun
  module Engine
    module Materials
      # Jednorazovy supress flag migracie (B2) — zije vedla katalogu, takze
      # test_dir_override ho presmeruje spolu s nim.
      MIGRATION_HOLD_FILE = 'migration_hold.json'

      module_function

      # --- 2A-4b: boot cutover (audit O4 + F11) --------------------------------

      # Jednorazovy cutover katalogu pri starte SketchUpu. Vola ho VYHRADNE
      # main.rb vo vlastnom begin/rescue MIMO hlavnej inicializacie a NIKDY
      # nezobrazuje messagebox (O1) — vsetko ide do logu; pouzivatelsky stav
      # nesie okno Materialy (read-only banner / banner nepouzitelnych pasok).
      # Poradie (zavazne):
      #   1. consume_migration_hold! — hold po rollbacku (B2) migraciu RAZ
      #      preskoci (flag sa zmaze -> dalsi start uz migruje normalne);
      #      hold sa konzumuje IBA tu, nikdy pri beznom behu.
      #   2. assess_catalog! — obnova primaru z .bak (F5) + posudenie;
      #      :read_only konci (mutacie zamknute, banner ukaze dialog).
      #   3. marker < 2 -> migrate_to_schema2! (ostry):
      #      :ok = log suhrn (ZIADNY messagebox);
      #      :not_found/:empty = nic (seed flow — seedy su uz SCHEMA 2);
      #      :already = nic (druhy proces/okno uz zmigrovali);
      #      :undecidable = log dovodov, katalog OSTAVA legacy a plugin bezi
      #        dual-mode dalej — mutacie sa NEZAMYKAJU (standard 7.1:
      #        nerozhodnutelne = atomicky NO-OP, nie porucha);
      #      ine statusy = log + assess_catalog! znova (skutocne poskodenie
      #        konci :read_only; prechodny stav necha katalog legacy).
      # Vrati symbol vykonanej vetvy (diagnostika + testy).
      # GH #93 P2 (4. kolo): dovod, preco cutover NEprebehol, VIDITELNY pre
      # okno Materialy (banner) — nie len log. nil = ziadny problem.
      def cutover_issue
        @cutover_issue
      end

      def cutover_issue=(value)
        @cutover_issue = value
      end

      def boot_cutover!
        self.cutover_issue = nil
        if consume_migration_hold!
          if defined?(Engine)
            Engine.log('materialy: migracia jednorazovo potlacena po rollbacku (migration_hold zmazany)')
          end
          assess_catalog!
          return :hold
        end
        state, = assess_catalog!
        return :read_only if state == :read_only
        return :schema2 if catalog_schema_on_disk >= SCHEMA_GROUPS
        report = migrate_to_schema2!
        case report[:status]
        when :ok
          log_migration_summary(report)
          :migrated
        when :not_found, :already
          report[:status]
        when :empty
          # GH #93 P2 (4. kolo) + P1 (5. kolo): platny PRAZDNY legacy katalog sa
          # povysi na prazdny SCHEMA 2 — ale POD ZAMKOM s cerstvym re-readom
          # (CAS): iny proces mohol medzitym zapisat prvy zaznam a prazdny
          # payload by ho zahodil. Zmena pod nami = jeden retry migracie.
          promoted = with_catalog_lock do
            JsonFileStore.invalidate(path)
            fresh = parse_catalog_file(path)
            still_empty = fresh && Array(fresh['sheets']).empty? &&
                          Array(fresh['edges']).empty? && schema_of(fresh) < SCHEMA_GROUPS
            if still_empty
              write_unlocked('sheets' => [], 'edges' => [], 'schema' => SCHEMA_GROUPS) ? :ok : :fail
            else
              :changed
            end
          end
          case promoted
          when :ok
            Engine.log('materialy: prazdny katalog povyseny na SCHEMA 2') if defined?(Engine)
            reload!
            :empty_promoted
          when :changed
            retry_report = migrate_to_schema2!
            if retry_report[:status] == :ok
              log_migration_summary(retry_report)
              :migrated
            else
              # GH #93 P2 (10. kolo): neuspech RETRY musi byt viditelny rovnako
              # ako neuspech hlavneho behu (banner, nie len log).
              Engine.log("materialy: katalog sa pod bootom zmenil, opakovana migracia: #{retry_report[:status]}") if defined?(Engine)
              set_cutover_issue_for(retry_report)
              assess_catalog!
              retry_report[:status]
            end
          else
            self.cutover_issue = 'Prázdny katalóg sa nepodarilo povýšiť na nový formát — pozri log.'
            :empty
          end
        when :undecidable
          if defined?(Engine)
            Engine.log('materialy: migracia neprebehla — nerozhodnutelne polozky, katalog bezi dalej v povodnom formate:')
            report[:reasons].each { |r| Engine.log("  - #{r}") }
          end
          set_cutover_issue_for(report)
          :undecidable
        when :backup_corrupt
          if defined?(Engine)
            Engine.log('materialy: migracia zablokovana — poskodena predmigracna zaloha')
          end
          set_cutover_issue_for(report)
          assess_catalog!
          :backup_corrupt
        else
          if defined?(Engine)
            Engine.log("materialy: migracia zlyhala (#{report[:status]}) — katalog sa znovu posudi")
          end
          set_cutover_issue_for(report)
          assess_catalog!
          report[:status]
        end
      rescue StandardError => e
        # GH #93 P2 (6. kolo): necakany pad POCAS cutoveru (subor zmizol/
        # nahradeny inym procesom medzi assess a migraciou) — dovod MUSI byt
        # viditelny (banner) a stav katalogu sa znovu posudi; nie len log.
        Engine.log_error(e, 'Materials.boot_cutover!') if defined?(Engine)
        self.cutover_issue = "Prepnutie katalógu zlyhalo neočakávane (#{e.class}: #{e.message}) — pozri log a reštartuj SketchUp."
        begin
          assess_catalog!
        rescue StandardError
          nil
        end
        :error
      end

      # JEDNA autorita textov cutover_issue (hlavny beh AJ retry — GH #93
      # 10. kolo). Uspesne/neutralne statusy dovod NEnastavuju.
      def set_cutover_issue_for(report)
        case report[:status]
        when :ok, :already, :not_found, :empty, :empty_promoted, :hold, :schema2
          nil
        when :undecidable
          self.cutover_issue = 'Migrácia katalógu neprebehla — nerozhodnuteľné položky: '                                "#{Array(report[:reasons]).join(' · ')}. Oprav dáta a reštartuj SketchUp."
        when :backup_corrupt
          self.cutover_issue = 'Migrácia je zablokovaná: predmigračná záloha '                                "(#{pre_schema2_backup_path}) je poškodená a nepoužiteľná. "                                'Premenuj/odstráň ju a reštartuj SketchUp.'
        else
          self.cutover_issue = "Migrácia katalógu zlyhala (#{report[:status]}) — pozri log a reštartuj SketchUp."
        end
      end

      # Suhrn uspesnej migracie do logu (O1: ziadny modal pri boote).
      def log_migration_summary(report)
        return unless defined?(Engine)
        Engine.log('materialy: katalog zmigrovany na SCHEMA 2 — ' \
                   "#{report[:groups].length} skupin, " \
                   "zmazane: #{report[:deleted].empty? ? 'nic' : report[:deleted].join(', ')}, " \
                   "retyp: #{report[:retyped].empty? ? 'nic' : report[:retyped].join(', ')}; " \
                   "predmigracna zaloha: #{pre_schema2_backup_path}")
        report[:warnings].each { |w| Engine.log("  ! #{w}") }
      end

      # --- 2A-4b: banner nepouzitelnych pasok (audit O2) -----------------------

      # Pocet ABS pasok, ktore picker v SCHEMA 2 NIKDY nevyberie — bez struktury
      # a bez priznaku universal (prazdna struktura nie je zhoda, standard 7.5).
      # V SCHEMA 1 vzdy 0 (legacy picker strukturu nepozna — banner by len
      # strasil). JEDNA autorita banneru okna Materialy — JS pocet NIKDY
      # nepocita sam (server-side count v payloade).
      def unusable_edges_count
        return 0 if catalog_schema < SCHEMA_GROUPS
        edges.count { |a| a['structure'].to_s.strip.empty? && a['universal'] != true }
      end

      # --- stav katalogu (B1 + B4) --------------------------------------------

      # :ok (mutacie povolene) | :read_only (nudzovy rezim len na citanie).
      # Bez behu assess_catalog! je stav :ok — 2A-4a nic produkcne nevola.
      def catalog_state
        @catalog_state || :ok
      end

      # Dovod :read_only pre UI/log (nil pri :ok).
      def catalog_state_reason
        @catalog_state_reason
      end

      def catalog_read_only?
        catalog_state == :read_only
      end

      # Jednotna hlaska mutacnych guardov (rename/set/batch/...).
      def catalog_read_only_message
        reason = catalog_state_reason.to_s
        base = 'Katalóg materiálov je len na čítanie'
        reason.empty? ? "#{base}." : "#{base} — #{reason}."
      end

      # VYHRADNE testy + explicitna oprava: vrati stav na default :ok (rovnaky
      # vzor ako test_dir_override — stav je modulovy, sandbox ho musi upratat).
      def reset_catalog_state!
        @catalog_state = nil
        @catalog_state_reason = nil
        true
      end

      # Posudi subor katalogu a nastavi modulovy stav. Vrati [stav, dovod].
      # Matica (zadanie 2A-4a):
      #   subor + .bak chybaju                  -> :ok (panensky stav, seed smie)
      #   primar chyba, .bak citatelna (F5)     -> obnova z .bak, potom posudenie
      #   marker 1                              -> :ok (legacy dual-mode)
      #   marker 2..CURRENT + schema2_complete? -> :ok (2B-1: 3 = duplak polia)
      #   hybrid bez group_id / marker novsi    -> :read_only s dovodom
      #   poskodeny JSON (aj po pokuse o .bak)  -> :read_only s dovodom
      # Zlyhanie samotneho posudenia = :read_only (bezpecny smer).
      def assess_catalog!
        with_catalog_lock do
          state, reason = assess_catalog_unlocked
          @catalog_state = state
          @catalog_state_reason = reason
          if state == :read_only && defined?(Engine)
            Engine.log("materialy: katalog v rezime len na citanie — #{reason}")
          end
          [state, reason]
        end
      rescue StandardError => e
        Engine.log_error(e, 'Materials.assess_catalog!') if defined?(Engine)
        @catalog_state = :read_only
        @catalog_state_reason = "posúdenie katalógu zlyhalo (#{e.message})"
        [:read_only, @catalog_state_reason]
      end

      # Telo posudenia BEZ zamku — volat VYHRADNE zvnutra assess_catalog!.
      def assess_catalog_unlocked
        file = path
        bak = "#{file}.bak"
        unless File.exist?(file)
          if File.exist?(bak)
            ok, why = restore_primary_from_bak
            return [:read_only, "katalóg chýba a záloha .bak sa nedá použiť (#{why})"] unless ok
          elsif File.exist?(pre_schema2_backup_path)
            # Primar aj .bak prec, ale predmigracna zaloha existuje — seed by
            # obnovitelne data zamaskoval (B4). Nudzovy rezim do obnovy.
            return [:read_only,
                    'katalóg chýba, existuje predmigračná záloha — obnov ju (restore_pre_schema2!)']
          else
            return [:ok, nil]
          end
        end
        data = parse_catalog_file(file)
        if data.nil?
          if File.exist?(bak)
            preserve_corrupted_primary
            ok, why = restore_primary_from_bak
            data = parse_catalog_file(file) if ok
            return [:read_only, "katalóg je poškodený a záloha .bak sa nedá použiť (#{why})"] unless ok
          end
          if data.nil?
            return [:read_only, 'katalóg materiálov je poškodený (neplatný JSON) a použiteľná záloha neexistuje']
          end
        end
        assess_catalog_schema(data)
      end

      # Posudenie UZ NACITANYCH dat podla SCHEMA markera (B1: marker 2 nestaci —
      # hybrid bez group_id NESMIE bezat ako zapisovatelny katalog).
      def assess_catalog_schema(data)
        marker = schema_of(data)
        if marker < SCHEMA_GROUPS
          # GH #92 P1: platny JSON s NEVALIDNYM legacy tvarom ({}, sheets nie je
          # pole) NESMIE byt :ok — catalog by ho ticho nahradil seedmi a CRUD
          # by obnovitelny subor prepisal.
          return [:ok, nil] if legacy_catalog_object?(data)
          return [:read_only,
                  'katalóg má poškodený tvar (sheets/edges nie sú polia) — oprav súbor alebo obnov zálohu']
        end
        # 2B-1: marker 2 aj 3 (duplak) su zname schemy tejto verzie — obe stoja
        # na skupinovej identite, hybrid bez group_id je read-only pre obe.
        if marker <= SCHEMA_CURRENT
          unless schema2_complete?(data['sheets'], data['edges'])
            return [:read_only,
                    "katalóg má marker SCHEMA #{marker}, ale záznamy nie sú kompletné (hybrid bez group_id) — oprav súbor alebo obnov zálohu"]
          end
          # GH #94 P2: nekonzistentne duplak vazby (chybajuci zdroj, zly nasobic,
          # retaz) = read-only — buildery by ich interpretovali naslepo a odhad
          # platni by ucotoval plochu zlemu materialu.
          if (dup_err = duplak_integrity_error(data['sheets']))
            return [:read_only, "katalóg má nekonzistentné duplák väzby (#{dup_err}) — oprav súbor alebo obnov zálohu"]
          end
          return [:ok, nil]
        end
        [:read_only, "katalóg je v novšej schéme (#{marker}), než pozná táto verzia pluginu"]
      end

      # Subor -> Hash, alebo nil (chybajuci/necitatelny/nie objekt).
      def parse_catalog_file(file)
        data = JSON.parse(File.binread(file))
        data.is_a?(Hash) ? data : nil
      rescue StandardError
        nil
      end

      # --- atomicke nasadenie bajtov + obnova z .bak (F5) ----------------------

      # Atomicky zapis PRESNYCH bajtov (tmp + rename; vzor JsonFileStore.write,
      # ale bez JSON serializacie — obnovy nasadzuju bajt-presne kopie).
      def deploy_bytes(target, bytes)
        FileUtils.mkdir_p(File.dirname(target))
        tmp = "#{target}.tmp-#{Process.pid}-#{Thread.current.object_id}"
        File.binwrite(tmp, bytes)
        File.rename(tmp, target)
        true
      ensure
        begin
          File.delete(tmp) if tmp && File.exist?(tmp)
        rescue StandardError
          nil
        end
      end

      # Obnovi primarny subor zo zalohy .bak (F5) — volat POD catalog lockom.
      # Vrati [true, nil] alebo [false, dovod]. .bak sa NIKDY nemaze.
      def restore_primary_from_bak
        bak = "#{path}.bak"
        bytes = File.binread(bak)
        parsed = JSON.parse(bytes)
        return [false, '.bak nie je objekt katalógu'] unless parsed.is_a?(Hash)
        deploy_bytes(path, bytes)
        JsonFileStore.invalidate(path)
        Engine.log('materialy: primarny katalog obnoveny zo zalohy .bak') if defined?(Engine)
        [true, nil]
      rescue StandardError => e
        [false, e.message]
      end

      # Poskodene bajty primaru odlozi bokom PRED obnovou z .bak (best-effort —
      # torzo zapisu sa nezahodi bez stopy). Vrati cestu alebo nil.
      def preserve_corrupted_primary
        target = timestamped_free_path('materials.corrupted')
        deploy_bytes(target, File.binread(path))
        target
      rescue StandardError => e
        Engine.log_error(e, 'Materials.preserve_corrupted_primary') if defined?(Engine)
        nil
      end

      # Volna cesta <prefix>-<timestamp>.json v dir (kolizie -2/-3 ako unique_id).
      def timestamped_free_path(prefix)
        base = File.join(dir, "#{prefix}-#{Time.now.strftime('%Y%m%d-%H%M%S')}")
        candidate = "#{base}.json"
        n = 2
        while File.exist?(candidate)
          candidate = "#{base}-#{n}.json"
          n += 1
        end
        candidate
      end

      # Platny LEGACY katalogovy objekt (sheets+edges polia, marker < 2) —
      # JEDNA autorita pre ensure_pre_schema2_backup aj restore_pre_schema2!
      # (GH P2 5. kolo: null/{}/schema 2 payload nie je predmigracny stav).
      def legacy_catalog_object?(data)
        data.is_a?(Hash) && data['sheets'].is_a?(Array) && data['edges'].is_a?(Array) &&
          data['schema'].to_i < SCHEMA_GROUPS
      end

      # --- jednorazovy supress flag migracie (B2) ------------------------------

      def migration_hold_path
        File.join(dir, MIGRATION_HOLD_FILE)
      end

      # Tvar flagu: { "until_restart": true, "created": ..., "source": ... }.
      # Semantika: existencia suboru = hold (obsah je len diagnostika).
      def write_migration_hold!
        payload = { 'until_restart' => true,
                    'created' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
                    'source' => 'restore_pre_schema2' }
        deploy_bytes(migration_hold_path, JSON.pretty_generate(payload))
        true
      rescue StandardError => e
        Engine.log_error(e, 'Materials.write_migration_hold!') if defined?(Engine)
        false
      end

      def migration_hold?
        File.exist?(migration_hold_path)
      end

      # Boot 2A-4b: check-and-consume v JEDNOM kroku. Vrati true, ak hold
      # existoval (boot migraciu PRESKOCI) a flag zmaze — dalsi start uz
      # migruje normalne (jednorazovost). Nepodarene mazanie = hold drzi
      # (bezpecny smer: radsej preskocena migracia nez necakana).
      def consume_migration_hold!
        return false unless File.exist?(migration_hold_path)
        File.delete(migration_hold_path)
        true
      rescue StandardError => e
        Engine.log_error(e, 'Materials.consume_migration_hold!') if defined?(Engine)
        true
      end

      # --- rollback na predmigracny stav (B2) ----------------------------------

      # Otestovany recovery postup: pod catalog lockom overi zalohu
      # materials.pre-schema-2.json (rovnaka validacia ako
      # ensure_pre_schema2_backup), zapise hold flag, ODLOZI aktualny
      # materials.json ako materials.rolledback-<timestamp>.json (nemaze!),
      # atomicky nasadi zalohu ako primar, invaliduje cache a znovu posudi stav.
      # Vrati [true, report] alebo [false, dovod] (bez zasahu do katalogu).
      #
      # Poradie krokov je zamerne: hold flag sa pise PRED nasadenim primaru —
      # keby nasadenie preslo a flag nie, buduci boot (2A-4b) by cerstvo
      # obnovenu schemu 1 HNED zmigroval spat (presne pasca auditu B2).
      # Opacne zlyhanie (flag ano, nasadenie nie) = jedna preskocena migracia
      # pri dalsom starte — bezpecny smer.
      def restore_pre_schema2!
        with_catalog_lock do
          backup = pre_schema2_backup_path
          unless File.exist?(backup)
            return [false, 'Predmigračná záloha (materials.pre-schema-2.json) neexistuje.']
          end
          bytes = File.binread(backup)
          data = begin
            JSON.parse(bytes)
          rescue StandardError
            nil
          end
          unless legacy_catalog_object?(data)
            return [false, 'Predmigračná záloha nie je platný legacy katalóg — obnova sa nespustí.']
          end
          unless write_migration_hold!
            return [false, 'Zápis poistky migration_hold.json zlyhal — obnova sa nespustila (katalóg nezmenený).']
          end
          # GH #92 P1 (2. kolo): PORADIE = najprv VSETKY pripravne kroky (kopia
          # aktualneho primaru, karantena starej .bak, legacy .bak), primar sa
          # vymiena AZ POSLEDNY. Pad kdekolvek pred tym necha migrovany stav
          # neporuseny (hold flag bez rollbacku = 1 preskocena migracia — bezpecne);
          # pad PO vymene primaru uz nema stale SCHEMA 2 .bak, ktora by rollback
          # neskor potichu zvratila.
          rolled = nil
          if File.exist?(path)
            rolled = timestamped_free_path('materials.rolledback')
            deploy_bytes(rolled, File.binread(path))
          end
          bak = "#{path}.bak"
          if File.exist?(bak)
            deploy_bytes(timestamped_free_path('materials.json.bak.pre-rollback'), File.binread(bak))
          end
          deploy_bytes(bak, bytes)
          deploy_bytes(path, bytes)
          JsonFileStore.invalidate(path)
          assess_catalog! # reentrantny zamok; obnoveny legacy katalog = :ok
          if defined?(Engine)
            Engine.log("materialy: katalog obnoveny z predmigracnej zalohy (odlozeny: #{rolled || 'nic'})")
          end
          [true, { 'rolledback' => rolled, 'hold_flag' => migration_hold_path,
                   'schema' => schema_of(data), 'state' => catalog_state.to_s }]
        end
      rescue StandardError => e
        Engine.log_error(e, 'Materials.restore_pre_schema2!') if defined?(Engine)
        [false, "Obnova predmigračnej zálohy zlyhala: #{e.message}"]
      end
    end
  end
end
