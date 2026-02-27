@echo off
set OFFIBOX_CHECK_EMAIL_SENDER=perraultalexandre78@gmail.com
set OFFIBOX_CHECK_EMAIL_APP_PASSWORD=mbsl pldt hpxy loqk
cd /d "%~dp0.."
python scripts\check_dead_links.py
