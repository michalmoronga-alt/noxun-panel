# M-R VZHĽAD — outside-in a natívne overenie (11.9.2026)

> Stav: KONCEPT — rešeršný podklad a výsledky izolovaných sond; nenahrádza záväzný plán ani doklad o hotovej implementácii.

Podklad schváleného [MR balíka](MR_VZHLAD_PACKAGE_2026-09-11.md). Východisko main b41c4f8, SU 26.0.429 / Ruby 3.2.2. Dva samostatné research behy Antigravity Gemini 3.8 Flash High, následne overenie proti oficiálnemu API a izolovaným natívnym sondám. Toto je dôkaz vybraných API predpokladov, nie hotovej implementácie pluginu.

## Reconcile rešerše

| Nález | Rozhodnutie a dôkaz |
|---|---|
| Natívny `.skm` už nesie celý vzhľad. | PRIJATÉ: roundtrip zachoval textúru, fyzickú mierku, alfa, prefarbenie, zapnuté PBR vlastnosti, normal/AO aj metalness/roughness mapy. Nevytvárať vlastný PBR formát. |
| Materials.load vždy páruje len podľa mena. | ODMIETNUTÉ: výsledkom môže byť existujúci aj nový handle. Overovať identitu výsledku; neprepisovať naslepo jeho vlastnosti. |
| color= možno rutinne nastaviť aj na textúre. | ODMIETNUTÉ: natívne to textúru prefarbí. Farebná cesta ostáva aktívna pri obyčajnej farbe, uložený/živý vzhľad musí mať ochranu. |
| Stačí texture=nil na odstránenie vzhľadu. | ODMIETNUTÉ: PBR zostáva aktívne. Návrat ku farbe má použiť čistý farebný materiál. |
| write_thumbnail poskytne vždy náhľad. | ODMIETNUTÉ: PNG aj JPG opakovane vrátili false. Texture.write fungovalo; fallback musí byť pravdivo označený ako náhľad textúry/farba. Súbor vzhľadu sa kvôli náhľadu nestráca. |
| Orientácia potrebuje ďalší observer. | NIE: explicitné mapovanie z natívnej fyzickej mierky funguje. Po zmene mierky 100 → 200 mm sa UV v rovnakom bode zmenilo 1 → 0,5 bez observera. |
| Ručné kopírovanie material vlastností je rovnocenná kópia. | ODMIETNUTÉ: texture= neprijalo Texture objekt a ImageRep + opakované colorize dalo odlišné deltas. Použiť `.skm`. Material.duplicate na hoste 26.0 nie je dostupné; docs ho uvádzajú od 2026.2. |
| Vzhľad vyžaduje obrázok. | ODMIETNUTÉ: materiál môže zostať obyčajnou farbou alebo mať natívne vlastnosti bez albedo obrázka. |

## Presný exportný probe

Krátka samostatná guarded operácia dočasne nastavila zdroju interné meno a scope/revíziu, uložila `.skm` a vždy skončila abortom. Obnovili sa pôvodný názov, metadata, PBR a počty modelu; aj pri vloženej výnimke po save_as. XML oboch exportov obsahovalo správne nové mená aj metadata, teda nešlo o exportnú cache.

Pri dvoch obsahovo zhodných revíziách s podobnými UUID končiacimi `301`/`302` sa handle zlúčili, ak meno končilo priamo UUID. **Meno `NOXUN_APPEARANCE_<UUID>_NATIVE` túto konkrétnu adversárnu dvojicu oddelilo**: PID 66676/66677, správne vlastné metadata, zhodné PBR aj pixel hashe so zdrojom. Opakované načítanie rovnakej revízie vrátilo ten istý handle. Výklad číselného konca ako automatického suffixu je **inferenciou**, nie zárukou API; kontrola tuple po load zostáva povinná.

Testy prebehli iba v dočasných kópiách `_dev/ENGINEtests.skp`, bez deploy a s izolovaným APPDATA. Pôvodná testovacia kópia bola obnovená na 15 entít / 28 materiálov / 64 definícií; pracovné okno na porte 7891 sa nemenilo. Úplné miestne dôkazy sú v ignorovanom `_dev/mr-plan/native_probe*` a `native_export*` vrátane `native_export_report.md`.

**Limity:** nebol testovaný SU2024 host, plný natívny editor, renderový screenshot ani produkčné Undo/Redo. Pokus so zlým priečinkom nevyvolal I/O chybu, preto sa nevydáva za taký dôkaz. Podpora klasických materiálov SU2024 ostáva, PBR musí rešpektovať dostupnosť API. Presný adaptér a rendererové mapovanie vyžadujú integračné testy svojich dávok.

## Primárne zdroje

- [SketchUp Material API](https://ruby.sketchup.com/Sketchup/Material.html) — save_as, color/texture, PBR, duplicate a verzie.
- [SketchUp Materials API](https://ruby.sketchup.com/Sketchup/Materials.html) — load a current.
- [SketchUp Face API](https://ruby.sketchup.com/Sketchup/Face.html) — position_material a UV.
- [SketchUp Texture API](https://ruby.sketchup.com/Sketchup/Texture.html) — fyzická mierka a export obrázka.

Prvý návrhový audit Astra: 0 BLOCKER / 5 FIX, všetky zapracované; delta Sol `task-mtx9a4r8-h54enb` skončila **SOUND**. Natívna sonda potom doplnila povinnú príponu `_NATIVE`. Michal schválil jeden spoločný vzhľad dosiek aj ABS podľa skupiny a povrchu, naprieč hrúbkami; obyčajné farby ostávajú, zástena má jeden vzhľad.
