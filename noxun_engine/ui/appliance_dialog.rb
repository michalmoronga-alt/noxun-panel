# frozen_string_literal: true
# Noxun Engine — SERVEROVA AUTORITA SEKCIE SPOTREBICE (`appl`) v okne STUDIO.
#
# S1-A2: sekcia NEMA a nikdy nemala vlastne okno (vzor `HardwareCatalogDialog`
# po ŠT-3a-2, `RulesDialog`, `TemplatesDialog`) — ziadny `DLG_KEY`, ziadny
# `HtmlDialog`, ziadna polozka menu, ktora by otvarala satelit. Jedine UI
# katalogu spotrebicov je SEKCIA `appl` okna ŠTÚDIO; tento modul je jej
# serverova strana a JEDINY vstup do `ApplianceCatalog`.
#
# CO SEM PATRI a co nie:
#   * SEM: whitelist akcii sekcie, zlozenie payloadov (strom, karta, texty
#     poli), preklad statusov katalogu na hlasky a chyby pri poli modalu.
#   * NIE: pravidla katalogu (validacia, `rev`, prilohy, seed) — tie ziju
#     VYHRADNE v `core/appliance_catalog.rb`; UI ich nesmie obchadzat ani
#     duplikovat (druha kopia by sa casom rozisla).
#   * NIE: zakazka, Inspector, Rozpocet, cena. Pohlad „V zákazke" je v tejto
#     davke PRIZNANY placeholder (D-78) a zapne ho S1-B.
#
# TRI KONTRAKTY, ktore su dolezitejsie nez vzhlad:
#   1. SERVER SKLADA PORADIE. Strom (kategorie v poradi `CATEGORIES`, polozky
#      podla nazvu cez `ApplianceCatalog.sort_records`), POCTY aj podtitul
#      riadku robi Ruby; JS kresli presne to, co dostal, a NIKDY nic nedopĺňa
#      ani nepreskladava (ten isty kontrakt ako `HardwareCatalogDialog#handle_tree`).
#   2. ECHO NEDVIHA GENERACIU OKNA. Zmena katalogu spotrebicov v A2 nemeni
#      ZIADNE cislo zakazky (kusovnik, rozpocet, nakup), takze rozkliknuty
#      riadok Kusovnika ani rozrobeny export nesmu po ulozeni modelu zastarat.
#      Posiela sa teda `NX.applTree` + `NX.applCard`, nie `push_state`.
#      (Po S1-B sa to prehodnoti — vtedy uz katalog do zakazky vstupuje.)
#   3. ODPOVED IDE TOMU, KTO SA PYTAL. Pocas synchronneho volania sekcie drzi
#      adresata `with_client(sink)`; mimo neho je adresatom Studio
#      (`StudioDialog.appl_js`). `ensure` je povinne — vynimka v handleri
#      nesmie nechat sink viset a poslat NASLEDUJUCU odpoved do cudzieho kanala.
require 'json'
require 'tmpdir'
require 'uri'

module Noxun
  module Engine
    module ApplianceDialog
      # UZAVRETY whitelist akcii, ktore smie poslat SEKCIA `appl`. Klient
      # posiela iba MENO akcie — co sa smie zavolat, rozhoduje SERVER
      # (HTML ani JS nie su ochrana).
      #
      # `ready` v zozname NIE JE (a byt nemoze): Studio registruje callbacky
      # pod TYMI ISTYMI menami, takze `ready` by prepisal jeho vlastny — okno
      # by prestalo dostavat prvy push a ostalo by prazdne. Prvotny stav
      # sekcie preto nesie `push_state` Studia pod klucom `appl`.
      SECTION_ACTIONS = %w[
        appl_tree appl_card appl_create appl_patch appl_delete appl_restore
        appl_attach appl_thumbnail appl_remove_attachment
        appl_open_url appl_open_attachment appl_leave
      ].freeze

      # Skupina vyradenych zaznamov je v strome POSLEDNA a ma vlastny kod —
      # tombstone patri do kategorie rovnako ako zivy zaznam, ale pouzivatel
      # ho hlada na jednom mieste („co som vyradil"), nie rozsypany po strome.
      DELETED_GROUP = 'deleted'

      # Nadpisy blokov karty. `front` sa vola INAK podla kategorie — jazyk
      # listov je tu autoritou (Bosch: Gerätemaße · Nischenmaße · Überstände).
      FRONT_TITLES = {
        'fridge' => 'Dvere spotrebiča (zdola)',
        'oven' => 'Čelo a presahy',
        'microwave' => 'Čelo a presahy',
        'dishwasher' => 'Nábytkové čelo (evidencia)',
        'hob' => 'Doska a výrez',
        'sink' => 'Drez a výrez',
        'hood' => 'Výrez a odvod',
        'other' => 'Čelo'
      }.freeze

      BLOCK_ICONS = { 'body' => 'box', 'niche' => 'cabinet',
                      'front' => 'door', 'install' => 'settings' }.freeze

      # RIADOK KARTY: [popisok, tvar, blok, *cesty poli].
      #   :xyz   — „a × b × c"      :pair  — „a × b"       :one — jedno cislo
      #   :range — „min – max" (jednostranny rozsah sa prizna slovom)
      #   :enum  — hodnota z `ENUM_FIELDS`, preklada `ENUM_LABELS`
      # Blok sa uvadza pri KAZDOM riadku, lebo niektore riadky patria vizualne
      # inam nez datovo: vyska tela umyvacky je ROZSAH (nastavitelne nohy),
      # takze v datach zije v `install`, ale citat sa ma pri tele.
      ROW_KIND_SEPARATOR = { xyz: ' × ', pair: ' × ' }.freeze

      NICHE_ROWS = [
        ['šírka', :range, 'niche', 'width_min', 'width_max'],
        ['výška', :range, 'niche', 'height_min', 'height_max'],
        ['hĺbka', :range, 'niche', 'depth_min', 'depth_max']
      ].freeze

      BODY_XYZ = [['Š × V × H', :xyz, 'body', 'width', 'height', 'depth']].freeze

      OVEN_ROWS = {
        'body' => BODY_XYZ,
        'niche' => NICHE_ROWS,
        'front' => [
          ['čelo Š × V', :pair, 'front', 'width', 'height'],
          ['hrúbka čela', :one, 'front', 'thickness'],
          ['presah hore', :one, 'front', 'overhang_top'],
          ['presah dole', :one, 'front', 'overhang_bottom'],
          ['presah voči', :enum, 'front', 'overhang_ref'],
          ['medzera pod čelom', :one, 'front', 'vent_gap_below']
        ],
        'install' => []
      }.freeze

      ROWS = {
        'fridge' => {
          'body' => BODY_XYZ,
          'niche' => NICHE_ROWS,
          'front' => [
            ['spodok', :one, 'front', 'door_bottom_offset'],
            ['dolné dvere', :one, 'front', 'door_lower'],
            ['medzera', :one, 'front', 'door_gap'],
            ['horné dvere', :one, 'front', 'door_upper'],
            ['nábytkové dvere z výkresu', :range, 'front',
             'furniture_doors.lower_min', 'furniture_doors.lower_max'],
            ['referenčná škára', :one, 'front', 'furniture_doors.gap_ref']
          ],
          'install' => [
            ['dvere', :enum, 'install', 'door_system'],
            ['strana pántu', :enum, 'install', 'hinge_side'],
            ['max hmotnosť nábyt. dverí', :one, 'install', 'door_weight_max'],
            ['max hrúbka nábyt. dverí', :one, 'install', 'door_thickness_max']
          ]
        },
        'oven' => OVEN_ROWS,
        'microwave' => OVEN_ROWS,
        'dishwasher' => {
          'body' => [
            ['Š × H', :pair, 'body', 'width', 'depth'],
            ['výška tela', :range, 'install', 'body_height_min', 'body_height_max']
          ],
          'niche' => NICHE_ROWS,
          'front' => [
            ['šírka čela', :one, 'front', 'width'],
            ['max výška čela', :one, 'front', 'height_max'],
            ['hmotnosť čela', :range, 'front', 'weight_min', 'weight_max']
          ],
          'install' => [
            ['trieda šírky', :enum, 'install', 'dishwasher_class'],
            ['sokel', :range, 'install', 'plinth_min', 'plinth_max']
          ]
        },
        'hob' => {
          'body' => BODY_XYZ,
          'niche' => NICHE_ROWS,
          'front' => [
            ['vonkajší Š × H', :pair, 'front', 'outer_width', 'outer_depth'],
            ['výrez Š', :one, 'front', 'cutout_width'],
            ['výrez H', :range, 'front', 'cutout_depth', 'cutout_depth_max'],
            ['montážna hĺbka', :one, 'front', 'mount_depth'],
            ['min hrúbka dosky', :one, 'front', 'worktop_min']
          ],
          'install' => []
        },
        'sink' => {
          'body' => BODY_XYZ,
          'niche' => NICHE_ROWS,
          'front' => [
            ['vonkajší Š × H', :pair, 'front', 'outer_width', 'outer_depth'],
            ['výrez Š × H', :pair, 'front', 'cutout_width', 'cutout_depth'],
            ['rádius rohu', :one, 'front', 'radius'],
            ['hĺbka vane', :one, 'front', 'bowl_depth'],
            ['min šírka skrinky', :one, 'front', 'min_cabinet_width'],
            ['montáž', :enum, 'front', 'mount']
          ],
          'install' => []
        },
        'hood' => {
          'body' => BODY_XYZ,
          'niche' => NICHE_ROWS,
          'front' => [
            ['min šírka skrinky', :one, 'front', 'min_cabinet_width'],
            ['výrez do dna Š × H', :pair, 'front', 'cutout_width', 'cutout_depth'],
            ['odvod Ø', :one, 'front', 'duct_diameter']
          ],
          'install' => []
        },
        'other' => {
          'body' => BODY_XYZ,
          'niche' => NICHE_ROWS,
          'front' => [],
          'install' => []
        }
      }.freeze

      # POPISKY POLI PRE MODAL — po BLOKOCH. Karta sklada riadky (`ROWS`, kde
      # „Š × V × H" je JEDEN riadok z troch cisel), formular ma jeden vstup na
      # pole, takze potrebuje meno KAZDEHO cisla zvlast. Su to dve tabulky
      # s roznou ulohou nad tym istym zoznamom poli — poradie aj vyber poli
      # urcuje VZDY `ROWS`, takze karta a formular nikdy neukazu ine polia.
      # Kluc je cesta v ramci bloku (vnorene pole nesie bodku), meno pola je
      # v ramci bloku jednoznacne aj naprie kategoriami.
      FIELD_LABELS = {
        'body' => { 'width' => 'šírka', 'height' => 'výška', 'depth' => 'hĺbka' },
        'niche' => { 'width_min' => 'šírka min', 'width_max' => 'šírka max',
                     'height_min' => 'výška min', 'height_max' => 'výška max',
                     'depth_min' => 'hĺbka min', 'depth_max' => 'hĺbka max' },
        'front' => { 'width' => 'šírka čela', 'height' => 'výška čela',
                     'height_max' => 'max výška čela', 'thickness' => 'hrúbka čela',
                     'overhang_top' => 'presah hore', 'overhang_bottom' => 'presah dole',
                     'overhang_ref' => 'presah voči', 'vent_gap_below' => 'medzera pod čelom',
                     'weight_min' => 'hmotnosť min', 'weight_max' => 'hmotnosť max',
                     'door_bottom_offset' => 'spodok', 'door_lower' => 'dolné dvere',
                     'door_gap' => 'medzera', 'door_upper' => 'horné dvere',
                     'furniture_doors.lower_min' => 'nábyt. dvere dolné min',
                     'furniture_doors.lower_max' => 'nábyt. dvere dolné max',
                     'furniture_doors.gap_ref' => 'referenčná škára',
                     'outer_width' => 'vonkajšia šírka', 'outer_depth' => 'vonkajšia hĺbka',
                     'cutout_width' => 'výrez šírka', 'cutout_depth' => 'výrez hĺbka',
                     'cutout_depth_max' => 'výrez hĺbka max', 'radius' => 'rádius rohu',
                     'mount' => 'montáž', 'min_cabinet_width' => 'min šírka skrinky',
                     'bowl_depth' => 'hĺbka vane', 'mount_depth' => 'montážna hĺbka',
                     'worktop_min' => 'min hrúbka dosky', 'duct_diameter' => 'odvod Ø' },
        'install' => { 'door_system' => 'dvere', 'hinge_side' => 'strana pántu',
                       'door_weight_max' => 'max hmotnosť nábyt. dverí',
                       'door_thickness_max' => 'max hrúbka nábyt. dverí',
                       'dishwasher_class' => 'trieda šírky',
                       'plinth_min' => 'sokel min', 'plinth_max' => 'sokel max',
                       'body_height_min' => 'výška tela min', 'body_height_max' => 'výška tela max' }
      }.freeze

      # SK popisky enumov. Kody su identita (`ENUM_FIELDS` v katalogu), toto je
      # jediny preklad pre KARTU aj MODAL — dve mapy by sa rozisli.
      ENUM_LABELS = {
        'overhang_ref' => { 'body' => 'telu', 'niche' => 'nike' },
        'mount' => { 'top' => 'na dosku', 'under' => 'pod dosku' },
        'door_system' => { 'sliding' => 'posuvné lišty', 'door_on_door' => 'door-on-door' },
        'hinge_side' => { 'left' => 'ľavá', 'right' => 'pravá', 'reversible' => 'otočná' },
        'dishwasher_class' => { '600' => '600 · 60 cm', '450' => '450 · 45 cm' }
      }.freeze

      # Polia v kilogramoch maju inu jednotku nez zvysok karty.
      UNIT_KG = 'kg'
      UNIT_MM = 'mm'

      # LAZY KANAL MINIATUR. Obrazok je radovo vacsi nez cely strom, takze
      # `data:` URI chodi LEN pre prilohy druhu `image`/`thumbnail`, LEN na
      # vyziadanie karty a LEN pre tie, ktore klient EST NEMA (`have`).
      # Nazov ulozenej prilohy je NEMENNY a nikdy sa nerecykluje (kontrakt
      # A1), takze klientska cache podla `id` prilohy nemoze zastarat.
      THUMB_MAX_PX = 96
      # Strop pre ODOSLANE bajty. Plati pre obe cesty (zmenseny aj povodny
      # obrazok) — data URI nad tento strop uz nie je nahlad, ale prenos.
      THUMB_MAX_BYTES = 256 * 1024
      # Najviac miniatur v JEDNEJ odpovedi. Karta s 20 obrazkami by inak
      # poslala 20 × 256 kB v jednom nadychu (lekcia `TPL_ASK_BATCH`).
      THUMB_BATCH = 6
      THUMB_MAGIC = {
        'png' => "\x89PNG".b, 'jpg' => "\xFF\xD8\xFF".b,
        'jpeg' => "\xFF\xD8\xFF".b, 'webp' => 'RIFF'.b
      }.freeze
      THUMB_MIME = { 'png' => 'image/png', 'jpg' => 'image/jpeg',
                     'jpeg' => 'image/jpeg', 'webp' => 'image/webp' }.freeze

      # Filter systemoveho dialogu `UI.openpanel` (JEDEN subor naraz).
      ATTACH_FILTER = 'Listy a obrázky|*.pdf;*.jpg;*.jpeg;*.png;*.webp||'

      class << self
        # --- vstup sekcie -----------------------------------------------------

        def dispatch(name, payload, sink)
          key = name.to_s
          unless SECTION_ACTIONS.include?(key)
            return sink.call(status_script('Neznáma akcia katalógu spotrebičov.', true))
          end

          with_client(sink) { run_section_action(key, payload) }
        rescue StandardError => e
          Engine.log_error(e, "ApplianceDialog.dispatch #{name}")
          sink.call(status_script("Chyba: #{e.message}", true))
        end

        def run_section_action(key, payload)
          case key
          when 'appl_tree'              then handle_tree(payload)
          when 'appl_card'              then handle_card(payload)
          when 'appl_create'            then handle_create(payload)
          when 'appl_patch'             then handle_patch(payload)
          when 'appl_delete'            then handle_delete(payload)
          when 'appl_restore'           then handle_restore(payload)
          when 'appl_attach'            then handle_attach(payload)
          when 'appl_thumbnail'         then handle_thumbnail(payload)
          when 'appl_remove_attachment' then handle_remove_attachment(payload)
          when 'appl_open_url'          then handle_open_url(payload)
          when 'appl_open_attachment'   then handle_open_attachment(payload)
          when 'appl_leave'             then handle_leave
          end
        end

        # Presmerovanie odpovedi na cas JEDNEHO volania (vzor
        # `HardwareCatalogDialog.with_client`). `ensure` je povinne.
        def with_client(sink)
          prev = @client_sink
          @client_sink = sink
          yield
        ensure
          @client_sink = prev
        end

        def js(script)
          sink = @client_sink
          return sink.call(script) if sink

          studio_js(script)
        end

        # Kanal SEKCIE. `js` Studia je private (patri jeho kanalu), preto
        # tenky verejny most `appl_js` — vzor `StudioDialog.hw_js`.
        def studio_js(script)
          return false unless defined?(StudioDialog)

          StudioDialog.appl_js(script)
        rescue StandardError => e
          Engine.log_error(e, 'ApplianceDialog.studio_js')
          false
        end

        def status_script(msg, error = false)
          "AP.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})"
        end

        def set_status(msg, error = false)
          js(status_script(msg, error))
        end

        # --- stav POHLADU sekcie ---------------------------------------------
        #
        # Filter (hladanie + „vyradené") je stav KLIENTA, ale echo po zapise ho
        # musi respektovat — inak by ulozenie zaznamu zhodilo pouzivatelovi
        # rozpisane hladanie a strom by sa pred nim „roztiahol". Server si ho
        # preto pamata presne v tom tvare, v akom ho klient naposledy poslal.
        def view_query
          @view_query.to_s
        end

        def view_deleted?
          @view_deleted == true
        end

        def view_gen
          @view_gen.to_i
        end

        # Odchod zo sekcie ZABUDNE filter. Bez toho by najblizsi PLNY push
        # (prepnutie dokumentu, prepocet) nakreslil strom zuzeny hladanim,
        # ktore pouzivatel uz davno nevidi — a vyzeralo by to ako prazdny
        # katalog. `selected` sa drzi na KLIENTOVI (pamat okna), server ho
        # nepotrebuje.
        def handle_leave
          @view_query = ''
          @view_deleted = false
          @view_gen = 0
          nil
        end

        # --- payload sekcie (prvotny stav v `push_state`) ---------------------

        def section_payload
          tree_payload(view_query, view_deleted?, view_gen)
        rescue StandardError => e
          Engine.log_error(e, 'ApplianceDialog.section_payload')
          nil
        end

        # --- STROM ------------------------------------------------------------

        def handle_tree(payload)
          data = parse(payload)
          @view_query = data['query'].to_s
          @view_deleted = data['include_deleted'] == true
          @view_gen = data['gen'].to_i
          tree = tree_payload(view_query, view_deleted?, view_gen)
          # FORMULAR (polia modalu pre VSETKY kategorie) chodi LEN na vyziadanie:
          # klient si ho vypyta raz za okno a drzi ho. V kazdom pushi by to bolo
          # niekolko kB navyse pri kazdom prepocte kusovnika (lekcia `mat`/`hw`
          # zapadiek `full_pending`).
          tree['form'] = form_payload if data['form'] == true
          js("NX.applTree(#{tree.to_json})")
        end

        # `gen` je generacia dotazu KLIENTA a server ju len ECHUJE: hladanie je
        # debounced a odpovede chodia asynchronne, takze pomalsie kolo by inak
        # prepisalo cerstvejsi strom (vzor `HardwareCatalogDialog#handle_tree`).
        def tree_payload(query, include_deleted, gen)
          status, info = ApplianceCatalog.search(query, include_deleted: include_deleted)
          rows = status == :ok ? Array(info[:records]) : []
          live = rows.reject { |r| ApplianceCatalog.deleted?(r) }
          gone = rows.select { |r| ApplianceCatalog.deleted?(r) }
          groups = ApplianceCatalog::CATEGORIES.map do |code|
            items = live.select { |r| r['category'].to_s == code }
            { 'code' => code, 'label' => ApplianceCatalog.category_label(code),
              'total' => items.length, 'items' => items.map { |r| tree_item(r) } }
          end
          unless gone.empty?
            groups << { 'code' => DELETED_GROUP, 'label' => 'Vyradené',
                        'total' => gone.length, 'items' => gone.map { |r| tree_item(r) } }
          end
          { 'gen' => gen.to_i, 'query' => query.to_s, 'include_deleted' => include_deleted == true,
            'groups' => groups, 'total' => live.length, 'deleted_total' => gone.length,
            'seed_total' => live.count { |r| r['seed'] == true },
            'categories' => category_options }.merge(state_payload)
        end

        # Kategorie pre select modalu — kod je identita, popisok jediny zdroj
        # (`CATEGORY_LABELS`); klient ziadnu vlastnu mapu nema.
        def category_options
          ApplianceCatalog::CATEGORIES.map { |c| [c, ApplianceCatalog.category_label(c)] }
        end

        # Stav katalogu ide v KAZDOM payloade sekcie — banner nad stromom aj
        # vypnute zapisy sa nesmu rozist s tym, co server naozaj dovoli.
        def state_payload
          { 'state' => ApplianceCatalog.state.to_s,
            'state_reason' => ApplianceCatalog.state_reason.to_s,
            'writable' => ApplianceCatalog.state == :ok }
        rescue StandardError => e
          Engine.log_error(e, 'ApplianceDialog.state_payload')
          # FAIL-CLOSED: nezistitelny stav = ziadne zapisy (lepsie nez tlacidla,
          # ktore vzdy skoncia chybou).
          { 'state' => 'read_only', 'state_reason' => 'stav katalógu sa nedá zistiť',
            'writable' => false }
        end

        def tree_item(rec)
          man = rec['manufacturer'].to_s.strip
          { 'id' => rec['id'].to_s, 'name' => rec['name'].to_s,
            'manufacturer' => man,
            # Zobrazovany nazov riadku sklada SERVER (jedno miesto) — klient
            # nelepi „vyrobca + model" po svojom.
            'title' => man.empty? ? rec['name'].to_s : "#{man} #{rec['name']}",
            'category' => rec['category'].to_s,
            'sub' => summary_line(rec), 'seed' => rec['seed'] == true,
            'deleted' => ApplianceCatalog.deleted?(rec) }
        end

        # PODTITUL riadku stromu sklada SERVER (kontrakt „JS nic nedopĺňa").
        # Je to JEDNA veta o tom, co model urcuje: nika (zabudovanie), vyrez
        # (doska) alebo trieda (umyvacka) — teda to, podla coho sa model
        # v strome pozna.
        def summary_line(rec)
          dims = rec['dims'].is_a?(Hash) ? rec['dims'] : {}
          parts = [summary_dims(rec['category'].to_s, dims)].reject { |s| s.to_s.empty? }
          parts << (rec['seed'] == true ? 'seed' : 'ručný')
          parts << 'vyradený' if ApplianceCatalog.deleted?(rec)
          parts.join(' · ')
        end

        def summary_dims(category, dims)
          case category
          when 'hob', 'sink'
            cut = dims['front'].is_a?(Hash) ? dims['front'] : {}
            pair = combo([cut['cutout_width'], cut['cutout_depth']], ' × ')
            pair.empty? ? '' : "výrez #{pair}"
          when 'hood'
            cut = dims['front'].is_a?(Hash) ? dims['front'] : {}
            pair = combo([cut['cutout_width'], cut['cutout_depth']], ' × ')
            pair.empty? ? '' : "výrez do dna #{pair}"
          else
            niche = dims['niche'].is_a?(Hash) ? dims['niche'] : {}
            trio = [range_text(niche['width_min'], niche['width_max']),
                    range_text(niche['height_min'], niche['height_max']),
                    range_text(niche['depth_min'], niche['depth_max'])].reject(&:empty?)
            trio.empty? ? '' : "nika #{trio.join(' × ')}"
          end
        end

        # --- KARTA ------------------------------------------------------------

        def handle_card(payload)
          data = parse(payload)
          id = data['id'].to_s
          have = data['have'].is_a?(Array) ? data['have'].map(&:to_s) : []
          status, info = ApplianceCatalog.find(id)
          unless status == :ok
            js('NX.applCard(null)')
            return set_status(info[:message].to_s, true)
          end

          js("NX.applCard(#{card_payload(info[:record], have: have, thumbs: data['thumbs'] == true).to_json})")
        end

        # `thumbs: false` = karta BEZ obrazkov (echo po zapise). Klient si
        # miniatury drzi v cache podla `id` prilohy a dopyta sa na chybajuce
        # sam — echo tak nikdy neposle stovky kB len preto, ze sa zmenil nazov.
        def card_payload(rec, have: [], thumbs: false)
          category = rec['category'].to_s
          specs = ROWS[category] || ROWS['other']
          blocks = ApplianceCatalog::DIM_BLOCKS.map do |block|
            { 'key' => block, 'title' => block_title(block, category),
              'icon' => BLOCK_ICONS[block],
              'rows' => Array(specs[block]).map { |spec| card_row(spec, rec) } }
          end
          { 'id' => rec['id'].to_s, 'rev' => rec['rev'].to_s,
            'name' => rec['name'].to_s, 'manufacturer' => rec['manufacturer'].to_s,
            'category' => category, 'category_label' => ApplianceCatalog.category_label(category),
            'seed' => rec['seed'] == true, 'deleted' => ApplianceCatalog.deleted?(rec),
            'note' => rec['note'].to_s,
            'blocks' => blocks,
            'shop_urls' => url_list(rec['shop_urls']),
            'sheet_urls' => url_list(rec['sheet_urls']),
            'attachments' => attachment_list(rec),
            'thumbs' => thumbs ? thumbs_for(rec, have) : {},
            'fields' => modal_fields(rec) }.merge(state_payload)
        end

        def block_title(block, category)
          case block
          when 'body' then 'Telo (rozmery spotrebiča)'
          when 'niche' then 'Nika (výklenok v skrinke)'
          when 'install' then 'Montáž'
          else FRONT_TITLES[category] || FRONT_TITLES['other']
          end
        end

        # RIADOK karty. `value` = hotovy text alebo `nil` (= „list to nekótuje").
        # `derived` hovori, ze hodnota je odvodena, nie z listu — klient k nej
        # dokresli „(odvodené)". Rozhodovanie o oboch znamienkach je na jednom
        # mieste (tu), kreslenie na druhom (JS).
        def card_row(spec, rec)
          label, kind, block, *fields = spec
          values = fields.map { |f| dim_value(rec, block, f) }
          { 'label' => label, 'value' => row_text(kind, values, fields),
            'unit' => row_unit(kind, fields),
            'derived' => fields.any? { |f| derived?(rec, block, f) } }
        end

        def row_text(kind, values, fields)
          case kind
          when :range then nil_if_empty(range_text(values[0], values[1]))
          when :enum then nil_if_empty(enum_label(fields.first, values.first))
          when :one then values.first.nil? ? nil : fmt_mm(values.first)
          else nil_if_empty(combo(values, ROW_KIND_SEPARATOR[kind] || ' × '))
          end
        end

        def row_unit(kind, fields)
          return nil if kind == :enum
          return UNIT_KG if fields.any? { |f| ApplianceCatalog::KG_FIELDS.include?(leaf(f)) }

          UNIT_MM
        end

        # Cesta pola moze byt vnorena (`furniture_doors.lower_min`).
        def dim_value(rec, block, field)
          dims = rec['dims'].is_a?(Hash) ? rec['dims'] : {}
          node = dims[block]
          field.to_s.split('.').each do |seg|
            return nil unless node.is_a?(Hash)

            node = node[seg]
          end
          node
        end

        def derived?(rec, block, field)
          list = rec['derived']
          return false unless list.is_a?(Array)

          list.include?("#{block}.#{field}")
        end

        def leaf(field)
          field.to_s.split('.').last.to_s
        end

        def enum_label(field, value)
          return '' if value.nil?

          map = ENUM_LABELS[leaf(field)] || {}
          map[value.to_s] || value.to_s
        end

        # „min 560" / „560 – 568" / „max 568" — jednostranny rozsah sa PRIZNA
        # slovom; holé číslo by klamalo o tom, ktorý koniec výrobca kótuje.
        def range_text(min, max)
          return '' if min.nil? && max.nil?
          return "min #{fmt_mm(min)}" if max.nil?
          return "max #{fmt_mm(max)}" if min.nil?
          return fmt_mm(min) if min.to_f == max.to_f

          "#{fmt_mm(min)} – #{fmt_mm(max)}"
        end

        def combo(values, sep)
          return '' if values.all?(&:nil?)

          values.map { |v| v.nil? ? '—' : fmt_mm(v) }.join(sep)
        end

        def nil_if_empty(text)
          text.to_s.empty? ? nil : text.to_s
        end

        # Cele mm bez desatin, inak 1 desatinne miesto (slovenska ciarka) —
        # ten isty tvar ako `Bom.fmt_mm` / `HardwareRules.fmt_mm`.
        def fmt_mm(v)
          f = v.to_f
          (f - f.round).abs < 0.05 ? f.round.to_s : format('%.1f', f).tr('.', ',')
        end

        # Adresa ide klientovi ako POPISOK + URL; otvara ju server
        # (`appl_open_url`), takze klient ziadne `href` nema a nemoze omylom
        # navigovat cele okno HtmlDialogu na cudziu stranku.
        def url_list(raw)
          Array(raw).map { |u| { 'url' => u.to_s, 'label' => url_label(u) } }
        end

        def url_label(url)
          host = URI.parse(url.to_s).host.to_s
          host.empty? ? url.to_s : host.sub(/\Awww\./, '')
        rescue StandardError
          url.to_s
        end

        def attachment_list(rec)
          items = rec['attachments'].is_a?(Array) ? rec['attachments'] : []
          items.map do |it|
            ext = ApplianceCatalog.attach_ext(it['file'])
            { 'id' => it['id'].to_s, 'kind' => it['kind'].to_s, 'name' => it['name'].to_s,
              'ext' => ext, 'image' => THUMB_MIME.key?(ext) && it['kind'].to_s != 'sheet',
              'thumbnail' => it['kind'].to_s == 'thumbnail' }
          end
        end

        # --- lazy miniatury ----------------------------------------------------

        def thumbs_for(rec, have)
          items = rec['attachments'].is_a?(Array) ? rec['attachments'] : []
          out = {}
          items.each do |it|
            break if out.length >= THUMB_BATCH
            next unless %w[image thumbnail].include?(it['kind'].to_s)
            next if have.include?(it['id'].to_s)

            status, info = ApplianceCatalog.attachment_path_for('id' => rec['id'], 'file' => it['file'])
            # `nil` je PLATNA odpoved „nahlad nebude" — klient si ju zacachuje
            # a uz sa nepyta (vzor zapornej cache `TPL_PNG`).
            out[it['id'].to_s] = status == :ok ? thumb_data_uri(info[:path]) : nil
          end
          out
        end

        # data: URI pre HtmlDialog (CEF nesmie citat subory zo systemu priamo).
        # PRIMARNA cesta je `Sketchup::ImageRep` — zmensi obrazok na
        # `THUMB_MAX_PX`, takze fotka z mobilu preleti mostom ako par kB.
        # Ked ImageRep nie je (headless testy) alebo zlyha, posle sa POVODNY
        # subor, ale LEN ked je pod `THUMB_MAX_BYTES` a ma spravne magic bytes.
        def thumb_data_uri(path)
          return nil unless path && File.file?(path)

          shrunk = shrink_to_png(path)
          return shrunk if shrunk

          ext = ApplianceCatalog.attach_ext(path)
          mime = THUMB_MIME[ext]
          return nil unless mime
          return nil if File.size(path) > THUMB_MAX_BYTES

          bytes = File.binread(path)
          return nil unless magic_ok?(bytes, ext)

          "data:#{mime};base64,#{[bytes].pack('m0')}"
        rescue StandardError => e
          Engine.log_error(e, 'ApplianceDialog.thumb_data_uri')
          nil
        end

        def shrink_to_png(path)
          return nil unless defined?(Sketchup::ImageRep)

          rep = Sketchup::ImageRep.new
          rep.load_file(path)
          w = rep.width.to_i
          h = rep.height.to_i
          return nil if w <= 0 || h <= 0

          scale = [THUMB_MAX_PX.to_f / w, THUMB_MAX_PX.to_f / h, 1.0].min
          small = scale < 1.0 ? rep.resize([(w * scale).round, 1].max, [(h * scale).round, 1].max) : rep
          @thumb_seq = @thumb_seq.to_i + 1
          tmp = File.join(temp_dir, "noxun_appl_thumb_#{Process.pid}_#{@thumb_seq}.png")
          begin
            small.save_file(tmp)
            return nil unless File.file?(tmp) && File.size(tmp) <= THUMB_MAX_BYTES

            "data:image/png;base64,#{[File.binread(tmp)].pack('m0')}"
          ensure
            begin
              File.delete(tmp) if File.file?(tmp)
            rescue StandardError
              nil
            end
          end
        rescue StandardError => e
          # ImageRep NEPOZNA kazdy format (webp, poskodeny subor) — zlyhanie je
          # tu bezny stav, nie chyba: volajuci skusi povodny subor.
          Engine.log("miniatura #{File.basename(path.to_s)}: #{e.class}") if defined?(Engine)
          nil
        end

        def temp_dir
          return Sketchup.temp_dir if defined?(Sketchup) && Sketchup.respond_to?(:temp_dir)

          Dir.tmpdir
        end

        def magic_ok?(bytes, ext)
          magic = THUMB_MAGIC[ext]
          return false unless magic

          b = bytes.to_s
          b = b.dup.force_encoding(Encoding::BINARY) unless b.encoding == Encoding::BINARY
          b.start_with?(magic)
        end

        # --- POLIA MODALU (Nový / Upraviť) -------------------------------------
        #
        # Hodnoty predvyplneneho formulara sklada SERVER a kluc pola je PRESNE
        # ta cesta, ktoru vracia katalog v `info[:field]` (`dims.niche.width_min`).
        # Vdaka tomu je „preklad chyb na kluce modalu" IDENTITA — ziadna druha
        # tabulka mien, ktora by sa pri pridani pola ticho rozisla.
        def modal_fields(rec)
          out = { 'category' => rec['category'].to_s,
                  'manufacturer' => rec['manufacturer'].to_s,
                  'name' => rec['name'].to_s,
                  'note' => rec['note'].to_s,
                  'shop_urls' => Array(rec['shop_urls']).map(&:to_s),
                  'sheet_urls' => Array(rec['sheet_urls']).map(&:to_s) }
          modal_paths(rec['category'].to_s).each do |(block, field)|
            v = dim_value(rec, block, field)
            out["dims.#{block}.#{field}"] = v.nil? ? '' : (v.is_a?(Numeric) ? fmt_mm(v) : v.to_s)
          end
          out
        end

        # FORMULAR modalu pre VSETKY kategorie (`{ kod => [polia] }`). Klient
        # prepina sadu poli pri zmene kategorie bez toho, aby sa pytal servera
        # — a bez druhej tabulky poli na svojej strane.
        def form_payload
          ApplianceCatalog::CATEGORIES.each_with_object({}) { |c, out| out[c] = form_fields(c) }
        end

        # Polia jednej kategorie: skupina (nadpis bloku) + jeden vstup na POLE.
        # Zoznam aj PORADIE urcuje `ROWS` — teda ta ista tabulka, z ktorej sa
        # kresli karta.
        def form_fields(category)
          specs = ROWS[category] || ROWS['other']
          out = []
          ApplianceCatalog::DIM_BLOCKS.each do |block|
            rows = Array(specs[block])
            next if rows.empty?

            out << { 'type' => 'group', 'label' => block_title(block, category) }
            rows.each do |spec|
              _, _, blk, *fields = spec
              fields.each { |f| out << form_field(blk, f) }
            end
          end
          out
        end

        def form_field(block, field)
          enum = ApplianceCatalog::ENUM_FIELDS[leaf(field)]
          base = { 'key' => "dims.#{block}.#{field}",
                   'label' => (FIELD_LABELS[block] || {})[field.to_s] || field.to_s,
                   'block' => block, 'field' => field.to_s }
          return base.merge('type' => 'select', 'options' => enum_options(leaf(field), enum)) if enum

          base.merge('type' => 'text',
                     'unit' => ApplianceCatalog::KG_FIELDS.include?(leaf(field)) ? UNIT_KG : UNIT_MM)
        end

        # Prazdna volba je POVINNA: „neznáme pole = prázdne" plati aj pre enum,
        # takze sa hodnota musi dat ZRUSIT (prazdny retazec = zmaz kluc).
        def enum_options(name, values)
          [['', '—']] + Array(values).map { |v| [v, (ENUM_LABELS[name] || {})[v] || v] }
        end

        # Cesty poli, ktore modal pre danu kategoriu kresli — ako dvojice
        # [blok, cesta]. Cita sa z `form_fields`, takze hodnoty a polia
        # formulara maju JEDEN zdroj.
        def modal_paths(category)
          form_fields(category).reject { |f| f['type'] == 'group' }
                               .map { |f| [f['block'], f['field']] }
        end

        # `field` z katalogu -> kluc pola modalu. Je to IDENTITA (kluce modalu
        # su rovnake cesty), ale existuje ako JEDNO miesto, kde sa da mapovanie
        # zmenit, keby sa tvary raz rozisli.
        def modal_field(field)
          f = field.to_s.strip
          f.empty? ? nil : f
        end

        def field_errors(message, field)
          e = { 'msg' => message.to_s }
          key = modal_field(field)
          e['field'] = key if key
          [e]
        end

        # --- ZAPISY ------------------------------------------------------------

        def handle_create(payload)
          data = parse(payload)
          token = data['token'].to_s
          attrs = attrs_from(data['fields'])
          attrs['category'] = data['fields'].is_a?(Hash) ? data['fields']['category'].to_s : ''
          status, info = ApplianceCatalog.create!(attrs)
          if status == :ok
            rec = info[:record]
            # Novy zaznam sa VYBERIE tym, ze mu echo posle KARTU — klient si
            # `selectedId` berie z nej, takze `applResult` nesie len vysledok
            # zapisu (a nemusi poznat identitu).
            echo(rec['id'])
            set_status("Spotrebič #{rec['name']} pridaný do katalógu.")
            result(true, "Spotrebič #{rec['name']} pridaný do katalógu.", [], 'create', token)
          else
            fail_result(status, info, 'create', token)
          end
        end

        def handle_patch(payload)
          data = parse(payload)
          token = data['token'].to_s
          id = data['id'].to_s
          attrs = attrs_from(data['fields'])
          status, info = ApplianceCatalog.patch!(id, attrs, rev: data['rev'].to_s)
          if status == :ok
            echo(id)
            set_status('Uložené.')
            result(true, 'Uložené.', [], 'patch', token)
          else
            echo(id) if %i[conflict not_found].include?(status)
            fail_result(status, info, 'patch', token)
          end
        end

        def handle_delete(payload)
          data = parse(payload)
          id = data['id'].to_s
          status, info = ApplianceCatalog.delete!(id, rev: data['rev'].to_s)
          if status == :ok
            echo(id)
            set_status("Spotrebič #{info[:record]['name']} vyradený — prílohy ostávajú.")
          else
            echo(id)
            set_status(reason(status, info), true)
          end
        end

        def handle_restore(payload)
          data = parse(payload)
          id = data['id'].to_s
          status, info = ApplianceCatalog.restore!(id, rev: data['rev'].to_s)
          if status == :ok
            echo(id)
            set_status("Spotrebič #{info[:record]['name']} je späť v katalógu.")
          else
            echo(id)
            set_status(reason(status, info), true)
          end
        end

        # PRILOHA: systemovy dialog bezi PRIAMO v callbacku (rovnaka cesta ako
        # `MaterialsDialog.appearance_pick_image` — overene, ze HtmlDialog
        # nezamrzne). Zrusenie (`nil`) NIE JE chyba: nic sa nezapise a okno to
        # povie jednou vetou.
        def handle_attach(payload)
          data = parse(payload)
          id = data['id'].to_s
          unless ApplianceCatalog.state == :ok
            return set_status(ApplianceCatalog.state_reason, true)
          end

          path = pick_attachment
          if path.to_s.strip.empty?
            return set_status('Nič sa nepriložilo.')
          end

          kind = ApplianceCatalog.attach_ext(path) == 'pdf' ? 'sheet' : 'image'
          status, info = ApplianceCatalog.attach!(id, path, kind: kind, rev: data['rev'].to_s)
          echo(id)
          if status == :ok
            set_status("Priložené: #{File.basename(path.to_s)}")
          else
            set_status(reason(status, info), true)
          end
        end

        def pick_attachment
          return nil unless defined?(UI) && UI.respond_to?(:openpanel)

          UI.openpanel('Priložiť súbor', nil, ATTACH_FILTER)
        end

        def handle_thumbnail(payload)
          data = parse(payload)
          id = data['id'].to_s
          status, info = ApplianceCatalog.set_thumbnail!(id, data['attachment_id'].to_s,
                                                        rev: data['rev'].to_s)
          echo(id)
          status == :ok ? set_status('Náhľad nastavený.') : set_status(reason(status, info), true)
        end

        def handle_remove_attachment(payload)
          data = parse(payload)
          id = data['id'].to_s
          status, info = ApplianceCatalog.remove_attachment!(id, data['attachment_id'].to_s,
                                                            rev: data['rev'].to_s)
          echo(id)
          if status == :ok
            set_status('Príloha odobratá zo zoznamu — súbor na disku ostáva.')
          else
            set_status(reason(status, info), true)
          end
        end

        # --- otvaranie ---------------------------------------------------------

        # SCHEMU OVERUJE SERVER. Katalog sice do `shop_urls`/`sheet_urls` pusti
        # len http/https, ale adresa sem chodi z KLIENTA — `UI.openURL` nad
        # `file:` alebo `javascript:` by bol uplne iny druh akcie, nez na aky
        # pouzivatel klikol.
        def handle_open_url(payload)
          data = parse(payload)
          url = data['url'].to_s.strip
          return set_status('Neplatný odkaz — otvárajú sa len http a https adresy.', true) unless http_url?(url)
          unless defined?(UI) && UI.respond_to?(:openURL)
            return set_status('Otvorenie odkazu je dostupné len v SketchUpe.', true)
          end

          UI.openURL(url) ? set_status("Otvorené v prehliadači: #{url_label(url)}")
                          : set_status('Odkaz sa nepodarilo otvoriť.', true)
        end

        def http_url?(url)
          uri = URI.parse(url.to_s)
          uri.is_a?(URI::HTTP) && !uri.host.to_s.strip.empty?
        rescue StandardError
          false
        end

        def handle_open_attachment(payload)
          data = parse(payload)
          status, info = ApplianceCatalog.open_attachment(data['id'].to_s, data['attachment_id'].to_s)
          return set_status('Otvorené.') if status == :ok

          set_status(reason(status, info), true)
        end

        # --- spolocne ----------------------------------------------------------

        def parse(payload)
          data = payload.is_a?(Hash) ? payload : JSON.parse(payload.to_s)
          data.is_a?(Hash) ? data : {}
        rescue StandardError
          {}
        end

        # Vstup MODALU -> atributy katalogu. Kluce `dims.<blok>.<pole>` sa
        # skladaju spat do vnoreneho tvaru; PRAZDNE pole je `nil`, co katalog
        # cita ako „zmaz kluc" (semantika A10) — inak by sa vymazana hodnota
        # ticho vratila pri dalsom ulozeni.
        def attrs_from(fields)
          f = fields.is_a?(Hash) ? fields : {}
          out = {}
          %w[manufacturer name note].each { |k| out[k] = f[k].to_s if f.key?(k) }
          %w[shop_urls sheet_urls].each do |k|
            next unless f.key?(k)

            out[k] = Array(f[k]).map { |v| v.to_s.strip }.reject(&:empty?)
          end
          dims = {}
          f.each do |key, value|
            next unless key.to_s.start_with?('dims.')

            _, block, *rest = key.to_s.split('.')
            next if block.to_s.empty? || rest.empty?

            node = (dims[block] ||= {})
            rest[0..-2].each { |seg| node = (node[seg] ||= {}) }
            node[rest.last] = value.to_s.strip.empty? ? nil : value
          end
          out['dims'] = dims unless dims.empty?
          out
        end

        # ECHO sekcie: strom (s filtrom, ktory klient naposledy poslal) + karta
        # BEZ miniatur. Generacia okna sa NEDVIHA — katalog spotrebicov v A2
        # nemeni ziadne cislo zakazky.
        def echo(selected_id = nil)
          js("NX.applTree(#{tree_payload(view_query, view_deleted?, view_gen).to_json})")
          return if selected_id.to_s.empty?

          status, info = ApplianceCatalog.find(selected_id.to_s)
          payload = status == :ok ? card_payload(info[:record]).to_json : 'null'
          js("NX.applCard(#{payload})")
        rescue StandardError => e
          Engine.log_error(e, 'ApplianceDialog.echo')
        end

        # Modal sa pri odmietnutom zapise NEZATVARA a zamok odoslania odomyka
        # VYHRADNE volajuci (kontrakt D-15) — server preto hlasi OBE vetvy.
        # `token` je identita JEDNEHO odoslania: klient prijme len odpoved,
        # ktora ju nesie spat (vzor `MDH.itemResult`).
        def result(ok, msg, errors, op, token)
          js("NX.applResult(#{ok ? 'true' : 'false'}, #{msg.to_s.to_json}, " \
             "#{Array(errors).to_json}, #{op.to_s.to_json}, #{token.to_s.to_json})")
        end

        def fail_result(status, info, op, token)
          msg = reason(status, info)
          set_status(msg, true)
          field = status == :invalid ? info[:field] : nil
          result(false, msg, field_errors(msg, field), op, token)
        end

        # Hlaska pre pouzivatela. Katalog uz hlasky sklada — tu sa len doplni
        # kontext tam, kde by holy text nepovedal, CO sa nestalo.
        def reason(status, info)
          msg = info.is_a?(Hash) ? info[:message].to_s : ''
          case status
          when :invalid then msg.empty? ? 'Neplatná hodnota.' : msg
          when :conflict then 'Záznam sa medzitým zmenil — obnovil sa, uprav ho znova.'
          when :not_found then msg.empty? ? 'Spotrebič sa nenašiel.' : msg
          when :read_only, :degraded then "Katalóg je len na čítanie: #{msg}"
          else msg.empty? ? 'Zápis zlyhal.' : msg
          end
        end
      end
    end
  end
end
