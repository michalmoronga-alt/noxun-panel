# frozen_string_literal: true
# H6a (blok 9 HARDENING, D-01) - R0: INVENTAR POMOCNYCH TEXTOV Inspectora.
# Invariant „ziadny udaj nezmizne": kazda pomocna veta zo zoznamu
# `tests/fixtures/h6_texty.json` je v Inspectore stale DOSIAHNUTELNA - ako text
# riadku, v `data-tip` bubline alebo v retazci ciste funkcie napovede. Test je
# zeleny PRED aj PO presune viet do „?" (vety sa nemenia, meni sa len miesto).
# Stavove vety (status) musia zostat viditelne - nie su len v `data-tip`.
# Fixturu nevyrabal novy kod (vznikla zo stareho).
require_relative '../helper' unless defined?(NxTest)
require 'json'
require 'cgi'

H6A_UI = File.join(NxTest::ROOT, 'noxun_engine', 'ui')
H6A_FIX = JSON.parse(File.read(File.join(NxTest::ROOT, 'tests', 'fixtures', 'h6_texty.json'), encoding: 'UTF-8'))

def h6a_read(rel)
  File.read(File.join(H6A_UI, rel), encoding: 'UTF-8')
end

# Normalizacia na porovnanie: bez tagov, bez entit, jedna medzera, male pismena.
def h6a_norm(s)
  CGI.unescapeHTML(s.to_s.gsub(/<[^>]*>/, ' ')).gsub(/\s+/, ' ').strip.downcase
end

# Zdrojovy JS: spojenie retazcov `' + '` je pre porovnanie JEDEN retazec.
def h6a_js(rel)
  src = h6a_read(rel)
  src = src.gsub(/(['"])\s*\+\s*(?:\/\/[^\n]*\n\s*)?\1/m, '')
  src.gsub("\\'", "'")
end

# Cely korpus, v ktorom sa veta smie nachadzat (HTML + JS panela a Studia + server textov).
def h6a_corpus
  @h6a_corpus ||= begin
    parts = [h6a_read('panel.html')]
    Dir.glob(File.join(H6A_UI, 'js', '*.js')).sort.each { |f| parts << h6a_js(File.join('js', File.basename(f))) }
    parts << h6a_read(File.join('panel', 'payloads.rb'))
    h6a_norm(parts.join("\n"))
  end
end

# Korpus BEZ data-tip atributov (viditelny text).
def h6a_visible_corpus
  @h6a_visible ||= begin
    html = h6a_read('panel.html').gsub(/data-tip="[^"]*"/m, '')
    parts = [html]
    %w[materials.js rules.js form.js core.js].each { |f| parts << h6a_js(File.join('js', f)) }
    parts << h6a_read(File.join('panel', 'payloads.rb'))
    h6a_norm(parts.join("\n"))
  end
end

NxTest.test('H6a R0: kazda pomocna veta je v Inspectore dosiahnutelna') do
  H6A_FIX['help'].each do |e|
    NxTest.assert(h6a_corpus.include?(h6a_norm(e['text'])), "veta #{e['id']} nenajdena: #{e['text'][0, 60]}")
  end
end

NxTest.test('H6a R0: stavove vety ostavaju viditelne (nie len v data-tip)') do
  H6A_FIX['status'].each do |e|
    NxTest.assert(h6a_visible_corpus.include?(h6a_norm(e['text'])), "stavova veta #{e['id']} nenajdena: #{e['text'][0, 60]}")
  end
end

NxTest.test('H6a R0: fixtura ma pomocne aj stavove vety a unikatne id') do
  NxTest.assert(H6A_FIX['help'].size >= 12, 'pomocne vety')
  NxTest.assert(H6A_FIX['status'].size >= 5, 'stavove vety')
  ids = (H6A_FIX['help'] + H6A_FIX['status']).map { |e| e['id'] }
  NxTest.assert_equal(ids.uniq.size, ids.size, 'id su unikatne')
end
