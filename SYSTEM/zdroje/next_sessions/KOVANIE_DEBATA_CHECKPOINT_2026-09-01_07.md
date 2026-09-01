# KOVANIE — debata checkpoint 2026-09-01 #07

> Working debate checkpoint. Nie je to implementačný spec. Zachytáva rozhodnutia po prvom Orchestrator/Fable 5 review a následnej diskusii s Michalom.

## Uzavreté rozhodnutia po review

### H1 — výklopy V1
**Rozhodnutie: HK + HL vo V1, HF mimo V1.**

- Dátová sonda s 8× HL setmi bola pravdepodobne skreslená jednou zákazkou; frekvencia preto nie je rozhodovací dôvod.
- Architektonický dôvod: HK aj HL sú stále jeden front + jeden lift mechanizmus; líši sa najmä dráha pohybu, ktorá V1 architektúru zásadne nemení.
- HF je dvojfrontová spoločná mechanika a otvára assembly-owner/lifecycle/split komplexitu, preto ide mimo V1.
- HF musí byť možné riešiť cez ad-hoc/Ostatné kovanie.

### H2 — zásuvkové výpočtové rodiny
**V1 implementačné archetypy: Atira + Quadro.**

Cieľ však nie je iba podpora dvoch konkrétnych produktov, ale dve všeobecné výpočtové rodiny:

1. **Kovové zásuvkové systémy:** Atira → neskôr StrongBox a TANDEMBOX Antaro.
   - veľmi podobný výpočtový základ,
   - rozdiely najmä v sete komponentov a niekoľkých technických premenných/receptových parametroch.

2. **Celodrevené zásuvky na skrytom výsuve:** Quadro → neskôr Blum TANDEM.
   - podobná geometria boxu, výplní a mechaniky,
   - menia sa technické odstupy, dĺžky, spojky/výsuvy a systémové parametre.

Atira a Quadro majú overiť, že receptový model je dostatočne všeobecný, aby sa ďalšie systémy dali pridávať prevažne dátovo, nie kopírovaním resolvera.

### H3 — editor receptov
**Rozhodnutie: bez UI editora receptov vo V1.**

- Recepty Atira/Quadro budú auditované, verzované technické dáta v repo a kryté testami.
- Nové systémy alebo opravy vzorcov sa robia vývojom/agenta, nie cez používateľský editor.

### H4 — pamäť konfigurácie
**Rozhodnutie: automatická obnova + revalidácia, bez restore dialógu.**

Príklad: `Zásuvka → Dvierka → Zásuvka` obnoví poslednú zásuvkovú konfiguráciu a znovu ju prevaliduje. Žiadne `Obnoviť poslednú / Použiť predvolené` vo V1.

### H5 — lifecycle/verzie setov
**Rozhodnutie: iba Active / Inactive + projektový snapshot + informácia o novšej verzii.**

- `Deprecated` sa vo V1 nepridáva.
- Staré zákazky ostávajú reprodukovateľné cez snapshot.

### H6 — smer jednokrídlových dvierok
**Rozhodnutie: `Neurčený` + warning; final output blokuje ERROR, kým smer nie je určený.**

- žiadna heuristika/inferencia smeru vo V1,
- žiadny pevný L/R default.

### H7 — ad-hoc / Ostatné kovanie
**Rozhodnutie: riešiť skoro vo V1. Veľká day-one hodnota.**

Je to kontrolovaný escape hatch, nie odpadkový kôš:

- čo Engine spoľahlivo vie → automatizuje,
- čo ešte nevie alebo je atyp → používateľ pridá manuálne,
- manuálne položky stále majú ownera, množstvo, provenance a idú do spoločného nákupného/výrobného výstupu.

Príklad: HF mimo V1 sa môže vypočítať externe a konkrétne komponenty sa manuálne priradia tam, kam patria; vo výrobe je stále jasné „toto ide sem“.

### H8 — updater / verzovanie klientov
**Rozhodnutie: rovnaká aktuálna verzia pluginu na oboch pracovných PC je podmienka V1 Kovania.**

- D-52/updater je prerequisite pre schema bumpy.
- Nepodporovať paralelnú plnú kompatibilitu starej a novej verzie pri write operáciách.
- Staršia/nekompatibilná verzia má radšej odmietnuť prestavbu alebo prepnúť knižnicu do bezpečného read-only režimu než ticho poškodiť dáta.

## Architektonické námietky Orchestratora — uzavreté

### C1 — funkčné zóny
**Rozhodnutie: vo V1 iba vypočítaný SPACE/CONTEXT, nie perzistentný objekt.**

Zachovať doménový princíp `OWNER != SPACE/CONTEXT`, ale implementovať napr. `context_for(owner)` → `clear_width`, `clear_height`, `clear_depth`.

Bez:
- vlastnej identity funkčnej zóny,
- lifecycle,
- samostatnej vrstvy/tree,
- parent overrideov.

### C2 — mechanical assembly owner
**Rozhodnutie: žiadny nový first-class assembly owner vo V1.**

- owner = existujúce čelo/dielec,
- `Zásuvková zostava` / `Výklopná zostava` môže byť logický/UI pojem,
- ale nebude mať vlastnú perzistentnú owner identitu.

Odloženie HF odstraňuje hlavný V1 dôvod pre multi-front assembly owner.

### C3 — restore last config
Uzavreté cez H4: **automaticky obnoviť + revalidovať, bez dialógu.**

### C4 — revision lifecycle
Uzavreté cez H5: **Active / Inactive + snapshot + new-version info.**

### C5 — locky/resolver
**Rozhodnutie: rozšíriť existujúce `hardware_overrides`; nevytvárať nový všeobecný lock framework.**

Manuálny override konkrétnej osi je zároveň jej lock a má vyššiu prioritu než automatický resolver.

### C6 — technické varianty
**Rozhodnutie: kompozičné osi + recept; nie kartézsky katalóg kompletných variantov.**

Príklad osí: systém/family, dĺžka, výška, nosnosť, opening mode, relevantné systémové parametre. Konkrétny výsledok sa skladá resolverom/receptom.

Toto je zásadné pre budúce rodiny Atira→StrongBox/Antaro a Quadro→TANDEM.

### C7 — validácia
**Rozhodnutie: použiť existujúcu Kontrolu + existujúce final/export gates.**

Nevytvárať paralelný validačný framework pre Kovanie. Kovanie iba pridá svoje issues do existujúceho validačného kanála a využije existujúce blokovanie finálneho výstupu.

## Stav po checkpoint #07

Po review sa V1 výrazne zoštíhlila bez straty hlavného doménového smeru:

- menej nových perzistentných entít,
- menej paralelných lifecycle/validation systémov,
- resolver stavia na existujúcich override primitives,
- dva výpočtové archetypy zásuviek namiesto širokej plošnej podpory,
- HK + HL namiesto architektonicky drahého HF,
- ad-hoc/Ostatné je zámerná súčasť architektúry a poistka proti prehnanej automatizácii.

Ďalšie body review sa majú uzatvárať po jednom pred návratom balíka Orchestratorovi.
