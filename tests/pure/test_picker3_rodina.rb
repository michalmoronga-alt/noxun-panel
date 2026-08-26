# frozen_string_literal: true
# PICKER-3 — SERVEROVÁ časť vyhľadávača: IDENTITA RODINY a KONTEXT RIADKOV.
#
# Dve veci, ktoré vyhľadávaču dáva server a klient ich hádať nesmie:
#
#   A · KONTEXT MENOVKY VIDÍ AJ VIRTUÁLNE DUPLÁKY. Menovka riadku hrúbku
#       hovorí LEN vtedy, keď ju riadok neukáže čipmi (jediná v rodine).
#       Virtuálna ponuka „(duplák ×2)" ale v `Materials.sheets` nie je — je to
#       samostatné pole payloadu (D-49) — takže rodina s jednou kúpenou
#       hrúbkou vyzerala jednovariantne a menovka tvrdila „… 18 mm", hoci
#       riadok dostal druhý čip a po jeho výbere vložil 36 mm.
#
#   B · KANONICKÉ SÚ VŠETKY ZLOŽKY KĽÚČA, nielen skupinová. Katalógový kontrakt
#       (`sheet_identity_key`) porovnáva typ aj štruktúru bez ohľadu na veľkosť
#       písmen, takže `DTDL`/`dtdl` a `ST9`/`st9` sú preň TEN ISTÝ materiál —
#       v surovom tvare však dostali rôzne kľúče a jeden dekor sa v ponuke
#       rozpadol na DVA riadky s rovnakou menovkou.
#
# A druhá strana tej istej mince (guard proti prehnanému zlučovaniu): kľúč
# nesmie zliať nič, čo katalóg drží oddelene — iného výrobcu, inú štruktúru,
# iný typ, iný formát PD ani surový dekor v SCHEMA 1.
require_relative '../helper' unless defined?(NxTest)

P3MAT = Noxun::Engine::Materials
P3_SG = Noxun::Engine::Materials::SCHEMA_GROUPS
P3_PAYLOADS_SRC = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'ui', 'panel', 'payloads.rb'),
                            encoding: 'UTF-8')

def p3_sheet(over = {})
  { 'material_id' => 'M1', 'group_id' => 'G1', 'decor' => '5981', 'structure' => 'MG',
    'type' => 'DTDL', 'thickness' => 18.0 }.merge(over)
end

# --- A: virtualne duplaky v kontexte menoviek --------------------------------

# Dekor s DVOMA rodinami (DTDL + HDF) — menovka riadku sa preto rozlisuje
# (typ, a hrubka pri jedinej v rodine). Bez kolizie by sa nerozlisovalo nic
# a nalez by nebolo vidiet.
def p3_two_families
  [p3_sheet('material_id' => 'A18', 'type' => 'DTDL', 'thickness' => 18.0),
   p3_sheet('material_id' => 'H3', 'type' => 'HDF', 'thickness' => 3.0)]
end

NxTest.test('PICKER-3 A: virtualny duplak robi z rodiny VIACVARIANTOVU') do
  sheets = p3_two_families
  fam = P3MAT.row_family_ctx(sheets, P3_SG) { |_s| '5981 MG' }
  NxTest.assert_equal('5981 MG · DTDL 18 mm',
                      P3MAT.row_label_disambiguated('5981 MG', sheets[0], fam, P3_SG),
                      'bez virtualneho duplaku je rodina jednovariantna — menovka hrubku povie')

  virt = P3MAT.row_family_ctx(sheets, P3_SG, virtual: [[sheets[0], 36.0]]) { |_s| '5981 MG' }
  NxTest.assert_equal('5981 MG · DTDL',
                      P3MAT.row_label_disambiguated('5981 MG', sheets[0], virt, P3_SG),
                      's virtualnym duplakom uz riadok zastupuje 18 aj 36 — hrubka v menovke by klamala')
end

NxTest.test('PICKER-3 A: virtualna hrubka patri do rodiny ZDROJA') do
  sheets = p3_two_families
  virt = P3MAT.row_family_ctx(sheets, P3_SG, virtual: [[sheets[0], 36.0]]) { |_s| '5981 MG' }
  dtd = P3MAT.variant_family_key(sheets[0], P3_SG)
  hdf = P3MAT.variant_family_key(sheets[1], P3_SG)
  NxTest.assert_equal([18.0, 36.0], virt['ths'][dtd].sort,
                      'zdvojena hrubka pribudla do rodiny zdroja')
  NxTest.assert_equal([3.0], virt['ths'][hdf], 'cudzia rodina sa nepohla')
  key = P3MAT.identity_norm('5981 MG')
  NxTest.assert_equal(2, virt['fams'][key].length,
                      'a POCET RODIN sa nemeni — duplak je dalsi cip, nie novy riadok')
end

NxTest.test('PICKER-3 A: kontext bez virtualnych ponuk sa sprava presne ako predtym') do
  sheets = p3_two_families
  NxTest.assert_equal(P3MAT.row_family_ctx(sheets, P3_SG) { |_s| '5981 MG' },
                      P3MAT.row_family_ctx(sheets, P3_SG, virtual: nil) { |_s| '5981 MG' },
                      'chybajuci parameter = povodne spravanie')
  NxTest.assert_equal(P3MAT.row_family_ctx(sheets, P3_SG) { |_s| '5981 MG' },
                      P3MAT.row_family_ctx(sheets, P3_SG,
                                           virtual: [[p3_sheet('uni' => true), 36.0]]) { |_s| '5981 MG' },
                      'UNI zaznam kontext neposunie ani ako virtualny')
end

NxTest.test('PICKER-3 A: panel stavia kontext RIADKOV z katalogu AJ z virtualnych ponuk') do
  # Keby sa dva zdroje rozisli, menovka by klamala zase — len inde.
  NxTest.assert(P3_PAYLOADS_SRC.include?('virtual: duplak_virtual_variants'),
                'row_fam_ctx posiela virtualne varianty')
  blok = P3_PAYLOADS_SRC[/def duplak_virtual_variants.+?\n        end/m].to_s
  NxTest.assert(blok.include?('Materials.duplak_offer_sources(2)'),
                'a berie ich z TEJ ISTEJ autority ako `duplak_offers` (nie z vlastneho filtra)')
end

# --- B: kanonicke zlozky kluca rodiny ----------------------------------------

NxTest.test('PICKER-3 B: VELKOST PISMEN v type a strukture rodinu NEROZBIJE') do
  base = P3MAT.variant_family_key(p3_sheet, P3_SG)
  NxTest.assert_equal(base, P3MAT.variant_family_key(p3_sheet('type' => 'dtdl'), P3_SG),
                      'katalog porovnava typ cez identity_norm — vyhladavac musi tiez')
  NxTest.assert_equal(base, P3MAT.variant_family_key(p3_sheet('structure' => 'mg'), P3_SG),
                      'to iste plati pre strukturu (ST9 vs st9)')
  NxTest.assert_equal(base, P3MAT.variant_family_key(p3_sheet('type' => '  DTDL '), P3_SG),
                      'a okrajove medzery uz vobec nie su iny material')
end

NxTest.test('PICKER-3 B: velkost pismen v RUBE zastenu tiez nerozbije') do
  # Pripona menovky (format + rub) je posledna zlozka kluca a katalog ju
  # porovnava cez identity_norm (`sheet_identity_key` pri obojstrannom type).
  # 'K552' a 'k552' su teda ten isty rub, nie dva materialy.
  a = p3_sheet('type' => 'ZASTENA', 'back_decor' => 'K552', 'back_structure' => 'MG')
  b = p3_sheet('type' => 'ZASTENA', 'back_decor' => 'k552', 'back_structure' => 'mg',
               'material_id' => 'M2', 'thickness' => 4.0)
  NxTest.assert_equal(P3MAT.sheet_identity_key(a, P3_SG),
                      P3MAT.sheet_identity_key(b.merge('thickness' => a['thickness']), P3_SG),
                      'predpoklad: pri rovnakej hrubke su to pre katalog DUPLICITY')
  NxTest.assert_equal(P3MAT.variant_family_key(a, P3_SG), P3MAT.variant_family_key(b, P3_SG),
                      'takze su to dve hrubky JEDNEJ rodiny — jeden riadok s dvomi cipmi')
end

NxTest.test('PICKER-3 B: kluc rodiny sedi s KATALOGOVOU identitou (bez hrubky)') do
  # Toto je cely zmysel opravy: co katalog povazuje za jeden material, ma mat
  # jeden riadok. Dva zaznamy lisiace sa LEN velkostou pisma su pre katalog
  # duplicita (rovnaky `sheet_identity_key`) — nesmu teda mat dve rodiny.
  a = p3_sheet('type' => 'DTDL', 'structure' => 'ST9')
  b = p3_sheet('type' => 'dtdl', 'structure' => 'st9')
  NxTest.assert_equal(P3MAT.sheet_identity_key(a, P3_SG), P3MAT.sheet_identity_key(b, P3_SG),
                      'predpoklad: katalog ich ma za ten isty variant')
  NxTest.assert_equal(P3MAT.variant_family_key(a, P3_SG), P3MAT.variant_family_key(b, P3_SG),
                      'takze aj vyhladavac')
end

NxTest.test('PICKER-3 B: normalizacia NEZLIALA nic, co su realne ROZNE materialy') do
  base = P3MAT.variant_family_key(p3_sheet, P3_SG)
  NxTest.assert(base != P3MAT.variant_family_key(p3_sheet('group_id' => 'G2'), P3_SG),
                'iny vyrobca ostava inou rodinou')
  NxTest.assert(base != P3MAT.variant_family_key(p3_sheet('structure' => 'BS'), P3_SG),
                'ina struktura tiez')
  NxTest.assert(base != P3MAT.variant_family_key(p3_sheet('type' => 'HDF'), P3_SG),
                'iny typ tiez')
  # Medzery sa NEODSTRANUJU (standard 7.1): 'ST9' a 'ST 9' su dva zapisy,
  # ktore katalog drzi oddelene — vyhladavac ich zliat nesmie.
  NxTest.assert(P3MAT.variant_family_key(p3_sheet('structure' => 'ST9'), P3_SG) !=
                P3MAT.variant_family_key(p3_sheet('structure' => 'ST 9'), P3_SG),
                'medzera je rozdiel, nie preklep — to riesi decor_conflict, nie tento kluc')
  pd1 = p3_sheet('type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 600.0])
  pd2 = p3_sheet('type' => 'PD', 'thickness' => 38.0, 'sheet_size' => [4100.0, 900.0])
  NxTest.assert(P3MAT.variant_family_key(pd1, P3_SG) != P3MAT.variant_family_key(pd2, P3_SG),
                'formaty PD ostavaju rozne rodiny (pripona sa normalizuje, nezahadzuje)')
end

NxTest.test('PICKER-3 B: v SCHEMA 1 ostava SUROVY dekor hranicou') do
  # V SCHEMA 1 je surovy text dekoru sucastou KATALOGOVEJ identity
  # (`record_group_key`), takze 'Dub' a 'dub' su tam dva zaznamy, ktore vedla
  # seba legalne existuju. Zlucit ich do jedneho riadku by znamenalo dva cipy
  # s rovnakou hrubkou a moznost vybrat cudzi zaznam.
  a = { 'material_id' => 'A', 'decor' => 'Dub', 'type' => 'DTDL', 'thickness' => 18.0 }
  b = { 'material_id' => 'B', 'decor' => 'dub', 'type' => 'DTDL', 'thickness' => 36.0 }
  NxTest.assert(P3MAT.variant_family_key(a, 1) != P3MAT.variant_family_key(b, 1),
                'skupinova cast sa NEnormalizuje — kanonicky kluc je autorita')
end
