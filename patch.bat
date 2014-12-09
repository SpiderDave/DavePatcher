@echo off
del AAA.backup.nes>nul
copy AAA.nes AAA.backup.nes>nul
del AAA.nes>nul
copy "Contra (U) [!].nes" AAA.nes>nul
davepatcher patch.txt AAA.nes