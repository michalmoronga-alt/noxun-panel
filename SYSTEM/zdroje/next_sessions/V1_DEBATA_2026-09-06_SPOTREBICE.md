# V1 debata · bod 5 SPOTREBIČE S1 — rozhodnutia a predúloha (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (okno „V1 plánovanie po KOVANÍ") · auditované proti kódu: zatiaľ nie ·
> detailná debata pokračuje **až po predúlohe „technické listy"** (§4) — task package vznikne až potom a po `codex-audit` (nový modul).
>
> Pred implementáciou platí postup z [README.md](README.md). Nadväzuje na [04_SPOTREBICE_S1.md](04_SPOTREBICE_S1.md) a [04A_SPOTREBICE_EXTERNY_AUDIT.md](04A_SPOTREBICE_EXTERNY_AUDIT.md);
> tento dokument koncept **zužuje na V1** — nie nahrádza.

## 0 · Čo má S1 vo V1 splniť (Michal)

Spotrebiče sú 50/50 — raz kupuje zákazník, raz firma. Hlavný úžitok V1 **nie je** cena, ale **poriadok a kontrola rozmerov**:

> „Vedieť: tento spotrebič patrí k tejto zákazke, k tejto skrinke. Tu je link, prípadne odkaz na technické detaily. Nemusím pátrať v ďalších 10 súboroch a dohľadávať typ a technické listy."

Časom **knižnica spotrebičov s overenými rozmermi ku konkrétnym modelom** (hlavne rúra, mikrovlnka, chladnička). V1 = **použiteľný základ + pár užitočných funkcií**, na ktoré nadviaže V1+.
Nekomplikovať: žiadny abstraktný framework, žiadne guardy navyše, jednoduchý systém.

## 1 · Rozhodnutia

| Téma | Rozhodnutie |
|---|---|
| Kategórie V1 | rúra · mikrovlnka · chladnička (nika v skrinke) · umývačka (šírka + čelo) · varná doska a drez (len výrez do PD + cena) · digestor, batéria, dávkovač = len cenová položka. **Poistka:** ak audit ukáže priveľký záber, V1 = **len rúra, mikrovlnka, chladnička, umývačka**. |
| Zdroj dát | **výhradne ručne** z technického listu; žiadny web scraping (obchody a URL sa menia) |
| Záznam katalógu | názov/model (napr. „Mikrovlnná rúra Bosch Serie 8 BFL7221B1 čierna") · **viac odkazov na obchod** (rýchly preklik, URL sa menia) · **viac URL technických listov** (býva ich 5–10) · ideálne aj **priamo nahraný list** (súbor) · rozmery podľa kategórie (§2) |
| Cena | **NIE v katalógu** (mení sa) — cena je **len položka rozpočtu** danej zákazky; spotrebič bez ceny = dodáva zákazník |
| Väzba | spotrebič patrí **zákazke a vlastníkovi podľa kategórie** (koncept 04 §Binding, Codex #322 P2): **skrinka** (rúra, mikro, chladnička) · **slot medzi skrinkami** (umývačka — nemá korpus) · **pracovná doska** (varná doska, drez) · **len zákazka** (digestor, batéria, dávkovač); jadro V1 = „viem, kde patrí a kde sú listy" |
| Kontrola rozmerov | vo V1 **len chladnička a umývačka** (jednoduché); **rúra a mikrovlnka zatiaľ nie** (previazané rozmery, presahy, rúra + mikro nad sebou) — až po predúlohe |
| Šablóna „spotrebičová" | uložená šablóna nesie **tag/kategóriu „spotrebičová"**; skrinka z nej **bez priradeného spotrebiča = upozornenie v Kontrole** (ORANGE, neblokuje). Tag pri ukladaní šablóny = nový prvok mini-modalu „Uložiť ako šablónu" — **vymyslieť ako** |
| UI | Štúdio: sekcia **Spotrebiče** (katalóg + zoznam v zákazke) · Inspector: riadok „Spotrebič" **len pri spotrebičových skrinkách** · Rozpočet/CP: skupina „Spotrebiče a vybavenie" |
| Police podľa niky | **nie vo V1** — police sa nastavia ručne podľa niky; automatiku ukáže výskum listov |
| 3D telo | nie (V1_VIZIA: kubusy mimo V1) |

## 2 · Rozmery — príklad mikrovlnky (Michalov zápis, 6.9.)

Ukazuje, že mikrovlnka a rúra majú **tri sady rozmerov** a presahy — nie jeden „šírka × výška × hĺbka":

```
Telo:        šírka 550 · výška 340 · hĺbka 300
Čelo:        šírka 594 · výška 382 · hĺbka 20    presah čela hore 6 · dole 14
Výklenok:    šírka 560–568 · výška 362–365        (rozsah min–max)
Odkazy:      obchod https://www.nay.sk/... · tech list https://image.nay.sk/... (+ ďalšie)
Cena:        699,90 € (len v rozpočte zákazky)
```

Rúra a mikrovlnka sú „dosť komplikované — viac previazané, medzery, presahy, hlavne keď sa viažu nad seba rúra + mikro". Chladnička a umývačka budú jednoduché.
**Ktoré polia sú povinné, ktoré rozsah a ktoré voliteľné, rozhodne až predúloha.** Neznámy údaj nikdy nedostane tichý default (04A invariant).

## 3 · Nahrávanie technického listu (súbor) — posúdenie Fable

Jednoduché a bez pascí: kópia súboru (PDF/JPG) do katalógového priečinka `%APPDATA%\NOXUN\Engine\appliances\<id>\`, otvorenie systémovým prehliadačom (`UI.openURL` na súbor).
Obmedzenie priznať: súbory sú **per PC** (zdieľanie = D-48 po V1). Nekomplikovať: žiadne náhľady, žiadna extrakcia rozmerov z PDF.

## 4 · PREDÚLOHA „TECHNICKÉ LISTY" (pred detailnou debatou S1)

Michal: „pred implementáciou si pripraviť pár konkrétnych tech listov s rozmermi — aby sme sa nebavili z brucha". Postup:

1. **Zoznam objednaných spotrebičov** z firemných objednávok (Disk / e-mail) → **modely, ktoré sa opakujú** (rúra, mikro, chladnička prioritne). *Kto:* toto okno cez konektory
   Google Drive / Gmail (Antigravity k Disku ani objednávkam prístup nemá — má len web). Vstup od Michala: **kde objednávky sú** (priečinok Disku / odosielateľ e-mailov / obchody).
2. **Technické listy** k opakujúcim sa modelom → **outside-in cez Antigravity** (skill `antigravity-outside-in`, web search + read_url): stiahnuť/prečítať listy, vypísať, aké rozmery
   výrobcovia uvádzajú (telo, čelo, nika min–max, presahy, odvetranie, medzery pri rúre + mikro nad sebou).
3. **Výstup = research packet** `SYSTEM/zdroje/next_sessions/SPOTREBICE_TECHLISTY_2026-09.md`: tabuľka modelov × rozmerov, čo listy ponúkajú, **čo z toho engine potrebuje**, kde je to
   komplikované a čo zatiaľ neriešiť + **prvý seed balík** (overené modely). Až nad ním: detailná debata S1 → package → `codex-audit`.

## 5 · Doplnenia Michala po výskume listov (6.9. večer)

- **Vetrací kanál sa vo V1 nerieši** (žiadne pole, žiadna kontrola plochy vetrania). **Odsadenia sa nefixujú** — odsadenie korpusu je nastaviteľný parameter (K1),
  šablóna nesie len hodnotu, ktorú si Michal zvolí; engine z listu nič nevynucuje.
- **Umývačky:** predpísané rozmery čela Michal bežne **obchádza** (čelo presahuje hore, presah doplní slepým korpusom alebo malým šuflíkom nad umývačkou).
  Dôsledok pre V1: kontrola umývačky = **len šírka slotu (450/600)**; výška čela vs. sokel sa nekontroluje (je to jeho konštrukčné rozhodnutie).
- **Galéria pri spotrebiči (rozhodnuté ÁNO, do S1):** k záznamu spotrebiča sa dajú **uložiť súbory** — technické listy (PDF/JPG), obrázky z listov a **jeden náhľadový obrázok**
  reálneho produktu. Posúdenie Fable: uskutočniteľné bez pascí — kópie súborov v `%APPDATA%\NOXUN\Engine\appliances\<id>\`, záznam nesie zoznam súborov s druhom
  (`list` / `obrázok` / `náhľad` — presne jeden náhľad), obrázky sa ukážu ako miniatúry (rovnaký lenivý kanál ako náhľady šablón PNG), PDF len ikona + otvorenie
  v systémovom prehliadači (`UI.openURL`). **Bez** generovania náhľadu z PDF, bez extrakcie rozmerov. Obmedzenie priznať: súbory sú per PC (D-48 po V1).
  Pri mazaní spotrebiča sa maže aj jeho priečinok; osirelé priečinky uprace ďalší štart (vzor zametania `template_previews`).
- Detailná debata polí S1 pokračuje **po Michalovom overení** aspoň jedného listu per kategória ([SPOTREBICE_TECHLISTY_2026-09.md](SPOTREBICE_TECHLISTY_2026-09.md) §3).

## 6 · Dopad na živé dokumenty (zapracuje záverečný docs PR debaty)

- [../../V1_VIZIA.md](../../V1_VIZIA.md) bod 5 prepísať: „katalóg (ručne) + spotrebič v zákazke s vlastníkom podľa kategórie (skrinka / slot / PD / len zákazka), s odkazmi a listami + kontrola niky pre chladničku/umývačku + šablóna
  spotrebičová s upozornením + galéria súborov + cena v rozpočte"; automatika políc a kontrola rúry/mikro = V1+.
- [../../PLAN.md](../../PLAN.md) blok 4 položka „Spotrebiče S1": odkaz sem + predúloha (research) ako prvý krok.
