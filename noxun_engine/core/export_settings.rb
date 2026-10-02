# frozen_string_literal: true
# Noxun Engine — H7a (C-07, R-38): NASTAVENIA EXPORTU v jadre.
#
# Subor `%APPDATA%\NOXUN\Engine\vepo_settings.json` je nastavenie POCITACA
# (nie zakazky): nazvy zakaziek (`project_names`, kluc = normalizovana cesta
# .skp, neulozeny model `guid:<DocKey token>`), prepinac „18 + 36 spolu"
# (`merge_18_36`) a posledny priecinok exportu (`last_dir`). Do H7a zil
# v `ui/production_core.rb`; okno Studia aj styri exporty (VEPO, CSV kovania,
# XLSX rozpoctu, XLSX ponuky) ho odteraz volaju ODTIALTO — jedna autorita,
# ziadne delegaty (dve mena jednej veci by stuby testov strazili staru cestu).
#
# Ziadny zapis do modelu, ziadny krok Spat. Pri nacitani sa na subor nesiaha.
require 'json'
require 'digest' # H7a: obsahovy podpis suborov (ADOPT_RETRY)

module Noxun
  module Engine
    module ExportSettings
      FILE = 'vepo_settings.json'
      # Nazov, ktorym sa vystupy pomenuju, kym model nie je ulozeny a nazov
      # zakazky nie je zadany (slovo ide do mien suborov — ostava).
      DEFAULT_PROJECT_NAME = 'projekt'

      module_function

      # --- VEPO nastavenia (V0.5 C) ---------------------------------------

      def path
        File.join(Materials.dir, FILE)
      end

      # --- H7a / R-38: tvar suboru, zapisova brana a vysledok zapisu ----------
      #
      # Subor nastaveni exportu je rovnaka rodina ako subory H9/R-37 (pravidla
      # ABS a kovania, dodavatel): POSKODENY primar (necitatelny alebo zleho
      # TVARU) s DOBROU zalohou sa cita zo ZALOHY a NEZAPISUJE sa — zapis by
      # primar ticho prepisal obsahom spred poskodenia a pri zlom tvare navyse
      # znicil dobru zalohu. Kazdy zapis vracia `[status, reason]` a okno
      # Studia zlyhanie povie cerveno (ziadne zelene „uložené" nad zlyhanim).
      #
      # Dovody (`%s` = cesta suboru) — veta napravy radi PREMENOVAT, nie
      # zmazat: premenovany subor plugin necita (cita presnu cestu), ostane na
      # rucnu obnovu a plugin pokracuje zo zalohy.
      DEGRADED_REASON = 'nastavenia exportu sú poškodené — číta sa záloha, zápisy sú vypnuté ' \
                        '(oprav súbor %s alebo ho premenuj, napr. na vepo_settings.poskodeny.json — ' \
                        'plugin potom pokračuje zo zálohy; spravidla sa stratí len posledná zmena, ' \
                        'ak súbor medzitým zapisovala staršia verzia pluginu, záloha môže byť staršia)'
      # `%s` = subor, ktory sa naozaj neda precitat: primar, a ked primar
      # chyba, jeho `.bak` (predrecenzia H7a P3).
      UNREADABLE_REASON = 'súbor nastavení exportu sa nedá prečítať (oprav súbor %s alebo ho premenuj; ' \
                          'ak je poškodená aj záloha .bak, premenuj aj ju — plugin potom začne ' \
                          's predvolenými nastaveniami a bez uložených názvov zákaziek)'
      FAILED_REASON = 'zápis sa nepodaril (súbor je zamknutý alebo disk nedostupný)'

      # Obsah suboru nie je objekt (dnesna sprava; `IOError` = I/O chyba
      # citania pre zapis, nie poskodeny JSON).
      NotObject = Class.new(IOError)

      # Posledny odmietnuty dovod — log LEN pri zmene stavu (vzor H9). Konstanta
      # (nie `@ivar`) ako `SESSION_KEY_BRIDGE` — modul nedrzi okenny stav.
      LAST_BLOCK = { reason: nil }

      # Ocakavany TVAR dokumentu — len kontajnery (hodnoty posudzuje dnesna
      # normalizacia). `{}` plugin nikdy nezapisal (od V0.5 C je kazdy zapis
      # zlucenie s neprazdnymi `attrs`), takze prazdny objekt je poskodenie.
      def doc_shape_ok?(doc)
        doc.is_a?(Hash) && !doc.empty? &&
          (!doc.key?(PROJECT_NAMES_KEY) || doc[PROJECT_NAMES_KEY].is_a?(Hash))
      end

      # Predikat pre `JsonFileStore` (vola ho VYHRADNE primitivum).
      def shape_check
        method(:doc_shape_ok?)
      end

      # CITANIE pre okno aj exporty (lenive, nikdy nevyhodi — audit F9). Zly
      # tvar s DOBROU zalohou = zaloha (H7a/R-38; dnes by `{}` dalo meno suboru
      # a zlucenie 18 + 36 proti nastaveniu v zalohe). Bez dobrej zalohy
      # (`InvalidShape`) presne dnesna cesta: `read` (necitatelny primar ->
      # `.bak`), nie-objekt -> `{}`.
      def read
        file = path
        return {} unless JsonFileStore.available?(file)
        data = begin
          JsonFileStore.read_valid(file, shape: shape_check)
        rescue JsonFileStore::InvalidShape
          JsonFileStore.read(file)
        end
        data.is_a?(Hash) ? data : {}
      rescue StandardError
        {}
      end

      # CITANIE pre ZAPIS — tu sa chyba prehltnut NESMIE (1b-6c, audit #1).
      # Lenive `{}` z NEPRECITATELNEHO suboru by sa zlucilo s novymi `attrs` a
      # zapis by zmazal `project_names`, `merge_18_36` aj `last_dir` — teda
      # presne tie zaznamy, ktore ma zamok chranit. Chybajuci subor (ani `.bak`)
      # je legitimny prazdny stav; existujuci, ale neprecitatelny ci nie-Hash
      # obsah je CHYBA: vyleti do rescue zapisovych dveri a NEZAPISE sa nic.
      # (`JsonFileStore` si zalohu skusi sam — sem sa dostane az ked padnu obe.)
      # Volat LEN pod zamkom v `update` (degradaciu riesi brana pred nim).
      def read_for_write
        file = path
        return {} unless JsonFileStore.available?(file)
        data = JsonFileStore.read(file)
        raise NotObject, "#{FILE}: obsah nie je objekt" unless data.is_a?(Hash)

        data
      end

      # H7a / R-38: JEDINA zapisova brana -> [state, reason], state je :ok |
      # :degraded. Vzdy CERSTVO nad DISKOM: `reload!` primaru AJ zalohy (cache
      # `….bak|nofallback` plni `read_valid` — bez nej by echo po odmietnutom
      # zapise do 1 s citalo staru zalohu). Chybajuci primar s dobrou zalohou
      # degradovany NIE JE (obnova). Vynimky (I/O, `ShapeCheckError`) sa
      # NECHYTAJU — volajuci = `:failed` (fail-closed). Nezapisuje, neloguje.
      def write_gate
        file = path
        JsonFileStore.reload!(file)
        JsonFileStore.reload!("#{file}.bak")
        return [:degraded, format(DEGRADED_REASON, file)] if JsonFileStore.degraded?(file, shape: shape_check)

        [:ok, '']
      end

      # Jeden riadok logu pri ODMIETNUTI, len pri zmene dovodu; uspech stav
      # nuluje. Vracia vysledok bez zmeny (`next note_block(...)`).
      def note_block(result)
        status, reason = result
        if %i[blocked unreadable].include?(status)
          Engine.log("export settings: zapis odmietnuty — #{reason}") if LAST_BLOCK[:reason] != reason
          LAST_BLOCK[:reason] = reason
        elsif written?(status)
          LAST_BLOCK[:reason] = nil
        end
        result
      end

      # JEDINY prevod vysledku na „zapis prebehol" (`:unchanged` = netreba nic
      # zapisat). Pole `[status, reason]` je v Ruby VZDY pravdive — volajuci
      # rozhoduje cez `case`/`==`/`written?`, nikdy pravdivostou.
      def written?(status)
        status == :ok || status == :unchanged
      end

      # --- 1b-6c: JEDINE DVERE k zapisu do vepo_settings.json ---------------
      #
      # Subor je nastavenie POCITACA a ma SIESTICH zapisovatelov (`merge_18_36`,
      # 4x `last_dir`, mapa `project_names`). Dve instancie SketchUpu zdielaju
      # jeden `%APPDATA%`, takze read-modify-write nad ODTLACKOM vedel prepisat
      # to, co medzitym zapisala tá druhá — a pri mape nazvov islo o cely
      # zaznam zakazky. `JsonFileStore` riesi atomicitu (tmp+rename, `.bak`),
      # NIE subeh.
      #
      # Preto kazdy zapis ide cez tieto dvere: MEDZIPROCESOVY zamok
      # (`Materials.with_catalog_lock` — jediny sidecar `.lock` nad TYM ISTYM
      # priecinkom, reentrantny, kriticke sekcie su v ms; dva samostatne zamky
      # by len vyrobili poradie a s nim riziko zaseknutia) + citanie suboru
      # NANOVO vnutri zamku (`reload!` zhodi sekundovu cache, bez ktorej by
      # cerstvy zapis druhej instancie nebolo vidiet). Blok dostane CERSTVE
      # nastavenia a vrati hash na zlucenie; `nil` znamena „netreba nic zapisat"
      # (bez zbytocneho pretocenia `.bak`).
      #
      # Cela zamknuta uprava je v rescue (kolo 3 #243): aj zlyhanie `.lock`
      # (prava profilu, I/O) je len zalogovany `:failed`, nikdy vynimka do okna
      # ci exportu. Kontext logu nesie FAZU (lock/gate/read/block/write), aby
      # sa chyba disku nezliala s chybou v odovzdanom bloku.
      #
      # H7a / R-38 -> [status, reason], status je :ok | :unchanged | :blocked |
      # :unreadable | :failed. Poradie zamok -> BRANA -> strikne citanie ->
      # blok -> zapis je zavazne (brana pod TYM ISTYM zamkom nad diskom, takze
      # poskodenie druhou instanciou po nasom citani zapis zastavi):
      #   :blocked    — poskodeny primar + dobra zaloha (brana), nic sa nepise;
      #   :unreadable — necitatelny / nie-objekt BEZ dobrej zalohy (dnes ticho);
      #   :failed     — zamok, I/O, blok alebo samotny zapis zlyhal.
      # Zapis nesie predikat tvaru (POZICNE — pasca Ruby 3, H9): zly primar
      # sa nikdy neotoci do dobrej `.bak`.
      #
      # `sign: true` (len prenos nazvu, `adopt_session_name`): pri odmietnuti
      # podla OBSAHU (:blocked/:unreadable) prida tretiu polozku — obsahovy
      # podpis suborov spocitany este POD zamkom (predrecenzia H7a P3: po
      # uvolneni zamku by ho mohol posunut zapis druhej instancie a pamat
      # pokusov by zablokovala aj stav, ktory sa uz zmenil).
      def update(sign: false)
        phase = 'lock'
        Materials.with_catalog_lock do
          phase = 'gate'
          state, why = write_gate
          next rejected(note_block([:blocked, why]), sign) unless state == :ok

          phase = 'read'
          fresh = begin
            read_for_write
          rescue JSON::ParserError, NotObject
            next rejected(note_block([:unreadable, format(UNREADABLE_REASON, unreadable_file)]), sign)
          end
          phase = 'block'
          attrs = yield(fresh)
          next note_block([:unchanged, '']) if attrs.nil?

          phase = 'write'
          doc = self_repair(fresh.merge(attrs))
          raise ArgumentError, "#{FILE}: zluceny dokument nema tvar nastaveni" unless doc_shape_ok?(doc)

          JsonFileStore.write(path, doc, shape_check)
          note_block([:ok, ''])
        end
      rescue StandardError => e
        Engine.log_error(e, "ExportSettings.update(#{phase})")
        [:failed, FAILED_REASON]
      end

      # SAMOOPRAVA objektu bez dobrej zalohy (matica R-A2, D3; review #456 P2):
      # neplatny kontajner `project_names` (pole, retazec, null …) nemoze niest
      # ziadny platny nazov zakazky (mapa je len objekt), takze ho kazdy uspesny
      # zapis nahradi prazdnou mapou a zaloguje to. Skalarny zapis (18 + 36,
      # posledny priecinok) ho opravi TU; zapis MAPY (nazov, prenos nazvu) ho
      # opravi uz v `update_project_names` (blok dostane prazdnu mapu a vrati
      # platnu), takze sem dorazi dokument dobreho tvaru — log rovnakej vety
      # ide preto odtial (`log_repair`). Platna mapa sa nikdy nemeni. Vysledok
      # `update` tak vzdy spĺňa `doc_shape_ok?` (inak by `:ok` hlasilo opravu,
      # ktora nenastala).
      def self_repair(doc)
        return doc unless doc.is_a?(Hash) && doc.key?(PROJECT_NAMES_KEY) && !doc[PROJECT_NAMES_KEY].is_a?(Hash)

        log_repair(doc[PROJECT_NAMES_KEY])
        doc.merge(PROJECT_NAMES_KEY => {})
      end

      # Jedna veta logu samoopravy pre obe cesty (skalarny zapis aj zapis mapy).
      def log_repair(bad)
        Engine.log("export settings: neplatny #{PROJECT_NAMES_KEY} (#{bad.class}) " \
                   'nahradeny prazdnou mapou — samooprava suboru bez zalohy')
      end

      # Odmietnutie podla obsahu, volitelne s podpisom suborov (volat POD zamkom).
      def rejected(result, sign)
        sign ? result + [adopt_signature] : result
      end

      # Ktory subor sa naozaj neda precitat: primar; ked chyba, jeho `.bak`.
      def unreadable_file
        file = path
        File.exist?(file) ? file : "#{file}.bak"
      end

      # Zapis nezavislych klucov (`last_dir`, `merge_18_36`) — hodnota nezavisi
      # od toho, co v subore uz je, takze staci zlucenie nad cerstvym citanim.
      # Vracia `[status, reason]` (H7a; predtym TRUE/FALSE — review #243 P2-1:
      # migracia nazvu zakazky musi vediet, ci zapis naozaj presiel).
      #
      # MAPU NAZVOV tadeto zapisat NEDA (1b-6c, audit #4): odovzdany odtlacok
      # mapy by cerstvu mapu prepisal cely a zamok by chranil len top-level
      # zlucenie. Na to su `update_project_names` — a strazi to aj guard test.
      def save(attrs)
        # Kluc sa porovnava v RETAZCOVEJ podobe (review #248): `:project_names`
        # by presiel a JSON by z neho spravil ten isty kluc — pri parsovani by
        # vyhral druhy vyskyt a odtlacok mapy by cerstvu mapu aj tak prepisal.
        if attrs.is_a?(Hash) && attrs.keys.any? { |k| k.to_s == PROJECT_NAMES_KEY }
          Engine.log_error(ArgumentError.new("#{PROJECT_NAMES_KEY} sa zapisuje len cez update_project_names"),
                           'ExportSettings.save')
          return [:failed, FAILED_REASON]
        end

        update { attrs }
      end

      # Cerstve nastavenia pre EXPORT (1b-6c, audit #3): sekundova cache
      # `JsonFileStore` by dala nazov zakazky alebo prepinac 18/36 spred zmeny
      # v druhej instancii — a hotovy CSV/XLSX sa dalsim citanim uz nezahoji.
      # Zamok sa tu zamerne NEBERIE: exportna cesta otvara MODALNE okno vyberu
      # suboru a drzat cez neho medziprocesovy zamok by druhu instanciu blokoval
      # dovtedy, kym pouzivatel kliká. Roztrhnute citanie nehrozi (tmp+rename),
      # riziko je len zastaralost — a tu zhodi prave `reload!`. H7a: aj cache
      # ZALOHY (`read_valid` cita pri zlom tvare `.bak` s vlastnym klucom).
      # Pamat pokusov prenosu nazvu (`ADOPT_RETRY`) sa tu NEMAZE — obsahovy
      # podpis suborov zmenu rozpozna sam (audit H7 §17 C3).
      def refresh
        JsonFileStore.reload!(path)
        JsonFileStore.reload!("#{path}.bak")
        true
      rescue StandardError
        false
      end

      # Posledny priecinok exportu — SUROVA hodnota (ako ju exporty citali
      # doteraz; typ kontroluje VEPO cesta — zjednotenie je H17).
      def last_dir
        read['last_dir']
      end

      # Vysledok exporty zamerne IGNORUJU (zlyhany `last_dir` nema zastavit
      # hotovy export; dovod je v logu `update`).
      def save_last_dir(dir)
        save('last_dir' => dir)
      end

      # Default nazvu projektu z ULOZENEHO suboru (audit F10 — nie z titulku).
      def default_project_name(model)
        p = model.path.to_s
        p.empty? ? DEFAULT_PROJECT_NAME : File.basename(p, '.*')
      end

      # --- ST-1a: nazov projektu je SERVEROVA autorita (audit #1) -----------
      #
      # Do ST-1a zil nazov projektu v INPUTE (vtedy este) okna Vyroba a kazdy
      # export si ho bral z DOM (`data['project']`). Odkedy su klienti DVAJA,
      # je to pasca: kto prepise nazov v jednom okne, exportoval by z druheho
      # pod inym menom — dva vystupy tej istej zakazky by sa volali rozne.
      #
      # Preto nazov zije v `vepo_settings.json` pod mapou `project_names`.
      # Je to nastavenie POCITACA, presne ako `last_dir`/`merge_18_36`: ziadny
      # zapis do modelu, ziadny krok Spat. VSETKY styri exporty (VEPO, CSV
      # kovania, XLSX rozpoctu, XLSX cenovej ponuky) citaju `project_name(model)`
      # — z klienta uz nazov neprichadza.
      #
      # KLUC JE CESTA SUBORU, NIE `model.guid` (review PR #193 P1). SketchUp
      # dokumentuje, ze guid sa MENI po kazdom ulozeni modelu — na guid kluci by
      # sa nazov po Ctrl+S ticho stratil (a v subore by rastli mrtve zaznamy).
      # Cesta sa normalizuje (Windows je case-insensitive, oddelovace sa
      # zjednocuju). NEULOZENY model cestu nema, takze dostane NAHRADNY kluc
      # `guid:<guid>` — ten plati len v ramci sedenia; pri prvom zapise s
      # platnou cestou sa zaznam ZMIGRUJE na cestu a guid zaznam zanikne.
      PROJECT_NAMES_KEY = 'project_names'
      PROJECT_NAME_MAX = 120 # strop proti nezmyslu z JS (nazov ide do mena suboru)
      SESSION_KEY_PREFIX = 'guid:'

      # --- 1b-6a: most medzi klucom sedenia a cestou ------------------------
      #
      # Ctrl+S urobi DVE veci NARAZ: model dostane cestu a SketchUp mu ZMENI
      # guid. Nazov zadany pred prvym ulozenim preto lezi pod klucom
      # `guid:<STARY guid>` a z ulozeneho modelu sa uz neda odvodit — zalozka
      # „skus kluc sedenia" (ST-1a) hlada `guid:<NOVY guid>` a najde prazdno.
      # Dosledok bol tichy VYROBNY prusvih: po prvom ulozeni sa VEPO, CSV
      # kovania aj oba XLSX pomenovali podla .skp suboru namiesto zakazky.
      #
      # Most je preto v PAMATI PROCESU: object_id modelu => posledny kluc
      # sedenia, pod ktorym sa nazov zapisal. Identita sa NEVERI slepo — zaznam
      # plati len ked ide o TEN ISTY Ruby objekt (`equal?` je cisto porovnanie
      # referencii, nesiaha do SketchUpu ani na zatvorenom dokumente); Windows
      # SketchUp pri File > New/Open model ZNIci a vytvori novy, takze cudzia
      # zakazka rozrobeny nazov zdedit nemoze. Pri prvom pouziti sa most
      # SPOTREBUJE a zaznam sa ZMIGRUJE na cestu, takze prezije aj restart.
      #
      # Preco to NIE JE okenny stav: nie je to stav okna ani medzivysledok
      # vypoctu, ale udaj o DOKUMENTE, ktory sa z modelu po ulozeni
      # preukazatelne precitat neda. Obe okna z neho citaju TO ISTE, takze si
      # ho nemaju ako prepisat.
      SESSION_KEY_BRIDGE = {}
      SESSION_BRIDGE_MAX = 32 # strop proti rastu pri mnohych rozrobenych oknach

      def project_names
        v = read[PROJECT_NAMES_KEY]
        v.is_a?(Hash) ? v : {}
      end

      # Atomicka uprava MAPY nazvov (1b-6c). Blok dostane CERSTVU mapu precitanu
      # vnutri zamku a vrati upravenu; `nil` = netreba nic zapisat. Bez toho by
      # sa mapa menila nad odtlackom a zapis jednej instancie by zmazal zakazku
      # pomenovanu v druhej. Vracia `[status, reason]` (H7a) — pri inom nez
      # zapisanom vysledku (`written?`) si volajuci MUSI nechat most na dalsi pokus.
      def update_project_names(sign: false)
        update(sign: sign) do |settings|
          names = settings[PROJECT_NAMES_KEY]
          # Samooprava neplatneho kontajnera (matica R-A2) — log len ked blok
          # naozaj nieco zapise (`nil` = ziadny zapis, ziadna oprava).
          bad = settings.key?(PROJECT_NAMES_KEY) && !names.is_a?(Hash)
          names = names.is_a?(Hash) ? names.dup : {}
          fresh = yield(names)
          log_repair(settings[PROJECT_NAMES_KEY]) if bad && !fresh.nil?
          fresh.nil? ? nil : { PROJECT_NAMES_KEY => fresh }
        end
      end

      # Stabilna identita zakazky pre nastavenia POCITACA. Windows nerozlisuje
      # velkost pismen ani smer lomitka, takze „C:\Zakazky\Klinika.skp" a
      # „c:/zakazky/klinika.skp" musia dat TEN ISTY kluc.
      def normalize_project_path(path)
        path.to_s.strip.tr('\\', '/').downcase
      end

      # Token dokumentu pre kluc sedenia — IDENTICKY s `ProductionCore.model_guid`
      # (kluc `guid:` sa presunom nesmie zmenit, inak by sa stratili nazvy
      # rozrobenych zakaziek). 1d/R-02b: DocKey token (Model#guid sa meni pri
      # kazdom ulozeni).
      def doc_token(model)
        model ? DocKey.key(model) : ''
      rescue StandardError
        ''
      end

      # Nahradny kluc neulozeneho modelu — plati LEN v ramci sedenia. Prefix
      # ho odlisuje od cesty, aby sa dal pri prvom zapise s platnou cestou
      # zmigrovat. Od 1d/R-02b je hodnotou DocKey token (drzi cez ulozenie,
      # prve ulozenie aj Save As a rotuje az pri vymene dokumentu) — most
      # SESSION_KEY_BRIDGE vyssie tym stratil svoj hlavny scenar (guid uz prve
      # ulozenie neprepise), ale ostava: kryje starsie zaznamy v subore.
      def project_session_key(model)
        guid = doc_token(model)
        guid.empty? ? '' : "#{SESSION_KEY_PREFIX}#{guid}"
      end

      # Kluc je nahradny (sedenie), nie cesta. Normalizovana cesta zacina
      # pismenom disku alebo lomitkom — s prefixom sa nikdy nezhodne.
      def session_key?(key)
        key.to_s.start_with?(SESSION_KEY_PREFIX)
      end

      def remember_session_key(model, key)
        return unless model && session_key?(key)

        SESSION_KEY_BRIDGE.delete(model.object_id)
        SESSION_KEY_BRIDGE[model.object_id] = { ref: model, key: key.to_s }
        SESSION_KEY_BRIDGE.shift while SESSION_KEY_BRIDGE.length > SESSION_BRIDGE_MAX
      end

      def forget_session_key(model)
        SESSION_KEY_BRIDGE.delete(model.object_id) if model
      end

      # Kluc sedenia, pod ktorym sa nazov TOHTO dokumentu naposledy zapisal,
      # kym este nemal cestu. Prazdny retazec = nic sa nepamata.
      #
      # `equal?` SAMO O SEBE NESTACI (1d/R-02b, review delty #267 P2-GLM):
      # Windows drzi jeden dokument na proces a pri File > New/Open smie
      # `Model` objekt RECYKLOVAT, takze `equal?` by nad recyklovanym objektom
      # vratilo true a novy Untitled by zdedil kluc sedenia — a s nim NAZOV
      # ZAKAZKY predosleho dokumentu, ktory by odisiel do VEPO/CSV/XLSX.
      # Zaznam preto zahadzuje `Engine.on_document_replaced` (oba AppObservery)
      # este PRED notifikaciou okien; `equal?` tu ostava ako druha poistka
      # proti recyklacii `object_id` po GC.
      def remembered_session_key(model)
        entry = model ? SESSION_KEY_BRIDGE[model.object_id] : nil
        return '' unless entry.is_a?(Hash) && entry[:ref].equal?(model)

        entry[:key].to_s
      end

      # Vsetky nahradne kluce, pod ktorymi moze lezat nazov TEJTO zakazky:
      # aktualny guid (ked sa este nezmenil) + zapamatany kluc spred ulozenia.
      def session_keys_for(model)
        [project_session_key(model), remembered_session_key(model)]
          .map(&:to_s).reject(&:empty?).uniq
      end

      # Primarny kluc: cesta, ak zakazka existuje na disku; inak sedenie.
      def project_key(model)
        path = normalize_project_path(model.respond_to?(:path) ? model.path : nil)
        path.empty? ? project_session_key(model) : path
      end

      # Ulozeny nazov, inak default zo suboru zakazky.
      #
      # Ked uz zakazka MA cestu, ale zaznam pod nou este nie je, skusia sa
      # nahradne kluce sedenia — to je presne stav „pomenoval som neulozeny
      # model a potom ho ulozil". Bez tejto zalozky by sa nazov pri Ctrl+S
      # stratil a vyrobne subory by niesli meno .skp suboru.
      def project_name(model)
        key = project_key(model)
        map = project_names
        # Kluce sedenia sa spotrebuju pri PRVOM citani s platnou cestou — aj
        # ked cesta uz nazov ma (review #243 P2-2). Ked migracia bezala, vracia
        # CERSTVU platnu hodnotu kluca (1b-6c): odtlacok spred zamku uz mohol
        # byt zastaraly a export by sa pomenoval podla .skp suboru napriek tomu,
        # ze v subore je spravny nazov (kolo 3 #243).
        adopted = adopt_session_name(model, key, map)
        saved = adopted.nil? ? map[key] : adopted
        s = saved.to_s.strip
        s.empty? ? default_project_name(model) : s
      end

      # Prechod NEULOZENY→ULOZENY (1b-6a). Kluce sedenia sa pri prvom citani s
      # platnou cestou VZDY spotrebuju:
      #   * ked cesta este nazov NEMA, presunie sa nan nazov spod kluca sedenia
      #     (bez toho by nazov zil len do konca sedenia a restart by ho zmazal);
      #   * ked uz nazov MA, ma PREDNOST a zaznamy sedenia sa len upracu —
      #     inak by rozrobeny nazov neskor sadol na uplne inu cestu (Ulozit ako)
      #     a mrtvy `guid:` kluc by v subore ostal navzdy (review #243 P2-2).
      # Vracia adoptovany nazov, inak nil.
      #
      # Zapisuje sa VYHRADNE do nastaveni pocitaca (vepo_settings.json), do
      # modelu nikdy; ked nie je co upratat, nezapisuje sa vobec. Most sa
      # zahadzuje AZ ked zapis naozaj presiel (review #243 P2-1) — zlyhany zapis
      # (zamknuty subor, plny disk) by inak zmazal jedinu stopu na stary kluc a
      # nazov by sa po dalsom refreshi aj tak stratil.
      def adopt_session_name(model, key, map)
        return nil if key.to_s.empty? || session_key?(key)

        # LACNA PREDBEZNA OTAZKA nad uz precitanou mapou: nemat co upratat je
        # bezny stav KAZDEHO citania a to sa nesmie platit zamkom.
        aliases = session_keys_for(model)
        return nil if aliases.none? { |k| map.key?(k) } && remembered_session_key(model).empty?

        # PREDZAMKOVY FALLBACK (1b-6c, audit #2): ked sa `.lock` nepodari vziat,
        # blok pod zamkom sa NIKDY nevykona — bez fallbacku by vsetky styri
        # exporty dostali meno .skp suboru namiesto zakazky. Cerstva hodnota
        # fallback prepise az vtedy, ked blok naozaj bezal. H7a: v poskodenom
        # stave je `map` zo ZALOHY (`read`), takze nazov plati dalej.
        name = effective_project_name(map, key, aliases)
        # H7a (audit H7 §15 A5, §16 B4, B6): po ODMIETNUTI branou (poskodeny
        # subor) sa prenos neopakuje, kym sa OBSAH suborov nezmeni — inak by
        # kazde citanie bralo zamok a kazde nove parsovanie poskodeneho primaru
        # pridalo riadok fallback logu `JsonFileStore`.
        retry_key = adopt_retry_key(key, aliases)
        sig = ADOPT_RETRY[retry_key]
        return(name.empty? ? nil : name) if sig && sig == adopt_signature

        fresh = nil
        status, _why, sig_now = update_project_names(sign: true) do |names|
          stale = aliases.select { |k| names.key?(k) }
          # Rozhodnutie (ktory kluc sedenia nesie nazov, ci ma cesta prednost)
          # patri DOVNUTRA zamku — nad zastaranym odtlackom by mohlo prepisat
          # nazov, ktory medzitym zapisala druha instancia.
          fresh = effective_project_name(names, key, stale)
          next nil if stale.empty? # niet co upratat = ziadny zapis

          stale.each { |k| names.delete(k) }
          names[key] = fresh unless fresh.empty? || fresh == default_project_name(model)
          names
        end
        name = fresh unless fresh.nil?
        note_adopt_attempt(retry_key, status, sig_now)
        # Most sa zahadzuje LEN po zapisanom vysledku (review #243 P2-1, H7a).
        forget_session_key(model) if written?(status)
        name.empty? ? nil : name
      end

      # --- H7a: pamat odmietnutych prenosov nazvu --------------------------
      #
      # Kluc = [cesta, zmrazena kopia aliasov] (bez odkazu na model), hodnota
      # = OBSAHOVY podpis suborov v case odmietnutia. Podpis je SHA1 bajtov
      # primaru a `.bak` (nie mtime + velkost — oprava rovnakej dlzky s
      # vratenym casom by sa inak nerozpoznala, sonda H7d L4). Zapamata sa LEN
      # odmietnutie podla OBSAHU (`:blocked`, `:unreadable`); prechodna chyba
      # (`:failed` — zamok, disk) sa skusa hned pri dalsom citani ako doteraz.
      # Podpis sa pocita POD zamkom (`update(sign: true)`). Zaznam zanikne
      # pri uspesnom prenose alebo vytlaceni stropom — `forget_session_key`
      # ho nemaze (kluc nenesie model; pri vymene dokumentu nova zakazka ma
      # iny kluc sedenia, takze stary zaznam sa jej netyka).
      ADOPT_RETRY = {}
      ADOPT_RETRY_MAX = 32

      def adopt_retry_key(key, aliases)
        [key, aliases.dup.sort.freeze].freeze
      end

      def note_adopt_attempt(retry_key, status, signature = nil)
        if %i[blocked unreadable].include?(status) && signature
          ADOPT_RETRY.delete(retry_key)
          ADOPT_RETRY[retry_key] = signature
          ADOPT_RETRY.shift while ADOPT_RETRY.length > ADOPT_RETRY_MAX
        else
          ADOPT_RETRY.delete(retry_key)
        end
      end

      def adopt_signature
        file = path
        [file_digest(file), file_digest("#{file}.bak")]
      end

      def file_digest(file)
        Digest::SHA1.hexdigest(File.binread(file))
      rescue Errno::ENOENT
        '-'
      rescue StandardError
        # Necitatelny subor = nezname — novy pokus (radsej log navyse nez
        # zaseknuty prenos).
        "?#{Time.now.to_f}"
      end

      # H7a (audit H7 §15 A1): nazov zakazky caka na prenos z kluca sedenia na
      # cestu — model uz cestu ma, pod cestou nazov nie je, ale pod niektorym
      # klucom sedenia ano. Nastava, ked prenos odmietla brana (poskodeny
      # subor pri prvom ulozeni): nazov plati LEN do zatvorenia SketchUpu
      # (most v pamati). Cista funkcia, nezapisuje. Pyta sa ju az kod, ktory
      # uz zavolal `project_name` (ten prenos skusil).
      #
      # Predrecenzia H7a P3: pravdive LEN ked posledny pokus odmietol OBSAH
      # suboru (zaznam v `ADOPT_RETRY`). Prechodne zlyhanie pri ZDRAVOM subore
      # (zamok, plny disk = `:failed`) nie je poskodenie — veta „premenuj
      # poskodeny subor" by navadzala premenovat zdravy subor; prenos sa tam
      # zopakuje pri dalsom citani sam.
      def name_pending?(model)
        key = project_key(model)
        return false if key.empty? || session_key?(key)

        aliases = session_keys_for(model)
        return false unless ADOPT_RETRY.key?(adopt_retry_key(key, aliases))

        map = project_names
        return false unless map[key].to_s.strip.empty?

        aliases.any? { |k| !map[k].to_s.strip.empty? }
      rescue StandardError
        false
      end

      # Nazov, ktory pre KLUC plati nad danou mapou: zaznam na ceste ma
      # PREDNOST (rozrobeny nazov ho nikdy neprepise), inak sa adoptuje nazov
      # spod prveho neprazdneho kluca sedenia.
      def effective_project_name(map, key, aliases)
        own = map[key].to_s.strip
        return own unless own.empty?

        hit = aliases.find { |k| !map[k].to_s.strip.empty? }
        hit ? map[hit].to_s.strip : ''
      end

      # Zapis nazvu. Prazdna hodnota (aj hodnota zhodna s defaultom) zaznam
      # ZMAZE — pomenovanie sa vtedy vrati na nazov .skp suboru a premenovanie
      # suboru sa v okne prejavi samo. Vracia `[status, reason]` (H7a; predtym
      # platny nazov — ten cita volajuci cez `project_name(model)`).
      #
      # MIGRACIA: ked zakazka uz ma cestu, zaznamy pod klucmi sedenia (aktualny
      # guid AJ zapamatany kluc spred ulozenia) sa pri kazdom zapise ZAHADZUJU
      # — ich ulohu prebrala cesta a guid by po dalsom ulozeni aj tak prestal
      # sediet. Pri NEULOZENOM modeli sa naopak kluc sedenia zapamata, aby ho
      # citanie po Ctrl+S nasiel (1b-6a).
      def save_project_name(model, name)
        key = project_key(model)
        return [:failed, FAILED_REASON] if key.empty?

        s = clean_project_name(name)
        stored = !(s.empty? || s == default_project_name(model))
        aliases = session_keys_for(model)
        # Cita a zapisuje POD ZAMKOM nad CERSTVOU mapou (1b-6c) — inak by zapis
        # z jednej instancie zmazal zakazku pomenovanu v druhej.
        result = update_project_names do |map|
          aliases.each { |k| map.delete(k) unless k == key }
          if stored
            map[key] = s
          else
            map.delete(key)
          end
          map
        end
        if stored && session_key?(key)
          remember_session_key(model, key)
        elsif written?(result.first)
          # Most sa zahadzuje len po USPESNOM zapise (review #243 P2-1) —
          # inak by po zlyhanom zapise zmizla jedina stopa na stary kluc.
          forget_session_key(model)
        end
        result
      end

      # „18 a 36 mm do jedneho suboru" — GLOBALNE nastavenie (audit #1: ostava
      # take, ake bolo). Default je zapnute.
      def merge_18_36
        read['merge_18_36'] != false
      end

      # -> [status, reason] (H7a; predtym hodnota po zapise — vysledok zapisu
      # sa zahadzoval a okno hlasilo zeleno aj zlyhanie).
      def save_merge_18_36(value)
        save('merge_18_36' => (value == true))
      end

      # --- H7b: jedna normalizacia nazvu, zdroj nazvu a kontrola `expect` ----
      #
      # Orez + strop 120 znakov — PRESNE to, co sa uklada (`save_project_name`).
      def clean_project_name(name)
        name.to_s.strip[0, PROJECT_NAME_MAX].to_s.strip
      end

      # Audit H7 §17 C2: JEDINA normalizacia nazvu pre porovnanie aj pre okno.
      # Prazdne = predvoleny nazov (meno suboru, inak „projekt") — to iste
      # pravidlo, akym `project_name` cita a `save_project_name` maze zaznam.
      # Payload okna posiela nazov UZ normalizovany a export porovnava obe
      # strany touto funkciou, takze rucne zapisany zaznam dlhsi ako 120 znakov
      # nevyrobi trvaly falosny nesulad. (Meno suboru exportu sa nemeni — ide
      # z `project_name`, parita H7a.)
      def normalize_project_name(model, name)
        s = clean_project_name(name)
        s.empty? ? default_project_name(model) : s
      end

      # Odkial je nazov, pod ktorym exporty odidu (R-B1, cista funkcia):
      # 'set' = zadany pouzivatelom · 'file' = meno ulozeneho suboru ·
      # 'default' = „projekt" (neulozeny model bez nazvu). Ulozeny nazov sa
      # predvolenemu nikdy nerovna (zapis taky zaznam zmaze), takze rovnost
      # s predvolenym znamena „nazov nie je zadany".
      def name_source(model, name)
        return 'set' unless name.to_s == default_project_name(model)

        (model.respond_to?(:path) ? model.path.to_s : '').empty? ? 'default' : 'file'
      rescue StandardError
        'set' # neznamy zdroj = bez bodky a bez vety (nic sa neblokuje)
      end

      # Audit H7 §16 B2 a §17 C1: kazde exportne volanie okna nesie
      # `expect {project, merge, source}` = co pouzivatel VIDI (hlavicka a jej
      # zdroj, prepinac). Export sa spusti LEN ked sa to zhoduje s ulozenou
      # pravdou — zlyhany zapis nazvu (zamok, poskodeny subor) ani zmena
      # z druheho okna tak nikdy nevyrobi subor pod inym nazvom, nez okno
      # ukazovalo. Bezstavove: nic necaka, nesulad = veta a klik znova.
      # Chybajuci alebo neplatny `expect` (stary klient) = FAIL-CLOSED.
      #
      # Spresnenie §17 C1 (predrecenzia H7b P2): AUTOMATICKY -> AUTOMATICKY
      # nazov sa toleruje. Ked okno ukazovalo automaticky nazov („projekt"
      # alebo meno suboru) a plati opat automaticky (najcastejsie: novy model
      # sa medzitym ULOZIL — Ctrl+S nepushuje okno), pouzivatel nic nezadal
      # a niet co stratit: export prebehne pod skutocnym menom a stav to
      # povie (`note`). Ked je na ktorejkolvek strane ZADANY nazov ('set')
      # a mena sa lisia -> odmietnutie neutralnou pravdivou vetou („Okno
      # ukazovalo …, plati …").
      # 18 + 36 sa porovnava len vo VEPO (`merge: true`), vzdy prisne — inde
      # vystup nemeni a zlyhany zapis prepinaca nesmie blokovat XLSX ani CSV.
      #
      # -> { stop: nil | veta, note: '' | veta na koniec statusu,
      #      project: overeny nazov (pre export), merge: overene 18 + 36 }
      EXPECT_STALE = 'Okno je zastarané — zatvor a otvor Štúdio a klikni znova.'
      EXPECT_FAILED = 'Export sa nespustil — nastavenia exportu sa nepodarilo overiť, skús znova.'
      SOURCES = %w[set file default].freeze
      AUTO_SOURCES = %w[file default].freeze

      def expect_valid?(expect)
        expect.is_a?(Hash) && expect['project'].is_a?(String) && [true, false].include?(expect['merge']) &&
          SOURCES.include?(expect['source'])
      end

      def expect_check(model, expect, merge: false)
        return { stop: EXPECT_STALE, note: '', project: nil, merge: nil } unless expect_valid?(expect)

        project = project_name(model)
        now = merge_18_36
        stored = normalize_project_name(model, project)
        source = name_source(model, project)
        out = []
        note = ''
        # Veta odmietnutia hovori LEN fakt (co okno ukazovalo a co plati) — nie
        # preco: rozdiel moze byt zlyhany zapis (ten povie cerveno uz okno) aj
        # zmena z druheho okna (slepa kontrola oprav H7b P3).
        shown = normalize_project_name(model, expect['project'])
        if shown != stored
          if AUTO_SOURCES.include?(expect['source']) && AUTO_SOURCES.include?(source)
            # predvoleny „projekt" povie veta `default_name_note` exportu
            note = source == 'file' ? " · Zákazka: #{stored} (podľa súboru)" : ''
          else
            out << "Okno ukazovalo „#{shown}\", platí „#{stored}\". Export sa nespustil, " \
                   'skontroluj názov a klikni znova.'
          end
        end
        if merge && expect['merge'] != now
          out << "Okno ukazovalo 18 + 36: #{expect['merge'] ? 'zapnuté' : 'vypnuté'}, " \
                 "platí: #{now ? 'zapnuté' : 'vypnuté'}. Export sa nespustil, skontroluj nastavenie a klikni znova."
        end
        { stop: out.empty? ? nil : out.join(' '), note: note, project: project, merge: now }
      rescue StandardError => e
        Engine.log_error(e, 'ExportSettings.expect_check')
        { stop: EXPECT_FAILED, note: '', project: nil, merge: nil }
      end

      # Len veta zastavenia (nil = export smie pokracovat).
      def expect_mismatch(model, expect, merge: false)
        expect_check(model, expect, merge: merge)[:stop]
      end
    end
  end
end
