# Script calendrier CERP BA – places restantes

Scrape la page [Académie CERP BA - Calendrier](https://www.academiecerpba.fr/nos-formations/calendrier/) et génère un CSV avec :
- **Col 1** : date (JJ/MM/AAAA)
- **Col 2** : nom de la formation
- **Col 3** : ville / lieu (Agence de …, Classe virtuelle, Hôtel …, etc.)
- **Col 4** : nombre de places restantes

## Installation

```bash
pip install -r scripts/requirements_cerp.txt
playwright install chromium
```

## Utilisation

```bash
# Export par défaut vers cerp_formations_calendrier.csv
python scripts/cerp_calendrier_places.py

# Fichier de sortie personnalisé
python scripts/cerp_calendrier_places.py -o mon_fichier.csv

# Pour exécution quotidienne : ajoute la date au nom du fichier
python scripts/cerp_calendrier_places.py --append-date
# → cerp_formations_calendrier_2026-02-27.csv
```

## Exécution quotidienne (Windows)

### Planificateur de tâches

1. Ouvrir le **Planificateur de tâches** (taskschd.msc)
2. **Créer une tâche** (ou tâche de base)
3. **Général** : nom « CERP Calendrier places »
4. **Déclencheurs** : Nouveau → Quotidien, heure souhaitée (ex. 8h00)
5. **Actions** : Nouveau → Démarrer un programme
   - Programme : `C:\Users\perra\Documents\projets_flutter\offibox\scripts\run_cerp_calendrier_daily.bat`
   - Dossier : `C:\Users\perra\Documents\projets_flutter\offibox`
6. **Conditions** : cocher « Démarrer uniquement si l’ordinateur est branché » si besoin

### Ligne de commande (création rapide)

```powershell
schtasks /create /tn "CERP Calendrier" /tr "C:\Users\perra\Documents\projets_flutter\offibox\scripts\run_cerp_calendrier_daily.bat" /sc daily /st 08:00
```

## Exécution quotidienne (Linux / macOS)

Ajouter dans crontab (`crontab -e`) :

```
0 8 * * * cd /chemin/vers/offibox && python scripts/cerp_calendrier_places.py -o cerp_formations_calendrier.csv --append-date
```

Exécution tous les jours à 8h00.
