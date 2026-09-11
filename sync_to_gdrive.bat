@echo off
chcp 65001 >nul
echo ========================================================
echo   [Tsumi-Pura RPG] 同步至 Google Drive 雲端中...
echo ========================================================
robocopy "%~dp0." "G:\マイドライブ\TsumiPuraRPG\nifty-heisenberg" /E /XD "build" ".dart_tool" /NFL /NDL /NJH /NJS
echo.
echo [V] 專案已全數同步至 Google Drive (G:\マイドライブ\TsumiPuraRPG)！
echo 另一台電腦只要開啟 Google 雲端硬碟即可直接使用。
echo ========================================================
pause
