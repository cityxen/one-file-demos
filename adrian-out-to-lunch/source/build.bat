echo Build Script: Building %1
sidreloc -p 50 -z 80-ff -v input.sid output.sid
kickass main.asm
sort prg_files\main.sym > prg_files\main-sorted.sym
call exomize.bat

