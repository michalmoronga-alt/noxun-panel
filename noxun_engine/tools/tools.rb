# frozen_string_literal: true
# Noxun Engine — NASTROJE-1: spolocna vrstva nastrojov (Mower + Snaper) a JEDINY
# registrator ich toolbaru a menu.
#
# PRECO VLASTNY TOOLBAR: toolbar enginu ma zelezne pravidlo „do modelu sa
# NEZAPISUJE" (D-103/D-105) — nastroje model MENIA, preto maju vlastny panel
# „Noxun Nastroje". Verziu, aktualizaciu (D-52) aj logovanie preberaju od enginu;
# vlastne registracie rozsireni zanikli.
#
# REGISTRACIA JE IDEMPOTENTNA (audit FIX 9): `file_loaded?` guard + procesna
# referencia `@toolbar` (drzi ju aj kvoli GC). Legacy Mower staval toolbar pri
# KAZDOM nacitani suboru bez guardu — po `load` pribudol dalsi rad tlacidiel.
module Noxun
  module Engine
    module Tools
      TOOLBAR_NAME = 'Noxun Nástroje'
      ICON_DIR = File.join(PLUGIN_DIR, 'ui', 'icons', 'tools')

      # Spolocne odmietnutia (jeden text pre oba nastroje).
      MSG_EDIT_CONTEXT = 'Noxun Nástroje: najprv ukonči úpravu komponentu (Esc) — nástroje pracujú ' \
                         'len nad modelom, nie vnútri otvoreného komponentu.'
      MSG_NESTED       = 'Noxun Nástroje: skrinka je vnorená v inom komponente — nástroje vedia ' \
                         'pracovať len so skrinkou na najvyššej úrovni modelu.'
      MSG_BUSY         = 'Noxun Nástroje: predchádzajúca zmena sa ešte spracúva — skús o chvíľu znova.'
      MSG_NOT_RIGID    = 'Noxun Nástroje: skrinka nesie mierku alebo skosenie — vráť ju krokom Späť ' \
                         'do pôvodného tvaru a nástroj zopakuj.'
      MSG_PICK_NONE    = 'Noxun Nástroje: najprv označ skrinku.'
      MSG_PICK_MANY    = 'Noxun Nástroje: označ len jednu skrinku.'

      class << self
        # --- vyber a kontext -------------------------------------------------

        def active_model
          Sketchup.active_model
        rescue StandardError
          nil
        end

        # Presne jedna instancia/skupina vo vybere; inak nemodalna hlaska a nil.
        def pick_target(model)
          picks = model.selection.to_a.select do |ent|
            ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
          end
          return picks.first if picks.length == 1

          warn(picks.empty? ? MSG_PICK_NONE : MSG_PICK_MANY)
          nil
        rescue StandardError => e
          Engine.log_error(e, 'Tools.pick_target')
          nil
        end

        # `transform_entities` interpretuje transformaciu GLOBALNE len v aktivnom
        # kontexte a jeho rodicoch (oficialna dokumentacia, outside-in packet) —
        # preto nastroje pracuju vyhradne v roote.
        def root_context?(model)
          path = model.active_path
          path.nil? || path.length.zero?
        rescue StandardError
          false
        end

        # Objekt na NAJVYSSEJ urovni dokumentu (rodic je model, nie definicia).
        def top_level?(inst)
          inst.parent.is_a?(Sketchup::Model)
        rescue StandardError
          false
        end

        # Ktorou cestou ist — rozhodovanie je v CISTOM jadre (MowerCalc.route).
        def route(model, inst)
          MowerCalc.route(kind: Store.kind(inst), root_context: root_context?(model),
                          top_level: top_level?(inst))
        end

        # Spolocne odmietnutie kontextu. `true` = volajuci ma SKONCIT.
        def refused_context?(route)
          case route
          when :edit_context then warn(MSG_EDIT_CONTEXT)
          when :nested then warn(MSG_NESTED)
          else return false
          end
          true
        end

        def noxun_route?(route)
          route == :cabinet || route == :board
        end

        # --- bariera pred mutaciou -------------------------------------------
        # 1. observer do POKOJA (`flush_pending!`) — inak by jeho odlozeny tik
        #    prilepil transparentny dedup/presun ghostov na krok pouzivatela,
        #    ktory s nim nema nic spolocne;
        # 2. az POTOM sa transformacia cita ZNOVA a musi byt RIGIDNA — sikma
        #    alebo skalovana skrinka by dala nezmyselny posun a `reject_scale`
        #    by neskor vratil polohu spred prikazu (ziadny tichy neuspech).
        def settle!(model, inst)
          unless ScaleWatch.flush_pending!(model)
            warn(MSG_BUSY)
            return false
          end
          return true if CabinetBuilder.rigid_matrix?(Array(inst.transformation.to_a))

          warn(MSG_NOT_RIGID)
          false
        rescue StandardError => e
          Engine.log_error(e, 'Tools.settle!')
          warn(MSG_BUSY)
          false
        end

        # --- mutacia ----------------------------------------------------------
        # JEDNO miesto, kde nastroje menia model. Nad NOXUN objektom bezi CELA
        # operacia pod `ScaleWatch.guard` (ako vlastne stavby enginu), v tej
        # istej operacii sa presunu ghost zony a AZ PO uspesnom commite sa
        # zapamata nova stabilna poloha.
        def mutate(model, inst, op_name, noxun, &block)
          runner = lambda do
            model.start_operation(op_name, true)
            begin
              block.call
              Zones.move_ghost(model, inst) if noxun && cabinet?(inst) && defined?(Zones)
              model.commit_operation
            rescue StandardError => e
              begin
                model.abort_operation
              rescue StandardError
                nil
              end
              raise e
            end
          end

          if noxun
            ScaleWatch.guard { runner.call }
            # Pod guardom sa observer k cache nedostane — bez tohto by neskor
            # ODMIETNUTA sikma mierka cez `reject_scale` obnovila polohu SPRED
            # prikazu nastroja. `remember_transform` si rigiditu overi sam.
            ScaleWatch.remember_transform(inst)
          else
            runner.call
          end
          true
        rescue StandardError => e
          Engine.log_error(e, 'Tools.mutate')
          warn("Noxun Nástroje: #{op_name} — zmena sa nepodarila (#{e.message}).")
          false
        end

        def cabinet?(inst)
          Store.kind(inst).to_s == 'cabinet'
        rescue StandardError
          false
        end

        # --- nemodalne hlasenia ------------------------------------------------
        # Modal z tlacidla toolbaru je zle UX (vzor Snapera). Vysledok ide do
        # statusu; odmietnutie navyse pipne a ukaze notifikaciu rozsirenia.
        def info(msg)
          Sketchup.status_text = msg
          nil
        rescue StandardError
          nil
        end

        def warn(msg)
          begin
            UI.beep
          rescue StandardError
            nil
          end
          Sketchup.status_text = msg
          notify(msg)
          nil
        rescue StandardError
          nil
        end

        # Referenciu drzi `@note` — bez nej ju GC zavrie skor, nez ju vidno.
        def notify(msg)
          ext = Engine.respond_to?(:extension) ? Engine.extension : nil
          return unless ext && defined?(UI::Notification)

          @note = UI::Notification.new(ext, msg)
          @note.show
        rescue StandardError => e
          Engine.log_error(e, 'Tools.notify')
        end

        # --- registracia toolbaru a menu ---------------------------------------
        # `parent_menu` = submenu „Noxun Engine" z `main.rb`. Druhe volanie
        # `UI.menu('Extensions').add_submenu('Noxun Engine')` by v SketchUpe
        # vyrobilo DRUHE rovnomenne submenu, preto sa podava uz existujuce.
        def install!(parent_menu = nil)
          return @toolbar if @toolbar
          return nil unless defined?(UI::Toolbar)

          cmds = build_commands
          @toolbar = build_toolbar(cmds)
          unless file_loaded?(__FILE__)
            build_menu(parent_menu, cmds) if parent_menu
            file_loaded(__FILE__)
          end
          @toolbar
        rescue StandardError => e
          Engine.log_error(e, 'Tools.install!')
          nil
        end

        # JEDNA sada `UI::Command` pre toolbar aj menu — dva rôzne objekty by
        # znamenali dve miesta, kde sa spravanie moze rozist.
        def build_commands
          [
            command('−90°', 'Otočiť o −90° (os Z, pivot = stred obálky)', 'rotate_ccw') { Mower.rotate(-90) },
            command('+90°', 'Otočiť o +90° (os Z, pivot = stred obálky)', 'rotate_cw') { Mower.rotate(90) },
            command('180°', 'Otočiť o 180° (os Z, pivot = stred obálky)', 'rotate_180') { Mower.rotate(180) },
            command('Z = 0', 'Položiť na nulovú výšku (Z = 0)', 'z0') { Mower.set_z_zero },
            command('Z posun…', 'Nastaviť výšku Z v mm', 'zmove') { ZDialog.show },
            command('Kópia vľavo', 'Kópia skrinky vľavo o jej šírku (vlastná os X)', 'copy_left') { Mower.copy(:left) },
            command('Kópia vpravo', 'Kópia skrinky vpravo o jej šírku (vlastná os X)', 'copy_right') { Mower.copy(:right) },
            command('Prisunúť vľavo', 'Prisunúť vľavo na doraz k najbližšej prekážke', 'snap_left') { Snaper.snap(:left) },
            command('Prisunúť vpravo', 'Prisunúť vpravo na doraz k najbližšej prekážke', 'snap_right') { Snaper.snap(:right) }
          ]
        end

        # D-52a (B2): KAZDY vstupny bod pluginu ma restart latch — po uspesnej
        # aktualizacii bezi v pamati STARY Ruby kod nad NOVYMI subormi, takze
        # prikaz musi odmietnut UZ V TELE (nie az v module nastroja).
        def command(label, tip, icon, &action)
          cmd = UI::Command.new(label) do
            next if Engine.update_restart_pending?

            action.call
          end
          cmd.tooltip = tip
          cmd.status_bar_text = tip
          icon_for(cmd, icon)
          cmd
        end

        # Mower ma PNG v dvoch velkostiach, Snaper jedno SVG pre obe.
        def icon_for(cmd, base)
          svg = File.join(ICON_DIR, "#{base}.svg")
          if File.exist?(svg)
            cmd.small_icon = svg
            cmd.large_icon = svg
            return
          end
          small = File.join(ICON_DIR, "#{base}_16.png")
          large = File.join(ICON_DIR, "#{base}_24.png")
          cmd.small_icon = small if File.exist?(small)
          cmd.large_icon = large if File.exist?(large)
        end

        # TROJSTAV (audit 2 NOTE): `install_toolbar` enginu vola len `restore`.
        # Tu je spravanie vyslovne — pouzivatel, ktory si panel skryl, ho po
        # restarte NEDOSTANE spat, ale pri prvom spusteni ho uvidi.
        def build_toolbar(cmds)
          tb = UI::Toolbar.new(TOOLBAR_NAME)
          cmds.each { |c| tb.add_item(c) }
          state = tb.get_last_state
          # TB_NEVER_SHOWN (-1) = prve spustenie -> ukaz; TB_VISIBLE (1) = vrat
          # na povodne miesto; TB_HIDDEN (0) = pouzivatel si ho skryl, nechaj tak.
          tb.show if state == TB_NEVER_SHOWN
          tb.restore if state == TB_VISIBLE
          tb
        rescue StandardError => e
          Engine.log_error(e, 'Tools.build_toolbar')
          tb
        end

        def build_menu(parent_menu, cmds)
          menu = parent_menu.add_submenu('Nástroje')
          cmds.each { |c| menu.add_item(c) }
          menu
        rescue StandardError => e
          Engine.log_error(e, 'Tools.build_menu')
          nil
        end
      end
    end
  end
end
