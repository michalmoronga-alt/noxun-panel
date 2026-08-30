# frozen_string_literal: true
# 1d/R-02b — DocKey: STABILNY kluc dokumentu pre identity guardy.
#
# PRECO to existuje: SketchUp meni Model#guid pri KAZDOM ulozeni, takze guardy
# postavene na guid videli Ctrl+S ako prepnutie dokumentu (debounced edit sa
# zahodil, nxDropDocState zmazal rozpisany stav). DocKey dava token viazany na
# OBJEKT modelu: novy dokument = novy objekt = novy token; ulozenie, prve
# ulozenie aj Save As identitu NEMENIA (Codex audit R-02b BLOCKER 3 — rotacia
# tokenu pocas zivota okna nema resync cestu ku klientom).
#
# Sada je BEHAVIORALNA (DocKey je cisty Ruby, ziadne SketchUp API): stub model
# nesie path/guid/valid? ako SketchUp a testy simuluju save/Save As/zanik
# zmenou tychto poli. K tomu zdrojove kontrakty: vsetci serverovi producenti
# `model_guid` beru hodnotu z DocKey (ziadne priame `model.guid` v identity
# cestach).
require_relative '../helper' unless defined?(NxTest)

DK = Noxun::Engine::DocKey

# Stub modelu: guid sa meni pri "ulozeni", path pri "Save As", valid? pri
# zaniku — presne osi, po ktorych sa hybe realny SketchUp dokument.
class DkFakeModel
  attr_accessor :path, :guid, :alive

  def initialize(path: '', guid: 'G-1')
    @path = path
    @guid = guid
    @alive = true
  end

  def valid?
    @alive
  end
end

NxTest.test('DocKey: obycajne ulozenie (Ctrl+S) identitu NEMENI') do
  DK.reset!
  m = DkFakeModel.new(path: 'C:/Zakazky/Klinika.skp', guid: 'G-1')
  t1 = DK.key(m)
  m.guid = 'G-2' # SketchUp pri save meni guid — presne to guardy nesmu vidiet
  t2 = DK.key(m)
  NxTest.assert(!t1.empty?, 'token nie je prazdny')
  NxTest.assert_equal(t1, t2, 'save nesmie zmenit identitu dokumentu (cela oprava R-02b)')
end

NxTest.test('DocKey: prve ulozenie ani Save As identitu NEMENIA (zivot objektu)') do
  # Vedome rozhodnutie (Codex audit R-02b, BLOCKER 3): rotacia tokenu pocas
  # zivota okna by nechala klienta drziaceho staru identitu (napr. sekcia
  # Materialy) odmietanym donekonecna. Je to stale ten isty rozrobeny
  # dokument; kopia .skp po otvoreni aj tak dostane NOVY objekt = novy token.
  DK.reset!
  m = DkFakeModel.new(path: '', guid: 'G-1')
  t_untitled = DK.key(m)
  m.path = 'C:/Zakazky/Nova.skp' # prve ulozenie: pribudne cesta, zmeni sa guid
  m.guid = 'G-2'
  NxTest.assert_equal(t_untitled, DK.key(m), 'prve ulozenie identitu nemeni')
  m.path = 'C:/Zakazky/Nova v2.skp' # Save As
  m.guid = 'G-3'
  NxTest.assert_equal(t_untitled, DK.key(m), 'Save As identitu nemeni')
end

NxTest.test('DocKey: iny objekt modelu = ina identita (File > New / Open)') do
  DK.reset!
  a = DkFakeModel.new(path: 'C:/Zakazky/A.skp')
  b = DkFakeModel.new(path: 'C:/Zakazky/B.skp')
  NxTest.refute(DK.key(a) == DK.key(b), 'dva dokumenty nesmu zdielat identitu')
end

NxTest.test('DocKey: dva NEULOZENE dokumenty maju rozne identity') do
  # Cesta ich nerozlisi (obe prazdne) — rozlisit ich musi objekt modelu.
  DK.reset!
  a = DkFakeModel.new(path: '')
  b = DkFakeModel.new(path: '')
  NxTest.refute(DK.key(a) == DK.key(b), 'dve Untitled zakazky nesmu zdielat identitu')
end

NxTest.test('DocKey: recyklovany object_id nezdedi cudziu identitu') do
  # GC moze object_id zomreteho modelu pridelit novemu — registry preto drzi
  # referenciu a overuje `equal?` (vzor SESSION_KEY_BRIDGE).
  DK.reset!
  a = DkFakeModel.new(path: '')
  token_a = DK.key(a)
  b = DkFakeModel.new(path: '')
  # Simulacia recyklacie: zaznam A presunieme pod object_id, pod ktorym pride B.
  reg = DK.instance_variable_get(:@registry)
  entry_a = reg.values.first
  reg.clear
  reg[b.object_id] = entry_a
  NxTest.refute(DK.key(b) == token_a, 'zaznam ineho objektu sa nesmie prevziat (equal? guard)')
end

NxTest.test('DocKey: ne-model a chyba = prazdna identita (fail-closed, BLOCKER 1)') do
  DK.reset!
  NxTest.assert_equal('', DK.key(nil), 'nil model = prazdno (prisne guardy odmietnu)')
  NxTest.assert_equal('', DK.key(Object.new), 'objekt bez path = prazdno')
  exploding = DkFakeModel.new
  def exploding.respond_to?(_name, _priv = false)
    raise 'boom'
  end
  NxTest.assert_equal('', DK.key(exploding),
                      'chyba pri citani objektu = prazdno — NIKDY nie vymysleny platny token')
end

NxTest.test('DocKey: zivy dokument NIKDY nepride o token (ziadny strop, BLOCKER 2)') do
  # macOS scenar: vela otvorenych dokumentov naraz — vytlaceny zivy zaznam by
  # po navrate dostal novy token a nxSetModelGuid by zahodil rozpisane drafty.
  DK.reset!
  docs = Array.new(40) { |i| DkFakeModel.new(path: "C:/Zakazky/#{i}.skp") }
  tokens = docs.map { |m| DK.key(m) }
  again = docs.map { |m| DK.key(m) }
  NxTest.assert_equal(tokens, again, '40 zivych dokumentov, vsetky tokeny stabilne')
  NxTest.assert_equal(40, tokens.uniq.length, 'a kazdy ma vlastny')
end

NxTest.test('DocKey: zaznam ZANIKNUTEHO dokumentu sa uprace pri novom tokene') do
  DK.reset!
  dead = DkFakeModel.new(path: 'C:/Zakazky/Zavrena.skp')
  DK.key(dead)
  dead.alive = false
  live = DkFakeModel.new(path: 'C:/Zakazky/Nova.skp')
  t_live = DK.key(live) # novy token = okamih upratovania
  reg = DK.instance_variable_get(:@registry)
  NxTest.assert_equal(1, reg.length, 'mrtvy zaznam je prec, zivy ostal')
  NxTest.assert_equal(t_live, DK.key(live), 'a zivy token sa upratovanim nezmenil')
end

NxTest.test('DocKey: token je unikatny aj naprieč sedeniami (nahodny, nie citac)') do
  # ProductionCore persistuje `guid:<hodnota>` kluce neulozenych zakaziek do
  # vepo_settings.json — deterministicky citac by po restarte kolidoval.
  DK.reset!
  a = DK.key(DkFakeModel.new(path: ''))
  DK.reset! # "novy proces"
  b = DK.key(DkFakeModel.new(path: ''))
  NxTest.assert(a.start_with?(Noxun::Engine::DocKey::TOKEN_PREFIX), 'token ma prefix nxdoc-')
  NxTest.refute(a == b, 'dve sedenia nesmu vyrobit ten isty token')
end

# --- Zdrojove kontrakty: identity guardy uz NIKDE necitaju model.guid --------

NX_DK_PRODUCERS = %w[
  noxun_engine/ui/panel/sync.rb
  noxun_engine/ui/production_core.rb
  noxun_engine/ui/materials_dialog.rb
  noxun_engine/ui/rules_dialog.rb
  noxun_engine/ui/hardware_catalog_dialog.rb
  noxun_engine/core/materials_replace_uni.rb
].freeze

NxTest.test('DocKey: vsetci producenti model_guid beru hodnotu z DocKey') do
  NX_DK_PRODUCERS.each do |rel|
    src = File.read(File.join(NxTest::ROOT, rel), encoding: 'UTF-8')
    NxTest.assert(src.include?('DocKey.key('),
                  "#{rel} musi brat identitu dokumentu z DocKey")
    code = src.lines.map { |l| l.sub(/#.*$/, '') }.join
    NxTest.refute(code =~ /\bmodel\.guid\b|\bm\.guid\b/,
                  "#{rel} uz nesmie citat model.guid priamo (meni sa pri kazdom ulozeni)")
  end
end

NxTest.test('DocKey: prisny guard odmieta aj PRAZDNY kluc servera (fail-closed)') do
  # Codex audit R-02b BLOCKER 1: '' == '' by pustilo zapis okna bez identity
  # do dokumentu, ktoremu sa identita nepodarila precitat.
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'),
                  encoding: 'UTF-8')
  body = src[/def foreign_document\?\(.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'foreign_document? sa nasiel')
  NxTest.assert(body.include?('!current.empty?'),
                'prazdny kluc SERVERA nesmie prejst (fail-closed aj na strane servera)')
end

NxTest.test('DocKey: loader aj headless harness nacitavaju doc_key pred pouzivatelmi') do
  main_src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  at_key = main_src.index("Sketchup.require 'noxun_engine/core/doc_key'")
  NxTest.assert(!at_key.nil?, 'main.rb nacitava core/doc_key')
  at_first_user = main_src.index("Sketchup.require 'noxun_engine/core/materials_replace_uni'")
  NxTest.assert(!at_first_user.nil? && at_key < at_first_user,
                'doc_key sa nacitava PRED prvym pouzivatelom (materials_replace_uni)')
end
