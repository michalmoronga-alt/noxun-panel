# frozen_string_literal: true
# Noxun Engine - Panel: sablony (save/delete/apply, merge) + toggle ghost zon.
# Cast modulu Panel (reopen) - zdiela ivary (dialog, active_zone_id, suspend guard)
# cez class << self. Nacitava panel.rb; ziadna logika mimo modulu.
module Noxun
  module Engine
    module Panel
      class << self
        # --- akcie: sablony --------------------------------------------------
        def handle_save_template(payload)
          data = parse(payload)
          model = Sketchup.active_model
          cab = find_cabinet(model)
          config = cab ? template_config_from(Store.config(cab) || {}) : template_config_from_fields(data)

          res = UI.inputbox(['Nazov sablony:'], [suggest_template_name(cab, data)], 'Ulozit sablonu')
          return if res == false # zrusene

          name = res[0].to_s.strip
          return set_status('Prazdny nazov — zrusene.', true) if name.empty?

          if TemplateStore.find(name) &&
             UI.messagebox("Sablona \"#{name}\" existuje. Prepisat?", MB_YESNO) != IDYES
            return set_status('Zrusene — sablona nezmenena.')
          end
          TemplateStore.upsert(name, config)
          push_templates
          set_status("Sablona \"#{name}\" ulozena.")
        end

        def handle_delete_template(payload)
          name = parse(payload)['template'].to_s
          return set_status('Vyber sablonu na vymazanie.', true) if name.empty?
          return unless UI.messagebox("Vymazat sablonu \"#{name}\"?", MB_YESNO) == IDYES

          TemplateStore.delete(name)
          push_templates
          set_status("Sablona \"#{name}\" vymazana.")
        end

        def handle_apply_template(payload)
          name = parse(payload)['template'].to_s
          tpl = TemplateStore.find(name)
          return set_status('Sablona sa nenasla.', true) if tpl.nil?
          model = Sketchup.active_model
          cab = find_cabinet(model)
          return set_status('Najprv oznac NOXUN korpus.', true) if cab.nil?

          # V0.3 FIX 1: MERGE, nie nahradenie. Konstrukcne kluce (+ zony/cela) zo sablony; ale
          # material + part_overrides ciela ZACHOVAJ (sablona ich prepise len ak ich explicitne nesie).
          merged = merge_template(existing_params(cab), tpl['config'])
          CabinetBuilder.rebuild(model, cab, merged)
          finish_cab(model, cab, "Sablona \"#{name}\" pouzita na #{Store.get(cab, 'cabinet_id')}.")
        end

        # Apply sablony = MERGE cieloveho korpusu so sablonou. Konstrukcne kluce beru zo sablony
        # (tpl_config), ale material_id/front/back + part_overrides + hardware_overrides ZOSTAVAJU
        # z ciela — aby sa nezahodili uzivatelove ABS/materialove upravy ani rucne pocty kovania.
        # Materialove pole prepiseme LEN ak ho sablona explicitne nesie (non-nil); oba overrides
        # sa beru VZDY z ciela (sablona ich nenesie — su viazane na konkretne dielce/zony zdroja).
        def merge_template(target_params, tpl_config)
          merged = tpl_config.dup
          merged['part_overrides'] = target_params['part_overrides'] || {}
          merged['hardware_overrides'] = target_params['hardware_overrides'] || []
          %w[material_id front_material_id back_material_id].each do |k|
            tv = present_str(tpl_config[k])
            merged[k] = tv || target_params[k]
          end
          merged
        end

        def handle_toggle_zones(val)
          model = Sketchup.active_model
          visible = truthy?(val)
          Zones.set_visible(model, visible)
          model.active_view.invalidate if model.active_view
          set_status(visible ? 'Ghost zony zapnute.' : 'Ghost zony vypnute.')
        end

      end
    end
  end
end
