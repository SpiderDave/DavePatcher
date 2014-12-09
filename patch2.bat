@echo off
del AAA2.backup.nes>nul
copy AAA2.nes AAA2.backup.nes>nul
del AAA2.nes>nul
copy "Super C (U) [!].nes" AAA2.nes>nul
davepatcher patch2.txt AAA2.nes