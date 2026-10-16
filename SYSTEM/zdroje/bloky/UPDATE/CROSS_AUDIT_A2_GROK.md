# Krížový audit bloku UPDATE — A2 Grok Build `grok-4.7` (17.10.2026)

> Surový výstup (zhustený orchestrátorom bez zmeny obsahu; repo len čítal). Zadanie rovnaké ako A1–A4.

## A · Odpovede na §5

1. **Bezpečnosť:** bezpečné, keď sa verzia prevezme až po overení celého obsahu a dočasné súbory neležia v zrkadlenej zložke. Overené 17.10.2026: mirror = plná kópia, offline aj bez bežiacej appky ([13401938](https://support.google.com/drive/answer/13401938)); pri rozdielnom obsahu Disk **ponechá obe verzie** ([13470231](https://support.google.com/drive/answer/13470231)); pri nezhode lokálnej zmeny s cloudom kópia úprav ostane v priečinku / koreni / Lost & Found ([2565956](https://support.google.com/drive/answer/2565956)); staršie verzie súboru Disku môžu zmiznúť po 30 dňoch alebo 100 verziách ([2409045](https://support.google.com/drive/answer/2409045)) → vlastných 5 nemenných verzií je správna história. Atomický rename medzi PC ani stav čítača počas sťahovania návod nepopisuje; `_conf(1)` len komunita. Zrkadlený H: odpovie hneď aj bez internetu (posledná lokálna kópia).
2. **Natívna cesta:** pre knižnice nie — Trimble Connect zdieľa `.skp`, nie AppData ([help.sketchup.com](https://help.sketchup.com/en/accounts-and-administration/trimble-connect-sketchup-desktop), 17.9.2026); SketchUp radí užívateľské dáta do AppData ([developer.sketchup.com](https://developer.sketchup.com/article-creating-a-sketchup-extension)); Drive API ťažšie. Názov zákazky → slovník `NOXUN` v `.skp` (vzor setov `hardware_sets.rb` 2185).
3. **Rez:** U2 a U3 nespájať (U2 = vynútenie zápisu a háčiky = dátový kontrakt; U3 = nový modul). U1 v bloku ako samostatná dávka; celý `vepo_settings.json` sa zdieľať nesmie („18 + 36", posledný priečinok — `library_registry.rb` 140–144).
4. **Čísla zákazky:** áno pri prepočte alebo prestavbe (D); otvorenie `.skp` geometriu neprepíše.
5. **Zlyhania:** pád počas prevzatia bezpečný len pri prepnutí celej generácie (JSON + prílohy) naraz (návrh 6.9. r. 131–133). Dve okná u Lucie: `Materials.with_catalog_lock` pri neúspechu spadne (`materials.rb` 515–519), `TemplateStore.with_lock` prehltne a vráti `false` (`templates.rb` 651–653) → zámok + kontrola odtlačku tesne pred zápisom, zámky nevnárať (F4). Odpojenie počas odoslania: zápis do zrkadla prejde, do cloudu neskôr — „Odoslané" = zapísané do zrkadlenej zložky; ukazovateľ pred artefaktom → druhé PC neprevezme a skúsi znova.
6. **Fotky:** `textures/` ako živá cache nie (`library_registry.rb` 169–171, `image_cache.rb` 1–9, 31–37); na Disk len obrázky, na ktoré verzia katalógu odkazuje, ako nemenné kópie s overeným obsahom; doťahovanie pri zobrazení ako doplnok (F2).

## B · Nálezy

- **B1 FIX:** „bez súboru je správca prvý, kto odošle" (koncept r. 50) otvára odoslanie Lucii → správcu založí len výslovná akcia na Michalovom PC; kým súbor nie je, Odoslať vypnuté na oboch.
- **B2 FIX:** dočasné súbory (`json_file_store.rb` 223–225, `*.tmp-<pid>`) nesmú vznikať v zrkadlenej zložke; do H: ukladať len hotový nemenný súbor; prepis toho istého `manifest.json` naráža na „ponechá obe" → ukazovateľ s jedinečným menom, malý súbor „aktuálna verzia" meniť až na konci; súrodenec s iným menom sa neberie ako pravda, len ohlási.
- **B3 FIX:** dve okná u Michala odošlú dve verzie z rovnakého základu → skoršia ostane na Disku bez ukazovateľa; po zápise overiť, že ukazovateľ ukazuje na práve odoslaný súbor, inak „odoslanie neprešlo" a lokálna knižnica ostane neodoslaná zmena.
- **B4 FIX:** záloha R4 nesmie byť `.bak` (`json_file_store.rb` 190–199) → pomenovaná kópia mimo synchronizácie (tvar forenzných kópií materiálov, kniznice.md r. 93).
- **B5 FIX:** zmazaný UNI záznam sa po prevzatí vráti (`library_registry.rb` 179–182, `materials_catalog.rb` 1071–1094, F5) → prevzatie katalógu bez UNI zapíše značku „vedome zmazané"; značka sa na Disk neposiela.
- **B6 FIX:** okno (U5) až po prílohách (U4) — inak prvá verzia materiálov odíde bez `.skm` a fotiek.
- **B7 NOTE:** „Disk nedostupný" pri zrkadle nenastane kvôli pomalému čítaniu; hláška patrí k chýbajúcemu H: alebo nečitateľnému súboru; časový limit ostáva (cesta môže mieriť na visiaci disk); vzor je okno O plugine (`supplier_settings_dialog.rb` 369–419), nie jadro `updater.rb` (27–28, 37–38 bez deadline).
- **B8 NOTE:** názov z cesty nájde len PC, ktoré tú cestu má (`export_settings.rb` 450–472); Michal raz uloží, názov ide do `.skp`; potom má prednosť názov v modeli; „18 + 36" ostáva každému PC.
- **B9 ALREADY EXISTS:** register, zámok materiálov, temp+rename, nemenné `.skm`, náhľady s menom z obsahu, prílohy spotrebičov, snapshot setov a pravidiel kovania, dopredná brána pri kovaní (`hardware_rules.rb` 972–994); U2 dopĺňa odmietnutie zápisu mimo registra a posúdenie pred importom (F12).
- **B10 SIMPLER:** názov do slovníka `NOXUN`; fotky ako prílohy verzie (ako `appearances/`, `appliances/`); vetva dvoch zapisovateľov správne škrtnutá.

## C · Rez

Poradie U2 → U3 → U4 → U5; U1 kedykoľvek. Audit návrhu: U1, U2, U3, U4 áno; U5 nie (ak len volá U3), predrecenzia všetky; U4 = migrácia príloh a zmena `sync` u `textures/` (test zdieľanej množiny ju drží ako cache). **Odhad 5 PR.** Do U3 doplniť B1, B3, B4, B5, postupné zámky; do U4 B6 a obsahovo adresované fotky.

## D · Riziká pre zákazky

Geometria sa sama neprepíše. **Hneď pri prepočte rozpočtu:** cena dosky (`budget.rb` 242), ABS (`budget.rb` 427), kovania (`hardware_sets.rb` 4603; `docs/architecture/hardware.md` 574), sadzby dodávateľa (`budget.rb` 549, `supplier_settings.rb` 15–20). **Pri prestavbe:** ABS z globálnych pravidiel (`cabinet_builder.rb` 1456–1458; ručne prepísaná hrana ostáva); pravidlá a sety kovania zmrazené (`hardware_rules.rb` 981–995, 1007–1011; `hardware_sets.rb` 2363–2368) — zákazka bez snapshotu si zmrazí práve prevzatú knižnicu; hrúbka a materiál z katalógu. **Nemení:** spotrebič (snapshot, `docs/architecture/appliances.md` 22), šablóny, vzhľady a fotky, názov zákazky. Pred prvým ostrým odoslaním cien veta v okne: prevzatie prepíše cenník a najbližší rozpočet pôjde podľa neho.

## Verdikt

Jeden správca a nemenné verzie sú správny tvar, návrh 6.9. sa oprávnene zmenšuje. Pred packages uzavrieť: správca len Michal, celá verzia vrátane príloh, záloha mimo `.bak`, značka zmazaného UNI. Ceny, sadzby a pri prestavbe ABS sa prevzatím zmeniť môžu; geometria sa sama neprepíše.
