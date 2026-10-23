# Rešerš PRAVIDLA — surový výstup Codex (gpt-6.1-sol, effort medium), 17.10.2026

> Surový výstup bez úprav obsahu. Údaj, nie rozhodnutie. Zadanie: [RESERS_ZADANIE.md](RESERS_ZADANIE.md).
> Beh cez `codex:codex-rescue` (companion `task`, read-only, bez `--write`); web search bežal (~22 vyhľadávaní). Trvanie a tokeny log neuvádza.
> Pozor: obal zadanie **skrátil** (nepreniesol doslova „bez skracovania" a „formát odpovede podľa sekcie").

Rešerš je spracovaná ku **17. 10. 2026**. Repo som nemenil, nevytvoril som commity.

**Dátumy pri zdrojoch:** „D" je dátum vydania alebo aktualizácie; „D: neuvedený" znamená, že ho otvorená stránka neuvádza. **Dátum overenia všetkých uvedených zdrojov je 17. 10. 2026.** Dokumentáciu výrobcov, ich blogy a prax konkrétnych repozitárov rozlišujem nižšie.

## 1. AGENTS.md: štandard a podpora nástrojov

`AGENTS.md` je otvorená konvencia spravovaná **Agentic AI Foundation pod Linux Foundation**. Je to obyčajný Markdown bez povinných polí; spoločný formát nezaručuje rovnaké načítavanie vo všetkých nástrojoch. [Oficiálna stránka formátu](https://agents.md/) — D: neuvedený.

| Nástroj | Overené správanie |
|---|---|
| **Claude Code** | Od **v2.1.277** číta `AGENTS.md` natívne. Predvolene však existujúci projektový `CLAUDE.md` alebo `CLAUDE.local.md` má prednosť a môže čítanie `AGENTS.md` vypnúť. Načítava nadradené súbory a vnorené pri práci v podadresári. Podporuje `@path` importy, maximálne štyri vnorené kroky. Pre Windows odporúča **`CLAUDE.md` s importom `@AGENTS.md`** pred symlinkom. Pevný veľkostný strop: **NEOVERENÉ**; odporúčanie je pod 200 riadkov. [Dokumentácia](https://code.claude.com/docs/en/memory) — D: neuvedený. |
| **Codex CLI** | Natívne. Globálny súbor → koreň projektu → adresáre po pracovný adresár. Na každej úrovni vyberá `AGENTS.override.md`, potom `AGENTS.md`, potom nastavené náhradné názvy. Bližšie pravidlá majú prednosť. Predvolený spoločný limit je **32 KiB**, nastaviteľný cez `project_doc_max_bytes`. Automatické rozbaľovanie `@súbor`: **NEOVERENÉ**. [Dokumentácia](https://learn.chatgpt.com/docs/agent-configuration/agents-md) — D: neuvedený. |
| **Codex GitHub review** | Natívne používa koreňové aj vnorené `AGENTS.md` podľa zmenených súborov. Odporúča sekciu `Code Review Rules`. Zhodný veľkostný limit a importy ako CLI: **NEOVERENÉ**. [Dokumentácia review](https://learn.chatgpt.com/docs/third-party/github) — D: neuvedený. |
| **Gemini CLI** | Predvolený názov je `GEMINI.md`; `AGENTS.md` možno zapnúť cez `context.fileName`. Spája globálny, projektový a priebežne objavený kontext. Podporuje `@file.md` importy. Pevný veľkostný limit: **NEOVERENÉ**. [Dokumentácia](https://geminicli.com/docs/cli/gemini-md/) — D: **18. 6. 2026**. |
| **Google Antigravity** | Natívne podporuje `AGENTS.md` aj `GEMINI.md`, vrátane podadresárov; konkrétnejší adresár má prednosť. `@[label](path)` obsah vloží, obyčajné `@filename` iba odkáže na súbor. Dokumentuje **24 000 bajtov na súbor po importoch** a **20 000 tokenov pre aktívne globálne a vždy platné pravidlá**. [Dokumentácia](https://www.antigravity.google/docs/rules/) — D: neuvedený. |
| **Grok Build** | Natívne číta `AGENTS.md` aj varianty názvu a súbory Claude. Globálne pravidlá → koreň repa → pracovný adresár; hlbšie majú prednosť. Súbory ignorované cez `.gitignore` vynecháva. Dokumentácia uvádza načítanie celého obsahu **bez veľkostného stropu**. Importy `@`: **NEOVERENÉ**. [Dokumentácia](https://docs.x.ai/build/features/project-rules) — D: **4. 7. 2026**. |

Pri Antigravity existuje rozpor: staršia dokumentácia uvádza **12 000 znakov**, novšia vyššie uvedené limity. Univerzálny limit pre všetky verzie je preto **NEOVERENÝ**. [Staršia dokumentácia](https://antigravity.google/docs/rules-workflows?app=cli) — D: neuvedený.

## 2. Pravidlá podľa cesty alebo typu súboru

| Nástroj | Podpora a syntax |
|---|---|
| **Claude Code** | `.claude/rules/*.md` s YAML `paths:`, napr. `paths: ["**/*.rb"]`. Bez `paths` sa pravidlo načíta všeobecne. [Dokumentácia](https://code.claude.com/docs/en/memory#path-specific-rules) — D: neuvedený. |
| **Codex CLI / review** | Vnorené `AGENTS.md` pre adresáre. Ekvivalent YAML `paths:` pre textové inštrukcie: **NEOVERENÉ**. Codex `.rules` riadia povolenia príkazov, ide o iný mechanizmus. [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md), [príkazové rules](https://learn.chatgpt.com/docs/agent-configuration/rules) — D: neuvedený. |
| **Gemini CLI** | Kontextové súbory v podadresároch; globová syntax typu `paths:`: **NEOVERENÉ**. [Dokumentácia](https://geminicli.com/docs/cli/gemini-md/) — D: **18. 6. 2026**. |
| **Antigravity** | `.agents/rules/*.md`, napr. `trigger: glob` a `globs: "**/*.rb, **/*.js"`. Ďalšie režimy: `always_on`, `model_decision`, `manual`. Chýbajúci alebo neplatný `trigger` môže pravidlo potichu vyradiť. [Dokumentácia](https://www.antigravity.google/docs/rules/) — D: neuvedený. |
| **Grok Build** | Vnorené `AGENTS.md`; číta tiež `.grok/rules/` a kompatibilné adresáre. Presné spracovanie globov v týchto pravidlách: **NEOVERENÉ**. [Dokumentácia](https://docs.x.ai/build/features/project-rules) — D: **4. 7. 2026**. |
| **Cursor** | `.cursor/rules/*.mdc` s `globs`, `alwaysApply`, `description`. Napríklad `globs: "**/*.rb"` a `alwaysApply: false`. [Dokumentácia](https://cursor.com/docs/rules) — D: neuvedený. |

## 3. Agent Skills: otvorený formát a načítavanie

Otvorený formát tvorí adresár so `SKILL.md`, YAML metadátami `name` a `description` a voliteľnými prílohami. Špecifikácia odporúča **menej než 500 riadkov a približne 5 000 tokenov hlavného obsahu**. Najprv sa sprístupnia metadáta, celé telo pri aktivácii, referencie podľa potreby. Ide o odporúčanie, nie spoločný tvrdý limit. [Špecifikácia Agent Skills](https://agentskills.io/specification) — D: neuvedený.

- **Claude Code:** podporuje formát, automatické aj používateľské vyvolanie; podrobnosti možno odložiť do referencií. Niektoré jeho rozšírené YAML polia sú špecifické pre Claude a nie sú prenosné. [Dokumentácia](https://code.claude.com/docs/en/skills) — D: neuvedený.
- **Codex:** najprv názov a popis, celé telo po výbere skillu. Projektové skills objavuje v `.agents/skills`. [Dokumentácia](https://learn.chatgpt.com/docs/build-skills) — D: neuvedený.
- **Gemini CLI:** najprv metadáta, potom `activate_skill`, používateľský súhlas a vloženie tela. Podporuje `.gemini/skills` aj `.agents/skills`. [Dokumentácia](https://geminicli.com/docs/cli/skills/) — D: **30. 4. 2026**.
- **Antigravity:** podporuje otvorený formát a načítavanie podľa potreby. Číselné odporúčanie veľkosti: **NEOVERENÉ**. [Dokumentácia](https://www.antigravity.google/docs/skills/) — D: neuvedený.
- **Grok Build:** podporuje `SKILL.md`, vlastné aj kompatibilné skills. Presná záruka režimu „iba metadáta → telo" a odporúčaná veľkosť: **NEOVERENÉ**. [Dokumentácia](https://docs.x.ai/build/features/skills-plugins-marketplaces) — D: **11. 8. 2026**.

## 4. Subagenti a pravidlá rolí

- **Claude Code:** bežný subagent dostáva vlastný systémový prompt a zadanie, začína s oddelenou históriou. Projektové inštrukcie štandardne načítavajú vlastné subagenty; vstavané **Explore a Plan sú výnimkou**. Vlastné definície môžu použiť `omitClaudeMd`. Skills uvedené v poli `skills` sa vložia celé už pri štarte. Fork preberá rodičovskú konverzáciu. [Dokumentácia](https://code.claude.com/docs/en/sub-agents#what-loads-at-startup) — D: neuvedený.
- **Codex:** vlastné roly majú `developer_instructions` v `.codex/agents/*.toml`. Dedia oprávnenia, sandbox a dostupné skills rodiča. Presný prísľub opätovného načítania všetkých `AGENTS.md` pre každý spôsob vytvorenia subagenta: **NEOVERENÉ**. Samotné „pracuj read-only" v role nevytvára samostatný read-only sandbox. [Dokumentácia](https://learn.chatgpt.com/docs/agent-configuration/subagents) — D: neuvedený.
- **Gemini CLI:** vlastný systémový prompt a oddelená história; presné dedenie kontextových súborov: **NEOVERENÉ**. [Dokumentácia](https://geminicli.com/docs/core/subagents/) — D: **8. 6. 2026**.
- **Antigravity:** vlastné subagenty nepreberajú existujúcu históriu rodiča; telo definície tvorí systémový prompt. Bezpečnostné nastavenia dedia. Presné dedenie rule súborov pre všetky typy: **NEOVERENÉ**. [Dokumentácia](https://www.antigravity.google/docs/subagents/) — D: neuvedený.
- **Grok Build:** samostatné detské sessions s vlastným kontextom, rodičovi vracajú výsledok. Presné dedenie `AGENTS.md`: **NEOVERENÉ**. [Dokumentácia](https://docs.x.ai/build/features/subagents) — D: **21. 7. 2026**.

## 5. Oficiálne odporúčania proti zahlteniu kontextu

- **Anthropic:** do spoločného súboru patria neodvoditeľné projektové zvláštnosti, príkazy a pracovné dohody. Nepatria tam samozrejmé jazykové pravidlá, podrobné API návody, často meniace sa informácie ani opis každého súboru. Odporúča pravidlá pravidelne skracovať a pozorovaním overovať ich účinok. [Oficiálna dokumentácia](https://code.claude.com/docs/en/best-practices#write-an-effective-claudemd) — D: neuvedený.
- **Anthropic zároveň upozorňuje:** importy pomáhajú organizácii, ale automaticky importovaný obsah **nešetrí kontext**. [Dokumentácia pamäte](https://code.claude.com/docs/en/memory) — D: neuvedený.
- **OpenAI:** odporúča opakovane posudzovať potrebnosť každej inštrukcie a čítať dokumenty podľa úlohy. Prikazovať kompletné povinné čítanie pred každou drobnou úpravou zvyšuje spotrebu kontextu. Aj popisy skills majú byť krátke a presne ohraničené. [Oficiálny blog](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra) — D: **11. 9. 2026**.
- **Google:** odporúča postupné načítavanie a presun podrobností do referencií skills. [Oficiálna dokumentácia](https://geminicli.com/docs/cli/skills-best-practices/) — D: **30. 4. 2026**.
- **xAI:** výslovne uvádza, že krátke konkrétne pravidlá sa dodržiavajú spoľahlivejšie než dlhé. Univerzálny odporúčaný počet riadkov koreňového súboru pre Google alebo xAI: **NEOVERENÉ**. [Oficiálna dokumentácia xAI](https://docs.x.ai/build/features/project-rules) — D: **4. 7. 2026**.

## 6. Konkrétna prax projektov proti rastu

| Príklad | Čo je skutočne doložené |
|---|---|
| **OpenAI Agents SDK, Python a TypeScript — OSS** | Krátke spoločné pravidlá v `AGENTS.md`, opakovateľné postupy v `.agents/skills`, mechanické kroky v skriptoch a GitHub Actions. Je to popísaná prax udržiavateľa. [Oficiálny blog](https://developers.openai.com/blog/skills-agents-sdk) — D: **9. 3. 2026**. |
| **`wshobson/agents` — verejný OSS projekt** | Jeden kanonický `AGENTS.md`, detaily v `docs/`. Kontrolný skript má rozpočty 150 riadkov pre `AGENTS.md` a 200 pre `CLAUDE.md`. Prekročenie však hlási iba ako **warning**; CI ho neblokuje. [Pravidlá projektu](https://raw.githubusercontent.com/wshobson/agents/main/AGENTS.md), [kontrolný skript](https://raw.githubusercontent.com/wshobson/agents/main/tools/doc_gardener.py), [CI](https://raw.githubusercontent.com/wshobson/agents/main/.github/workflows/validate.yml) — D: neuvedený, živá vetva `main`. |
| **OpenAI — interný tímový príklad, nie OSS** | Približne 100-riadkový vstupný rozcestník, podrobnosti v `docs/`, automatické kontroly dokumentácie a opakované upratovacie PR. Tvrdý limit veľkosti vstupného súboru článok nepotvrdzuje. [Oficiálny blog](https://openai.com/index/harness-engineering/) — D: **11. 2. 2026**. |

Zdrojový kód repozitára je primárnym dôkazom jeho vlastnej praxe; nie je potvrdením správania cudzích nástrojov. **ID pravidiel, pravidelný archív histórie pravidiel a tvrdé veľkostné CI brány ako bežná prax veľkých OSS projektov: NEOVERENÉ.** Uvedené príklady nepostačujú na také zovšeobecnenie.

## 7. Hooky a CI namiesto textových pravidiel

Claude Code podporuje všetkých päť menovaných udalostí. Ich funkčný význam je: [oficiálna referencia](https://code.claude.com/docs/en/hooks) — D: neuvedený.

| Udalosť | Vhodné použitie |
|---|---|
| `PreToolUse` | Pred vykonaním posúdiť alebo zablokovať konkrétnu operáciu. |
| `PostToolUse` | Po úspešnej operácii spustiť kontrolu a vrátiť chyby. Už vykonanú operáciu nezvráti. |
| `Stop` | Pred ukončením skontrolovať dokončenie; nesprávna podmienka môže vyvolávať opakované pokračovanie. |
| `SubagentStop` | Skontrolovať ukončenie konkrétneho subagenta. |
| `UserPromptSubmit` | Spracovať vstup alebo doplniť kontext pred odovzdaním modelu. |

**Codex už má natívne hooky**, vrátane uvedených udalostí. Ich možnosti však nie sú všade totožné s Claude: niektoré chyby, timeouty alebo nepodporované odpovede hooku nezablokujú nástroj; nie všetky nástroje prechádzajú hookmi. Podporu lokálnych hookov nemožno automaticky preniesť na GitHub review. [Oficiálna dokumentácia](https://learn.chatgpt.com/docs/hooks) — D: neuvedený.

**Grok Build** má rovnaké názvy viacerých udalostí, ale blokuje iba `PreToolUse`; pád, timeout alebo chybný výstup sú **fail-open** — operácia pokračuje. [Oficiálna dokumentácia](https://docs.x.ai/build/features/hooks) — D: **2. 7. 2026**.

**Odporúčanie pre tento projekt:** strojom kontrolovať formát, encoding, platné odkazy, veľkosť dokumentov, verziové zhody a výsledky testov. V texte ponechať význam pravidiel, hranice zodpovednosti a výnimky. Náročné kontroly sú vhodnejšie ako spoločná CI brána než po každom zápise; ide o odvodený návrh, opretý o odporúčanie OpenAI ponechať mechanické kontroly v CI. [Oficiálny blog](https://developers.openai.com/blog/custom-code-review-rules-for-codex) — D: **20. 7. 2026**.

Pri overovaní hookov treba skúšať aj správny povolený prípad, nie iba zakázaný. OpenAI obdobne odporúča pri review pravidlách skúsiť porušenie, bezpečný protipríklad a nesúvisiacu zmenu. [Ten istý zdroj](https://developers.openai.com/blog/custom-code-review-rules-for-codex) — D: **20. 7. 2026**.

## 8. RAG/MCP verzus statické súbory

**MCP je spôsob sprístupnenia dát a nástrojov; RAG je spôsob vyhľadania relevantných úryvkov.** Pripojený MCP server nezaručuje prečítanie každého pravidla: protokol neurčuje jediný spôsob vloženia resources do kontextu. [Oficiálna špecifikácia MCP](https://modelcontextprotocol.io/specification/2025-11-25/server/resources) — D: verzia **25. 11. 2025**, samostatný dátum aktualizácie neuvedený.

RAG má význam pri rozsiahlej referenčnej báze, ale môže minúť potrebný úryvok alebo stratiť jeho súvislosti. Anthropic opisuje zlepšenia kombináciou kontextových úryvkov, textového vyhľadávania a zoradenia výsledkov. [Oficiálny technický blog](https://www.anthropic.com/engineering/contextual-retrieval) — D: **19. 9. 2024**.

Aj OpenAI pri vlastnom dokumentačnom MCP odporúča vložiť do `AGENTS.md` pravidlo, ktoré agenta na server nasmeruje; samotné pripojenie nestačí na spoľahlivé používanie. [Oficiálna dokumentácia](https://developers.openai.com/learn/docs-mcp) — D: neuvedený.

**Odvodenie pre Noxun:** povinné minimum a rozcestník ponechať statické; MCP/RAG prípadne pridať pre rozsiahle referencie. Dôkaz, že zavedenie MCP vyrieši rast či duplicity vašich pravidiel, je **NEOVERENÝ**. Podklad: vyššie uvedená špecifikácia a dokumentácia.

## 9. Bezpečnosť spoločných súborov a hookov

- **Inštrukčný súbor je vstup ovplyvňujúci správanie agenta.** Cudzí alebo zmenený obsah môže slúžiť na prompt injection. Anthropic odporúča kontrolovať kritické zmeny a pri nedôveryhodnom obsahu používať obmedzené prostredie. [Oficiálna dokumentácia bezpečnosti](https://code.claude.com/docs/en/security) — D: neuvedený.
- **Hook je spustiteľný program s právami používateľa.** Claude upozorňuje na kontrolu príkazov, vstupov a ciest. Pri `claude -p` sa nezobrazuje interaktívne potvrdenie dôvery a repozitárové settings hooky môžu bežať aj v predtým nepotvrdenom priečinku. [Oficiálna dokumentácia hookov](https://code.claude.com/docs/en/hooks#security-considerations) — D: neuvedený.
- **Tajomstvá nepatria do pravidiel ani skills.** Google výslovne odporúča neukladať heslá a API kľúče do dokumentácie či skriptov skillu a pred použitím kontrolovať cudzie skills. [Oficiálne odporúčania](https://geminicli.com/docs/cli/skills-best-practices/) — D: **30. 4. 2026**.
- **Textové „read-only" nie je technické obmedzenie prístupu.** Codex výslovne rozlišuje pokyny roly od skutočného sandboxu. [Oficiálna dokumentácia](https://learn.chatgpt.com/docs/agent-configuration/subagents) — D: neuvedený.

Odvodené opatrenia pre vás: zmeny pravidiel, hookov a konfigurácie nástrojov posudzovať ako zmeny správania aplikácie; nedôveryhodné checkouty spúšťať s minimálnymi právami; tajomstvá držať mimo dokumentácie. Podkladom sú uvedené oficiálne bezpečnostné zdroje.

## Päť najsilnejších zistení pre váš prípad — odporúčania na rozhodnutie

1. **Spoločný `AGENTS.md` je použiteľný základ, ale potrebuje overené napojenie každého klienta.** Na Windows je pre Claude praktický tenký `CLAUDE.md` s importom. [Anthropic](https://code.claude.com/docs/en/memory) — D: neuvedený.
2. **Rozdelenie veľkého súboru do automatických importov samo osebe kontext nezmenší.** Úspora prichádza až načítaním podľa úlohy, cesty alebo roly. [Anthropic](https://code.claude.com/docs/en/memory) — D: neuvedený.
3. **Spoločný vstup má byť krátky rozcestník; podrobné postupy patria k príslušnej práci.** Tento model má doloženú prax aj v OSS údržbe. [OpenAI](https://developers.openai.com/blog/skills-agents-sdk) — D: **9. 3. 2026**.
4. **Ochranu proti „pretekaniu" možno merať automaticky, ale treba výslovne rozhodnúť, či prekročenie iba upozorní alebo zastaví zmenu.** Oboje nemožno zamieňať. [Konkrétny kontrolný skript](https://raw.githubusercontent.com/wshobson/agents/main/tools/doc_gardener.py), [jeho CI](https://raw.githubusercontent.com/wshobson/agents/main/.github/workflows/validate.yml) — D: neuvedený.
5. **Povinné bezpečnostné a výrobné brány nemajú závisieť iba od toho, či si agent spomenie na vetu alebo ju nájde vyhľadávaním.** Krátke pravidlo má určiť povinnosť; vykonateľná kontrola má overiť výsledok. [OpenAI](https://developers.openai.com/blog/custom-code-review-rules-for-codex) — D: **20. 7. 2026**.
