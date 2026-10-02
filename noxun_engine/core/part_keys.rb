# frozen_string_literal: true

module Noxun
  module Engine
    # Stabilna identita dielca v ramci korpusu. part_id a nazov definicie mozu
    # nadalej pouzivat renderovaci suffix; part_key je datovy kontrakt pre
    # override, kovanie a buduce vystupy.
    module PartKeys
      SCHEMA = 1

      module_function

      def cabinet(kind, variant = nil)
        key = "cabinet/#{segment(kind)}"
        variant ? "#{key}:#{segment(variant)}" : key
      end

      def zone(zone_id, kind, index)
        "zone:#{segment(zone_id)}/#{segment(kind)}:#{index.to_i}"
      end

      def front(front_id, kind, variant = nil)
        key = "front:#{segment(front_id)}/#{segment(kind)}"
        variant ? "#{key}:#{segment(variant)}" : key
      end

      # Samostatna doska (V0.4.7): kluc je v ramci dosky KONSTANTNY ('board/main') —
      # unikatnost dava id dosky (BRD-001), vazba = id + part_key (owner-scope,
      # standard 2.3). Parameter kind je rezerva pre buduce viacdielcove dosky.
      def board(kind = 'main')
        "board/#{segment(kind)}"
      end

      def for_descriptor(descriptor)
        key = descriptor && descriptor[:part_key].to_s
        raise "Dielcu #{descriptor && descriptor[:suffix]} chyba part_key." if key.nil? || key.empty?
        key
      end

      # Formalna kontrola formatu stabilnej identity — BuildPlan.validate! nou strazi
      # cudzie/poskodene kluce (napr. z rucne editovaneho configu).
      # 'board/' pridane V0.4.7 ADITIVNE (bez bumpu SCHEMA — stare kluce sa nemenia).
      # Toto je len SYNTAKTICKA validita; referencnu validitu ownera v konkretnom
      # plane strazi BuildPlan.validate_hardware! (kluc musi existovat v parts).
      def valid?(key)
        key.to_s.match?(%r{\A(cabinet/|zone:|front:|board/)\S+\z})
      end

      # Prevedie V0.3 override kluce (renderovaci suffix) na part_key podla
      # aktualneho planu. Nezname kluce zachova, aby sa pri migracii nestratili
      # data. Ak existuje novy aj stary kluc, explicitny novy kluc vyhrava.
      def migrate_overrides(raw, descriptors)
        source = raw.is_a?(Hash) ? raw : {}
        current = {}
        legacy_to_current = {}
        Array(descriptors).each do |descriptor|
          key = for_descriptor(descriptor)
          raise "Duplicitny part_key #{key} v plane." if current[key]
          current[key] = true
          suffix = descriptor[:suffix].to_s
          legacy_to_current[suffix] = key unless suffix.empty?
        end

        out = {}
        source.each { |key, value| out[key.to_s] = value if current[key.to_s] }
        source.each do |key, value|
          old = key.to_s
          target = legacy_to_current[old] || old
          out[target] = value unless out.key?(target)
        end
        out
      end

      # --- D-92: ludska podoba identity (LEN zobrazenie) ----------------------
      # Panel doteraz ukazoval v sekcii Kovanie SUROVY part_key
      # ("front:Fmsi0wnix-1-3a3kxe/panel") — id cela je generovany retazec,
      # takze sa z neho neda precitat, o ktore celo ide. Tato funkcia z neho
      # sklada slovensky popis; SERVER je jedina autorita textu (JS uz nic
      # neskladá).
      #
      # fronts = resolved cela (cfg['front_items'], F1 = SPODNE) — cislo „F2"
      # je PORADIE v tomto zozname, presne to, co pouzivatel vidi v karte Cela.
      # Ked sa id v zozname nenajde (stary config, cudzi kluc), pouzije sa
      # surove id — NIKDY sa nehada.
      #
      # CISTA funkcia (ziadne IO/SketchUp) — headless testovatelna. Neznamy
      # tvar kluca sa vracia NEZMENENY: radsej surovy kluc nez vymysleny nazov.
      # nil/prazdny kluc = nil (kovanie na urovni skrinky vlastnika nema).
      def human_label(key, fronts: [])
        k = key.to_s.strip
        return nil if k.empty?

        if (m = k.match(%r{\Afront:([^/]+)/panel\z}))
          return "#{front_no(m[1], fronts)} · zásuvkové čelo"
        end
        if (m = k.match(%r{\Afront:([^/]+)/wing:(left|right|single|p[1-4])\z}))
          return "#{front_no(m[1], fronts)} · #{wing_label(m[2], m[1], fronts)}"
        end
        # KOV-A1: vyklop/sklop (rola flap) a blenda (rola false_front).
        if (m = k.match(%r{\Afront:([^/]+)/flap\z}))
          return "#{front_no(m[1], fronts)} · #{flap_label(m[1], fronts)}"
        end
        if (m = k.match(%r{\Afront:([^/]+)/blind\z}))
          return "#{front_no(m[1], fronts)} · #{blind_label(m[1], fronts)}"
        end
        # KOV-C2b: vyrabane dielce zasuvky z receptu. `box_side` nesie stranu
        # (left/right) — bez nej by dva boky Quadro boxu mali rovnaky popis.
        if (m = k.match(%r{\Afront:([^/]+)/box_side:(left|right)\z}))
          return "#{front_no(m[1], fronts)} · bok boxu #{m[2] == 'left' ? 'ľavý' : 'pravý'}"
        end
        if (m = k.match(%r{\Afront:([^/]+)/(drawer_bottom|drawer_back|drawer_inner_front)\z}))
          return "#{front_no(m[1], fronts)} · #{DRAWER_PART_LABELS[m[2]]}"
        end
        if (m = k.match(%r{\Azone:[^/]+/(shelf|divider_v|divider_h):(\d+)\z}))
          return "#{ZONE_PART_LABELS[m[1]]} #{m[2]}"
        end

        k
      end

      # H12d (C-05): JEDINA tabulka ZOBRAZOVACICH mien roli dielcov. Autoritou
      # je stlpec Rola v Kusovniku — `ProductionCore::ROLE_LABELS`/`role_label`
      # su od H12d alias a delegacia sem; karta dielca dostane hotovy text
      # v payloade (`role_label`), JS ziadnu vlastnu mapu nema. VYROBNE nazvy
      # dielcov (ASCII, kusovnik a VEPO) su INY udaj a ziju v builderoch.
      # Rezervovane roly (`cover_panel`, `gola_profile`) plan nevydava a meno
      # nemaju — vypisu sa surovo, rovnako ako rola z novsieho pluginu.
      ROLE_LABELS = {
        'side_left' => 'Bok ľavý', 'side_right' => 'Bok pravý',
        'top' => 'Strop', 'bottom' => 'Dno', 'back' => 'Chrbát',
        'shelf' => 'Polica', 'divider_v' => 'Zvislá priečka', 'divider_h' => 'Vodorovná priečka',
        'rail_front' => 'Výstuha predná', 'rail_back' => 'Výstuha zadná',
        'plinth' => 'Sokel', 'front_door' => 'Dvierka', 'drawer_front' => 'Čelo zásuvky',
        'free_panel' => 'Voľná doska',
        # KOV-A1 (Codex #280 P2-B): rola `flap` je SPOLOCNA pre vyklop AJ sklop,
        # takze jej nazov musi byt NEUTRALNY — „Výklop" by v kusovniku aj v karte
        # dielca klamal pri kazdom sklope. Konkretny text (vyklop vs. sklop) vie
        # povedat len TYP cela, nie rola: `PartKeys.flap_label` (rovnaky neutralny
        # tvar bez zhody) a od KOV-A2 karta cela s piktogramami.
        'flap' => 'Výklop/sklop', 'false_front' => 'Blenda',
        # KOV-C2a: roly dielcov zasuviek (prehlad ABS cita roly zo seedu — bez
        # nazvov by ukazal holé identifikatory `drawer_bottom`; od KOV-C2b ich
        # plan aj emituje).
        'drawer_bottom' => 'Dno zásuvky', 'drawer_back' => 'Chrbát zásuvky',
        'box_side' => 'Bok boxu', 'drawer_inner_front' => 'Vnútorné čelo zásuvky',
        # KON-B · K2: listy chrbta (spolocny nazov dielca „Lista chrbta", rola
        # rozlisuje hornu a dolnu — stlpec Rola „Lišta chrbta horná · … dolná").
        'back_rail_top' => 'Lišta chrbta horná', 'back_rail_bottom' => 'Lišta chrbta dolná',
        # ROH-A1 · K3: rohova zostava (nazvy dielcov z buildera su ASCII,
        # stlpec Rola je s diakritikou).
        'corner_blind_panel' => 'Blenda korpusová', 'hinge_rail' => 'Výstuha závesov',
        'corner_rail' => 'Rohová výstuha', 'cr_front' => 'CR lišta 1', 'cr_side' => 'CR lišta 2'
      }.freeze

      # Zobrazovacie meno roly; rola bez mena sa vypise surovo (nova rola sa
      # nestrati), prazdna nevymysla text.
      def role_label(role)
        r = role.to_s
        ROLE_LABELS[r] || (r.empty? ? '' : r)
      end

      # Mena dielcov zony v `human_label` (Kovanie, Kontrola) — ODVODENE z tabulky
      # mien roli (H12d), nie druha kopia.
      ZONE_PART_LABELS = %w[shelf divider_v divider_h].to_h { |r| [r, ROLE_LABELS.fetch(r)] }.freeze

      # KOV-C2b: ludske nazvy vyrabanych dielcov zasuvky — v `human_label` stoja
      # za cislom cela („F2 · dno zásuvky"), preto s MALYM prvym pismenom; od H12d
      # odvodene z `ROLE_LABELS` (bajtovo rovnake slova).
      DRAWER_PART_LABELS = %w[drawer_bottom drawer_back drawer_inner_front].to_h do |r|
        label = ROLE_LABELS.fetch(r)
        [r, (label[0].downcase + label[1..]).freeze]
      end.freeze

      # KOV-A2b: ID CELA z kluca dielca (`front:F2/wing:single` -> „F2"), inak
      # nil. Pouziva ju deep-link „klik na RED nález otvorí kartu čela" — kluc
      # ineho druhu (zona, doska, korpus) sa NEHADA a Inspector nedostane nic.
      # CISTA funkcia (ziadne IO), zamerne TU: format kluca je kontrakt tohto
      # modulu a druhy parser inde by sa casom rozisiel.
      def front_id(key)
        m = key.to_s.strip.match(%r{\Afront:([^/]+)/})
        m ? m[1] : nil
      end

      # „F2" podla poradia v resolved celach; bez zhody surove id.
      def front_no(front_id, fronts)
        idx = Array(fronts).index { |f| f.is_a?(Hash) && f['id'].to_s == front_id.to_s }
        idx ? "F#{idx + 1}" : front_id.to_s
      end

      # KOV-A1: kluc `front:F#/flap` je pre vyklop AJ sklop (jedna rola `flap`,
      # smer vyklapania je v `flap_dir`), takze SLOVO rozhoduje TYP resolved
      # cela. Bez zhody sa NEHADA — vrati sa neutralne „výklop/sklop".
      def flap_label(front_id, fronts)
        f = Array(fronts).find { |x| x.is_a?(Hash) && x['id'].to_s == front_id.to_s }
        case f && f['type'].to_s
        when 'lift' then 'výklop'
        when 'fall' then 'sklop'
        else 'výklop/sklop'
        end
      end

      # D-138: blenda je dielec blendy — okrem jedineho cela SLOTU UMYVACKY,
      # ktore je datovo blenda, ale su to dvere umyvacky. Ich resolved polozka
      # nesie odvodeny `label` (zapisuje ho LEN plan slotu); bez neho — alebo
      # bez zhody ID — ostava „blenda". Nic sa nehada.
      def blind_label(front_id, fronts)
        f = Array(fronts).find { |x| x.is_a?(Hash) && x['id'].to_s == front_id.to_s }
        lbl = f ? f['label'].to_s.strip : ''
        lbl.empty? ? 'blenda' : lbl
      end

      # Kridlo dvierok. p1..p4 nesie aj celkovy pocet kridiel („krídlo 2/3"),
      # ked ho resolved celo pozna (wings_n) — inak len poradie.
      def wing_label(wing, front_id, fronts)
        case wing
        when 'left'  then 'dvierka ľavé'
        when 'right' then 'dvierka pravé'
        when 'single' then 'dvierka'
        else
          i = wing[1..-1].to_i
          f = Array(fronts).find { |x| x.is_a?(Hash) && x['id'].to_s == front_id.to_s }
          n = f ? f['wings_n'].to_i : 0
          n >= i ? "dvierka, krídlo #{i}/#{n}" : "dvierka, krídlo #{i}"
        end
      end

      def segment(value)
        cleaned = value.to_s.strip.gsub(/[^A-Za-z0-9_.-]+/, '_')
        cleaned.empty? ? 'unknown' : cleaned
      end
    end
  end
end
