# frozen_string_literal: true
# Regresny test hotfixu v0.5.39 (smoke 3.8., A-05): relay metody satelitneho
# okna MUSIA byt public — panel.rb ich vola zvonku ako `Modul.do_*(payload)`
# (flush handshake relay). `do_hw_csv` bola omylom definovana POD `private`
# (GH #127 P1 pridal metodu na zle miesto suboru) — CSV kovania padal LEN
# s otvorenym panelom; interna cesta handle_hw_csv -> do_hw_csv funguje aj
# pre private metodu (implicit receiver), preto to povodne testy nechytili.
#
# ŠT-1c PR B3: okno Vyroba (`ui/production_dialog.rb`) ZANIKLO — vsetky relaye
# panela mieria do okna ŠTÚDIO a telo kazdeho z nich zije v zdielanom jadre
# `ProductionCore`. Test preto strazi DVE veci naraz:
#   1) `StudioDialog.do_*` su PUBLIC (relay z panel.rb),
#   2) `ProductionCore.do_*` su PUBLIC (obal ich vola zvonku).
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/*.rb nie su v require zozname helpera (ui vrstva) — nacitavaju sa
# TU. Parse-time nema ziadne SketchUp API (UI::HtmlDialog, Sketchup.active_model
# a spol. su vyhradne VNUTRI metod, vyhodnocuju sa az pri volani). V SketchUpe
# su subory uz nacitane pluginom — nenacitavame ich druhykrat.
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_core')
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'studio_dialog')
end

RELAY_PANEL_RB = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel.rb'),
                           encoding: 'UTF-8')

NxTest.test('relay: metody okna Studio volane z panela su PUBLIC') do
  sd = Noxun::Engine::StudioDialog
  %i[do_export do_select do_hw_csv do_budget_xlsx do_cp_xlsx].each do |m|
    NxTest.assert(sd.respond_to?(m),
                  "StudioDialog.#{m} musi byt PUBLIC (nad `private` ciarou) — " \
                  'relay z panel.rb ju vola zvonku; respond_to? private metody nevidi')
  end
end

NxTest.test('relay: telo kazdeho relayu je v ZDIELANOM jadre a je PUBLIC') do
  pc = Noxun::Engine::ProductionCore
  %i[do_export do_select do_hw_csv do_budget_xlsx do_cp_xlsx do_budget].each do |m|
    NxTest.assert(pc.respond_to?(m), "ProductionCore.#{m} musi byt PUBLIC (vola ju obal okna)")
  end
end

NxTest.test('relay: panel uz NEMA ziadny callback zaniknuteho okna Vyroba') do
  %w[open_production production_do_select production_do_export
     production_do_hw_csv production_do_budget production_do_cp].each do |name|
    NxTest.refute(RELAY_PANEL_RB.include?("cb(dlg, '#{name}')"),
                  "callback #{name} zanikol spolu s oknom Vyroba (ŠT-1c PR B3)")
  end
  # A NAOPAK: kazdy z nich ma svoj protajsok v kanali Studia.
  %w[open_studio studio_do_select studio_do_export studio_do_hw_csv
     studio_do_budget_xlsx studio_do_cp_xlsx].each do |name|
    NxTest.assert(RELAY_PANEL_RB.include?("cb(dlg, '#{name}')"),
                  "kanal Studia musi mat callback #{name}")
  end
end

NxTest.test('relay: modul ProductionDialog v repe uz NEEXISTUJE') do
  NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog.rb')),
                'ui/production_dialog.rb zanikol (ŠT-1c PR B3)')
  %w[production.html js/production.js].each do |rel|
    NxTest.refute(File.exist?(File.join(NxTest::ROOT, 'noxun_engine', 'ui', *rel.split('/'))),
                  "ui/#{rel} zanikol (ŠT-1c PR B3)")
  end
end
