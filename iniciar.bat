@echo off
cd /d "%~dp0"
where mix >nul 2>nul
if errorlevel 1 (
  echo Instala Elixir y Erlang y vuelve a abrir esta ventana.
  pause
  exit /b 1
)
call mix local.hex --force
if errorlevel 1 exit /b 1
call mix deps.get
if errorlevel 1 exit /b 1
echo Abre http://localhost:4000 en cuatro navegadores con el mismo codigo.
call mix run --no-halt
pause
