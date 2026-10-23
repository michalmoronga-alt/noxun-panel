# Rešerš PRAVIDLA — surový výstup Grok Build (grok-4.7), 17.10.2026

> Surový výstup, bez úprav (prvý riadok = priebežné hlášky nástroja). Údaj, nie rozhodnutie. Zadanie: [RESERS_ZADANIE.md](RESERS_ZADANIE.md). Beh 4 min 58 s.

Prečítam zadanie a odpoviem na všetky otázky podľa požadovaného formátu. Súbory v repe nemeníam.Oficiálne stránky si otvorím priamo, aby som oddelil dokumentáciu od blogov.Codex dokumentácia sa presunula. Otvorím oficiálne stránky k pravidlám, skillom, hookom a kontextu.Rešerš je len údaj. Súbory v repe som nemenil. Všetko nižšie je overené **17. 10. 2026**. Kde stránka v tele neuvádza dátum, je to tak zapísané. Čo nepotvrdil oficiálny zdroj, je **NEOVERENÉ**.

## A1. AGENTS.md — štandard a kto ho číta

**Krátka odpoveď.** AGENTS.md je obyčajný Markdown bez povinných polí. Vznikol v auguste 2025 pri Codexe, 9. 12. 2025 ho OpenAI odovzdal Agentic AI Foundation pod Linux Foundation. Spravuje ho táto nadácia, nie jedna firma. Špecifikácia na agents.md hovorí: súbor v koreni, vnorené súbory v balíkoch, pri konflikte vyhrá najbližší súbor k upravovanému súboru a pokyn v chate má prednosť pred súborom. Nástroje to čítajú rôzne. Claude Code od verzie 2.1.277 načíta AGENTS.md len vtedy, keď v pracovnom adresári ani nad ním nie je CLAUDE.md, .claude/CLAUDE.md ani CLAUDE.local.md. Codex ho číta vždy, po ceste od koreňa ku aktuálnemu adresáru, najviac jeden súbor na adresár, a celú reťaz oreže na 32 KiB. Gemini CLI ho sám od seba nečíta, kým ho nezapneš v nastavení. Antigravity (aplikácia, CLI aj IDE) číta AGENTS.md aj GEMINI.md. Grok Build číta AGENTS.md aj CLAUDE.md, bez stropu veľkosti.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| Formát je Markdown, žiadne povinné polia. Pri konflikte vyhrá najbližší AGENTS.md k súboru; pokyn v chate má prednosť. V monorepe patrí ďalší AGENTS.md do balíka. V čase textu mal hlavný repozitár OpenAI 88 takých súborov. | https://agents.md/ | v tele neuvedený | 17. 10. 2026 | OVERENÉ, oficiálna špecifikácia |
| Odovzdanie nadácii 9. 12. 2025. Spoluzakladatelia OpenAI, Anthropic a Block, podpora Google, Microsoft, AWS, Bloomberg, Cloudflare. Vydanie v auguste 2025, vtedy viac ako 60 000 projektov. Medzi čitateľmi sú menovaní Codex, Cursor, Gemini CLI, GitHub Copilot, Jules a ďalší. | https://openai.com/index/agentic-ai-foundation/ | 9. 12. 2025 | 17. 10. 2026 | OVERENÉ, oficiálny blog OpenAI |
| Claude číta AGENTS.md priamo od v2.1.277, v predvolení len keď v ceste nie je CLAUDE.md, .claude/CLAUDE.md ani CLAUDE.local.md. Osobný ~/.claude/CLAUDE.md a .claude/rules/ túto podmienku nespúšťajú. Voľba v /config: claude-md-or-agents-md (predvolené), claude-md-and-agents-md, claude-md, managed-only. | https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ, dokumentácia Anthropic |
| Odporúčané prepojenie, keď Claude AGENTS.md sám nenačíta: prvý riadok CLAUDE.md je @AGENTS.md. Import ide do hĺbky štyroch skokov a tokeny nešetrí, lebo sa rozbalí hneď na štarte. Symlink ln -s AGENTS.md CLAUDE.md funguje, na Windows ho Git bez core.symlinks uloží ako obyčajný text a zápis cez odkaz Claude odmietne. | https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ, dokumentácia Anthropic |
| Cieľ je pod 200 riadkov na jeden CLAUDE.md. Súbor do 4 MiB sa načíta celý, väčší sa preskočí. HTML komentáre sa pred vložením do kontextu zmažú. | https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ, dokumentácia Anthropic |
| Codex: najprv ~/.codex (AGENTS.override.md, inak AGENTS.md), potom od koreňa gitu po aktuálny adresár, v každom adresári najviac jeden súbor, poradie override, potom AGENTS.md, potom záložné názvy. Hlbší súbor je v texte neskôr, preto pri rozpore platí on. Prázdne súbory sa preskočia. Súčet sa zastaví na project_doc_max_bytes, predvolene 32 KiB. | https://learn.chatgpt.com/codex/agent-configuration/agents-md.md | v tele neuvedený | 17. 10. 2026 | OVERENÉ, dokumentácia OpenAI |
| GitHub review Codexu berie sekciu ## Code Review Rules z AGENTS.md najbližšie ku zmenenému kódu. Koreňové pravidlá aj pravidlá vnoreného súboru sa zložia na každý zmenený súbor. | https://learn.chatgpt.com/docs/third-party/github | v tele neuvedený | 17. 10. 2026 | OVERENÉ, dokumentácia OpenAI |
| Gemini CLI skladá GEMINI.md z domova, z pracovných adresárov a rodičov a dotiahne ďalší súbor až keď nástroj siahne do adresára. Iný názov, aj zoznam vrátane AGENTS.md, sa zapína v settings.json kľúčom context.fileName. Import je @cesta.md. | https://geminicli.com/docs/cli/gemini-md | Last updated 18. 6. 2026 | 17. 10. 2026 | OVERENÉ, dokumentácia Google |
| Pre jednotlivcov Gemini CLI 18. 6. 2026 skončil. Nástupca Antigravity CLI číta GEMINI.md aj AGENTS.md v aktívnom adresári a globálny ~/.gemini/GEMINI.md bez úpravy súborov. | https://antigravity.google/docs/gcli-migration a https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/ | blog 19. 5. 2026; migračná stránka bez dátumu v tele | 17. 10. 2026 | OVERENÉ, dokumentácia a blog Google |
| Antigravity (app, CLI, IDE) berie AGENTS.md aj GEMINI.md v ľubovoľnom podadresári a tiež .agents/rules. Pravidlá sa sčítavajú. Pri rozpore má prednosť konkrétnejší adresár. Jeden súbor nad 24 000 bajtov sa skráti. Všetky vždy zapnuté pravidlá majú spoločný strop 20 000 tokenov, nad ním sa najväčšie súbory zmenia na odkaz. | https://antigravity.google/docs/rules | v tele neuvedený | 17. 10. 2026 | OVERENÉ, dokumentácia Google |
| Grok načíta pravidlá z ~/.grok/ a potom z každého adresára od koreňa po pracovný adresár. V adresári berie AGENTS.md, Agents.md, AGENT.md, CLAUDE.md, Claude.md, CLAUDE.local.md a každý *.md v .grok/rules/ (kvôli zhode aj .claude/rules/ a .cursor/rules/). Súbory v .gitignore preskočí. Súbory idú celé, strop veľkosti nie je. Krátke konkrétne vety sa držia spoľahlivejšie. grok inspect vypíše nájdené súbory a odhad tokenov. | https://docs.x.ai/build/features/project-rules | v tele markdownu dátum nebol | 17. 10. 2026 | OVERENÉ, dokumentácia xAI |

**Nenašiel som.** Jedno spoločné poradie „kto vyhrá, keď v tom istom adresári leží aj AGENTS.md, aj CLAUDE.md“ pre všetky štyri nástroje. U Claude je to prepínač. U Codexu je CLAUDE.md len záložný názov, ak ho pridáš do project_doc_fallback_filenames. U Groka veta „reads any of“ vymenúva obe rodiny a strop „jeden súbor na adresár“ tam nie je. Či Grok pri oboch súboroch vloží oba texty, stránka nehovorí vetou „oba naraz“. Tvrdenie z blogov, že v Antigravity GEMINI.md porazí AGENTS.md v tom istom adresári, súčasná oficiálna stránka pravidiel nepotvrdzuje. **NEOVERENÉ.**

## A2. Pravidlá viazané na cestu alebo typ súboru

**Krátka odpoveď.** U Claude je to .claude/rules/*.md s YAML poľom paths a globmi. Bez paths sa súbor načíta pri každom štarte. S paths sa načíta, až keď Claude súbor číta alebo mení. Codex path-glob na text pravidiel nemá. Má vnorené AGENTS.md a AGENTS.override.md podľa adresára. Stránka „Rules“ u Codexu je o tom, ktoré príkazy smú ísť mimo sandboxu, nie o textoch k súborom. Gemini CLI dotiahne GEMINI.md adresára, keď doň nástroj siahne. Antigravity má v .agents/rules/*.md povinné trigger: always_on, model_decision, glob alebo manual. Grok číta všetky *.md v .grok/rules/, .claude/rules/ a .cursor/rules/ a pri skilloch má vlastné paths. Či u pravidiel ctí Claude pole paths, stránka nehovorí. Cursor, hoci nie je v tvojej sade nástrojov, má oficiálne .cursor/rules/*.mdc s globs a alwaysApply. Obyčajné .md v tom priečinku ignoruje.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| Claude: paths je jediné pole, ktoré z pravidla číta. Glob napríklad src/**/*.{ts,tsx}. Pravidlo sa načíta pri Read, Write, Edit a pri čítaní cez príkazy ako cat. Bez paths ide do každého sedenia spolu s .claude/CLAUDE.md. | https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Vnorený CLAUDE.md v podadresári sa u Claude nenačíta na štarte. Načíta sa, keď Claude pracuje so súborom v tom adresári. Súbory sa skladajú, nižší adresár neruší horný. | https://code.claude.com/docs/en/memory a https://code.claude.com/docs/en/large-codebases | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Codex: vnorený AGENTS.md alebo AGENTS.override.md. Žiadny glob na typ súboru v sprievodcovi AGENTS.md nie je. | https://learn.chatgpt.com/codex/agent-configuration/agents-md.md | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Codex „Rules“ ovládajú príkazy mimo sandboxu. | https://learn.chatgpt.com/llms.txt (odkaz na rules) | v tele neuvedený | 17. 10. 2026 | OVERENÉ, rozsah stránky |
| Antigravity: trigger glob s globs: "*.proto, **/*.pb.go". Súbor v .agents/rules/ bez platného trigger sa potichu zahodí. Priečinok rules sa neprechádza do podpriečinkov, kým ich nezapíšeš do .agents/rules.json. AGENTS.md a GEMINI.md frontmatter nemajú a sú v svojom adresári stále zapnuté. | https://antigravity.google/docs/rules | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Gemini CLI: JIT kontext z podadresára, keď nástroj súbor alebo adresár otvorí. | https://geminicli.com/docs/cli/gemini-md | 18. 6. 2026 | 17. 10. 2026 | OVERENÉ |
| Grok: každý *.md v priečinkoch rules. Skill môže mať paths ako gitignore globy a zostane skrytý, kým sa nesiahne na zhodný súbor. | https://docs.x.ai/build/features/project-rules a https://docs.x.ai/build/features/skills-plugins-marketplaces | v tele neuvedený | 17. 10. 2026 | OVERENÉ pre to, čo je napísané |
| Cursor: .cursor/rules/*.mdc, polia alwaysApply, description, globs. AGENTS.md je čistý Markdown, vnorené súbory sa zapnú pri práci v tom strome. | https://cursor.com/docs/rules.md | v tele neuvedený | 17. 10. 2026 | OVERENÉ, dokumentácia Cursor |

**Nenašiel som.** Vetu, že Grok pri čítaní .claude/rules/ poslúcha pole paths a nenačíta súbor pri každom sedení. **NEOVERENÉ.** Rovnako som nenašiel glob syntax pre textové pravidlá Codexu.

## A3. Agent Skills (SKILL.md)

**Krátka odpoveď.** Otvorený formát je priečinok so SKILL.md. Povinné sú name a description. Na štarte ide do kontextu len názov a popis, zhruba 100 tokenov na skill. Celé telo sa načíta až keď sa úloha zhoduje s popisom. Odporúčanie špecifikácie: telo pod 500 riadkov a pod 5 000 tokenov, dlhší materiál do references/. Claude, Codex, Gemini CLI, Antigravity aj Grok tento súbor čítajú, každý z iného priečinka.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| Špecifikácia: name do 64 znakov, zhodné s priečinkom. description do 1 024 znakov, má povedať čo skill robí a kedy. Tri stupne: metadata, telo, súbory v scripts/, references/, assets/ až keď sú potrebné. | https://agentskills.io/specification | v tele neuvedený | 17. 10. 2026 | OVERENÉ, špecifikácia |
| Formát vznikol u Anthropic a je zverejnený ako otvorený štandard. | https://github.com/agentskills/agentskills | v tele README neuvedený | 17. 10. 2026 | OVERENÉ, repozitár štandardu |
| Claude: skill sa načíta na požiadanie, keď je relevantný alebo ho vyvoláš. Do každého sedenia patrí CLAUDE.md. Postup, ktorý netreba stále, patrí do skillu. Subagent načíta celé telo len skillov uvedených v jeho poli skills. | https://code.claude.com/docs/en/features-overview a https://code.claude.com/docs/en/sub-agents | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Codex: postupné odhalenie, najprv name a description. Osobné skillly v ~/.agents/skills, projektové v .agents/skills. | https://learn.chatgpt.com/docs/customization/overview | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Gemini CLI: na rozdiel od GEMINI.md je skill odbornosť na požiadanie. Pred spustením model vidí description. Po súhlase sa do histórie vloží telo SKILL.md. Miesta: .gemini/skills/, .agents/skills/, ~/.gemini/skills/, ~/.agents/skills/. | https://geminicli.com/docs/cli/skills/ a https://geminicli.com/docs/cli/skills-best-practices/ | v tele neuvedený (index okolo 30. 4. 2026) | 17. 10. 2026 | OVERENÉ, dokumentácia; produkt pre jednotlivcov skončil 18. 6. 2026 |
| Antigravity: na štarte zoznam mien a popisov, pri zhode celé SKILL.md. Projektové .agents/skills/, globálne podľa povrchu ~/.gemini/config/skills/ alebo ~/.gemini/antigravity-cli/skills/. CLI zo skillu spraví lomítkový príkaz. | https://antigravity.google/docs/skills | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Grok: .grok/skills/, ~/.grok/skills/, pluginy a ~/.agents/skills/. description hovorí, čo skill robí a kedy. paths ho skryje, kým sa nesiahne na zhodný súbor. user-invocable a disable-model-invocation riadia, či ho model smie spustiť sám. | https://docs.x.ai/build/features/skills-plugins-marketplaces | v tele neuvedený | 17. 10. 2026 | OVERENÉ |

**Nenašiel som.** Vetu xAI, že Grok na štarte drží presne tie tokenové stropy zo špecifikácie (100 a 5 000). Polia description a paths tomu zodpovedajú, čísla stránka neuvádza. **NEOVERENÉ.** Gemini v odporúčaniach píše „pod 5 000 slov“, špecifikácia píše „pod 5 000 tokenov“. To sú dva rôzne stropy.

## A4. Čo dostane subagent

**Krátka odpoveď.** Subagent všade, kde je to popísané, začína vlastným zadaním a nevidí celý rozhovor rodiča. U Claude je to napísané najpresnejšie: vlastný systémový text, správa s úlohou a súbory CLAUDE.md, ktoré načítalo hlavné sedenie, vrátane AGENTS.md, ak sa použil ako projektové inštrukcie. Vstavaní Explore a Plan tieto súbory nedostanú. Vlastný agent ich môže vypnúť poľom omitClaudeMd. Codex dáva vlastnému agentovi povinný developer_instructions a dedí oprávnenia, poskytovateľa a MCP servery. Či dieťa znova načíta reťaz AGENTS.md, stránka nehovorí. Gemini a Antigravity dávajú za systémový text telo súboru agenta a držia históriu oddelene. Grok opisuje dieťa ako samostatnú reláciu, ktorá rodičovi vráti súhrn.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| Claude: čerstvé okno. Nedostane históriu, už použité skilly ani prečítané súbory. Dostane vlastný prompt, text úlohy, hierarchiu CLAUDE.md a AGENTS.md hlavného sedenia, git status a celé telá prednačítaných skillov. Explore a Plan preskočia CLAUDE.md aj git. | https://code.claude.com/docs/en/sub-agents | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Codex: vlastný agent v .codex/agents/*.toml alebo ~/.codex/agents/. Povinné name, description, developer_instructions. Dedí oprávnenia, provider a MCP. Súbor agenta ich neprepíše. Výsledok sa vracia ako súhrn, surový medzikrok v hlavnom vlákne nezostáva. | https://learn.chatgpt.com/docs/agent-configuration/subagents.md a https://developers.openai.com/codex/subagents.md | v tele neuvedený | 17. 10. 2026 | OVERENÉ v tomto rozsahu |
| Gemini CLI: telo .gemini/agents/*.md je systémový prompt. Vlastná história, len vymenované nástroje. | https://geminicli.com/docs/core/subagents/ | v tele neuvedený (index 8. 6. 2026) | 17. 10. 2026 | OVERENÉ |
| Antigravity: .agents/agents/<meno>/agent.md alebo globálne ~/.gemini/config/agents/. Telo je systémový prompt. Objavovanie agentov je postupné, podobne ako pri skilloch. | https://antigravity.google/docs/cli/commands/agents a https://antigravity.google/blog/introducing-custom-agents/ | blog 12. 8. 2026; príkazová stránka bez dátumu | 17. 10. 2026 | OVERENÉ |
| Grok: dieťa je samostatná relácia, vráti súhrn. Typy general-purpose, explore, plan. Vlastné typy v .grok/agents/. | https://docs.x.ai/build/features/subagents | v tele neuvedený | 17. 10. 2026 | OVERENÉ |

**Nenašiel som.** Priamu vetu, že subagent Codexu, Gemini, Antigravity alebo Groka dostane ten istý AGENTS.md alebo CLAUDE.md ako rodič. U Claude je to napísané. U ostatných by šlo o dohad z toho, že „každá relácia načíta pravidlá“. **NEOVERENÉ.**

## B5. Oficiálne rady k veľkosti a k tomu, čo v pamäťovom súbore nemá byť

**Krátka odpoveď.** Spoločná rada štyroch dokumentácií: do súboru, ktorý ide do každého sedenia, patrí len to, čo platí vždy a čo sa inak nedá vyčítať z kódu. Postup na jednu úlohu patrí do skillu. Pravidlo pre jeden druh súborov patrí do súboru, ktorý sa načíta až pri práci s nimi. Anthropic má na CLAUDE.md cieľ pod 200 riadkov a v auguste 2026 píše, aby súbor ostal ľahký a väčšina tokenov išla na nástrahy projektu. OpenAI píše „nech je malý“ a tvrdý strop Codexu je 32 KiB na celú reťaz. Google má u Antigravity 24 KB na súbor a 20 000 tokenov na vždy zapnuté pravidlá. xAI strop nemá a píše, že krátke konkrétne vety sa držia lepšie. Samostatný text xAI s názvom context engineering som nenašiel.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| Dobrá práca s kontextom je najmenšia sada tokenov, ktorá ešte vedie k želanému výsledku. CLAUDE.md ide do kontextu hneď. Veľké dáta sa majú siahnuť nástrojoch až keď treba. Subagent drží šum mimo hlavného okna. | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | 29. 9. 2025 | 17. 10. 2026 | OVERENÉ, oficiálny inžiniersky blog |
| CLAUDE.md má ostať ľahký: na čo repozitár je a nástrahy, ktoré z priečinkov nevidno. Opakované overenie patrí do skillu, na ktorý súbor odkáže. /doctor má súbory a skilly skrátiť. | https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models | 27. 8. 2026 podľa indexu; celé telo článku sa v tomto behu neotvorilo, beriem vety z úryvku oficiálnej URL | 17. 10. 2026 | OVERENÉ v rozsahu úryvku |
| Do CLAUDE.md patrí to, čo by si inak opakoval každé sedenie. Viackrokový postup alebo pravidlo pre časť stromu patria do skillu alebo do path pravidla. Import súbor nezmenší. | https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Codex: „Keep it small.“ Patria tam príkazy na zostavenie a test, očakávania pri review, zvyky repozitára a pokyny pre jeden adresár. Textové pravidlo sa má opierať o pre-commit, linter a typovú kontrolu. Review pravidlá majú byť stručné. | https://learn.chatgpt.com/docs/customization/overview a agents-md sprievodca | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Antigravity: pravidlo je zákaz alebo nemenná veta. Skill je viackrokový postup. Stropy 24 KB a 20 000 tokenov sú vyššie. | https://antigravity.google/docs/rules | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Grok: súbor sa načíta celý, strop nie je, krátke konkrétne inštrukcie sa nasledujú spoľahlivejšie. | https://docs.x.ai/build/features/project-rules | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Samostatný oficiálny text Google alebo xAI s názvom context engineering pre tieto súbory. | — | — | 17. 10. 2026 | NEOVERENÉ, nenašiel som |

Čísla „150 riadkov je tvrdý strop“ a „model nad 200 riadkov súbor prestane čítať“ sú z blogov, nie z dokumentácie. Anthropic hovorí o zhoršení držania pravidiel, nie o odseknutí súboru. Odseknutie má Codex na 32 KiB a Claude až na 4 MiB.

## B6. Ako veľké projekty bránia rastu súboru

**Krátka odpoveď.** Oficiálne vzory sú tri. Súbor, ktorý platí všade, ostane krátky. To, čo platí v jednom adresári, žije v súbore toho adresára. To, čo je postup, žije v skille. Codex má tvrdý strop v produkte, nie v CI. Claude má cieľ 200 riadkov a príkaz /doctor prompt-audit od v2.1.283, ktorý hľadá spory, mŕtve príkazy a zastarané vety a nič neprepíše, kým nepovieš. V CI som overil jeden verejný repozitár, cloudposse/atmos: pri zmene CLAUDE.md púšťa kontrolu veľkosti so stropom 40 000 bajtov a pri súboroch agentov 25 000 bajtov. ID pravidiel, povinný archív histórie a heslo „jedno pravidlo, jeden domov“ ako spoločný postup veľkých projektov oficiálny zdroj neopisuje.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| agents.md dáva za vzor vnorené súbory a ukazuje openai/codex, apache/airflow, temporalio/sdk-java, PlutoLang/Pluto. | https://agents.md/ | v tele neuvedený | 17. 10. 2026 | OVERENÉ, že ich stránka uvádza; veľkosť tých súborov som dnes nemeral |
| /doctor prompt-audit prejde CLAUDE.md, CLAUDE.local.md, AGENTS.md, rules, skilly, príkazy a subagentov. | https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| cloudposse/atmos, workflow Claude Quality Checks, krok Check CLAUDE.md size s max-size 40000 a agentov s max-size 25000. | https://github.com/cloudposse/atmos/blob/main/.github/workflows/claude.yml | dátum commitu v úryvku neuvedený | 17. 10. 2026 | OVERENÉ ako obsah súboru vo výsledku vyhľadávania; celé telo akcie som neotváral |
| Skúsenosť jedného tímu: strop veľkosti súbor znova narastie, keď sa doň vracia história. | https://dev.to/rulestack/we-cut-claudemd-to-33kb-eighteen-days-later-it-was-45kb-again-what-a-size-cap-missed-and-a-3ha8 | 20. 6. 2026 | 17. 10. 2026 | blog, nie oficiálny zdroj a nie veľký verejný produkt |
| ID pravidiel, pravidelný archív dejín a „jedno pravidlo = jeden domov“ ako zvyk pomenovaných veľkých repozitárov. | — | — | 17. 10. 2026 | NEOVERENÉ |

Blízko „jedného domova“ sú oficiálne rady, nie názov metódy: Anthropic káže presunúť postup do skillu a čiastočné pravidlo do path súboru. OpenAI káže dať vetu do najbližšieho adresára. Antigravity káže oddeliť zákaz od postupu.

## B7. Hooky a CI namiesto textu

**Krátka odpoveď.** Textové pravidlo model môže obísť. Hook a CI nie. Anthropic to píše priamo: CLAUDE.md je kontext, nie zámok. Zámok je PreToolUse, oprávnenia alebo CI. Oplatí sa tak vynucovať to, čo sa nesmie stať ani raz: zápis do chránených súborov, nebezpečný príkaz, test pred dokončením. Štýl, názvy a „ako písať kód“ v hooku stoja beh a ľahko zablokujú oprávnenú prácu. Codex má rovnakú rodinu udalostí a hook nespustí, kým ho neschváliš podľa odtlačku. Grok má PreToolUse ako jedinú blokujúcu udalosť a pri páde alebo časovom limite hooku príkaz pustí ďalej.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| Claude: udalosti zahŕňajú UserPromptSubmit, PreToolUse (vie zastaviť), PostToolUse (nástroj už dobehol), Stop, SubagentStop. PreToolUse neobíde pravidlo deny. Statický text patrí do CLAUDE.md, lebo nespúšťa skript. | https://code.claude.com/docs/en/hooks a https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Hook je príkaz s tvojimi oprávneniami. Úprava hooku sa má pozrieť v /hooks, aby sa do konfigurácie nedal pripísať príkaz potichu. Vstup treba kontrolovať, premenné v shelli dávať do úvodzoviek, nesiahnuť na .env. | https://claude.com/resources/articles/how-to-configure-hooks | 11. 12. 2025 | 17. 10. 2026 | OVERENÉ, oficiálny článok Anthropic |
| Text vložený hookom a napísaný ako rozkaz môže spustiť obranu proti vstreknutiu pokynu a Claude ho ukáže tebe namiesto toho, aby ho poslúchol. Pri obnovení sedenia sa starý výstup hooku prehrá a nemusí sedieť s dnešným stavom. | https://code.claude.com/docs/en/hooks | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Codex: PreToolUse, PostToolUse, UserPromptSubmit, SubagentStop, Stop a ďalšie. Ne-spravovaný hook beží až po schválení konkrétneho odtlačku. Zmenený hook sa preskočí, kým ho znova neschváliš. | https://learn.chatgpt.com/docs/hooks | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Grok: tie isté názvy udalostí vrátane PreToolUse, PostToolUse, Stop, SubagentStop, UserPromptSubmit. Číta aj hooky z .claude/settings.json. Projektové hooky treba najprv /hooks-trust. Časový limit predvolene 5 sekúnd. Pád, časový limit a rozbitý výstup príkaz nezastavia. Zastaví len výslovné deny alebo návratový kód 2. | https://docs.x.ai/build/features/hooks | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Antigravity CLI si z Gemini CLI necháva hooky ako schopnosť. | https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/ | 19. 5. 2026 | 17. 10. 2026 | OVERENÉ, že schopnosť ostáva |
| Zoznam udalostí hookov Antigravity CLI a Gemini CLI v tomto behu. | — | — | 17. 10. 2026 | NEOVERENÉ, stránku s tabuľkou udalostí som neotvoril |
| Namerané spomalenie sedenia kvôli hookom. | — | — | 17. 10. 2026 | NEOVERENÉ ako číslo; oficiálne je len to, že hook je proces s časovým limitom |

Falošné blokovanie je u Claude a Codexu vlastnosť návratového kódu 2 a u Groka naopak diera: pokazený bezpečnostný hook príkaz pustí. To druhé je v dokumentácii xAI napísané ako správanie, nie ako odporúčanie.

## B8. RAG alebo MCP server s dokumentáciou namiesto súborov

**Krátka odpoveď.** Oficiálna rada nie je „nahraď pravidlá vyhľadávaním“. To, čo má platiť v každom sedení, ostáva v súbore, lebo sa vloží samo. Veľký opis, ktorý treba len niekedy, ide do skillu, do path pravidla alebo do súboru, ktorý agent otvorí, keď naň inštrukcia ukáže. MCP je u všetkých štyroch prípojka na vonkajší systém, nie náhrada za zákaz. Riziko, že agent pravidlo neuvidí, je v mechanizme: skill sa nenačíta, keď popis nesedí s úlohou, a path pravidlo sa nenačíta, kým sa nesiahne na zhodný súbor.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| CLAUDE.md sa vloží hneď. Vyhľadávanie súborov a subagenti sú spôsob, ako veľký materiál nechať mimo, kým nie je potrebný. | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | 29. 9. 2025 | 17. 10. 2026 | OVERENÉ |
| Skill a path pravidlo sa nenačítajú samy od seba. Popis skillu nesie celé rozhodnutie, či sa telo otvorí. | https://agentskills.io/specification a https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ ako mechanizmus |
| Codex: AGENTS.md je trvalé správanie, skill je opakovateľný postup, MCP je spojenie von z pracovného priestoru. | https://learn.chatgpt.com/docs/customization/overview | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Štúdia, ktorá by merala, ako často agent „nenájde“ pravidlo presunuté do RAG. | — | — | 17. 10. 2026 | NEOVERENÉ |

Antigravity má k tomu blízko režim model_decision: do promptu ide len cesta a popis, celé pravidlo si agent dočíta. To je postupné odhalenie, nie vektorová databáza.

## C9. Bezpečnosť zdieľaných súborov a hookov

**Krátka odpoveď.** Súbor v repe je pokyn, ktorý agent po dôvere v priečinok poslúchne. Cudzí alebo upravený CLAUDE.md, AGENTS.md aj hook vedia zmeniť správanie a hook vie spustiť príkaz s tvojimi právami. Tajomstvo v takom súbore ide do kontextu modelu. Oficiálna ochrana je dôvera v priečinok pred spustením, schválenie hooku podľa odtlačku, kľúče mimo agenta a zákazy, ktoré model nevie prepísať.

| Fakt | Zdroj | Dátum zdroja | Overené | Stav |
| --- | --- | --- | --- | --- |
| Claude: nezvyčajné inštrukcie v README repozitára sa môžu dostať do konania agenta. Kľúč nemá byť v prostredí agenta. Odporúčaný vzor je proxy mimo agenta, ktorý kľúč doplní. | https://code.claude.com/docs/en/agent-sdk/secure-deployment | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Pri prvom otvorení priečinka Claude ukáže dialóg dôvery. V nezverenom priečinku -p beh berie hooky zo súborov nastavení. Dialóg dôvery pri pridaní adresára vymenúva allow pravidlá, hooky a pomocné príkazy, ktoré by sa zapli. | https://code.claude.com/docs/en/permissions | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Import mimo pracovného adresára sa u Claude pýta. Odmietnutie importy v projekte vypne. Symlink pravidiel mimo stromu sa správa ako taký import. Sieťová cesta ako UNC sa nenasleduje. | https://code.claude.com/docs/en/memory | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Hook beží s právami používateľa. Priama úprava konfigurácie hooku čaká na kontrolu v /hooks. | https://claude.com/resources/articles/how-to-configure-hooks | 11. 12. 2025 | 17. 10. 2026 | OVERENÉ |
| Codex: hook bez schválenia konkrétneho odtlačku nebeží. Spravovaný hook z politiky vypnúť nejde. | https://learn.chatgpt.com/docs/hooks | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Grok: projektové hooky, MCP a LSP čakajú na /hooks-trust. Zlyhaný hook je fail-open. | https://docs.x.ai/build/features/hooks | v tele neuvedený | 17. 10. 2026 | OVERENÉ |
| Doslovná veta „do AGENTS.md nikdy nedávaj tajomstvo“ v prejdených dokumentoch. | — | — | 17. 10. 2026 | NEOVERENÉ ako citát; mechanizmus áno: súbor ide do kontextu a kľúč má ostať mimo agenta |

## Najsilnejšie zistenia pre váš prípad

1. Samotné premenovanie CLAUDE.md na AGENTS.md Claude Code nezapne, kým v strome ostane CLAUDE.md alebo CLAUDE.local.md. Spoľahlivé prepojenie na Windows je jednořádkový import @AGENTS.md. Symlink Git na Windows bez zapnutých symlinkov uloží ako krátky text a pravidlá zmiznú.

2. Váš dnešný súbor má okolo 35 kB a ide každej role v každej správe. Codex takú reťaz oreže na 32 KiB, takže spodok súboru review ani audit neuvidí. Claude ho načíta celý a sám píše, že nad 200 riadkov sa pravidlá držia horšie. Grok strop nemá, ale tiež píše, že dlhý text sa drží horšie. Súbor na každú správu unesie príkazy na test, mapu projektu a pár zákazov. WORKFLOW, roly a história tam nepatria.

3. Pravidlo, ktoré platí len pre časť pluginu, má žiť pri tej časti. Claude ho načíta až pri práci s tými súbormi (.claude/rules/ a paths). Codex a GitHub review ho načíta z vnoreného AGENTS.md vedľa zmeneného kódu. Antigravity má na to trigger glob. Rola, ktorá ten kód neotvára, pravidlo nedostane a malé pravidlo nezapadne v spoločnom súbore.

4. Postup, ktorý sa má spustiť len niekedy, patrí do skillu. Na štarte ide do kontextu len jeho veta „kedy ma použiť“. Celé telo príde až pri zhode. To je oficiálna náhrada za rastúci pamäťový súbor. Veta musí povedať, kedy skill použiť. Inak sa telo neotvorí a pravidlo akoby nebolo.

5. Zákaz, ktorý sa nesmie porušiť, text nevynúti. Claude to píše priamo. Patrí do PreToolUse, do oprávnení alebo do CI. Hook v repe je príkaz s vašimi právami, preto má ísť cez revíziu ako kód. U Groka pokazený bezpečnostný hook príkaz pustí ďalej. Tajomstvá do AGENTS.md ani CLAUDE.md nepatria, lebo súbor ide do modelu.

