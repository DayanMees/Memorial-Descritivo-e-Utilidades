@echo off
title Agente de Relatorios - nao feche esta janela enquanto usar o app
cd /d "%~dp0"

where uv >nul 2>nul
if errorlevel 1 set "PATH=%USERPROFILE%\.local\bin;%PATH%"

where uv >nul 2>nul
if errorlevel 1 (
    echo.
    echo O programa "uv" nao foi encontrado neste computador.
    echo Instale o uv conforme o passo a passo e abra este atalho novamente.
    echo.
    pause
    exit /b 1
)

uv run --python 3.12 --with-requirements requirements.txt streamlit run app.py
if errorlevel 1 pause
