# frozen_string_literal: true
# Noxun Engine - Panel: viditelnost NOXUN tagov modelu (D-27; patri sem aj
# checkbox „Zobraziť zóny (ghost)" — je to ten isty tag). Sprava sablon (save/delete/apply/merge)
# sa V0.4.5 D2 PRESUNULA do samostatneho okna TemplatesDialog (ui/templates_dialog.rb)
# — v paneli ostal len rychly vyber sablony vo vkladacej karte (form.js).
# Cast modulu Panel (reopen) - zdiela ivary cez class << self.
module Noxun
  module Engine
    module Panel
      class << self
        # --- D-27: viditelnost NOXUN tagov v modeli ---------------------------
        # JEDEN handler pre OBA vstupne body: okno tagov v raile Inspectora aj
        # checkbox „Zobraziť zóny (ghost) v modeli" (kluc `zony`) — druhy
        # ovladac nad tym istym tagom nesmie mat vlastnu cestu ani vlastnu
        # undo semantiku.
        #
        # SERVEROVE GUARDY (HTML nie je ochrana, vzor `handle_edge_option`):
        #   * IDENTITA DOKUMENTU — callback HtmlDialogu je asynchronny; bez
        #     prisnej zhody by klik po prepnuti dokumentu skryl tag v CUDZOM
        #     modeli (lekcia Codex #168 P2). Prazdny guid = okno bez dobehnuteho
        #     NX.init, nie „stary klient".
        #   * WHITELIST KLUCA (`Tags::KEYS`) a VYSLOVNY boolean — retazec
        #     "false" je v Ruby pravdivy, preto sa porovnava `== true`.
        # Zapis samotny robi ZDIELANA `Engine.set_tag_visible`, ktora prepne
        # tag v JEDNEJ operacii (= jeden krok Späť) a rozposle novy stav.
        def handle_tag_visible(payload)
          data = parse(payload)
          model = Sketchup.active_model
          key = data['key'].to_s
          value = data['value']

          if DocKey.foreign?(data['model_guid'], model)
            push_tags
            return set_status('Model sa medzitým prepol — stav obnovený, klikni znova.', true)
          end
          unless Tags::KEYS.include?(key) && (value == true || value == false)
            push_tags
            return set_status('Neznámy tag — v modeli sa nič nezmenilo.', true)
          end

          before = tag_row(tags_state(model), key)
          state = Engine.set_tag_visible(key, value, model)
          model.active_view.invalidate if model.active_view
          msg, err = tag_toggle_status(state, before, key, value)
          set_status(msg, err)
        end

        # Riadok tagu zo stavu (alebo nil, ked tag v modeli nie je).
        def tag_row(state, key)
          rows = state.is_a?(Hash) ? state['rows'] : nil
          return nil unless rows.is_a?(Array)

          rows.find { |r| r.is_a?(Hash) && r['key'].to_s == key.to_s }
        end

        # Potvrdenie SKLADA SERVER — a hovori pravdu aj vtedy, ked sa nestalo
        # nic (tag v modeli nie je) alebo ked skrytie posunulo kreslenie
        # (SketchUp aktivny tag skryt nenecha — robime to vedome, Codex F7).
        #
        # Review #249 P2: uspech sa hlasi az podla VYSLEDNEHO STAVU, nie podla
        # toho, co si klient pytal. Ked zapis do modelu zlyhal (`Tags.write`
        # operaciu abortuje a vrati nezmeneny stav), riadok drzi opacnu
        # viditelnost — vtedy je to CHYBA, nie potvrdenie.
        # Vracia dvojicu [sprava, chyba?].
        def tag_toggle_status(state, before, key, value)
          row = tag_row(state, key)
          return ['Tento tag v modeli zatiaľ nie je — nič sa nezmenilo.', false] if row.nil? && before.nil?

          label = (row || before)['label']
          return ["#{label}: tag sa nepodarilo prepnúť — v modeli sa nič nezmenilo.", true] if row.nil?

          unless (row['visible'] == true) == value
            return ["#{label}: tag sa nepodarilo prepnúť — v modeli sa nič nezmenilo.", true]
          end

          if row['folder_hidden'] && value
            return ["#{label}: tag je zapnutý, ale jeho priečinok tagov je skrytý — " \
                    'v modeli ho vidno nebude.', false]
          end

          msg = value ? "#{label} — zobrazené v modeli." : "#{label} — skryté v modeli."
          msg += ' Kreslenie prepnuté na Untagged (skrytý tag nemôže byť aktívny).' if state.is_a?(Hash) && state['active_reset']
          [msg, false]
        end

        # D-14: ulozenie OZNACENEHO korpusu ako sablony priamo z panela (in-panel
        # modal). Serverove guardy — HTML/CSS nie je ochrana: identita korpusu
        # (Codex F2 — oneskoreny zapis po prekliknuti sa zahodi), neprazdny nazov,
        # upsert false = chyba zapisu (Codex F7 — ziadny falosny uspech).
        def handle_save_template_as(payload)
          data = JSON.parse(payload.to_s)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv označ NOXUN korpus — šablóna sa ukladá z neho.', true) if cab.nil?

          # UI-B3 (Codex audit BLOCKER 2): PRISNY guard dokumentu. ID skriniek sa
          # naprie dokumentmi opakuju (kazdy model ma CAB-001), takze modal
          # otvoreny nad jednym dokumentom by po prepnuti ulozil skrinku z ineho.
          # Prazdny guid = okno bez dobehnuteho NX.init, nie „stary klient"
          # (rovnaka zasada ako handle_clear_selection).
          if DocKey.foreign?(data['model_guid'], model)
            return set_status('Šablóna neuložená — panel patrí inému dokumentu.', true)
          end

          expected = data['cabinet_id'].to_s
          actual = Store.get(cab, 'cabinet_id').to_s
          if !expected.empty? && expected != actual
            return set_status('Výber sa medzitým zmenil — šablóna neuložená, skús znova.', true)
          end

          name = data['name'].to_s.strip
          return set_status('Prázdny názov — šablóna neuložená.', true) if name.empty?

          # H2 (D-76): model = zdroj ZMRAZENYCH definicii setov kovania.
          cab_cfg = Store.config(cab) || {}
          config = template_config_from(cab_cfg, model: model)
          hw_note = template_save_hardware_note(cab_cfg, config, model) # GH #133 P2
          type_note = apply_template_type!(config, data['type'])        # UI-B3 modal: Nazov + Typ
          # UI-D2: nahlad sa foti AZ TERAZ — po VSETKYCH guardoch a z TOHO
          # ISTEHO `cab`, z ktoreho vznikol config (inak by obrazok patril inej
          # skrinke nez data). Zlyhany capture = nil -> pripadny stary PNG sa
          # pri prepise zmaze (viz TemplateStore.upsert).
          preview = TemplatePreviews.capture(model, cab)
          # UI-C1a: z panela sa uklada VZDY korpusova sablona (doskove vznikaju
          # inou cestou) — identita v sklade je dvojica (kind, name).
          unless TemplateStore.upsert('cabinet', name, config, preview)
            return set_status('Šablónu sa nepodarilo zapísať (disk/práva) — skús znova.', true)
          end

          push_templates                       # quick-pick v paneli
          TemplatesDialog.push_library_echo    # Codex F3: zivy sync sekcie `tpl`
          set_status("Šablóna \"#{name}\" uložená do knižnice.#{type_note}#{hw_note}")
        end

        # --- SMOKE PACK 1 (6A): rucne odfotenie nahladu k EXISTUJUCEJ sablone --
        # Michal 20.8.: stare sablony nemaju fotku a jedina cesta k nej bola
        # ulozit sablonu NANOVO — tym by sa vsak prepisal aj jej config. Tato
        # akcia si skrinku necha naaranzovat rucne (izolacia, natocenie) a
        # prida k ulozenej sablone LEN OBRAZOK; zaznam sa nedotkne.
        #
        # NEROBI NIC NOVE: foti sa TOU ISTOU cestou ako pri ulozeni sablony
        # (`TemplatePreviews.capture` — kamera sa obnovuje v `ensure`, ziadna
        # `start_operation`, ziadny krok Späť) a subor vymiena `TemplateStore
        # .set_preview` pod sidecar zamkom. Guardy su SERVEROVE (HTML nie je
        # ochrana): existujuca sablona druhu `cabinet` + PRAVE JEDNA oznacena
        # NOXUN skrinka; ked nesedi cokolvek, NEZAPISE sa nic.
        #
        # Vracia dvojicu [ok, sprava] — hlasku vypisuje volajuce OKNO (panel aj
        # okno Sablony maju vlastny status riadok), aby sa jedna logika nemusela
        # duplikovat pre dva statusove kanaly.
        def capture_preview_for(kind, name)
          k = kind.to_s
          n = name.to_s
          return [false, 'Najprv vyber šablónu — náhľad sa priradí k nej.'] if n.empty?
          # Doskove sablony sa nefotia: dlazdica dosky je schema, nie skrinka.
          return [false, 'Náhľad sa fotí len pre šablóny skriniek.'] unless k == 'cabinet'
          return [false, "Šablóna \"#{n}\" už v knižnici nie je."] if TemplateStore.find(k, n).nil?

          model = Sketchup.active_model
          cabs = selected_cabinets(model)
          return [false, 'Označ v modeli práve jednu NOXUN skrinku — z nej sa náhľad odfotí.'] if cabs.empty?
          if cabs.length > 1
            return [false, "Označených je #{cabs.length} skriniek — nechaj označenú práve jednu."]
          end

          tmp = TemplatePreviews.capture(model, cabs.first)
          return [false, 'Náhľad sa nepodarilo odfotiť — šablóna ostáva pri schéme.'] if tmp.nil?
          unless TemplateStore.set_preview(k, n, tmp)
            return [false, 'Náhľad sa nepodarilo uložiť (disk/práva) — skús znova.']
          end

          push_templates # dlazdice v paneli si novy `preview_rev` vypytaju samy
          [true, "Náhľad šablóny \"#{n}\" je odfotený."]
        rescue StandardError => e
          Engine.log_error(e, 'Panel.capture_preview_for')
          [false, 'Náhľad sa nepodarilo odfotiť.']
        end

        # PRIAMO oznacene NOXUN korpusy (nie `find_cabinet`, ktory dielec doriesi
        # na jeho skrinku): akcia sa pyta „ktoru skrinku fotim", takze oznaceny
        # dielec ani viacnasobny vyber nesmie ticho vybrat jednu za pouzivatela.
        # Ciste citanie vyberu — ziadna operacia, ziadny zapis, ziadny krok Späť.
        def selected_cabinets(model)
          return [] unless model

          model.selection.to_a.select { |e| e.valid? && Store.kind(e) == 'cabinet' }
        rescue StandardError => e
          Engine.log_error(e, 'Panel.selected_cabinets')
          []
        end

        # UI-B3: typ z mini-modalu „Uložiť ako šablónu". Typ je JEDINY udaj,
        # ktory sa v modale nastavuje nad ramec nazvu — riadi, pod ktorym typom
        # sa sablona ponuka pri vkladani (zoznam je typovo filtrovany).
        # Whitelist je TU (HTML nie je ochrana); chybajuca hodnota = typ skrinky
        # (spravanie ako doteraz). Rozdiel oproti skrinke sa POVIE nahlas —
        # ulozene rozmery a konstrukcia ostavaju z tejto skrinky, meni sa len
        # zaradenie sablony.
        def apply_template_type!(config, raw)
          want = raw.to_s.strip.downcase
          return '' unless %w[lower upper].include?(want)

          have = (config['type'] || 'lower').to_s
          config['type'] = want
          return '' if want == have

          " Uložená ako #{want == 'upper' ? 'HORNÁ' : 'DOLNÁ'} (rozmery a konštrukcia ostali z tejto skrinky)."
        end

        # --- UI-C1a: identita pouzitej sablony vo vkladacom payloade ---------

        # Vyberie z payloadu metadata sablony (`template_kind` + `template_name`)
        # a ODSTRANI ich — builder o nich nesmie vediet (do configu korpusu ani
        # dosky nepatria). Vrati [kind, name] na opeciatkovanie, alebo nil, ked
        # payload sablonu nenesie ci nesedi druh (doskova sablona vo vklade
        # korpusu = ziadna peciatka, vklad bezi normalne).
        def take_template_ref!(params, expected_kind)
          kind = params.delete('template_kind').to_s
          name = params.delete('template_name').to_s
          return nil if name.empty? || kind != expected_kind

          [kind, name]
        end

        # Peciatka „naposledy pouzite" — SAMOSTATNA operacia PO uspesnom
        # vlozeni a MIMO model.start_operation. Zaznam sa najprv znovu najde
        # (medzitym ho mohol niekto vymazat alebo prepisat inym druhom) —
        # zmiznuta sablona = vklad je hotovy a peciatka sa ticho vynecha.
        # Zlyhanie zapisu NIKDY nemeni vysledok vkladania: len log, ziadna
        # chybova hlaska pouzivatelovi.
        def stamp_template_used(ref)
          return if ref.nil?

          kind, name = ref
          return if TemplateStore.find(kind, name).nil?
          return unless TemplateStore.touch_used(kind, name)

          push_templates # poradie „Naposledy pouzite" v paneli je hned cerstve
        rescue StandardError => e
          Engine.log_error(e, 'Panel.stamp_template_used')
        end

      end
    end
  end
end
