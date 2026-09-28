# DC „Rohová" — presné meranie geometrie (sonda 27. 9. 2026)

> **Zdroj:** `C:\APP DEV\RUBY\COMPONENTS V2\1 Nové Dynamicke\Rohová.skp` (DC naposledy upravený 5. 10. 2025 12:27 podľa `_lastmodified`).
> **Metóda:** dve samostatné inštancie SketchUp 2026 (26.0.429, Dynamic Components 1.8.3) spustené cez `-RubyStartup` nad **kópiami**
> v scratchpade (vzor `scripts\run_su_tests.ps1`, bez deployu pluginu). Sonda 1 = statický dump (všetky slovníky, dielce, plochy).
> Sonda 2 = vloženie DC ako komponentu do nového modelu + zmeny parametrov a zrkadlenie s DC redraw. Obe inštancie sa samy uložili
> do svojej kópie a zavreli (exit 0). Michalova inštancia (PID 182532) nedotknutá. Originál `Rohová.skp` nezmenený
> (SHA-256 pred aj po `4B81C412…2CB16D`), repo nezmenené.
> **Jednotky:** všetko v mm (zaokrúhlené na 0,1). DC ukladá dĺžky v palcoch; **vzorce DC sa vyhodnocujú v centimetroch**
> (`_lengthunits = CENTIMETERS`) — konštanta `-1.9` vo vzorci = −19 mm, `8` = 80 mm, `10` = 100 mm, `0.3` = 3 mm.

---

## 1 · Súradnicová sústava

- **Počiatok (0, 0, 0)** = ľavý predný dolný roh obrysu skrinky **na podlahe** (vonkajšia plocha ľavého boku × predná rovina korpusu × podlaha).
- **X = šírka** (0 → 1100, doprava) · **Y = hĺbka** (0 = predná rovina korpusu, +Y dozadu ku stene, 510 = zadná hrana) · **Z = výška** (0 = podlaha, 862 = vrch).
- **Predok = −Y.** Všetko pred korpusom (dvere, CR lišty, rohová výstuha) má Y < 0.
- DC je modelovaný **iba ako „dvere vľavo"**: **dverová časť X 0–450 vľavo**, **slepá časť X 450–1100 vpravo**, **roh (kút) je pri pravom boku** —
  slepá časť sa zasúva do kúta za susedný kolmý rad. Rohová zostava (CR 1, CR 2, rohová výstuha) sedí na hranici dverovej a slepej časti **pred** korpusom.
- Obrys: **12 voľných hrán (tag „Master")** tvorí drôtený kváder 1100 × 510 × 862 od podlahy — roztiahnu obrys DC až po Z 0, hoci pod dnom (Z 0–150)
  nie je žiadny dielec; sokel ani nohy modelované nie sú (§ 7).

```text
POHĽAD ZHORA (pôdorys) — predok dole (−Y), X doprava, mierka len orientačná

                            zadná hrana Y 510 (stena)
 +---+----------------------------------------------------------+---+
 |   |                                                          |   |
 | L |   DVEROVÁ ČASŤ X 0–450       SLEPÁ ČASŤ X 450–1100       | P |
 | b |                              (zasunutá do kúta vpravo)   | b |
 | o |               +--+                                       | o |
 | k |     Blend2 -> |  | Y 0–80                                | k |
 |   |               |  |======== Blenda Y 0–18 ================|   |
 +---+---------------+--+---------------------------------------+---+   Y 0 = predná rovina korpusu
   [====== DVERE ======] [= CR 1 =]|C |C |                               Y −1 … −19 = rovina čiel
    X 2 … 448            452 … 530 |R |R |
                                   |2 |b |    CR 2      X 530–548, Y −1 … −97  (čelový)
                                   |  |l.|    CR blend  X 548–566, Y  0 … −98  (korpus = rohová výstuha)
                                   +--+--+
 X: Lbok 0–18 · Blend2 432–450 · Blenda 450–1082 · Pbok 1082–1100 · dvere 2–448 · CR 1 452–530
```

---

## 2 · Parametre komponentu (Component Options)

Používateľské parametre (koreňový slovník `dynamic_attributes` modelu; hodnoty v mm, predvolený stav súboru). **Žiadny z nich nemá vzorec.**

| Atribút | Popis v okne DC | Hodnota | Typ | Poznámka |
|---|---|---|---|---|
| `LenX` | Šírka skrinky ↔ | **1100** | TEXTBOX | mení sa mierkou (DC ju absorbuje, `_lenx_nominal`) |
| `LenY` | Hĺbka skrinky ∟ | **510** | TEXTBOX | hĺbka korpusu bez dverí |
| `LenZ` | Výška skrinky ↕ | **862** | TEXTBOX | od podlahy, vrátane sokla |
| `a_nastaveniakorp` | „NASTAVENIA KORPUSU" | — | VIEW | len nadpis sekcie |
| `b_CR1` | CR1 | **80** | TEXTBOX mm | § 4, § 5 |
| `b_CR2` | CR2 | **80** | TEXTBOX mm | § 4, § 5 |
| `b_pocet_polic` | Počet políc | **0** | LIST 0–6 | |
| `b_policaods` | Odsadenie police | **20** | TEXTBOX mm | odstup police od čela |
| `b_xdvere` | Šírka dverí | **450** | TEXTBOX mm | v skutočnosti **šírka dverovej zóny**: od vonkajšej plochy ľavého boku po os medzery dvere ↔ CR 1 |
| `c_vSok` | Výška sokla ↨ | **150** | TEXTBOX mm | len zdvihne korpus |
| `d_chrb` | Chrbát | **3 = Pevný vložený** | LIST: Bez = 0 · HDF = 1 · Pevný naložený = 2 · Pevný vložený = 3 | |
| `e_hrubka` | Hrúbka materiálu ▬ | **18** | TEXTBOX mm | |
| `f_dno` | Nastavenie dna └-┘ | **0 = Naložené** | LIST: Naložené = 0 · Vložené = 1 | dno pod bokmi |
| `f_strop` | Nastavenie stropu ┌-┐ | **1 = Vložené** | LIST: Naložené = 0 · Vložené = 1 | vrch medzi bokmi |
| `g_nadn` | Typ stropu | **1 = Nadnože** | LIST: Plný strop = 0 · Nadnože = 1 | |
| `h_nastdvr` | „NASTAVENIA DVERÍ" | — | VIEW | len nadpis sekcie |
| `j_ukw` | UKW | **1 = Nie** | LIST: Áno = 0 · Nie = 1 | úchytkový profil UKW7 na dverách |
| `k_medzD` | Medzera/presah dole ▼ | **0** | TEXTBOX mm | |
| `k_medzH` | Medzera/presah hore ▲ | **5** | TEXTBOX mm | |
| `k_medzL` | Medzera/presah ľavá ◄ | **2** | TEXTBOX mm | |
| `k_medzP` | Medzera/presah pravá ► | **4** | TEXTBOX mm | medzera dvere ↔ CR 1, delí sa napoly (§ 5) |

Skryté (počítané) atribúty koreňa:

| Atribút | Hodnota | Vzorec | Význam |
|---|---|---|---|
| `H_clear` | 676 | `LenZ − c_vSok − 2·e_hrubka` | svetlá výška medzi dnom a nadnožami |
| `hr2X` | 1064 | `LenX − 2·e_hrubka` | vnútorná šírka |
| `hr2Z` | 676 | `LenZ − 2·e_hrubka − c_vSok` | = H_clear |
| `gap` | 0 | `IF(b_pocet_polic > 0, (H_clear − n·e_hrubka)/(n + 1), 0)` | rozostup políc |
| `K_CHRB_HDF` | 3 | konštanta `0.3` | hrúbka HDF |
| `sirka` | 1100 | `LenX` | (uložené ako 110 — cm) |
| `ScaleTool` | 120 | — | skrytý |
| `Description` | „Základné nastavenie" | — | |

**Atribút strany (vľavo/vpravo) v DC neexistuje** — ani skrytý, ani na dielcoch (§ 6).

---

## 3 · Dielce — predvolený stav

Stav: šírka 1100, hĺbka 510, výška 862, dvere 450, CR 80 + 80, medzery L 2 / P 4 / H 5 / D 0, sokel 150, hrúbka 18.
Súradnice sú v koreni DC (§ 1), rozmer = X × Y × Z. Skratky vo vzorcoch: **W** = LenX, **D** = LenY, **H** = LenZ, **e** = e_hrubka.
Názov = DC meno `_name` (v zátvorke definícia v súbore — tá je zavádzajúca, pozri § 9).

### 3a · Viditeľné dielce

| # | Dielec | Materiál | X od–do | Y od–do | Z od–do | Rozmer | Kľúčové vzorce polohy / rozmeru |
|---|---|---|---|---|---|---|---|
| 1 | **DNO** (`DNO#1`) | korpus | 0 – 1100 | 0 – 510 | 150 – 168 | 1100 × 510 × 18 | x = `f_dno=1 ? e : 0` · šírka = `f_dno=1 ? W−2e : W` · z = `c_vSok` · hĺbka = D (chrbát bez/vložený), D−3 (HDF), D−e (pevný naložený) |
| 2 | **Lbok** (`Lbok#3`) | korpus | 0 – 18 | 0 – 510 | 168 – 862 | 18 × 510 × 694 | x = 0 · z = `c_vSok + (f_dno=0 ? e : 0)` · výška = `H − c_vSok − e·([f_dno=0] + [f_strop=0])` · hĺbka ako dno |
| 3 | **Pbok** (`Lbok#2`) | korpus | 1082 – 1100 | 0 – 510 | 168 – 862 | 18 × 510 × 694 | x = `W − e`, inak ako Lbok |
| 4 | **Nadn** predná (`nadnož1#2`) | korpus | 18 – 1082 | 0 – 100 | 844 – 862 | 1064 × 100 × 18 | x = `f_strop=1 ? e : 0` · šírka = `f_strop=1 ? W−2e : W` · hĺbka = 100 (konštanta) · z = `H − e` · viditeľná pri `g_nadn = 1` |
| 5 | **Nadn** zadná (`nadnož1#4`) | korpus | 18 – 1082 | 410 – 510 | 844 – 862 | 1064 × 100 × 18 | y = `D − 100` (−3 pri HDF, −e pri pevnom naloženom), inak ako predná |
| 6 | **chrb pevný** (`chrb pevný#1`) | korpus | 18 – 1082 | 492 – 510 | 168 – 844 | 1064 × 18 × 676 | vložený: x = e, šírka `W−2e`, y = `D−e`, z = `c_vSok+e`, výška `H−c_vSok−2e` · naložený (d_chrb = 2): x = 0, šírka W, z = `c_vSok`, výška `H−c_vSok` |
| 7 | **Dvere** (obal `Celo#4` → `Dvere#2`) | Dvere | 2 – 448 | −19 – −1 | 150 – 857 | 446 × 18 × 707 | x = `k_medzL` · šírka = `b_xdvere − k_medzL − k_medzP/2` · y = −19 (konštanta, hrúbka 18 konštanta → 1 mm pred korpusom) · z = `c_vSok + k_medzD` · výška = `H − c_vSok − k_medzD − k_medzH` |
| 8 | **Blenda** korpusová (`Blenda`) | korpus | 450 – 1082 | 0 – 18 | 168 – 844 | 632 × 18 × 676 | šírka = `W − e − b_xdvere` · x = `W − e − šírka` (= b_xdvere) · y = 0, hrúbka e · z = `c_vSok + e` · výška = `H_clear` |
| 9 | **Blend2** = výstuha závesov (`Blend2`) | korpus | 432 – 450 | 0 – 80 | 168 – 844 | 18 × 80 × 676 | x = `W − Blenda.šírka − 2e` (= b_xdvere − e) · hrúbka e · hĺbka = 80 (konštanta, nezávisí od CR) · z a výška ako Blenda |
| 10 | **CR 1** (`CR 1`) | Dvere | 452 – 530 | −19 – −1 | 150 – 857 | 78 × 18 × 707 | x = `b_xdvere + k_medzP/2` · šírka = `b_CR1 − k_medzP/2` · y = −19 · hrúbka = e · z a výška ako dvere |
| 11 | **CR 2** (`CR 1#1`) | Dvere | 530 – 548 | −97 – −1 | 150 – 857 | 18 × 96 × 707 | x = `b_xdvere + CR1.šírka + k_medzP/2` (= b_xdvere + b_CR1) · hrúbka = e · hĺbka = `b_CR2 − k_medzP/2 + e` · y = `−hĺbka − 1` · z a výška ako dvere |
| 12 | **CR blend** = rohová výstuha (`CR 1#2`) | korpus | 548 – 566 | −98 – 0 | 150 – 862 | 18 × 98 × 712 | x = `b_xdvere + CR1.šírka + k_medzP/2 + e` (= b_xdvere + b_CR1 + e) · hrúbka = e · hĺbka = `b_CR2 + e` · y = `−hĺbka` · z = `c_vSok + k_medzD` · výška = `H − c_vSok` |

### 3b · Skryté varianty (v súbore prítomné, predvolene `hidden`)

| # | Dielec | Materiál | X od–do | Y od–do | Z od–do | Rozmer | Kedy sa zobrazí / vzorce |
|---|---|---|---|---|---|---|---|
| 13 | **Chrbat001** (HDF) | HDF1 | 0 – 1100 | 507 – 510 | 150 – 862 | 1100 × 3 × 712 | `d_chrb = 1`; naložený za bokmi, boky a dno sa skrátia na D − 3 |
| 14 | **Strop001** (plný strop) | korpus | 18 – 1082 | 0 – 510 | 844 – 862 | 1064 × 510 × 18 | `g_nadn = 0` (namiesto nadnoží) |
| 15 | **Polica** | korpus | 18 – 1082 | 20 – 492 | 168 + gap … | 1064 × 472 × 18 | `b_pocet_polic > 0`, kópie = n − 1 · **cez celú šírku vrátane slepej časti** · y = `b_policaods` · hĺbka = `D − chrbát − b_policaods` · z = `c_vSok + gap + i·(e + gap) + e` |
| 16 | **DvereUKW** (variant dverí s profilom) | — | 2 – 448 | −20,3 – −1 | 150 – 857 | 446 × 19,3 × 707 | `j_ukw = 0` (Áno); obsahuje čelo „celo s ukw" 446 × 18 × 671 (Z 150–821, výška = dvere − 36) + profil **UKW7** 446 × 19,2 × 37,4 (Z 819,6–857, Y −20,3…−1,1, prekryv 1,4 mm) |
| — | **Obrys** (12 voľných hrán, tag Master) | — | 0 – 1100 | 0 – 510 | 0 – 862 | kváder | viditeľné čiary, nie dielec |

Plochy: všetky dielce sú jednoduché kvádre (**6 plôch, 12 hrán**); profil UKW7 má 85 plôch; `Celo#4` a `DvereUKW` sú len obaly
(2 vnorené komponenty). Najhlbšie vnorenie = 3 (Dvere → DvereUKW → UKW7), meraných záznamov 19.
Rotácie: **žiadny dielec nie je otočený** (všetky osi rovnobežné s koreňom; `rotz = 0` so vzorcom „0" majú len CR 2 a rohová výstuha).
Vzorec materiálu nemá žiadny dielec. Vzorec `hidden` majú len prepínané varianty: HDF chrbát, pevný chrbát, plný strop, obe nadnože, polica a dva varianty dverí.

---

## 4 · Rohová zostava — kde presne čo sedí

- **Predná rovina korpusu = Y 0** (predné hrany bokov, dna, prednej nadnože a Blendy). **Rovina čiel = Y −1 … −19** (1 mm škára + 18 mm hrúbka).
- **Dvere** — vľavo, **pred korpusom**: X 2–448, Z 150–857. Ľavá hrana 2 mm od vonkajšej plochy ľavého boku, pravá hrana 2 mm pred hranicou
  dverovej zóny (X 450). Spodná hrana lícuje so spodkom dna (Z 150 = výška sokla), horná je 5 mm pod vrchom korpusu. Dvere prekrývajú ľavý bok
  o 16 mm a výstuhu závesov o 16 mm (432–448).
- **Blenda korpusová** — **v prednej rovine korpusu, za rovinou čiel** (Y 0–18, vnútri medzi bokmi), X 450–1082 = od hranice dverovej zóny po
  vnútornú plochu pravého boku, Z 168–844 = svetlá výška medzi dnom a nadnožami. Zakrýva slepú časť. Materiál korpus **napevno** (bez vzorca),
  **bez ABS** (ani na čelnej ploche).
- **Výstuha závesov (Blend2)** — **za rovinou korpusu**, kolmé rebro X 432–450, hĺbka 80 (Y 0–80), Z 168–844. Jej pravá plocha (X 450) lícuje
  s ľavým koncom Blendy → spolu tvoria „L". Pre dvere funguje ako „pravý bok": dvere ju prekrývajú o 16 mm, **pánty pri rohu patria na jej ľavú
  plochu (X 432)**. Svetlý otvor dverovej časti = X 18–432 = **414 mm**. ABS len na zadnej hrane (Y 80, viditeľná zvnútra).
- **CR 1** — **pred korpusom v rovine dverí** (Y −19 … −1), X 452–530, Z 150–857 (rovnaká výška a Z ako dvere). Medzera dvere ↔ CR 1 = 4 mm
  s osou na X 450. Pravým koncom (X 530) naráža na ľavú plochu CR 2. Čelový materiál, ABS dookola.
- **CR 2** — **pred korpusom, kolmo na čelo**: 18 mm doska X 530–548 postavená do hĺbky od Y −1 po **Y −97** → **trčí 97 mm pred prednú rovinu
  korpusu, t. j. 78 mm pred líce dverí** (líce Y −19). Z 150–857 ako dvere. Čelový materiál, ABS dookola (predná hrana, zadná hrana, vrch, spodok).
  Jej ľavá (viditeľná) plocha X 530 = `b_xdvere + b_CR1`.
- **Rohová výstuha (CR blend)** — **pred korpusom**, tesne za CR 2 na strane slepej časti (X 548–566), od prednej roviny korpusu dopredu **Y 0 … −98**
  (**trčí 98 mm**, o 1 mm ďalej než CR 2), **Z 150–862** (od spodku dna po vrch korpusu = výška − sokel = 712, o 5 mm vyššie než CR 2). Materiál korpus.
  Zozadu sa opiera o čelo Blendy (Y 0) — celá CR zostava je namontovaná pred Blendou. ABS na prednej hrane, vrchu a spodku (zadná nie).
- **Ako to spolu funguje (výklad, NEOVERENÉ — susedný rad v DC nie je):** CR 1 + CR 2 tvoria rohovú „L" lištu. CR 2 leží v rovine, kde má byť
  líce dverí susedného kolmého radu (X 530 = `b_xdvere + b_CR1`), a čelo rohovej výstuhy určuje, kde stojí bok prvej skrinky susedného radu
  (Y −98 = `−(b_CR2 + e)`). **b_CR1 posúva rovinu susedného radu do šírky, b_CR2 jeho odstup od čela rohovej skrinky do hĺbky** — preto sa nimi
  dolaďujú milimetre v rohu a nemusia byť rovnaké.

---

## 5 · Šírka dverí a medzery

- `b_xdvere` (v okne „Šírka dverí", 450) = **šírka dverovej zóny** od vonkajšej plochy ľavého boku po **os medzery** dvere ↔ CR 1.
- **Šírka dverí** = `b_xdvere − k_medzL − k_medzP/2` = 450 − 2 − 2 = **446**; poloha x = `k_medzL` = 2.
- **Výška dverí** = `LenZ − c_vSok − k_medzD − k_medzH` = 862 − 150 − 0 − 5 = **707**; spodok z = `c_vSok + k_medzD` = 150.
- **`k_medzP` sa delí napoly:** 2 mm uberá dverám, 2 mm uberá CR 1 (medzera dvere ↔ CR 1 = celé k_medzP = 4). Tú istú polovicu odpočíta aj hĺbka CR 2.
- **CR 1** šírka = `b_CR1 − k_medzP/2` = **78** · **CR 2** hĺbka = `b_CR2 − k_medzP/2 + e` = **96** · **rohová výstuha** hĺbka = `b_CR2 + e` = **98**.
- Dvere, CR 1 a CR 2 majú **rovnakú výšku aj Z** (707, od 150); rohová výstuha ide až po vrch korpusu (712).
- Dvere majú hrúbku 18 a polohu Y −19 **natvrdo** (konštanty), CR 1 / CR 2 / rohová výstuha berú `e_hrubka` — pri inej hrúbke by sa rozišli (zo vzorcov).

**Overené experimentom** (sonda 2, DC redraw na vloženej inštancii):

| Stav | Dvere X | CR 1 X | CR 2 X / Y | Rohová výstuha X / Y | Blenda X | Blend2 X | Korpus |
|---|---|---|---|---|---|---|---|
| S0 predvolený (po redraw = zhodný so súborom) | 2–448 | 452–530 | 530–548 / −97…−1 | 548–566 / −98…0 | 450–1082 | 432–450 | 1100 |
| S1: dvere 500, CR1 60, CR2 100, medzera P 3 | 2–498,5 | 501,5–560 | 560–578 / −117,5…−1 | 578–596 / −118…0 | 500–1082 | 482–500 | 1100 |
| S2: ako S1 + šírka 1200 (mierkou, DC absorboval) | 2–498,5 | 501,5–560 | 560–578 / −117,5…−1 | 578–596 / −118…0 | **500–1182** | 482–500 | **1200** (Pbok 1182–1200) |

Všetko presne podľa vzorcov. **Pri zmene šírky rastie len korpus a Blenda (slepá časť); dvere, CR lišty a výstuha závesov sú viazané na ľavý (dverový) okraj.**

---

## 6 · Prepínač strany (zrkadlenie)

- DC **nemá atribút strany**. Všetky dielce majú kladný determinant transformácie (nič nie je zrkadlené) — model pozná len „dvere vľavo".
- Pravá verzia = **Flip Along (červená os) celej inštancie**. Overené v sonde 2:

| Stav | Dvere X | CR 1 X | CR 2 X | Rohová výstuha X | Blenda X | Blend2 X | „Lbok" X |
|---|---|---|---|---|---|---|---|
| S3: flip okolo x = 550 + redraw | 652–1098 | 570–648 | 552–570 | 534–552 | 18–650 | 650–668 | 1082–1100 |
| S4: S3 + dvere 500 + redraw | 602–1098 | 520–598 | 502–520 | 484–502 | 18–600 | 600–618 | 1082–1100 |

- DC redraw flip **zachová** (inštancia ostane zrkadlená, det −1) a zmena parametra po flipe sa prepočíta správne v lokálnych osiach.
  Y a Z sa nemenia (CR 2 stále −97…−1, rohová výstuha −98…0).
- Pravidlo: zrkadlená verzia = **X' = LenX − X**. Pozor: DC dielec „Lbok" je po flipe fyzicky pravý bok (mená sa neprehadzujú).

---

## 7 · Korpus a všetko ostatné v DC (okrem rohovej zostavy)

- **Dno:** naložené (pod bokmi), celá šírka 1100 × celá hĺbka 510, Z 150–168. Variant „vložené" = medzi bokmi.
- **Boky:** 18 × 510 × 694, stoja na dne (Z 168–862).
- **Vrch:** **dve nadnože 100 mm** (predná Y 0–100, zadná Y 410–510), vložené medzi boky, Z 844–862, ABS na všetkých 4 hranách. Variant „plný strop" skrytý.
- **Chrbát:** **pevný vložený 18 mm** medzi bokmi, medzi dnom a nadnožami, zarovno so zadnou hranou (Y 492–510, Z 168–844), bez ABS.
  Varianty: HDF 3 mm naložený, pevný naložený, bez chrbta.
- **Police:** predvolene 0 (skryté). Pri n > 0 **cez celú šírku vrátane slepej časti** (1064 × 472), 20 mm od čela, končia pri chrbte,
  rovnomerne v svetlej výške 676.
- **Sokel: len parameter** `c_vSok` = 150 — korpus je zdvihnutý, **soklová doska ani nohy v DC nie sú**. Rohová zostava tiež začína až na Z 150
  (pod CR 2 a rohovou výstuhou nie je nič).
- **Nohy, pánty, úchytka, iné kovanie:** v DC **nie sú** (iba profil UKW7 ako skrytý variant dverí).
- **Navyše oproti bežnej dolnej skrinke:** 3 parametre (`b_xdvere`, `b_CR1`, `b_CR2`), **jedny dvere so šírkou dverovej zóny** (nie celej skrinky)
  a **5 dielcov rohovej zostavy**: Blenda, výstuha závesov (Blend2), CR 1, CR 2, rohová výstuha (CR blend).

---

## 8 · Materiály, ABS a tagy

- **Materiály** (priamo na inštanciách, **žiadny vzorec materiálu**): „korpus" (biela) — korpus, Blenda, výstuha závesov, rohová výstuha ·
  „Dvere" (svetlomodrá 204/206/245) — dvere, CR 1, CR 2 · „HDF1" — HDF chrbát · „UKW" — profil · „ABS" (žltá 253/255/143) je natretá na hranových plochách.
- **ABS podľa plôch:** dno — predná · boky — predná · nadnože — všetky 4 · pevný chrbát — nič · dvere — 4 · CR 1 — 4 · CR 2 — 4 (predná, zadná, vrch, spodok) ·
  rohová výstuha — predná, vrch, spodok · **Blenda — nič** · výstuha závesov — len zadná (Y 80) · polica — predná.
- **Tagy:** Korpus (dno, boky, nadnože) · Chrbát (oba chrbty) · Dvere (obal dverí) · Untagged (Blenda, Blend2, CR 1, CR 2, rohová výstuha, polica, plný strop) · Master (obrys).

---

## 9 · Pasce pri čítaní tohto DC

- Vzorce v cm, uložené hodnoty dĺžok v palcoch; vlastné atribúty bez `_formulaunits` sú uložené v cm (`sirka = 110`, `h_clear = 67.6`).
- Dielce sú **škálované inštancie** (napr. definícia pevného chrbta má 1418,6 × 159 × 1399,7, mierka je v transformácii) — rozmery brať z geometrie, nie z definície.
- `Dvere#2` má v DC `x = −232,6 mm` **bez vzorca** — zastaraná hodnota; skutočná poloha je z transformácie (0 voči obalu dverí).
- Po zmene šírky mierkou ostáva `lenx` v definícii zastaraný (1100), platný je `_lenx_nominal` (1200) — potvrdené, zhodné s DC_PRAVIDLA bod 2.
- **Mená definícií klamú:** `CR 1#1` je CR 2, `CR 1#2` je rohová výstuha („CR blend"), `Lbok#2` je pravý bok („Pbok"). Spoľahlivé meno = DC `_name`.
- Popisky voľby UKW sa na koreni a na obale dverí líšia (koreň „Áno = 0 / Nie = 1", obal „bez = 0 / UKW7 = 1") — logika sedí s koreňom (1 = obyčajné dvere).

---

## 10 · Postrehy pre koncept (návrhy sondy, nie rozhodnutia)

- **Prvok pred rovinou čiel:** CR 2 a rohová výstuha trčia 97 / 98 mm pred korpus (78 mm pred líce dverí) — obrys skrinky, náhľad pri vkladaní,
  kontrola kolízií, sokel pod rohom aj hĺbka pracovnej dosky s tým musia počítať.
- **„Šírka dverí" v DC je dverová zóna** (450 → dvere 446). V UI Engine by pomohli dva jasné pojmy: „dverová časť" (zadáva sa) a výsledná šírka dverí (odvodená).
- **Rohová zostava je viazaná na dverový okraj** — pri zmene šírky skrinky rastie len slepá časť (S2). Zrkadlenie = X' = W − X (S3/S4), sedí s „transformácia plánu".
- **Výstuha závesov má pevnú hĺbku 80** nezávislú od CR; **Blenda nemá v DC žiadne ABS** a je vždy korpusová — overiť s Michalom, či to tak chce aj vo výstupoch.
- **Sokel v rohu DC nerieši** (všetko začína na Z 150) — otázka pre mockup: ako ide soklová doska okolo vystupujúcej CR 2.

---

## 11 · NEOVERENÉ / čo sa nepodarilo zmerať

1. **Poloha susedného kolmého radu** — DC ho neobsahuje; väzba „CR 2 = rovina líca susedných dverí, rohová výstuha = bok susednej skrinky" je výklad z geometrie.
2. **Pánty (počet, poloha), smer otvárania, úchytka, nohy, soklová doska** — v DC nie sú. Že pánty sedia na výstuhe závesov, je výklad (Blend2 je presne za pravou hranou dverí).
3. **Ostatné polohy prepínačov** (dno vložené, strop naložený, chrbát bez / HDF / naložený, plný strop, police > 0, UKW áno, medzera dole ≠ 0, iná hrúbka) sa
   **nemerali** redraw-om — popis je len zo vzorcov. Zo vzorcov vidno tri nezrovnalosti DC: (a) polica pri vloženom dne o 18 mm vyššie,
   (b) rohová výstuha pri `k_medzD ≠ 0` prečnieva nad korpus o `k_medzD`, (c) dvere 18 / −19 natvrdo, CR lišty podľa `e_hrubka`.
4. **Či dielňa pravú verziu robí vždy flipom** — DC inak nevie; technicky flip funguje (S3, S4).
5. **UKW variant** je v súbore v zastaranom stave (`DvereUKW` má `lenz` 600 bez vzorca, geometria 707) — pri `j_ukw = 0` nemerané.
6. **Výrobné údaje** (kusovník, VEPO, smer dekoru, typ a hrúbka ABS) DC nenesie — ABS je len žltá farba na plochách.

---

## 12 · Súbory (scratchpad)

> Surové súbory sondy ostali v lokálnom scratchpade orchestrátora (okno 27./28.9.2026) — **v repe nie sú**; autoritou pre blok je tento dokument.
> Sondu sa dá zopakovať nad kópiou `C:\APP DEV\RUBY\COMPONENTS V2\1 Nové Dynamicke\Rohová.skp` postupom z hlavičky.

- `dc_probe\dc_rohova.json` — sonda 1: všetky slovníky modelu, definícií a materiálov, 19 záznamov dielcov (bounds v koreni, transformácie, DC atribúty, plochy).
- `dc_probe\dc_rohova_parts.tsv` — rýchla tabuľka dielcov (bounds v mm).
- `dc_probe\dc_rohova_exp.json` — sonda 2: voľné hrany obrysu + stavy S0–S4.
- `dc_probe\probe.rb`, `dc_probe\probe2.rb`, `dc_probe\launch.ps1` — skripty; `probe_log.txt`, `probe2_log.txt`, `DONE.txt`, `DONE2.txt` — záznamy behov.
- `dc_probe\Rohova_copy.skp`, `dc_probe\Rohova_run2.skp` — kópie po behoch (knižnica nedotknutá).
