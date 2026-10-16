# Krížový audit bloku UPDATE — A3 rešeršér web (Claude Sonnet, 17.10.2026)

> Surový výstup (zhustený orchestrátorom bez zmeny obsahu). Zadanie: `cross_audit_update.md` (scratchpad orchestrátora; rovnaké pre A1–A4).

## Zhrnutie
- Model „jeden správca + nemenné verzie + ukazovateľ" je bezpečný, len ak nepredpokladá nič, čo Google nezaručuje (atomický rename, poradie doručenia, zámky). Koncept už počíta s doručením mimo poradia a overením celistvosti.
- Oficiálne potvrdené málo: mirror drží plnú lokálnu kópiu, zmeny sa prenášajú oboma smermi, chyby sú v notifikáciách.
- `UI::Notification` je pre oznámenie pri štarte použiteľná (SU 2017+).
- Prior art (OpenCutList, Cabinet Vision, Mozaik, imos, Polyboard) — nič použiteľné nenájdené.

## 1 · Google Drive for desktop (Windows, mirror)
| Fakt | Zdroj | Stav (overené 17.10.2026) |
|---|---|---|
| Mirror = plná kópia na PC; edit/zmazanie/presun sa zopakuje na druhej strane | support.google.com/drive/answer/10838124 · support.google.com/a/users/answer/13022292 | OVERENÉ |
| Stav synchronizácie a chyby v dlaždici „Sync status" a notifikáciách; sync sa dá pozastaviť | support.google.com/drive/answer/10838124 | OVERENÉ |
| Offline: pri streame sa offline súbory po odpojení účtu odstránia; mirror nepopísaný | tamže | OVERENÉ len stream |
| Súbory idú pred uploadom do content cache; vyčistenie cache pred uploadom môže súbor stratiť | knowledge.workspace.google.com/admin/drive/advanced-drive-for-desktop-configuration | OVERENÉ |
| Cache len NTFS, SMB/NFS nepodporované; stream = FAT32 s limitom 4 GB; Win10+ 64-bit, WebView2 | support.google.com/drive/answer/2375082 | OVERENÉ |
| Názov konfliktných kópií („(1)", „[Conflict]") | len sekundárne weby | NEOVERENÉ |
| Temp + rename, prepis počas sťahovania, poradie doručenia, zámky, limity mien a počtu | — | NEOVERENÉ (Google nepopisuje) |

Mirror vs stream: pri streame prvé čítanie sťahuje a môže visieť (inferencia, NEOVERENÉ); R10 = mirror u oboch, no O plugine má diagnostikovať „H: nedostupný/nezrkadlený".

## 2 · Prior art
- SketchUp: Trimble Connect 2.0 Extension sa po SU 2024.0 neodporúča; Trimble Connect Sync je samostatná appka (help.sketchup.com/cs/sketchup/trimble-connect-extension) — ako alternatíva NEOVERENÉ, cudzia závislosť.
- OpenCutList: importuje len materiály z modelu (fórum, NEOVERENÉ).
- LightBurn (zdieľaný súbor knižnice cez sieť/cloud — zmeny sa neprejavia bez načítania, Dropbox medzi 2 PC rozpája väzby) · MaxCut (kopírovanie priečinka / zdieľaný priečinok) → vzor „publish/subscribe s jedným správcom a explicitnou aktualizáciou" je bežný; živý zdieľaný súbor cez sync bol v praxi problematický.

## 3 · SketchUp Ruby API
- `UI::Notification.new(extension, message, icon_name, icon_tooltip)`, `on_accept` / `on_dismiss` pred `show` (inak RuntimeError); ignorovaná zmizne **bez callbacku**; referenciu držať (GC crash pred 2021.1); `\n` od 2019 (ruby.sketchup.com/UI/Notification.html).
- Vlákna: dokumentácia nič nehovorí; vzor updatera (worker s deadline + `UI.start_timer` na hlavné vlákno) je v súlade. NEOVERENÉ oficiálne.

## Dopad na koncept
- **FIX 1 celistvosť:** ukazovateľ → manifest s veľkosťou a hash každého súboru; chýbajúci/nezhodný = „synchronizácia ešte beží", nie chyba; povinný test s nedoručenou/skrátenou prílohou.
- **FIX 2 konfliktné kópie:** ignorovať všetko mimo vlastnej schémy mien; konfliktná kópia ukazovateľa nie je ukazovateľ; ukazovateľ nesie číslo verzie.
- **FIX 3 nedostupný H::** rozlíšiť „H: neexistuje" / „koreň prázdny alebo sa synchronizuje" / „v poriadku"; prázdny priečinok ≠ zmazaná knižnica.
- **FIX 4 mená:** súbory a prílohy ASCII a krátke (hash/ID), nie podľa názvu dekoru; diakritiku a dĺžku cesty overiť na H:.
- **FIX 5 oznámenie:** stav „novšie knižnice" vždy aj v O plugine; `on_accept` nič nesťahuje.
- **NOTE 1:** natívna cesta nie je jednoduchšia; „nemenné verzie + explicitné Aktualizovať" je správny smer.
- **NOTE 2:** správanie Drive overiť **empiricky na oboch PC** pred zmrazením packages (sonda: veľká sada súborov s manifestom, sledovať poradie, oneskorenie, konfliktné kópie).
- **NOTE 3:** žiadny BLOCKER z webu.
