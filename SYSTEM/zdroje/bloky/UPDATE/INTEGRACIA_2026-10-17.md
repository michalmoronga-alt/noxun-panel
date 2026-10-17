# Blok UPDATE — integračné zladenie packages po delta audite (17.10.2026)

> **Vstup:** [AUDIT_DELTA_raw.md](AUDIT_DELTA_raw.md) (Codex `gpt-6.1-sol`, verdikt „zatiaľ nie do zásoby"). **Výstup:** body „Integračné zladenie (delta 17.10.)" v §15 každého package
> (U1 §15.1 · U2 §15.11 · U3 §15.1 · U4 §15.7 · U5 §15.1) + opravy dotknutých miest v §6/§7 a tabuliek API. Rozhodnutia R1–R21 a O1–O9 sa nemenia, nová funkcia nepribúda.
> **Autorita mien a signatúr API** = PACKAGE_U2 **R4.8** (tabuľka) a PACKAGE_U3 R-I/R-J/R-N; U4 a U5 ich len citujú.
> **Stav položky:** „zapracované" = požiadavka a pomenovaný regresný test sú v package; dôkaz prinesie až implementácia. Na potvrdenie odporúčaná krátka delta verifikácia nad týmito bodmi.

## A — nálezy CIASTOCNE (regresný test, pri U2/6 a U4/4 aj vecné doplnenie)

| Položka delty | Package · miesto | Test (súbor · názov) | Stav |
|---|---|---|---|
| U1/2 F `merge_18_36` | U1 §15.1, T9b v §7 | `test_u1_nazov_zakazky.rb` · `test_t9b_expect_check_merge_18_36` (4 druhy exportu + VEPO nesúlad 18 + 36) | zapracované |
| U2/6 F leases / ďalší proces počas snímku | U2 §15.11 „A U2/6" (leases pred **každým** zápisom a pred koncom snímku; export píše žurnál `exporting` pred usadením, poradie žurnál → leases; druhý proces blokovaný `pending_block`) | `test_u2_transfer.rb` · `test_u2_6_lease_before_each_write`, `test_u2_6_lease_at_snapshot_end`, `test_u2_6_second_process_during_export`, `test_u2_6_dead_export_journal` | zapracované |
| U3/1 B výber skupín na odoslanie | U3 R-H1, §15.1 | `test_u3b_library_sync.rb` · `test_publish_selects_edited_group_despite_entry`, `test_publish_after_plugin_bump_selects_all` | zapracované |
| U3/2 B úprava pred aktualizáciou pluginu | U3 R-F3, §15.1 | `test_u3a_library_sync.rb` · `test_edit_before_plugin_update_stays_local_changes` | zapracované |
| U3/3 B opačné poradie tiketov | U3 R-J2, §15.1 | `test_stale_ticket_reverse_commit_order` (U3b), `test_disk_behind_no_take` (U3a) | zapracované |
| U3/4 F konflikt správcov po lehote T | U3 R-C3/R-C4, §15.1 | `test_late_admin_conflict_after_T` (U3b) | zapracované |
| U3/5 F `:unknown` z `peek_group` v U3 | U3 R-F1, R-J2, R-N1, §15.1 | `test_status_and_diff_with_peek_unknown`, `test_diff_used_tristate` (U3a) | zapracované |
| U3/6 F odmietnutie distribúcie R18 | U3 R-G2, §15.1 | `test_r18_distribution_gate` (U3a) | zapracované |
| U3/7 F zaseknutý precheck | U3 R-G2, R-E2, §15.1 | `test_precheck_hang_does_not_block` (U3b) | zapracované |
| U3/8 F pád po U2 pred stavom U3 | U3 R-J5, §15.1 | `test_recover_done_before_state_write` (U3b; varianty a/b/c) | zapracované |
| U3/9 F oneskorený ukazovateľ | U3 R-H7, §15.1 | `test_sweep_keeps_folder_awaiting_pointer` (U3b) | zapracované |
| U4/1 B `replacements:` z U3 | U3 R-J3 (+ R-I), U4 §15.7, U2 R4.8 | U3 `test_take_passes_replacements_to_u2`, `test_attachment_conflict_stops_group`; U4 `test_u4_1_replacements_reach_journal` | zapracované |
| U4/4 F prvé doplnenie digestu | U4 §15.7 C3 (nahrádza vetu v 15.4), U3 R-B1 | `test_u4_prilohy.rb` · `test_c3_first_digest_fill_is_conservative` | zapracované |
| U5/1 B obnova bez odtlačku | U5 R-J1, §15.1 | `test_u5a_library_ui.rb` · `test_restore_backup_passes_seen_fingerprint`, `test_restore_backup_changed_after_preview`, `test_restore_backup_impact_window` | zapracované |
| U5/3 F väzba plánu na zákazku | U5 R-C2, §15.1 | `test_plan_rebuilt_when_model_switched`, `test_plan_rebuilt_when_usage_changed` | zapracované |
| U5/4 F `:unknown` použitie | U5 R-D3, R-C2; U3 R-N1 | `test_used_unknown_visible_materials_and_appliances` (U5), `test_diff_used_tristate` (U3) | zapracované |
| U5/7 F ručné vyriešenie správcov | U5 R-F3, §15.1; U3 R-C5 | `test_resolve_admin_from_menu` | zapracované |

## B — nesúlady rozhraní (jedno meno, jedna signatúra)

| Položka delty | Rozhodnutie zladenia | Miesta | Stav |
|---|---|---|---|
| U2 R4.8 bez `library_members(g)`, `pending_block` | R4.8 prepísaná na tabuľku — doplnené `library_members`, `pending_block(entry_key = nil)`, čítače `last_recovery`, `pending_issue`, výsledky `recover_pending!` | U2 R4.8, §15.11; U3 R-I | zapracované |
| `with_store_lock(entry_key)` vs `row` | jediný tvar **`with_store_lock(entry_key)`**; pre prílohu `entry_key = LibraryAttachments.row_for(rel)` | U2 R4.4, 15.9 (3); U3 R-I, R-M1; U4 R4.1, 15.1, 15.7 | zapracované |
| U3 R-J3/R-I bez `replacements:` | `import_group!(g, packet, plugins_dir:, reason:, tag: nil, replacements: [])`; U3 zbiera položky z `place` | U2 R4.8; U3 R-I, R-J3; U4 15.7 | zapracované |
| tvar `decisions[g]` | jediný tvar **`{action: :take \| :overwrite \| :skip, seen_fingerprint: String}`**; U5 server ho skladá (klient posiela len akciu, `seen_fingerprint` drží server pri tikete) | U3 R-J2; U4 15.2; U5 R-C2, R-C5, R-J3 | zapracované |
| U5 R-J1 `restore_backup!` bez `seen_fingerprint:` | volanie vždy s `seen_fingerprint:` z `diff_documents(…, attachment_rels:)` | U5 R-J1; U3 R-K, R-N3 | zapracované |
| `:unknown` použitie vs `.include?` | `used_ids` = `{entry_key => Hash{id => [kde]} \| :unknown}`; `used` ∈ `true/false` · `:unknown` · `nil` (zámerne neoverené); bez `.include?` | U3 R-N1; U5 R-D3, R-C2 | zapracované |
| `diff: :unknown` bez vetvy v U5 R-C2 | jediný tvar výsledku `diff` (`'documents' => Hash \| :unknown`, `price_changed`, `seen_fingerprint`, `attachment_conflicts`); U5 vetva `'diff' => 'unknown'` = skupina ako s lokálnymi zmenami + veta R17 | U3 R-N1; U5 R-C1, R-C2 | zapracované |
| U5 R-N „ponechané tvoje" vs U4 §15.2 | prevzatá skupina konflikt nehlási; konflikt = výsledok skupiny **`attachment_conflict`** (neprevzatá); počty príloh sa neukazujú | U5 R-N; U4 R4.3, 15.7; U3 R-J4 | zapracované |

## C — nové BLOCKERy

| Položka delty | Požiadavka | Test | Stav |
|---|---|---|---|
| C1 obnova zálohy bez archivovaných príloh | `restore_backup!(A)` vráti aj prílohy z `library_backups/<A>/attachments/` cez `place(…, resolve: :force)` v tej istej transakcii (žurnál, `rollback!`); nahradené súčasné súbory idú do novej zálohy B; záloha A ostáva celá | U2 `test_c1_restore_returns_archived_attachments`; U4 `test_c1_restore_backup_returns_attachment` | zapracované (U2 §15.11 C1, U4 §15.7 C1) |
| C2 potvrdenie nechráni prílohy | `local_fingerprint(g, attachment_rels:)` zahŕňa prílohy, ktoré rozhodnutie smie prepísať (prevzatie a Vrátiť verziu: `local` cesty príloh z manifestu tiketu; návrat zálohy: `backup_peek['attachment_rels']`) | U2 `test_c2_seen_fingerprint_covers_attachments`; U3 `test_seen_fingerprint_includes_ticket_attachments` | zapracované (U2 §15.10/15.11, U3 R-J2/R-N1) |
| C3 prvé doplnenie digestu = neoverený základ | chýbajúci `local_replace_digest` → `local_changes` + varovanie R4, ak existuje lokálny náhľad, ktorý by sa prepísal; doplní sa len po úspešnom prevzatí; R-F3 ani `:skip` ho nedopĺňajú | U4 `test_c3_first_digest_fill_is_conservative` | zapracované (U4 §15.7 C3, U3 R-B1) |

## Čo ostáva otvorené (mimo delty)

- **R0 sondy** — U3 §16 (Google Disk na oboch PC) a U4 §16 (inventár príloh, dĺžka ciest) ešte neprebehli; packages U3 a U4 sú do ich výsledku **nezmrazené** (nezmenené).
- **Poistka U2b** sa zdvíha z ~550 na ~620 riadkov (U2 §15.11 „Rez") — rozhodne orchestrátor pri štarte U2b.

## Odhad kódu pluginu po zladení

| Dávka | Pred deltou | Po zladení | Poistka |
|---|---|---|---|
| U1 | ~110–150 novej logiky (diff +300/−400) | bez zmeny (len text testu) | ~800 diff |
| U2a | ~320 | ~320 | — |
| U2b | ~530 | **~575** | ~620 (zdvihnutá) |
| U2c | ~300 | ~300 | — |
| U3a | ~540 | **~555** | ~650 |
| U3b | ~520 | **~550** | ~650 |
| U4 | ~360 | **~385** | ~400 |
| U5a | ~720 | **~735** | ~780 |
| U5b | ~470 | ~470 | — |
