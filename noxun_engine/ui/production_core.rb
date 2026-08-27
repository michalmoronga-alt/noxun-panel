# frozen_string_literal: true
# Noxun Engine — ST-1a PR A: ZDIELANE CISTE JADRO vystupov zakazky.
#
# Preco vlastny modul: kusovnik, supisy platni/ABS a VEPO export sa v davke
# ST-1a stahovali zo starsieho okna Vyroba do noveho okna Studio. Obe okna
# museli citat TIE ISTE cisla — dve kopie tych istych pomocnikov by sa casom
# rozisli a rozdiel by sa prejavil az na vyrobnom vystupe.
#
# ŠT-1c PR B3: okno Vyroba zaniklo. Modul tym neprestal davat zmysel — cita ho
# okno Studio, rail Inspectora aj vsetky styri exporty, takze ostava JEDINOU
# autoritou cisel, guardov a slovenskych textov.
#
# ZAVAZNE PRAVIDLO MODULU: ziadny OKENNY STAV. Sem NEPATRI `@dialog`,
# `@generation` ani `@pending_*` — to su veci konkretneho okna. Vsetko tu je
# cista funkcia alebo citanie katalogu/modelu: rovnaky vstup = rovnaky vystup,
# ziadny zapis do modelu, ziadny undo krok (jedina vynimka je sekcia Rozpocet,
# ktora zapisuje VEDOME: 1 mutacia = 1 krok Spat).
module Noxun
  module Engine
    module ProductionCore
      VEPO_SETTINGS_FILE = 'vepo_settings.json'

      module_function

      # --- VEPO nastavenia (V0.5 C) ---------------------------------------

      def vepo_settings_path
        File.join(Materials.dir, VEPO_SETTINGS_FILE)
      end

      # CITANIE pre okno: fallback na defaulty pri poskodenom subore (audit F9)
      # — export nikdy nesmie zablokovat okno kvoli nastaveniam.
      def vepo_settings
        path = vepo_settings_path
        return {} unless JsonFileStore.available?(path)
        data = JsonFileStore.read(path)
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
      def vepo_settings_for_write
        path = vepo_settings_path
        return {} unless JsonFileStore.available?(path)
        data = JsonFileStore.read(path)
        raise IOError, "#{VEPO_SETTINGS_FILE}: obsah nie je objekt" unless data.is_a?(Hash)

        data
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
      # (prava profilu, I/O) je len zalogovany `false`, nikdy vynimka do okna
      # ci exportu. Kontext logu nesie FAZU (lock/read/block/write), aby sa
      # chyba disku nezliala s chybou v odovzdanom bloku.
      def update_vepo_settings
        phase = 'lock'
        Materials.with_catalog_lock do
          phase = 'read'
          JsonFileStore.reload!(vepo_settings_path)
          fresh = vepo_settings_for_write
          phase = 'block'
          attrs = yield(fresh)
          next true if attrs.nil?

          phase = 'write'
          JsonFileStore.write(vepo_settings_path, fresh.merge(attrs))
          true
        end
      rescue StandardError => e
        Engine.log_error(e, "ProductionCore.update_vepo_settings(#{phase})")
        false
      end

      # Zapis nezavislych klucov (`last_dir`, `merge_18_36`) — hodnota nezavisi
      # od toho, co v subore uz je, takze staci zlucenie nad cerstvym citanim.
      # Vracia TRUE/FALSE (review #243 P2-1): migracia nazvu zakazky musi
      # vediet, ci zapis naozaj presiel — pri zamknutom subore alebo plnom
      # disku sa nesmie zahodit jedina stopa na stary kluc.
      #
      # MAPU NAZVOV tadeto zapisat NEDA (1b-6c, audit #4): odovzdany odtlacok
      # mapy by cerstvu mapu prepisal cely a zamok by chranil len top-level
      # zlucenie. Na to su `update_project_names` — a strazi to aj guard test.
      def save_vepo_settings(attrs)
        # Kluc sa porovnava v RETAZCOVEJ podobe (review #248): `:project_names`
        # by presiel a JSON by z neho spravil ten isty kluc — pri parsovani by
        # vyhral druhy vyskyt a odtlacok mapy by cerstvu mapu aj tak prepisal.
        if attrs.is_a?(Hash) && attrs.keys.any? { |k| k.to_s == PROJECT_NAMES_KEY }
          Engine.log_error(ArgumentError.new("#{PROJECT_NAMES_KEY} sa zapisuje len cez update_project_names"),
                           'ProductionCore.save_vepo_settings')
          return false
        end

        update_vepo_settings { attrs }
      end

      # Cerstve nastavenia pre EXPORT (1b-6c, audit #3): sekundova cache
      # `JsonFileStore` by dala nazov zakazky alebo prepinac 18/36 spred zmeny
      # v druhej instancii — a hotovy CSV/XLSX sa dalsim citanim uz nezahoji.
      # Zamok sa tu zamerne NEBERIE: exportna cesta otvara MODALNE okno vyberu
      # suboru a drzat cez neho medziprocesovy zamok by druhu instanciu blokoval
      # dovtedy, kym pouzivatel kliká. Roztrhnute citanie nehrozi (tmp+rename),
      # riziko je len zastaralost — a tu zhodi prave `reload!`.
      def refresh_vepo_settings
        JsonFileStore.reload!(vepo_settings_path)
        true
      rescue StandardError
        false
      end

      # --- VEPO labely materialov ------------------------------------------

      # VEPO stlpec material: dekor + typ (hrubka je vlastny stlpec); fallback
      # family, fallback material_id. Tvar mapy definuje audit F7.
      #
      # 2A-4b (audit F8 + GH #93 P1): 'label' je EXPORTNY label — grouping +
      # nazov suboru + CSV stlpec. INVARIANT nie je "decor+typ", ale STABILNY
      # TEXT pre te iste realne data: migracia rozdelila "K009 PW" na cislo
      # "K009" + strukturu "PW", takze exportny label MUSI byt zlozeny
      # decor+structure+typ — zmigrovany zaznam da presne povodny text
      # ("K009 PW DTDL") a dve struktury toho isteho cisla sa NEZLEJU do
      # jedneho VEPO bucketu. Legacy zaznam (bez struktury) = dnesny tvar.
      # Strazi zlaty test (legacy fixture == zmigrovana fixture, bajtovo).
      # decor_name ide VYHRADNE do 'display' (zobrazovaci/LOG label).
      # GH #93 P1 (2. kolo): label sklada AJ decor_name — legacy "W1000 ST9
      # Biela" sa migruje na cislo+strukturu+NAZOV, takze bez nazvu by sa
      # export zmenil ("W1000 ST9 DTDL" != "W1000 ST9 Biela DTDL"). Kolizia
      # labelu MEDZI roznymi skupinami (rovnake cislo+struktura+typ dvoch
      # vyrobcov — len SCHEMA 2 stav bez legacy precedensu) dostava prefix
      # vyrobcu, aby sa buckety nezliali.
      def vepo_materials
        labeled = Materials.sheets.map { |s| [s, vepo_base_label(s)] }
        # 1. kolo: kolizia medzi skupinami -> prefix vyrobcu.
        labeled = vepo_disambiguate(labeled) do |s, l|
          [s['manufacturer'].to_s.strip, l].reject(&:empty?).join(' ')
        end
        # GH #93 P2 (3. kolo): aj PO prefixe mozu dve skupiny TOHO ISTEHO
        # vyrobcu zlozit rovnaky text ("K009 PW"+"" vs "K009"+"PW") — druhe
        # kolo pridava stabilny skupinovy sufix, aby sa VEPO buckety nezliali.
        labeled = vepo_disambiguate(labeled) do |s, l|
          "#{l} [#{vepo_group_key(s)}]"
        end
        # GH #93 P1 (4. kolo): kolizia VNUTRI skupiny — dva PD varianty s inym
        # formatom (4100×600 vs 4100×920) maju rovnaky label aj group_key;
        # format je sucast identity PD variantu, do labelu ide pri kolizii.
        labeled = vepo_disambiguate_variants(labeled)
        # Finalna poistka (GH #93 5. kolo): ak by po vsetkych kolach ostala
        # kolizia, rozhodne material_id — bucket sa NIKDY nesmie zliat.
        labeled = vepo_disambiguate(labeled) { |s, l| "#{l} [#{s['material_id']}]" }
        labeled.each_with_object({}) do |(s, l), out|
          entry = { 'label' => l }
          # GH #93 P2 (9. kolo): ked label nesie technicke disambiguatory
          # (vyrobca/skupina/format/ID), LOG ukazuje LUDSKY zaklad cez
          # 'display' — inak by display_labels cesta VepoExportu nikdy nezila.
          human = vepo_base_label(s)
          entry['display'] = human unless human.empty? || human == l
          out[s['material_id']] = entry
        end
      end

      # Ludsky zaklad labelu (cislo struktura nazov typ; fallback family/id) —
      # zdiela ho kompozicia exportneho labelu aj 'display' pre LOG.
      def vepo_base_label(s)
        # 2B-2: rub zasteny patri do labelu VZDY (obchodna identita produktu
        # — Demos vzor "Zastena K551/K552"; bez neho by sa dva ruby zliali).
        back = s['back_decor'].to_s.strip
        back = "/#{[back, s['back_structure'].to_s.strip].reject(&:empty?).join(' ')}" unless back.empty?
        label = [s['decor'], s['structure'], s['decor_name'], s['type'], back]
                .map { |v| v.to_s.strip }.reject(&:empty?).join(' ')
        label = s['family'].to_s.strip if label.empty?
        label = s['material_id'].to_s if label.empty?
        label
      end

      # Kolizia labelu medzi VARIANTMI (rovnaka skupina): zaznamu s formatom
      # v identite (PD + ZASTENA — 2B-2 flag F10) sa prida "D×S" (cele mm) —
      # identita zakazuje uplne duplicity, takze vysledok je unikatny.
      def vepo_disambiguate_variants(labeled)
        by_label = labeled.group_by { |(_s, l)| l }
        labeled.map do |(s, l)|
          next [s, l] unless by_label[l].length > 1 && Materials.format_in_identity?(s['type'])
          fmt = Materials.size_key(s['sheet_size'])
          # GH #93 P1 (5. kolo): format su mm Floaty — .round by zlial 4100.1
          # a 4100.2; %g drzi normalizovanu presnost size_key (round(2)) a
          # rozne kluce daju VZDY rozny text.
          fmt ? [s, "#{l} #{fmt.map { |x| format('%g', x) }.join('×')}"] : [s, l]
        end
      end

      # Jedno kolo rozlisenia labelov: label zdielany VIACERYMI skupinami sa
      # prepise blokom (zaznamy tej istej skupiny dostanu rovnaky vysledok),
      # unikatne labely sa nemenia.
      def vepo_disambiguate(labeled)
        groups_per = labeled.group_by { |(_s, l)| l }.transform_values do |same|
          same.map { |(r, _l)| vepo_group_key(r) }.uniq
        end
        labeled.map do |(s, l)|
          groups_per[l].length > 1 ? [s, yield(s, l)] : [s, l]
        end
      end

      # Kluc skupiny pre koliznu kontrolu labelu (group_id, fallback vyrobca).
      def vepo_group_key(s)
        gid = s['group_id'].to_s.strip
        gid.empty? ? "man:#{s['manufacturer'].to_s.strip}" : gid
      end

      def vepo_edge_thicknesses
        Materials.edges.each_with_object({}) { |a, out| out[a['abs_id']] = a['thickness'].to_f }
      end

      # Default nazvu projektu z ULOZENEHO suboru (audit F10 — nie z titulku).
      def default_project_name(model)
        p = model.path.to_s
        p.empty? ? 'projekt' : File.basename(p, '.*')
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
      # Preco to NIE JE zakazany okenny stav (kontrakt v hlavicke modulu):
      # nie je to stav okna ani medzivysledok vypoctu, ale udaj o DOKUMENTE,
      # ktory sa z modelu po ulozeni preukazatelne precitat neda. Obe okna z
      # neho citaju TO ISTE, takze si ho nemaju ako prepisat. Konstanta (nie
      # `@ivar`) aj kvoli guard testu, ktory tu instancne premenne nepripusta.
      SESSION_KEY_BRIDGE = {}
      SESSION_BRIDGE_MAX = 32 # strop proti rastu pri mnohych rozrobenych oknach

      def project_names
        v = vepo_settings[PROJECT_NAMES_KEY]
        v.is_a?(Hash) ? v : {}
      end

      # Atomicka uprava MAPY nazvov (1b-6c). Blok dostane CERSTVU mapu precitanu
      # vnutri zamku a vrati upravenu; `nil` = netreba nic zapisat. Bez toho by
      # sa mapa menila nad odtlackom a zapis jednej instancie by zmazal zakazku
      # pomenovanu v druhej. Vracia uspech zapisu (false aj ked sa nepodarilo
      # vziat zamok — volajuci si vtedy MUSI nechat most na dalsi pokus).
      def update_project_names
        update_vepo_settings do |settings|
          names = settings[PROJECT_NAMES_KEY]
          names = names.is_a?(Hash) ? names.dup : {}
          fresh = yield(names)
          fresh.nil? ? nil : { PROJECT_NAMES_KEY => fresh }
        end
      end

      # Stabilna identita zakazky pre nastavenia POCITACA. Windows nerozlisuje
      # velkost pismen ani smer lomitka, takze „C:\Zakazky\Klinika.skp" a
      # „c:/zakazky/klinika.skp" musia dat TEN ISTY kluc.
      def normalize_project_path(path)
        path.to_s.strip.tr('\\', '/').downcase
      end

      # Nahradny kluc neulozeneho modelu — plati LEN v ramci sedenia (guid sa
      # po ulozeni zmeni). Preto ma vlastny prefix: aby sa dal rozoznat od
      # cesty a pri prvom ulozeni zmigrovat.
      def project_session_key(model)
        guid = model_guid(model)
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
        # fallback prepise az vtedy, ked blok naozaj bezal.
        name = effective_project_name(map, key, aliases)
        fresh = nil
        ok = update_project_names do |names|
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
        forget_session_key(model) if ok
        name.empty? ? nil : name
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
      # suboru sa v okne prejavi samo. Vracia nazov, ktory PLATI po zapise.
      #
      # MIGRACIA: ked zakazka uz ma cestu, zaznamy pod klucmi sedenia (aktualny
      # guid AJ zapamatany kluc spred ulozenia) sa pri kazdom zapise ZAHADZUJU
      # — ich ulohu prebrala cesta a guid by po dalsom ulozeni aj tak prestal
      # sediet. Pri NEULOZENOM modeli sa naopak kluc sedenia zapamata, aby ho
      # citanie po Ctrl+S nasiel (1b-6a).
      def save_project_name(model, name)
        key = project_key(model)
        return project_name(model) if key.empty?

        s = name.to_s.strip[0, PROJECT_NAME_MAX].to_s.strip
        stored = !(s.empty? || s == default_project_name(model))
        aliases = session_keys_for(model)
        # Cita a zapisuje POD ZAMKOM nad CERSTVOU mapou (1b-6c) — inak by zapis
        # z jednej instancie zmazal zakazku pomenovanu v druhej.
        ok = update_project_names do |map|
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
        elsif ok
          # Most sa zahadzuje len po USPESNOM zapise (review #243 P2-1) —
          # inak by po zlyhanom zapise zmizla jedina stopa na stary kluc.
          forget_session_key(model)
        end
        project_name(model)
      end

      # „18 a 36 mm do jedneho suboru" — GLOBALNE nastavenie (audit #1: ostava
      # take, ake bolo). Default je zapnute.
      def merge_18_36
        vepo_settings['merge_18_36'] != false
      end

      def save_merge_18_36(value)
        save_vepo_settings('merge_18_36' => (value == true))
        merge_18_36
      end

      # --- Mapy katalogov + identita modelu --------------------------------

      # Stabilna identita modelu — zrkadlo MaterialsDialog.model_guid (oneskoreny
      # klik po prepnuti dokumentu nesmie otvorit modal nad inym projektom).
      def model_guid(model)
        model && model.respond_to?(:guid) ? model.guid.to_s : ''
      rescue StandardError
        ''
      end

      # Katalog dosiek ako mapa pre Validation.run ({ material_id => sheet }).
      def sheets_map
        return {} unless defined?(Materials)

        Materials.sheets.each_with_object({}) { |s, out| out[s['material_id']] = s }
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.sheets_map')
        {}
      end

      # Katalog ABS pasok ako mapa pre Validation.run ({ abs_id => zaznam }) —
      # 2A-2 (F6): kontrola abs_missing (hrana s paskou mimo katalogu). Pri
      # chybe vraciame nil (= kontrola sa preskoci), NIE prazdnu mapu — tá by
      # falosne oznacila vsetky olepene hrany.
      def edges_map
        return nil unless defined?(Materials)

        Materials.edges.each_with_object({}) { |a, out| out[a['abs_id']] = a }
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.edges_map')
        nil
      end

      # --- Vyberove resolvery (klik v okne -> entity v modeli) --------------

      # Nalez 4: PID cielov semaforovej polozky sa hladaju v CERSTVOM modeli podla
      # STABILNEJ identity (owner_id + part_key). Bez part_key = korpus/doska ako
      # celok (vypnute kovanie, korpusove build warning). Vnorene dielce sa vyberaju
      # cez persistent_id (rovnaka cesta ako refs_for).
      def pids_for_problem(model, item)
        # D-103 (Codex audit FIX 4): nalez „dva kusy na jednom mieste" ma VLASTNU
        # adresu — presne tie top-level objekty daneho druhu. Vseobecna vetva nizsie
        # by pri korpuse pribalila aj odpojene dielce s tym istym cabinet_id.
        # 1b-3: nalez „dva kusy s tym istym ID" ma adresu v TOM ISTOM tvare
        # (`dup_kind` + `dup_owner_ids`), takze telo sa zdiela — klik oznaci VSETKY
        # kusy, ktore si ID delia. Vseobecna vetva by pri korpuse pribalila aj
        # odpojene dielce s tym istym cabinet_id.
        dup_cats = [Validation::CAT_DUPLICATE, Validation::CAT_DUP_ID]
        return pids_for_duplicate(model, item) if dup_cats.include?(item['category'].to_s)

        oid = item['owner_id'].to_s
        pkey = item['part_key'].to_s
        out = []
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          case Store.kind(inst)
          when 'cabinet'
            next unless Store.get(inst, 'cabinet_id').to_s == oid

            if pkey.empty?
              out << inst.persistent_id
            else
              found = []
              inst.definition.entities.grep(Sketchup::ComponentInstance).each do |pi|
                next unless Store.kind(pi) == 'part'
                found << pi.persistent_id if Store.get(pi, 'part_key').to_s == pkey
              end
              # Codex GH #65 P2: build warning moze mierit na dielec, ktory NEBOL
              # postaveny (part_skipped_degenerate, shelf_skipped_shallow_zone) —
              # ziadna entita s tym klucom neexistuje. Fallback: oznac vlastnika
              # (cely korpus), nie prazdny vyber s hlaskou o zmene zoznamu.
              out.concat(found.empty? ? [inst.persistent_id] : found)
            end
          when 'board'
            # Doska JE vlastnik — part_key sa nefiltruje (warning na dosku
            # oznaci dosku aj pri kluci nepostaveneho detailu).
            out << inst.persistent_id if Store.get(inst, 'id').to_s == oid
          when 'part'
            if Store.get(inst, 'cabinet_id').to_s == oid && (pkey.empty? || Store.get(inst, 'part_key').to_s == pkey)
              out << inst.persistent_id
            end
          end
        end
        out.compact.uniq
      end

      # ŠT-3b-2a (F10): oko pri jantarovom riadku sekcie Pravidlá. Adresa je
      # STABILNA DVOJICA (owner_id, part_key) — presne ta, ktorou je adresovany
      # aj sam override; PIDy sa neposielaju (rebuild ich meni). Telo uz existuje
      # v `pids_for_problem`, preto sa NEDUPLIKUJE: pri prazdnom `part_key` (override
      # kovania na celej skrinke) oznaci korpus, inak jeho vnorene dielce daneho kluca.
      # Vedomy dosledok zdielaneho tela: ak ma korpus ODPOJENE dvojca s tym istym
      # klucom, oznaci sa tiez. Je to vyber (nic sa nezapisuje) a pouzivatelovi to
      # ukaze OBA kusy — co je pri odpojenom dielci skor uzitocne nez matuce.
      def pids_for_override(model, ref)
        return [] unless ref.is_a?(Hash)

        oid = ref['owner_id'].to_s
        return [] if oid.empty?

        pids_for_problem(model, { 'owner_id' => oid, 'part_key' => ref['part_key'].to_s })
      end

      # D-103: klik na nalez o zhodnom umiestneni oznaci CELU skupinu (obe/vsetky
      # zhodne umiestnene skrinky ci dosky), aby pouzivatel videl, co presne mazat.
      # Identita je (dup_kind + dup_owner_ids) — zbierana zo SERVERA, klient ju
      # neposiela; hlada sa VYHRADNE medzi top-level objektmi daneho druhu.
      def pids_for_duplicate(model, item)
        kind = item['dup_kind'].to_s
        ids = Array(item['dup_owner_ids']).map(&:to_s).reject(&:empty?)
        return [] if kind.empty? || ids.empty?

        id_key = kind == 'cabinet' ? 'cabinet_id' : 'id'
        out = []
        model.entities.grep(Sketchup::ComponentInstance).each do |inst|
          next unless Store.kind(inst).to_s == kind
          out << inst.persistent_id if ids.include?(Store.get(inst, id_key).to_s)
        end
        out.compact.uniq
      end

      # Refs podla kluca z CERSTVEHO bomu; fallback pids (SU testy/kompat).
      def refs_for(bom, data)
        if data['parts_key']
          row = bom[:rows].find { |r| r['key'] == data['parts_key'] }
          row ? row['refs'].map { |x| x['pid'] } : []
        elsif data['hw_key']
          g = bom[:hardware].find { |x| x['key'] == data['hw_key'] }
          g ? g['breakdown'].map { |b| b['owner_pid'] } : []
        elsif data['material_key']
          refs_by_material(bom, data)
        elsif data['abs_key']
          refs_by_abs(bom, data)
        else
          Array(data['pids'])
        end.compact.uniq
      end

      # --- ŠT-2d: „Kde sa používa" -> vyber dielcov v modeli -----------------
      #
      # Adresa vyberu je `material_id` (resp. `abs_id`), NIE nazov dekoru:
      # zdrojom je BOM, a ten stoji na VYROBNOM SNAPSHOTE dielca — cize na
      # EFEKTIVNOM materiali. Preto sa oznaci aj dielec, ktory material iba
      # DEDI po korpuse (v jeho configu ziadny override nie je, ale snapshot
      # uz nesie rozhodnute `material_id`). Textove menovky dekorov
      # (`Materials.used_material_ids` a spol.) tuto vlastnost NEMAJU — dedene
      # dielce by v nich chybali a pouzivatel by videl oznacenu polovicu
      # skrinky (audit ŠT-2d #14).
      #
      # `material_key`/`abs_key` smie byt RETAZEC alebo POLE: jeden dekor ma
      # spravidla viac hrubkovych variantov (18 aj 36 mm) a „Kde sa používa"
      # sa pyta na CELU skupinu naraz. `owner_id` je nepovinne zuzenie na jeden
      # korpus/dosku (riadok zoznamu vlastnikov).
      def selector_ids(value)
        Array(value).map { |v| v.to_s.strip }.reject(&:empty?).uniq
      end

      # POZOR na rozdiel medzi „kluc CHYBA" a „kluc je PRAZDNY" (review #4):
      #   chyba          -> vyber sa NEZUZUJE (klik na cely dekor),
      #   prazdna hodnota -> zuzenie na vlastnika BEZ IDENTITY.
      # Keby sa oboje bralo ako „bez zuzenia", riadok vlastnika s prazdnym
      # `owner_id` (odpojeny dielec bez `cabinet_id`) by ticho oznacil VSETKY
      # dielce dekoru — pouzivatel by klikol na jeden riadok a dostal celu
      # zakazku. Zoznam taky riadok uz ani nekresli (`mat_used_where_owner`),
      # toto je druha poistka na serveri.
      def refs_of_rows(rows, data)
        scoped = data.is_a?(Hash) && data.key?('owner_id')
        oid = data.is_a?(Hash) ? data['owner_id'].to_s : ''
        rows.flat_map do |r|
          Array(row_value(r, 'refs')).filter_map do |ref|
            next nil unless ref.is_a?(Hash)
            next nil if scoped && ref['owner_id'].to_s != oid

            ref['pid']
          end
        end
      end

      def refs_by_material(bom, data)
        ids = selector_ids(data['material_key'])
        return [] if ids.empty?

        rows = Array(bom[:rows]).select { |r| ids.include?(row_value(r, 'material_id').to_s) }
        refs_of_rows(rows, data)
      end

      # Paska sa hlada vo VSETKYCH STYROCH hranach riadku (L1/L2/W1/W2) —
      # dielec s danou paskou je „pouzity" bez ohladu na to, ktora hrana to je.
      def refs_by_abs(bom, data)
        ids = selector_ids(data['abs_key'])
        return [] if ids.empty?

        rows = Array(bom[:rows]).select do |r|
          edges = row_value(r, 'edges')
          edges.is_a?(Hash) && edges.values.any? { |v| ids.include?(v.to_s) }
        end
        refs_of_rows(rows, data)
      end

      # --- Zber modelu (ST-1a PR B) ----------------------------------------

      # Cerstvy RAW zber. JEDEN collect pre kusovnik, semafor aj VEPO (nalez 5) —
      # compute/Validation citaju TEN ISTY zber.
      #
      # ZAVAZNY KONTRAKT (1b-3, brana G bloku 1b): TOTO JE CISTE CITANIE.
      # Nesmie sa odtialto zapisat do modelu, otvorit operacia ani pribudnut krok
      # Späť — plati to pre refresh, `push_state`, klik-select AJ vsetky styri
      # exporty. Strazi to guard test (`tests/pure/test_1b3_citanie.rb`), ktory
      # v celej UI vrstve nepripusti volanie `dedup_copies`.
      #
      # CO TU BOLO A PRECO JE TO PREC: od 19.7.2026 (Codex GH #48 P2) tu bezal
      # dedup tik — `CabinetBuilder.dedup_copies` + `BoardBuilder.dedup_copies`.
      # Vzniklo to ako ZRKADLO vtedajsieho `Panel.push_selected`, ktory dedup tiez
      # vykonaval PRIAMO. Lenze `push_selected` sa toho 9.8.2026 vzdal (D-103:
      # netransparentna operacia v selection evente rozbijala `*N` nasobenie) a od
      # vtedy opravu uz len ZIADA u observera — kym citacia cesta si ju drzala
      # dalej. Obycajne „Obnoviť" teda potichu prepisovalo ID kopiam a pridavalo
      # krok Späť.
      #
      # KDE ZIJE OPRAVA DNES: vo VLASTNEJ ZAPISOVEJ CESTE — `ScaleWatch` (dedup tik
      # po kopirovani, transparentne k pouzivatelovmu kroku) a `Panel.push_selected`
      # po zapise z panela (`ScaleWatch.request_dedup`). Kym oprava nedobehne,
      # duplicitna identita sa PRIZNAVA v Kontrole (`Validation::CAT_DUP_ID`)
      # — semafor varuje, nic neblokuje a nic sa nemeni za chrbtom.
      def fresh_collect(model)
        Bom.collect(model)
      end

      # V0.6 D1b: nakupny zoznam kovania. Stav snapshotu setov (audit F9):
      # :ok = snapshot projektu · :missing = projekt este sety nezmrazil ->
      # global default LEN NA CITANIE (okna su read-only; zmrazi ho az prva
      # stavba/zmena predvolby) · :invalid = NIC sa nemapuje (vsetko unmapped
      # ORANGE) + banner, NIKDY tichy fallback na dnesny global.
      def hardware_expansion(model, collected)
        status, state = HardwareSets.project_state_status(model)
        if status == :missing
          lib = HardwareSets.load
          by_id = {}
          lib['sets'].each { |s| by_id[s['set_id']] = s }
          state = { 'mapping' => lib['mapping'], 'sets' => by_id }
        end
        exp = HardwareSets.expand(
          Array(collected[:hardware]), state,
          cabinet_overrides: collected[:cabinet_sets].is_a?(Hash) ? collected[:cabinet_sets] : {},
          catalog: HardwareCatalog.items
        )
        # H1b (audit FIX 9 UI): dovod dostane SK text uz na SERVERI — tab
        # Kovanie aj CSV citaju to iste 'reason_sk' (JS ziadny vlastny preklad
        # enumu nema).
        exp['unmapped'] = Array(exp['unmapped']).map do |u|
          u.is_a?(Hash) ? u.merge('reason_sk' => HardwareSets.unmapped_reason_sk(u)) : u
        end
        exp.merge('state_status' => status.to_s)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.hardware_expansion')
        nil
      end

      # --- ŠT-1c (audit #3): generika kovania s POPISKAMI --------------------
      #
      # Riadok „Podľa pravidiel (generika)" v sekcii Nákup kovania potrebuje
      # dva SERVEROVE texty, ktore v BOM nie su a do snapshotu sa neukladaju:
      #   `label`        — slovensky nazov typu (V0.6 C-2, audit F11),
      #   `params_label` — „rez 597 mm" (D-90; bez neho by pri dlzkovom kovani
      #                    nebolo v zozname vidiet, aky rozmer objednat).
      # Obohatenie zije TU, aby ho okno, ktore zoznam kresli, nemuselo skladat
      # samo — inak by sa dva klienty mohli rozist v tom, ako sa polozka vola.
      def hardware_labeled(bom)
        list = bom.is_a?(Hash) ? (bom[:hardware] || bom['hardware']) : bom
        Array(list).map do |g|
          next g unless g.is_a?(Hash)

          g.merge('label' => HardwareRules.label_for(g['generic_type'] || g[:generic_type]),
                  'params_label' => HardwareRules.params_label(g['params'] || g[:params]))
        end
      end

      # 1b-3 (review P2-1): VAROVANIE O DUPLICITNEJ IDENTITE do statusu exportov,
      # ktore `Validation.run` NEVOLAJU — nakupny zoznam kovania a XLSX rozpoctu.
      # Prave ich cisla su duplicitou skreslene (zaznamy oboch kusov maju rovnaky
      # `owner_id`, takze clen setu uctovany na vlastnika sa zapocita raz), takze
      # pouzivatel by inak odoslal objednavku BEZ SLOVA — nalez by svietil len
      # v Kontrole, kam sa pri exporte nepozera.
      #
      # KDE SUFIX NIE JE a preco:
      #   * VEPO export — `Validation.run` vola, takze nalez uz ide do
      #     `control_suffix` (pocet ORANGE) AJ do sekcie KONTROLA vo VEPO LOGu.
      #     Druhe znenie tej istej veci v jednom statuse by len robilo hluk.
      #   * XLSX cenovej ponuky — ma VLASTNY zoznam dovodov (`cp_warnings`,
      #     GH #139: jeden zoznam, ktory riadi aj farbu statusu), takze duplicita
      #     patri DO NEHO, nie ako priveseny sufix.
      #
      # Strop na tri ID + „a ďalšie N" (vzor hlasky validacie pravidiel): stavovy
      # riadok nie je odsek.
      def dup_id_suffix(collected)
        dups = Validation.duplicate_identities(Array(collected.is_a?(Hash) ? collected[:identities] : nil))
        return '' if dups.empty?

        ids = dups.map { |_kind, id, _n| id }
        shown = ids.first(3).join(', ')
        more = ids.length > 3 ? " a ďalšie #{ids.length - 3}" : ''
        " · POZOR: v modeli sú kusy so spoločným ID (#{shown}#{more}) — kovanie účtované na " \
          'vlastníka (napr. TipOn) sa započíta len raz; pozri Kontrolu.'
      end

      # Suhrn KONTROLY do statusu okna/exportu (nalez 6: RED neblokuje export).
      def control_suffix(control)
        c = control.is_a?(Hash) ? (control['counts'] || {}) : {}
        return '' if c['total'].to_i.zero?

        " · KONTROLA: #{c['red'].to_i}× RED, #{c['orange'].to_i}× ORANGE (v LOGu)"
      end

      # --- ST-1a (audit #4): popisky materialov pre skupiny Kusovnika -------
      #
      # Skupina kusovnika ma v Studiu farebnu vzorku, ludsky nazov dekoru a
      # hrubku. Ziadny z tychto udajov v BOM riadku NIE JE (riadok nesie
      # `material_id`), takze by si ich klient musel dopytovat z katalogu —
      # a mal by tak DRUHU pravdu o tom, ako sa material vola. Preto ich
      # sklada SERVER, presne ako slovenske labely kovania.
      #
      # `color` je katalogove pole `[r, g, b]` (nie CSS retazec) — prevod na
      # hex robi klient, ktory farbu aj kresli.
      def materials_meta(bom)
        smap = sheets_map
        ids = []
        Array(bom[:rows]).each { |r| ids << row_value(r, 'material_id').to_s }
        Array(bom[:sheets]).each { |s| ids << row_value(s, 'material_id').to_s }
        ids = ids.reject(&:empty?).uniq
        labels = material_labels(ids, smap)
        ids.each_with_object({}) do |id, out|
          sheet = smap[id]
          out[id] = { 'label' => labels[id],
                      'color' => catalog_color(sheet),
                      'th' => sheet ? sheet['thickness'].to_f : nil,
                      'uni' => !sheet.nil? && Materials.uni?(sheet) }
        end
      end

      # To iste pre ABS pasky (pohlad ABS): popis, farba a dekor, ku ktoremu
      # paska patri. Bez toho by supis pasok ukazoval len `abs_id`.
      def edges_meta(bom)
        emap = edges_map || {}
        ids = Array(bom[:edging]).map { |e| row_value(e, 'abs_id').to_s }.reject(&:empty?).uniq
        labels = edge_labels(ids, emap)
        ids.each_with_object({}) do |id, out|
          rec = emap[id]
          out[id] = { 'label' => labels[id], 'color' => catalog_color(rec),
                      'decor' => rec ? rec['decor'].to_s : '',
                      'th' => rec ? rec['thickness'].to_f : nil,
                      'width' => (rec && rec['width'] ? rec['width'].to_f : nil),
                      'code' => rec ? rec['code'].to_s : '' }
        end
      end

      # --- 1b-6b: hlavicka skupiny materialov musi byt JEDNOZNACNA ----------
      #
      # `material_label` je LUDSKY nazov dekoru (cislo struktura nazov) — dva
      # ROZNE vyrobne materialy (iny vyrobca, typ, format platne alebo rub
      # zasteny) z neho dostanu ROVNAKY text. Podla tychto hlaviciek sa v Studiu
      # OBJEDNAVA (Kusovnik, Platne), takze dve nerozlisitelne hlavicky su
      # vyrobne riziko: objedna sa iny vyrobca, format alebo rub.
      #
      # Rozlisenie sa pridava LEN PRI REALNEJ KOLIZII (zasada `label_base` aj
      # `vepo_disambiguate` — bezna zakazka ostava kratka) a NEVYMYSLA si vlastny
      # text: eskaluje na TU ISTU menovku, aku kresli Inspector, takze panel
      # a vystupy nemozu mat dve pravdy o tom, ako sa material vola.
      #   1. `Panel.raw_row_label` — vyrobca pri kolizii (`label_base`) + pripona
      #      formatu/rubu (`Materials.sheet_label_suffix`, GH #95 P1),
      #   2. `Panel.sheet_label`   — navyse typ a hrubka (ten isty dekor v dvoch
      #      typoch: DTDL 18 vs kompakt 18),
      #   3. `[material_id]`       — poistka (vzor VEPO: dva materialy sa nesmu
      #      zliat do jednej hlavicky ani vtedy, ked katalog obsahuje nezmysel).
      #
      # KOLIZNY KLUC je to, co riadok skupiny UKAZE: menovka + hrubka (hrubka ma
      # v hlavicke aj v supise Platni vlastne miesto). Dve hrubky toho isteho
      # dekoru — najbeznejsi pripad zakazky — preto ziadne rozlisenie
      # nedostanu a ich hlavicky ostavaju kratke.
      #
      # `ctx` = kontext kolizie vyrobcov. Sentinel `:panel` znamena „postav ho
      # AZ pri prvej kolizii" — bezna zakazka tak katalog kvoli hlavickam
      # necita vobec; test si moze podstrcit vlastny kontext.
      def material_labels(ids, smap, ctx = :panel)
        labels = {}
        Array(ids).each { |id| labels[id] = material_label(smap[id], id) }
        %i[row full id].each do |level|
          amb = ambiguous_label_ids(labels) { |id| meta_thickness_key(smap[id]) }
          break if amb.empty?

          ctx = panel_label_ctx if ctx == :panel
          amb.each { |id| labels[id] = escalated_material_label(smap[id], id, labels[id], level, ctx) }
        end
        labels
      end

      # ABS pasky maju ten isty problem v mensom: `edge_label` nesie dekor
      # a rozmery, ale nie strukturu ani vyrobcu — dve pasky toho isteho cisla
      # v dvoch strukturach su v supise nerozlisitelne. Eskalacia je panelovy
      # `abs_label` (struktura + vyrobca pri kolizii + „univ.") a poistka `[id]`.
      def edge_labels(ids, emap, ctx = :panel)
        labels = {}
        Array(ids).each { |id| labels[id] = edge_label(emap[id], id) }
        %i[full id].each do |level|
          amb = ambiguous_label_ids(labels) { |id| meta_thickness_key(emap[id]) }
          break if amb.empty?

          ctx = panel_label_ctx if ctx == :panel
          amb.each { |id| labels[id] = escalated_edge_label(emap[id], id, labels[id], level, ctx) }
        end
        labels
      end

      # ID, ktorych zobrazeny riadok (menovka + hrubka z bloku) je nerozlisitelny
      # od ineho ID. Menovky sa porovnavaju `identity_norm` — rovnako ako kluce
      # `Panel.label_ctx`, takze rozdiel iba vo velkosti pismen nie je rozdiel.
      def ambiguous_label_ids(labels)
        labels.keys.group_by { |id| [Materials.identity_norm(labels[id]), yield(id)] }
              .values.select { |g| g.length > 1 }.flatten
      end

      def meta_thickness_key(rec)
        rec.is_a?(Hash) ? Materials.thickness_key(rec['thickness']) : nil
      end

      # Kontext kolizie vyrobcov z panela. Nikdy nezhodi payload — bez kontextu
      # su menovky presne dnesne (SCHEMA 1 ho nema tiez).
      def panel_label_ctx
        return nil unless defined?(Panel) && Panel.respond_to?(:label_ctx)

        Panel.label_ctx
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.panel_label_ctx')
        nil
      end

      def escalated_material_label(rec, id, current, level, ctx)
        return "#{current} [#{id}]" if level == :id
        return current unless rec.is_a?(Hash)

        level == :row ? Panel.raw_row_label(rec, ctx) : Panel.sheet_label(rec, ctx)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.escalated_material_label')
        "#{current} [#{id}]"
      end

      def escalated_edge_label(rec, id, current, level, ctx)
        return "#{current} [#{id}]" if level == :id
        return current unless rec.is_a?(Hash)

        Panel.abs_label(rec, ctx)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.escalated_edge_label')
        "#{current} [#{id}]"
      end

      # --- ST-1a (Š2): volitelny stlpec „Rola" ------------------------------
      #
      # BOM riadok rolu NENESIE (agreguje sa podla vyrobnych parametrov, nie
      # podla roly — zrkadlove dielce sa zliavaju zamerne). Rola vsak V ZAZNAME
      # je (`Bom.record` ju cita z entity), takze sa da doplnit READ-ONLY
      # obohatenim: zaznamy sa zoskupia TYM ISTYM `Bom.row_key`, akym vznikli
      # riadky, a k riadku sa priradi zoznam rol. Menit kluc agregacie by zmenilo
      # kusovnik AJ VEPO — to sa kvoli jednemu volitelnemu stlpcu nerobi.
      #
      # Slovensky text sklada SERVER (jedna autorita nazvov, JS ziadny preklad
      # enumu nema — vzor `HardwareRules.label_for`).
      ROLE_LABELS = {
        'side_left' => 'Bok ľavý', 'side_right' => 'Bok pravý',
        'top' => 'Strop', 'bottom' => 'Dno', 'back' => 'Chrbát',
        'shelf' => 'Polica', 'divider_v' => 'Zvislá priečka', 'divider_h' => 'Vodorovná priečka',
        'rail_front' => 'Výstuha predná', 'rail_back' => 'Výstuha zadná',
        'plinth' => 'Sokel', 'front_door' => 'Dvierka', 'drawer_front' => 'Čelo zásuvky',
        'free_panel' => 'Voľná doska'
      }.freeze

      def role_label(role)
        r = role.to_s
        ROLE_LABELS[r] || (r.empty? ? '' : r)
      end

      def row_roles(collected)
        Array(collected[:records]).each_with_object({}) do |r, out|
          next unless r.is_a?(Hash)

          key = Bom.row_key(r)
          list = (out[key] ||= [])
          label = role_label(r['role'])
          list << label unless label.empty? || list.include?(label)
        end
      end

      # Riadky kusovnika obohatene o `role_label` (Š2). Parovanie ide cez
      # RUBY hash (kluc riadku je POLE — v JSON by sa uz neparovalo), takze
      # klient dostane hotovy text priamo v riadku.
      def rows_with_roles(rows, collected)
        roles = row_roles(collected)
        Array(rows).map do |r|
          next r unless r.is_a?(Hash)

          list = roles[r['key']]
          list.nil? || list.empty? ? r : r.merge('role_label' => list.join(' · '))
        end
      end

      # BOM riadky chodia raz so String, raz so Symbol klucmi (Bom.compute vs
      # to_json cesta) — jedno miesto, kde sa to rozhoduje.
      def row_value(row, key)
        return nil unless row.is_a?(Hash)

        row[key].nil? ? row[key.to_sym] : row[key]
      end

      # Ludsky nazov dekoru pre UI (NIE exportny label — ten sklada
      # `vepo_base_label` a nesie navyse typ aj disambiguatory).
      def material_label(sheet, id)
        return id if sheet.nil?

        txt = [sheet['decor'], sheet['structure'], sheet['decor_name']]
              .map { |v| v.to_s.strip }.reject(&:empty?).join(' ')
        txt = sheet['family'].to_s.strip if txt.empty?
        txt.empty? ? id : txt
      end

      def edge_label(rec, id)
        return id if rec.nil?

        dims = [rec['width'], rec['thickness']].compact.map { |v| format('%g', v.to_f) }
        base = rec['decor'].to_s.strip
        base = id if base.empty?
        dims.length == 2 ? "#{base} #{dims[0]}×#{dims[1]}" : base
      end

      # Katalogova farba ako [r, g, b]; chybajuca/poskodena = nil (klient vtedy
      # nekresli ziadnu vzorku — radsej nic nez nahodna farba).
      def catalog_color(rec)
        c = rec.is_a?(Hash) ? rec['color'] : nil
        c.is_a?(Array) && c.length == 3 ? c.map(&:to_i) : nil
      end

      # --- ST-1a PR B: zdielane telo EXPORTU a VYBERU ----------------------
      #
      # Telo zije TU a volajuci (okno Studio, po in-SU testy) odovzdava svoj
      # stav EXPLICITNE:
      #   generation — okenny generacny token (B4 guard stareho DOM kliku),
      #   status     — ->(msg, error) do TOHO okna,
      #   repush     — -> { } cerstvy payload TOMU oknu (ak zije).
      # Parametre ostavaju aj po zaniku druheho okna (ŠT-1c PR B3): drzia
      # ZAVAZNU BEZSTAVOVOST tela. Keby si jadro siahlo na `@generation` alebo
      # `js` samo, prestalo by byt cistou funkciou a kazdy dalsi klient by
      # musel obchadzat cudzi okenny stav.

      # V0.5 C: export VEPO — vstup po relay z panela (edity flushnute) alebo
      # priamo (panel nezije). Poradie: gen check -> flush guard -> vyber
      # priecinka -> CERSTVY BOM -> build -> atomicky zapis -> ulozit settings.
      def do_export(model, data, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i
          repush.call
          return status.call('Dáta okna sa medzitým zmenili — skús export znova.', true)
        end
        if data['flush_blocked']
          return status.call('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
        end

        refresh_vepo_settings # 1b-6c: nazov aj 18/36 z CERSTVEHO suboru
        settings = vepo_settings
        last = settings['last_dir']
        start_dir = last.is_a?(String) && File.directory?(last) ? last : nil
        dir = UI.select_directory(title: 'Priečinok pre VEPO export', directory: start_dir)
        return status.call('Export zrušený.') if dir.nil? || dir.to_s.empty?

        # Nalez 5: JEDEN cerstvy RAW zber -> nad nim compute AJ kontrola;
        # validaciu EXPLICITNE odovzdame do build (prefix statusu + sekcia
        # KONTROLA v LOGu z TOHO ISTEHO vysledku).
        #
        # Review #1 (ŠT-1b): kontrola sa tu pocita ZDIELANOU `control_payload`,
        # teda VRATANE upozorneni rozpoctu. Bez toho by LOG a status exportu
        # hlasili ine cislo nez semafor sekcie Kontrola a badge navigacie —
        # a pouzivatel by nevedel, ktore z dvoch cisel plati.
        collected = fresh_collect(model)
        bom = Bom.compute(collected)
        smap = sheets_map
        hw_exp = hardware_expansion(model, collected)
        control = control_payload(collected, hardware_expansion: hw_exp,
                                             budget: budget_payload(model, bom, collected,
                                                                    nil, hw_exp, smap),
                                             sheets: smap)
        # audit #1: nazov projektu aj merge su SERVEROVE — z DOM uz nechodia.
        merge = merge_18_36
        result = VepoExport.build(
          bom[:rows],
          project: project_name(model),
          materials: vepo_materials,
          edge_thicknesses: vepo_edge_thicknesses,
          validation: control,
          version: Engine::VERSION,
          generated_at: Time.now.strftime('%Y-%m-%d %H:%M'),
          merge_18_36: merge
        )
        if result['groups'].empty? && result['errors'].empty?
          return status.call('Niet čo exportovať — model nemá výrobné dielce.', true)
        end

        # GH P2: aj ked su VSETKY riadky chybne, LOG s dovodmi sa MUSI zapisat
        # (inak by diagnostika chybala presne pri uplne zlyhanom exporte).
        target = VepoExport.write(result, dir)
        # Nalez 6: KONTROLA nikdy neblokuje export; jej suhrn ide do statusu.
        ctrl = control_suffix(control)
        save_vepo_settings('last_dir' => dir)
        if result['groups'].empty?
          return status.call("Export nevytvoril žiadny CSV — #{result['errors'].length} chybných riadkov. " \
                             "Dôvody v LOGu: #{target}#{ctrl}", true)
        end

        err = result['errors'].empty? ? '' : " · #{result['errors'].length} vyradených riadkov (viď LOG)"
        status.call("VEPO export hotový: #{result['groups'].length} súborov, #{result['total_rows']} riadkov " \
                    "(#{result['total_pieces']} ks) → #{target}#{err}#{ctrl}", !result['errors'].empty?)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_export')
        status.call("Chyba exportu: #{e.message}", true)
      end

      # --- ŠT-1c: CSV nakupneho zoznamu kovania (Š7) ------------------------
      #
      # Telo sa sem prestahovalo spolu s tabom Kovanie zaniknuteho okna Vyroba
      # (dnes sekcia `buy` v Studiu). Poradie je vzor VEPO exportu: gen guard
      # -> flush guard -> CERSTVY zber modelu -> vyber suboru -> zapis.
      #
      # VEDOMA ZMENA (audit #15): export dostal GENERACNY GUARD, ktory predtym
      # NEMAL — ako jediny zo styroch exportov. Zosuladenie, nie nova ochrana:
      # CO GUARD NAOZAJ CHYTA je klik z okna, ktoreho payload uz neplati —
      # medzitym PREPNUTY DOKUMENT (`on_model_changed` zdvihne generaciu) alebo
      # push, ktory si okno medzitym vyziadalo odinakial (refresh, zmena
      # katalogu, zapis z ineho okna). CO NECHYTA: prestavbu skrinky
      # z Inspectora — tá generaciu NEZDVIHA. Na tú je poistkou to, ze zoznam
      # sa aj tak pocita z CERSTVEHO zberu (`fresh_collect` nizsie) az v tejto
      # metode, nie z toho, co drzi DOM. Odmietnutie nie je tiche — okno sa
      # obnovi a povie to.
      def do_hw_csv(model, data, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i
          repush.call
          return status.call('Dáta okna sa medzitým zmenili — skús export znova.', true)
        end
        if data['flush_blocked']
          return status.call('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
        end

        refresh_vepo_settings # 1b-6c: nazov zakazky z CERSTVEHO suboru
        collected = fresh_collect(model)
        exp = hardware_expansion(model, collected)
        return status.call('Nákupný zoznam sa nedá zostaviť (pozri Ruby konzolu).', true) if exp.nil?

        if Array(exp['rows']).empty? && Array(exp['unmapped']).empty?
          return status.call('Model nemá žiadne kovanie — niet čo exportovať.', true)
        end

        # audit #1: nazov projektu je SERVEROVA autorita (jeden nazov pre
        # VSETKY styri exporty) — z DOM uz nechodi.
        project = project_name(model)
        fname = "kovanie_#{VepoExport.project_slug(project)}.csv"
        target = UI.savepanel('Uložiť nákupný zoznam kovania', vepo_settings['last_dir'], fname)
        return status.call('Export zrušený.') if target.nil? || target.to_s.empty?

        csv = HardwareSets.purchase_csv(exp, project: project,
                                        generated_at: Time.now.strftime('%Y-%m-%d %H:%M'))
        File.open(target, 'wb') { |f| f.write("\xEF\xBB\xBF" + csv) } # BOM pre Excel
        save_vepo_settings('last_dir' => File.dirname(target))
        n = Array(exp['rows']).length
        un = Array(exp['unmapped']).length
        dup = dup_id_suffix(collected)
        status.call("Nákupný zoznam: #{n} položiek" \
                    "#{un.positive? ? " + #{un} nemapovaných (v CSV aj KONTROLE)" : ''} → #{target}#{dup}",
                    un.positive? || !dup.empty?)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_hw_csv')
        status.call("Export zlyhal: #{e.message}", true)
      end

      # Vstup pre relay z panela (B1): panel uz flushol edity, mozeme vyberat.
      # Klik nesie KLUC riadku, nie pids (Codex GH #48 P2: flush mohol korpus
      # rebuildnut a stare pids zomreli) — refs sa hladaju v CERSTVOM zbere.
      #
      # `focus_inspector` (ST-1a, Š3 ceruzka): po vybere sa Inspector zdvihne
      # dopredu, aby sa dielec dal rovno upravit. Vyber sa tym NEMENI a do
      # modelu sa nezapisuje nic.
      def do_select(model, data, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i # B4: stale klik (iny model/stary DOM)
          # Review PR #193 P2: tichy no-op tu bol chyba — pouzivatel klikol,
          # v modeli sa nic neoznacilo a okno mlcalo. Data sa obnovia A POVIE
          # sa to (rovnaky vzor ako pri exporte).
          repush.call
          return status.call('Dáta okna sa medzitým obnovili — klikni znova.', true)
        end

        # Nalez 4: semafor klik nesie STABILNY kluc problemu; validacia sa po
        # flushi editov PREPOCITA NANOVO a entity sa dohladaju podla identity
        # (owner_id + part_key), nie podla PID (rebuild ho meni).
        #
        # ŠT-3b-2b (review #221): zber sa robi AZ V TEJ VETVE, ktora ho naozaj
        # potrebuje. Vetva `rule_ref` hlada podla identity a s BOM nerobi nic —
        # plny sken modelu (a dedup tik v nom) bol pri nej cista rezia.
        if data['problem_key']
          collected = fresh_collect(model)
          # GH #127 P2: klik-resolve MUSI ratat s rovnakym vstupom ako
          # push_state — bez hardware_expansion by sa stable kluce novych
          # ORANGE (hardware_unmapped/hardware_code) nikdy nenasli.
          item = Validation.run(collected, sheets: sheets_map, edges: edges_map,
                                hardware_expansion: hardware_expansion(model, collected),
                                placements: collected[:placements],
                                identities: collected[:identities])['items']
                           .find { |it| it['stable_key'] == data['problem_key'] }
          if item.nil?
            repush.call
            return status.call('Kontrola sa medzitým zmenila — obnovené, klikni znova.', true)
          end
          pids = pids_for_problem(model, item)
        elsif data['rule_ref']
          # ŠT-3b-2a: oko pri jantarovom riadku sekcie Pravidlá. Vlastna vetva
          # ZAMERNE: `refs_for` hlada v HOTOVOM bome podla klucov riadkov, kdezto
          # override je adresovany identitou (owner_id, part_key) — v kusovniku
          # ziadny taky riadok byt nemusi (napr. vypnute kovanie).
          pids = pids_for_override(model, data['rule_ref'])
        else
          pids = refs_for(Bom.compute(fresh_collect(model)), data)
        end
        targets = pids.filter_map do |pid|
          ent = model.find_entity_by_persistent_id(pid.to_i)
          ent if ent && ent.valid? && ent.respond_to?(:definition)
        end
        if targets.empty?
          # riadok/polozka medzitym zanikol (flush editov zmenil rozmery/model) —
          # obnov data, nech pouzivatel klikne na aktualny riadok
          repush.call
          return status.call('Zoznam sa medzitým zmenil — obnovené, klikni znova.', true)
        end

        Panel.suspend_selection_sync do
          sel = model.selection
          sel.clear
          targets.each { |t| sel.add(t) }
        end
        Panel.push_selected(model, dedup: false) # B2: ziadna mutacia pri selecte
        focus = data['focus_inspector'] == true && Panel.dialog_alive?
        Panel.bring_to_front if focus
        status.call("Vybraných #{targets.length} položiek v modeli." \
                    "#{focus ? ' Inspector je vpredu — dielec sa dá hneď upraviť.' : ''}")
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_select')
        status.call("Chyba výberu: #{e.message}", true)
      end

      # --- ŠT-1b (audit #2): JEDNO CISLO KONTROLY PRE VSETKYCH ------------
      #
      # Semafor sekcie Kontrola (Studio), badge navigacie aj suhrn v statuse
      # a LOGu exportu musia ukazovat TO ISTE. Preto sa cely vypocet KONTROLY —
      # vratane zlucenia s upozorneniami ROZPOCTU — robi TU a vsetci volaju
      # tuto jednu metodu. Dva takmer rovnake vypocty by sa casom rozisli
      # a pouzivatel by videl dve rozne cisla.
      #
      # POZOR na zamenu: ⚠ chip v INSPECTORE je nieco INE — su to build
      # warnings PRAVE OZNACENEJ skrinky, nie kontrola celej zakazky. Inspector
      # sem len VEDIE (deep-link „Otvoriť v Štúdiu → Kontrola").
      #
      # `budget` je HOTOVY payload rozpoctu (Studio ho aj tak pocita pre
      # svoj tab, tak ho odovzda a nepocita sa dvakrat); nil = rozpocet sa
      # nepodaril zostavit a jeho ORANGE do zoznamu nepribudnu.
      def control_payload(collected, hardware_expansion: nil, budget: nil, sheets: nil)
        smap = sheets || sheets_map
        control = Validation.run(collected, sheets: smap, edges: edges_map,
                                 hardware_expansion: hardware_expansion,
                                 placements: collected[:placements],
                                 identities: collected[:identities])
        return control unless budget.is_a?(Hash)

        Validation.with_budget(control, budget['budget_check'])
      end

      # V0.6 E-b: payload rozpoctu z TYCH ISTYCH dat ako kusovnik/semafor (jedna
      # autorita cisel). ŠT-1b: telo sa stahuje sem, lebo rozpoctove upozornenia
      # su sucastou KONTROLY a tu uz cita aj Studio. Zlyhanie NIKDY nezhodi okno —
      # vrati nil a zvysok okna zije dalej.
      def budget_payload(model, bom, collected, estimate = nil, hw_exp = nil, smap = nil)
        smap ||= sheets_map
        est = estimate || SheetEstimate.estimate(
          bom[:rows],
          sheet_sizes: smap.each_with_object({}) { |(id, s), out| out[id] = s['sheet_size'] },
          uni_ids: smap.each_with_object({}) { |(id, s), out| out[id] = true if Materials.uni?(s) }
        )
        exp = hw_exp || hardware_expansion(model, collected)
        Budget.payload_for(model, bom, sheets: smap, edges: (edges_map || {}),
                           hardware_expansion: exp, hardware_catalog: hardware_catalog_items,
                           sheet_estimate: est)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.budget_payload')
        nil
      end

      # Katalog kovania pre scan veku cien; chyba katalogu = scan sa preskoci
      # (vzor edges_map), rozpocet sa nezhodi.
      def hardware_catalog_items
        return nil unless defined?(HardwareCatalog)

        HardwareCatalog.items
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.hardware_catalog_items')
        nil
      end

      # --- D-83 / ŠT-1b (audit #13): skratka „Nahradiť UNI…" ---------------
      #
      # Riadok KONTROLY „materiál neurčený" ponuka rovno zamenu UNI za realny
      # dekor. Modal patri oknu Materialy, tu je len cesta k nemu. Okno NEMUTI
      # model — otvara sa okno, preto ziadny flush handshake.
      # Vsetky tri guardy bezia na SERVERI (klientovi sa neveri):
      #   gen        — riadok zo stareho DOM (medzitym prepocitana kontrola),
      #   model_guid — medzitym prepnuty dokument,
      #   uni_id     — material medzitym zmazany/nahradeny/uz nie je UNI.
      def replace_uni(model, data, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i
          repush.call
          return status.call('Kontrola sa medzitým zmenila — obnovené, klikni znova.', true)
        end
        guid = data['model_guid'].to_s
        if !guid.empty? && guid != model_guid(model)
          repush.call
          return status.call('Model sa medzitým prepol — obnovené, klikni znova.', true)
        end
        uni_id = data['uni_id'].to_s
        sheet = defined?(Materials) ? Materials.sheet(uni_id) : nil
        unless sheet && Materials.uni?(sheet)
          repush.call
          return status.call('Materiál už nie je UNI (medzitým sa zmenil) — kontrola obnovená.', true)
        end
        unless defined?(MaterialsDialog) && MaterialsDialog.request_replace_uni(uni_id, model)
          return status.call('Okno Materiály sa nepodarilo otvoriť.', true)
        end

        status.call("Otváram „Nahradiť UNI…“ pre #{uni_id}.")
      end

      # --- D-104 / D-105 / K2 (audit #5): ZDIELANE PREPINACE OVERLAYOV ------
      #
      # „Zvýrazniť hrany" a „Smer kresby" su od ŠT-1b v liste sekcie Kontrola
      # (Studio); dovtedy boli v tabe Kontrola zaniknuteho okna Vyroba. Ta ista
      # akcia ma DVA vstupne body (okno + rail Inspectora), takze telo MUSI byt
      # jedno; okno odovzdava LEN svoj generacny token, svoj status, svoj
      # refresh a svoje echo (maly push stavu).
      #
      # Model sa NEMENI — overlay kresli NAD nim (ziadna operacia, ziadny undo
      # krok, ziadny zapis do .skp; nastavenie zije v %APPDATA%).

      # Spolocne serverove guardy (HTML disabled nie je ochrana):
      #   available  — SketchUp bez Overlay API (2022 a starsi),
      #   gen        — klik zo stareho DOM (medzitym prepocitane okno),
      #   model_guid — medzitym prepnuty dokument (zaplo by sa v cudzej zakazke).
      # false = akcia sa NEVYKONA (volajucemu uz odisiel status aj cerstvy stav).
      def edge_check_guard(data, model, generation:, status:, repush:, echo:)
        unless defined?(EdgeCheck) && EdgeCheck.available?(model)
          echo.call
          status.call('Zvýraznenie hrán vyžaduje SketchUp 2023 alebo novší.', true)
          return false
        end
        identity_guard(data, model, generation: generation, status: status, repush: repush)
      end

      # Identita kliku (BEZ otazky na konkretny overlay): generacia okna +
      # dokument. Review #6: kresba smeru si dostupnost API overuje SAMA a jej
      # hlaska musi hovorit o KRESBE — nie o hranach; preto je tato cast
      # vyclenena a zdielaju ju obe akcie.
      def identity_guard(data, model, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i
          repush.call
          status.call('Okno sa medzitým prepočítalo — obnovené, klikni znova.', true)
          return false
        end
        unless data['model_guid'].to_s == model_guid(model)
          repush.call
          status.call('Model sa medzitým prepol — obnovené, klikni znova.', true)
          return false
        end
        true
      end

      # Prepnutie zvyraznenia. Ide ZDIELANOU Engine.toggle_edge_check — tá stav
      # rozposle OBOM prijimatelom (lista sekcie Kontrola v Studiu a rail
      # Inspectora), takze vlastny push tu netreba; lokalny je uz len status.
      def do_edge_check(model, data, generation:, status:, repush:, echo:)
        return unless edge_check_guard(data, model, generation: generation, status: status,
                                                    repush: repush, echo: echo)

        state = Engine.toggle_edge_check(model)
        status.call(edge_check_status(state))
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_edge_check')
        status.call("Chyba zvýraznenia hrán: #{e.message}", true)
      end

      # D-105: prepinace stavov (chyba / mimo pravidla / olepene + „len vybrané").
      # Codex audit FIX 4: kluc musi byt z whitelistu a hodnota VYSLOVNE
      # true/false (retazec "false" je v Ruby pravdivy) — inak sa NEZAPISE nic.
      def do_edge_check_option(model, data, generation:, status:, repush:, echo:)
        return unless edge_check_guard(data, model, generation: generation, status: status,
                                                    repush: repush, echo: echo)

        key = data['key'].to_s
        value = data['value']
        unless EdgeCheck::OPTION_KEYS.include?(key) && (value == true || value == false)
          echo.call
          return status.call('Neznáme nastavenie zvýraznenia — nič sa nezmenilo.', true)
        end
        Engine.set_edge_check_option(key, value)
        status.call(edge_check_option_status(key, value))
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_edge_check_option')
        status.call("Chyba nastavenia zvýraznenia: #{e.message}", true)
      end

      # K2/D-87: prepinac „Smer kresby". Identita kliku (gen + model_guid) je
      # ZDIELANA so zvyraznenim hran; dostupnost Overlay API si vsak overuje
      # VLASTNU (`GrainCheck.available?`) a hlasi ju VLASTNOU vetou — review #6:
      # pouzivatel klikol na kresbu, takze hlaska o hranach by ho poslala hladat
      # chybu inam.
      def do_grain_check(model, data, generation:, status:, repush:, grain_echo:)
        unless defined?(GrainCheck) && GrainCheck.available?(model)
          grain_echo.call
          return status.call('Smer kresby vyžaduje SketchUp 2023 alebo novší.', true)
        end
        return unless identity_guard(data, model, generation: generation, status: status,
                                                  repush: repush)

        state = Engine.toggle_grain_check(model)
        status.call(grain_check_status(state))
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_grain_check')
        status.call("Chyba kresby smeru: #{e.message}", true)
      end

      def edge_check_status(state)
        st = state.is_a?(Hash) ? state : {}
        return 'Zvýraznenie hrán vypnuté — v modeli nič neostalo.' unless st['active']

        opts = st['options'].is_a?(Hash) ? st['options'] : {}
        counts = st['counts'].is_a?(Hash) ? st['counts'] : {}
        parts = []
        parts << "#{counts['missing'].to_i} chýba podľa pravidla" if opts['show_missing']
        parts << "#{counts['extra'].to_i} neolepených mimo pravidla" if opts['show_extra']
        parts << "#{counts['taped'].to_i} olepených" if opts['show_taped']
        return 'Zvýraznenie zapnuté — žiadny stav nie je zapnutý (otvor nastavenie ▾).' if parts.empty?

        extra = st['unresolved'].to_i.positive? ? " · #{st['unresolved'].to_i} sa nedá zvýrazniť" : ''
        "Zvýraznenie zapnuté — #{parts.join(' · ')}#{extra}."
      end

      # D-105: kratke potvrdenie prepnutia (nazvy su TIE ISTE ako v rozbalovacom
      # okne — server je jediny zdroj textov; zrkadli ich js/edge_menu.js).
      EDGE_OPTION_LABELS = {
        'show_missing' => 'Chýba podľa pravidla', 'show_extra' => 'Neolepené mimo pravidla',
        'show_taped' => 'Olepené', 'taped_selected_only' => 'Olepené — len vybrané'
      }.freeze

      def edge_check_option_status(key, value)
        "#{EDGE_OPTION_LABELS[key] || key}: #{value ? 'zapnuté' : 'vypnuté'}."
      end

      def grain_check_status(state)
        st = state.is_a?(Hash) ? state : {}
        return 'Smer kresby vypnutý — v modeli nič neostalo.' unless st['active']

        parts = ["#{st['parts'].to_i} #{grain_part_plural(st['parts'].to_i)} s kresbou"]
        parts << "#{st['skipped'].to_i} bez kresby (materiál bez smeru)" if st['skipped'].to_i.positive?
        parts << "#{st['unresolved'].to_i} sa nedá nakresliť" if st['unresolved'].to_i.positive?
        "Smer kresby zapnutý — #{parts.join(' · ')}."
      end

      # 1 dielec / 2–4 dielce / 5+ dielcov
      def grain_part_plural(n)
        v = n.abs
        return 'dielec' if v == 1
        return 'dielce' if v >= 2 && v <= 4

        'dielcov'
      end

      # ==================== ŠT-1c PR B1: ROZPOCET ============================
      #
      # Rozpocet je JEDINA cesta, ktora ZAPISUJE do modelu — a od tejto davky
      # zije v sekcii `budget` okna Studio. Telo sa sem presunulo zo (vtedy
      # este ziveho) okna Vyroba z toho isteho dovodu ako vsetko ostatne: dve
      # kopie zapisovacej cesty by sa casom rozisli a rozdiel by sa ukazal az
      # na cenovej ponuke.
      #
      # Okno odovzdava LEN svoj stav:
      #   generation — okenny generacny token (zapis zo stareho DOM sa odmietne),
      #   status     — ->(msg, error) do TOHO okna,
      #   repush     — -> {} cerstvy payload TOMU oknu (pri rozpocte BEZ zdvihu
      #                generacie — viz `StudioDialog.push_state(bump: false)`),
      #   result     — ->(op, ok) echo vysledku PRED payloadom (rozpisany draft
      #                sa smie zavriet LEN pri uspechu).
      #
      # INVARIANT: jedna mutacia = jedna metoda `BudgetStore` = JEDEN krok Spat.
      # Validacia aj rozsahy su v `BudgetStore` (server) — tu sa len smeruje.

      # Mutacie rozpoctu (rezim, prepis sumy, nasobok, m2, spotrebice v sucte,
      # vlastne polozky, zaradenie v cenovej ponuke). Guardy bezia na SERVERI —
      # HTML disabled ani klientske echo nie su ochrana:
      #   gen        — zapis zo stareho DOM (medzitym prepocitane okno),
      #   model_guid — medzitym prepnuty dokument (zapis by sadol do cudzej zakazky).
      # Po KAZDOM zapise ide cerstvy payload — klient si sumy NIKDY neprepocitava.
      def do_budget(model, data, generation:, status:, repush:, result: nil)
        unless data['gen'].to_i == generation.to_i
          repush.call
          return status.call('Rozpočet sa medzitým prepočítal — obnovené, skús znova.', true)
        end
        guid = data['model_guid'].to_s
        # Tolerantne: prazdny udaj z klienta (starsi cachovany DOM) guard
        # neblokuje, NEZHODNE ID ano.
        if !guid.empty? && guid != model_guid(model)
          repush.call
          return status.call('Model sa medzitým prepol — obnovené, skús znova.', true)
        end
        ok, errors = apply_budget_op(model, data)
        # GH #138 P2: vysledok ide do okna PRED cerstvym payloadom — rozpisany
        # novy riadok sa smie zavriet LEN pri uspechu (inak by pouzivatel po
        # odmietnutom zapise prisiel o vsetky vyplnene hodnoty).
        result.call(data['op'].to_s, ok) if result
        repush.call
        return status.call("Nezapísané: #{Array(errors).join(' · ')}", true) unless ok

        status.call(budget_op_status(data))
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_budget')
        # Aj po vynimke musi prist payload — inak by okno ostalo v stave
        # „cakam na odpoved" a fronta zapisov by sa neuvolnila.
        repush.call
        status.call("Chyba rozpočtu: #{e.message}", true)
      end

      # Jedna mutacia = jedna metoda BudgetStore = jeden undo krok.
      # -> [ok, errors]
      def apply_budget_op(model, data)
        attrs = data['attrs'].is_a?(Hash) ? data['attrs'] : {}
        id = data['id'].to_s
        case data['op'].to_s
        when 'mode'             then BudgetStore.set_mode!(model, data['mode'])
        when 'override'         then BudgetStore.set_override!(model, data['row_key'], data['amount'])
        when 'multiplier'       then BudgetStore.set_std_multiplier!(model, data['row_key'], data['multiplier'])
        when 'viz_m2'           then BudgetStore.set_viz_m2!(model, data['value'])
        when 'appl_included'    then BudgetStore.set_appliances_included!(model, data['included'])
        when 'custom_add'       then ok_pair(BudgetStore.add_custom_item!(model, attrs))
        when 'custom_update'    then ok_pair(BudgetStore.update_custom_item!(model, id, attrs))
        when 'custom_remove'    then BudgetStore.remove_custom_item!(model, id)
        when 'appliance_add'    then ok_pair(BudgetStore.add_appliance!(model, attrs))
        when 'appliance_update' then ok_pair(BudgetStore.update_appliance!(model, id, attrs))
        when 'appliance_remove' then BudgetStore.remove_appliance!(model, id)
        when 'cp_group'         then BudgetStore.set_cp_group!(model, data['source_key'], data['group'])
        else [false, ['neznáma operácia rozpočtu']]
        end
      end

      # add_/update_ vracaju [polozka|nil, chyby] — zjednotenie na [ok, chyby].
      def ok_pair(result)
        item, errors = result
        [!item.nil? && Array(errors).empty?, errors]
      end

      BUDGET_OP_STATUS = {
        'mode' => 'Cenový režim zmenený.', 'override' => 'Suma riadku prepísaná.',
        'multiplier' => 'Násobok riadku uložený.', 'viz_m2' => 'm² vizualizácie uložené.',
        'appl_included' => 'Spotrebiče v súčte — prepnuté.',
        'custom_add' => 'Položka pridaná.', 'custom_update' => 'Položka upravená.',
        'custom_remove' => 'Položka zmazaná.', 'appliance_add' => 'Spotrebič pridaný.',
        'appliance_update' => 'Spotrebič upravený.', 'appliance_remove' => 'Spotrebič zmazaný.',
        'cp_group' => 'Zaradenie v cenovej ponuke zmenené.'
      }.freeze

      def budget_op_status(data)
        BUDGET_OP_STATUS[data['op'].to_s] || 'Rozpočet uložený.'
      end

      # ↗ v riadku: URL sa NEBERIE z klienta — dohladava sa v modeli podla ID
      # polozky a este raz sanitizuje (BudgetStore.sanitize_url povoluje LEN
      # http/https). Klient tak nema ako podstrcit javascript:/file: adresu.
      def budget_open_url(model, data, status:)
        id = data['id'].to_s
        list = data['kind'].to_s == 'appliance' ? BudgetStore.appliances(model) : BudgetStore.custom_items(model)
        item = list.find { |it| it['id'] == id }
        return status.call('Položka sa nenašla — obnov okno.', true) if item.nil?

        url = BudgetStore.sanitize_url(item['url'])
        return status.call('Položka nemá platnú adresu (http:// alebo https://).', true) if url.nil?

        UI.openURL(url)
        status.call("Otváram #{url}")
      end

      # ŠT-4a: `open_budget_settings` ZANIKLO. ⚙ v liste sekcie Rozpocet otvarala
      # SATELIT „Nastavenia rozpočtu"; ten uz neexistuje — sadzby su SEKCIA `bset`
      # TOHTO okna, takze ⚙ je odteraz cisto klientske prepnutie sekcie
      # (`studioGoSection('bset')`). Server o prepnuti sekcie vediet nemusi
      # a callback `budget_settings` zanikol s nim.

      def fmt_eur(value)
        format('%.2f €', value.to_f).tr('.', ',')
      end

      # V0.6 E-b: XLSX rozpocet v „Luciinom formate". Rovnaky flush/generation
      # handshake ako VEPO — cisla harku musia sediet s modelom PO flushi
      # rozpisaneho editu panela, nie s tym, co drzi DOM okna.
      def do_budget_xlsx(model, data, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i
          repush.call
          return status.call('Dáta okna sa medzitým zmenili — skús export znova.', true)
        end
        if data['flush_blocked']
          return status.call('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
        end

        refresh_vepo_settings # 1b-6c: nazov zakazky z CERSTVEHO suboru
        collected = fresh_collect(model)
        bom = Bom.compute(collected)
        budget = budget_payload(model, bom, collected)
        return status.call('Rozpočet sa nepodarilo zostaviť (pozri Ruby konzolu).', true) if budget.nil?

        project = project_name(model) # audit #1: server je autorita nazvu
        now = Time.now
        target = UI.savepanel('Uložiť rozpočet (XLSX)', vepo_settings['last_dir'],
                              BudgetXlsx.file_name(project, now))
        return status.call('Export zrušený.') if target.nil? || target.to_s.empty?

        # Bez pripony by Excel subor neotvoril dvojklikom — savepanel ju
        # nedoplna, ked ju pouzivatel v nazve prepise.
        target = "#{target}.xlsx" unless File.extname(target.to_s).downcase == '.xlsx'
        XlsxWriter.write(target, BudgetXlsx.sheet(budget, project: project, now: now), now: now)
        save_vepo_settings('last_dir' => File.dirname(target))
        totals = budget['totals'] || {}
        miss = totals['unknown_count_in_total'].to_i
        dup = dup_id_suffix(collected)
        status.call("Rozpočet uložený: #{fmt_eur(totals['total'])} → #{target}" \
                    "#{miss.positive? ? " · #{miss} riadkov bez ceny sa nezapočítalo" : ''}#{dup}",
                    miss.positive? || !dup.empty?)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_budget_xlsx')
        status.call("Export rozpočtu zlyhal: #{e.message}", true)
      end

      # V0.6 E-b2: ZAKAZNICKA CENOVA PONUKA (XLSX, 2 harky). Rovnaky
      # flush/generation handshake ako rozpocet — CP je VIEW nad TYM ISTYM
      # payloadom, takze cisla musia sediet s modelom PO flushi editov panela.
      #
      # FIREWALL: pred zapisom sa cely vysledny harok prejde blocklistom
      # (CpExport.firewall_hits). Nalez export NEBLOKUJE (rovnaky kontrakt ako
      # KONTROLA pri VEPO), ale ide do statusu aj do logu — Michal musi
      # vediet, ze do zakaznickeho dokumentu presiel interny pojem.
      def do_cp_xlsx(model, data, generation:, status:, repush:)
        unless data['gen'].to_i == generation.to_i
          repush.call
          return status.call('Dáta okna sa medzitým zmenili — skús export znova.', true)
        end
        if data['flush_blocked']
          return status.call('V paneli sú neplatné polia (červené) — oprav ich a exportuj znova.', true)
        end

        refresh_vepo_settings # 1b-6c: nazov zakazky z CERSTVEHO suboru
        collected = fresh_collect(model)
        bom = Bom.compute(collected)
        smap = sheets_map
        hw_exp = hardware_expansion(model, collected)
        budget = budget_payload(model, bom, collected, nil, hw_exp, smap)
        return status.call('Rozpočet sa nepodarilo zostaviť (pozri Ruby konzolu).', true) if budget.nil?

        cp = budget['cp_preview']
        cp ||= CpExport.preview(budget, BudgetStore.cp_overrides(model), SupplierSettings.active)
        spec = CpExport.specification(collected[:records], sheets: smap,
                                                           hardware_expansion: hw_exp, budget: budget)

        project = project_name(model) # audit #1: server je autorita nazvu
        now = Time.now
        target = UI.savepanel('Uložiť cenovú ponuku (XLSX)', vepo_settings['last_dir'],
                              CpXlsx.file_name(project, now))
        return status.call('Export zrušený.') if target.nil? || target.to_s.empty?

        target = "#{target}.xlsx" unless File.extname(target.to_s).downcase == '.xlsx'
        sheets = CpXlsx.sheets(cp, spec, project: project, now: now)
        hits = CpExport.firewall_hits(CpXlsx.text_cells(sheets))
        XlsxWriter.write_book(target, sheets, now: now)
        save_vepo_settings('last_dir' => File.dirname(target))
        warnings = cp_warnings(cp, budget, hits, collected)
        status.call(cp_status(cp, spec, target, warnings), !warnings.empty?)
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.do_cp_xlsx')
        status.call("Export cenovej ponuky zlyhal: #{e.message}", true)
      end

      # GH #139 P1/P2: JEDEN zoznam dovodov, preco zakaznicky dokument NIE JE
      # v poriadku — rozhoduje aj o farbe statusu, aby sa zelene „uložené"
      # nikdy neobjavilo nad podhodnotenou alebo zápornou sumou.
      # 1b-3 (review P2-1): `collected` je nepovinne — duplicitna identita je
      # dalsi dovod, preco cena ponuky nemusi sediet (kovanie uctovane na
      # vlastnika sa zapocita raz), takze patri do TOHO ISTEHO zoznamu, nie do
      # zvlastneho sufixu: rozhoduje aj o farbe statusu.
      def cp_warnings(cp, budget, hits, collected = nil)
        c = cp.is_a?(Hash) ? cp : {}
        totals = budget.is_a?(Hash) && budget['totals'].is_a?(Hash) ? budget['totals'] : {}
        out = []
        dups = Validation.duplicate_identities(Array(collected.is_a?(Hash) ? collected[:identities] : nil))
        unless dups.empty?
          ids = dups.map { |_kind, id, _n| id }
          shown = ids.first(3).join(', ')
          more = ids.length > 3 ? " a ďalšie #{ids.length - 3}" : ''
          out << "v modeli sú kusy so spoločným ID (#{shown}#{more}) — kovanie účtované na " \
                 'vlastníka (napr. TipOn) sa započíta len raz; pozri Kontrolu'
        end
        miss = totals['unknown_count_in_total'].to_i
        if miss.positive?
          out << "#{miss} riadkov rozpočtu nemá cenu — suma ponuky je PODHODNOTENÁ " \
                 '(položky v špecifikácii sú, v cene nie)'
        end
        if c['assembly_negative']
          out << "„Nábytková zostava“ vyšla záporná (#{fmt_eur(c['assembly'])}) — " \
                 'samostatné riadky prevyšujú rozpočet'
        end
        out << "CP nesedí s rozpočtom o #{fmt_eur(c['diff'])}" if c['consistent'] == false
        unless Array(hits).empty?
          terms = hits.map { |h| h['term'] }.uniq.first(5).join(', ')
          out << "v dokumente ostali interné pojmy (#{terms}) — oprav názvy a exportuj znova"
        end
        out
      end

      def cp_status(cp, spec, target, warnings)
        c = cp.is_a?(Hash) ? cp : {}
        items = spec.is_a?(Hash) ? spec['item_count'].to_i : 0
        msg = "Cenová ponuka uložená: #{fmt_eur(c['total'])} · #{c['rows'].to_a.length} riadkov · " \
              "špecifikácia #{items} položiek → #{target}"
        return msg if Array(warnings).empty?

        "#{msg} · POZOR: #{warnings.join(' · ')}"
      end

      # --- V0.6 E-c: Prepocitat ceny ---------------------------------------
      # Jedno tlacidlo obnovi ceny VSETKYCH poloziek zakazky, ktore maju vazbu
      # na Demos (dosky, ABS, kovanie). Beh riadi SERVER; okno odovzdava:
      #   emit  — ->(event) posle event do TOHO okna (`NX.priceRefresh`),
      #   alive — -> boolean, ci ZIJE TA ISTA instancia okna (GH #140 P2),
      #   after — -> {} refresh ciest po dobehnuti (ceny sa zmenili GLOBALNE).
      def do_price_refresh(model, data, generation:, status:, repush:, emit:, alive:, after:)
        reject = ->(msg) { price_refresh_reject(msg, emit: emit, status: status) }
        unless data['gen'].to_i == generation.to_i
          repush.call
          return reject.call('Rozpočet sa medzitým prepočítal — obnovené, skús znova.')
        end
        guid = data['model_guid'].to_s
        if !guid.empty? && guid != model_guid(model)
          repush.call
          return reject.call('Model sa medzitým prepol — obnovené, skús znova.')
        end
        return reject.call('Prepočet cien už beží.') if PriceRefresh.running?

        targets = price_refresh_targets(model, data)
        if targets.empty?
          repush.call
          return reject.call('Nie je čo obnoviť — položka už nie je v rozpočte alebo nemá väzbu na Demos.')
        end
        pid = PriceRefresh.run(targets, alive: alive,
                                        emit: price_refresh_emit(emit: emit, status: status, after: after))
        return reject.call('Prepočet cien sa nepodarilo spustiť.') if pid.nil?
        # GH #140 P2: beh mohol dobehnut UZ TERAZ (synchronne — napr. bez
        # sietoveho transportu alebo same chybne vazby). Vtedy status uz nesie
        # VYSLEDOK a „Sťahujem…" by ho prepisalo klamlivym priebehom.
        return if PriceRefresh.running_pid != pid

        status.call("Sťahujem ceny z Demosu (#{targets.length}) — medzi položkami je 3 s pauza (pravidlo Demosu).")
      end

      # GH #140 P2: okno prepne modal do „bezi" HNED po kliku (odpoved servera
      # je asynchronna). Kazde odmietnutie startu preto musi poslat TERMINALNY
      # event — inak by progres aj tlacidlo ostali zamknute a Zrusit by nemalo
      # co zrusit (ziadny beh na serveri neexistuje).
      def price_refresh_reject(msg, emit:, status:)
        emit.call('type' => 'rejected', 'error' => msg)
        status.call(msg, true)
      end

      def price_refresh_emit(emit:, status:, after:)
        lambda do |event|
          emit.call(event)
          next unless event['type'] == 'complete'

          after_price_refresh(event['report'], status: status, after: after)
        end
      end

      # Po dobehnuti: cerstvy rozpocet (sumy AJ pas cenovej cerstvosti) + refresh
      # ostatnych okien nad katalogom — ceny sa prave zmenili globalne.
      def after_price_refresh(report, status:, after:)
        begin
          after.call
        rescue StandardError => e
          Engine.log_error(e, 'ProductionCore.after_price_refresh refresh')
        end
        status.call(price_refresh_status(report), price_refresh_report_error?(report))
      rescue StandardError => e
        Engine.log_error(e, 'ProductionCore.after_price_refresh')
      end

      # Zrusenie: dalsie polozky sa uz nestiahnu, rozbehnuta dobehne a zapise
      # sa (jej cena je realne overena — zahodit ju by bolo horsie).
      def price_refresh_cancel(status:)
        if PriceRefresh.cancel!
          status.call('Prepočet cien sa ukončí po dobehnutí prebiehajúcej položky.')
        else
          status.call('Žiadny prepočet cien nebeží.')
        end
      end

      # Ciele = viazane polozky POUZITE v CERSTVOM rozpocte. kind+id (jeden
      # riadok zo zoznamu starych cien) sa pouzije len ako FILTER nad tymto
      # serverovym zoznamom — polozka mimo rozpoctu sa nefetchuje.
      def price_refresh_targets(model, data)
        collected = fresh_collect(model)
        bom = Bom.compute(collected)
        budget = budget_payload(model, bom, collected)
        return [] unless budget

        all = PriceRefresh.targets_from_budget(budget)
        kind = data['kind'].to_s
        id = data['id'].to_s
        return all if kind.empty? || id.empty?

        all.select { |t| t['kind'] == kind && t['id'] == id }
      end

      def price_refresh_report_error?(report)
        report.is_a?(Hash) && report['errors'].to_i.positive?
      end

      def price_refresh_status(report)
        # Vetne tvary bez sklonovania poctu (status je jednoriadkovy; plne
        # sklonovane zhrnutie ukazuje report v okne).
        r = report.is_a?(Hash) ? report : {}
        parts = ["zmenené #{r['changed'].to_i}", "bez zmeny #{r['unchanged'].to_i}"]
        parts << "chyby #{r['errors'].to_i}" if r['errors'].to_i.positive?
        parts << "zrušené (preskočené #{r['skipped'].to_i})" if r['cancelled']
        "Prepočet cien hotový — #{parts.join(' · ')}."
      end
    end
  end
end
