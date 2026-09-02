# KOVANIE — ODOVZDÁVKA 2.9.2026 (koniec MAX plánu / Fable → Opus + Codex)

> Stav: KONCEPT / odovzdávka — vstupný bod pre pokračovanie bez Fable; autorita architektúry = KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md, autorita dávok = packages v SYSTEM/PLAN.md.

**Kontext:** 2.9.2026 večer končí Michalov MAX plán → Fable končí; pokračuje **Opus (orchestrátor + implementátori) + Codex (audit/review)**. Michal Fable možno kúpi znova po V1 na veľké rozhodnutia. Tento súbor = jediný vstupný bod pre pokračovanie.

**Stav main (2.9. večer):** `2fd6aac` docs; plugin v0.9.4 (PR #277 bumpuje na 0.9.5). Headless 2280/0, JS 78/78 (na #277 vetve 2310).

**Blok KOVANIE — kompletne naplánovaný, implementácia začala:**
- Autorita architektúry: `SYSTEM/zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md` (po cross-audite Codex/GLM/Opus + reconcile + O1–O3). UX: `SYSTEM/zdroje/ui20/mockup_kovanie_v1.html` (schválený). Dáta: checkpoint #10 (vendor matica), #11 (detail fill: ABS zásuviek, UNI 16 default, H70=105), #12 (sonda kit vs atomic: 93 % K-sady, tabuľka Démos kódov). Packages v `SYSTEM/PLAN.md` blok KOVANIE: KOV-A, KOV-B, KOV-H (+ C/D/E/F/G/I podľa stavu PLANu — viď KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md).
- **Poradie:** 0 (D-52 updater) → A → B → H → C → D → E → F → G → I. D-52 je TVRDÝ predpoklad pred prvým schema bumpom (obe PC rovnaká verzia).

**HOTOVÉ: D-52 KOMPLET (3.9.2026 ráno) — main v0.9.14 (`6214b1a`):** D-52a #277 (jadro) · D-52b1 #278 · D-52b2 #279 (UI + apply). In-SU 1297/0. Uzáver v KRONIKE/STAV/PLAN/DOGFOODING_vyriesene. Plugin v Plugins preinštalovaný z main (0.9.14). **ĎALEJ: KOV-A** (čelá — dátová vrstva; package v PLAN; codex-audit návrhu spustený 3.9. ako Codex task `task-mtjno9g8-jnkb0j` — výsledok: `node ~/.claude/plugins/cache/openai-codex/codex/1.0.5/scripts/codex-companion.mjs result task-mtjno9g8-jnkb0j`; potom implementácia Opus subagentom vo worktree; in-SU povinné; charakterizácia starých zákaziek = exit kritérium). Potom KOV-B ‖ KOV-H → C → D → E/F/G/I.

**Ako pokračovať bez Fable (rytmus, ktorý fungoval):** pre každú dávku: prečítať CLAUDE.md tabuľku povinného čítania → package v PLAN.md (autorita) + FINAL doc + mockup → `codex-audit` skill PRED implementáciou (kontrakt/schéma/migrácia/nový modul = povinné; KOV-A/B/C/D/H všetky áno) → implementácia Opus subagentom vo worktree (vetva `feat/…`, malé PR, testy headless+JS, in-SU pri builderoch) → `codex-po-pr` → merge → uzáver dávky (bump, docs odsek na mieste, STAV/KRONIKA/PLAN, DOGFOODING_vyriesene). Michal testuje večer podľa smoke checklistu v package.

**Otvorené pre Michala (nie blokery):** hmotnostné prahy závesov (tabuľka výrobcu — KOV-F), PDF follow-up z #10 (nie sú V1 blokery), Disk súbory `výpočet quadro V6 EB 23.xlsx` + StrongMax datasheety (pre KOV-C dáta). Súvisí: KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md, SYSTEM/STAV.md, skill codex-po-pr, CLAUDE.md Git workflow.

**Packages (všetky v SYSTEM/PLAN.md, 2.9. večer):** D-52 (+revízia po Codex audite, rez a/b) · KOV-A · KOV-B · KOV-H · KOV-C (C1/C2) · KOV-D · KOV-E · KOV-F · KOV-G · KOV-I. Dáta receptov: checkpoint #13. Pre-committed brána smeru: AUDIT_REGISTER R-39.
