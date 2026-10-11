1. **RESOLVED** — Pin sa už neposúva projektovým pushom, Undo ani prepnutím dokumentu; T‑A6 pokrýva pôvodný scenár tichého prepísania.

2. **RESOLVED** — `baseline_state(:inherits_global)` obchádza cachované porovnanie a konflikt rieši čerstvou predkontrolou bez zmazania formulára; T‑A3a/b pokrýva obe časovania cache.

3. **RESOLVED** — `library_check` rozlišuje `:ok / :blocked / :unreadable`; poradie brán je fail-closed a pin sa pri chybe čítania ani blokovanom zápise neposúva.

4. **RESOLVED** — T‑A4 aj in‑SU krok 4 deterministicky vkladajú cudzí zápis presne po uzavretí projektovej operácie a pred zamknutým globálnym zápisom; overujú konflikt, bajty, snapshot, kovanie, Undo aj obnovený pin.

5. **RESOLVED** — Návrh výslovne odlišuje starý DOM od starého procesu a požaduje reštart všetkých SketchUp okien zdieľajúcich `%APPDATA%`.

6. **RESOLVED** — R2.7 obmedzuje zlučovanie na dnešných päť kľúčov a T‑B2 explicitne zachytáva `[]`, chýbajúce aj neznáme kľúče bez sľubu forward compatibility.

7. **RESOLVED** — Golden testy sú správne označené iba ako dôkaz nezmenených výpočtov; nový konfliktový lifecycle kryjú samostatné T‑A/T‑B a in‑SU scenáre.

**NEW findings:** žiadne.


Codex session ID: 01a0f4d8-2a30-7440-a6aa-b60f70e2622e
Resume in Codex: codex resume 01a0f4d8-2a30-7440-a6aa-b60f70e2622e
