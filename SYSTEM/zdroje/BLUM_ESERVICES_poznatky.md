# Blum e-services — poznatky pre Noxun System (research 15.7.2026)

> Web research (sonnet agent) — e-services.blum.com je za prihlásením, čerpané z oficiálnych stránok, PDF katalógov a stolárskych fór. Účel: inšpirácia pre pravidlový engine a UX čiel/kovania.

## Nástroje Blum

**Product Configurator** (1 kus kovania) · **Cabinet Configurator** (celá skrinka + kolízie; nástupca DYNAPLAN) · **EASYSTICK** (nie plánovač — nastavenie dorazov vŕtacieho stroja zo súboru) · Order Management · Product Database · CAD/CAM Data Service.

## Logika výberu kovania (overené pravidlá — vstup pre náš rules engine)

**CLIP top pánty — počet podľa HMOTNOSTI dvierok** (šírka do 600 mm):
| Hmotnosť | Pánty |
|---|---|
| 4–6 kg | 2 |
| 6–12 kg | 3 |

Dvierka širšie 600–650 mm → +1 pánt. Veľké skrine: 5 pántov do 22 kg, 6 do 27 kg, 7 do 32 kg.
→ **Dôsledok pre nás:** náš systém pozná materiál (hustotu) aj rozmery čela → **hmotnosť dvierok vieme dopočítať automaticky** (Blum: „materiál → hmotnosť sa dopočíta"). Pravidlá pántov teda môžeme stavať na hmotnosti (presnejšie ako len výška) — výškové pásma nechať ako fallback.

**AVENTOS (výklopy) — dvojkrokový výber:**
1. Typ mechanizmu podľa výšky skrinky a spôsobu otvárania: HF 480–1219 mm (skladacie), HS 350–800 (celé hore a cez), HL 300–580 (paralelný zdvih), HK 205–610 (klasický výklop), HK-S 186–610, HK-XS 238–610 (min. hĺbka 100), HKi 162–610. Šírky do 1828 mm.
2. Sila: **Power Factor LF = výška skrinky [mm] × hmotnosť dvierok [kg]** (rukoväť ×2) → tabuľka → konkrétny mechanizmus. Široké/ťažké → 2.–3. mechanizmus (stredový +50 % únosnosti).
AVENTOS HF pánty medzi dielmi: 3 od šírky 1200 mm alebo 12 kg; 4 od 1800 mm alebo 20 kg.

**Výsuvy (LEGRABOX/TANDEMBOX/MERIVOBOX):** nosnosť (30/40/65/70 kg) si volí POUŽÍVATEĽ; systém obmedzí dostupné dĺžky. **Min. vnútorná hĺbka skrinky = NL + 3 mm** (NL = nominálna dĺžka výsuvu). Rozsahy NL: LEGRABOX 40 kg → 270–600; 70 kg → 450–650; TANDEMBOX 30 kg → 270–600; 65 kg → 450–650; MERIVOBOX 40 kg → 270–600; 70 kg → 450–600.

## UX princípy na prevzatie

1. **Číselný vstup namiesto kreslenia** — rýchlejší pri opakovanej práci (potvrdené stolármi na fórach; pozor na vstupnú bariéru pre nováčika).
2. **Filtrovať len validné možnosti** — nevalidné voľby vôbec nezobrazovať; polia ukazujú platný rozsah.
3. **Okamžitá validácia pri zadaní**, nie až na konci; defaulty navrhnuté, prepísateľné.
4. **Kontrola kolízií celku ako posledný krok** (= náš semafor).
5. **„My Library" šablóny** naprieč projektmi — potvrdzuje náš NOXUN_KOVANIE_TEMPLATE koncept.
6. **BXF (Blum Exchange Format)** — JEDEN strojovo čitateľný výstup nesúci všetko (rozmery dielca + vŕtania + kovanie). Poučenie z fór: viacero exportov s rôznym obsahom mätie (vŕtacie dáta nesie len jedna konkrétna voľba exportu). → Náš interný dátový model dielca je presne tento koncept; exporty z neho.

## Kde môžeme byť LEPŠÍ než Blum

- **Obojsmerné locky:** Blum ide len rozmery+hmotnosť → kovanie. Opačný smer („zafixuj konkrétny typ kovania → over/obmedz rozmery skrinky") NEPONÚKA — pre nás reálna pridaná hodnota (Michalov „lock" koncept pri čelách presne do toho zapadá).
- UX trenie u Bluma (podľa fór): neprehľadný layout, skryté ukladanie, nejasné poradie krokov — nerobiť.

## Neoverené / za prihlásením

Presná podoba UI, „reset to default" indikácia, najnovšie LF tabuľky top-generácie (princíp platí, čísla sa mohli posunúť — pred implementáciou pravidiel overiť aktuálny katalóg).
