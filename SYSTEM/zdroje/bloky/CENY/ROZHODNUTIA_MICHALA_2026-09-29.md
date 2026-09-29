# Blok CENY — overenie cien materiálov a ABS: rozhodnutia Michala (6.9., 10.9. a 29.9.2026)

> **Produktové rozhodnutia bloku** — čo a ako má plugin robiť z pohľadu stolára. **Technické požiadavky** (polia, verzie dát, brány
> staršieho pluginu, testy…) sa zapisujú do **package každej dávky** a prejdú jej auditom návrhu.
> Pôvodná debata: [../../next_sessions/V1_DEBATA_2026-09-06_VYSTUPY.md](../../next_sessions/V1_DEBATA_2026-09-06_VYSTUPY.md) §0 (historický vstup)
> a hotový vzor pre katalógové kovanie **CENY-KOV** (PR #345/#346, v0.10.4–v0.10.5; plný text v
> [../../../archiv/ROADMAP_hotove_etapy.md](../../../archiv/ROADMAP_hotove_etapy.md), sekcia „CENY-KOV"). **Kde sa s nimi rozchádzajú, platia rozhodnutia tohto súboru.**
> Ďalšie súbory priečinka pribudnú s prípravou bloku (fakty z kódu, mockup, packages).

## 1 · Rozhodnutia

| # | Téma | Rozhodnutie | Kedy |
|---|---|---|---|
| C1 | Prečo a čo | zvyšok V1-03 vo **Výstupoch**: pri položke **bez väzby na Demos** ručné overenie ceny na jeden klik — **„cena sedí"** (zapíše dnešný dátum overenia, cena sa nemení) a **„zmeniť"** (nová cena + dátum); **klik na odkaz sám nič nezapisuje** | 6.9. |
| C2 | Odkazy | položka nesie **zoznam odkazov** (obchody sa menia), rýchly preklik; **cena je vždy jedna** | 6.9. |
| C3 | „Na faktúru" | prepínač ×1,2 **vyradený** — existuje prepínač s DPH / bez DPH | 6.9. |
| C4 | Kovanie | katalógové kovanie má od CENY-KOV **jeden hlavný odkaz** a akciu **„Overiť cenu"** (katalóg aj Rozpočet); **viac odkazov a materiály/ABS ostali** na tento blok | 10.9. |
| C5 | Štart bloku | blok sa robí **teraz ako posledný kódový bod V1** (nie „keď si to prax vypýta") — po ňom je V1 rozsah Výstupov prázdny | 29.9. |
| C6 | Rozsah (Q1) | **áno** — rovnaký vzor ako kovanie: pri doske a ABS **bez Demos väzby** ikona „Otvoriť produkt" + akcia „Overiť cenu" (formulár, „Potvrdiť cenu k dnešku") v **Štúdiu → Materiály aj v Rozpočte**; Rozpočet ukazuje vek ich ceny a počíta ich medzi ceny „na kontrolu"; UNI a duplák bez akcií | 29.9. |
| C7 | Odkaz (Q2) | **jeden odkaz** na položku ako pri kovaní — **mení C2** (zoznam odkazov sa nerobí; zmena obchodu = prepísať odkaz) | 29.9. |
| C8 | Cena vo formulári (Q3) | dosky: cena sa zadáva **za platňu**, plugin ju prepočíta na €/m² podľa formátu a formulár ukáže obe; ABS za bežný meter | 29.9. |
| C9 | Postup (Q4) | **sedí** — bez novej outside-in rešerše (vzor aj rešerš z CENY-KOV 10.9.), krížový audit bloku nahradí povinný Codex audit návrhu každej dávky; dávky **CENY-M1** (dáta + Štúdio → Materiály) → **CENY-M2** (Rozpočet) | 29.9. |
| C10 | Reálna zákazka | test na kompletnej reálnej zákazke (V1 bod 1 „Návrh") **až po V1** — Michal teraz nemá zákazku, na ktorej by ho spravil; **po dobehnutí bodov pred V1 (blok CENY, R-13) určí ďalší postup** | 29.9. |

## 2 · Otázky pre Michala — zodpovedané 29.9.2026 (C6–C9)

Podklad: [FAKTY_Z_KODU_2026-09-29.md](FAKTY_Z_KODU_2026-09-29.md) — zo 76 nákupných záznamov je bez Demos väzby len 5 (2× DTDL, zástena, sklo, 1 ABS; 3 bez ceny)
a dnes sú v Rozpočte prakticky neviditeľné. Michal odpovedal: **Q1 áno · Q2 jeden · Q3 za platňu · Q4 sedí** (C6–C9); detaily UI idú do mockupu
ako body „návrh — potvrdí Michal".

| # | Otázka | Návrh orchestrátora |
|---|---|---|
| Q1 | Rozsah | rovnaký vzor ako kovanie: pri doske a ABS **bez Demos väzby** ikona „Otvoriť produkt" + akcia „Overiť cenu" (formulár, „Potvrdiť cenu k dnešku") v **Štúdiu → Materiály aj v Rozpočte**; Rozpočet začne ukazovať vek ich ceny a počítať ich medzi ceny „na kontrolu". UNI a duplák bez akcií (UNI nemá nákupnú cenu, duplák sa oceňuje zdrojovou doskou) |
| Q2 | Jeden odkaz alebo zoznam | **jeden odkaz** ako pri kovaní (zmena obchodu = prepísať odkaz); zoznam by kvôli jednotnosti znamenal prerobiť aj kovanie |
| Q3 | Cena vo formulári | zadáva sa **za platňu** s automatickým prepočtom na €/m² podľa formátu (obchody uvádzajú cenu za platňu), formulár ukáže obe; ABS za bm |
| Q4 | Postup bloku | nová outside-in rešerš sa nerobí (vzor aj rešerš existujú z CENY-KOV 10.9.2026); krížový audit bloku nahradí **povinný Codex audit návrhu** každej dávky (mení formát katalógu). Dávky: **CENY-M1** odkaz + overenie v Štúdiu (dáta a Materiály) → **CENY-M2** Rozpočet |
