# Krížový audit V1 — rozhodnutia Michala (30.9.–1.10.2026)

> Priečinok bloku `V1_AUDIT` — autorita počas bloku. Podklad pre audítorov: [PODKLAD_KRIZOVY_AUDIT.md](PODKLAD_KRIZOVY_AUDIT.md).

## Zadanie (Michal 30.9.2026)

Ako posledný krok V1 spraviť **krížový audit všetkými providermi** s tromi cieľmi:

1. nájsť súbory a dokumenty, ktoré potrebujú **refaktor alebo upratanie** — hlavne s ohľadom na ďalšie rozširovanie po V1,
2. pozrieť sa na plugin **ako celok** a doplniť **nápady po V1**,
3. nájsť **UI/UX drobnosti a doplnky** na spríjemnenie, sprofesionalizovanie prostredia alebo zjednodušenie práce.

Výsledky si Michal prejde a spolu roztriedime: **teraz** · **zásobník** · **vyradiť**.

## Rozhodnutia

| # | Otázka | Rozhodnutie |
|---|---|---|
| V1A-1 | Rozsah | **Matica rolí** (každá os má 2 hlavné hlasy, ostatní krátky príspevok) — nie „všetci všetko". **Antigravity vyradený** z tohto auditu; jeho rolu (konkurencia, UX vzory) preberá Claude rešeršér. |
| V1A-2 | Screenshoty pre UI audit | **Robí orchestrátor** v neuloženom okne s ukážkovou kuchyňou (7 skriniek zo šablón). |
| V1A-3 | Čo znamená „teraz" | **Nechané na orchestrátora.** Michal: máme pár dní s plánom MAX a jeden reset pre Claude aj Codex — **rozumne ich minúť na hardening pred pokračovaním na funkciách**; vypísané súbory sú „dosť extrém". → definícia bloku HARDENING nižšie. |
| V1A-4 | Kvóty | Vystačia (všade plán MAX 5×, 20 % stačí aj na veľký blok); Michal sleduje spotrebu a v prípade potreby dá reset. |

## Definícia „teraz" = blok HARDENING (orchestrátor na základe V1A-3)

Blok **pred funkciami po V1**, na pár dní s jedným resetom. Obsahuje:

- **R-13 → R-37 → R-35** (už rozhodnuté 30.9. ako prvé po V1 — [../../../PLAN.md](../../../PLAN.md), „Po V1 — zásobník"),
- **vybrané položky tohto auditu**, ktoré spĺňajú všetky štyri podmienky:
  1. zmenšujú riziko alebo cenu budúcich zmien v niektorom **scenári rozšírenia** (S1–S6 v podklade),
  2. **nemenia výrobné ani cenové čísla** — preukázateľne (charakterizačné/golden testy PRED zásahom: VEPO bajtovo, kusovník, rozpočet),
  3. dajú sa narezať na dávky po ~1 dni,
  4. pri UI: len drobnosti, ktoré nič nepočítajú a nemenia dáta.

Všetko ostatné ide do **zásobníka Po V1** alebo sa **vyradí** s dôvodom. Poradie a konečný výber robí Michal pri triedení.

## Postup

0. Podklad + balíček screenshotov (orchestrátor) → 1. beh 7 audítorov paralelne → 2. spojenie (reconcile, dedup, sondy pri „už existuje / jednoduchšia natívna cesta")
→ 3. triedenie Michalom (interaktívna stránka: Teraz / Po V1 / Vyradiť + poznámka) → 4. zápis do PLAN, zásobníka a archívu → štart bloku HARDENING.
