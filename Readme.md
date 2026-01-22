After accidentally corrupting db or moving all workflows, credentials from one n8n to other this script simply exports from old sqlite db and imports into current n8n installation.  
This should help in creating backups, bulk import/export.  
While this script is for sqlite, and assumes both dbs are on the same PC, you can use this as base and prompt AI according to your needs. In case of corrupted/malformed db, you will need to salvage the remains and create a clean db before proceeding.

Make sure both have the same `N8N_ENCRYPTION_KEY` env.
##Steps
1. First create backup of current live DB, and delete the live db.
2. Start n8n (`docker compose up -d` in my case), and create a new user.
3. Adjust the paths in the script
4. now run the script in the same folder as docker-compose or replace those lines with how you start/stop n8n.
Voila! now you should have all the workflows/credentials from your old installation.
