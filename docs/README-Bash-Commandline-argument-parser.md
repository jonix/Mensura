# Bash CLI Argument Parser
En robust, utbyggbar Bash-parser för kommandoradsargument, byggd för riktiga CLI-verktyg och automation!

## Varför denna parser?
Standard Bash-verktyg (getopts) är begränsade (ingen långflagga, ingen typvalidering, ingen multi-value eller required-stöd).

Vi vill ha feature-paritet med modernare CLI-parsers i Python/Go – men direkt i Bash!

Parsern hittar ALLTID required-flaggor som saknas (även om positionals används) tack vare en sentinel-lösning.

Byggd för att utökas: stöd för help, multi-value, typkontroll, positionella argument, etc.

## Hur fungerar parsern?
Du deklarerar flaggor och positionella argument i arrays (FLAGS, POSITIONALS_SPEC).
Igenom att ange 
  - beskrivningar 
  - kort/long
  - typ
  - required/default

Parsern tolkar flaggor, tilldelar defaultvärden, och för required-flaggor som ej anges sätter parsern ett speciellt värde (__UNSET__, kallas sentinel).

Vid validering kontrolleras om required-flaggor har sentinel-värdet – i så fall ges fel och hjälptext visas, programmet avslutas.

Resultatet exporteras som variabler med namn som DESC, REPEAT, eller POSITIONAL[0] osv.

## Kommandy-syntax definition:

Exempel på vilka parametrar som programmet vill hantera 

### Namngivna parametrar
FLAGS=(
  # flag  | kort | typ | required | default  | beskrivning                | valideringstyp
  #--------------------------------------------------------------------------------------------
  "desc   | d    | s   | 1        |          | Mötesbeskrivning (krävs)   | str"
  "repeat | r    | s   | 0        | weekly   | Hur ofta                   | str"
  "tags   | t    | m   | 0        |          | Taggar (flera gånger)      | str"
  "count  | c    | s   | 0        | 1        | Antal upprepningar         | int"
  "dry_run|      | b   | 0        |          | Torrkörning                | bool"
  "note   | n    | s   | 0        |          | Noteringsfil               | str"
  "help   | h    | h   | 0        |          | Visa hjälp                 | "
)

### Positionella argument:

POSITIONALS_SPEC=(
  "inputfile : str : Indatafil:" 
  "num       : int : Antalrader:5"
)

### Exempel på användning

./task-commandline-parser.sh --desc "Veckomöte" --tags jobb --tags akut -n anteckning.txt inputfil.txt 50

Enligt vår FLAGS och vår POSITIONAL_SPEC så är parameter 
  --desc   är required om den saknas, visas fel + hjälptext och programmet avbryts.
  --tags   kan anges flera gånger (multi).
  --repeat Har default värdet 
  --count  Måste vara ett tal

Alla flaggvärden exporteras som variabler efter parse_args.

## Hur fungerar sentinel-logiken?
När en required-flagga inte anges på kommandoraden sätts dess värde till __UNSET__ (sentinel).
Vid validering jämför parsern varje required-flaggas värde mot sentinel.
Om värdet är __UNSET__ → flaggan saknas, fel visas.
Om flaggan är satt på CLI → används värdet.
Detta eliminerar vanliga Bash-problem där “tom sträng” eller positionals kan maskera en saknad flagga.

