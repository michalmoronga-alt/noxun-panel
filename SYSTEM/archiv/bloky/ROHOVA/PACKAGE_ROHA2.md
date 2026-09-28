# Package ROH-A2 · vkladanie a náhľad rohovej skrinky (K3)

> **Blok 8 · K3 ROHOVÁ SKRINKA**, druhá kódová dávka. **Package v1** (28.9.2026 ~02:35, paralelná príprava počas A1). Štartuje z čerstvého `main`
> **po mergi ROH-A1** — ak A1 zmení niečo, na čom A2 stojí (názvy polí, `front_opening`, `DEFAULTS`), orchestrátor package pred štartom zladí.
> Podklady: [ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md) (R6, R7, R8), package ROH-A1 (kontrakt typu `corner_blind`),
> [FAKTY_Z_KODU_2026-09-27.md](FAKTY_Z_KODU_2026-09-27.md) §3.1, §8–§9, krížový audit Codex Q7 (zoznam JS čitateľov šírky) a C8 (značky pántov).
> **Trieda:** UI + akcia panela zapisujúca do modelu (vkladanie) → **in-SU brána**; **nový ovládací prvok v UI** (tlačidlo typu) → **predrecenzia povinná**;
> kontrakt, schéma ani observer sa nemenia → `codex-audit` **nie je povinný** · GH Codex review. Verzia → **v0.14.2**.

## Cieľ (z pohľadu stolára)

- Vo vkladacej karte je tlačidlo **„Rohová"** (Dolná · Horná · **Rohová** · Umývačka · Doska) — klik, ghost, klik = rohová skrinka s predvolenými rozmermi
  (šírka 1100, dverová časť 450, CR 80/80, dvere vľavo, pánty pri rohu) ako **jeden krok Späť**. Šablóny typu „Rohová" sa ponúkajú len pri nej.
- **Náhľad v Inspectore nekreslí klamstvo:** dvere sú v dverovej časti (nie cez celú šírku), značky pántov na strane podľa smeru (pri rohu), kóty a medzery
  sedia; slepá časť ostáva bez čela (kresba CR lišiet a blendy príde s ROH-B podľa mockupu).
- Náhľad nôh vo vkladacej karte funguje aj pre rohovú; modal „Uložiť ako šablónu" ukáže typ rohovej zamknutý (ako pri slote).
- Po A2 sa dá rohová **naozaj použiť** (R8 splnené) — Michalov smoke nižšie.

## Scope IN

1. **Vkladacia karta** (`panel.html:190–195`, `form.js onInsertType :892–899`): tlačidlo + **ikona** (inline SVG v sprite, štýl ostatných; jednoduchá: skrinka
   s dverami vľavo a lištou „L" pri rohu), `aria-pressed`, tooltip „Rohová — dolná slepá rohová skrinka s CR lištou (dvere v dverovej časti)".
   Rad ostáva **jeden** (pravidlo vertikálneho priestoru). `applyVisibility` pri vkladaní rohovej = ako dolná (polia rohovej sa vo vkladaní nezobrazujú — ROH-B/mockup).
2. **Predvoľby vkladania** zo servera `DEFAULTS` (`sync.rb:40–46`, `CORNER_DEFAULTS` z A1) — insert pošle typ `corner_blind` a konštrukciu ako dolná;
   polia rohovej doplní server predvoľbami (JS ich neposiela — A1 C6).
3. **Šablóny:** filter ponuky podľa typu (`insert_state.js templatesForType`) — rohová šablóna len pri „Rohová"; vloženie rohovej šablóny = nová skrinka
   so stranou zo šablóny (A1 to na serveri dovoľuje). Modal „Uložiť ako šablónu" (`form.js:1479–1490`, `tplSaveType`): pri rohovej zamknutý typ
   „Rohová" (vzor slotu) — server už typ nepreklopí (A1).
4. **Náhľad čiel s otvorom** (Codex Q7, fakty §3.1): **serverovú časť už robí ROH-A1** (audit A1 NOTE 5 — preflight počíta otvor pre každý typ cez
   `Construction.front_opening`, pri rohovej z uloženého configu a živej šírky); A2 ju **použije v JS** (`form.js:404–420` — odpoveď preflightu pre
   **aktuálnu revíziu**, živá zmena šírky pravej rohovej posúva `x0 = W − D`). **Stav mainu po A1 (overené 28.9. ~02:00, `442008ed`):**
   `front_preflight_result` (`actions_cabinet.rb:48–98`) otvor **počíta** (`Construction.front_opening(preflight_opening_cfg(...))`), ale **nevracia** ho —
   odpoveď nesie len `valid/items/errors/slots`. A2 doplní do odpovede **`opening` `{x0, w, z0, h}` pre každý typ** (slot vlastný) a JS ho použije; pri
   **vkladaní** (bez uloženého configu) berie `corner_preflight_src` polia rohovej z payloadu — A2 ich teda pri vkladaní rohovej pošle (predvoľby
   `CORNER_DEFAULTS` zo `sync.rb DEFAULTS`, v DOM nie sú). JS čitatelia plnej šírky: `preview.js:79` (rozsah), `:125`
   (vkladací rozsah), `:543` (plocha návrhu), `:885` (čelá a popisky), `:1072` (medzery a kóty), `:1138` (kovanie), `:1386` (ghost čiel), `nxFrontsResolve :445`,
   `nxFrontsExtent :132` — všetci **od otvoru** (`x0`, `w`); pri ostatných typoch otvor = celá šírka → **bez zmeny** správania (JS test parity).
5. **Značky pántov podľa smeru** (C8, `preview.js:1184`, dáta `payloads.rb:935` / `front_slots`): kresliť na strane zo smeru; pri `unset` stranu nehádať
   (symbol „?" ako dnes v `direction_check`); legacy bez kľúča = nič. Platí pre všetky typy (dnes `wing:single` vždy vľavo — oprava aj pre dolnú).
6. **Náhľad nôh** vo vkladacej karte aj pre rohovú (`hardware.js:2458` dnes zahodí iný typ než `lower`).
7. **Ghost:** obálka ostáva nominálna `[0..W] × [0..d] × [0..h]` (CR 2 a rohová výstuha pred ňou — R9, bez zmeny); `home_z` 0.

## Scope OUT

Riadky Inspectora (dverová časť, CR, strana), prepínač strany, kresba CR lišiet a blendy v náhľade, skrytie ovládačov štruktúry čiel a delenia zón —
**ROH-B** podľa mockupu. Zmeny kontraktu/geometrie — nie (A1).

## Testy a DoD

- **JS** `tests/js/test_roha2_vkladanie.js`: typ „Rohová" vo vkladacej karte (stav, `aria-pressed`, filter šablón), náhľad čiel od otvoru (dolná bez zmeny —
  parita čísel; rohová vľavo/vpravo: dvere 2–448 / 652–1098 pri W 1100), značky pántov podľa smeru (`left`/`right`/`unset`/legacy), preflight odpoveď
  s otvorom pre aktuálnu šírku, náhľad nôh pre rohovú. Každú JS sadu zvlášť.
- **Headless**: preflight otvoru pre všetky typy (`actions_cabinet`), `DEFAULTS` rohovej v `sync`, guard `?v=`.
- **In-SU** `run_roha2`: vloženie rohovej cez cestu panela (typ z karty, predvoľby) = 1 krok Späť, config = `CORNER_DEFAULTS`, geometria plán ↔ model;
  vloženie rohovej šablóny pravej strany; preflight s živou šírkou. Runner `-CloseWhenDone`.
- Screenshoty panela (vkladacia karta s „Rohová", náhľad rohovej vľavo/vpravo) do PR — cez `view.write_image` alebo HtmlDialog screenshot v in-SU behu, ak to runner vie; inak popis.

## Smoke pre Michala (po A2)

1. Vkladacia karta → **Rohová** → ghost → klik: skrinka 1100 so dverami vľavo, pred skrinkou **CR lišta do tvaru L** (trčí ~10 cm dopredu), Ctrl+Z ju odstráni jedným krokom.
2. Inspector: typ „Rohová", náhľad ukazuje dvere len vľavo (450), pánty na strane pri rohu; kusovník/Štúdio: blenda, výstuha závesov, rohová výstuha, CR 1, CR 2.
3. VEPO export: nové riadky s krátkymi názvami (≤ 20 znakov), CR z čelového materiálu s ABS dookola; Nákup kovania: 2 závesy, 6 nôh.
4. Zmeň šírku na 1200 (Inspector aj ťahaním) — rastie len slepá časť, dvere a CR ostanú. Zmeň smer dverí na vonkajší bok — ide.
5. Skús pridať zásuvku / priečku v rohovej — plugin odmietne s vetou.
6. Pri prvej rohovej v dielni: záves na výstuhe závesov, dvere sa otvoria bez dotyku CR 1.

## Checklist uzáveru

Bump v0.14.2 + `?v=` → testy (headless, JS, in-SU) → `ui-lifecycle.md` (vkladacia karta, náhľad s otvorom, značky pántov) + `docs/UI_DIZAJN.md` (tlačidlo typu)
→ STAV/KRONIKA/PLAN (riadok ROH-A2 ✅ `PR #?`) → číslo PR samostatným commitom. Package do `SYSTEM/zdroje/bloky/ROHOVA/`.
