# Externý audit — kolo 0 (Michalov Codex audit, dodaný 26.8.2026)

> Vrstva `zdroje/` — podklad, nie autorita. Vznikol PRED cieleným podkladom [AUDIT_2026-08_podklad.md](AUDIT_2026-08_podklad.md)
> (Michal ho mal vypracovaný vopred, je všeobecnejší). **Toto kolo 0 NIE JE jeden z troch pohľadov bloku 1c** —
> je to predbežný vstup do registra. Všetci traja audítori 1c (externý Codex · Fable · slepý subagent) bežia
> až s jednotným podkladom; externý Codex sa teda spustí ZNOVA s briefom. Posúdenie užitočnosti (Fable, 26.8.) je v závere.

## Kandidáti na refactor/hardening (verbatim)

| Priorita | Súbory | Odporúčanie |
|---|---|---|
| P0 | `ui/js/studio_settings.js` · `ui/supplier_settings_dialog.rb` | Najprv opraviť už zdokumentovaný zastaraný pin a nepravdivý status prepočtu. Ide o možnú stratu rozpísanej práce, nie iba technický dlh. |
| P0 | `ui/production_core.rb:447` · `ui/studio_dialog.rb:1272` | Oddeliť čistý read-only snapshot od opravy duplicitných identít. Dnes môže obyčajné „Obnoviť" opraviť ID a vytvoriť Undo operáciu. Pre budúcu kontrolu musí byť jasné, kedy sa iba číta a kedy sa model opravuje. |
| P0 | `core/scale_observer.rb:180` · `core/cabinet_builder.rb:250` · `board_builder.rb` | Hardening observer/Undo/multi-model lifecycle. Nie veľký prepis; najprv charakterizačné in-SU scenáre pre copy, *N, Undo/Redo, prepnutie modelu a prerušenie operácie. |
| P1 | `ui/studio_dialog.rb:1272` · `ui/js/studio.js` · `ui/production_core.rb` | Štúdio dnes pri jednom pushi skladá všetkých 12 sekcií. Zaviesť samostatných poskytovateľov sekcií, cache a izoláciu zlyhania. |
| P1 | `core/cabinet_builder.rb:107` · `ui/panel/actions_cabinet.rb:286` | Builder má v jednom súbore normalizáciu, migrácie, materiály, ABS, kovanie, geometriu, kopírovanie aj vloženie. Rozdeliť po existujúcich zodpovednostiach bez zmeny verejného správania. |
| P1 | `hardware_sets.rb` · `hardware_rules.rb` · `hardware_catalog.rb` | Pred Kovaním fáza 3 oddeliť knižnicu, projektový snapshot, vyhodnocovanie pravidiel, nákupný rozpis a vysvetlenie výsledku. |
| P1 | `materials_decor.rb` · `materials.rb` · `proj_materials.js` | Veľké a často menené súbory. Refactor až po PICKER dávkach: samostatne identita skupiny, transakčný editor, tvorba variantov a appearance vrstva. |
| P1 | `tests/sketchup/su_runner.rb` | 9 009 riadkov v jednom runneri. Rozdeliť scenáre podľa domén, aby sa nový observer/Tool test dal bezpečne dopĺňať. |
| P2 | `budget.rb` · `budget_store.rb` · `cp_export.rb` · `xlsx_writer.rb` · `price_refresh.rb` · `budget.js` | Pred DOCX/PDF vytvoriť jeden neutrálny model ponuky; XLSX, DOCX a PDF majú byť iba rôzne renderery rovnakých dát. |
| P2 | `json_file_store.rb` + všetky katalógy | Pred zdieľanou knižnicou doplniť jednotný transakčný/CAS kontrakt, integritu balíka, rollback a konflikt dvoch PC. |

## Súbory dôležité pre budúce témy (verbatim, skrátené)

- **Ghost:** `placement.rb` netreba refaktorovať (28 riadkov, ostáva fallback); potrebná nová samostatná Tool/PlacementSession vrstva a predtým rozdeliť `handle_insert` na prípravu a commit. Dotknuté: `actions_cabinet.rb`, `cabinet_builder.rb`, `insert_state.js`, `selection.rb`, `scale_observer.rb`.
- **D-95 kontrola:** `edge_check.rb`, `grain_check.rb`, `edge_overlay.rb`, `validation.rb`, `production_core.rb`, `studio_dialog.rb`, `studio.js`, `selection.rb`. Najprv garantovať, že zapnutie/vypnutie kontroly nemení model ani Undo.
- **Zostavy:** STANDARD, `ids.rb`, `part_keys.rb`, `store.rb`, `build_plan.rb`, oba buildery, `zones.rb`, `zone_tree.rb`, `templates.rb`, `bom.rb`, `validation.rb`, `scale_observer.rb` — najrizikovejšia budúca téma; vyžaduje nový dátový kontrakt, nie iba ďalšie pole.
- **Kovanie fáza 3:** `hardware_rules.rb`, `hardware_sets.rb`, `hardware_catalog.rb`, `build_plan.rb`, `cabinet_builder.rb`, `templates.rb`, `bom.rb`, `budget.rb`, `production_core.rb`.
- **Shared library/updater:** `json_file_store.rb`, všetky katalógy, `templates.rb`, `supplier_settings.rb`, `main.rb` a loader. Najprv persistence kontrakt, až potom sync UI.
- **Render:** `materials.rb`, `materials_decor.rb`, oba buildery, `part_faces.rb`, `templates.rb`, `proj_materials.js`. Najprv oddeliť výrobný materiál od appearance.
- **Spotrebiče:** nový doménový modul; napojenie na templates, zones, build_plan, validation, budget, cp_export a Štúdio.
- **Ponuka/DOCX/PDF:** budget, cp_export, xlsx_writer, price_refresh, production_core, budget.js.

Odporúčané poradie dávok (verbatim): docs cleanup → P0 nastavenia + post-hoc sweep #186–#226 → oddelenie čistého
snapshotu od opravy identít → observer/Undo hardening → rozdelenie insert prepare/commit a builder hraníc →
fresh audit Ghostu → doménové refactory vždy tesne pred témou, ktorá ich potrebuje. Žiadny „refactor všetkého";
malé dávky: charakterizačné testy → presun zodpovednosti bez zmeny správania → až potom nová funkcia.

## Posúdenie (Fable, 26.8.2026)

**Užitočné a preberá sa:**
- **Tri P0 nálezy idú rovno do bloku 1b** (nečakajú na 1c): (1) zastaraný pin/nepravdivý status v nastaveniach — kandidát na stratu rozpísanej práce, treba najprv overiť proti v0.8.5; (2) „Obnoviť" vie opraviť duplicitné ID a vyrobiť Undo krok — oddeliť čítanie od opravy; (3) observer/Undo charakterizačné in-SU scenáre PRED akýmkoľvek zásahom — presne prístup blokov 1c/1d.
- **P1/P2 tabuľka + mapa súborov per téma** = hotový vstup do registra 1c (R-čísla sa z nej založia) a do plánovacej dávky 1e (závislosti packages).
- **Metodika** („charakterizačné testy → presun bez zmeny správania → až potom funkcia", žiadny big-bang) sa zhoduje s blokmi 1c–1e — potvrdená dvomi nezávislými pohľadmi.
- **`su_runner.rb` 9 009 riadkov** — dobrý úlovok, ktorý náš podklad nemal; zaradené do osí 1c (test infra).

**Zastarané / neaktuálne (nepreberá sa):**
- Sekcia „Audit PR #210" — PR je od 26.8. zmergovaný a dávka Docs cleanup B doplnila statusové hlavičky konceptov („Stav: KONCEPT · auditované proti kódu: zatiaľ nie"); zvyšné navrhované metadáta (canonical_plan_item, expirácia) zváži plánovacia dávka 1e.
- „Poradie musí potvrdiť Michal (stabilizácia → Kovanie)" — potvrdené a zapísané inak: PLAN drží 1b → 1c → 1d → 1e → **GHOST** → KOVANIE (Michal 26.8.); fresh audit Ghostu je v PLANe povinný.
- Rozpor D-95 konceptu s „diel po diele" režimom v PLAN/DOGFOODING — platný postreh, rieši ho plánovacia dávka 1e pri tvorbe task package pre D-95 (koncept je podklad, nie autorita).
