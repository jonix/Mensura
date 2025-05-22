#!/usr/bin/env bash

source source-parser.sh

FLAGS=(
  "desc   | d  | s | 1 |        | Mötesbeskrivning (krävs)        | str"
  "repeat | r  | s | 0 | weekly | Hur ofta                        | str"
  "tags   | t  | m | 0 |        | Taggar (kan anges flera gånger) | str"
  "count  | c  | s | 0 | 1      | Antal upprepningar              | int"
  "dry_run|    | b | 0 |        | Torrkörning                     | bool"
  "note   | n  | s | 0 |        | Noteringsfil                    | str"
  "help   | h  | h | 0 |        | Visa hjälp                      | "
)
POSITIONALS_SPEC=("inputfile:str:Indatafil:" "num:int:Antal rader:5")




parse_args FLAGS POSITIONALS_SPEC --desc "foo" /tmp/inputfile.xt 50
echo "DESC: $DESC"
echo "REPEAT: $REPEAT"
echo "TAGS: $TAGS"
echo "TAGS_ARR: ${TAGS_ARR[*]}"
echo "DRY_RUN: $DRY_RUN"
echo "NOTE: $NOTE"
echo "COUNT: $COUNT"
echo "INPUTFILE: $INPUTFILE"
echo "NUM: $NUM"
echo "POSITIONALS: ${POSITIONAL[*]}"
