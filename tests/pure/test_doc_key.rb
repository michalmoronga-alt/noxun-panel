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
#
# ROTACIA JE UDALOSTNA (review #267 P1-1): povodna verzia stavila na „novy
# dokument = novy Ruby objekt", lenze Windows smie pri File > Open ten isty
# `Model` objekt RECYKLOVAT (auditovane pri GHOST vkladani, review #268 P2-2).
# Preto identitu rotuje `DocKey.invalidate` volany z `onNewModel`/`onOpenModel`
# — nikdy z `onActivateModel` a nikdy pri ulozeni.
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

# --- Udalostna rotacia (review #267 P1-1) ------------------------------------

NxTest.test('DocKey: onOpenModel nad TYM ISTYM objektom vyda NOVU identitu (Windows recyklacia)') do
  # JADRO nalezu P1-1: Windows drzi jeden dokument na proces a pri File > Open
  # smie vratit ten isty `Model` objekt. Bez udalostnej rotacie by novy dokument
  # zdedil token stareho — `nxSetModelGuid` by zmenu nezbadal, zachytena identita
  # v bufferi by sedela a `foreign_document?` by zapis PUSTIL do cudzej zakazky.
  DK.reset!
  m = DkFakeModel.new(path: 'C:/Zakazky/Stara.skp', guid: 'G-1')
  stary = DK.key(m)
  # File > Open nad recyklovanym objektom: meni sa dokument (cesta aj guid),
  # objekt ostava ten isty — presne to podá SketchUp observeru.
  m.path = 'C:/Zakazky/Otvorena_ina.skp'
  m.guid = 'G-2'
  DK.invalidate(m) # presne to, co robi PanelAppObserver#onOpenModel
  novy = DK.key(m)
  NxTest.assert(!novy.empty?, 'novy token nie je prazdny')
  NxTest.refute(stary == novy, 'RECYKLOVANY objekt NESMIE zdedit identitu predosleho dokumentu')
end

ENG = Noxun::Engine

# Kazdy tickovy test zacina ZAVRETOU udalostou — inak by doslov predosleho
# testu tichcho preskocil cleanup a test by nemeral, co si mysli.
def nx_dk_tick_reset!
  ENG.end_document_event
  DK.reset!
end

NxTest.test('DocKey: JEDEN event (tick) = JEDEN token aj ked medzi observermi bezi key() [P2-N1]') do
  # Callbacky observerov NIE SU len oznamenie — ony rovno NOTIFIKUJU KLIENTOV,
  # takze medzi dva cleanupy sa REALNE vmesti `key`:
  #   EngineAppObserver -> on_document_replaced -> model_switched -> push (key!)
  #   PanelAppObserver  -> on_document_replaced -> on_model_switched -> push (key!)
  # Bez ohranicenia by Studio drzalo token A, panel token B a prvy klik
  # v Studiu by v SPRAVNOM dokumente skoncil falosnym „model sa prepol".
  nx_dk_tick_reset!
  m = DkFakeModel.new(path: 'C:/Zakazky/Stara.skp', guid: 'DOC-A')
  stary = DK.key(m)

  m.guid = 'DOC-B'
  m.path = 'C:/Zakazky/Nova.skp'

  ENG.on_document_replaced(m)   # 1. observer
  t_studio = DK.key(m)          # ... a jeho notifikacia klientov
  ENG.on_document_replaced(m)   # 2. observer TOHO ISTEHO ticku
  t_panel = DK.key(m)

  NxTest.refute(t_studio == stary, 'novy dokument dostal NOVU identitu')
  NxTest.assert_equal(t_studio, t_panel,
                      'oba observery JEDNEHO ticku musia klientom poslat TU ISTU identitu')
end

NxTest.test('DocKey: DVA ticky = DVE rotacie (ohranicenie nesmie zablokovat dalsi event)') do
  nx_dk_tick_reset!
  m = DkFakeModel.new(path: 'C:/A.skp', guid: 'DOC-A')
  t_a = DK.key(m)

  ENG.on_document_replaced(m)        # prvy File > Open
  t_b = DK.key(m)
  ENG.end_document_event             # koniec ticku (v SketchUpe nulovy timer)

  ENG.on_document_replaced(m)        # druhy File > Open
  t_c = DK.key(m)

  NxTest.assert_equal(3, [t_a, t_b, t_c].uniq.length, 'kazdy tick ma vlastnu identitu')
end

NxTest.test('DocKey: KOPIA .skp s TYM ISTYM guidom rotuje tiez [review v2 P2-1]') do
  # DIERA, ktoru mala medziverzia s „epochou z Model#guid": guid je OBSAH .skp
  # SUBORU, takze kopia zakazky (alebo re-open toho isteho suboru) nesie TEN
  # ISTY guid, kym sa neulozi. Nad recyklovanym objektom by sa znacka zhodovala,
  # rotacia by sa vynechala a novy dokument by zdedil identitu stareho — teda
  # CELY povodny nalez P1 spat. Tick ziadnu hodnotu z modelu necita.
  nx_dk_tick_reset!
  m = DkFakeModel.new(path: 'C:/Zakazky/Klinika.skp', guid: 'ROVNAKY-GUID')
  t_original = DK.key(m)

  # File > Open KOPIE nad recyklovanym objektom: iny subor, ZHODNY guid.
  m.path = 'C:/Zakazky/Klinika - kopia.skp'
  ENG.on_document_replaced(m)
  t_kopia = DK.key(m)

  NxTest.refute(t_original == t_kopia,
                'kopia .skp so zhodnym guidom NESMIE zdedit identitu originalu')
  NxTest.assert(DK.foreign?(t_original, m),
                'stary token uz do kopie zapisat NESMIE (jadro nalezu P2-1)')
end

NxTest.test('DocKey: zaseknuta udalost sa po poistke sama otvori (nikdy nezablokuje rotaciu)') do
  # Keby timer nikdy nedosiel, otvorena udalost by uz NIKDY nepustila rotaciu
  # a to je presne navrat P1. Poistka `DOC_EVENT_MAX_S` to odblokuje.
  nx_dk_tick_reset!
  m = DkFakeModel.new(path: 'C:/A.skp', guid: 'G')
  ENG.on_document_replaced(m)
  t1 = DK.key(m)
  # simulacia „timer nedosiel": udalost ostava otvorena, ale posunieme jej cas
  ENG.instance_variable_set(:@doc_event_at,
                            ENG.send(:monotonic_now) - (ENG::DOC_EVENT_MAX_S + 1.0))
  ENG.on_document_replaced(m)
  NxTest.refute(t1 == DK.key(m), 'po vyprsani poistky sa rotuje znova')
  ENG.end_document_event
end

NxTest.test('DocKey: invalidate na nil je bezpecny no-op') do
  DK.reset!
  NxTest.refute(DK.invalidate(nil), 'nil nema co invalidovat')
end

NxTest.test('DocKey: ulozenie NEROTUJE — rotuje VYHRADNE udalost') do
  # Poistka proti regresii opacnym smerom: keby niekto zavolal invalidate aj
  # z onActivateModel alebo z ulozenia, vratili by sme sa presne k chybe,
  # ktoru cela davka R-02b odstranuje.
  DK.reset!
  m = DkFakeModel.new(path: 'C:/Zakazky/Klinika.skp', guid: 'G-1')
  t1 = DK.key(m)
  m.guid = 'G-2' # Ctrl+S
  m.path = 'C:/Zakazky/Klinika v2.skp' # Save As
  NxTest.assert_equal(t1, DK.key(m), 'bez udalosti sa identita nemeni')
end

NxTest.test('DocKey: onActivateModel NEUPRATUJE (zdrojovy kontrakt observerov)') do
  # Upratovanie sa smie diat LEN v New/Open vetvach. Kontrakt sa overuje na
  # zdrojaku, lebo observer callbacky bez SketchUpu spustit nevieme.
  %w[noxun_engine/ui/panel/selection.rb noxun_engine/core/scale_observer.rb].each do |rel|
    src = File.read(File.join(NxTest::ROOT, rel), encoding: 'UTF-8')
    act = src[/def onActivateModel.*?\n        end\n/m].to_s
    NxTest.refute(act.empty?, "#{rel}: onActivateModel sa nasiel")
    NxTest.refute(act.include?('on_document_replaced'),
                  "#{rel}: onActivateModel NESMIE upratovat (macOS prepnutie medzi oknami)")
    %w[onNewModel onOpenModel].each do |cb|
      body = src[/def #{cb}\(model\).*?\n        end\n/m].to_s
      NxTest.assert(body.include?('Engine.on_document_replaced(model)'),
                    "#{rel}: #{cb} musi ohlasit vymenu dokumentu")
    end
  end
end

NxTest.test('DocKey: vymena dokumentu je JEDNA udalost s JEDNYM zoznamom cleanupov [P2-GLM]') do
  # Kazda pamat viazana na `object_id` + `equal?` musi mat svoj riadok na
  # JEDNOM mieste — inak sa na dalsiu (ako sa stalo mostu nazvu zakazky)
  # jednoducho zabudne.
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'doc_key.rb'), encoding: 'UTF-8')
  body = src[/def document_cleanups\(model\).*?\n      end\n/m].to_s
  NxTest.refute(body.empty?, 'zoznam cleanupov existuje')
  NxTest.assert(body.include?('DocKey.invalidate'), 'rotuje identitu dokumentu')
  NxTest.assert(body.include?('ProductionCore.forget_session_key'),
                'zahadzuje most nazvu zakazky (inak novy Untitled zdedi cudzi nazov)')
  NxTest.assert(body.scan(/rescue StandardError/).length >= 2,
                'kazdy cleanup je osetreny zvlast — zlyhanie jedneho nesmie zastavit ostatne')
end

NxTest.test('DocKey: upratovanie bezi PRED notifikaciou klientov (OBE vetvy, OBA observery)') do
  # Keby sa upratovalo az po `Panel.on_model_switched` / `model_switched`,
  # stihol by odist push so STARYM tokenom a klient by prepnutie nezbadal.
  # POZOR na holy substring `on_document_replaced` (review v2, P3-2): matchol by
  # aj `GhostTool.on_document_replaced`, ktory v paneli stoji hned vedla — presun
  # NASHO volania ZA push by testom presiel. Hlada sa preto PRESNY tvar.
  ENG_CALL = 'Engine.on_document_replaced(model)'
  { 'noxun_engine/ui/panel/selection.rb' => 'Panel.on_model_switched',
    'noxun_engine/core/scale_observer.rb' => 'model_switched(model)' }.each do |rel, push|
    src = File.read(File.join(NxTest::ROOT, rel), encoding: 'UTF-8')
    %w[onNewModel onOpenModel].each do |cb|
      body = src[/def #{cb}\(model\).*?\n        end\n/m].to_s
      NxTest.refute(body.empty?, "#{rel}: #{cb} sa nasiel")
      at_cleanup = body.index(ENG_CALL)
      at_push = body.index(push)
      NxTest.assert(at_cleanup && at_push, "#{rel}: #{cb} ma cleanup aj notifikaciu")
      NxTest.assert(at_cleanup < at_push,
                    "#{rel}: #{cb} — cleanup MUSI predchadzat notifikacii klientov")
    end
  end
end

NxTest.test('DocKey: ZLOZENY scenar — edit + Ctrl+S + echo, rozpisana praca PREZIJE [P3-GLM-1]') do
  # Obe polovice povodnej chyby naraz (dosial pripnute len zvlast):
  # klient zachyti identitu pri NAPLANOVANI editu -> pouzivatel da Ctrl+S
  # (SketchUp meni guid) -> debounce dobehne a zapise. Pred R-02b sa tento
  # zapis TICHO ZAHODIL ako „patri inemu dokumentu".
  nx_dk_tick_reset!
  m = DkFakeModel.new(path: 'C:/Zakazky/Klinika.skp', guid: 'G-PRED')

  zachytena = DK.key(m)                       # identita v okamihu naplanovania editu
  payload = { 'model_guid' => zachytena, 'width' => 650.0 }

  m.guid = 'G-PO'                             # Ctrl+S — SketchUp prepisal guid
  NxTest.assert_equal(zachytena, DK.key(m), 'ulozenie identitu nezmenilo')
  NxTest.refute(DK.foreign?(payload['model_guid'], m),
                'debounced edit sa po Ctrl+S MUSI zapisat (jadro celej davky)')

  # A protivaha v tom istom scenari: keby medzitym prisla VYMENA dokumentu,
  # ten isty payload uz prejst NESMIE.
  m.guid = 'G-INY-DOKUMENT'
  Noxun::Engine.end_document_event
  Noxun::Engine.on_document_replaced(m)
  NxTest.assert(DK.foreign?(payload['model_guid'], m),
                'po vymene dokumentu ten isty edit uz zapisat NESMIE')
end

# --- Fail-closed porovnavac (review #267 P3-2) -------------------------------

NxTest.test('DocKey.foreign?: PRAZDNY kluc SERVERA zastavi zapis vzdy') do
  DK.reset!
  NxTest.assert(DK.foreign?('', nil), 'bez modelu sa nezapisuje')
  NxTest.assert(DK.foreign?('nxdoc-cokolvek', nil), 'bez modelu nepomoze ani platny token klienta')
  NxTest.assert(DK.foreign?('', nil, tolerate_blank_client: true),
                'tolerancia klienta NESMIE zmiernit prazdny kluc servera')
end

NxTest.test('DocKey.foreign?: prisny vs tolerantny rezim sa lisi LEN v prazdnom kliente') do
  DK.reset!
  m = DkFakeModel.new(path: 'C:/Zakazky/A.skp')
  mine = DK.key(m)
  NxTest.refute(DK.foreign?(mine, m), 'zhodna identita prejde')
  NxTest.assert(DK.foreign?('nxdoc-cudzi', m), 'cudzia identita neprejde ani tolerantne')
  NxTest.assert(DK.foreign?('nxdoc-cudzi', m, tolerate_blank_client: true),
                'tolerancia sa NETYKA nezhodnej identity')
  NxTest.assert(DK.foreign?('', m), 'PRISNY rezim: okno bez NX.init nezapisuje')
  NxTest.refute(DK.foreign?('', m, tolerate_blank_client: true),
                'TOLERANTNY rezim: starsi cachovany DOM bez identity prejde (kryje ho generacny zamok)')
  NxTest.refute(DK.foreign?(nil, m, tolerate_blank_client: true), 'nil == prazdny klient')
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

# Pocet CITANI `.guid` v zdrojaku. Vynechavaju sa VYHRADNE riadky, ktore su
# CELE komentarom — vsetko ostatne sa skenuje vratane retazcov a interpolacie.
#
# POZOR na povodnu verziu (review #267 P2-1): strihala komentare cez
# `l.sub(/#.*$/, '')`, cim zmazala aj `"#{model.guid}"` — interpolacia zacina
# znakom `#`, takze cely riadok zmizol a mutacia s interpolovanym `model.guid`
# testom PRESLA. Radsej par falosnych poplachov z komentarov ZA kodom (tie sa
# preformuluju) nez diera, ktorou prejde skutocne citanie guidu.
def nx_dk_guid_hits(src)
  src.lines.reject { |l| l =~ /\A\s*#/ }.join.scan(/\.guid\b/).size
end

NxTest.test('DocKey: vsetci producenti model_guid beru hodnotu z DocKey') do
  NX_DK_PRODUCERS.each do |rel|
    src = File.read(File.join(NxTest::ROOT, rel), encoding: 'UTF-8')
    NxTest.assert(src.include?('DocKey.key('),
                  "#{rel} musi brat identitu dokumentu z DocKey")
    NxTest.assert(nx_dk_guid_hits(src).zero?,
                  "#{rel} uz nesmie citat model.guid priamo (meni sa pri kazdom ulozeni)")
  end
end

NxTest.test('DocKey: sken chyta aj INTERPOLOVANY model.guid (mutacia review #267 P2-1)') do
  NxTest.assert(nx_dk_guid_hits("x = model.guid\n").positive?,
                'holy `model.guid` sa musi najst')
  NxTest.assert(nx_dk_guid_hits('  log("dokument #{model.guid} sa prepol")' + "\n").positive?,
                'INTERPOLOVANY `model.guid` v retazci sa musi najst (povodna diera)')
  NxTest.assert(nx_dk_guid_hits('  key = "#{m.guid}-#{n}"' + "\n").positive?,
                'interpolacia s viacerymi vyrazmi na riadku')
  NxTest.assert(nx_dk_guid_hits("  # historicky sme tu citali model.guid\n").zero?,
                'riadok, ktory je CELY komentarom, sa nepocita')
  NxTest.assert(nx_dk_guid_hits("      # `model.guid` sa meni pri ulozeni\n").zero?,
                'odsadeny cely komentar sa nepocita')
end

# Zoznam vyssie stráži, že SÚČASNÍ producenti berú hodnotu z DocKey. Sám o sebe
# ale nechytí NOVÉ miesto, ktoré si `model.guid` privedie znova (polovičná
# migrácia je horšia než žiadna — časť guardov by Ctrl+S rozhodila a časť nie).
# Preto ešte plošný sken CELÉHO pluginu s VYMENOVANÝMI vedomými výnimkami:
# nový výskyt `guid` v `noxun_engine/` musí test buď zhodiť, alebo si autor
# musí vedome dopísať riadok sem (a tým rozhodnutie priznať).
NX_DK_GUID_ALLOWED = {
  # Cache stabilnych transformacii — guid je tu DETEKTOR zmeny dokumentu
  # v ceste (`forget_detached_models`), ktora pri ULOZENI vobec nebezi;
  # klucom cache je `object_id`, nie guid. Vedome (R-04, review #261 P1).
  'noxun_engine/core/scale_observer.rb' => 1,
  # `same_model?` porovnava DVE SUCASNE drzane referencie v tom istom
  # okamihu (`equal?` najprv; guid je len ZALOHA pre novy Ruby obal toho
  # isteho dokumentu a od kola 3 review #267 plati LEN spolu so ZHODNOU
  # cestou — samotny guid zdielaju dve sucasne otvorene KOPIE .skp, lebo je
  # to obsah suboru). Ulozenie medzi dvoma citaniami sa tam stat nemoze
  # a nejde o zapisovu cestu: overlay lifecycle, nie identita zapisu.
  'noxun_engine/core/edge_check.rb' => 2,
  'noxun_engine/core/grain_check.rb' => 2,
  # KOV-A2b: `DirectionCheck.same_model?` je BAJT-ZHODNY s vetvou vyssie
  # (overlay lifecycle, nie zapisova cesta) — plati preto to iste zdovodnenie.
  'noxun_engine/core/direction_check.rb' => 2,
  'noxun_engine/core/hover_edge.rb' => 2
}.freeze

NxTest.test('DocKey: v celom plugine uz nie je NEPRIZNANY `model.guid`') do
  root = File.join(NxTest::ROOT, 'noxun_engine')
  found = {}
  Dir.glob(File.join(root, '**', '*.rb')).sort.each do |abs|
    rel = abs.sub("#{NxTest::ROOT}/", '').tr('\\', '/')
    n = nx_dk_guid_hits(File.read(abs, encoding: 'UTF-8'))
    found[rel] = n if n.positive?
  end
  found.each do |rel, n|
    allowed = NX_DK_GUID_ALLOWED[rel]
    NxTest.assert(allowed,
                  "#{rel} cita `.guid` (#{n}x) — identita dokumentu patri DocKey; " \
                  'ak je to vedoma vynimka, dopis ju do NX_DK_GUID_ALLOWED aj s dovodom')
    NxTest.assert(allowed == n,
                  "#{rel}: ocakavanych #{allowed} vedomych `.guid`, naslo sa #{n} — " \
                  'novy vyskyt treba posudit (Ctrl+S meni guid)')
  end
  NX_DK_GUID_ALLOWED.each_key do |rel|
    NxTest.assert(found.key?(rel),
                  "#{rel} uz `.guid` necita — vyhod ho z NX_DK_GUID_ALLOWED (zoznam nesmie klamat)")
  end
end

# --- `same_model?` v overlay guardoch (review #267 kolo 3, P3) ---------------
#
# Tieto tri moduly maju VLASTNY porovnavac (a vedomu vynimku v zozname vyssie),
# lebo neriesia identitu ZAPISU, ale lifecycle prekrytia: porovnavaju dve
# SUCASNE drzane referencie. Guid tam sam o sebe nestacil — je to obsah .skp
# suboru, takze dve sucasne otvorene KOPIE tej istej zakazky ho maju ZHODNY
# a dva rozne dokumenty by vysli ako jeden (prekrytie by sa neodpojilo).
NX_DK_OVERLAY_GUARDS = [
  Noxun::Engine::EdgeCheck,
  Noxun::Engine::GrainCheck,
  Noxun::Engine::HoverEdge
].freeze

NxTest.test('same_model?: ZHODNY guid + ROZNA cesta = RÔZNE dokumenty (dve otvorene kopie .skp)') do
  NX_DK_OVERLAY_GUARDS.each do |mod|
    original = DkFakeModel.new(path: 'C:/Zakazky/Klinika.skp', guid: 'ROVNAKY-GUID')
    kopia = DkFakeModel.new(path: 'C:/Zakazky/Klinika - kopia.skp', guid: 'ROVNAKY-GUID')
    NxTest.refute(mod.same_model?(original, kopia),
                  "#{mod}: kopia .skp so zhodnym guidom NIE JE ten isty dokument")
    NxTest.refute(mod.same_model?(kopia, original),
                  "#{mod}: a plati to symetricky")
  end
end

NxTest.test('same_model?: ZHODNY guid + ZHODNA cesta = ten isty dokument (novy Ruby obal)') do
  NX_DK_OVERLAY_GUARDS.each do |mod|
    stary = DkFakeModel.new(path: 'C:/Zakazky/Klinika.skp', guid: 'G-1')
    novy_obal = DkFakeModel.new(path: 'C:/Zakazky/Klinika.skp', guid: 'G-1')
    NxTest.assert(mod.same_model?(stary, novy_obal),
                  "#{mod}: novy obal TOHO ISTEHO dokumentu sa musi rozpoznat (macOS)")
    NxTest.assert(mod.same_model?(stary, stary), "#{mod}: `equal?` ma prednost")
    NxTest.refute(mod.same_model?(stary, nil), "#{mod}: nil nie je dokument")
  end
end

NxTest.test('same_model?: dva NEULOZENE dokumenty sa nezlucia cez prazdnu cestu') do
  # Obe cesty su '' — rozlisit ich musi guid; zhodna prazdna cesta nesmie
  # z porovnania spravit „to iste".
  NX_DK_OVERLAY_GUARDS.each do |mod|
    a = DkFakeModel.new(path: '', guid: 'G-A')
    b = DkFakeModel.new(path: '', guid: 'G-B')
    NxTest.refute(mod.same_model?(a, b), "#{mod}: dve Untitled zakazky nie su ten isty dokument")
    prazdny = DkFakeModel.new(path: '', guid: '')
    druhy_prazdny = DkFakeModel.new(path: '', guid: '')
    NxTest.refute(mod.same_model?(prazdny, druhy_prazdny),
                  "#{mod}: PRAZDNY guid nesmie nikdy znamenat zhodu (fail-closed)")
  end
end

NxTest.test('DocKey: fail-closed zije v JEDNOM porovnavaci, nie v jednej ceste') do
  # Codex audit R-02b BLOCKER 1: '' == '' by pustilo zapis okna bez identity
  # do dokumentu, ktoremu sa identita nepodarila precitat.
  # Review #267 P3-2: poistka musi byt v `DocKey.foreign?`, cez ktory idu VSETKY
  # guardy — nie v tele `foreign_document?`, ktore kryje len panelove zapisy.
  dk = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'core', 'doc_key.rb'), encoding: 'UTF-8')
  body = dk[/def foreign\?\(.*?\n        end\n/m].to_s
  NxTest.refute(body.empty?, 'DocKey.foreign? sa nasiel')
  NxTest.assert(body.include?('return true if current.empty?'),
                'prazdny kluc SERVERA nesmie prejst (fail-closed aj na strane servera)')
  NxTest.assert(body.index('return true if current.empty?') <
                body.index('return false if tolerate_blank_client'),
                'fail-closed servera sa vyhodnocuje PRED toleranciou klienta')

  sync = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'sync.rb'), encoding: 'UTF-8')
  fd = sync[/def foreign_document\?\(.*?\n        end\n/m].to_s
  NxTest.assert(fd.include?('DocKey.foreign?'), 'panelovy guard deleguje na zdielany porovnavac')
end

NxTest.test('DocKey: ZIADNY guard uz neporovnava identitu na vlastnu past') do
  # Plosna poistka proti navratu dvoch tried guardov: v celom plugine nesmie
  # ostat rucne porovnanie `model_guid` — take miesto by fail-closed obislo.
  offenders = []
  Dir.glob(File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')).sort.each do |abs|
    code = File.read(abs, encoding: 'UTF-8').lines.reject { |l| l =~ /\A\s*#/ }.join
    next unless code =~ /model_guid'\]\.to_s\s*[!=]=|guid\s*!=\s*(?:ProductionCore\.)?model_guid\(/

    offenders << abs.sub("#{NxTest::ROOT}/", '').tr('\\', '/')
  end
  NxTest.assert(offenders.empty?,
                "rucne porovnanie identity ostalo v: #{offenders.join(', ')} — " \
                'pouzi DocKey.foreign? (fail-closed pre vsetkych rovnako)')
end

NxTest.test('DocKey: loader aj headless harness nacitavaju doc_key pred pouzivatelmi') do
  main_src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
  at_key = main_src.index("Sketchup.require 'noxun_engine/core/doc_key'")
  NxTest.assert(!at_key.nil?, 'main.rb nacitava core/doc_key')
  at_first_user = main_src.index("Sketchup.require 'noxun_engine/core/materials_replace_uni'")
  NxTest.assert(!at_first_user.nil? && at_key < at_first_user,
                'doc_key sa nacitava PRED prvym pouzivatelom (materials_replace_uni)')
end
