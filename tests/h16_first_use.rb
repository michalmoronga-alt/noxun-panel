# frozen_string_literal: true
# Noxun Engine — H16 (C-04, package §15 A5): BEZEC PRVEHO BEHU v SAMOSTATNOM
# procese. NIE je to testova sada (`run_all` nacita len `tests/pure/test_*.rb`)
# — spusta ho `tests/pure/test_h16_kniznice.rb` cez `IO.popen([RbConfig.ruby,
# tento_subor])` a generator `tests/fixtures/h16_golden/generate.rb`.
#
# PRECO samostatny proces: `require_relative 'helper'` da CERSTVY sandbox
# `APPDATA` a cistu pamat modulov. V spolocnom procese by si `HardwareCatalog`
# a `ApplianceCatalog` pamatali stav z inych sad (druhy beh by ich subory
# nevyrobil) a cudzi `ApplianceCatalog.test_dir_override` (napr. `test_s1a1`)
# by spotrebice zapisal mimo korena — vysledok by zavisel od poradia sad.
#
# Co robi: PRVY BEH pluginu nad prazdnym korenom (vsetky kniznice, znacky UNI,
# prepinace, rady, aktualizacie, statistika, legacy znacka) + druhy zapis rad
# a aktualizacii (`.bak`). Pocas behu spion `File#flock` + `JsonFileStore.write`
# zapise ZAMOK DRZANY V OKAMIHU ZAPISU kazdeho suboru. Ked je nacitany
# `LibraryRegistry`, vrati aj cesty jeho resolverov a zamkov bez override
# (T11) a s `Materials.test_dir_override` (T2).
#
# Vystup: jeden riadok `NXH16_JSON=<json>` na stdout, aj s malou sondou
# `JSON.pretty_generate` — od JSON 2.8 sa prazdne objekty/polia formatuju inak.
# Sonda vybera pre-H16 golden variant; bajty suborov sa NENORMALIZUJU.
# Nikdy nesiaha na zivy
# `%APPDATA%` — helper ho headless presmeruje do TEMP (inak beh odmietne).
require 'json'
require 'digest'
require 'tmpdir'
live_appdata = ENV['APPDATA'].to_s
require_relative 'helper'
abort 'H16 bezec: len headless (v SketchUpe nie je samostatny interpreter)' unless NxTest.headless?
abort 'H16 bezec: APPDATA nie je sandbox — STOP' if !live_appdata.empty? && ENV['APPDATA'] == live_appdata

module NxH16Run
  E = Noxun::Engine
  HELD = []
  LOCKS_AT = {}

  module_function

  def root
    File.expand_path(E::Materials.dir)
  end

  # Relativna cesta pod korenom; mimo korena nil.
  def rel(path)
    full = File.expand_path(path.to_s)
    base = "#{root}/"
    full.start_with?(base) ? full.sub(base, '') : nil
  end

  # 'Modul.metoda' / 'A::B.metoda' -> vysledok volania (resolver registra).
  def resolve(spec)
    mod, meth = spec.split('.', 2)
    owner = mod.split('::').reduce(E) { |m, c| m.const_get(c, false) }
    owner.public_send(meth)
  end

  def resolve_all(specs)
    specs.to_h do |spec|
      [spec, begin
        File.expand_path(resolve(spec))
      rescue NameError, NoMethodError
        'nedostupny'
      end]
    end
  end

  # Kroky prveho behu — kazdy subor, ktory plugin vyrobi BEZ okna. Novy subor
  # v koreni, ktory vznika bez UI = novy krok TU (mapa rozsirovacich bodov).
  def first_use!
    E::Materials.load
    E::Materials.ensure_uni_records!
    E::Materials.ensure_drawer_uni!
    E::AbsRules.load
    E::HardwareRules.load
    E::HardwareTaxonomy.load
    E::HardwareCatalog.load
    E::HardwareSets.load
    E::SupplierSettings.load
    E::ApplianceCatalog.list
    E::TemplateStore.load
    E::TemplateUsage.stamp('cabinet', 'H16')
    E::UsageStats.record({ 'h16' => 1 }) # zatvorky: Hash, nie kwargs (Ruby 3)
    E::EdgeCheck.write_settings({})
    E::GrainCheck.remember!(true)
    E::DirectionCheck.remember!(true)
    2.times { |i| E::Updater.set_source_dir("X:/h16/d#{i}") }
    2.times { E::DimSeries.set(E::DimSeries::DEFAULTS) }
    E::Tools::LegacyCleanup.run!(Dir.mktmpdir('h16-plugins-'), marker_path: E::Tools::LegacyCleanup.path)
  end
end

module NxH16FlockSpy
  def flock(op)
    res = super
    name = File.basename(path.to_s)
    if (op & File::LOCK_UN).nonzero?
      i = NxH16Run::HELD.index(name)
      NxH16Run::HELD.delete_at(i) if i
    elsif (op & File::LOCK_EX).nonzero?
      NxH16Run::HELD << name
    end
    res
  end
end
File.prepend(NxH16FlockSpy)

module NxH16WriteSpy
  def write(path, payload, shape = nil)
    rel = NxH16Run.rel(path)
    (NxH16Run::LOCKS_AT[rel] ||= []) << NxH16Run::HELD.uniq.sort.join('+') if rel
    super
  end
end
Noxun::Engine::JsonFileStore.singleton_class.prepend(NxH16WriteSpy)

out = { 'json_format' => JSON.pretty_generate({ 'object' => {}, 'array' => [] }) }
reg = defined?(Noxun::Engine::LibraryRegistry) ? Noxun::Engine::LibraryRegistry : nil
if reg
  specs = reg::ENTRIES.map { |r| r['resolver'] }.compact + reg::LOCKS.values
  out['env_root'] = File.expand_path(File.join(ENV['APPDATA'], 'NOXUN', 'Engine'))
  out['paths_env'] = NxH16Run.resolve_all(specs)
end

NxH16Run.first_use!
root = NxH16Run.root
files = Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH)
           .select { |p| File.file?(p) }.map { |p| NxH16Run.rel(p) }.compact.sort
out['files'] = files
out['sha'] = files.to_h { |f| [f, Digest::SHA256.file(File.join(root, f)).hexdigest] }
out['locks_at_write'] = NxH16Run::LOCKS_AT.transform_values { |v| v.uniq.sort }.sort.to_h

if reg
  tmp = Dir.mktmpdir('h16-override-')
  Noxun::Engine::Materials.test_dir_override = tmp
  out['override_root'] = File.expand_path(tmp)
  out['paths_override'] = NxH16Run.resolve_all(specs)
  Noxun::Engine::Materials.test_dir_override = nil
end

puts "NXH16_JSON=#{JSON.generate(out)}"
