# frozen_string_literal: true
# M-R / MR-1A: jeden volitelny vzhlad dosiek aj ABS tej istej skupiny/povrchu.
# Bez SketchUp API. Exporter dodava staging subor a overuje jeho nativny obsah.
require 'securerandom'
require 'time'

module Noxun
  module Engine
    module Materials
      APPEARANCE_KEYS = %w[version id mode saved_at].freeze
      APPEARANCE_UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/.freeze
      class AppearanceError < StandardError; end

      module_function

      # Uzavrety descriptor; chybajuci kluc riesi volajuci. Nil NIE JE absent.
      def normalize_appearance(value)
        valid = value.is_a?(Hash) && value.keys.sort == APPEARANCE_KEYS.sort &&
                value['version'].is_a?(Integer) && value['version'] == 1 &&
                value['id'].is_a?(String) && APPEARANCE_UUID.match?(value['id']) &&
                %w[native color].include?(value['mode']) && value['saved_at'].is_a?(String)
        if valid
          stamp = value['saved_at']
          valid = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/.match?(stamp) &&
                  Time.iso8601(stamp).utc.iso8601 == stamp
        end
        raise AppearanceError, 'Neplatný alebo novší formát vzhľadu — oprav katalóg alebo aktualizuj plugin.' unless valid

        APPEARANCE_KEYS.to_h { |key| [key, value[key]] }
      rescue ArgumentError, TypeError
        raise AppearanceError, 'Neplatný formát vzhľadu — oprav katalóg alebo aktualizuj plugin.'
      end

      def put_appearance_field(out, attrs)
        return out unless attrs.key?('appearance') || attrs.key?(:appearance)

        value = attrs.key?('appearance') ? attrs['appearance'] : attrs[:appearance]
        out['appearance'] = normalize_appearance(value)
        raise AppearanceError, 'UNI materiál nemá uložený vzhľad.' if uni?(out)
        out
      end

      # group_id zostava opaque. Povrch zdiela presne identity_norm s UI.
      def appearance_scope_key(rec)
        return nil unless rec.is_a?(Hash) && !uni?(rec)
        gid = rec['group_id']
        return nil unless gid.is_a?(String) && !gid.strip.empty?

        [identity_norm(gid), identity_norm(rec['structure'])]
      end

      def appearance_rows(data)
        [['sheets', 'material_id', 'sheet'], ['edges', 'abs_id', 'edge']].flat_map do |list, id_key, kind|
          Array(data[list]).map { |rec| [kind, rec[id_key], rec] }
        end
      end

      def appearance_integrity_error(data)
        return 'katalóg nemá polia dosiek a ABS' unless data.is_a?(Hash) &&
          data['sheets'].is_a?(Array) && data['edges'].is_a?(Array)
        return 'katalóg obsahuje neplatný záznam' unless (data['sheets'] + data['edges']).all? { |rec| rec.is_a?(Hash) }
        appearance_rows(data).each do |_kind, _id, rec|
          next unless rec.key?('appearance')
          normalize_appearance(rec['appearance'])
          return 'vzhľad nemá platnú skupinu alebo patrí UNI materiálu' unless appearance_scope_key(rec)
        end
        nil
      rescue AppearanceError => e
        e.message
      end

      # Bez cache, seedu aj obnovy zo zalohy. Zapis nesmie pracovat s nahradnymi datami.
      def appearance_fresh_catalog!(full_health: true)
        data = parse_catalog_file(path)
        raise AppearanceError, 'Katalóg sa nedá bezpečne načítať — obnov sekciu Materiály.' unless data
        issue = appearance_integrity_error(data)
        raise AppearanceError, issue if issue
        raise AppearanceError, 'Katalóg je v novšej schéme — aktualizuj plugin.' if schema_of(data) > SCHEMA_CURRENT
        if full_health
          state, reason = assess_catalog_schema(data)
          raise AppearanceError, reason if state != :ok
        end
        data
      end

      def appearance_scope_in(data, kind, anchor_id)
        raise AppearanceError, 'Neplatný druh materiálu.' unless %w[sheet edge].include?(kind)
        anchor = appearance_rows(data).find { |k, id, _rec| k == kind && id == anchor_id }
        raise AppearanceError, 'Materiál už v katalógu nie je — obnov sekciu Materiály.' unless anchor
        key = appearance_scope_key(anchor[2])
        raise AppearanceError, 'UNI alebo materiál bez skupiny nemá spoločný vzhľad.' unless key

        members = appearance_rows(data).select { |_k, _id, rec| appearance_scope_key(rec) == key }
        # Absent je samostatny stav, nie hodnota ktoru mozno z porovnania vypustit.
        states = members.map { |_k, _id, rec| rec['appearance'] }.uniq
        baseline_rows = members.map { |k, id, rec| [k, id, rec['appearance']] }.sort_by { |row| row[0, 2] }
        { 'scope' => key, 'members' => members.map { |k, id, _rec| { 'kind' => k, 'id' => id } },
          'baseline' => Digest::SHA256.hexdigest(JSON.generate([key, baseline_rows])),
          'conflict' => states.length > 1, 'appearance' => states.length == 1 ? states.first : nil }
      end

      # Read-only podklad formulara, platny aj pre explicitnu napravu konfliktu.
      def appearance_scope(kind, anchor_id)
        with_catalog_lock { [:ok, appearance_scope_in(appearance_fresh_catalog!, kind, anchor_id)] }
      rescue AppearanceError, IOError, SystemCallError => e
        [:invalid, { 'message' => e.message }]
      end

      def appearance_file(id)
        raise AppearanceError, 'Neplatné ID vzhľadu.' unless id.is_a?(String) && APPEARANCE_UUID.match?(id)
        File.join(dir, 'appearances', "#{id}.skm")
      end

      # Interny exporter dostane (staging_path, descriptor, scope_key). Jeho true
      # znamena, ze overil NATIVNY obsah; toto jadro overuje iba existenciu/bajty.
      # Export nebezi pod catalog lockom. Druhy fresh baseline guard je az pred
      # immutable rename + JSON publikaciou. Zlyhanie JSON smie nechat orphan.
      def publish_appearance(kind, anchor_id, baseline:, mode:, &exporter)
        return [:catalog_read_only, { 'message' => catalog_read_only_message }] if catalog_read_only?
        return [:invalid, { 'message' => 'Neplatný režim vzhľadu.' }] unless %w[native color].include?(mode)
        status, initial = appearance_scope(kind, anchor_id)
        return [status, initial] unless status == :ok
        return [:stale, initial] unless baseline.is_a?(String) && baseline == initial['baseline']
        descriptor = { 'version' => 1, 'id' => SecureRandom.uuid, 'mode' => mode,
                       'saved_at' => Time.now.utc.iso8601 }
        target = appearance_file(descriptor['id'])
        staging = "#{target}.staging"
        if mode == 'native'
          raise AppearanceError, 'Chýba natívny exportér vzhľadu.' unless exporter
          FileUtils.mkdir_p(File.dirname(target))
          raise AppearanceError, 'Súbor vzhľadu sa nepodarilo overiť.' unless
            exporter.call(staging, JsonFileStore.deep_copy(descriptor), initial['scope'].dup) == true &&
            File.file?(staging) && File.size(staging).positive?
        end
        with_catalog_lock do
          data = appearance_fresh_catalog!
          current = appearance_scope_in(data, kind, anchor_id)
          return [:stale, current] unless current['baseline'] == baseline
          if mode == 'native'
            raise AppearanceError, 'Revízia vzhľadu už existuje.' if File.exist?(target)
            File.rename(staging, target)
          end
          appearance_rows(data).each do |_k, _id, rec|
            next unless appearance_scope_key(rec) == current['scope']
            rec['appearance'] = descriptor.dup
          end
          # Zapis smie zmenit iba tento overeny scope; ostatne riadky drzi
          # centralny backstop rovnako ako pri beznej zmene ceny.
          unless write_unlocked(data, current['scope'])
            return [:write_failed, { 'message' => 'Zápis katalógu zlyhal.' }]
          end
          [:ok, appearance_scope_in(data, kind, anchor_id)]
        end
      rescue StandardError => e
        [:invalid, { 'message' => e.message }]
      ensure
        begin
          File.delete(staging) if staging && File.exist?(staging)
        rescue StandardError => e
          Engine.log_error(e, 'Materials.publish_appearance staging cleanup') if defined?(Engine)
        end
      end

      def copy_appearance!(rec, source)
        rec.delete('appearance')
        rec.delete(:appearance)
        rec['appearance'] = normalize_appearance(source['appearance']) if source && source.key?('appearance')
        rec
      end

      # Legacy payload nesmie priniest descriptor ani ho stratit. Volat POD
      # zamkom pred normalize a sync_duplaks_in! s cerstvym data.
      def appearance_upsert_attrs(attrs, data, kind)
        rec = attrs.reject { |key, _value| key.to_s == 'appearance' }
        id_key = kind == :edge ? 'abs_id' : 'material_id'
        list = kind == :edge ? 'edges' : 'sheets'
        id = (rec[id_key] || rec[id_key.to_sym]).to_s
        old = data[list].find { |row| row[id_key] == id }
        copy_appearance!(rec, old)
      end

      # Jedna poistka pre vsetky katalogove write cesty: preserve, dedenie aj
      # presun medzi scopes sa odvodi z cerstveho disku, nikdy z UI payloadu.
      def prepare_appearance_write!(data, authorized_scope: nil)
        if File.exist?(path)
          # Bezny write mohol historicky explicitne opravit hybrid bez
          # group_id uplnym payloadom. Tento kontrakt nemeni appearance:
          # shape/schema/appearance su fresh guard, group/duplak opravu
          # posudzuju doterajsie guardy vystupneho payloadu. Purpose publish
          # vyssie naopak vyzaduje uplne zdravy povodny katalog.
          fresh = appearance_fresh_catalog!(full_health: false)
        elsif File.exist?("#{path}.bak") || File.exist?(pre_schema2_backup_path)
          raise AppearanceError, 'Katalóg chýba — najprv obnov zálohu.'
        else
          fresh = { 'sheets' => [], 'edges' => [] }
        end
        # Nezahodit poskodeny descriptor v prichadzajucom internom payloade.
        if (issue = appearance_integrity_error(data))
          raise AppearanceError, issue
        end
        old_rows = appearance_rows(fresh)
        appearance_rows(data).each do |kind, id, rec|
          key = appearance_scope_key(rec)
          next if authorized_scope && key == authorized_scope
          old = old_rows.find { |k, old_id, _r| k == kind && old_id == id }&.last
          if old && appearance_scope_key(old) == key
            copy_appearance!(rec, old)
          elsif key
            matches = old_rows.select { |_k, _id, row| appearance_scope_key(row) == key }
            states = matches.map { |_k, _id, row| row['appearance'] }.uniq
            raise AppearanceError, 'Vzhľady povrchu sa nezhodujú — najprv ulož spoločný vzhľad.' if states.length > 1
            copy_appearance!(rec, matches.first&.last)
          else
            copy_appearance!(rec, nil)
          end
        end
        # Duplak ma jedineho vlastnika vzhladu: svoj zdroj. Kopirovanie absent
        # stav aj explicitny color odstrania rovnako ako bezny sync zdroja.
        data['sheets'].each do |rec|
          next unless duplak?(rec)
          source = data['sheets'].find { |row| row['material_id'] == rec['source_material_id'] }
          if source && (rec.key?('appearance') || source.key?('appearance')) &&
             appearance_scope_key(rec) != appearance_scope_key(source)
            raise AppearanceError, 'Duplák a jeho zdroj nemajú rovnakú skupinu a povrch — oprav väzbu.'
          end
          copy_appearance!(rec, source) if source
        end
        true
      end
    end
  end
end
