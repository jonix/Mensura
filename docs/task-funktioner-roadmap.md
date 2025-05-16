#  En outforskad roadmap av vad som är grundläggande i Task-* metoder såsom task-meeting, task-us, task-pu 

Punkt 2: Vad återstår för att börja med task-* funktionerna?
Jag går igenom task-meeting, task-todo, task-note, och task-done och listar vad som saknas eller behöver kopplas på ovanpå din färdiga datummodul.

🧩 task-meeting
Mål: Skapa en TaskWarrior-uppgift med korrekt datum, tid, anteckningsfil, och eventuellt återkommande tagg.

✅ Har du redan:

 Tolkning av startdatum + klockslag (__parse_datetime)

 Beräkning av slutdatum från offset (+1h, +30m)

🟡 Behöver läggas till:

 Automatisk sluttid om ingen anges (t.ex. via TASK_MEETING_LENGTH)

 Skapa anteckningsfil och koppla till task (t.ex. notes/2025-05-15T14:00-meeting.md)

 Hook till on-modify eller on-start som öppnar anteckningen

 Möjlighet att lägga till --repeat=weekly och sätta annotation/tag

🧩 task-todo
Mål: Skapa en enkel planerad uppgift med prioritet och projekt.

✅ Redan klart:

 Datumparsern kan känna igen idag, imorgon, fredag 13:30, osv.

 Kan använda defaulttid (TASK_START_OF_DAY) om inget anges

🟡 Behöver läggas till:

 Flagghantering: --prio, --project, --due

 Automatisk default-tag/typ: t.ex. task-todo

 Beskrivningsfält som inte feltolkas som datum

Lösning: använd __is_date_based som gate

🧩 task-note
Mål: Skapa en tom anteckningsfil kopplad till en uppgift, med metadata.

✅ Redan klart:

 Datumparsern kan skapa korrekt ISO-stämpel för anteckningens namn

 Filnamn kan byggas från __parse_datetime output

🟡 Behöver läggas till:

 Skapa fil i t.ex. notes/YYYY-MM-DDTHH:MM-<slug>.md

 Möjlig markdown mall eller YAML-frontmatter

🧩 task-done
Mål: Avsluta pågående task och fråga om reflektion.

✅ Du har redan:

 Tidshantering nog att avgöra varaktighet

 Kroppsskanning och loggning är på gång via task-scan

🟡 Behöver läggas till:

 Efter-fråga: vill du skriva något om hur detta kändes?

 Automatisk logg i .jsonl med:

start, stop

tid

känsla

eventuell anteckning


