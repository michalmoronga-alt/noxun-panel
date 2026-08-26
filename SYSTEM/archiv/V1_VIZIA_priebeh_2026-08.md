# V1 vízia — priebeh plánovania (paragrafy 3–7, august 2026)

> **ARCHÍV.** Presunuté zo `SYSTEM/V1_VIZIA.md` 26.8.2026 (dávka Docs cleanup B).
> Živý dokument [../V1_VIZIA.md](../V1_VIZIA.md) drží už len **§1 Čo znamená „V1 hotové"**
> a **§2 Princípy (nemenné)** — teda definíciu cieľa. Tieto paragrafy boli **priebeh
> plánovania** z augusta 2026 (rozsahy dávok, poradie, stavy) a väčšina z nich je odvtedy
> hotová alebo prerozdelená.
>
> **Aktuálne plánovanie žije v [../PLAN.md](../PLAN.md)**, koncepty ďalších fáz
> v [../zdroje/next_sessions/](../zdroje/next_sessions/) (nezáväzné, status `KONCEPT`).
> Text sa nemenil — upravené sú výhradne relatívne cesty odkazov.

## 3 · Konštrukčný balík V1

- **Per-dielec odsadenia vpredu/vzadu** pre strop/dno/boky (V1-01; chladničkový komín) — UI na karte dielca; config → šablónovateľné. Warning kombinácie s drážkovým chrbtom.
- **Interiér rešpektuje výstuhy** (D-80): z_hi = spodná hrana výstuh (offset + upright výška) — zóny/police/šuflíky sa nerátajú do pásma varnej dosky.
- **Typy čiel** (V1-07, návrhová dávka po E): lakované (MDF+úprava, cena/m²), frézované (vzor), sklo/Al rám (profil+výplň, objednávka na rozmer) — „čelo ako produkt s dodávateľom".
- Plný balík V0.4.8 (rohové spoje per strana, poldrážka, „bez dielca") ostáva v zásobe — ťahá sa podľa praxe.

## 4 · Kovanie V1 (fáza 3 po E)

- **Rady namiesto jedného kódu:** nohy podľa výšky sokla (pásma: 17–21 klzák · 100/120/150 AXILO; D-79), bočnice výsuvov podľa výšky čela (H70/H144/H176 + owner override; D-81), **výklopy podľa hmotnosti čela** (C-05: generic_type lift, Aventos tabuľky, density z M-C — SNAPSHOT do modelu).
- **Výplne šuflíkov = vyrábané dielce** (V1-05): Atira dno+chrbát 16 mm (chrbát výška podľa bočnice), Quadro/Tandem celý šuflík — fáza A do výťaže/kusovníka (vzorce dodá Michal), fáza B geometria po V1.
- **Šablóny nesú kovanie** (D-76): hardware_sets do šablón — „chladničková skriňa s kovaním" na 1 klik.

## 5 · Spotrebiče a ceny

- **Spotrebiče** (V1-02): katalóg (6 typov + neskôr príslušenstvo; niche rozmery; viac URL; cena s DPH) → **položky PROJEKTU s voliteľnou väzbou na skrinku**; kontrola niche semaforom; sekcia v rozpočte. Šablóna nesie očakávaný typ („spotrebič nevybraný" ORANGE).
- **Dávka E — rozpočet** (UX-08 potvrdené zadanie): Materiály tab = súčet po CELÝCH TABULIACH (D-61) s cenami; ABS tab = bm × cena; Kovanie už má; **okno Rozpočet = všetko spolu** + sadzby služieb („Nastavenia dodávateľa") + montáž (count_max × 5,8 × sadzba) + spotrebiče. Luciin nástroj — dizajnovať pre ňu.
- **Cenová čerstvosť** (V1-03, globálne): price_checked_at všade; overenie AUTO (Demos fetch) alebo MANUÁL (klik URL → 1-klik „cena sedí/zmeniť" — klik sám NEzapisuje); vek ceny viditeľný kontextovo pri POUŽITÍ (rozpočet: „N cien starších ako 30 dní"); viac URL na položke, cena vždy JEDNA. *Stav po dávke E (6.8.): hotová je **AUTO vetva** („Prepočítať ceny" nad položkami s väzbou na Demos, server-stamped dátum overenia) a **vek ceny** v rozpočte; **zvyšok V1-03 ostáva otvorený** — manuálne 1-klik overenie pre položky BEZ väzby a viac URL na položke (vedomý odklad, zoznam v [DOGFOODING.md](../DOGFOODING.md)).*

## 6 · Workflow a UI 2.0

- **Vkladanie na klik** (V1-04 fáza 1, SKORO — malá dávka): skrinka visí na kurzore, klik umiestni. Snap/pripájanie k susedom = V1 zostavy ([PLAN.md](../PLAN.md)).
- **Vizuálny materiálový workflow:** farba per DEKOR (C-06/D-82, skupinová operácia) → Demos fotka ako textúra SU materiálu (M-R quick-win) → **nástroj „pixla"** (V1-06): ikonka na dlaždici materiálu → klik prefarbuje dielce (cez part_override cestu, 1 klik = 1 undo). Koniec „hnedého mora".
- **UI 2.0 — štúdio** (D-50 + celý E blok zápisu): satelity (Materiály·Kovanie·Výroba·Pravidlá·Šablóny) → JEDNO okno s bočnou navigáciou (OCL vzor, GPL kód nie); header panela = prístup ku všetkému (UX-02); karta Zóna so smerovými ikonami (UX-06); štandard veľkostí okien/tlačidiel (D-51) PRED Luciiným nasadením — vrátane okien, ktoré sa otvárajú odseknuté (D-77); select „(podľa projektu)" vs explicitná voľba viditeľne (zámok predvoľby); polia šírkou podľa obsahu (UX-03); „Nahradiť UNI" dostupné z KONTROLY (UX-07/D-83). **Mockup pred implementáciou** (vzor Materiály 2.0 — schválený klikateľný HTML).

## 7 · Navrhované poradie po smoke teste

1. **H-dávky (opravy+malé, pred E) — HOTOVÉ 4.8. (PR #131–#135, v0.5.44):** H1 kovanie (D-75 live push setov · D-79 nohy default+rad · D-81 bočnice+owner override) → H2 šablóny s kovaním (D-76) → H3 geometria interiéru (D-80, SU testy) → H4 UI drobnosti (D-78 · D-82 · D-83). **D-77** (odseknuté okno detailu) z H4 VYPADOL — Michal 4.8.: „vyriešime plošným reworkom, týchto chýb v oknách je viac" → rieši ho bod 6 (UI 2.0, spolu s D-50/D-51). H-dávky teda E neblokujú.
2. **Dávka E — HOTOVÉ 6.8. (PR #137–#140, v0.5.48):** rozpočet + zákaznícka cenová ponuka + „Prepočítať ceny". **Zmena rozsahu oproti pôvodnému zadaniu:** z cenovej čerstvosti (V1-03) dávka dodala **AUTO overenie a vek ceny**, ale **manuálne 1-klik overenie pre položky bez väzby na Demos sa vedome ODLOŽILO** (nie je to prehliadnutie — zoznam odkladov dávky E je v [DOGFOODING.md](../DOGFOODING.md), skupina „V1 DOTIAHNUTIE" — EN DANIELI export v skupine „KONTROLA + VÝROBA").
3. ~~**Seed katalógu** (odložený po E — plán platí).~~ — **ZRUŠENÉ (Michal 10.8.):** katalóg si narastie sám prácou na zákazkách; skutočný problém je **nájsť materiál aj v malom zozname** = UX výberov (D-85), teda súčasť UI 2.0.
4. **UI 2.0** (mockup → dávky; vrátane V1-01 karta dielca Konštrukcia — alebo V1-01 skôr, rozhodne prax). — **PREDRADENÉ pred S1 aj M-R (Michal 10.8.):** po dokončení zákazky KLINIKA nasleduje kontrola + testy + posledné úpravy, potom UI 2.0 (najprv debata, potom klikateľný mockup vzorom Materiály 2.0). Podklad: merač používania D-25 (materiály/ABS 400+ interakcií, taby 287×, satelitné okná 234× — [zdroje/MERAC_D25_odpocet_2026-08.md](../zdroje/MERAC_D25_odpocet_2026-08.md)). **Žiadne quick-win náplasti pred reworkom.**
5. **Spotrebiče S1** (katalóg+model+kontrola+rozpočet sekcia). — posunuté ZA UI 2.0 (Michal 10.8.).
6. **M-R render** (textúry — Lucia) + pixla nástroj (V1-06). — posunuté ZA UI 2.0 (Michal 10.8.).
7. **V1.0 zostavy** ([PLAN.md](../PLAN.md): sokel/PD/obklady/snap) + vkladanie fáza 1 SKÔR (malá, zaradiť medzi H-dávky?).
8. **V1-05 výplne + C-05 výklopy** = kovanie fáza 3 (po E, vzorce od Michala).

*(Poradie 4–8 na diskusiu — závisí od Luciinho nasadenia a reálnych zákaziek.)*
