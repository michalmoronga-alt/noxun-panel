# frozen_string_literal: true
# Testy UI-01: firemna paleta NOXUN TEAL, jednotny radius a mechanizmus temy.
#
# Kontrolovane invarianty:
#   1) vyberova rodina v `:root` (panel.css) ma PRESNE schvalene teal hodnoty
#      (rozhodnutie O1, 15.8.2026) a nikde v ui/ nezostal stary modry hex,
#   2) komponentovy radius je zjednoteny na 6 px (koniec mixu 4/6/7 — O3),
#   3) tema (O4) prepina VYHRADNE vyberovu rodinu; vyznamove tokeny
#      (danger/warn/ok/ABS/edge/semafor) v nej nesmu byt,
#   4) Ruby aj JS strana poznaju TIE ISTE temy a rovnaky fallback ('noxun'),
#   5) tema zije v %APPDATA%\NOXUN\Engine\ui_theme.json — NIKDY v modeli.
#
# POZN. k forme: `noxun_engine/main.rb` sa headless nacitat NEDA (`require
# 'sketchup.rb'` + registracia menu pri nacitani), preto sa jeho kontrakt overuje
# nad ZDROJOM (rovnaky vzor ako test_guards.rb). Spravanie normalizacie a
# fallbacku behom behu testuje JS dvojnik s rovnakymi pravidlami
# (tests/js/test_ui01_tema.js).
require_relative '../helper' unless defined?(NxTest)

UI01_UI_DIR = File.join(NxTest::ROOT, 'noxun_engine', 'ui')
UI01_CSS = File.read(File.join(UI01_UI_DIR, 'css', 'panel.css'), encoding: 'UTF-8')
UI01_MAIN = File.read(File.join(NxTest::ROOT, 'noxun_engine', 'main.rb'), encoding: 'UTF-8')
UI01_WIN_FIT = File.read(File.join(UI01_UI_DIR, 'js', 'win_fit.js'), encoding: 'UTF-8')

# Schvalena teal rodina (O1) — zrkadlo tabulky tokenov v docs/UI_DIZAJN.md.
UI01_TEAL = {
  '--nx-select' => '#107787',
  '--nx-select-strong' => '#0B5661',
  '--nx-select-accent' => '#0e6b7a',
  '--nx-select-bg' => '#e0f2f4',
  '--nx-select-bg-soft' => '#f0f9fa',
  '--nx-select-bg-hover' => '#d6eef1',
  '--nx-part-border' => '#7fc4cf',
  '--nx-part-bg' => '#f2fafb'
}.freeze

# Stara modra rodina — po UI-01 nesmie zostat ANI JEDEN vyskyt (ani v JS
# kreslenych farbach nahladu).
UI01_STARE_MODRE = %w[#1565c0 #01579b #0277bd #e3f2fd #f1f8ff #e1f5fe #90caf9 #f5fbff
                      #b3e5fc #4fc3f7].freeze

def ui01_css_token(name)
  UI01_CSS[/#{Regexp.escape(name)}\s*:\s*([^;]+);/, 1].to_s.strip
end

def ui01_ui_files
  Dir[File.join(UI01_UI_DIR, '**', '*.{css,html,js,rb}')].sort
end

# --- 1) teal rodina -----------------------------------------------------------

NxTest.test('UI-01: :root ma schvalenu NOXUN teal vyberovu rodinu') do
  UI01_TEAL.each do |token, hex|
    NxTest.assert_equal(hex.downcase, ui01_css_token(token).downcase,
                        "#{token} musi byt #{hex} (rozhodnutie O1)")
  end
end

NxTest.test('UI-01: v ui/ nezostal ziadny hex starej modrej vyberovej rodiny') do
  offenders = []
  ui01_ui_files.each do |path|
    src = File.read(path, encoding: 'UTF-8')
    src.each_line.with_index do |line, i|
      UI01_STARE_MODRE.each do |hex|
        offenders << "#{File.basename(path)}:#{i + 1} (#{hex})" if line.downcase.include?(hex)
      end
    end
  end
  NxTest.assert(offenders.empty?,
                "stara modra vyberova rodina prezila UI-01: #{offenders.join(', ')}")
end

NxTest.test('UI-01: vyznamove farby ostali NEDOTKNUTE (semafor, ABS, hrany, stavy)') do
  # Tieto tokeny nesie vyznam, nie znacka — paleta ani tema sa ich netykaju.
  nedotknutelne = {
    '--nx-action' => '#2e7d32', '--nx-danger' => '#c62828', '--nx-warn' => '#ffb74d',
    '--nx-abs-1mm' => '#e53935', '--nx-abs-2mm' => '#43a047', '--nx-abs-none' => '#b0bec5',
    '--nx-edge-missing' => '#e24b4a', '--nx-edge-extra' => '#ff8c00', '--nx-edge-taped' => '#1d9e75',
    '--nx-state-red' => '#d32f2f', '--nx-state-orange' => '#f9a825', '--nx-state-green' => '#388e3c'
  }
  nedotknutelne.each do |token, hex|
    NxTest.assert_equal(hex.downcase, ui01_css_token(token).downcase,
                        "#{token} sa v UI-01 nesmel zmenit")
  end
end

# --- 2) radius ----------------------------------------------------------------

NxTest.test('UI-01: komponentovy radius je zjednoteny na 6 px (ziadne 4/5/7 px)') do
  # Zakazane su MEDZIHODNOTY 4/5/7 px — presne ten mix, ktory O3 rusi. Vedome
  # povolene ostavaju: 8 px (karty, modaly, dlazdice, boxy), 9 px (badge),
  # 2-3 px (farebne stvorceky), 12px/99px (pill) a 50 % (kruh) — nie su to
  # komponentove ramy. Ked pribudne odovodnena vynimka, patri do WHITELISTU
  # nizsie AJ do docs/UI_DIZAJN.md (inak invariant „vsetko 6" prestane platit
  # potichu).
  whitelist = [] # zatial ziadna vynimka nie je potrebna
  offenders = []
  ui01_ui_files.each do |path|
    next unless path.end_with?('.css', '.html')

    File.read(path, encoding: 'UTF-8').each_line.with_index do |line, i|
      next unless line =~ /border-radius:\s*(4|5|7)px/

      misto = "#{File.basename(path)}:#{i + 1}"
      offenders << misto unless whitelist.include?(misto)
    end
  end
  NxTest.assert(offenders.empty?,
                "radius 4/5/7 px prezil zjednotenie na 6 px (O3): #{offenders.join(', ')}")
end

NxTest.test('UI-01: vyberove tokeny sa nepouzivaju ako farba AKCIE') do
  # Kontrakt temy: „vykonaj" je ZELENE na oboch pocitacoch. Vyplnene tlacidlo
  # akcie preto nesmie brat --nx-select* (v teme Lucia by zruzovelo). Zapnuty
  # stav prepinaca, aktivny tab, hover a odkazy su VYBER — tie farbu menit smu.
  akcne_triedy = %w[.baddbig .primary].freeze
  offenders = []
  ui01_ui_files.each do |path|
    next unless path.end_with?('.css', '.html')

    src = File.read(path, encoding: 'UTF-8').gsub(%r{/\*.*?\*/}m, '') # komentare von
    # Hrube delenie na CSS pravidla (selektor { deklaracie }) — na nasu potrebu staci.
    src.scan(/([^{}]+)\{([^{}]*)\}/) do |selector, body|
      next unless akcne_triedy.any? { |cls| selector.include?(cls) }
      next unless body.include?('--nx-select')

      offenders << "#{File.basename(path)}: #{selector.strip.split("\n").last.strip}"
    end
  end
  NxTest.assert(offenders.empty?,
                "akcne tlacidlo pouziva vyberovy token (v teme Lucia by zruzovelo): #{offenders.join(', ')}")
end

# --- 3) + 4) tema: rozsah, whitelist, fallback --------------------------------

NxTest.test('UI-01: tema pozna presne temy noxun + lucia (Ruby aj JS rovnako)') do
  ruby_themes = UI01_MAIN[/UI_THEMES\s*=\s*%w\[([^\]]+)\]/, 1].to_s.split
  NxTest.assert_equal(%w[noxun lucia], ruby_themes, 'Engine::UI_THEMES')
  NxTest.assert_equal("'noxun'", UI01_MAIN[/UI_THEME_DEFAULT\s*=\s*('[^']+')/, 1].to_s,
                      'zakladna tema je noxun (neznama hodnota na nu spadne)')
  js_themes = UI01_WIN_FIT[/NX_THEME_TOKENS\s*=\s*\{(.+?)\n\};/m, 1].to_s.scan(/^\s{2}(\w+):/).flatten
  NxTest.assert_equal(ruby_themes, js_themes,
                      'JS aj Ruby musia poznat TIE ISTE temy — inak by okno dostalo temu, ktoru nevie nasadit')
  NxTest.assert(UI01_WIN_FIT.include?("NX_THEME_DEFAULT = 'noxun'"),
                'JS fallback musi byt rovnaky ako Ruby')
end

NxTest.test('UI-01: tema Lucia prepisuje PRESNE vyberovu rodinu (8 tokenov)') do
  block = UI01_WIN_FIT[/lucia:\s*\{(.+?)\}/m, 1].to_s
  keys = block.scan(/'(--nx-[a-z-]+)'\s*:/).flatten.sort
  NxTest.assert_equal(UI01_TEAL.keys.sort, keys,
                      'tema smie menit len vyberovu rodinu — vyznamove farby NIKDY')
  hexy = block.scan(/:\s*'(#[0-9a-fA-F]{6})'/).flatten
  NxTest.assert_equal(8, hexy.length, 'kazdy temovy token ma plnu hex hodnotu')
end

NxTest.test('UI-01: tema zije v %APPDATA%, NIKDY v modeli') do
  NxTest.assert(UI01_MAIN.include?("UI_THEME_FILE = 'ui_theme.json'"),
                'nastavenie temy je subor ui_theme.json')
  sekcia = UI01_MAIN[/UI_THEMES = .+?\n  end\nend/m].to_s
  # `JsonFileStore` je subor v %APPDATA% a je v poriadku; `Store.` (NOXUN dict
  # na entite) by znamenal, ze farba panela cestuje v .skp medzi PC.
  NxTest.refute(sekcia.match?(/(?<!JsonFile)Store\./),
                'tema sa NESMIE ukladat do modelu (Store/NOXUN dict)')
  NxTest.assert(sekcia.include?('JsonFileStore.write'),
                'zapis ide cez JsonFileStore (atomicky + .bak)')
  NxTest.assert(sekcia.include?('def self.get_ui_theme') && sekcia.include?('def self.set_ui_theme'),
                'Ruby API davky UI-01: get_ui_theme + set_ui_theme')
end

NxTest.test('UI-01: temu dostane KAZDE okno (spolocny boot hook register_dialog_fit)') do
  NxTest.assert(UI01_MAIN[/def self\.register_dialog_fit.+?register_dialog_theme/m],
                'register_dialog_fit musi registrovat aj nx_theme — inak ostane cast okien bez temy')
  NxTest.assert(UI01_MAIN.include?("dlg.add_action_callback('nx_theme')"),
                'callback nx_theme sa registruje PRED show (kontrakt HtmlDialog)')
  volajuci = Dir[File.join(UI01_UI_DIR, '*.rb')].select do |path|
    File.read(path, encoding: 'UTF-8').include?('register_dialog_fit')
  end
  # ST-1a: pribudlo okno Studio (8. okno) — hook je povinny pre KAZDE okno,
  # inak by nove okno ostalo bez temy aj bez dorovnania velkosti (D-77).
  # ŠT-1c PR B3: okno Vyroba zaniklo — ostalo ich SEDEM.
  # ŠT-2b: okno Materialy zaniklo (obsah je sekcia `mat` Studia) — SEST.
  # ŠT-3a-2: okno Katalog kovania zaniklo (obsah je sekcia `hw`) — PAT.
  # ŠT-3b-1: okno Pravidla kovania zaniklo (obsah je sekcia `rules`) — STYRI.
  # ŠT-3c-1: okno Sablony zaniklo (obsah je sekcia `tpl`) — TRI.
  # ŠT-4a: zaniklo okno Nastavenia rozpoctu (obsah su sekcie `sup`/`bset`/`about`)
  # — DVE, a je to KONECNY stav: ostal Inspector a Studio, ziadny satelit uz nie
  # je. Keby toto cislo niekedy stuplo, znamena to NOVE okno — a to je vzdy
  # rozhodnutie, nie vedlajsi ucinok davky.
  NxTest.assert_equal(2, volajuci.length,
                      "spolocny boot hook musi volat OBIDVE okna (najdene: #{volajuci.map { |p| File.basename(p) }.join(', ')})")
  NxTest.assert_equal(%w[panel.rb studio_dialog.rb], volajuci.map { |p| File.basename(p) }.sort,
                      'a su to PRAVE Inspector a Studio')
  %w[materials_dialog.rb hardware_catalog_dialog.rb rules_dialog.rb
     supplier_settings_dialog.rb templates_dialog.rb].each do |gone|
    NxTest.refute(volajuci.any? { |p| File.basename(p) == gone },
                  "#{gone} uz ziadne okno nevlastni — hook by registroval do prazdna")
  end
  NxTest.assert(UI01_WIN_FIT.include?('sketchup.nx_theme'),
                'okno si temu vypyta z win_fit.js (jediny skript nacitany vo vsetkych oknach)')
  chybajuce = Dir[File.join(UI01_UI_DIR, '*.html')].reject do |path|
    File.read(path, encoding: 'UTF-8').include?('js/win_fit.js')
  end
  NxTest.assert(chybajuce.empty?,
                "okno bez win_fit.js nedostane temu ani fit: #{chybajuce.map { |p| File.basename(p) }.join(', ')}")
end
