---
name: antigravity-outside-in
description: OUTSIDE-IN / prior-art audit návrhu cez Antigravity CLI (agy, Gemini Flash s web searchom) — čo už SketchUp/CAD svet rieši, čo je jednoduchšia natívna cesta, aké oficiálne limity nám unikajú. Beží PRED codex-audit pri štarte bloku, novom module, novej API ploche alebo UX vzore s CAD precedensom. Výstup = research packet, ktorý orchestrátor triáduje (reconcile) a až potom posiela návrh do drahých interných auditov.
---

# Antigravity OUTSIDE-IN audit (prior art)

**Čo rieši (Michal 3.9.2026):** doterajšie audity idú zvnútra von (doména → návrh → repo → riziká implementácie). Táto rola otáča smer:
čo už existuje vo SketchUpe / CAD svete → čo z toho vieme použiť → až potom náš návrh. Chytá inú triedu chýb: nie „toto je bug",
ale „toto vôbec nemusíte stavať" a „oficiálna dokumentácia tento limit pomenúva". Zároveň šetrí drahé limity: lacný široký web research
robí Gemini Flash, Fable/Opus len rozhoduje, Codex audituje už lepší návrh.

**Kedy povinne:** štart bloku · nový modul alebo nová SketchUp API plocha (Tool, Overlay, Observer, HtmlDialog kanál, súbory, sieť) ·
UX vzor, pre ktorý existuje CAD precedens (kótovanie, knižnice kovania, nesting, symboly otvárania) · pred schválením mockupu.
**Kedy nie:** fix dávky, docs, čisto dátové dávky bez novej mechaniky (typ A1).

**Mandát agenta je úzky:** dostane hotový proposal package + non-goals + 3–7 cielených otázok a odpovedá VÝHRADNE kategóriami
**ALREADY EXISTS · SIMPLER NATIVE PATH · CAD PRECEDENT · MISSED CONSTRAINT · GOOD CUSTOM SOLUTION · RESEARCH GAP · NO ACTION**.
Nerobí nový návrh, nepíše kód. Každý nález má stav **VERIFIED** (stránku otvoril) / **UNVERIFIED** (z pamäte modelu); každý CAD
precedens nesie **licenciu** (GPL = vzory áno, kód nie; proprietárny produkt = vzory). RESEARCH GAP = „nenašiel som", nikdy vymyslený údaj.

## Postup

1. **Prompt do súboru (UTF-8):** rola + HARD RULES + OUTPUT FORMAT + TARGETED QUESTIONS + inline kontext (text package z PLAN.md,
   výsek FINAL/koncept, prípadne mockup). Vzor: `scratchpad/ag_outside_in_kovcd.md` z 3.9. (pilot KOV-C/D) a `ag_outside_in_sweep.md`
   (jednorazový sweep architektúry). Prompt drž pod ~30 kB; agent NEMÁ čítať repo — obsah ide inline (headless view_file je nespoľahlivé).
2. **Beh (Bash tool, nie PowerShell — diakritika a newliny):**
   ```
   R="$TEMP/agy_research"; mkdir -p "$R"; cd "$R"
   ( agy -p "$(cat <prompt.md>)" --model gemini-3.7-flash-high --mode plan --print-timeout 30m > "$R/<x>_packet.md" 2> "$R/<x>_err.txt"; echo "exit=$?" > "$R/<x>.done" ) > /dev/null 2>&1 &
   ```
   potom `Monitor` s `until [ -f "$R/<x>.done" ]`. `--mode plan` zakazuje edity a shell (rešerš je čítanie), cwd = scratch, nikdy repo.
   Model: najvyšší Gemini Flash (`agy models`; 3.9.2026 = `gemini-3.7-flash-high`). Web nástroje `search_web` + `read_url_content`
   musia mať grant v `~/.gemini/config/config.json` → `userSettings.globalPermissionGrants.allow` (`search_web`, `read_url(*)`) —
   inak headless auto-deny („jetski: … read_url permission"). Detail: memory `antigravity-agy-pilot`.
3. **Packet (max ~70 riadkov, slovensky):** hlavička · tabuľka nálezov (Kategória | Tvrdenie | Dôkaz URL+verzia | Overenie + probe
   snippet | Dotknutá časť package | Odporúčanie | Prácnosť S/M/L | Licencia) · „Nenašiel som" · Zdroje. Ulož do
   `SYSTEM/zdroje/next_sessions/<BLOK>_OUTSIDE_IN_<datum>.md` so status riadkom (KONCEPT / research packet).
4. **Reconcile (orchestrátor, krátko):** pri každom nálezi „berieme / neberieme / mení návrh" + dôvod, do toho istého súboru; ALREADY
   EXISTS a SIMPLER NATIVE PATH sa **pred prijatím overia probe snippetom v SketchUp 2026** (SkAgent `execute_ruby`) — modely si API
   vymýšľajú. Až potom `codex-audit` nad (prípadne upraveným) návrhom.
5. **Ekonomika:** Gemini pool je veľkorysý (pilot 3.9.: dva behy ≈ 2,2 % 5-hodinového limitu), ale Codex má kĺzavé okno ~5 h zdieľané GH review + CLI
   (3.9.: dva paralelné Codex audity ho vyčerpali) — outside-in rešerš patrí na agy, nie na Codex.
6. **Kusovanie (Michal 3.9.): Gemini Flash NIE JE thinking model** — odpovedá rýchlo, ale bez kôl uvažovania. Preto: **jeden beh = 1–2 cielené otázky**
   (nie šesť), pokojne 3–6 malých paralelných behov; každý beh dostane len výsek kontextu, ktorý k otázke patrí. Syntézu packetov a reconcile robí
   orchestrátor; keď treba súdiť medzi protichodnými zdrojmi, druhé kolo pusti na thinking modeli (`gemini-3.1-pro-high` alebo `claude-opus-4-6-thinking`
   z pool-u agy) s už nájdenými URL — retrieval lacno (Flash), úsudok draho (Pro/Opus) a len tam, kde treba.

## Pasce

- Halucinované API: bez URL + verzie + snippetu sa nález neberie. `UNVERIFIED` = nič viac než hypotéza.
- Agent tvrdí, že má aj `run_command`/`write_to_file` — preto `--mode plan` a scratch cwd, nikdy beh v repe.
- `-p -` (stdin) nefunguje; PowerShell rozbije viacriadkový prompt; `--print-timeout` default 5 min je pre rešerš málo.
- Packet nie je rozhodnutie: bez reconcile sa nič v návrhu nemení.
