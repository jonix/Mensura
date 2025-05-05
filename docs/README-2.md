# 🧭 Mensura – README & TODO

## 💡 Vad är Mensura?
Mensura är ett Bash-baserat terminalverktyg för planering, loggning och reflektion i arbetslivet.
Den är byggd för att fånga det mänskliga i hur vi planerar tid, prioriterar uppgifter och hanterar avbrott – med korta kommandon, tydliga strukturer, och total äganderätt över data.

> "Mensura låter dig tala till terminalen som till en kollega."

---

## 🧠 Grundbultarna

### 1. Mänsklig datumtolkning
- `idag`, `imorgon`, `måndag`, `fredag`
- `+30m`, `+1h`, `830`, `13.45`, `2025-04-10`, `4/10`
- Kombinationer som: `fredag 10:30`, `idag +1h`

### 2. Naturliga kommandon
- `task-meeting "Sprintplanering" fredag 10:00 1h`
- `task-brand "Fixade SSH-problem"`
- `task-brandlog "Lisa kunde inte logga in" 13:30 20m`
- `task-us-pu "PU-1234: Optimera indexering"`
- `task-done`, `task-pause`, `task-resume`, `task-canceled`

### 3. Tidshantering
- Automatiskt loggad tid i TimeWarrior
- Retrospektiv loggning stöds
- Metadata lagras i annotation och förbereder rapportering

### 4. Anteckningsfiler
- En anteckningsfil kopplas till varje task
- Metadata som planerad start/sluttid sparas
- Filen öppnas automatiskt vid `start`

### 5. Automation
- ICS-import från Outlook
- `notify-send` påminnelser
- `cron` varje morgon/måndag

---

## ✅ Implementerade funktioner
- Modulariserat system med Bash-guarding
- `__parse_datetime`, `__normalize_time`, `__normalize_offset`
- Funktioner: `task-meeting`, `task-brand`, `task-brandlog`, `task-us-pu`, `task-done`, etc
- TimeWarrior-integration
- Enhetstest-ramverk med .tests-filer
- `mensura-help`, `task-doctor`, `task-selftest`
- Färghantering, trimming, felhantering och logging

---

## 📋 TODO / Roadmap

### 🅐 Prioritet A (Närmaste utveckling)
- [ ] `task-import-outlook`: hämta .ics via curl
- [ ] `task-remind-meetings`: visa kommande möten med `notify-send`
- [ ] `task-summary`: summera tidsanvändning
- [ ] `task-doctor`: kontrollera config, miljö, ICS-url etc.
- [ ] `task-meeting`: sätt start- och sluttid, skapa anteckningsfil
- [ ] Notifiera från cron varje måndag 07:30
- [ ] Enhetstester för relativ tid ("fredag", "+1h")

### 🅱️ Prioritet B (Nästa fas)
- [ ] `task-dev`: skapa Mensura-funktioner som task
- [ ] Automatisera prioritering med `+prio-A/B/C`
- [ ] Projektöversikt: `task +mensura`
- [ ] Konfigurationskommandon: `task-config`

### 🅰️ Prioritet C (framtidsdrömmar)
- [ ] `mensura planera-dagen`: visa schema + föreslå starter
- [ ] Slack/email-påminnelse
- [ ] `task-notify` med ljudsignal
- [ ] Integration med Microsoft Graph API

---

## 🧪 Testsystem
- Testfil per funktion (`*.tests`)
- `run-one-test.sh testcases/time.tests`
- Output: ✅ / ❌, färgat och beskrivande
- Guarding av moduler via `__GUARD_*_LOADED`

---

## 🔐 Konfiguration
Styrs via `.mensura.env`:
```bash
export TASK_DEFAULT_PRIO=Betydande
export TASK_START_OF_DAY=08:00
export TASK_MEETING_LENGTH=1h
export TASK_BREAK_LENGTH=15m
export TASK_DEFAULT_PROJECT=todo
export MENSURA_ICAL_URL="https://...outlook.ics"
```

---

## 💬 Om projektet
Mensura är skapat med passion för terminalen, förtydligande, och självrespekt.
Det började som ett alias. Nu är det ett förhållningssätt.

> „Jag vill inte bara logga tid – jag vill förstå vad jag använder den till.”

--

Vill du se fler översikter eller exportera detta till task-todo-kommandon? Fråga bara! ✨

