# Benchmark review: Open Code Review + Grok vs. GitHub Codex (10.10.2026)

> **Nezáväzný podklad** na pokyn Michala (10.10.2026). Otázka: dá sa Codex kvóta šetriť tým, že menej podstatné review urobí
> **Open Code Review (OCR) + Grok Build** namiesto GH Codex review? Pravidlá review (CLAUDE.md, WORKFLOW.md) sa týmto **nemenia** —
> zmenu navrhuje orchestrátor a schvaľuje Michal.

## Verdikt

**Ako náhrada GH Codex review zatiaľ nie — ani pri ľahkých dávkach.** Grok + OCR zachytil v oboch kolách len **28 %** nálezov Codexu
(5 z 18; s čiastočnou zhodou 33 %), **minul jediný P1** a v kódových PR (Ruby, JS, skripty) bol výrazne slabší ako v dokumentácii.
Je **presný** (kolo 1: 0 planých poplachov) a našiel aj **pravdivé veci, ktoré Codex nemal** — zmysel má ako **doplnkový kontrolór**,
hlavne pri dokumentačných a workflow PR. Kapacita Groka nie je neobmedzená: 20 behov = **52 % týždenného limitu** (~2,5 % na review).

## Nástroj

- **Open Code Review** — `alibaba/open-code-review`, Apache-2.0, CLI `ocr` (npm `@alibaba-group/open-code-review`, testovaná v1.12.13).
  Deterministicky vyberie súbory diffu a priradí im pravidlá; samotnú kontrolu robí LLM.
- **Režim delegovania** (`ocr delegate preview` + `ocr delegate rule`): OCR nevolá žiadny model, kontrolu urobí hostiteľský agent
  z vlastného predplatného. Hostiteľ = **Grok Build CLI `grok-4.7`** cez oficiálny plugin `xai-grok-build` (skript `grok-bridge.mjs run`,
  len čítanie, `--cwd` izolovanej kópie). Žiadny API kľúč, žiadny proxy.
- **Nepoužiteľné cesty:** CC-Switch a podobné presmerovanie predplatného do cudzieho programu (zakázané pravidlami — riziko banu);
  „cesta A" = delegovanie na Claude Code šetrí Codex, ale míňa Claude, ktorý je najužším limitom (prah 80 % session pre implementátorov).
- **Neoverené:** OCR s vlastným `XAI_API_KEY` (plný postup OCR, aj GitHub Action s poznámkami v PR) — či API čerpá zo spoločného týždenného
  poolu predplatného xAI, treba overiť u zdroja; netestované.

## Metodika

- **10 zmergovaných PR** z bloku 9 HARDENING a okolia: 8 s nálezmi Codexu (#466, #457, #456, #455, #454, #438, #434, #465) a 2 bez nálezov
  (#453, #437) na meranie planých poplachov. Spolu **18 nálezov Codexu** (1× P1 v #465, ostatné P2); všetky hodnotiteľ overil v kóde ako reálne.
- Každé PR na **presne tej verzii, ktorú videl Codex** (`original_commit_id` nálezov; pri #465 prvé kolo). Base = merge-base s mainom pred mergom.
- **Slepota:** každá verzia v samostatnej plytkej kópii repa (`git init` + `fetch --depth` jedného commitu) — bez neskorších commitov, opráv
  a zápisov v KRONIKE. Grok nálezy Codexu nevidel.
- **Vyhodnotenie:** vždy nový subagent (Opus), ktorý spáruje nálezy (ZHODA / ČIASTOČNE / MINUL) a nálezy Groka navyše overí v kóde
  (PRAVDIVÝ / SPORNÝ / PLANÝ).
- **Kolo 1:** systémové pravidlá OCR (Ruby nemá vlastné — len všeobecný zoznam; `.md` OCR štandardne vynecháva), effort predvolený.
- **Kolo 2:** projektové pravidlá [ocr_rule_noxun.json](ocr_rule_noxun.json) (26 pravidiel podľa typu súboru, `.md` zapnuté, `tests/fixtures` vynechané)
  + `--effort high`. Pravidlá napísal subagent **len z dokumentácie** (bez KRONIKY, DOGFOODINGU a histórie PR). Verzia v repe je **po review #468
  spresnená** v 4 pravidlách (chýbajúci kľúč, čerstvá inštalácia zo seedov, `PR #?` pri otvorení PR, prázdny `model_guid` v zdokumentovaných
  cestách); aby sa zmestili do limitu ~2500 znakov, z troch pravidiel (výrobné výstupy, jadro, perzistencia) vypadlo aj zopár
  vedľajších kontrolných bodov — pôvodné znenie je v commite 3c3cbb2f. Kolo 2 bežalo s pôvodnou verziou; pôvodné pravidlo o `PR #?` vyrobilo oba plané nálezy.

## Výsledky

| | Kolo 1 (systémové pravidlá) | Kolo 2 (pravidlá Noxun + effort high) |
|---|---|---|
| nálezov Groka | 8 | 16 |
| zhody s Codexom (z 18) | 5 (28 %) | 5 + 1 čiastočne (28 / 33 %) |
| pravdivé nálezy navyše | 3 | 5 (+ 3 sporné) |
| plané poplachy | 0 | 2 (oba z chybného pravidla o `PR #?`) |
| presnosť (potvrdené / všetky) | 100 % | 69 % (88 %, ak sa potvrdia 3 sporné) |
| P1 v #465 | minul | minul |
| čas na PR | 2–30 min | 9–21 min |

- **Zjednotenie oboch kôl:** 7 z 18 (39 %). Kolá sa líšia aj na tých istých PR (kolo 2 jednu zhodu z kola 1 minulo a druhú chytilo len čiastočne) — výsledok jedného behu
  je teda dosť náhodný.
- **Podľa oblasti (kolo 2):** Ruby kód pluginu 1 z 5 · JS/UI 1 + 1 čiastočne z 5 · skripty `ui_foto` 0 zo 4 · dokumentácia 3 zo 4.
  12 zo 16 nálezov Groka bolo v dokumentácii.
- **Typ chýb, ktoré Grok míňa:** chybové a záložné cesty, súbežnosť (dve okná, dva behy v tej istej sekunde), dôsledky mimo zmenených riadkov,
  okrajové veľkosti (malá doska, dlhý názov).
- **Silné stránky:** nesúlad medzi STAV / PLAN / KRONIKA / architektúrou, vizuálne chyby s konkrétnym číselným scenárom. Pravdivý nález nad rámec
  Codexu v #465: WORKFLOW tvrdil, že effort sa pri volaní subagenta nedá nastaviť — nástroj ho od v2.1.292 má.

Plné párovania s odôvodnením: [KOLO1_parovanie.md](KOLO1_parovanie.md), [KOLO2_parovanie.md](KOLO2_parovanie.md).

## Výhrady

- Malá vzorka (10 PR, 18 nálezov); Codex ako referencia nie je úplná pravda (Grok našiel aj veci, ktoré Codex nemal).
- Pravidlá kola 2 vychádzajú zo **súčasnej** dokumentácie, ktorá už obsahuje poučenia z neskorších opráv — kolo 2 môže byť mierne optimistické.
- Hodnotiteľ je Claude; Codex aj Grok sú iní dodávatelia, takže hodnotiteľ nie je stranou ani jedného.

## Technické poznámky

- Windows: zadanie dlhšie ako ~32 kB padne v `grok-bridge` na `spawn ENAMETOOLONG` → vstupy OCR dať do súboru v kópii repa a v zadaní len odkaz.
- OCR štandardne vylučuje `.md` a `tests/fixtures/**`; `.rb`, `.js`, `.ps1`, `.html`, `.css` kontroluje. Ruby nemá vlastné systémové pravidlo.
- Výstup Groka pred JSON obsahuje krátky text — parsovať od `{"findings"`.

## Možné využitie (návrh, nerozhodnuté)

1. **Doplnkový kontrolór** dokumentačných a workflow PR popri GH Codex review (nie namiesto neho) — zachytí nesúlady dokumentov, ktoré Codex prehliada.
2. **Náhrada GH kola len pri čisto dokumentačných PR** — až po ďalšom teste na 3–4 docs PR; P1 v #465 však minul práve v dokumentácii.
3. Pri kódových PR **nie** — pri ~30 % záchyte by väčšina P2 prešla do mainu.
