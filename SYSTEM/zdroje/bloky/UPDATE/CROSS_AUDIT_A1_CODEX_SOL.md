# Krížový audit bloku UPDATE — A1 Codex `gpt-6.1-sol` (17.10.2026, ~05:20)

> Surový výstup, úzke zadanie (R12): čítal len ROZHODNUTIA, KONCEPT, RECONCILE a vymenované úseky `json_file_store.rb`, `library_registry.rb` 1–120,
> `materials_appearance.rb` 175–220, `cabinet_builder.rb` 1440–1460 / 1760–1780, `budget.rb` 100–135 / 235–250. Packages U1–U5 nevidel.
> 1. beh `gpt-6-astra` (široké zadanie, 00:15) skončil limitom bez výstupu.

- **S1 BLOCKER — chýba záväzná obnova po prerušení lokálneho prevzatia.** Skupina má viac JSON súborov, zápis atomicky vymení len jeden (`json_file_store.rb:79–88`); pád medzi výmenami = nový katalóg so starými pravidlami → zlé výrobné/cenové čísla. Celistvosť na Disku lokálny stav nerieši (RECONCILE:46–47). → transakčný kontrakt skupiny (záloha, označenie prevzatej verzie, obnova po páde) a nedokončený stav vyriešiť pred sprístupnením knižnice výpočtom.
- **S2 BLOCKER — odoslanie môže povýšiť náhradný obsah.** Čítanie poškodeného/chýbajúceho primáru vráti starší obsah zo zálohy (`json_file_store.rb:177–184`) → správca by rozšíril starší stav ako novú verziu. → export overí zdravý primár bez tichého fallbacku; náhradný stav najprv obnova; prvé založenie samostatne.
- **S3 BLOCKER — zámok odosielania nezaručuje konzistentný snímok.** Bežná úprava knižnice počas exportu; kovanie má dva zámky, ktoré sa nevnárajú (`library_registry.rb:98–112`) → export môže zachytiť katalóg pred úpravou a sety po nej; odtlačky overia nekonzistentnú zmes. → U2 stanoví zachytenie jednej revízie celej skupiny za účasti existujúcich zapisovateľov; U3 publikuje len tento snímok.
- **S4 BLOCKER — obnovenie katalógov nepokrýva odvodené výpočty.** Rozpočet berie hotový odhad platní a plochu platne s cenou z materiálovej mapy (`budget.rb:114–128`, `239–245`) → po zmene formátu platne rozpočet zo starého odhadu a nového katalógu. → pri relevantnej zmene zneplatniť a prepočítať odvodené výsledky; výsledok vyžadujúci prestavbu označiť ako neaktuálny (R17 ostáva).
- **S5 FIX — „rovnosť verzie" v RECONCILE nezodpovedá R18** (ROZHODNUTIA:45, RECONCILE:46) → dve samostatné brány presne podľa R18.
- **S6 FIX — poradie U3 → U4 potrebuje spoločnú akceptačnú bránu** (RECONCILE:47–51) → kontrakt príloh uzavrieť pred U3; po U4 skutočné odoslanie, prevzatie a návrat staršej verzie vrátane príloh a lokálneho stavu.

**Verdikt (Codex):** jeden správca zjednodušuje publikovanie, ale neuzatvára bezpečnosť lokálneho prevzatia, zdrojového snímku ani následných výpočtov; U2/U3 podmieniť uzavretím S1–S4 a S5–S6; U1 samostatná.
