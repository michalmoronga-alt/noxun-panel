# KOVANIE — debata k dávkam E (výklopy) a F (závesy), 8.9.2026 — CHECKPOINT rozhodnutí

> Stav: KONCEPT / checkpoint rozhodnutí Michala — nie implementačný spec, neimplementovať priamo; záväzné znenie packages KOV-W / KOV-F / KOV-E je v [PLAN.md](../../PLAN.md).

> Autorita rozhodnutí Michala pre packages **KOV-W** (hmotnosť), **KOV-F** (závesy) a **KOV-E** (výklopy) v [PLAN.md](../../PLAN.md).
> Debata prebehla v implementačnom okne po nočnej smene D-121 (main v0.9.46). Podklady: [KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md) §5,
> `noxun_engine/core/hardware_rules.rb` (seed), `hardware_sets.rb` (seed), `hardware_catalog.rb` (seed), zber Démos `_dev/demos_harvest/aventos_hk_hl_top_2026-09-08.json`.

## A. Rozhodnutia Michala (8.9.2026)

1. **Neznáma hustota** (UNI, typ bez hustoty): **rátať ťažšie** — automat beží s najvyššou hustotou doskového typu (okrem kompaktu) + ORANGE. Nikdy ticho, nikdy ľahšie.
2. **Závesy — počet:** JEDNA tabuľka Noxun (platí pre všetkých výrobcov; set rozhoduje o produkte, Blum nedostane vlastnú tabuľku).
   Výška dverí: **do 849 → 2 · 850–1700 → 3 · 1701–2200 → 4 · 2201–2400 → 5 · 2401–2600 → 6 · 2601–2800 → 7.** Guard z praxe: **šírka nad 600 mm → +1 záves** (bez podmienky výšky —
   platí aj pre široké nízke dvere). Varovania bez vplyvu na počet: šírka nad 800 (ORANGE), šírka väčšia než výška (ORANGE — „nemá to byť výklop?").
   **Hmotnosť vo V1 len varuje** (Michal: pre 18 mm DTD do 600 mm dáva Hettich prakticky to isté číslo ako výška; hmotnosť rozhoduje len pri ťažkých čelách):
   keď Hettich hmotnostné pásma chcú viac závesov než tabuľka → ORANGE; nad 22 kg → ORANGE. Neskôr sa dá prepnúť na automatický +1 bez zmeny dát.
3. **Nasadenie závesu V1 = len naložený.** Polonaložený / vložený mimo V1.
4. **Úchytky MIMO V1** (Michal: neskôr postupne aj s geometriou úchytiek; vždy 1 ks; jeden set per projekt + override per čelo).
5. **Výklopy:** rodiny **HK top a HL top**; **sklop** = závesy ako klasické/Tip-On dvierka podľa pravidiel dverí (vzpery — plynová alebo Kraby — mimo V1).
   Trieda mechanizmu = **plný automat, zámky netreba**. Výška korpusu pre LF = výška skrinky; ak výklop kryje len jeden riadok čiel vyššej skrinky, výška toho riadku.
6. **Krytky predvolene biela; čelný príchyt na skrutky (20S4200).**
7. **Seed položiek kompletný** ako D-118a (Démos URL, presný názov, cena s DPH, MJ, výrobca, rada, dátum overenia) — pred implementáciou E dostane Michal **seed tabuľku na kontrolu**.
8. D-120 (UKW aj na dolnej/bočnej hrane) → **balík Čiel**, nie F.
9. Poradie: **KOV-W (hmotnosť + D-125) → KOV-F → KOV-E → G → I.** Implementácia autonómne v tomto okne (subagenti Opus, Codex review, audity podľa pravidiel).

## B. Oficiálny algoritmus Hettich (z kódu kalkulačky hta.hettich.com, prečítané 8.9.2026)

Kalkulačka „Počet závěsů na dveře – Sensys" počíta v prehliadači (funkcia `rechnen()`):

- hmotnosť [kg] = hustota [kg/dm³] × výška × šírka × hrúbka [mm] / 1 000 000 (DTD 0,7 · MDF 0,9 · preglejka 0,45 · sklo 2,6 · hliník 2,7 · buk 0,8 · smrek 0,5 · Corian 1,6)
- pásmo hmotnosti: ≤ 7,70 → 2 · ≤ 13,70 → 3 · ≤ 17,10 → 4 · ≤ 22,00 → 5 · nad 22 kg „Höchstgewicht 22 kg überschritten"
- pásmo výšky: ≤ 1000 → 2 · ≤ 1700 → 3 · ≤ 2200 → 4 · ≤ 2400 → 5 · ≤ 2600 → 6 · ≤ 2800 → 7 · nad 2800 chyba
- **počet = max(pásmo hmotnosti, pásmo výšky)**
- šírka max 600 mm („Max. šířka 600 mm!") a šírka nesmie byť väčšia než výška („Max. šířka = Výška") — inak nepočíta

Poznámka: tabuľka prepísaná v debate (900/1600/2000/2400 s hmotnosťami 4–5/5–12/12–17/17–22) oficiálna NIE JE; náš pôvodný seed (900/1400/1900 → 2/3/4/5) bol prísnejší než Hettich.
Noxun tabuľka (A.2) berie Hettich výškové pásma a sprísňuje prvé (od 850 už 3) — dôvod: dvere tejto výšky sa na dvoch závesoch zle nastavujú (Michal).

## C. Výklopy Blum — dáta z Démosu (zber 8.9.2026, LBX API + produktové stránky)

Blum e-services (`e-services.blum.com`, konfigurátor) vyžaduje prihlásenie — bez neho je vidieť len úvod. **Démos nesie Blum hodnoty priamo na stránke** („Použiteľný v rozmedzí LF
(výška korpusu v mm × hmotnosť čela, vr. dvojnásobnej hmotnosti úchytky v kg)") a LBX API dáva cenu bez aj s DPH (`price` / `price_with_vat`), príslušenstvo a alternatívy.

**AVENTOS HK top** (sada = mechanizmus; „nutné doplniť o krytky a čelné kovanie", Tip-on verzia navyše o Tip-On jednotku):

| trieda | LF | skrutky | euroskrutky | Tip-on (skrutky) | Tip-on (euro) | cena s DPH (skrutky / Tip-on) |
|---|---|---|---|---|---|---|
| 22K2300 slabý | 420–1610 | 347810 | 378189 | 347814 | 378200 | 71,45 / 76,68 |
| 22K2500 stredný | 930–2800 | 347811 | 378190 | 347826 | 378202 | 71,45 / 76,68 |
| 22K2700 silný | 1730–5200 | 347812 | 378191 | 347827 | 378203 | 71,80 / 81,56 |
| 22K2900 najsilnejší | 3200–9000 | 347813 | 378193 | 347828 | 378204 | 84,00 / 93,77 |

Príslušenstvo: čelný príchyt 20S4200 **13781** (pár, 4,40 s DPH) · Expando 20S42E1 23789 (ks) · krytky 22K8000 bez Servo-Drive: **biela 347834** (11,27 s DPH), svetlo šedá 347833,
tmavo šedá 347835 · Tip-On jednotka pre HK top — doplniť pri seede (zber ju v tomto behu nezachytil). Eclipse čierne varianty (559521–559531) mimo seedu.
Triedy sa prekrývajú — pravidlo vyberá **najslabšiu triedu, ktorej rozsah LF pokrýva** (ceny sú takmer rovnaké; audit E to posúdi).

**AVENTOS HL top:** mechanizmus podľa výšky korpusu **22L2200 slabý (KH 300–389) 507351** · **22L2500 silný (KH 390–580) 507352** (+ euroskrutky 507353/507354);
ramená **22L3200 (300–339) 507355 · 22L3500 (340–389) 507356 · 22L3800 (390–540) 507357 · 22L3900 (480–580) 507358**; stabilizačná tyč 22Q1076U 507365 (+ predĺženie 507366);
krytky 22.8000 bez S-D **biela 507343** (12,73 s DPH), svetlo šedá 507344, tmavo šedá 507345; príchyt 20S4200 13781. **Hmotnostné limity HL top Démos neuvádza** —
otvorený údaj (Blum e-services s Michalovým loginom alebo Blum technický list); do overenia ORANGE „limit neoverený".

Staré rady (HL 20L2x00.05 = 23790–23793, ramená 197609/197610) sa dopredávajú — do seedu nejdú. HK-S / HK-XS / HKi Michal nepoužíva.

## D. Čo z toho ide do PLANu

Packages **KOV-W**, **KOV-F**, **KOV-E** (plné znenie v [PLAN.md](../../PLAN.md), blok KOVANIE). Audity: W nie (aditívne kľúče), F áno (Sol — nový kind, mapovacie kľúče, náhrada seed pravidla),
E áno (Astra — config čela, nový kind, sety, dátový balík).

## E. Audity návrhu (8.9.2026 popoludní) — čo zmenili v packages (v2)

- **Sol audit KOV-F (Codex CLI, 2 BLOCKER + 7 FIX + 1 NOTE):** starší plugin neznámy kind preskočí (žiadne závesy) → dopredná brána `CONFIG_SCHEMA` 8 → 9 + `STD` bump;
  aditívne triedne mapovanie by prepísalo vlastný výber setu → kľúče sa odvodzujú z účinného legacy mapovania a existujúci kľúč sa nikdy neprepíše; nad 2800 mm RED s nápravou
  zámkom; seed sety potrebujú úplnú klasifikáciu (výrobca povinný); per-krídlo override mimo F; obnova setov + mapovania automaticky v `ensure_project_state!`; hmotnostná
  kontrola nad výsledným počtom po zámku; prekryv pravidiel = ORANGE; editor druhu = F2; hranice pásiem Float + explicitné krídla v testoch.
- **Codex GH #327 (docs PR, 8× P1 + 6× P2):** LF s rezervou na úchytku (`handle_allowance_kg` 0,5); prekryv ramien HL 480–540 → deterministicky 22L3800; nové pole klasifikácie
  `lift_system` + verzia; sklop cez `door_hinges` (`use_type door`), `USE_TYPE_GENERIC` sa nemení; tyč HL do každého HL setu; `lift_class_missing` blokuje aj cenovú ponuku;
  zber Démos dát presunutý do repa (`SYSTEM/zdroje/demos/`); KOV-W bez nového modulu (audit netreba) a jedna sémantika odhadu; D-120 a STAV zosúladené s rozhodnutím.

