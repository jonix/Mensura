# Enhetstester i Mensura

Det här ramverket är till för att testa Bash-funktioner i Mensura med minimal boilerplate och maximal kontroll.

Varje `.test`-fil definierar ett antal testfall från en Bash-script. Dessa kan antingen vara:

---

## Linjebaserat (funktion | input | output)

Varje testcase definieras i en `filnamn.test`-fil som ligger under katalogen testcases

Den första raden måste ha #@ source:  och så sökvägen till Bash-scriptet som ska testas emot

Varje rad kör funktionen med angivet argument och jämför det mot angivet resultat.

```
#@ source: ../parse-datetime.sh

__normalize_date|2025-04-03|2025-04-03
__normalize_date|04/03|2025-04-03
__normalize_date|abcd|ERROR

```

Första fältet är funktions-namnet som måste vara åtkomligt från #@ source: direktivet

Andra fältet är input fält
1. Antingen ensam parameter
2. Som ett flertal parametrar
3. En eller flera in-parametrerar kan dynamiskt evaluerat uttryck 

Tredje fältet här är det föväntade resultat 
1. Mest triviala är att jämföra vad funktionen skriver ut på standard-out
2. Om fältet innehåller enbart ett heltal, så jämförs den mot retur-koden från funktionen istället för text
3. Du kan även ha outputen vara en del av ett dynamiskt evaluerat uttryck


## Dynamiska resultat (eval-stöd)
Som in eller ut-parametrar kan innehålla en eller flera dynamiska parametrar
De är vanliga Bash/Shell kommandon
T ex raden

```
__parse_datetime|today 08:00|$(date +%Y-%m-%d)T08:00

```
Jämför här today mot systemets klocka, igenom att evaluera ett shell-kommando

En säkerhets-whitelist (t.ex. date, echo) används för att undvika att man gör riktigt dumma saker i tester
Kolla i koden vilka som stöds, men vid skrivandes stund var det ("date" "echo" "basename" "dirname")
som stöds

## Kör testrunnern
Kör ett enskilt testfall igenom att exekvera

```bash
./run-one-test.sh testcases/parse-datetime.tests
```
Kör alla tester:

```bash
./run-all-tests.sh
```

## Exempelresultat
🧪 Kör testfall från: parse-datetime.tests
✔︎ __normalize_date "04/03" ➝ 2025-04-03
✘ __normalize_date "abcd"
   Förväntat: ERROR
   Fick:      "abcd är inte ett giltigt datum"

Totalt: 12 | ✔︎ 11 | ✘ 1


## Struktur

1. testcases/*.test – Testfiler i ett av ovanstående format
2. unittest-*.sh – Ramverk, assertions, testloader
3. run-one-test.sh – Kör en testfil
4. run-all-tests.sh – Kör alla testfiler

## Tips för egna tester
Glöm inte första raden måste vara #@ source: ../filnamn.sh

Du kan ha flera .test-filer per modul, men du kan inte testa flera moduler i samma .test-fil

Använd ERROR som output om du bara vill kontrollera felmeddelanden

Du kan använda Bash-struktur: $(date ...), $(echo ...), etc. som förväntade resultat

Du kan köra testerna i temporär miljö med TaskWarrior och TimeWarrior riktade mot temporära .taskrc-filer



# OBS:
Det finns ett skelett till en ännu mera avancerad Enhets-testar som har SETUP och TEARDOWN
Men det finns bara 24 timmar per dygn. Den får vänta i någon kö


# OBS 2:
Byggt med <3 i Bash av en utvecklare som bara ville förstå varför han var så trött.
