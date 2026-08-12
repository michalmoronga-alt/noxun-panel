# frozen_string_literal: true
# D-101 — panel sa po Spat/Znova obnovi. Observer sa headless spustit neda
# (potrebuje zivy SketchUp) — plne scenare su v tests/sketchup/su_runner.rb
# (sekcia D-101). Tu su STATICKE guardy na kontrakt, ktory sa nesmie stratit
# pri buducej uprave selection.rb.
require_relative '../helper' unless defined?(NxTest)

module NxD101
  SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'selection.rb'),
                  encoding: 'UTF-8')
end

NxTest.test('D-101: PanelModelObserver pokryva undo, redo aj abort') do
  NxTest.assert(NxD101::SRC.include?('class PanelModelObserver < Sketchup::ModelObserver'),
                'PanelModelObserver chyba — panel by po Ctrl+Z visel na starom stave')
  %w[onTransactionUndo onTransactionRedo onTransactionAbort].each do |cb|
    NxTest.assert(NxD101::SRC.include?("def #{cb}(model)"), "chyba callback #{cb}")
  end
end

NxTest.test('D-101: refresh z observera je VYHRADNE citanie (dedup: false)') do
  # Lekcia D-103: dedup pyta ScaleWatch.request_dedup = zasah do modelu.
  # Z observer cesty je zakazany — inak by sa stal vrcholom undo stacku.
  body = NxD101::SRC[/def flush_txn_refresh.*?\n        end/m].to_s
  NxTest.refute(body.empty?, 'flush_txn_refresh sa nenasiel')
  NxTest.assert(body.include?('push_selected(model, dedup: false)'),
                "odlozeny refresh musi volat push_selected s dedup: false: #{body}")
end

NxTest.test('D-101: observer callback je tenky — refresh bezi az v timeri') do
  body = NxD101::SRC[/def on_model_txn.*?\n        end/m].to_s
  NxTest.refute(body.empty?, 'on_model_txn sa nenasiel')
  NxTest.refute(body.include?('push_selected'),
                'v observer kontexte sa NESMIE pushovat — len naplanovat refresh')
  NxTest.assert(body.include?('request_txn_refresh'), 'callback musi naplanovat odlozeny refresh')
  NxTest.assert(NxD101::SRC.include?('UI.start_timer'), 'refresh musi bezat MIMO observer kontextu')
end

NxTest.test('D-101: guardy handlera — dialog, ten isty a aktivny dokument') do
  guard = NxD101::SRC[/def txn_model_ok\?.*?\n        end/m].to_s
  NxTest.assert(guard.include?('@observer_model') && guard.include?('Sketchup.active_model'),
                "multi-model guard chyba: #{guard}")
  # Guard sa overuje DVAKRAT: v callbacku aj tesne pred pushom (odlozeny
  # callback zo stareho dokumentu nesmie prepisat Inspector aktivneho).
  NxTest.assert_equal(2, NxD101::SRC.scan(/return unless txn_model_ok\?\(model\)/).length)
end

NxTest.test('D-101: detach ma pre kazdy observer vlastny chraneny krok') do
  body = NxD101::SRC[/def detach_observer.*?\n        end/m].to_s
  NxTest.assert(body.scan(/detach_one\(/).length == 2,
                "zlyhanie jedneho remove nesmie preskocit druhy: #{body}")
  NxTest.assert(body.include?('model.selection.remove_observer') && body.include?('model.remove_observer'),
                'detach musi odvesit observer vyberu aj observer transakcii')
end
