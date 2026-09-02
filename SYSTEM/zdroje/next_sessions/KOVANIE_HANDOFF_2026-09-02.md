# KOVANIE — ODOVZDÁVKA 2.9.2026 (koniec MAX plánu / Fable → Opus + Codex)

> Stav: KONCEPT / odovzdávka — vstupný bod pre pokračovanie bez Fable; autorita architektúry = KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md, autorita dávok = packages v SYSTEM/PLAN.md.

**Kontext:** 2.9.2026 večer končí Michalov MAX plán → Fable končí; pokračuje **Opus (orchestrátor + implementátori) + Codex (audit/review)**. Michal Fable možno kúpi znova po V1 na veľké rozhodnutia. Tento súbor = jediný vstupný bod pre pokračovanie.

**Stav main (2.9. večer):** `2fd6aac` docs; plugin v0.9.4 (PR #277 bumpuje na 0.9.5). Headless 2280/0, JS 78/78 (na #277 vetve 2310).

**Blok KOVANIE — kompletne naplánovaný, implementácia začala:**
- Autorita architektúry: `SYSTEM/zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md` (po cross-audite Codex/GLM/Opus + reconcile + O1–O3). UX: `SYSTEM/zdroje/ui20/mockup_kovanie_v1.html` (schválený). Dáta: checkpoint #10 (vendor matica), #11 (detail fill: ABS zásuviek, UNI 16 default, H70=105), #12 (sonda kit vs atomic: 93 % K-sady, tabuľka Démos kódov). Packages v `SYSTEM/PLAN.md` blok KOVANIE: KOV-A, KOV-B, KOV-H (+ C/D/E/F/G/I podľa stavu PLANu — viď KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md).
- **Poradie:** 0 (D-52 updater) → A → B → H → C → D → E → F → G → I. D-52 je TVRDÝ predpoklad pred prvým schema bumpom (obe PC rovnaká verzia).

**HOTOVÉ: PR #277 D-52a (jadro updatera) ZMERGOVANÝ 3.9. skoro ráno — main v0.9.9 (`d2ecb3f`).** 4 GH Codex kolá + slepá delta-verifikácia (CLEAN, 3× P3 → do D-52b package), CI zelené, merge s pripnutou hlavou `40952db`. Dve vedomé odchýlky od pravidla 3 kôl zapísané v KRONIKE. Uzáver dávky hotový (KRONIKA/STAV/PLAN).
- **BEŽÍ (spustené Fable 3.9. skoro ráno): D-52b — UI updatera** — Opus subagent vo worktree, vetva `feat/d52b-updater-ui`, package v PLAN.md (D-52b). **Ďalší krok pre Opus, ak Fable nedokončil:** `gh pr list --head feat/d52b-updater-ui` — ak PR existuje → skill `codex-po-pr` (prvé kolo automatické; P1 → oprava + `@codex review`; pravidlo 3 kôl; merge s `--match-head-commit`); ak PR neexistuje a vetva má commity → dokončiť podľa package a otvoriť PR; ak vetva neexistuje → spustiť D-52b nanovo podľa package. In-SU sekciu `run_d52b` spustiť cez `scripts\run_su_tests.ps1` pred merge (bariéra okien sa headless nedá overiť). Po D-52b: D-52 uzáver (DOGFOODING_vyriesene plný text) → **KOV-A**.
- (pôvodne) **D-52b** (UI updatera: About v Štúdiu, async `updater_check` s deadline, bariéra zatvorenia okien pred swapom, natívne hlášky, in-SU smoke) — package v PLAN.md D-52 „REVÍZIA PO CODEX AUDITE", rez D-52b. Downgrade zakázaný (rozhodnutie 2.9., Michal môže vrátiť).

**Ako pokračovať bez Fable (rytmus, ktorý fungoval):** pre každú dávku: prečítať CLAUDE.md tabuľku povinného čítania → package v PLAN.md (autorita) + FINAL doc + mockup → `codex-audit` skill PRED implementáciou (kontrakt/schéma/migrácia/nový modul = povinné; KOV-A/B/C/D/H všetky áno) → implementácia Opus subagentom vo worktree (vetva `feat/…`, malé PR, testy headless+JS, in-SU pri builderoch) → `codex-po-pr` → merge → uzáver dávky (bump, docs odsek na mieste, STAV/KRONIKA/PLAN, DOGFOODING_vyriesene). Michal testuje večer podľa smoke checklistu v package.

**Otvorené pre Michala (nie blokery):** hmotnostné prahy závesov (tabuľka výrobcu — KOV-F), PDF follow-up z #10 (nie sú V1 blokery), Disk súbory `výpočet quadro V6 EB 23.xlsx` + StrongMax datasheety (pre KOV-C dáta). Súvisí: KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md, SYSTEM/STAV.md, skill codex-po-pr, CLAUDE.md Git workflow.

**Packages (všetky v SYSTEM/PLAN.md, 2.9. večer):** D-52 (+revízia po Codex audite, rez a/b) · KOV-A · KOV-B · KOV-H · KOV-C (C1/C2) · KOV-D · KOV-E · KOV-F · KOV-G · KOV-I. Dáta receptov: checkpoint #13. Pre-committed brána smeru: AUDIT_REGISTER R-39.
