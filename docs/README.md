WORK IN PROGRESS!!!!

Både dokumentation och kod är under arbete



Hjälp funktioner för att skapa TaskWarrior prioritetsuppgifter

Programmet är till för att de ska hjälpa till med att få en enhetlig och snabbt upp
nya uppgifter i TaskWarrior och använder TimeWarrior för att logga tid.

 ----- Förväntad arbetsdag -----------------
 Det finns en del olika funktioner här, dessa är tänkt att kopieras från JIRA tavlan
 Men jag går lätt vilse i tavlorna, så jag tror detta är mycket enklare att inte tappa bort saker

 task-us-pu: Skapa task i projekt baserat på PU/US.
    Exempel är
      task-us-pu "US-1234: Kalle har inte fått sina e-mail"
      task-us-pu "PU-4321: Skriv ny Foobar sykronisering mellan Klient och server"

 task-teknik: Alltid projekt 'teknik', men tillhör antingen PU- och US-ärende
   Exempel är
     task-teknik "US-777: "US-666: Inför SSL kryptering mellan klient och server



 ---- Vanlig arbetsdag -------------
 Dessa är tänkt att användas för att registrera avhopp från sedvanlig rutin,
 då någon behöver har hjälp akut, eller bara kollega s

 task-brand: Skapa task för när saker verkligen brinner i systemet
   Exempel är:
     task-brand "Kunden har månadomställning och allt krashar"

 task-brandlog: Skapa task för när saker verkligen brinner i systemet, och du vill logga tiden i efterhand
   Exempel är:
     task-brandlog "Kunden har månadomställning och allt krashar" 14:30 20m


 task-kollega: För att få lite koll på vad jag gör som jag kan assitera kollegor med
   Exemple är:
     task-kollega "Homer vill ha hjälp med klient uppstart"

 ---- Avslut, pauser och fika --------------

 task-done  : Uppgiften är avslutad
 task-fika  : Markera uppgift som pausad
 task-pause : Markera uppgift som pausad
 task-resume: Återuppta senaste pausade ärendet


 --- Avslutande ord ---
 För att få en lista över alla task, kör task-help




 OBS 
 Miljövariabel för att ändra beteendet

 Sätt default klockslag för start av dagen
 Igenom att sätta Miljövariabeln TASK_DEFAULT_START till en sträng med klockslag
 så startar alla Tasks vid det här klockslaget

 T ex: i ~/.bashrc
 export TASK_DEFAULT_START="06:00"

