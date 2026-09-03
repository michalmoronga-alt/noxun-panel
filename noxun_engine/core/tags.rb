# frozen_string_literal: true
# Noxun Engine — VIDITELNOST TAGOV MODELU (D-27).
#
# Tagy (SketchUp Layers) tvoria BUILDERY pri stavbe: `CabinetBuilder.part_tag`
# (Korpus/Chrbát/Čelá/Vnútro), `CabinetBuilder.hardware_tag`, `BoardBuilder
# .board_tag` a `Zones.sync_ghost`. Tento modul o nich vie len TOLKO, ze ich
# vie NAJST a PREPNUT im viditelnost — geometriu sa nedotyka.
#
# ROZDELENIE VIZUALOV KOVANIA (D-116, Michal 3.9.): NOHY id na `hardware_tag`
# (Kovanie), ale UCHYTKOVE PROFILY (D-90) na tag SVOJHO CELA cez `part_tag`
# — su s celom zrastene, takze pri skryti tagu „Čelá" musia zmiznut s nim.
# VEDOMY DOSLEDOK: prepinac tagu Kovanie uchytky uz neschova. Tento modul sa
# tym NEMENI (mena tagov aj tu ostavaju z konstant builderov).
#
# STYRI ZASADY (draho zaplatene inde v repe a v Codex audite davky):
#   1) MENA TAGOV MAJU JEDINY ZDROJ — konstanty builderov. Citaju sa az za
#      behu (`const_defined?` guard), takze tu nie je opisany ani jeden
#      retazec a premenovanie tagu v builderi sa sem premietne samo.
#   2) NEZNAMY / NEEXISTUJUCI TAG = NIC. `state` vracia LEN tagy, ktore su
#      v modeli naozaj (D-78: mrtve tlacidlo je horsie nez ziadne) a
#      `set_visible` bez existujuceho tagu NEOTVORI ziadnu operaciu. Jedina
#      vynimka je tag ZON (CREATABLE_KEYS) — checkbox „Zobraziť zóny
#      (ghost)" smel tag zalozit uz pred D-27 a v modeli bez ghostov ziadny
#      este nie je; keby ho nezalozil, checkbox by sa po kliknuti vratil spat.
#   3) VIDITELNOST TAGU JE ZAPIS DO .skp — na rozdiel od EdgeCheck/GrainCheck
#      (Sketchup::Overlay NAD modelom, lekcia D-103/D-104/D-105) sa uklada do
#      suboru, takze bezi v `start_operation`/`commit_operation` = PRESNE JEDEN
#      krok Spat. Nezabaleny zapis by sa priplietol k nasledujucej pouzivatelovej
#      operacii a jej Spat by vratil nieco ine. Operacia ma ABORT vetvu —
#      vynimka v nej nesmie nechat otvorenu transakciu (audit BLOCKER 4).
#   4) SKRYTIE AKTIVNEHO TAGU MA VEDLAJSI UCINOK. SketchUp pri skryti aktivneho
#      tagu sam prepne kreslenie inam — robime to preto VEDOME (na Untagged),
#      v TEJ ISTEJ operacii, a volajuci to prizna v statuse (audit F7).
module Noxun
  module Engine
    module Tags
      # Poradie = poradie v UI (okno tagov v raile Inspectora). `key` je
      # stabilny kluc payloadu — meno tagu je zobrazovaci udaj a klient ho
      # nikdy neposiela spat.
      ROWS = [
        { 'key' => 'korpus',  'label' => 'Korpus' },
        { 'key' => 'chrbat',  'label' => 'Chrbát' },
        { 'key' => 'cela',    'label' => 'Čelá' },
        { 'key' => 'vnutro',  'label' => 'Vnútro' },
        { 'key' => 'kovanie', 'label' => 'Kovanie' },
        { 'key' => 'dosky',   'label' => 'Dosky' },
        { 'key' => 'zony',    'label' => 'Zóny (ghost)' }
      ].freeze

      KEYS = ROWS.map { |r| r['key'] }.freeze

      # Tagy, ktore smie zalozit PANEL (nie stavba) — viď zásada 2.
      CREATABLE_KEYS = %w[zony].freeze

      # Nazov kroku v ponuke Spat. Jeden pre vsetky tagy — pouzivatel vidi
      # „Spat: Viditeľnosť tagu", nie sedem roznych mien.
      OP_NAME = 'Viditeľnosť tagu'

      module_function

      # Meno tagu pre kluc — z KONSTANT BUILDEROV, ziadna kopia retazca.
      # Nenacitany builder (ciastocny load) = kluc jednoducho nema meno.
      def tag_name(key)
        case key.to_s
        when 'korpus'  then defined?(CabinetBuilder) ? const_of(CabinetBuilder, :PART_TAG_DEFAULT) : nil
        when 'chrbat'  then part_tag_name('back')
        when 'cela'    then part_tag_name('front_door')
        when 'vnutro'  then part_tag_name('shelf')
        when 'kovanie' then defined?(CabinetBuilder) ? const_of(CabinetBuilder, :HARDWARE_TAG) : nil
        when 'dosky'   then defined?(BoardBuilder) ? const_of(BoardBuilder, :BOARD_TAG) : nil
        when 'zony'    then defined?(Zones) ? const_of(Zones, :TAG) : nil
        end
      end

      def part_tag_name(role)
        return nil unless defined?(CabinetBuilder)

        map = const_of(CabinetBuilder, :PART_TAGS)
        map.is_a?(Hash) ? map[role] : nil
      end

      # Konstanta modulu. `BoardBuilder` ma svoje konstanty deklarovane VNUTRI
      # `class << self`, teda na singleton triede — preto sa hlada aj tam
      # (inak by tag dosiek z registra ticho vypadol).
      def const_of(mod, name)
        return mod.const_get(name) if mod.const_defined?(name)

        sc = mod.singleton_class
        sc.const_defined?(name) ? sc.const_get(name) : nil
      rescue StandardError
        nil
      end

      # Vrstva pre kluc, alebo nil. TAG SA TU NIKDY NETVORI ANI NEPREMENUVA
      # (`layers.add` patri builderom, premenovanie migracii v `Zones`).
      # Zony maju v starsich zakazkach ESTE stary nazov (`NOXUN_SLOTY`;
      # migracia bezi az pri stavbe ghostov) — citame ho rovnako tolerantne
      # ako `Zones.visible?`, inak by sa v starej zakazke tag „nenasiel"
      # a riadok by z ponuky vypadol (audit BLOCKER 3).
      def layer_of(model, key)
        return nil unless model

        name = tag_name(key)
        return nil if name.nil? || name.to_s.empty?

        lay = model.layers[name]
        if lay.nil? && key.to_s == 'zony' && defined?(Zones)
          old = const_of(Zones, :OLD_TAG)
          lay = model.layers[old] if old && !old.to_s.empty?
        end
        lay
      rescue StandardError => e
        Engine.log_error(e, 'Tags.layer_of') if defined?(Engine)
        nil
      end

      # Tag moze lezat v PRIECINKU tagov, ktory je skryty — vtedy ma sam
      # `visible? == true`, ale v modeli ho aj tak nevidno (audit F8).
      # Priecinok nezapiname: moze obsahovat cudzie tagy. Len to POVIEME.
      def folder_hidden?(layer)
        return false unless layer.respond_to?(:folder)

        f = layer.folder
        while f
          return true unless f.visible?

          f = f.respond_to?(:folder) ? f.folder : nil
        end
        false
      rescue StandardError
        false
      end

      # Stav pre UI. CISTE CITANIE — ziadna operacia, ziadny zapis, ziadny
      # krok Spat. Riadky su LEN za tagy, ktore v modeli naozaj su.
      #   visible       — vlastna viditelnost tagu (to, co prepina checkbox)
      #   folder_hidden — nadradeny priecinok tagov je skryty (tag je zapnuty,
      #                   ale vidiet ho aj tak nie je)
      #   hidden        — kolko tagov v modeli NEVIDNO (oboma sposobmi); podla
      #                   toho svieti ikona v raile
      def state(model)
        rows = ROWS.map do |r|
          lay = layer_of(model, r['key'])
          next nil unless lay

          vis = lay.visible? ? true : false
          { 'key' => r['key'], 'label' => r['label'], 'name' => lay.name.to_s,
            'visible' => vis, 'folder_hidden' => folder_hidden?(lay) }
        end.compact
        { 'rows' => rows,
          'hidden' => rows.count { |r| !r['visible'] || r['folder_hidden'] } }
      rescue StandardError => e
        Engine.log_error(e, 'Tags.state') if defined?(Engine)
        { 'rows' => [], 'hidden' => 0 }
      end

      # Prepnutie viditelnosti JEDNEHO tagu. Vrati novy `state(model)`;
      # ked sa nic nemenilo (neznamy kluc, tag neexistuje a nesmie vzniknut,
      # hodnota uz plati), NEOTVORI sa ziadna operacia a v ponuke Spat
      # nepribudne prazdny krok.
      # Do vysledku sa navyse prilepi `active_reset` = kreslenie sa muselo
      # presunut z prave skryteho tagu (zasada 4).
      def set_visible(model, key, visible)
        k = key.to_s
        return state(model) unless model && KEYS.include?(k)

        want = (visible == true)
        lay = layer_of(model, k)
        return state(model) if lay.nil? && !CREATABLE_KEYS.include?(k)

        name = tag_name(k)
        return state(model) if lay.nil? && (name.nil? || name.to_s.empty?)
        return state(model) if lay && (lay.visible? ? true : false) == want

        write(model, lay, name, want)
      rescue StandardError => e
        Engine.log_error(e, 'Tags.set_visible') if defined?(Engine)
        state(model)
      end

      # Samotny zapis — JEDNA operacia, ABORT pri vynimke (otvorena transakcia
      # by rozbila nasledujuce Spat).
      def write(model, lay, name, want)
        reset = false
        model.start_operation(OP_NAME, true)
        begin
          lay ||= model.layers.add(name)
          reset = move_active_layer_away(model, lay) unless want
          lay.visible = want
          model.commit_operation
        rescue StandardError => e
          begin
            model.abort_operation
          rescue StandardError
            nil
          end
          Engine.log_error(e, 'Tags.write') if defined?(Engine)
          return state(model)
        end
        state(model).merge('active_reset' => reset)
      end

      # SketchUp pri skryti aktivneho tagu prepne kreslenie sam a ticho —
      # robime to preto VEDOME, este pred skrytim a v tej istej operacii.
      # Vrati true, ked sa kreslenie naozaj presunulo.
      def move_active_layer_away(model, lay)
        return false unless model.respond_to?(:active_layer) && model.active_layer == lay

        untagged = model.layers[0]
        return false if untagged.nil? || untagged == lay

        model.active_layer = untagged
        true
      rescue StandardError
        false
      end
    end
  end
end
