# Noxun Component Standard — osnova (v0.2, 15.7.2026)

> ⚠️ **ARCHÍV — historický pracovný dokument (presunuté 24.7.2026).** Záväzná verzia je [../01_STANDARD.md](../01_STANDARD.md); pri rozpore platí štandard. Osnova sa ponecháva ako záznam rozhodovania. Legenda: ✅ = rozhodnuté · 🔶 = smer daný · ❓ = otvorené (stav k 15.7.).

## 1. Pojmy a hierarchia

Návrh: **Zostava** (kuchyňa/skriňa = rad korpusov) → **Korpus** (skrinka; nesie konfiguráciu) → **Slot / vnútorný priestor** (adresovateľné pole vnútra — celé, alebo medzi policami/priečkami; vzniká a zaniká delením) → **Child** (funkčný modul v slote: šuflík, dvierka, polica, priečka, doplnok) → **Dielec** (fyzický kus materiálu na výrobu — vždy samostatný komponent) → **Virtuálna položka** (kovanie/spotrebný materiál bez geometrie, len v súpise).

- 🔶 **Slot: vizuálny „ghost" s prepínačom viditeľnosti** (Michal: „ideálne ako ghost — viditeľný/neviditeľný — musím to najskôr vidieť"). Realizácia: polopriehľadné boxy na vlastnom tagu (vypnutie tagu = neviditeľné; geometria slotov mimo kusovníka). Potvrdiť po vizuálnom deme v SketchUpe.
- ✅ **Kovanie — hranica fyzické/virtuálne:** pár základných jednoduchých fyzických objektov — **1 generický fyzický typ na kategóriu** (záves, výsuv, nožička…), slúži pre vizuál a pozície a ako základ budúcich vylepšení. **Na fyzický typ sa viaže ľubovoľne veľa virtuálnych variantov** (konkrétni výrobcovia, typy, kódy) — čisto dáta v katalógu. Skrutky/spojky = čisto virtuálne.

## 2. Identita a atribúty

- Jednotný slovník: navrhujem `NOXUN` dictionary s pod-kľúčmi podľa vrstvy (`NOXUN/type`, `NOXUN/role`, `NOXUN/config…`), namiesto dnešnej zmesi (`NOXUN_CORE`, `NOXUN_KOVANIE`, DC `dynamic_attributes`).
- **Autorita: inštancia.** Definícia nesie defaulty/šablónu; inštancia konkrétny stav (poučenie: zdieľané definície dverí v Master majú na definícii zastarané hodnoty).
- ~~Identifikácia inštancie cez `persistentId`~~ — SPRESNENÉ v drafte (2.3): trvalé väzby VÝHRADNE cez logické ID + rolu (persistentId dielcov zaniká rebuildom); `persistentId` len na navigáciu v rámci session.
- Rola dielu explicitným atribútom (`NOXUN/role = "bok_L"`), nie parsovaním názvov (poučenie: `_name` „Pbok" vs. definícia „Lbok#1").
- **Verzia štandardu na komponente** (`NOXUN/std = 1`) — migrácie budú.
- 🔶 Čo všetko musí niesť dielec — minimum odvodené z VEPO kontraktu (`03_VYSTUP_vepo_kontrakt.md`): názov, dĺžka×šírka×hrúbka (reálna aj obchodná), počet, materiál, **hrany per strana (l1/l2/w1/w2)**, smer dekoru/rotácia, rola, väzba na korpus. Finálny zoznam po doriešení hrán (sekcia 7 ❓).

## 3. Jednotky a geometria

- Naša vrstva (Ruby + UI + uložené hodnoty v NOXUN dictionary): **všetko v mm** (Float alebo Length — rozhodnúť ❓). DC vrstva si nechá svoje tri svety (palce/cm/mm) — prekladáme len na hranici, na jednom mieste v kóde.
- Osi: dohoda čo je šírka/výška/hĺbka lokálne (X=šírka, Y=hĺbka, Z=výška — ako dnes) + **pravidlo pre origin** každého typu komponentu (dvierka: origin na hrane pántu; dielce: ľavý-predný-dolný roh?) ❓
- Smer dekoru: explicitný atribút na dielci (`NOXUN/grain = X|Y|none`) — nie odvodený z textúry.
- Rozmery čítať z nominálov / našich atribútov — nikdy z bounding boxu (dvere pred korpusom).

## 4. Korpus — konfigurácia a konštrukčné typy

- Korpus nesie konfiguráciu ako dáta: vonkajšie rozmery, hrúbky, sokel, chrbát (typ), konštrukčný typ.
- **Konštrukčné typy** (ArchiWood vzor): boky obaľujú dno/vrch ↔ dno/vrch obaľujú boky ↔ kombinácie; naložené/vložené varianty (dnešné `f_dno`/`f_strop`).
- ✅ **Typy na štart: DOLNÁ a HORNÁ skrinka** (rozhodnuté 15.7.2026) — pokryjú 60–70 % potrieb; ostatné (vysoká, spotrebičová, drezová, rohová…) sa neskôr odvodia od týchto dvoch základov.
- ✅ **Korpus generuje RUBY** (regenerate pattern: konfig v atribútoch → clear → rebuild v 1 Undo operácii), žiadne DC vzorce v korpuse. Rozhodnuté 15.7.2026 — analýza `02_ANALYZA_korpus_dc_vs_ruby.md` + 3 živé experimenty (generovanie 4 ms, rebuild 3 ms, DC most funguje). Existujúce DC moduly dočasne ako čierne skrinky (scale+redraw), bez spoliehania na ich `parent!` vzorce.

## 5. Sloty a pripájanie childov

- Slot má: rozmery (svetlé), pozíciu, rodiča, stav (voľný/obsadený), pravidlá (čo doň smie).
- Child pri vložení: dostane rozmery zo slotu + vlastné pravidlá (škáry, presahy, max hĺbka výsuvu, odsadenie od chrbta — ArchiWood „inteligentné defaulty").
- Delenie: priečka/polica rozdelí slot na nové sloty (rekurzívne) — vzniká strom priestorov.
- ✅ **Vkladanie na výšku: FIXNÉ + AUTO s „lockmi"** (rozhodnuté 15.7.2026) — maximálna prispôsobiteľnosť na štýl zámkov: jedno čelo môžem zamknúť na fixnú výšku, ostatné sa dopočítavajú automaticky. Inšpirácia: Blum e-services konfigurátor (výborný engine nastavení — research beží, závery sa doplnia).
- ❓ Čo sa deje pri zmene rozmeru korpusu s obsadenými slotmi — prepočet detí automaticky (a kedy resize zakázať/limitovať — `LARGEST/SMALLEST` princíp)?

## 6. Kovanie — flagy a pravidlá

- **Two-phase:** (1) pri vkladaní/zmene childu systém pridelí **generický flag** (`zaves`, `vysuv_450`, `nozicka`…) s množstvom podľa **pravidiel v JSON** (dvierka H≤900 → 2 závesy; H≤1600 → 3; šuflík → 1 pár výsuvov + N skrutiek…); (2) na konci projektu (alebo raz v nastaveniach) sa flagy **mapujú na konkrétne katalógové kódy** — mapovanie sa ukladá a nabudúce prebehne automaticky.
- Katalóg, ceny, Demos import — prevziať bloky z KOVANIE (CatalogStore, search, export).
- ✅ **Formát pravidiel: JSON súbory v knižnici pravidiel, editovateľné cez jednoduchý panel** (nie ručne v súbore). Odsúhlasené 15.7.2026.
- ✅ **Vŕtanie/pozície kovania: MIMO SCOPE** (aspoň zatiaľ) — riešia sa len počty, typy a kódy. Fyzická reprezentácia kovania = 1 generický objekt na kategóriu (viď sekcia 1).

## 7. Materiály a ABS hrany

- Dielec nesie: materiál (odkaz do materiálovej knižnice: dekor + hrúbka + cena/m²) + **hrany**: 4 strany, každá `none | ABS(hrúbka, dekor)` — ako dáta na dielci, nezávislé od vizuálnej textúry.
- **Pravidlové defaulty** (ArchiWood): typ dielca určí default hranovanie (čelo: dookola; polica: len predná…), výnimky pravidlami (hrúbka < prah → nič; názov obsahuje X → nič). Ručný override per dielec.
- Materiálová knižnica je NAŠA (názvy, dekory, ceny) — VEPO názvy a normalizácia hrúbok (18/36) sa aplikujú až pri exporte (kontrakt v `03_VYSTUP_vepo_kontrakt.md`).
- ❓ **Mapovanie hrán po rotácii dielca** (predná/zadná/ľavá/pravá vs. lokálne osi) — opakovaný problém aj v OCL (Michal to potvrdzuje). Rozobrať KOMPLEXNE počas návrhu + otestovať na reálnych dielcoch cez SkAgent skôr, než sa uzamkne. V modeli držať hrany per strana (l1, l2, w1, w2), nie súhrnné kódy — tie sa dopočítajú pri exporte.

## 8. Výstupy — vlastný engine (bez OCL a vepo_exporter)

✅ **Rozhodnutie 15.7.2026: OCL aj vepo_exporter časom úplne vyhodíme.** Z každého si berieme logiku, ktorá sa zíde (OCL: výpis materiálu, ABS hranovanie, orientácie; vepo_exporter: presný VEPO formát — už extrahovaný do `03_VYSTUP_vepo_kontrakt.md`). Dôvod: neprispôsobovať dátový model cudzím pluginom; jeden systém, žiadne export-z-exportu; flow úplne customizovateľný a rýchly. Neskôr posúdime, čo sa neoplatí extrahovať (napr. material editor OCL).

- **Výstup 1 — VEPO tabuľka priamo z dielcov:** presne podľa `03_VYSTUP_vepo_kontrakt.md` (stĺpce, `—`/`=` kódy, normalizácia hrúbok, slug súbory). Bez OCL medzikroku.
- **Výstup 2 — Kusovník + súpis kovania + ABS** (interný, pre výrobu).
- **Výstup 3 — Rozpočet/ponuka:** ✅ formát rozhodnutý (15.7.2026): **čisto kusovník dielov + m² materiálu + ABS (bm) + kovanie (ks) + celkový sumár**. Žiadne marže, žiadne DPH — možno neskôr. Cena práce sa NErieši.
- **Kontrola pred odovzdaním:** zoznam problémov (dielec bez materiálu, flag bez kódu, nezmyselný rozmer) — „semafor".
- **Prechodné obdobie (poistka):** OCL zostáva nainštalovaný len na KRÍŽOVÚ VALIDÁCIU — na prvých zákazkách porovnáme náš kusovník s OCL výstupom; po zhode sa odstaví. Nie je to prispôsobovanie sa OCL, je to test správnosti.

## 9. Čo štandard NErieši (zámerne, aby sme sa neutopili)

✅ Vŕtacie rastre a CNC pozície kovania • **nárezové plány/nesting** • **cena práce** • automatické výkresy (Noxun Sketch vetva — neskôr) • úlohy/tasks • cloud. K tomu sa systém dostane, až keď jadro stojí.

---

## Navrhované poradie diskusií (jedno sedenie = jedna téma)

1. **Hierarchia + identita + jednotky** (sekcie 1–3) — čiastočne rozbehnuté (slot 🔶, kovanie ✅); zostáva: identita, jednotky, osi/originy
2. ~~Korpus: DC vs. Ruby~~ ✅ ROZHODNUTÉ (Ruby generovanie) — zostáva len ❓ počet konštrukčných typov na štart
3. **Sloty a pripájanie** (sekcia 5) — srdce UX; podklad = vizuálne demo slotov v SketchUpe
4. **Kovanie: pravidlá a two-phase** (sekcia 6) — formát ✅, zostáva obsah pravidiel a katalóg
5. **Materiály/ABS + výstupy** (sekcie 7–8) — výstupná stratégia ✅ (vlastný engine), zostáva: mapovanie hrán (veľká téma) + formát rozpočtu

Po každom sedení sa rozhodnuté veci presunú z osnovy do finálneho `01_STANDARD.md`.
