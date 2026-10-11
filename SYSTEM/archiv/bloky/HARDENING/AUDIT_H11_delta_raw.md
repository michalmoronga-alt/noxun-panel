Checkout: `main` @ `6723421b996b351065fcbdbd478e1c92210da593`, bez zmien.

1. **RESOLVED** — F‑01 sa už neuzatvára na 26.0; H11a je iba príprava a H11c vyžaduje quit test aj smoke priamo na 2026.2. [_dev/audit_h11/PACKAGE_H11_v2.md:119](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:119>)

2. **RESOLVED** — nespoľahlivá návratová hodnota `Sketchup.require` už nerozhoduje; Ruby `require` má samostatnú povinnú bránu P1 a jej zlyhanie odloží H11a‑2. [_dev/audit_h11/PACKAGE_H11_v2.md:186](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:186>)

3. **RESOLVED** — session sa pri quit vetve zneplatní bez SketchUp API a klik/Esc/znovuotvorenie potvrdia pokračovanie a dokončia odložené upratanie. [_dev/audit_h11/PACKAGE_H11_v2.md:140](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:140>)

4. **RESOLVED** — vznikol samostatný quit test, ktorý vyžaduje exit `0`, kontroluje poradie udalostí a `0xC0000374` hodnotí ako FAIL. [_dev/audit_h11/PACKAGE_H11_v2.md:255](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:255>)

5. **PARTIAL** — registrácia observera je správne podmienkou initu a testuje `false`/výnimku, ale opakovaný `install!` ešte nemá bezpečný kontrakt pre zlyhanie `remove_observer`; pozri nový nález 1. [_dev/audit_h11/PACKAGE_H11_v2.md:138](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:138>)

6. **RESOLVED** — jedinou podporovanou obnovou je reštart SketchUpu; reload poškodeného procesu sa už nesľubuje. [_dev/audit_h11/PACKAGE_H11_v2.md:197](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:197>)

7. **RESOLVED** — bootstrap `app_lifecycle.rb` má nezávislú chybovú vetvu, sentinel a testy chýbania, syntax chyby aj nedokončeného načítania. [_dev/audit_h11/PACKAGE_H11_v2.md:191](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:191>)

8. **RESOLVED** — podpora `.rbe/.rbs` je výslovne odstránená z kontraktu a chránená statickým testom; nejde už o skrytú nekompatibilitu. [_dev/audit_h11/PACKAGE_H11_v2.md:186](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:186>)

9. **RESOLVED** — triedenie zostáva primerané a inštalátor dostal funkčné scenáre pre 2026, novší ročník, nepodporované ročníky aj override. [_dev/audit_h11/PACKAGE_H11_v2.md:94](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:94>)

## NEW findings

1. **FIX-IN-H11 — Idempotentnosť QuitObservera nie je fail-closed pri zlyhaní odobratia.** Návrh predpisuje pri každom `install!` sekvenciu `remove_observer → add_observer`, ale neurčuje kontrolu návratu ani výnimky z `remove_observer`; ak starý observer ostane a nový `add_observer` uspeje, vzniknú dve doručenia `onQuit`, hoci T3 modeluje len úspešné odobratie a A6 vyžaduje presne jedno. Použi návrat bez novej registrácie, ak už držaná referencia bola úspešne nainštalovaná, alebo pri neúspešnom remove zastav aktiváciu. [_dev/audit_h11/PACKAGE_H11_v2.md:138](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:138>), [_dev/audit_h11/PACKAGE_H11_v2.md:220](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:220>)

2. **FIX-IN-H11 — „Chyba v ktoromkoľvek súbore“ stále nezahŕňa syntax chybu samotného `main.rb`.** `main.rb` načítava priamo `SketchupExtension` registrovaný loaderom; syntax chyba vznikne skôr, než sa vykoná jeho bootstrap `begin/rescue`, takže nevznikne jednotná hláška ani záznam `AppLifecycle`. Buď zúž kontrakt na „ktorýkoľvek vnútorný súbor načítavaný z validného main.rb“, alebo pridaj stabilný bootstrap entrypoint, ktorý načíta main cez chránený `require`. [noxun_engine.rb:373](</C:/APP DEV/RUBY/ENGINE/noxun_engine.rb:373>), [_dev/audit_h11/PACKAGE_H11_v2.md:191](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:191>)

3. **FIX-IN-H11 — Quit test porušuje deklarovaný „len Ruby stav“ nepriamym súborovým I/O.** `onQuit → trace('on_quit') → trace_sink` má počas ukončovania appendovať do `quit_trace.txt`; textový guard kontroluje iba telo `onQuit`, takže `File` volanie cez sink neodhalí. Nejde o SketchUp API, ale test už nemeria totožnú cestu ako produkcia a jeho I/O môže zmeniť timing alebo zlyhať. Kontrakt musí túto testovaciu výnimku priznať a sink chyby úplne izolovať, prípadne zapisovať jedným vopred otvoreným handle. [_dev/audit_h11/PACKAGE_H11_v2.md:133](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:133>), [_dev/audit_h11/PACKAGE_H11_v2.md:256](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:256>)

4. **FIX-IN-H11 — `-ResolveOnly` nemá výslovne nulové vedľajšie účinky a existujúca override vetva vytvára adresár.** Aktuálny inštalátor pri `NOXUN_INSTALL_DEST` volá `New-Item` ešte pred kopírovaním; jednoduché vloženie návratu až pred `Copy-Item` preto v resolve režime stále zmení disk. Doplň podmienku, že `-ResolveOnly` cieľ iba vypočíta a nevyrobí ho, plus test s neexistujúcim override cieľom. [INSTALL_noxun_engine.ps1:25](</C:/APP DEV/RUBY/ENGINE/INSTALL_noxun_engine.ps1:25>), [_dev/audit_h11/PACKAGE_H11_v2.md:87](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:87>)

5. **NOTE — Absolútny Ruby `require` je vedomý proprietárny kontrakt, nie ekvivalent SketchUp loadera.** Oficiálne SketchUp pravidlá odporúčajú `Sketchup.require` bez prípony práve pre `.rb/.rbe/.rbs`; P1 preto musí okrem druhého rovnakého Ruby require zaznamenať presný `$LOADED_FEATURES` kľúč a potvrdiť, že celý updater/restart tok vždy začína v novom procese bez predchádzajúceho `Sketchup.require` toho istého súboru. Aktuálny updater skutočne vyžaduje reštart, čo riziko znižuje. [main.rb:447](</C:/APP DEV/RUBY/ENGINE/noxun_engine/main.rb:447>), [_dev/audit_h11/PACKAGE_H11_v2.md:209](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:209>), [oficiálne Extension Requirements](https://ruby.sketchup.com/file.extension_requirements.html)

6. **NOTE — H11b parsovanie major verzie je prijateľné, ale oficiálne API už poskytuje číselný `Sketchup.version_number`.** Testy `"abc"`, `""`, výnimku a reálne `26.0.429` pokrývajú zamýšľaný fail-open kontrakt; odporúčam iba zapísať, prečo sa zámerne používa stringový major namiesto stabilného číselného API. [_dev/audit_h11/PACKAGE_H11_v2.md:73](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h11/PACKAGE_H11_v2.md:73>), [oficiálna dokumentácia verzie](https://ruby.sketchup.com/Sketchup.html)

**Nový výsledok: 0 BLOCKER · 4 FIX-IN-H11 · 2 NOTE.**


Codex session ID: 01a0f6d7-2f92-71c0-bd4d-847c1b19bcc6
Resume in Codex: codex resume 01a0f6d7-2f92-71c0-bd4d-847c1b19bcc6
