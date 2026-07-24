# Noxun System — vízia (v0.1, 15.7.2026)

> Plánovací dokument nového komplexného systému. Toto je živý dokument — dopĺňa sa pri každom plánovacom sedení.
>
> **Stav k 24.7.2026 (v0.5.0):** vrstvy 1–3 a 5 stavebného poradia STOJA (štandard → referenčný korpus → zóny/čelá/childy → výstupy s VEPO validáciou a semaforom); vrstva 4 (kovania engine) má hotovú fázu 1 (pravidlá/flagy), katalóg a ceny = V0.6. Princíp „Hybrid DC + Ruby" bol prekonaný praxou — korpusy aj childy generuje čistý Ruby (regenerate pattern), DC most ostáva len pre budúce čierne skrinky (Atira). Meradlo úspechu (manželka dostane výstupy bez SketchUpu) čaká na cenovú vrstvu V0.6.

## Cieľ jednou vetou

Z modelu skrinky v SketchUpe sa **bez ručného prepisovania** dostanem ku kompletným výrobným a obchodným podkladom: kusovník dielov, ABS hrany, kovanie s kódmi, ceny, rozpočet a objednávky — a skrinky skladám z modulov namiesto hodín manuálnej práce.

## Používatelia

- **Michal** — návrh: vkladá korpusy, pripája childy (šuflíky, dvierka, priečky, doplnky), nastavuje rozmery. Power-user SketchUpu.
- **Manželka** — ceny a rozpočty: potrebuje z modelu dostať cenovú ponuku a objednávkový sumár **bez znalosti SketchUpu a bez komplikovaných krokov**. Dnešný KOVANIE workflow je pre ňu príliš zložitý — preto sa kovania reálne nepoužívajú. Toto je hlavné meradlo úspechu výstupnej vrstvy.

## Workflow

**Dnes:** zameranie (Bosch GLM 50C, MagicPlan) → SketchUp model → DC skrinky (vnútro natvrdo, prepínané cez Hidden) → OpenCutList → ručné dopĺňanie → VEPO objednávka → prípadne CNC/Vectric. Kovania a ceny sa riešia ručne alebo vôbec.

**Cieľ:** zameranie → SketchUp → **vložím korpus → panelom pripájam childy do vnútorných priestorov** → systém automaticky prideľuje flagy (3 čelá → 3× šuflík; 2 dvierka výšky H → N závesov) → na konci priradím konkrétne katalógové kódy (raz — systém si mapovanie pamätá) → **jeden klik: kusovník + ABS + kovanie + ceny + rozpočet + objednávkový sumár** (VEPO pipeline zostáva).

## Rozhodnutia (15.7.2026)

1. **Nelepíme na staré.** ~90 % existujúceho sa prerobí; nestaviame medzivrstvy nad starými DC skrinkami (zamietnutá „Fáza 1 — autocesta na existujúcich skrinkách").
2. **Zostávajú ako funkčné súčiastky:** `Noxun_Pick`/V2fable vkladanie, `snaper`. **OCL aj `vepo_exporter` sa časom úplne vyhodia** (rozhodnutie 15.7.2026) — z každého extrahujeme užitočnú logiku (VEPO formát už zachytený v `03_VYSTUP_vepo_kontrakt.md`; z OCL: výpis materiálu, ABS, orientácie) a nový systém generuje výstupy priamo, bez export-z-exportu. OCL dočasne zostáva len na krížovú validáciu prvých výstupov.
3. **Prerába sa:** celý kovania engine sa **presunie do nového pluginu** (z KOVANIE si berieme funkčné bloky: CatalogStore, search, Demos import, export engine); **všetky dynamické komponenty** sa prerobia na nový systém (dnešné majú vnútro natvrdo + Hidden prepínanie).
4. **Poradie: najprv štandard a návrh, potom kód.** Neponáhľame sa — sila systému > rýchlosť dodania. (Presne to potvrdzuje GPT audit: koreňová príčina všetkých problémov = chýbajúci jednotný „Noxun Component Standard".)
5. Popri plánovaní zlepšujeme spoluprácu: MCP SkAgent (nainštalovaný 15.7.), poriadok v zložkách a dokumentoch.

## Referenčné skrinky súčasného stavu (na analýzu, nie ako vzor riešenia)

`COMPONENTS V2\1 Nové Dynamicke\`: **Horná HF.skp**, **Master.skp** (schéma: `STARE\_dev\DC_SCHEMA.md`), **Spotrebičová.skp**, **Sufliková 2x.skp**. Vnútorné komponenty natvrdo, skrývané cez Hidden — to je presne to, čo nový systém nahradí pripájaním.

## Vrstvy nového systému (stavebné poradie)

1. **ŠTANDARD** — Noxun Component Standard: jednotný kontrakt komponentu, dielca, atribútov, osí, hrán, identity, slotov. → `01_STANDARD.md` (osnova v `archiv/`)
2. **REFERENČNÝ KORPUS** — jedna „nudná", dokonale definovaná skrinka podľa štandardu; validácia proti OpenCutList a VEPO. Až keď funguje, škáluje sa na typy.
3. **CHILDY + PRIPÁJANIE** — šuflíky, dvierka, police, priečky ako moduly pripájané do vnútorných priestorov (ArchiWood princíp); panel na vkladanie a nastavovanie.
4. **KOVANIA ENGINE (nový plugin)** — pravidlá ako dáta (JSON): flagy automaticky z konfigurácie skrinky; two-phase: generický flag → konkrétny kód; katalóg a ceny z KOVANIE blokov.
5. **VÝSTUPY** — kusovník, ABS, kovanie, ceny, rozpočet, objednávky (VEPO), kontrola pred odovzdaním („semafor"). Persona: manželka.

## Princípy

- **Pravidlá ako dáta, nie kód** — počty závesov, výnimky hranovania, mapovania kódov si Michal edituje bez programovania.
- **Automatika namiesto možností** — menej tlačidiel, viac odvodenia z modelu (opak ArchiWood 81 ikon).
- **Hybrid DC + Ruby** — DC engine na vnútornú geometriu dielcov, Ruby na vkladanie, resize, flagy, výstupy. (DC nevie za behu pripájať childy — viď docs\DC_PRAVIDLA.md.)
- **Dáta na inštancii, autorita nominálov, jednotný slovník** — poučenia z DC_SCHEMA a ročnej GPT histórie (tri jednotkové svety, _name vs. definícia, zdieľané definície).
- **Každá vrstva samostatne otestovateľná** — cez MCP SkAgent priamo v SketchUpe.

## Zdroje

- `zdroje\GPT_audit_historie_sketchup.md` — ročná história riešení a problémov (ChatGPT audit)
- `STARE\_dev\DC_SCHEMA.md` — detailná schéma súčasného Master komponentu
- `docs\` — SKETCHUP_PRAVIDLA, DC_PRAVIDLA, ARCHIWOOD_INSPIRACIA
