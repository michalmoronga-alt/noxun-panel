---
name: codex-po-pr
description: Po odoslaní PR — budík ~10 min, kontrola Codex GH review (nálezy sú v review threadoch, nie komentoch), oprava nálezov pôvodným implementátorom, kontrola opravy novým slepým subagentom, reply s commit hashom; po splnení brán (CI zelené + review vybavené) merge robí orchestrátor, main nainštaluje len keď PR menil plugin alebo je nasadené niečo iné než main (hook po mergi to konštatuje) a výsledok ide do reportu.
---

# Codex review po PR

**Jediný domov pravidiel review kôl** (delta-verifikácia, kto opravuje a kto kontroluje, nové plné kolo, pravidlo 3 kôl) — ORCHESTRATOR.md
a WORKFLOW na tento skill len odkazujú. Definície tried, na ktoré sa pravidlá odvolávajú (audit-povinná, výrobná/cenová, eskalácia), sú
v `SYSTEM/pravidla/DEFINICIE.md`; kvótové prahy v skille `usage`, sekcia „Prahy a reakcie".

GitHub Codex review (rola **review PR** v tabuľke Obsadenie rolí, `SYSTEM/WORKFLOW.md`) beží automaticky na každý PR, ktorý nie je draft.
**Kolo 1 je vždy plné GH review** (samo po otvorení PR). **Nálezy sú v REVIEW THREADOCH** — `gh pr view --json comments` ich NEUKÁŽE. Signály: 👀 emotikon = review beží; 👍 = OK bez nálezov; review komentáre = nálezy na vyriešenie.

## Postup

0. **Pred `gh pr create`:**
   - **Predrecenzia** (skill `predrecenzia`) prebehla, keď je povinná podľa `SYSTEM/pravidla/DEFINICIE.md` § D4 — jej P1/P2 sú opravené
     a PR popis má sekciu „Predrecenzia".
   - **Číslo PR** je všade, kde ho dávka píše (PLAN, KRONIKA, STAV, `DOGFOODING_vyriesene`), zatiaľ `PR #?` — doplní ho samostatný commit hneď
     po `gh pr create` (krok 1); **PR aj ten commit urobí jedným príkazom `scripts\otvor_pr.ps1`** (ručný postup ostáva ako záloha).
   - **Kvótová brána (rozhodnutie N18, 26.9.2026; `scripts\otvor_pr.ps1` ju volá sám):** `& ".claude\skills\usage\usage.ps1" -Label "<dávka>" -Phase before -Gate codex` — **exit 3 = PR sa
     otvorí ako draft** (`gh pr create --draft`; Codex draft nerecenzuje) a ďalej podľa triedy dávky — prah a reakcie (náhradná brána z kroku 3, alebo
     rozhodne Michal a draft dovtedy čaká): skill `usage`, sekcia „Prahy a reakcie". Dôvod draftu: kolo, ktoré beží samo po otvorení PR, sa nedá zastaviť.
1. **Otvorenie PR:** `powershell -NoProfile -File scripts\otvor_pr.ps1 -Title "<názov>" -BodyFile <popis.md> -CoAuthor "Claude <model> <noreply@anthropic.com>"`
   (PR popis po slovensky v súbore, nie here-string; `-WhatIf` = suchý beh) — skript spraví kvótovú bránu (exit 3 aj neznámy stav kvóty = draft), pushne vetvu, `gh pr create` a hneď **doplní číslo PR**
   namiesto `PR #?` (PLAN, KRONIKA, STAV, `DOGFOODING_vyriesene`; len na riadkoch pridaných vetvou) samostatným commitom, ktorý mení len číslo, a pushne ho.
   **Záloha ručne:** `git push` + `gh pr create` (`--body-file`) a samostatný commit s číslom. Tento commit **pred mergom skontroluje orchestrátor** (pri čistom
   kole 1 inak žiadna delta nebeží; keď delta beží, patrí do nej). Potom nastav budík — Bash `sleep 600` s `run_in_background: true`;
   medzitým pokračuj v inej práci. **Prvé kolo (po `gh pr create`) beží automaticky — ďalšie NIE.**
2. **Po budíku over stav:**
   - `gh pr view <N> --comments` — ak 👀 a nič viac, review ešte beží → krátky druhý budík (~3 min).
   - Nálezy (review thready):
     ```
     gh api graphql -f query='query { repository(owner:"michalmoronga-alt", name:"noxun-panel") { pullRequest(number:<N>) { reviewThreads(first:50) { nodes { isResolved path line comments(first:10) { nodes { databaseId author { login } body } } } } } } }'
     ```
3. **Každý nález:** posúď závažnosť (P1/P2/P3). **Opravu robí pôvodný implementátor** (pokračovanie toho istého subagenta — pozná kód aj dôvody; jeho
   označenie orchestrátor zapíše do handoffu skôr, než sa jeho kontext skomprimuje), **kontrolu opravy nový slepý subagent**; **pri P0/P1 alebo oprave,
   ktorá mení koncept, nový subagent s novým zadaním** (profil Ť — eskalácia podľa `SYSTEM/pravidla/DEFINICIE.md` § D3; a pravidlo 3 kôl b nižšie).
   Oprava ide do vetvy PR, commit + push. Testy:
   headless `ruby tests/run_all.rb` a všetky JS sady (`scripts\run_js_tests.ps1`) vždy; **in-SU test podľa spúšťačov v `SYSTEM/pravidla/DEFINICIE.md` § D6 — je to brána mergu**, runner
   vždy s `-CloseWhenDone` (výsledkový grep až PO dobehu — output sa dopisuje). Pri zmene css/js bumpni `?v=` cache-bust.
   **Pravidlo delta-verifikácie (Michal 29.8.2026, rozšírené 26.9.2026 — šetrenie Codex limitov; každé GH kolo číta celý PR nanovo):**
   ak kolo vrátilo **LEN P2/P3 nálezy**, nové GH kolo sa NEvyžiada. Namiesto toho: fix push → reply s hashom v threadoch → **interná verifikácia
   delty**: **nový slepý subagent** (rola slepý recenzent) overí VÝHRADNE fix commity (`git diff <pred>..<po>`) — správnosť opravy, žiadne vedľajšie
   zmeny, testy pre opravu; pri cenových miestach môže deltu overiť aj ďalší nezávislý hlas z tabuľky Obsadenie rolí (Antigravity nie v nočných
   behoch bez obsluhy). Po čistej delta-verifikácii je review brána uzavretá → merge. Platí **aj pre audit-povinné a výrobné/cenové dávky, ak prešli
   predrecenziou** (rozhodnutie N7).
   **Nové PLNÉ GH kolo (`@codex review`) sa vyžiada LEN pri:** P1/P0 náleze · oprave, ktorá mení KONCEPT riešenia (nie len riadok) · audit-povinnej
   alebo výrobnej/cenovej dávke, ktorá **neprešla predrecenziou**. Precedens úspory: PR #251 mal 3 plné kolá na docs opravy pár riadkov — pod týmto
   pravidlom by kolá 2–3 boli interné delty.

   **Fix push review NEREŠTARTUJE** (zistenie K1, PR #185): Codex sa po pushi opráv sám neozve — ak podľa pravidla
   vyššie nové kolo TREBA, treba ho **VYŽIADAŤ**:
   ```
   gh pr comment <N> --body "@codex review"
   ```
   Budík ~10 min počítaj **od vyžiadania**, nie od pushu. Bez tohto komentára by si čakal na kolo, ktoré nikdy nezačalo — a „žiadne nové thready" by neznamenalo nič.
   **Kvótová brána pred každým ďalším kolom (skill `usage`):** pred každým `@codex review` spusti `& ".claude\skills\usage\usage.ps1" -Gate codex`
   (číta len Codex) — **exit 3 = kolo NEVYŽIADAŠ** a ďalej podľa triedy dávky (skill `usage`, Prahy a reakcie). Pri **náhradnej bráne** (slepý recenzent
   s reprodukciami + interná delta-verifikácia; vzor 31.8., 9.9. a PR #363 13.9.2026) do PR zapíšeš komentár, že GH kolo nahradila z dôvodu kvóty.
   Kolo, ktoré beží samo po otvorení PR, sa nedá zastaviť — ak zlyhá na limite (bot „Failed"/ticho), ber to ako nevyžiadané a pokračuj podľa triedy
   dávky ako pri exit 3.
   **Pri `gh pr ready`** (draft otvorený pre kvótu, krok 5) brána o prepnutí nerozhoduje — rozhoduje len o tom, **či sa na kolo, ktoré tým Codex spustí,
   čaká** (exit 3 = nečaká sa; inak sa naň čaká a vybaví sa podľa krokov 2–4).
4. **Odpovedz v threade s hashom opravy:**
   ```
   gh api repos/michalmoronga-alt/noxun-panel/pulls/<N>/comments/<databaseId>/replies -f body="Opravené v <hash> — <krátko čo a ako>."
   ```
   Ak nález vedome neopravuješ, odpovedz prečo.
5. **Merge robí orchestrátor** — až keď AKTUÁLNA hlava vetvy prešla oboma bránami:
   - **Review kolo uzavreté pre aktuálny head:** buď (a) head dostal 👍 / po budíku **z vyžiadaného kola** nepribudli nové thready a všetky existujúce majú reply (oprava s hashom / zdôvodnenie), alebo (b) predchádzajúce kolo malo LEN P2/P3 a fix delta prešla **internou verifikáciou** (pravidlo delta-verifikácie, krok 3; pri triede D bránu splní kontrola opravy orchestrátorom — odsek Trieda D nižšie) — pri audit-povinnej či výrobnej/cenovej dávke **len ak prešla predrecenziou**; bez predrecenzie sa tam vyžaduje nové plné GH kolo, **okrem** 3. kola podľa výnimky (a) pravidla 3 kôl nižšie a **okrem kvótovej náhradnej brány** (Codex pod prahom podľa skillu `usage`, krok 3: slepý recenzent s reprodukciami + interná delta-verifikácia — vtedy platí v každom kole a PR to prizná; pri audit-povinnej či výrobnej/cenovej dávke alebo oprave P0/P1 len s Michalovým súhlasom), alebo (c) draft otvorený pre kvótu (krok 0) prešiel náhradnou bránou (pri audit-povinnej či výrobnej/cenovej dávke alebo oprave P0/P1 len s Michalovým súhlasom). CI býva hotové skôr než review, takže „CI zelené po pushi opráv" samo osebe NIKDY nestačí na merge. **Brána „žiadne nové thready" platí LEN pre reálne vyžiadané kolo** — ticho po nevyžiadanom kole je ticho Codexu, nie súhlas.
   - **CI zelené** na aktuálnom head commite (`gh pr checks <N>`).
   - **Commit s číslom PR** (krok 1) orchestrátor skontroloval — mení len číslo PR.
   **Draft otvorený pre kvótu** treba pred mergom prepnúť `gh pr ready` (GitHub draft nezmerguje) — **tým sa spustí kolo Codexu**. Ak je kvóta stále
   pod prahom (`-Gate codex` exit 3), **na výsledok kola sa nečaká** — náhradná brána už prebehla; neskorší nález z tohto kola rieši **nový fix PR**.
   Ak sa kvóta medzitým obnovila, na kolo sa čaká a vybaví sa podľa krokov 2–4.
   Merge s pripnutou odrevidovanou hlavou (ochrana pred pretekom s cudzím pushom): `sha=$(git rev-parse HEAD)` → `gh pr merge <N> --merge --match-head-commit "$sha"` (vetvu na GitHube maže repo automaticky). Potom **návrat na čerstvý main**: `git checkout main && git pull && git branch -d <vetva>` a — **keď PR menil plugin** (`noxun_engine/`, `noxun_engine.rb`) **alebo je v SketchUpe nasadené niečo iné než main** (runner, foto okien a export test nasadzujú vetvu; značka `%TEMP%\noxun_nasadene.txt`; oboje po `gh pr merge` konštatuje hook `po_merge.js`) — **inštalácia mainu do SketchUpu** (`INSTALL_noxun_engine.ps1` z čerstvého mainu — in-SU runner nechal nasadenú rozpracovanú vetvu a updater pri rovnakom čísle verzie nič neponúkne) — ďalšia dávka štartuje výhradne odtiaľto. Over `git log origin/main --oneline -3`, že merge commit v maine naozaj je.
6. **Záznam do reportu** (nahrádza niekdajšie hlásenie „môžeš mergovať"): čo PR mení z pohľadu používateľa · stav testov · výsledok Codex review (počet nálezov + ako vyriešené). Report ide Michalovi vždy, keď autonómny beh skončí alebo sa zastaví (najneskôr večer), zrozumiteľný z mobilu bez čítania diffu.

**Trieda D (drobnosť, `SYSTEM/pravidla/DEFINICIE.md` § D3) — len kolo 1:** kolo 1 je plné GH review ako pri každom PR. Nálezy **P2/P3** →
oprava pôvodným implementátorom + reply s hashom (krok 4) a **kontrolu opravy urobí orchestrátor sám** — bez delta subagenta a bez ďalšieho GH kola.
Nález **P0/P1** (alebo oprava meniaca koncept) → eskalácia podľa D3: opravu robí profil Ť s novým zadaním a ďalej platia kroky 3–5 ako pri bežnej dávke.

**Pravidlo 3 kôl (spresnené 25.9.2026):** počítajú sa **GH kolá review, ktoré vrátili nálezy** (kolo s 👍 sa nepočíta; pri dávkach, kde stačí delta-verifikácia,
sa ďalšie GH kolo po P2/P3 ani nevyžaduje — pravidlo sa teda týka hlavne kôl s P0/P1, zmenou konceptu a dávok bez predrecenzie). Keď nálezy vráti aj **3. kolo**:

- **(a) len P2/P3 bez zmeny konceptu** (okrajový prípad, text, fokus, chýbajúci test) → **vedomá výnimka**, PR sa nereže:
  1. opravu urobí na mieste pôvodný implementátor a pushne ju, v každom threade reply s hashom (krok 4),
  2. spusti **slepú delta-verifikáciu**: nový slepý subagent (rola slepý recenzent, Agent tool) overí VÝHRADNE `git diff <hlava pred opravou>..<hlava po oprave>` — správnosť
     opráv, žiadne vedľajšie zmeny, testy na každú opravu (musia na starom kóde padať a na novom prechádzať),
  3. P2/P3 nájdené deltou opraví pôvodný implementátor a overí orchestrátor sám (bez ďalšieho subagenta a bez GH kola — tu sa slučka končí),
  4. **4. GH kolo sa nevyžaduje**; výsledok delty ide do komentára PR a výnimka do PR popisu aj KRONIKY (precedensy S1-B1 #382, D-140 #389),
  5. merge po zelenom CI na finálnej hlave (brána (b) v kroku 5).
- **(b) P0/P1 alebo oprava mení koncept** (dátový kontrakt, tok, návrh riešenia) → PR bol zle narezaný — **zavri ho a rozdeľ na menšie celky**, neiteruj
  (lekcie PR #93 s 10 kolami, #243, #278). To isté platí, keď P1 alebo zmenu konceptu nájde slepá delta v bode (a).

## Pasce

- **Fix push nespúšťa nové kolo** — bez `@codex review` komentára čakáš na niečo, čo nebeží. Prvé kolo po `gh pr create` je jediné automatické.
- **Ani prvé kolo nie je isté:** keď bot namiesto 👀 odpovie „To use Codex here, create an environment for this repo" (stalo sa na PR #186), automatické kolo NEBEŽÍ — vyžiadaj ho tým istým komentárom `@codex review` a budík počítaj odtiaľ. Preto sa stav vždy OVERUJE, nikdy sa nepredpokladá.
- MERGED v `gh pr list` ≠ obsah v maine — po mergi vždy `git fetch` + `git log origin/main`.
- Stacked PR: ak base vetva nebola zmazaná, over `gh pr view <N> --json baseRefName` a prípadne `gh pr edit <N> --base main`. (Repo má „Delete branch on merge" zapnuté, takže pasca hrozí len pri ručne vytvorených reťaziach.)
- Slovenský text do PR/replies vždy cez `--body-file` alebo `-f body=` (nie here-string v PowerShelli).
