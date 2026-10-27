---
paths:
  - "noxun_engine/**/*.rb"
  - "noxun_engine.rb"
---

# Oblasť: Ruby kód pluginu (core / modules / ui)

> Načíta sa samo pri práci s Ruby kódom pluginu; ďalšie oblasti pridávajú vlastné súbory podľa dotknutých ciest
> (tabuľka v [POVINNE_CITANIE.md](../../SYSTEM/pravidla/POVINNE_CITANIE.md)).

**Pred zmenou Ruby kódu POVINNE prečítaj:**

- rozcestník [docs/ARCHITEKTURA.md](../../docs/ARCHITEKTURA.md) → odseky **dotknutých modulov** v `docs/architecture/`
  (Grep `^### <súbor>`; súbory mapy majú 47–257 kB, celé sa nečítajú),
- dotknuté § [SYSTEM/STANDARD.md](../../SYSTEM/STANDARD.md) (Grep `^## <číslo>.` / `^### <číslo>`; celý má 170 kB).

Architektúra sa udržiava priebežne: dávka, ktorá mení modul, prepíše JEHO odsek v `docs/architecture/` (nikdy nie text na koniec
súboru); nový modul = nový odsek aj nový riadok v tabuľke rozcestníka (guard test to stráži).

Uzáver kódovej dávky (VERSION, odsek modulu v `docs/architecture/`, STAV, KRONIKA):
[IMPLEMENTATOR.md, Verzia a uzáver dávky](../../SYSTEM/pravidla/roly/IMPLEMENTATOR.md#verzia).
