echo off

if [%1]==[] goto USAGE

:RUN
java -cp .. hyperlit.HyperlitFrame %1

goto END


:USAGE

echo Usage:
echo     runHyperlit lex_file_name
echo Example:
echo     runHyperlit temp.lex


:END