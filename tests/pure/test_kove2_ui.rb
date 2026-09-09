# frozen_string_literal: true
# KOV-E2 (9.9.2026) — VÝKLOPY: UI. Karta čela, výber setu (vrátane tmavého),
# editor pravidla `lift_class` a editor setov pre nové tvary člena.
#
# Dávka NEMENÍ geometriu, VEPO, kusovník ani ceny — mení sa len to, čo panel
# ZOBRAZUJE a čo cez existujúce zápisové cesty POŠLE. Riziká sú preto tiché:
# veta, ktorú si panel zloží sám (a rozíde sa s Kontrolou), zápis pod iným
# kľúčom (a tmavý set sa nikdy neuplatní) a validácia, ktorú pozná len jedna
# strana (formulár prejde a server ho odmietne bez cesty von).
#
# ČO SA OVERUJE:
#   1) `Panel.front_lift_payload` — stavy karty: `ok` (text + technický detail),
#      `conflict` (RED veta = DOSLOVNE tá istá, akú vydá Kontrola), `stale`
#      (skrinka spred pravidiel výklopov — TÁ ISTÁ autorita `Bom.pre_lift_build?`),
#      `pending`; ORANGE je riadok NAVIAC, nie náhrada.
#   2) GOLDEN: skrinka BEZ výklopu má payload karty prázdny (karta sa nemení
#      ani o pixel) a zásuvkový kanál (`front_drawer`) ostáva nedotknutý.
#   3) TEXTY sú z ULOŽENÝCH dát — číslo, ktoré na položke nie je (LF, hmotnosť),
#      si server NEDOPOČÍTAVA; KH je TÝM ISTÝM vzorcom ako kontext pravidiel.
#   4) VÝBER SETU VÝKLOPU vrátane tmavého: ponuka je LEN triedne kompatibilná,
#      zápis ide existujúcou cestou pod OWNER TRIEDNYM kľúčom
#      `class:lift|<mode>|<system>@front:<id>/flap` a resolver ho po reopene číta.
#   5) VALIDÁCIA `lift_class` — nové kritériá E2 (záporný prah tyče, záporná
#      hodnota v tabuľke, spôsobilosť s obrátenou výškou) + parita s klientom
#      (spoločná fixtúra `rules_validation_parity.json`).
#   6) ČLEN SETU v tvare, aký posiela EDITOR: `code_by_param` + `quantity_from`;
#      dve stratégie naraz server odmietne vetou.
#   7) ZRKADLO KLIENTA: `rules.js` pozná presne tie isté kľúče pravidla,
#      `hw_sets.js` už NEMÁ read-only režim (E1a badge zanikol).
#
# MUTÁCIE, ktoré táto sada chytá (každá by prázdnou sadou prešla):
#   M1 karta si zloží vlastnú vetu konfliktu   -> (1) doslovná zhoda s Kontrolou
#   M2 `stale` sa pýta len na `config_schema`  -> (1) stará seed verzia pravidiel
#   M3 ORANGE nahradí riadok výklopu           -> (1) `warn` je NAVIAC
#   M4 payload vydá záznam aj pre sklop/dvierka -> (2) golden
#   M5 KH sa počíta z výšky vrátane sokla      -> (3) skrinka so soklom
#   M6 zápis setu ide pod generický kľúč `lift` -> (4) owner triedny kľúč
#   M7 ponuka setu pustí HL set na HK čelo     -> (4) filter triedy
#   M8 záporná hodnota / obrátená spôsobilosť prejde -> (5)
#   M9 `code_by_param` z editora server odmietne -> (6)
#  M10 editor setov ostane read-only            -> (7)
# Codex #334 kolo 1 (P2), doplnené mutácie:
#  M11 karta píše „automat" aj pri ručnom zásahu -> (3) štítok zdroja
#  M12 `stale` sa nepýta na ručnú zostavu       -> (1) úplná ručná zostava
#  M13 nulový prah druhej tyče prejde           -> (5) nekladný prah
#  M14 nedopísaný riadok sa uloží ticho         -> (5) brána nad surovým vstupom
#  M15 duplicitná trieda v tabuľke člena prejde -> (7) `hwsMemberProblems`
require_relative '../helper' unless defined?(NxTest)

require 'json'

# UI vrstva nie je headless v require zozname helpera (vzor KOV-C2c/D1a/D1b).
if NxTest.headless?
  require File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads')
end

module NxKovE2
  E   = Noxun::Engine
  HR  = E::HardwareRules
  HWS = E::HardwareSets

  OWNER      = 'front:F1/flap'
  CLASS_HK   = 'class:lift|classic|hk_top'
  CLASS_HL   = 'class:lift|classic|hl_top'
  RULES_JS   = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'rules.js')
  HWSETS_JS  = File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'hw_sets.js')

  module_function

  # Položka výklopu presne v tvare, aký zapíše `HardwareRules.lift_compute`.
  def lift_item(over = {}, params = {})
    { 'owner_part_key' => OWNER, 'generic_type' => 'lift', 'quantity' => 1,
      'rule_id' => HR::LIFT_RULE_ID,
      'params' => { 'use_type' => 'lift', 'lift_system' => 'hk_top',
                    'opening_mode' => 'classic', 'rod_count' => 1,
                    'rod_extension' => 0, 'lift_class' => '22K2300' }.merge(params) }
      .merge(over)
  end

  # Config skrinky s JEDNÝM výklopom, postavenej UŽ pod pravidlami výklopov.
  def cfg(over = {})
    { 'config_schema' => E::CabinetBuilder::LIFT_ACTIVATION_SCHEMA,
      'rules_seed_version' => HR::LIFT_SEED_VERSION,
      'width' => 600.0, 'height' => 400.0, 'floor_height' => 0.0, 'depth' => 560.0,
      'front_items' => [{ 'id' => 'F1', 'type' => 'lift', 'flap_dir' => 'up',
                          'lift_system' => 'hk_top' }],
      'hardware' => [lift_item], 'hardware_conflicts' => [], 'warnings' => [] }
      .merge(over)
  end

  def row(c = cfg, fid = 'F1')
    NxKovE2::E::Panel.lift_card_row(c, fid, nil)
  end

  def conflict(code, message)
    { 'owner_part_key' => OWNER, 'code' => code, 'message' => message }
  end

  # Seed sety výklopu (biely + tmavý) tak, ako ich má knižnica.
  def seed_set(sid)
    HWS::SEED_SETS.find { |s| s['set_id'] == sid }
  end

  def lift_sets
    %w[vyklop-hk-klasik vyklop-hk-klasik-tmavy vyklop-hk-tipon vyklop-hk-tipon-tmavy
       vyklop-hl-klasik vyklop-hl-klasik-tmavy].map { |sid| seed_set(sid) }.compact
  end

  def js(path)
    File.read(path, encoding: 'UTF-8')
  end
end

# ============================================================================
# 1 — STAVY KARTY VÝKLOPU
# ============================================================================

NxTest.test('KOV-E2 (1): vyriešený výklop = JEDEN riadok + technický detail') do
  c = NxKovE2
  r = c.row
  NxTest.assert_equal('ok', r['state'], 'položka existuje a nič nie je zle')
  NxTest.assert(r['text'].include?('AVENTOS HK top'), "riadok menuje systém: #{r['text']}")
  NxTest.assert(r['text'].include?('22K2300'), 'aj triedu mechanizmu')
  NxTest.assert(r['text'].include?('automat'),
                'a prizná, že položku riadi celé pravidlo (ručný zásah sa neuplatní)')
  NxTest.assert(r['detail'].is_a?(Array) && !r['detail'].empty?, 'detail nie je prázdny')
  NxTest.assert_equal(nil, r['warn'], 'bez varovania niet ORANGE riadku')
end

NxTest.test('KOV-E2 (1): RED dôvod je DOSLOVNE tá istá veta ako v Kontrole') do
  c = NxKovE2
  veta = 'Výklop „F1“: LF 9500 je nad tabuľkou HK top — rozdeľ čelo.'
  cfg = c.cfg('hardware_conflicts' => [c.conflict('lift_class_missing', veta)])
  r = c.row(cfg)
  NxTest.assert_equal('conflict', r['state'], 'karta je červená')
  NxTest.assert_equal(veta, r['message'],
                      'a hovorí PRESNE to, čo uložil builder — žiadna druhá verzia vety')
  # Kód MIMO registra brán karta ignoruje: nosič je zdieľaný a cudzí záznam
  # (napr. zásuvkový) sa do karty výklopu dostať nesmie.
  iny = c.cfg('hardware_conflicts' => [c.conflict('drawer_kit_missing', 'nič o výklope')])
  NxTest.assert_equal('ok', c.row(iny)['state'], 'cudzí kód konfliktu kartu nezčervená')
end

NxTest.test('KOV-E2 (1): každý výklopový kód brány kartu zčervená') do
  c = NxKovE2
  %w[lift_class_missing lift_dimension_unsupported lift_multirow_unsupported
     lift_combo_unsupported].each do |code|
    cfg = c.cfg('hardware_conflicts' => [c.conflict(code, "dôvod #{code}")])
    NxTest.assert_equal('conflict', c.row(cfg)['state'], code)
  end
end

NxTest.test('KOV-E2 (1): ORANGE je riadok NAVIAC, nie náhrada vyriešeného riadku') do
  c = NxKovE2
  veta = 'Výklop „F1“: LF 300 je pod spodnou hranicou tabuľky — použije sa najslabšia trieda.'
  cfg = c.cfg('warnings' => [{ 'code' => 'lift_light_front', 'severity' => 'warn',
                               'message' => veta, 'part_key' => c::OWNER, 'data' => {} }])
  r = c.row(cfg)
  NxTest.assert_equal('ok', r['state'], 'položka sa aj tak objedná')
  NxTest.assert(r['text'].include?('22K2300'), 'riadok výklopu ostáva')
  NxTest.assert_equal(veta, r['warn'], 'a jantárová veta stojí NAVIAC')
end

NxTest.test('KOV-E2 (1): ORANGE patrí LEN tomuto vlastníkovi a LEN výklopovým kódom') do
  c = NxKovE2
  cudzi = c.cfg('warnings' => [{ 'code' => 'lift_light_front', 'message' => 'iné čelo',
                                 'part_key' => 'front:F2/flap', 'data' => {} }])
  NxTest.assert_equal(nil, c.row(cudzi)['warn'], 'varovanie iného čela sem nepatrí')
  # `hardware_rule_overlap` je varovanie o PRAVIDLÁCH (vlastníka nenesie) —
  # v karte by nemalo kde pristáť.
  ov = c.cfg('warnings' => [{ 'code' => 'hardware_rule_overlap', 'message' => 'prekryv',
                              'part_key' => c::OWNER, 'data' => {} }])
  NxTest.assert_equal(nil, c.row(ov)['warn'], 'prekryv pravidiel nie je vlastnosť čela')
end

NxTest.test('KOV-E2 (1): STALE skrinka — TÁ ISTÁ autorita ako RED `flap_stale`') do
  c = NxKovE2
  # (a) stará schéma configu
  stara = c.cfg('hardware' => [], 'config_schema' => 10)
  r = c.row(stara)
  NxTest.assert_equal('stale', r['state'], 'skrinka spred E1b')
  NxTest.assert(r['message'].include?('Doplniť nové predvoľby'), 'a navádza na nápravu')
  NxTest.assert(r['message'].include?('prestav'), 'na OBE jej časti')
  # (b) stará seed verzia pravidiel — prestavba samotná RED nezhasne
  stary_seed = c.cfg('hardware' => [], 'rules_seed_version' => NxKovE2::HR::LIFT_SEED_VERSION - 1)
  NxTest.assert_equal('stale', c.row(stary_seed)['state'],
                      'stará proveniencia pravidiel stačí (M2)')
end

NxTest.test('KOV-E2 (1): ÚPLNA RUČNÁ ZOSTAVA stale ZHASÍNA — presne ako v Kontrole') do
  # Codex #334 kolo 1 P2: RED `flap_stale` nie je jedna podmienka, ale tri —
  # stará proveniencia, chýbajúce kovanie podľa smeru čela A VÝNIMKA pre úplnú
  # ručnú zostavu. Karta sa pýtala len prvej, takže čelo s ručne zloženým
  # mechanizmom malo v karte červenú vetu, kým Kontrola mlčala (M12).
  c = NxKovE2
  rucny = { 'source' => 'catalog', 'owner_part_key' => c::OWNER, 'code' => '347810',
            'quantity' => 1 }
  cfg = c.cfg('hardware' => [], 'config_schema' => 10, 'hardware_manual' => [rucny])
  NxTest.assert_equal('pending', c.row(cfg)['state'], 'karta o chýbajúcom mechanizme MLČÍ')
  NxTest.assert_equal(nil, NxKovE2::E::Bom.flap_stale_issue('CAB-1', 1, cfg),
                      'a Kontrola tiež — obe odpovede sú z tej istej metódy')
  # Ručný riadok, ktorý mechanizmom NIE JE (krytky), výnimku nedáva:
  # obe strany ostávajú červené.
  kryt = c.cfg('hardware' => [], 'config_schema' => 10,
               'hardware_manual' => [rucny.merge('code' => '347834')])
  NxTest.assert_equal('stale', c.row(kryt)['state'], 'krytky mechanizmus nenahradia')
  NxTest.assert(!NxKovE2::E::Bom.flap_stale_issue('CAB-1', 1, kryt).nil?,
                'a Kontrola hovorí to isté')
  # Predikát je ZDIEĽANÝ — karta si druhú podmienku neopisuje vlastnou rukou.
  NxTest.refute(NxKovE2::E::Bom.flap_stale_front?(cfg, 'F1'), 'ručná zostava = nie stale')
  NxTest.assert(NxKovE2::E::Bom.flap_stale_front?(kryt, 'F1'))
  NxTest.refute(NxKovE2::E::Bom.flap_stale_front?(kryt, ''), 'bez identity čela sa netvrdí nič')
end

NxTest.test('KOV-E2 (1): PENDING — čerstvá skrinka bez položky karta MLČÍ') do
  c = NxKovE2
  # Vypnuté výklopové pravidlo: skrinka je postavená pod aktuálnou verziou,
  # takže „stale" to nie je — a tvrdiť „chýba mechanizmus" by bola lož.
  NxTest.assert_equal('pending', c.row(c.cfg('hardware' => []))['state'])
end

# ============================================================================
# 2 — GOLDEN: skrinka BEZ výklopu
# ============================================================================

NxTest.test('KOV-E2 (2): skrinka bez výklopu má payload karty PRÁZDNY') do
  c = NxKovE2
  dvierka = c.cfg('front_items' => [{ 'id' => 'F1', 'type' => 'door' }], 'hardware' => [])
  NxTest.assert_equal({}, NxKovE2::E::Panel.front_lift_payload(dvierka), 'dvierka záznam nedostanú')
  sklop = c.cfg('front_items' => [{ 'id' => 'F1', 'type' => 'fall', 'flap_dir' => 'down' }],
                'hardware' => [])
  NxTest.assert_equal({}, NxKovE2::E::Panel.front_lift_payload(sklop),
                      'ani SKLOP — dostáva závesy, mechanizmus žiadny (M4)')
  NxTest.assert_equal({}, NxKovE2::E::Panel.front_lift_payload({}), 'prázdny config nespadne')
end

NxTest.test('KOV-E2 (2): výklop záznam DOSTANE a je kľúčovaný `front_id`') do
  c = NxKovE2
  out = NxKovE2::E::Panel.front_lift_payload(c.cfg)
  NxTest.assert_equal(['F1'], out.keys, 'jeden výklop = jeden záznam')
  NxTest.assert_equal('ok', out['F1']['state'])
end

# ============================================================================
# 3 — TEXTY IDÚ Z ULOŽENÝCH DÁT
# ============================================================================

NxTest.test('KOV-E2 (3): riadok HL top nesie mechanizmus AJ ramená') do
  c = NxKovE2
  t = NxKovE2::E::Panel.lift_row_text('lift_system' => 'hl_top', 'lift_class' => '22L2500',
                             'arm_class' => '22L3800')
  NxTest.assert(t.include?('AVENTOS HL top'), t)
  NxTest.assert(t.include?('22L2500') && t.include?('22L3800'), 'obe triedy naraz')
end

NxTest.test('KOV-E2 (3): chýbajúci údaj sa VYNECHÁ, nikdy nehádže') do
  c = NxKovE2
  t = NxKovE2::E::Panel.lift_row_text({ 'lift_system' => 'hk_top' }, c.lift_item)
  NxTest.assert(t.include?('AVENTOS HK top'), t)
  NxTest.refute(t.include?('nil'), 'žiadne „nil“ v texte')
  NxTest.assert_equal('AVENTOS HK top · automat', t, 'len to, čo je uložené')
end

NxTest.test('KOV-E2 (3): štítok „automat“ patrí LEN chránenému seed pravidlu') do
  # Codex #334 kolo 1 P2: „automat" neznamená „vybral to plugin", ale „ručný
  # zásah sa na tejto položke NEUPLATNÍ" — a to platí výhradne pre chránené
  # seed pravidlo. Na položke z VLASTNÉHO výklopového pravidla je override
  # účinný a `apply_overrides` ju označí `source: 'manual'`; karta by o ručne
  # prepísanom počte tvrdila „automat" (M11).
  c = NxKovE2
  vlastne = c.lift_item('rule_id' => 'moje-vyklopy', 'source' => 'manual')
  t = NxKovE2::E::Panel.lift_row_text(vlastne['params'], vlastne)
  NxTest.assert(t.include?('ručne'), "ručne prepísaná položka to prizná: #{t}")
  NxTest.refute(t.include?('automat'), 'a NEtvrdí opak')
  # Vlastné pravidlo BEZ overridu štítok nedostane — mlčanie je presnejšie
  # než ktorékoľvek z dvoch slov.
  bez = c.lift_item('rule_id' => 'moje-vyklopy')
  t2 = NxKovE2::E::Panel.lift_row_text(bez['params'], bez)
  NxTest.refute(t2.include?('automat'), t2)
  NxTest.refute(t2.include?('ručne'), t2)
  # A seedová položka s ručným zásahom ostáva „automat" — override je na nej
  # zámerne neúčinný (ORANGE `lift_override_ignored`).
  seed = c.lift_item('source' => 'manual')
  NxTest.assert(NxKovE2::E::Panel.lift_row_text(seed['params'], seed).include?('automat'),
                'chránené pravidlo si štítok drží')
  # Karta ho vypĺňa z POLOŽKY, nie z parametrov (bez položky žiadny štítok).
  NxTest.refute(NxKovE2::E::Panel.lift_row_text('lift_system' => 'hk_top').include?('automat'))
end

NxTest.test('KOV-E2 (3): KH je TEN ISTÝ vzorec ako kontext pravidiel (bez sokla)') do
  c = NxKovE2
  so_soklom = c.cfg('height' => 500.0, 'floor_height' => 100.0)
  lines = NxKovE2::E::Panel.lift_detail_lines(so_soklom, c.lift_item['params'])
  dim = lines.find { |l| l.include?('Rozmery') }.to_s
  NxTest.assert(dim.include?('400'), "KH = 500 − 100 = 400 mm (M5): #{dim}")
  NxTest.refute(dim.include?('500'), 'výška vrátane sokla by vybrala inú triedu')
  NxTest.assert(dim.include?('600'), 'a šírka korpusu je KB')
end

NxTest.test('KOV-E2 (3): riadok stabilizačnej tyče hovorí to, čo je v nákupe') do
  c = NxKovE2
  jedna = NxKovE2::E::Panel.lift_rod_line('rod_count' => 1, 'rod_extension' => 0)
  NxTest.assert(jedna.include?('1×'), jedna)
  NxTest.refute(jedna.include?('predlžovací'), 'jedna tyč predĺženie nemá')
  dve = NxKovE2::E::Panel.lift_rod_line('rod_count' => 2, 'rod_extension' => 1)
  NxTest.assert(dve.include?('2×') && dve.include?('predlžovací diel'), dve)
  NxTest.assert_equal(nil, NxKovE2::E::Panel.lift_rod_line({}), 'bez údaja žiadny riadok')
  NxTest.assert_equal(nil, NxKovE2::E::Panel.lift_rod_line('rod_count' => 0),
                      'nula tyčí = člen sa nevydá, riadok o ňom neklame')
end

NxTest.test('KOV-E2 (3): detail nesie otváranie (rozhoduje o SETE)') do
  c = NxKovE2
  lines = NxKovE2::E::Panel.lift_detail_lines(c.cfg, c.lift_item({}, 'opening_mode' => 'tipon')['params'])
  NxTest.assert(lines.any? { |l| l.start_with?('Otváranie:') }, lines.inspect)
end

# ============================================================================
# 4 — VÝBER SETU VÝKLOPU (vrátane TMAVÉHO)
# ============================================================================

NxTest.test('KOV-E2 (4): ponuka setu výklopu je LEN triedne kompatibilná') do
  c = NxKovE2
  opts = NxKovE2::HWS.class_set_options(c::CLASS_HK, c.lift_sets, {}, [])
  ids = opts.map { |o| o['set_id'] }
  NxTest.assert(ids.include?('vyklop-hk-klasik'), 'biely HK klasik je v ponuke')
  NxTest.assert(ids.include?('vyklop-hk-klasik-tmavy'), 'aj TMAVÝ (to je celá pointa)')
  NxTest.refute(ids.include?('vyklop-hk-tipon'), 'Tip-On set na klasické čelo NIE (iná trieda)')
  NxTest.refute(ids.include?('vyklop-hl-klasik'), 'ani HL set na HK čelo (M7)')
  tmavy = opts.find { |o| o['set_id'] == 'vyklop-hk-klasik-tmavy' }
  NxTest.assert(tmavy['label'].include?('tmavá'),
                "tmavý set je v ponuke POZNAŤ: #{tmavy['label']}")
end

NxTest.test('KOV-E2 (4): HL trieda ponúka LEN HL sety') do
  c = NxKovE2
  ids = NxKovE2::HWS.class_set_options(c::CLASS_HL, c.lift_sets, {}, []).map { |o| o['set_id'] }
  NxTest.assert_equal(%w[vyklop-hl-klasik vyklop-hl-klasik-tmavy].sort, ids.sort)
end

NxTest.test('KOV-E2 (4): zápis tmavého setu ide pod OWNER TRIEDNY kľúč') do
  c = NxKovE2
  status, map = NxKovE2::HWS.apply_cabinet_override(c.cfg, 'lift', c::OWNER,
                                           'vyklop-hk-klasik-tmavy',
                                           known_sets: c.lift_sets)
  NxTest.assert_equal(:ok, status, "zápis prejde (#{map})")
  NxTest.assert_equal({ "#{c::CLASS_HK}@#{c::OWNER}" => 'vyklop-hk-klasik-tmavy' }, map,
                      'kľúč nesie triedu AJ vlastníka — generický `lift` by sa neuplatnil (M6)')
end

NxTest.test('KOV-E2 (4): výber PREŽIJE reopen — resolver ho číta') do
  c = NxKovE2
  _, map = NxKovE2::HWS.apply_cabinet_override(c.cfg, 'lift', c::OWNER, 'vyklop-hk-klasik-tmavy',
                                      known_sets: c.lift_sets)
  # Reopen = ten istý config zo .skp; resolver dostane mapovanie projektu
  # (biely default) a override skrinky (tmavý per čelo). Overridy sú kľúčované
  # `owner_id` (skrinkou) — presne tak, ako ich zbiera expanzia.
  mapping = { c::CLASS_HK => 'vyklop-hk-klasik' }
  item = c.lift_item('owner_id' => 'CAB-001')
  sid, = NxKovE2::HWS.resolve_set_id('lift', item, { 'CAB-001' => map }, mapping)
  NxTest.assert_equal('vyklop-hk-klasik-tmavy', sid, 'tmavý set platí aj po reopene')
  # A bez override sa vráti projektová predvoľba (voľba „predvolené").
  _, prazdna = NxKovE2::HWS.apply_cabinet_override(c.cfg, 'lift', c::OWNER, '',
                                                   known_sets: c.lift_sets)
  sid2, = NxKovE2::HWS.resolve_set_id('lift', item, { 'CAB-001' => prazdna }, mapping)
  NxTest.assert_equal('vyklop-hk-klasik', sid2, 'zrušenie výberu vráti predvoľbu projektu')
end

NxTest.test('KOV-E2 (4): ponuka karty pre KONKRÉTNE čelo (payload `compat`)') do
  c = NxKovE2
  hw = [c.lift_item]
  out = NxKovE2::E::Panel.class_compat_payload('lift', hw, {}, { c::CLASS_HK => 'vyklop-hk-klasik' },
                                      c.lift_sets, {}, [])
  NxTest.assert(out.is_a?(Hash), 'klasifikovaná položka ponuku dostane')
  scope = out['owners'][c::OWNER]
  NxTest.assert(!scope.nil?, "vlastník `#{c::OWNER}` má vlastný rozsah")
  NxTest.assert_equal(c::CLASS_HK, scope['class_key'], 'a je to trieda výklopu')
  NxTest.assert(scope['class_label'].include?('HK top'),
                "popisok povie, o akú triedu ide: #{scope['class_label']}")
  NxTest.assert(scope['none_label'].include?('projektu'), 'prvá voľba povie, čo platí bez výberu')
  ids = scope['options'].map { |o| o['set_id'] }
  NxTest.assert(ids.include?('vyklop-hk-klasik-tmavy'), 'tmavý je v ponuke karty')
end

# ============================================================================
# 5 — VALIDÁCIA PRAVIDLA `lift_class` (nové kritériá E2)
# ============================================================================

module NxKovE2
  module_function

  def lift_rule(over = {})
    { 'rule_id' => HR::LIFT_RULE_ID, 'enabled' => true, 'output' => 'lift',
      'kind' => HR::LIFT_KIND, 'applies_to' => { 'role' => 'flap', 'flap_dir' => 'up' },
      'handle_allowance_kg' => 0.5, 'rod_double_from_kb_mm' => 1100.0,
      'classes' => [{ 'code' => '22K2300', 'min' => 420.0, 'max' => 1610.0 }],
      'mechanisms' => [{ 'code' => '22L2500', 'max' => 580.0 }],
      'arms' => [{ 'code' => '22L3200', 'kh_min' => 300.0, 'kh_max' => 340.0,
                   'kg_min' => 1.5, 'kg_max' => 9.0 }],
      'eligibility' => { 'hk_top' => { 'kh_min' => 205.0, 'kh_max' => 600.0,
                                       'kb_max' => 1800.0 } } }.merge(over)
  end

  def rule_message(rule)
    HR.rules_problems(NxKovE2::HR.normalize_rules([rule])).map { |p| p['message'] }.first.to_s
  end
end

NxTest.test('KOV-E2 (5): seedový tvar výklopového pravidla prejde') do
  c = NxKovE2
  NxTest.assert_equal('', c.rule_message(c.lift_rule), 'nič sa nevymýšľa')
end

NxTest.test('KOV-E2 (5): NEKLADNÝ prah druhej tyče sa NEULOŽÍ (ani nula)') do
  # Codex #334 kolo 1 P2: `lift_rod_count` žiada KLADNÉ číslo — nulu aj zápornú
  # hodnotu zahodí („druhá tyč nikdy"), kým súhrn editora by písal „tyč od 0 mm"
  # („druhá tyč vždy"). Dve opačné tvrdenia nad jednou hodnotou.
  c = NxKovE2
  [-1100.0, -5.0, 0.0].each do |bad|
    msg = c.rule_message(c.lift_rule('rod_double_from_kb_mm' => bad))
    NxTest.assert(msg.include?('druhú stabilizačnú tyč'), "#{bad}: #{msg}")
    NxTest.assert(msg.include?('musí byť kladná'), 'a povie prečo')
    NxTest.assert(msg.include?('nepridáva nikdy'), 'aj to, ako sa myslí „žiadne zdvojenie“')
  end
  NxTest.assert_equal('', c.rule_message(c.lift_rule('rod_double_from_kb_mm' => 1100.0)),
                      'kladný prah je v poriadku')
  # Kľúč, ktorý vo formulári ostal prázdny, sa nezapíše — a to je legitímne.
  bez = c.lift_rule
  bez.delete('rod_double_from_kb_mm')
  NxTest.assert_equal('', c.rule_message(bez), 'prázdne pole = „druhá tyč nikdy“, bez hlášky')
  # A `lift_rod_count` sa s nulou správa TAK, ako veta tvrdí (jedna tyč).
  NxTest.assert_equal(1, NxKovE2::HR.lift_rod_count({ 'rod_double_from_kb_mm' => 0.0 }, 1800.0),
                      'nula prah NIE JE — inak by veta klamala')
end

NxTest.test('KOV-E2 (5): NEDOPÍSANÝ riadok tabuľky sa NEULOŽÍ TICHO') do
  # Codex #334 kolo 1 P2: normalizácia neúplný riadok ZAHODÍ (a pri čítaní
  # legacy snapshotu je to správne), takže druhá brána o ňom nemá ako povedať —
  # používateľovi by riadok po prestavbe zmizol. Brána nad SUROVÝM vstupom
  # (`lift_input_problems`) je jediné miesto, kde ho ešte vidno.
  c = NxKovE2
  msgs = lambda { |rule| NxKovE2::HR.lift_input_problems([rule]).map { |p| p['message'] } }
  # (a) kód bez hornej hranice VEDĽA platného riadku
  neuplny = c.lift_rule('classes' => [{ 'code' => '22K2300', 'min' => 420.0, 'max' => 1610.0 },
                                      { 'code' => '22K2500', 'min' => 1610.0 }])
  m = msgs.call(neuplny).first.to_s
  NxTest.assert(m.include?('nedopísaný'), m)
  NxTest.assert(m.include?('22K2500'), 'veta menuje TEN riadok, ktorý treba dopísať')
  NxTest.assert(m.include?('tried HK top'), 'aj tabuľku, v ktorej je')
  NxTest.assert_equal([], NxKovE2::HR.rules_problems(NxKovE2::HR.normalize_rules([neuplny])),
                      'druhá brána ho naozaj NEVIDÍ — preto je prvá potrebná')
  # (b) hranica bez kódu — mechanizmy aj ramená
  NxTest.assert(msgs.call(c.lift_rule('mechanisms' => [{ 'code' => '22L2500', 'max' => 580.0 },
                                                       { 'code' => '', 'max' => 700.0 }])).any?)
  NxTest.assert(msgs.call(c.lift_rule('arms' => [{ 'code' => '22L3200', 'kh_min' => 300.0,
                                                   'kh_max' => 340.0, 'kg_min' => 1.5,
                                                   'kg_max' => 9.0 },
                                                 { 'code' => '22L3500', 'kh_min' => 340.0 }])).any?)
  # (c) ÚPLNE prázdny riadok je pohodlie editora — mlčky sa zahodí
  NxTest.assert_equal([], msgs.call(c.lift_rule('classes' => [
                        { 'code' => '22K2300', 'min' => 420.0, 'max' => 1610.0 },
                        { 'code' => '', 'min' => nil, 'max' => nil }
                      ])), 'pridaný a nevyplnený riadok uloženie neblokuje')
  # (d) seed a vypnuté pravidlo prejdú; iný `kind` sa brány netýka
  NxTest.assert_equal([], msgs.call(c.lift_rule), 'seedový tvar')
  NxTest.assert_equal([], msgs.call(c.lift_rule('enabled' => false,
                                                'classes' => [{ 'code' => 'X', 'min' => 1.0 }])),
                      'vypnuté pravidlo sa nekontroluje (zhodne s druhou bránou)')
  NxTest.assert_equal([], NxKovE2::HR.lift_input_problems([{ 'rule_id' => 'zavesy',
                                                             'kind' => 'bands', 'enabled' => true,
                                                             'bands' => [{ 'max' => nil }] }]),
                      'pásmové pravidlo brána výklopov nerieši')
  NxTest.assert_equal([], NxKovE2::HR.lift_input_problems(nil), 'nil vstup nespadne')
end

NxTest.test('KOV-E2 (5): brána nad surovým vstupom je v ZÁPISOVEJ ceste, PRED normalizáciou') do
  src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'rules_dialog.rb'),
                  encoding: 'UTF-8')
  body = src[/def handle_save\(payload\).*?\n        end\n/m].to_s
  NxTest.assert(body.include?('HardwareRules.lift_input_problems'), 'brána sa naozaj volá')
  NxTest.assert(body.index('lift_input_problems') < body.index('normalize_rules'),
                'a stojí PRED normalizáciou — po nej už neúplný riadok neexistuje')
  # CITACIE cesty ostávajú nedotknuté (vzor `rules_problems`): brána je LEN
  # v uložení — stavba ani seed ju nevolajú.
  root = File.join(NxTest::ROOT, 'noxun_engine')
  hits = Dir[File.join(root, '**', '*.rb')].sort.select do |f|
    code = File.read(f, encoding: 'UTF-8').lines.reject { |l| l.strip.start_with?('#') }.join
    code.include?('lift_input_problems')
  end.map { |f| f.sub("#{NxTest::ROOT}/", '').tr('\\', '/') }
  NxTest.assert_equal(['noxun_engine/core/hardware_rules.rb', 'noxun_engine/ui/rules_dialog.rb'],
                      hits.sort, 'definícia + JEDINÝ volajúci (zápisová cesta)')
end

NxTest.test('KOV-E2 (5): ZÁPORNÁ hodnota v tabuľke sa NEULOŽÍ') do
  c = NxKovE2
  [c.lift_rule('classes' => [{ 'code' => '22K2300', 'min' => -420.0, 'max' => 1610.0 }]),
   c.lift_rule('mechanisms' => [{ 'code' => '22L2500', 'max' => -580.0 }]),
   c.lift_rule('arms' => [{ 'code' => '22L3200', 'kh_min' => 300.0, 'kh_max' => 340.0,
                            'kg_min' => -1.5, 'kg_max' => 9.0 }])].each do |rule|
    msg = c.rule_message(rule)
    NxTest.assert(msg.include?('zápornú hodnotu'), "riadok so zápornou hodnotou: #{msg}")
  end
end

NxTest.test('KOV-E2 (5): SPÔSOBILOSŤ s obrátenou výškou sa NEULOŽÍ') do
  c = NxKovE2
  msg = c.rule_message(c.lift_rule('eligibility' => {
    'hl_top' => { 'kh_min' => 580.0, 'kh_max' => 300.0 }
  }))
  NxTest.assert(msg.include?('spôsobilosť HL top'), msg)
  NxTest.assert(msg.include?('od väčšiu než do'), 'taký systém by nebol použiteľný nikdy')
  # Rovnaký rozsah je v poriadku (jedna povolená výška).
  ok = c.lift_rule('eligibility' => { 'hl_top' => { 'kh_min' => 300.0, 'kh_max' => 300.0 } })
  NxTest.assert_equal('', c.rule_message(ok), 'kh_min == kh_max je legitímne')
end

NxTest.test('KOV-E2 (5): normalizácia ZÁPORNÚ spôsobilosť zahodí (brána ju nerieši)') do
  c = NxKovE2
  stored = NxKovE2::HR.normalize_rules([c.lift_rule('eligibility' => {
    'hk_top' => { 'kh_min' => -205.0, 'kh_max' => 600.0 }
  })]).first
  NxTest.assert_equal({ 'kh_max' => 600.0 }, stored['eligibility']['hk_top'],
                      'nekladná hodnota do configu nejde — deliaca čiara ako pri door guardoch')
end

NxTest.test('KOV-E2 (5): VYPNUTÉ pravidlo sa nekontroluje (cesta von existuje)') do
  c = NxKovE2
  rule = c.lift_rule('enabled' => false, 'rod_double_from_kb_mm' => -1.0,
                     'classes' => [], 'mechanisms' => [], 'arms' => [])
  NxTest.assert_equal('', c.rule_message(rule))
end

# ============================================================================
# 6 — ČLEN SETU V TVARE, AKÝ POSIELA EDITOR
# ============================================================================

NxTest.test('KOV-E2 (6): `code_by_param` + `quantity_from` z editora server PRIJME') do
  c = NxKovE2
  member = { 'per' => 'unit', 'qty' => 1, 'label' => 'mechanizmus HL top',
             'quantity_from' => 'rod_count',
             'code_by_param' => { 'param' => 'lift_class',
                                  'codes' => { '22L2200' => '507351',
                                               '22L2500' => '507352' } } }
  norm, errors = NxKovE2::HWS.validate_member(member)
  NxTest.assert_equal([], errors, "editor posiela platný tvar: #{errors.inspect}")
  NxTest.assert_equal('lift_class', norm['code_by_param']['param'])
  NxTest.assert_equal('rod_count', norm['quantity_from'], 'počet z parametra prežije')
end

NxTest.test('KOV-E2 (6): DVE stratégie naraz server odmietne VETOU') do
  c = NxKovE2
  _, errors = NxKovE2::HWS.validate_member({ 'per' => 'unit', 'qty' => 1, 'code' => '347810',
                                             'code_by_param' => { 'param' => 'lift_class',
                                                                  'codes' => { 'A' => '1' } } })
  NxTest.assert(errors.first.to_s.include?('práve jedno z'), errors.inspect)
end

NxTest.test('KOV-E2 (6): polovičná trieda sa NESCHOVÁ — server o nej povie') do
  c = NxKovE2
  _, errors = NxKovE2::HWS.validate_member({ 'per' => 'unit', 'qty' => 1,
                                             'code_by_param' => { 'param' => 'lift_class',
                                                                  'codes' => { '22L2200' => '' } } })
  NxTest.assert(errors.first.to_s.include?('nemá kód'), errors.inspect)
  # Prázdna tabuľka (nový člen bez jediného riadku) tiež.
  _, e2 = NxKovE2::HWS.validate_member({ 'per' => 'unit', 'qty' => 1,
                                         'code_by_param' => { 'param' => 'lift_class',
                                                              'codes' => {} } })
  NxTest.assert(e2.first.to_s.include?('ani jednu triedu'), e2.inspect)
  # A člen bez názvu parametra („iné" bez vypísaného textu).
  _, e3 = NxKovE2::HWS.validate_member({ 'per' => 'unit', 'qty' => 1,
                                         'code_by_param' => { 'param' => '',
                                                              'codes' => { 'A' => '1' } } })
  NxTest.assert(e3.first.to_s.include?('názov parametra'), e3.inspect)
end

NxTest.test('KOV-E2 (6): ZÁPIS zmeneného člena setu výklopu server PUSTÍ') do
  # E1a mala dočasnú bránu „členov tohto setu zatiaľ meniť nemožno" — editor
  # pre nové tvary vtedy neexistoval. Po E2 by bola JEDINOU prekážkou opravy
  # setu výklopu (kód triedy zmenený v Démose, nová trieda), takže zanikla.
  # Ochranou ostáva VALIDÁCIA OBSAHU, nie zákaz zápisu.
  hws = NxKovE2::HWS
  tax = NxKovE2::E::HardwareTaxonomy
  # Sada beži v spoločnom %APPDATA% (helper ho presmeruje do tempu), takže
  # súbory po INÝCH sadách musia ísť preč — inak sa zápis odmietne z dôvodu,
  # ktorý s výklopmi nemá nič spoločné (napr. „taxonómia je z novšej verzie").
  [hws.path, "#{hws.path}.bak", tax.path, "#{tax.path}.bak"].each do |f|
    File.delete(f) if File.exist?(f)
    Noxun::Engine::JsonFileStore.invalidate(f)
  end
  set = { 'set_id' => 'moj-vyklop', 'name' => 'Môj výklop', 'generic_type' => 'lift',
          'use_type' => 'lift', 'opening_mode' => 'classic', 'lift_system' => 'hk_top',
          'manufacturer' => 'Blum', 'series' => 'AVENTOS',
          'members' => [{ 'per' => 'unit', 'qty' => 1,
                          'code_by_param' => { 'param' => 'lift_class',
                                               'codes' => { '22K2300' => '347810' } } }] }
  status, info = hws.save_set!(set, revision: hws.revision)
  NxTest.assert_equal(:ok, status, "set výklopu sa uloží (#{info.inspect})")
  zmeneny = JSON.parse(JSON.generate(set))
  zmeneny['members'][0]['code_by_param']['codes']['22K2500'] = '347811'
  zmeneny['members'] << { 'per' => 'unit', 'qty' => 1, 'code' => '507365',
                          'quantity_from' => 'rod_count' }
  status, rec = hws.save_set!(zmeneny, revision: hws.revision)
  NxTest.assert_equal(:ok, status, 'a ZMENA jeho členov tiež — editor už tie tvary vie')
  NxTest.assert_equal(2, rec['members'].length, 'nový člen pribudol')
  NxTest.assert_equal({ '22K2300' => '347810', '22K2500' => '347811' },
                      rec['members'][0]['code_by_param']['codes'], 'nová trieda sa uložila')
  # Ale NEZMYSEL server odmietne ďalej — brána je obsah, nie zákaz.
  zly = JSON.parse(JSON.generate(zmeneny))
  zly['members'][0]['code'] = '999'
  status, = hws.save_set!(zly, revision: hws.revision)
  NxTest.assert_equal(:invalid, status, 'dve stratégie kódu naraz sa neuložia')
  [hws.path, "#{hws.path}.bak"].each { |f| File.delete(f) if File.exist?(f) }
  Noxun::Engine::JsonFileStore.invalidate(hws.path)
end

NxTest.test('KOV-E2 (6): seedové sety výklopu prejdú editorovým kontraktom') do
  c = NxKovE2
  c.lift_sets.each do |set|
    Array(set['members']).each_with_index do |m, i|
      _, errors = NxKovE2::HWS.validate_member(m, i)
      NxTest.assert_equal([], errors, "#{set['set_id']} člen #{i + 1}: #{errors.inspect}")
    end
  end
end

# ============================================================================
# 7 — ZRKADLO KLIENTA
# ============================================================================

NxTest.test('KOV-E2 (7): `rules.js` pozná PRESNE tie isté kľúče pravidla') do
  c = NxKovE2
  js = c.js(c::RULES_JS)
  keys = js[/var RD_LIFT_KEYS = \[(.*?)\];/m].to_s.scan(/'([a-z_]+)'/).flatten
  server = NxKovE2::HR::LIFT_SCALARS.keys + %w[classes mechanisms arms eligibility]
  NxTest.assert_equal(server.sort, keys.sort,
                      'klient si slovník kľúčov neopisuje vlastnou rukou')
  elig = js[/var RD_LIFT_ELIG = \[(.*?)\];/m].to_s.scan(/\['([a-z_]+)'/).flatten
  NxTest.assert_equal(NxKovE2::HR::ELIGIBILITY_KEYS.sort, elig.sort,
                      'a ani polia spôsobilosti')
end

NxTest.test('KOV-E2 (7): `rules.js` má editor, nie read-only vetu') do
  c = NxKovE2
  js = c.js(c::RULES_JS)
  NxTest.assert(js.include?('function rdLiftHtml('), 'editor existuje')
  NxTest.assert(js.include?('function rdCollectLift('), 'a zbiera sa do pravidla')
  NxTest.refute(js.include?('Tabuľky sa tu zatiaľ needitujú'),
                'veta z E1b zanikla — po E2 by klamala')
  # Súhrn v lište ostáva (zbalený blok musí povedať, čo skrýva).
  NxTest.assert(js.include?('function rdLiftSummary('), 'súhrn do lišty')
end

NxTest.test('KOV-E2 (7): tabuľky výklopu sú na oboch stranách TIE ISTÉ') do
  # Codex #334 kolo 1 P2: hlášku o nedopísanom riadku skladá klient aj server —
  # keby sa zoznamy tabuliek rozišli, jedna strana by o tabuľke mlčala.
  c = NxKovE2
  js = c.js(c::RULES_JS)
  keys = js[/var RD_LIFT_TABLES = \[(.*?)\];/m].to_s.scan(/\['([a-z]+)', '([^']+)', \[/)
  NxTest.assert_equal(NxKovE2::HR::LIFT_TABLES.map { |k, human, _| [k, human] }, keys,
                      'kľúče, ľudské názvy aj PORADIE sú zrkadlom servera')
  NxTest.assert(js.include?('function rdLiftPartialProblem('), 'klient nedopísaný riadok pozná')
  NxTest.assert(js.include?('nedopísaný'), 'a hovorí tú istú vetu ako server')
end

NxTest.test('KOV-E2 (7): duplicitnú hodnotu v tabuľke člena stráži KLIENT') do
  # JEDINÉ miesto, kde je autoritou klient: `code_by_param.codes` je na serveri
  # MAPA, takže druhý riadok s tou istou triedou prepíše prvý ešte pri skladaní
  # payloadu a server duplicitu nikdy neuvidí (Codex #334 kolo 1 P2).
  c = NxKovE2
  js = c.js(c::HWSETS_JS)
  NxTest.assert(js.include?('function hwsMemberProblems('), 'kontrola existuje')
  NxTest.assert(js.include?('hwsSetValidate(d).concat(hwsMemberProblems('),
                'a beží PRI ODOSLANÍ setu, nie len v teste')
  NxTest.assert(js.include?('dvakrát'), 'veta povie, čo je zle')
end

NxTest.test('KOV-E2 (7): `hw_sets.js` UŽ NEMÁ read-only režim z E1a') do
  c = NxKovE2
  js = c.js(c::HWSETS_JS)
  %w[HWS_LOCKED_HINT hwsSetIsNewShape hwsMemberIsNew is_locked].each do |dead|
    NxTest.refute(js.include?(dead), "`#{dead}` zanikol — editor tie tvary už vie (M10)")
  end
  NxTest.assert(js.include?("['param', 'podľa triedy položky']"),
                'stratégia kódu má štvrtú voľbu')
  NxTest.assert(js.include?('code_by_param'), 'a skladá sa do kontraktu servera')
  NxTest.assert(js.include?('quantity_from'), 'aj počet z parametra')
end

NxTest.test('KOV-E2 (7): karta čela kreslí systém VÝHRADNE výklopu') do
  c = NxKovE2
  core = c.js(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'js', 'core.js'))
  body = core[/function frontCardModel\(item, entry, drawer, lift\)\{.*?\n  \}/m].to_s
  NxTest.assert(!body.empty?, 'view-model sa našiel')
  NxTest.assert(body.include?("if (type === 'lift'){\n      rows.push({ kind: 'seg', key: 'lift_system'"),
                'segment systému je pod podmienkou typu `lift`')
  NxTest.assert(body.include?('frontLiftRows(lift)'), 'a riadky výklopu chodia zo servera')
end
