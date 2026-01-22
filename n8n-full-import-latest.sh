#!/bin/bash
set -e

# ---------------------------
# CONFIG
# ---------------------------
BACKUP_DB=/home/amunim/backup/database_clean.sqlite
LIVE_DB=/mnt/n8n-data/database.sqlite
TMP=/tmp/n8n-full-import

# ---------------------------
# STOP n8n
# ---------------------------
echo "Stopping n8n..."
# change this to how you stop n8n
docker compose down

# ---------------------------
# PREP TEMP DIR
# ---------------------------
sudo rm -rf "$TMP"
mkdir -p "$TMP"

# ---------------------------
# EXPORT TABLES FROM BACKUP (excluding users)
# ---------------------------
echo "Exporting tables from backup DB..."
TABLES=(
  project
  workflow_entity
  workflow_history
  shared_workflow
  credentials_entity
  shared_credentials
  tag_entity
  workflows_tags
  folder
  folder_tag
)
for table in "${TABLES[@]}"; do
  echo "Exporting $table..."
  sqlite3 "$BACKUP_DB" ".dump $table" > "$TMP/${table}.sql"
done

# ---------------------------
# CLEAR RELEVANT TABLES IN LIVE DB
# ---------------------------
echo "Clearing tables in live DB..."
sqlite3 "$LIVE_DB" << 'EOF'
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;

DELETE FROM shared_workflow;
DELETE FROM shared_credentials;
DELETE FROM workflow_entity;
DELETE FROM workflow_history;
DELETE FROM workflows_tags;
DELETE FROM credentials_entity;
DELETE FROM tag_entity;
DELETE FROM folder;
DELETE FROM folder_tag;
DELETE FROM project;

COMMIT;
PRAGMA foreign_keys=ON;
EOF

# ---------------------------
# IMPORT TABLES INTO LIVE DB
# ---------------------------
echo "Importing tables into live DB..."
for table in "${TABLES[@]}"; do
  echo "Importing $table..."
  sqlite3 "$LIVE_DB" < "$TMP/${table}.sql"
done

# ---------------------------
# CREATE PERSONAL PROJECT FOR LIVE ADMIN IF MISSING
# ---------------------------
echo "Ensuring personal project exists..."
ADMIN_ID=$(sqlite3 "$LIVE_DB" "SELECT id FROM user LIMIT 1;")
PERSONAL_PROJECT_ID=$(sqlite3 "$LIVE_DB" "SELECT id FROM project WHERE creatorId='$ADMIN_ID' AND type='personal' LIMIT 1;")

if [ -z "$PERSONAL_PROJECT_ID" ]; then
  echo "Creating personal project for admin..."
  PERSONAL_PROJECT_ID=$(sqlite3 "$LIVE_DB" "INSERT INTO project (id, name, type, createdAt, updatedAt, creatorId) VALUES (LOWER(HEX(RANDOMBLOB(16))), 'Personal Project', 'personal', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, '$ADMIN_ID'); SELECT id FROM project WHERE creatorId='$ADMIN_ID' AND type='personal' LIMIT 1;")
fi

echo "Personal Project ID: $PERSONAL_PROJECT_ID"

# ---------------------------
# FIX PROJECT REFERENCES IN SHARED TABLES
# ---------------------------
echo "Fixing project references for shared_workflow and shared_credentials..."
sqlite3 "$LIVE_DB" << EOF
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;

-- Attach all workflows to personal project
UPDATE shared_workflow
SET projectId = '$PERSONAL_PROJECT_ID';

-- Attach all credentials to personal project
UPDATE shared_credentials
SET projectId = '$PERSONAL_PROJECT_ID';

COMMIT;
PRAGMA foreign_keys=ON;
EOF

# ---------------------------
# CLEANUP
# ---------------------------
echo "Cleaning temp files..."
sudo rm -rf "$TMP"

# ---------------------------
# RESTART N8N
# ---------------------------
echo "Starting n8n..."
# change this to how you start your n8n
docker compose up -d

echo "Import complete. Check UI for workflows & credentials."
