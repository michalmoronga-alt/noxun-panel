# Retro — záznamy po behoch (pokus 27.9.–11.10.2026)

> **Načo je tento priečinok:** krátke postrehy orchestrátora k **workflowu** (nie ku kódu), zapísané hneď po behu, kým je udalosť čerstvá.
> Z nich na pokyn Michala vzniká vyhodnotenie s najviac tromi návrhmi zmien. **Retro nikdy nemení pravidlá samo** — rozhoduje Michal.
> Pravidlá pokusu: [../WORKFLOW.md](../WORKFLOW.md) (časť 9 · Retro) · postup krok za krokom: skill `.claude/skills/retro/SKILL.md` ·
> spracované vyhodnotenia: [../archiv/retro/](../archiv/retro/).

## Kde čo je

| Cesta | Čo | V gite |
|---|---|---|
| `SYSTEM/retro/README.md` | tento popis formátu | áno |
| `SYSTEM/retro/inbox/` | nespracované záznamy, jeden súbor na beh | **nie** — `.gitignore`; žiadne PR ani kolo review za poznámku; headless guardy ho preskakujú |
| `SYSTEM/archiv/retro/VYHODNOTENIE_<dátum>.md` | spracované vyhodnotenia s rozhodnutiami Michala (záznam „prečo") | áno |

Inbox je lokálny — žije v hlavnom checkoute, v ktorom pracuje orchestrátor (`C:\APP DEV\RUBY\ENGINE`); worktree subagentov ho nemajú
a subagenti doň nezapisujú (svoje postrehy dávajú do reportu).

## Formát záznamu

Súbor `inbox/<YYYY-MM-DD>_<téma>.md` (téma krátko, malé písmená a pomlčky, napr. `2026-09-28_blok8-start.md`). Najviac ~10 riadkov:

```
# Retro <YYYY-MM-DD> · <beh alebo blok>

- <udalosť> · stálo: <čas / kolo review / kvóta> · návrh: <voliteľne>
- FUNGOVALO: <udalosť> — nemeniť
- od subagenta (<rola>): <postreh z jeho sekcie „Postrehy k workflowu">
```

## Kvalita (čo sem patrí a čo nie)

- **Áno:** konkrétna udalosť s cenou — „PR #402: P2 v kole 1, lebo package tvrdil X z úvahy; +25 min" · „predrecenzia chytila P2 pred PR,
  GH kolo čisté — nemeniť".
- **Nie:** všeobecné rady („treba viac testovať"), opis kódu, zoznam hotových PR (ten je v KRONIKE), písanie nasilu. **Ticho = žiadny záznam.**
- **Opakovanie:** pred zápisom pozri inbox — pri rovnakom postrehu len pripíš `znova <dátum>` k existujúcemu bodu. Opakovanie je
  najsilnejší signál pri vyhodnotení.
- Postrehy k workflowu idú sem, **nie do pamäte agenta** ako varovania; pamäť ostáva pre fakty o Michalovi a projekte.
