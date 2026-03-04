@echo off
REM Exécute le script CERP calendrier avec date dans le nom du fichier.
REM À planifier dans le Planificateur de tâches Windows pour une exécution quotidienne.

cd /d "%~dp0.."
set PYTHON=python
where python >nul 2>&1 || set PYTHON=py

%PYTHON% scripts/cerp_calendrier_places.py -o cerp_formations_calendrier.csv --append-date

REM Optionnel : garder seulement les 30 derniers fichiers
REM forfiles /p "%~dp0.." /m cerp_formations_calendrier_*.csv /d -30 /c "cmd /c del @path" 2>nul
