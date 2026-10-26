---
name: smoke
description: Vedenie smoke bloku s Michalom po uzávere — zápisník SMOKE_ZAPISNIK_<dátum>.md v priečinku bloku (stav bodov PASS/FAIL/VYNECHANÉ/ZOSTÁVA s dôkazom, postrehy S1…), commit a push po každom sedení, Michal najprv škrtne nerelevantné body, rozdelenie bodov na overiteľné agentom (len v testovacom modeli) a ručné u Michala, nálezy do DOGFOODING a opravy x.y.z, smoke PASS dokumentačným PR. Použi, keď Michal začne smoke po uzávere bloku alebo keď sa smoke prenáša do novej session.
---

# Smoke bloku

Smoke robí Michal **po uzávere bloku** podľa checklistu v záverečnom dokumente bloku (skill `uzaver-bloku`, krok 5). Orchestrátor ho vedie:
drží zápisník, robí body overiteľné agentom, zapisuje nálezy a zvyšok nechá na Michala. Testuje sa len v testovacom modeli
(`_dev\ENGINEtests.skp` alebo model pripravený pre smoke), nikdy v zákazke ([AGENTS.md](../../../AGENTS.md), Zákazy).

## Formát checklistu

Body sú **po skupinách s ID**: skupina = písmeno (A, B, C …) podľa oblasti alebo okna, najdôležitejšia prvá (to, čo mení výrobné a cenové
čísla), v skupine číslo (A1, A2 …); prípravné body majú skupinu P. **ID je stabilné** — bod sa nikdy neprečísluje, vynechaný ostáva s ID.
Bod = čo urobiť · čo má byť výsledok · zdroj dávky v zátvorke; značka **[model]** = potrebuje testovací model, **[záloha]** = potrebuje zálohu
súborov z `%APPDATA%\NOXUN\Engine`.

## Zápisník

- **Súbor** `SMOKE_ZAPISNIK_<dátum>.md` v priečinku bloku (po uzávere `SYSTEM/archiv/bloky/<BLOK>/`), založený hneď na začiatku smoke.
- **Obsah:** hlavička (odkaz na checklist, spôsob smoke, prostredie: verzia SketchUpu a pluginu, model) · legenda · **stav každého bodu**
  · log postupu · tabuľka postrehov.
- **Stav bodu:** ✅ PASS · ❌ FAIL (→ postreh) · ⏭ VYNECHANÉ (s dôvodom a **kto rozhodol**) · ☐ ZOSTÁVA; ku každému bodu **dôkaz** (čo sa
  skontrolovalo a ako: výstup bridge/MCP, súbor exportu, foto okna, Michalova veta).
- **Zostáva:** v zápisníku vždy aktuálny zoznam zostávajúcich bodov s pokynmi, aby sa dal dokončiť v novom okne.
- **Postrehy** `S1`, `S2` … (tabuľka: číslo · kde · čo · závažnosť · kam zaradiť); návrh a nápad sa označia ako také, rozhoduje Michal.
- **Po každom sedení commit a push** vetvy `docs/smoke-<blok>`. Zápisník v lokálnej alebo nepushnutej vetve sa stratí — nová session
  dostane **cestu k zápisníku a názov vetvy**, nie len slovo „smoke".

## Priebeh

1. **Michal najprv škrtne.** Pred začiatkom prejdi checklist po skupinách a pri každej sa opýtaj, ktoré body sú nerelevantné
   (nepoužíva funkciu, už overené, mimo rozsahu). Vynechané body sa zapíšu ako ⏭ s dôvodom a menom, kto rozhodol.
2. **Rozdeľ zvyšné body:**
   - **Overiteľné agentom:** runner testov v SketchUpe, export test, fotenie okien, bridge/MCP kontrola stavu modelu — postupy a príkazy:
     [IMPLEMENTATOR.md](../../../SYSTEM/pravidla/roly/IMPLEMENTATOR.md#testovanie) a [NASTROJE_TESTOV.md](../../../SYSTEM/pravidla/NASTROJE_TESTOV.md).
     **Pred exportom over cieľový priečinok** — výber priečinka sa otvára na poslednom použitom, takže export by mohol skončiť v reálnom
     projekte; exporty idú do `_dev`.
   - **Ručné u Michala:** vizuál, UX, dielňa a všetko, čo sa nedá overiť bez ľudského oka.
3. **Sedenie:** orchestrátor pošle Michalovi malú dávku bodov (jedna skupina alebo okno), Michal odpovie „ok" alebo čo nesedí; po každej
   odpovedi zapíš stav a dôkaz do zápisníka. Body overiteľné agentom robí orchestrátor sám medzi Michalovými odpoveďami.
4. **Po sedení** commit a push zápisníka (viď vyššie).

## Nálezy a ukončenie

- **Nález (FAIL, postreh)** → položka v dočasnej skupine „smoke po uzávere" v `SYSTEM/DOGFOODING.md`; oprava ide ako dávka s patch
  verziou x.y.z (bežný postup dávky, nový blok sa nezačína). Skupina zanikne s posledným nálezom.
- **Smoke PASS** = Michalovo slovo. Potom **dokumentačné PR so zápisníkom**: v `SYSTEM/STAV.md` „smoke PASS" (a nový „Robí sa" a „Ďalší
  krok"), odsek v `SYSTEM/archiv/KRONIKA.md`. **Alebo** výslovné **„ideme ďalej"** — zápisník sa uloží so stavom, ktorý je (neoverené body
  ostávajú ☐).
- Až po smoke PASS alebo „ideme ďalej" sa začína ďalší blok (ORCHESTRATOR.md, Autonómne bloky).
