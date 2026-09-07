# V1 debata · drobné dlhy — D-106, D-10, D-51, hmotnosť a hustota (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (okno „V1 plánovanie po KOVANÍ") · auditované proti kódu: ČIASTOČNE (`materials.rb`
> register typov s hustotou, `density_for`; KOV-E/F packages v PLANe).
>
> Pred implementáciou platí postup z [README.md](README.md).

## Rozhodnutia (Michal 6.9.)

| Položka | Rozhodnutie |
|---|---|
| **D-106** predbežná cena korpusu v Základných | **mimo V1** (zásobník) |
| **D-10** čelá ťahaním v náhľade | **mimo V1** (zásobník) |
| **D-51** štandard veľkostí okien | **uzavreté ako vyriešené** — veľkosť okien je OK (Inspector 470 × 810 z UI-B1, satelity zanikli v Štúdiu); plný text v archíve |

## Hmotnosť a hustota — stav (odpoveď na Michalovu otázku)

- **Hustota je hotová ako vlastnosť TYPU** (dávka M-C, rozhodnutie 2.8.): register kanonických typov v `materials.rb` nesie default kg/m³ — DTDL 680 · MDF 750 · HDF 870 ·
  PD 680 · zástena 680 · kompakt 1350; typ „iný" a UNI = nič (nikdy vymyslená váha). `Materials.density_for(záznam)` ju vracia; per-záznam override **až keď prax vypýta** (mimo V1).
- **Hmotnosť čela sa nikde nezobrazuje** — nie je to samostatná položka. Spotrebuje ju až blok KOVANIE: **KOV-E** (výklopy podľa hmotnosti čela — rozmery × hrúbka × hustota,
  tabuľky HK/HL z **oficiálnych** Blum hodnôt, PDF follow-up pred zápisom) a **KOV-F** (závesy = max(výška, hmotnosť); hmotnostné prahy **dodá Michal / oficiálne**).
  Hustota nil → konzervatívny odhad + ORANGE (fail-closed).
- Čo teda ešte treba: **nie hustotu**, ale **hmotnostné tabuľky výrobcov** pre E a F (Blum AVENTOS HK/HL, prahy závesov). Obe sú vo V1 v rámci KOVANIA; nič ďalšie sa neplánuje.
- Reprodukovateľnosť: hustota sa pri použití **zmrazí do modelu** (POJMY: density vstupy sa zmrazia ako sety), živý register je len default.
