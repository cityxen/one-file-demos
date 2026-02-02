echo Build Script: Building %1
call KickAss main.asm -cfgfile "E:\youtube\CityXen\Videos\CXN - Chill 8-Bit Chiptunes\SID Curation\KickAss.cfg"
call exomize.bat
del prg_files\*.sym
