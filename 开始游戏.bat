@echo off
chcp 65001 >nul
set "GAME_DIR=%~dp0"
set "GODOT_EXE=%~dp0..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_EXE%" (
    start "" "%GODOT_EXE%" --path "%GAME_DIR%."
    exit /b
)
where godot >nul 2>&1
if not errorlevel 1 (
    start "" godot --path "%GAME_DIR%."
    exit /b
)
echo 未找到 Godot。请使用 Godot 4.3 或更高版本打开本目录的 project.godot，再按 F5 运行。
pause
