# frozen_string_literal: true
# Guard testy nad zdrojakmi (citaju subory ako text — invarianty repa).
require_relative '../helper' unless defined?(NxTest)

NxTest.test('guard: VERSION v loaderi a main.rb su synchronne') do
  main_src = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'))
  main_version = main_src[/VERSION\s*=\s*'([^']+)'/, 1].to_s
  NxTest.refute(NxTest::LOADER_VERSION.empty?, 'loader VERSION sa nenasla')
  NxTest.assert_equal(NxTest::LOADER_VERSION, main_version,
                      "VERSION drift: loader '#{NxTest::LOADER_VERSION}' vs main.rb '#{main_version}' — bump treba na oboch miestach")
end

NxTest.test('guard: kazdy ?v= cache-bust v ui/*.html sedi s VERSION') do
  # Konvencia od v0.5.0: jednotny suffix = verzia pluginu. Zmena css/js po
  # vydani = bump patch VERSION (loader + main.rb) — tym sa bumpne aj ?v=.
  offenders = []
  Dir[File.join(NxTest::ROOT, 'noxun_engine', 'ui', '*.html')].sort.each do |path|
    File.readlines(path, encoding: 'UTF-8').each_with_index do |line, i|
      line.scan(/\?v=([0-9A-Za-z.]+)/).each do |(ver)|
        next if ver == NxTest::LOADER_VERSION

        offenders << "#{File.basename(path)}:#{i + 1} (?v=#{ver})"
      end
    end
  end
  NxTest.assert(offenders.empty?,
                "?v= cache-bust nesedi s VERSION '#{NxTest::LOADER_VERSION}': #{offenders.join(', ')}")
end

NxTest.test('guard: Numeric#mm sa nepouziva mimo units.rb') do
  offenders = []
  Dir[File.join(NxTest::ROOT, 'noxun_engine', '**', '*.rb')].sort.each do |path|
    next if File.basename(path) == 'units.rb'

    File.readlines(path, encoding: 'UTF-8').each_with_index do |line, i|
      code = line.sub(/#.*$/, '') # komentare ignorujeme
      next unless code =~ /\.mm\b/
      next if code.include?('Units.mm') && code.scan(/\.mm\b/).length == code.scan(/Units\.mm\b/).length

      offenders << "#{File.basename(path)}:#{i + 1}"
    end
  end
  NxTest.assert(offenders.empty?, "Numeric#mm mimo units.rb (mm<->Length prevadza VYHRADNE Units): #{offenders.join(', ')}")
end
