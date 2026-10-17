# Blok PRAVIDLA — zadanie od Michala (17.10.2026)

> Zápis z orchestračnej debaty (session „project-feedback-evaluation", 17.10.2026). Počas bloku autorita pre rozsah; technické riešenie
> patrí do packages po inventúre. Rešerš: [RESERS_POROVNANIE.md](RESERS_POROVNANIE.md).

## Prečo

Dokumentácia je vedená dobre, problém je **udržiavanie a rast**: pravidlá sa dopisujú, nič sa nezlučuje ani neruší, súbory „pretekajú"
(CLAUDE.md 35 kB pri každej správe každej roly), malé pravidlá zapadnú. Michal: „chvíľkovo to fungovalo super, ale v poslednom čase je to
nejaké zmätené." Dôkaz: retro záznamy sa od 2.10.2026 prestali písať, vyhodnotenie k 11.10. sa neurobilo.

## Čo Michal chce

1. **Univerzálne pravidlá — `AGENTS.md`**, nie CLAUDE.md; odkazovať sa má na AGENTS.md (CLAUDE.md len ako most, viď rešerš Z2).
2. **Každá rola má jasné vlastné pravidlá** — orchestrátor, implementátor, slepý recenzent, audítor, rešeršér, review PR; rola nedostáva
   pravidlá, ktoré pre ňu neplatia.
3. **Ekonomickejšie a presnejšie** — menej kontextu na správu, načítanie podľa miesta, roly a úlohy; ochrana proti opätovnému „pretekaniu".
4. **Bezpečné** — hooky a inštrukčné súbory ako kód s review, žiadne tajomstvá v pravidlách.
5. **Retro sa nesmie strácať** — automatická pripomienka (návrh: hook po `gh pr merge` → „zhodnoť, ako sa pracovalo"), zápis povinný
   (aj „bez postrehov"), vyhodnotenie naviazané na uzáver bloku, nie na dátum. Pokus 27.9.–11.10. sa vyhodnotí v rámci bloku
   (inbox: 7 záznamov 27.9.–2.10., hlavný checkout `SYSTEM/retro/inbox/`).
6. **Hodnotenie modelov po úlohách + model ROUTER** (Michal 17.10.):
   - orchestrátor po dokončení úlohy, ktorú delegoval, zapíše **drobné hodnotenie modelu** (ako dopadol, na čo sa hodí, pasce);
   - orchestrátor má mať **aktuálne info o modeloch, ktoré spúšťa** — hodnotenia, výstupy, schopnosti; príklady formy poznatku:
     „Grok 4.7 — schopný na rešerš a implementáciu, na audity nie je vhodný; RUBY interný bench 7/10, vhodný na stredne náročné úlohy",
     „Astra minula celý 5h limit za ~5 min pri komplexnej rešerši — pozor";
   - cieľ: niečo ako **model ROUTER**, ktorý z týchto dát odporúča, koho na čo spustiť.
   - **Existuje:** koncept routera v repe `noxun-mods` (`router/NAVRH.md`, 6.10.2026, čaká na Michala), benchmark
     `noxun-mods/benchmark/` (`behy.jsonl`, `vysledky/U001–U003`) a v `docs/PLAN.md` nápad „Karta modelu". Blok nadviaže, nevymýšľa nanovo.

## Drobnosti zaradiť do novej štruktúry (z retro inboxu)

- skript na spustenie všetkých JS testov jedným príkazom (izolácia worktree odmieta zložené príkazy — 5 záznamov),
- runner in-SU testov si vezme `_dev\ENGINEtests.skp` z hlavného checkoutu, keď vo worktree chýba (4 záznamy).

## Postup (dohodnutý)

0. ✅ rešerš (Grok + Codex SOL; agy zlyhal) — [RESERS_POROVNANIE.md](RESERS_POROVNANIE.md)
1. ✅ (18.10.) sonda na lokálnom Claude Code (docs pre 2.1.299) + **inventúra pravidiel** + prieskum 18 sessions lacným modelom
   ([PRIESKUM_SESSIONS.md](PRIESKUM_SESSIONS.md)) — spracované v [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md)
2. návrh štruktúry → schvaľuje Michal (ako mockup) — **[NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md), čaká na schválenie a odpovede § 9**
3. prepis po dávkach (jadro AGENTS.md → roly → miesta → hooky a stropy veľkosti → retro a karty modelov)

## Otvorené otázky (odpovie Michal v novej session)

- **Kde žijú karty modelov** — v `noxun-mods` (spoločné pre všetky projekty, návrh orchestrátora) alebo v ENGINE?
- **Stupnica hodnotenia** — benchmark má 1–5 od slepého recenzenta; Michalov príklad je „7/10". Zjednotiť na jednu.
- **Nie-slepé hodnotenie orchestrátora** (drobné, po každej úlohe) vs. **slepý benchmark** (občas) — ako ich vážiť v karte modelu.
