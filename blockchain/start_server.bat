@echo off
title TrashQuest Blockchain Relayer API Server
color 0B
cls
echo ========================================================
echo   TRASHQUEST - BLOCKCHAIN RELAYER API SERVER (SEPOLIA)
echo ========================================================
echo.
echo Menjalankan REST API server di port 3000...
echo Endpoint otomatis: POST http://localhost:3000/api/mint
echo.
node server.js
echo.
pause
