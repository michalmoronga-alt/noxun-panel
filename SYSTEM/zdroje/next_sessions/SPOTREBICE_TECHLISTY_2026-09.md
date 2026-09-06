# SPOTREBIČE — technické listy: zoznam objednávaných modelov a čo z listov potrebujeme (predúloha S1)

> Stav: KONCEPT — neimplementovať priamo · zdroj: predúloha z [V1_DEBATA_2026-09-06_SPOTREBICE.md](V1_DEBATA_2026-09-06_SPOTREBICE.md) §4 · dáta: firemný Disk (tabuľky
> „VYBAVENIE <zákazník>") + objednávky NAY v pošte (6.9.2026, čítané cez konektory) · technické listy: Antigravity outside-in (§3, dopĺňa sa) · auditované proti kódu: nie.
>
> Pred implementáciou platí postup z [README.md](README.md).

## 1 · Odkiaľ zoznam vznikol

- **Disk:** tabuľky „VYBAVENIE" per zákazka — Medzihradský (3 verzie 2025–2026), Bella (2025), Trochtová (2025), Hurbanová (2025), Szebellai (bez kuchynských spotrebičov).
  Štruktúra: kategória · názov modelu · odkaz na obchod (NAY / Alza / drezyonline) · cena · poznámky · často **varianty „ALEBO"** (2–3 alternatívy pre zákazníka).
- **Pošta (noxuninfo):** objednávky NAY č. 8842501257 (10.10.2025, 6 spotrebičov) a 7323216251 (13.10.2025, 3 spotrebiče) = reálne kúpené kusy (zákazka Bella);
  staršie faktúry NAY 2023–2024 (PDF prílohy, nečítané).
- Michalov vlastný zápis mikrovlnky Bosch BFL7221B1 (V1 debata 6.9.) = vzor, čo od listu čakáme.

## 2 · Modely podľa kategórie (★ = objednané / opakuje sa, ostatné = ponúkané ako varianta)

| Kategória | Model | Kde | Poznámka |
|---|---|---|---|
| **Rúra** | ★ Whirlpool OMSR58RU1SB (STEAM+) | Bella (objednaná), | 299 € |
| Rúra | Whirlpool WOI9A8PT2SBA (W Collection) | Trochtová | set s mikro na Alze |
| Rúra | Bosch Serie 8 HBG774KB1 (pyrolýza) | Medzihradský | alternatíva Electrolux EOE8P39H |
| Rúra | Bosch HBF153EB0 (Séria 2) | Hurbanová | Alza |
| **Mikrovlnka** | ★ Whirlpool MBNA900B (New Actual) | Bella (objednaná) | 239 € |
| Mikrovlnka | Whirlpool WMD7O4TB | Trochtová | set s rúrou |
| Mikrovlnka | Bosch Serie 8 BFL7221B1 | Medzihradský | Michalov vzorový zápis rozmerov; alternatíva Electrolux LMS4253TBK |
| Mikrovlnka | Bosch BFL623MB3 (Séria 2) | Hurbanová | Alza |
| **Chladnička vstavaná** | ★ Beko Beyond BCNA306E5ZSN | Bella (objednaná) | 639 € |
| Chladnička vstavaná | Whirlpool ART 97101 2 | Hurbanová | Alza |
| Chladnička voľne stojaca | Whirlpool WHSD18A011B2 / Beko B3BLNC305SW (+ mrazničky) | Medzihradský | **mimo S1** (voľne stojace) |
| **Umývačka 60** | ★★ Whirlpool WIO 3O540 PELG (Supreme Clean) | Bella (objednaná), Trochtová | **opakuje sa** |
| Umývačka 60 | Bosch SMD8TCX04E / Gorenje ULTRA16BWIFI / Electrolux EEG68600W | Medzihradský | varianty |
| Umývačka 45 | Bosch SPV6EMX05E | Hurbanová | Alza |
| **Varná doska** | ★ Whirlpool WL B1160 BF (i100, 60) | Bella (objednaná) | 289 € |
| Varná doska | Electrolux EIV63443CT (60) / EIV84550 (78) | Trochtová | |
| Varná doska | Bosch PUG611AA5E | Hurbanová | |
| Varná doska s odsávaním | Bosch PVQ731H26E / Elica NIKOLATESLA FIT BL/A/72 | Medzihradský | **mimo S1** (downdraft) |
| **Digestor** | ★ Whirlpool WCT3 63F LTK | Bella (objednaný) | 255 € |
| Digestor | Elica FOLD BL MAT/A/52 | Hurbanová | |
| Drez / batéria / dávkovač | Blanco, Alveus, Franke, Schock (drezyonline) | Bella, Trochtová, Hurbanová | len cenová položka + výrez PD |

**Záver pre seed:** prioritné modely na technické listy = **Whirlpool rad (OMSR58RU1SB · MBNA900B · WIO 3O540 PELG · WL B1160 BF · BCNA306E5ZSN)** ako reálne kúpená sada,
**Bosch BFL7221B1 + HBG774KB1** (Michalov vzor + prémiová alternatíva), **Whirlpool ART 97101 2** (druhá vstavaná chladnička), **Bosch SPV6EMX05E** (jediná 45 cm umývačka).

## 3 · Technické listy — čo výrobcovia uvádzajú (dopĺňa Antigravity research)

*(sekcia sa doplní po dobehu agy behov — tabuľka model × rozmery: telo Š×V×H · čelo Š×V · nika min–max Š×V×H · presahy · odvetranie · medzera rúra + mikro nad sebou)*

## 4 · Čo z toho engine potrebuje (návrh po researchi)

*(doplní sa)*
