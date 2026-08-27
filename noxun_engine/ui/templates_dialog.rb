# frozen_string_literal: true
# Noxun Engine — SERVEROVA AUTORITA SABLON.
#
# ŠT-3c-1: satelitne okno „Šablóny" ZANIKLO (HtmlDialog, `DLG_KEY`,
# `templates.html`, polozka menu aj tlacidlo v paneli). Jedine UI sablon je
# odteraz SEKCIA `tpl` v okne ŠTÚDIO. Modul sa pritom ZAMERNE NEPREMENUVA
# (vzor audit #21 zo ŠT-2a): zaniklo OKNO, nie serverova autorita — telo
# kazdej akcie aj vsetky guardy ziju dalej TU.
#
# SPRAVA sablon (pouzit na oznacenu skrinku / odfotit nahlad / zmazat) je
# v sekcii; UKLADANIE NOVEJ sablony ostava v mini-modale Inspectora
# (`Panel.handle_save_template_as`, UI-B3) — je to jediny vstup, ktory ma
# oznacenu skrinku po ruke, a duplikovat ho v sekcii by znamenalo druhu
# zapisovaciu cestu k tomu istemu suboru. Tlacidlo „Uložiť označený korpus
# ako šablónu" zo starého okna sa preto NEPRENASA (priznane v PR).
#
# Sablony su GLOBALNE (%APPDATA%, TemplateStore) — nie su viazane na model,
# preto sekcia nema `on_model_changed` a payload nepotrebuje model; „oznaceny
# korpus" sa hlada CERSTVO pri kazdej akcii.
#
# VYBER (audit N27): sekcia NEMA selection observer a mat ho nebude. Okno
# si disabled stav tlacidiel drzalo cez `Panel.push_selected` -> to zilo
# LEN kym zil Inspector. Tlacidla su preto VZDY AKTIVNE a verdikt („nic nie
# je oznacene", „iny typ", „oznacenych je viac") povie SERVER pri kliku —
# vzor `Panel.capture_preview_for` a pravidlo D-78 (ziadne mrtve tlacidlo
# bez vysvetlenia).
#
# H2 (D-76): sablona nesie AJ kovanie — mapovanie setov + ZMRAZENE definicie
# (ulozenie: Panel.template_config_from s modelom; aplikacia: merge_hardware_sets
# + zmrazenie do projektoveho snapshotu v operacii prestavby). Sablona je datovy
# subor MIMO modelu, preto sa jej kovanie cita BEZSTRATOVO alebo vobec
# (HardwareSets.read_template_mapping — GH #133 P2).
require 'json'

module Noxun
  module Engine
    module TemplatesDialog
      # UZAVRETY whitelist akcii, ktore smie poslat SEKCIA `tpl`. Klient
      # posiela iba MENO akcie — co sa smie zavolat, rozhoduje SERVER.
      #
      # `ready` v zozname NIE JE (a byt nemoze): Studio registruje callbacky
      # pod TYMI ISTYMI menami, takze `ready` by prepisal jeho vlastny.
      # Prvotny stav sekcie nesie `push_state` Studia pod klucom `tpl`.
      SECTION_ACTIONS = %w[tpl_apply tpl_delete tpl_capture tpl_rename tpl_preview].freeze

      # Druhy sablon, ktore sekcia spravuje. Kontrakt skladu je dvojica
      # (kind, name) — kind sa preto NIKDY neberie z HTML bez kontroly.
      KINDS = %w[cabinet board].freeze

      # 1b-4 (B3): jedine kluce configu, ktore DLAZDICA sekcie kresli
      # (typ + tri rozmery). Zvysok zaznamu do okna nikdy nesiel na nic.
      TILE_CONFIG_KEYS = %w[type width height depth].freeze

      class << self
        # --- vstup SEKCIE `tpl` (vzor RulesDialog.dispatch) ------------------

        def dispatch(name, payload, sink)
          key = name.to_s
          return sink.call(status_script('Neznáma akcia šablón.', true)) unless SECTION_ACTIONS.include?(key)

          with_client(sink) { run_section_action(key, payload) }
        rescue StandardError => e
          Engine.log_error(e, "TemplatesDialog.dispatch #{name}")
          sink.call(status_script("Chyba: #{e.message}", true))
        end

        def run_section_action(key, payload)
          case key
          when 'tpl_apply'   then handle_apply(payload)
          when 'tpl_delete'  then handle_delete(payload)
          when 'tpl_capture' then handle_capture(payload)
          when 'tpl_rename'  then handle_rename(payload)
          when 'tpl_preview' then handle_preview(payload)
          end
        end

        # Presmerovanie odpovedi na cas JEDNEHO volania. `ensure` je povinne:
        # vynimka v handleri nesmie nechat sink viset, inak by ho zdedila
        # NASLEDUJUCA odpoved a poslala ju do cudzieho kanala.
        def with_client(sink)
          prev = @client_sink
          @client_sink = sink
          yield
        ensure
          @client_sink = prev
        end

        # --- payload sekcie -------------------------------------------------
        #
        # Sablony su GLOBALNE, takze payload NEPOTREBUJE model (na rozdiel od
        # ostatnych sekcii). Argument sa napriek tomu prijima kvoli jednotnemu
        # tvaru mostov v `StudioDialog` — a ZAMERNE sa nepouziva.
        #
        # `previews: true` pripaja TRANSIENTNY `preview_rev` (odtlacok PNG
        # suboru) — dlazdica podla neho vie, ci ma o obrazok vobec ziadat,
        # a ci pisat „Odfotiť" alebo „Prefotiť". Do `templates.json` sa
        # nezapisuje. Samotne PNG chodi VLASTNYM kanalom (`tpl_preview`).
        #
        # 1b-4 (B3): payload je OREZANY NA TVAR DLAZDICE. Bezi v KAZDOM plnom
        # pushi okna (kazdy prepocet kusovnika, kazdy zapis rozpoctu), a dlazdica
        # z celeho zaznamu kresli len meno, druh/typ, tri rozmery a nahlad —
        # zvysok configu (`zone_tree`, `fronts`, `hardware_sets`,
        # `hardware_set_defs`, materialy) je pritom jeho NAJVACSIA cast a do okna
        # nikdy nedosiel na nic. Cely zaznam si pyta az akcia, ktora ho naozaj
        # potrebuje (`handle_apply` cita zo skladu, nie z payloadu).
        # Podmienit payload OTVORENOU sekciou sa NEDA: server nevie, ktora sekcia
        # je v okne otvorena (guard je od #225 na klientovi) a kontrakt „okno
        # zanika — modul zije" znamena, ze `push_state` posiela VSETKY sekcie
        # naraz; orezanie je preto jedina cesta, ktora nezavedie druhu pravdu.
        # `usage: false` — poradie „Naposledy pouzite" kresli LEN panel, takze
        # sekcia nepotrebuje ani citanie `TemplateUsage`.
        # `version` sa nepripaja: plny push okna ho nesie na najvyssej urovni.
        def tpl_payload(_model = nil)
          { 'cabinet' => tile_rows('cabinet'), 'board' => tile_rows('board') }
        rescue StandardError => e
          # Zlyhanie sa NEZAMLCUJE: sekcia ostane bez dat a jedinou stopou
          # preco je tento zaznam (rovnaka lekcia ako `mat_payload`).
          Engine.log_error(e, 'TemplatesDialog.tpl_payload')
          nil
        end

        # Jeden druh sablon v tvare dlazdice.
        def tile_rows(kind)
          Panel.template_list(kind: kind, previews: true, usage: false).map { |t| tile_row(t) }
        end

        # Tvar DLAZDICE. Kluce su UZAVRETY zoznam — keby sa posielal cely
        # `config`, kazdy novy kluc zaznamu (napr. dalsi blok kovania) by ticho
        # nafukoval kazdy push okna a nikto by si toho nevsimol.
        # Prazdna hodnota sa NEDOPLNA (dlazdica chybajuci rozmer nekresli —
        # `tplDims` vynechava padnute hodnoty).
        def tile_row(rec)
          cfg = rec['config'].is_a?(Hash) ? rec['config'] : {}
          { 'name' => rec['name'].to_s,
            'preview_rev' => rec['preview_rev'],
            'config' => TILE_CONFIG_KEYS.each_with_object({}) do |k, out|
              out[k] = cfg[k] unless cfg[k].nil?
            end }
        end

        # --- Ruby -> JS -----------------------------------------------------

        # Stavovy riadok sekcie: prijimac `TPL.setStatus` je v tom istom
        # `js/templates.js`, ktory sekcia nacitava, a `#status` je uzol
        # `studio.html`. Text sklada SERVER (jedna autorita).
        def status_script(msg, error = false)
          "TPL.setStatus(#{msg.to_json}, #{error ? 'true' : 'false'})"
        end

        def set_status(msg, error = false)
          js(status_script(msg, error))
        end

        # Odpoved ide TOMU, KTO sa pytal. Sink zije PRESNE jeden synchronny
        # callback sekcie (`with_client`); mimo neho je adresat jediny mozny:
        # okno Studio.
        def js(script)
          sink = @client_sink
          return sink.call(script) if sink

          studio_js(script)
        end

        # Kanal SEKCIE. `js` Studia je private (patri jeho kanalu), preto
        # tenky verejny most `tpl_js` — vzor `rules_js`.
        def studio_js(script)
          return false unless defined?(StudioDialog)

          StudioDialog.tpl_js(script)
        rescue StandardError => e
          Engine.log_error(e, 'TemplatesDialog.studio_js')
          false
        end

        # LACNE ECHO sekcie po zmene KNIZNICE (zmazanie, novy nahlad, ulozenie
        # sablony z Inspectora). Kniznica je subor MIMO modelu, takze plny push
        # okna (a s nim cely prepocet kusovnika a zdvih generacie) by bol drahy
        # a zbytocny — a navyse by zneplatnil rozkliknuty riadok inej sekcie.
        #
        # 1b-4 (B4): metoda sa do 1b-4 volala `refresh_if_open` a to meno
        # KLAMALO — ziadne „if open" tu uz od #225 nie je. Otvorenost sekcie
        # posudzuje KLIENT (`tplIsActive` v `js/templates.js`): ked je pouzivatel
        # inde, `TPL.init` stav iba ULOZI a nekresli, lebo `#secbody`/`#sectools`
        # su ZDIELANE uzly celeho okna. Server o otvorenej sekcii nevie NIC a
        # vediet nemusi — meno teraz hovori to, co sa naozaj deje: posle sa echo.
        # (Menuje sa VYHRADNE metoda; modul `TemplatesDialog` ostava — vzor
        # „okno zanika, modul zije".)
        def push_library_echo
          pay = tpl_payload
          js("TPL.init(#{pay.to_json})") if pay
        rescue StandardError => e
          Engine.log_error(e, 'TemplatesDialog.push_library_echo')
        end

        # --- PNG kanal SEKCIE (audit N24/N26) --------------------------------
        #
        # Panelovy `Panel.push_template_preview` sa pouzit NEDA: ma guard
        # `dialog_alive?` INSPECTORA a odpoved posiela prijimacu panela
        # (`NX.setTemplatePreview`). Sekcia ma preto VLASTNY callback, vlastny
        # prijimac (`TPL.setPreview`) a vlastnu cache per revizia v kliente.
        #
        # PULL kanal (vzor UI-D2): data URI je radovo vacsie nez cely zoznam,
        # takze sa posiela LEN na vyziadanie a LEN pre jednu sablonu. `rev` sa
        # vracia SPAT nezmenene, aby si klient odpoved priradil k spravnej
        # verzii (medzitym mohol prist novy nahlad); `png: nil` = bez nahladu,
        # dlazdica ostane na scheme a klient si to zacachuje.
        #
        # Limit 64 kB + PNG magic bytes drzi `TemplatePreviews.data_uri` —
        # tu sa NEOBCHADZA a neduplikuje.
        def handle_preview(payload)
          data = JSON.parse(payload.to_s)
          kind = data['kind'].to_s
          name = data['name'].to_s
          return if name.empty? || !KINDS.include?(kind)

          out = { 'kind' => kind, 'name' => name, 'rev' => data['rev'].to_s,
                  'png' => TemplatePreviews.data_uri(kind, name) }
          js("TPL.setPreview(#{out.to_json})")
        rescue StandardError => e
          Engine.log_error(e, 'TemplatesDialog.handle_preview')
        end

        # --- akcie ----------------------------------------------------------

        # SMOKE PACK 1 (6A): „Odfotiť" — prida nahlad k UZ ULOZENEJ sablone.
        # Zaznam sa NEPREPISUJE (na rozdiel od ukladania), meni sa VYHRADNE
        # obrazok; vsetky guardy aj capture su v `Panel.capture_preview_for`
        # (jedna cesta, jeden zamok) a ten je aj autoritou hlasky.
        #
        # ŠT-3c-1: doskovym sablonam sa akcia v sekcii NEZOBRAZUJE (dlazdica
        # dosky je schema, nie skrinka) — serverovy guard `kind == 'cabinet'`
        # v `capture_preview_for` napriek tomu OSTAVA (HTML nie je ochrana).
        def handle_capture(payload)
          data = JSON.parse(payload.to_s)
          name = data['template'].to_s
          # Review #225 NOTE: druh sa validuje proti UZAVRETEMU zoznamu rovnako
          # ako pri mazani (konzistencia — HTML nie je ochrana). Chybajuci udaj
          # znamena korpusovu sablonu (jedine, ktore sa fotia); `capture_preview_for`
          # si guard `kind == 'cabinet'` robi aj tak sam.
          kind = data['kind'].to_s
          kind = 'cabinet' if kind.empty?
          return set_status('Neznámy druh šablóny — nič sa neodfotilo.', true) unless KINDS.include?(kind)

          ok, msg = Panel.capture_preview_for(kind, name)
          set_status(msg, !ok)
          push_library_echo if ok
        end


        # ŠT-3c-2: PREMENOVANIE sablony. Vstup je D-15 modal s JEDNYM polom
        # (predvyplneny nazov), takze payload nesie `new_name` — kluc `name`
        # by bol PASCA: v ostatnych akciach sekcie znamena `template` meno
        # SUCASNE, a zamena by ticho premenovala nieco ine.
        #
        # Modal sa pri ODMIETNUTI NEZATVARA (audit B4): pouzivatel ma meno
        # opravit, nie ho pisat znova. Preto dva prijimace — `TPL.renameSaved`
        # (zavri a zabudni rozpisane) a `TPL.renameError` (chyba k polu, modal
        # ostava a odomkne sa). Bez toho by po prvom odmietnuti ostal modal
        # navzdy zamknuty v `isBusy` (vzor `MD.editSaved`/`MD.editErrors`).
        def handle_rename(payload)
          data = JSON.parse(payload.to_s)
          kind = data['kind'].to_s
          old_name = data['template'].to_s
          # F4: meno sa `strip`-uje TU aj v sklade — okrajové medzery su
          # v mene sablony vzdy preklep, nikdy zamer.
          new_name = data['new_name'].to_s.strip

          return rename_error('Neznámy druh šablóny — nič sa nepremenovalo.') unless KINDS.include?(kind)
          return rename_error('Vyber šablónu na premenovanie.') if old_name.empty?
          return rename_error('Prázdny názov — šablóna sa nepremenovala.') if new_name.empty?
          # PNG sa presuva POD zamkom skladu; ci sa to naozaj podarilo, sa da
          # zistit len porovnanim PRED a PO (sklad vracia symbol o ZAZNAME).
          had_png = !TemplatePreviews.rev_for(kind, old_name).nil?

          case TemplateStore.rename(kind, old_name, new_name)
          when :ok
            # Peciatka „naposledy pouzite" zije v INOM subore a je best-effort —
            # jej zlyhanie premenovanie nemeni (poradie dlazdic sa len vrati
            # na „nikdy nepouzita").
            TemplateUsage.rename(kind, old_name, new_name)
            # Review #226 P2: vkladacia karta panela drzi zvolenu sablonu MENOM —
            # bez prehodenia by vkladala pod starou identitou. Ide to PRED echom,
            # aby prestavane dlazdice uz vyznacili spravnu.
            Panel.push_template_renamed(kind, old_name, new_name)
            js('TPL.renameSaved()')
            note = if had_png && TemplatePreviews.rev_for(kind, new_name).nil?
                     ' Náhľad sa nepreniesol — odfoť ho znova.'
                   else
                     ''
                   end
            after_change("Šablóna premenovaná na „#{new_name}“.#{note}")
          when :unchanged
            # F4 + review #226 NOTE 1: rovnake meno NIE JE chyba, ale ani zapis
            # (subor sa nedotkne). Rozhoduje o tom SKLAD — pod zamkom a az za
            # guardmi, takze o zmiznutej sablone sa uz „hotovo" nepovie.
            js('TPL.renameSaved()')
            set_status('Meno sa nezmenilo.')
          when :exists
            rename_error("Šablóna „#{new_name}“ už v knižnici je — vyber iné meno.")
          when :missing
            # Zmizla medzitym (druha instancia, rucny zasah). Modal sa ZAVRIE
            # (review #226 NOTE 3): opravovat meno sablony, ktora uz neexistuje,
            # nie je co — otvoreny formular nad nicim by sluboval cestu, ktora
            # nikam nevedie. Hlaska ide do statusu sekcie a zoznam sa obnovi,
            # aby pouzivatel videl, co v kniznici naozaj je.
            js('TPL.renameClosed()')
            set_status("Šablóna „#{old_name}“ už v knižnici nie je — zoznam je obnovený.", true)
            push_library_echo
          when :readonly
            rename_error('Knižnica šablón je z novšej verzie Noxunu — nič sa nezmenilo.')
          else
            rename_error('Premenovanie zlyhalo (disk/práva) — nič sa nezmenilo.')
          end
        end

        # Odmietnutie premenovania: chyba ide K POLU v otvorenom modale (klient
        # ho odomkne a nechá otvorený) a ZAROVEN do stavoveho riadku sekcie —
        # ked modal medzitym zanikol, pouzivatel sa aj tak dozvie, preco sa nic
        # nestalo.
        # Sablona, ktora v kniznici uz NIE JE (druha instancia, rucny zasah):
        # jedna hlaska a obnova zoznamu pre vsetky cesty, ktore na to prisli.
        def template_gone(name)
          push_library_echo
          set_status("Šablóna „#{name}“ už v knižnici nie je — zoznam je obnovený.")
        end

        def rename_error(msg)
          js("TPL.renameError(#{msg.to_json}, 'name')")
          set_status(msg, true)
          nil
        end

        # ŠT-3c-1: mazanie ma potvrdenie v D-15 modale KLIENTA (nx_modal) —
        # `UI.messagebox` v callbacku HtmlDialogu sem UZ NEPATRI (audit N28:
        # nativny modal blokuje callback a v Studiu by zamrzol cely kanal).
        # Server preto NEPOTVRDZUJE, iba MAZE — a robi to s vlastnymi guardmi,
        # lebo HTML nie je ochrana.
        #
        # KIND GUARD sa PRVY RAZ rozsiruje aj na `board` (audit N29): doskove
        # sablony dnes nespravuje NIC a jedina cesta, ako sa zbavit omylom
        # vzniknutej, by bola rucna uprava suboru.
        def handle_delete(payload)
          data = JSON.parse(payload.to_s)
          kind = data['kind'].to_s
          name = data['template'].to_s
          return set_status('Vyber šablónu na vymazanie.', true) if name.empty?
          return set_status('Neznámy druh šablóny — nič sa nezmazalo.', true) unless KINDS.include?(kind)

          # N1 (ŠT-3c-2): sablona, ktora medzitym zmizla (druha instancia, rucny
          # zasah), ma VLASTNU hlasku — sklad na nu odteraz vracia `false` a bez
          # tohto rozlisenia by pouzivatel dostal hlasku o chybe disku.
          return template_gone(name) if TemplateStore.find(kind, name).nil?

          # Codex #174 P2: pri odmietnutom zapise ZIADNA hlaska o uspechu.
          unless TemplateStore.delete(kind, name)
            # Review #226 P2: kontrola vyssie bezi MIMO zamku skladu, takze medzi
            # nou a zamknutym mazanim mohla sablonu zmazat druha instancia —
            # `delete` vtedy vrati `false` z UPLNE INEHO dovodu nez novsia schema
            # ci chyba disku. Rozhoduje az pohlad PO navrate: ked uz v kniznici
            # nie je, plati „zmizla" (aj so zoznamom nanovo).
            return template_gone(name) if TemplateStore.find(kind, name).nil?

            return set_status('Šablónu sa nepodarilo vymazať — knižnica je z novšej verzie ' \
                              'Noxunu alebo zlyhal zápis na disk. Nič sa nezmenilo.', true)
          end
          after_change("Šablóna \"#{name}\" vymazaná.")
        end

        # Pouzije sablonu na oznaceny korpus. MERGE, nie nahradenie: konstrukcne
        # kluce zo sablony; part_overrides + hardware_overrides CIELA zostavaju
        # (sablona ich nenesie — viazane na konkretne dielce zdroja).
        # H2 (D-76): SETY KOVANIA sablona nesie (mapovanie + zmrazene definicie) —
        # merge_hardware_sets, zmrazenie v operacii prestavby.
        def handle_apply(payload)
          name = JSON.parse(payload.to_s)['template'].to_s
          # Guard kind (UI-C1a): doskovu sablonu na korpus aplikovat nemozno —
          # hladame VYHRADNE medzi korpusovymi. Sekcia doskam tlacidlo ani
          # nezobrazuje, ale guard je SERVEROVY a ostava.
          tpl = TemplateStore.find('cabinet', name)
          return set_status('Šablóna sa nenašla.', true) if tpl.nil?
          model = Sketchup.active_model
          # Review #225: PRAVE JEDNA oznacena skrinka (vzor `capture_preview_for`).
          # `find_cabinet` by pri viacnasobnom vybere TICHO vzal prvy korpus —
          # a prestavba NESPRAVNEJ skrinky je horsia nez hlaska. Akcia sa pyta
          # „ktoru skrinku prestavat", takze odpoved musi byt jednoznacna.
          cabs = Panel.selected_cabinets(model)
          if cabs.empty?
            return set_status('Označ v modeli práve jednu NOXUN skrinku — šablóna sa použije na ňu.', true)
          end
          if cabs.length > 1
            return set_status("Označených je #{cabs.length} skriniek — nechaj označenú práve jednu.", true)
          end

          cab = cabs.first

          # Typovy guard aj TU, nie len v HTML disabled (Codex PR #29): sekcia
          # vyber NESLEDUJE (audit N27 — ziadny observer), takze verdikt musi
          # dat server pri kliku.
          cab_type = (Store.config(cab) || {})['type'] || 'lower'
          tpl_type = (tpl['config'] || {})['type'] || 'lower'
          if tpl_type != cab_type
            return set_status("Šablóna je pre iný typ (#{tpl_type == 'upper' ? 'horná' : 'dolná'}) " \
                              'než označená skrinka — nepoužitá.', true)
          end

          # GH #133 P2: kovanie sablony sa cita BEZSTRATOVO alebo vobec. Sablona
          # z novsej verzie (neznamy typ kovania) ci rucne upravena by ocesanou
          # mapou ticho ZMAZALA platny vyber setov cielovej skrinky.
          hw_status, hw_lost = HardwareSets.read_template_mapping((tpl['config'] || {})['hardware_sets'])
          if hw_status == :lossy
            return set_status("Šablóna nesie kovanie, ktoré sa nedá prečítať (#{Array(hw_lost).join(', ')}) — " \
                              'je z novšej verzie Noxun alebo ručne upravená. Nepoužitá, nič sa nezmenilo.', true)
          end

          target = Panel.existing_params(cab)
          merged = merge_template(target, tpl['config'])
          # D-45 (audit B4): sablona nesie hrubku aj (nepovinne) material — dvojica
          # sa musi zladit PRED rebuildom, inak by stavba spadla surovou hrubkovou
          # hlaskou. Explicitny material sablony vyhrava (hrubka sa prevezme z neho),
          # inak material dobera body_preflight; nejednoznacnost = odmietnutie.
          pf = template_material_preflight(merged, tpl['config'], target, model)
          return set_status(pf[:error], true) if pf && pf[:error]
          # H2 (D-76): definicie setov zo sablony sa zmrazia do projektoveho
          # snapshotu v TEJ ISTEJ operacii ako prestavba (rebuild_many blok) —
          # jedno undo a ziadna skrinka s nezmrazenym setom (zlyhanie zmrazenia
          # vyhodi vynimku a operacia sa cela zrusi).
          hw_note = ''
          Panel.suspend_selection_sync do
            CabinetBuilder.rebuild_many(model, [[cab, merged]], op_name: 'NOXUN: Aplikuj sablonu') do
              hw_note = freeze_sets_from_template!(model, merged, tpl['config'])
            end
            Panel.reselect(model, cab)
          end
          # UI-C2 (B4): legacy sablona s viac nez 3 urovnami zon sa POUZIJE, ale
          # povie sa to — orezanie stromu je zakazane.
          set_status("Šablóna \"#{name}\" použitá na #{Store.get(cab, 'cabinet_id')}. " \
                     "Jeden krok Späť to vráti.#{pf ? pf[:note] : ''}#{hw_note}" \
                     "#{Panel.zone_depth_note((Store.config(cab) || {})['zone_tree'])}")
          after_model_write(model)
        end

        # ŠT-3c-1: po ZAPISE DO MODELU (pouzitie sablony) musia cerstve cisla
        # dostat OBAJA odberatelia — PANEL (prestavana skrinka je vo vybere)
        # aj ŠTÚDIO so ZDVIHOM generacie (prestavba meni kusovnik, nakupny
        # zoznam aj rozpocet). Poradie je zavazne (vzor RulesDialog): NAJPRV
        # panel, az potom Studio.
        def after_model_write(model)
          Panel.push_selected(model) if defined?(Panel)
          return unless defined?(StudioDialog)

          StudioDialog.refresh_if_open(bump: true)
        rescue StandardError => e
          Engine.log_error(e, 'TemplatesDialog.after_model_write')
        end

        # Po zmene KNIZNICE (nie modelu): status + echo sekcie + quick-pick
        # v paneli. ZIADNY plny push okna — kniznica s kusovnikom nema nic
        # spolocne (a zdvih generacie by zneplatnil rozkliknute riadky).
        def after_change(msg)
          set_status(msg)
          push_library_echo
          Panel.push_templates
        end

        # H2 (D-76): zmrazenie definicii setov zo sablony do projektu. Legacy
        # sablona (bez kluca 'hardware_sets') nema co mrazit — mapovanie ciela
        # ostava tak, ako ho projekt uz ma zmrazene.
        def freeze_sets_from_template!(model, merged, tpl_config)
          return '' unless tpl_config.is_a?(Hash) && tpl_config.key?('hardware_sets')

          Panel.freeze_template_hardware!(model, merged['hardware_sets'],
                                          tpl_config['hardware_set_defs'])
        end

        # D-45: zladenie hrubka<->material pre MERGED params sablony.
        # Vrati nil / { error: } / { note: } (rovnaky kontrakt ako Panel preflighty).
        # GH P1: hrubku smie prevzat LEN material, ktory dodala SAMOTNA SABLONA —
        # merge_template kopiruje do merged aj material CIELA, takze test musi ist
        # na tpl_config (inak by sablona bez materialu zdedila staru hrubku ciela).
        # GH P1 (remap): old_eff sa cita z CIELA pred merge — merged uz nesie novy
        # material a remap rucnych ABS by inak ziadnu zmenu nevidel.
        def template_material_preflight(merged, tpl_config, target, model)
          note = ''
          if defined?(Materials) && Panel.present_str((tpl_config || {})['material_id'])
            sheet = Materials.sheet(CabinetBuilder.effective_materials(model, merged)['body'])
            if sheet
              adopt = Panel.adopt_body_thickness!(merged, sheet)
              return adopt if adopt && adopt[:error]
              note += adopt[:note].to_s if adopt
            end
          end
          pf = Panel.material_preflight(merged, model,
                                        old_eff: CabinetBuilder.effective_materials(model, target))
          return pf if pf && pf[:error]
          note += pf[:note].to_s if pf
          note.empty? ? nil : { note: note }
        end

        def merge_template(target_params, tpl_config)
          merged = tpl_config.dup
          merged['part_overrides'] = target_params['part_overrides'] || {}
          merged['hardware_overrides'] = target_params['hardware_overrides'] || []
          merged['hardware_sets'] = merge_hardware_sets(target_params, tpl_config)
          # D-13 (Codex F3): legacy sablona BEZ plinth_recess nesmie cielovy korpus
          # ticho stiahnut na novy default — chybajuci kluc = zachovaj hodnotu ciela.
          merged['plinth_recess'] = target_params['plinth_recess'] unless tpl_config.key?('plinth_recess')
          # D-100 (GH #149 P2): sablona nazov skrinky NENESIE (template_config_from
          # ho neuklada) — bez tohto by merge zacal od sablony a rucny nazov ciela
          # („Chladnickova") by po pouziti sablony ticho zmizol. Rovnaky vzor ako
          # plinth_recess: chybajuci kluc = zachovaj hodnotu CIELA.
          merged['name'] = target_params['name'] unless tpl_config.key?('name')
          %w[material_id front_material_id back_material_id].each do |k|
            tv = Panel.present_str(tpl_config[k])
            merged[k] = tv || target_params[k]
          end
          merged
        end

        # H2 (D-76): sety kovania pri aplikacii sablony.
        #   sablona kluc NEMA (legacy/seed)  -> zachova sa CELE mapovanie CIELA
        #     (vzor plinth_recess D-13; do H2 sa override setov ticho ZMAZAL)
        #   sablona kluc MA                  -> genericke kluce zo SABLONY;
        #     composite kluce „typ@owner_part_key" CIELA sa pridaju spat —
        #     su viazane na konkretne dielce ciela, sablona o nich nic nevie
        #     a nikdy ich nemaze ani neprepisuje.
        # Mapa zo sablony sa VZDY normalizuje s allow_owner: false — rucne
        # upraveny JSON s composite klucom sa cez sablonu do skrinky nedostane.
        def merge_hardware_sets(target_params, tpl_config)
          target = target_params['hardware_sets'].is_a?(Hash) ? target_params['hardware_sets'] : {}
          target = HardwareSets.normalize_mapping(target, nil, allow_owner: true)
          return target unless tpl_config.is_a?(Hash) && tpl_config.key?('hardware_sets')

          out = HardwareSets.normalize_mapping(tpl_config['hardware_sets'], nil, allow_owner: false)
          target.each do |key, value|
            parsed = BuildPlan.parse_hardware_set_key(key)
            out[key] = value if parsed && parsed[1] # composite = override na dielci
          end
          out
        end
      end
    end
  end
end
