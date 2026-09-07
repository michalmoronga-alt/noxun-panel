# V1 debata · bod 7 DVAJA POUŽÍVATELIA — Lucia, zdieľané knižnice (D-48), prílohy (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (okno „V1 plánovanie po KOVANÍ") · auditované proti kódu: ČIASTOČNE (existujúce vzory: revízny
> odtlačok Štúdia, `JsonFileStore` + `.bak`, brány R-11/R-12, updater D-52 s distribučným priečinkom, náhľady šablón cez base64 kanál) · task package vznikne **až po uzávere V1**
> (rozhodnutie Michala nižšie) a po `codex-audit` (nový modul + zápis do všetkých katalógov).
>
> Pred implementáciou platí postup z [README.md](README.md). Nadväzuje na [05_SHARED_LIBRARY_UPDATE.md](05_SHARED_LIBRARY_UPDATE.md) — tento dokument ho **rozhoduje** (tvar D-48).

## 0 · Rozhodnutia (Michal 6.9.)

| Téma | Rozhodnutie | V1? |
|---|---|---|
| Zdieľanie knižníc medzi 2 PC (D-48) | **ÁNO, ale MIMO V1 — prvá funkcia po uzávere V1 („V1.10")**, v tvare §1 (verzie + Odoslať / Aktualizovať + konflikt per katalóg) | po V1 |
| Čo sa zdieľa | **všetko:** materiály · šablóny (aj náhľady) · katalóg kovania · sety · výrobcovia/rady · spotrebiče (aj prílohy) · **nastavenia rozpočtu a dodávateľa** | po V1 |
| Odoslať / Aktualizovať | **naraz** pre všetky katalógy (riadok per katalóg so stavom), konflikt sa rieši **per katalóg, ručne** (výber verzie) | po V1 |
| Štart pluginu | verzie len **porovná a oznámi**; sťahovanie je vždy klik | po V1 |
| Zdieľaný koreň | **`H:\Môj disk\NoxunENGINE data`** (firemný Google Disk, zrkadlený na oboch PC — Michal vytvoril 6.9.) | pripravené |
| Lucia | **od 6.9. prvýkrát testuje** (plugin nainštalovaný na jej notebooku); po uzávere V1 sa jej plugin preinštaluje **raz**, ďalej updater (D-52) + knižnice cez Odoslať/Aktualizovať | — |
| Prílohy spotrebičov (galéria) | V1 **len lokálne** (`%APPDATA%`), záznam nesie **relatívne cesty**, aby sa priečinok dal po V1 presunúť do zdieľaného koreňa bez migrácie záznamov | V1 (v S1) |

Michalov dôvod: „všetko vo V1 je perfektný balík, po uzávere obaja môžeme naplno používať — a ja už iba doručujem update packy: nové dogfoodingy od Lucie a mňa a naplánované bloky po V1."

## 1 · Tvar riešenia (dohodnutý, na package po V1)

Nie zámok, ale **optimistické verzovanie** (vzor revízneho odtlačku Štúdia): pracovná kópia ostáva lokálne v `%APPDATA%`; v zdieľanom koreni je každý katalóg ako súbor +
**manifest** (katalóg · verzia · dátum · meno PC) + podpriečinky so súbormi (prílohy, náhľady šablón). Lokálny katalóg si pamätá **základnú verziu** (z ktorej zdieľanej vznikol) a
či má lokálne zmeny.

- **Odoslať — kolízne bezpečne (Codex #322 P1: Google Disk nedáva zámok ani CAS, samotné „prečítaj tesne pred zápisom" okno TOCTOU nezavrie):** publikácia
  **nikdy neprepisuje zdieľaný súbor**. Každé odoslanie zapíše **nemenný artefakt** `<katalóg>.r<rev>.<pc>.json` (unikátne meno = verzia + meno PC, nikdy sa neprepisuje) a
  až potom **manifest** (ukazovateľ na víťazný artefakt, zapísaný cez dočasný súbor + premenovanie, posledný). Konflikt sa **nedetekuje len z manifestu**: klient číta **všetky
  artefakty** — dva artefakty tej istej verzie z rôznych PC = konflikt viditeľný na oboch stranách, nič sa nestratí (oba ostávajú), používateľ vyberie víťaza a ten sa
  zapíše ako `r<rev+1>`. Navyše **advisory zámok** `publish.lock` (PC + čas, TTL ~10 min) ako prvá bariéra — Disk ho môže doručiť neskoro, preto je len pomocný, nie
  garancia. Zdieľaná verzia == základná → zápis; zdieľaná novšia → konflikt (nižšie). Zdieľaná novšia → **konflikt**: okno povie katalóg,
  kto/kedy zmenil, koľko lokálnych zmien; výber **prepísať zdieľaný mojou** / **zahodiť moje a prevziať** / zrušiť. Nič potichu.
- **Aktualizovať:** zdieľaná novšia a bez lokálnych zmien → prevzatie (so `.bak`); s lokálnymi zmenami → ten istý konfliktný výber. Prevzatie ide **cez zápisovú cestu store**
  (assess, brány std/schema), nie kopírovaním súboru — katalóg z novšieho pluginu sa odmietne s odkazom „najprv aktualizuj plugin" (D-52; distribučný priečinok pluginu môže byť
  podpriečinok toho istého koreňa).
- **Verzia = celý katalóg** (nie záznam). Zlučovanie po záznamoch len ak by konflikty boli časté.
- **Štúdio → O plugine:** riadok per katalóg „Materiály rev. 42 · zdieľaná rev. 43 ↑" (mockup v koncepte 05), tlačidlá Odoslať / Aktualizovať, pri štarte len oznámenie.
- **Súbory** (prílohy, náhľady): žijú **len v zdieľanom koreni**, názvy podľa id, bez lokálnej kópie; bez Disku sa neukážu a plugin to povie.

## 2 · Riziká (zapísané, opatrenia v package)

1. Oneskorenie Disku → obaja vidia tú istú základnú verziu a obaja odošlú → **rieši §1: nemenné artefakty per publikácia + manifest posledný + čítanie všetkých artefaktov** (nikdy tichá strata, konflikt vidia obaja); advisory zámok len pomáha. Reziduálne: manifest z dvoch PC = dve kópie manifestu od Disku → klient berie artefakty ako pravdu, manifest len ako ukazovateľ.
2. Rozdielne verzie pluginu → brány R-11/R-12 odmietnu novší katalóg → hláška na updater.
3. Rozpísaný súbor počas synchronizácie → dočasný súbor + premenovanie (existujúci vzor).
4. Zákazka s materiálom, ktorý druhé PC nemá → snapshot na skrinke je autorita, „chýba v katalógu" ako dnes pri kovaní.
5. Disk v režime „stream" namiesto „zrkadliť" → čítanie môže zaseknúť → všetky čítania s časovým limitom (vzor updatera), odporúčať zrkadlenie.

## 3 · Odhad prácnosti (Fable, 6.9.)

| Dávka | Obsah | Audit | Odhad |
|---|---|---|---|
| SYNC-1 jadro | čistý modul: nemenné artefakty per publikácia + manifest ako ukazovateľ + čítanie všetkých artefaktov (kolízia bez CAS), advisory zámok, základná verzia + lokálne zmeny per katalóg, Odoslať/Aktualizovať s konfliktmi, prevzatie cez store API každého zo 6–7 katalógov, headless testy s mutáciami | ÁNO (nový modul, zápis katalógov) | 1 PR, 1 deň + review |
| SYNC-2 UI | O plugine: riadky per katalóg, tlačidlá, konfliktný modal (D-15), oznámenie pri štarte (asynchrónne s deadline, vzor updater check) | NIE (nad kontraktom SYNC-1), in-SU smoke na oboch PC | 1 PR, 1 deň |
| SYNC-3 súbory | prílohy spotrebičov + náhľady šablón do zdieľaného koreňa (relatívne cesty, migrácia existujúcich náhľadov, zametanie sirôt) | ÁNO (migrácia) | 1 PR, 0,5–1 deň |

Spolu **3 PR, cca 3 pracovné dni** pri bežnom rytme (Opus subagent + Codex kolá + in-SU), plus **smoke na oboch PC** s reálnym Diskom (oneskorenie, konflikt vyrobený naschvál,
odpojený Disk). Najväčšia neistota: každý katalóg má vlastný store s vlastným zámkom a bránou — sync musí ísť cez ne, nie okolo nich (preto SYNC-1 audit).

## 4 · Čo ostáva v bode 7 pre V1

- **M-R FOTO** (fotka dekoru z Demosu na dielcoch; package v PLAN blok 5, audit ÁNO) — potvrdiť V1 a poradie (otázka Michalovi).
- **D-51** štandard veľkostí okien — zavrieť ako vyriešené Štúdiom, alebo dodať hodnoty (otázka Michalovi).
- **Lucia testuje od 6.9.** — jej postrehy = D-čísla do [../../DOGFOODING.md](../../DOGFOODING.md) hneď; do V1 idú tie, ktoré blokujú prácu, ostatné do update packov po V1.

## 5 · Dopad na živé dokumenty (zapracuje záverečný docs PR debaty)

- [../../V1_VIZIA.md](../../V1_VIZIA.md) bod 7: „D-48 mimo V1" ostáva, ale doplniť **tvar a poradie** („prvá funkcia po V1: Odoslať/Aktualizovať knižnice s verziami"); Lucia testuje.
- [../../PLAN.md](../../PLAN.md): blok 6 INFRA / zásobník Po V1 — D-48 dostane tento tvar + odhad + koreň `H:\Môj disk\NoxunENGINE data`; S1 package: prílohy s relatívnymi cestami.
- [../../DOGFOODING.md](../../DOGFOODING.md) D-48 (Po V1 — zásobník): stav doplniť (rozhodnuté 6.9., tvar §1).
