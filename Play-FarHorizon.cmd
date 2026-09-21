@echo off
title Far Horizon
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Start-FarHorizon.ps1"
if errorlevel 1 (
  echo.
  echo Far Horizon did not launch. Read the status message above.
  pause
)
