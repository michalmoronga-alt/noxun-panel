# frozen_string_literal: true
# Regresny test hotfixu v0.5.39 (smoke 3.8., A-05): relay trojica okna Vyroba
# MUSI byt public — panel.rb ju vola zvonku ako ProductionDialog.do_*(payload)
# (flush handshake relay). do_hw_csv bola omylom definovana POD `private`
# (GH #127 P1 pridal metodu na zle miesto suboru) — CSV kovania padal LEN
# s otvorenym panelom; interna cesta handle_hw_csv -> do_hw_csv funguje aj
# pre private metodu (implicit receiver), preto to povodne testy nechytili.
require_relative '../helper' unless defined?(NxTest)

# Headless: ui/production_dialog.rb nie je v require zozname helpera (ui
# vrstva) — nacitava sa TU. Parse-time nema ziadne SketchUp API (UI::HtmlDialog,
# Sketchup.active_model a spol. su vyhradne VNUTRI metod, vyhodnocuju sa az pri
# volani). V SketchUpe je subor uz nacitany pluginom — nenacitavame druhykrat.
require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'production_dialog') if NxTest.headless?

NxTest.test('production_dialog: relay metody do_export/do_select/do_hw_csv su public') do
  pd = Noxun::Engine::ProductionDialog
  %i[do_export do_select do_hw_csv].each do |m|
    NxTest.assert(pd.respond_to?(m),
                  "ProductionDialog.#{m} musi byt PUBLIC (nad `private` ciarou) — " \
                  'relay z panel.rb ju vola zvonku; respond_to? private metody nevidi')
  end
end
