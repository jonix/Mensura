
# Vad som är klart och har testfall i parse-date.sh 
# Det är över 400+ UnitTester som går igenom 

# Last updated: 2025-05-15, Jonix


🧠 Översikt: Vad är färdigt och stabilt i parse-date.sh
🟦 1. Datumigenkänning och validering ✅
Du hanterar:

 YYYY-MM-DD, YYYY/MM/DD, YY-MM-DD, YYMMDD, MM-DD, MM/DD, MMDD

 Full datumvalidering via date -d

 __is_valid_date, __is_only_date_string, __is_date_string

📌 Status: Klart och vältestat – till och med felaktiga datum som 2025-02-30 fångas korrekt.

🟦 2. Tidigenkänning och normalisering ✅
Du stödjer:

 HH:MM, HH.MM, HHMM

 Tolkning av 10, 1, 123000

 __normalize_time + testade gränsfall

 __is_time_or_offset klassificerar tid vs offset

📌 Status: Robusta, konsekventa resultat. Klart.

🟦 3. Offset och duration-parsing ✅
Stöder:

 +1h, +30m, +1h30m

 1h, 1timme, 30minuter, 45m

 Utan plustecken: 90m, 45, 2tim

 __normalize_offset, __normalize_duration

 Läggs korrekt på datetime via __add_offset_to_datetime

📌 Status: Imponerande bredd och exakthet. Klart.

🟦 4. Namngivna dagar & svenska begrepp ✅
Du har stöd för:

 idag, imorgon, nu

 svenska och engelska veckodagar

 förkortningar: mån, tis, wed, thurs

 korrekt framtidskompensation: måndag på en måndag ger nästa vecka

 __normalize_day, __parse_namegiven_day, __is_namegiven_day

📌 Status: Komplett och språkoberoende. Klart.

🟦 5. Fritexttolkning (master-funktion) ✅
__parse_datetime:

 Tolkar alla kombinationer: "idag +30m", "nu", "2025-04-01 13.30", "1330", "måndag 13:00"

 Hanterar ISO-strängar, offset-only, time-only, named days, och fallback till starttid (TASK_START_OF_DAY)

 Utgång: alltid YYYY-MM-DDThh:mm

📌 Status: Extremt robust. Alla testfall godkända. Kan nu ses som den centrala ingångspunkten för task-*.

🟦 6. Normalisering till ISO ✅
 __normalize_datetime fungerar med 1 eller 2 parametrar

 Tar höjd för edge cases

 Utdata i YYYY-MM-DDThh:mm oavsett input

📌 Status: Produktionsklar.

🟦 7. Hjälpfunktioner och utils ✅
 __trim

 __combine_datetime

 __split_datetime, split_datetime

 Guard-funktion i början ([[ "${BASH_SOURCE[0]}" == "${0}" ]])

📌 Status: Bra verktygssvit, redo att användas i andra moduler.

💡 Slutsats: Vad betyder detta?
Du har byggt ett färdigt datum/tid-normaliserings-API i Bash.
Du kan nu:

✅ Lita på att vilken input du än får i task-meeting eller task-todo, så kan du trygga den via __parse_datetime.

