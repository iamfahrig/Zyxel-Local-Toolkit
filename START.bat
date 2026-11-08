@echo off
chcp 65001 >nul
title Zyxel-Local-Toolkit
cd /d "%~dp0"
cls

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0core\unlock.ps1"
echo.
pause
