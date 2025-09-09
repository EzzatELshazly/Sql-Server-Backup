#!/bin/bash

# Variables
BACKUP_DIR="/var/opt/mssql/backups"
TIMESTAMP=$(date +%F-%H%M%S)
LOG_FILE="/var/log/sqlbackup.log"
AZURE_URL="YOUR_SAS_URL_HERE"

echo "===== Backup started at $(date) =====" >> $LOG_FILE

# Get all databases
DBS=$(sqlcmd -S localhost -U SA -P 'YourStrongPassword' -C -h -1 -Q "SET NOCOUNT ON; SELECT name FROM sys.databases;")

# Backup each database
for DB in $DBS; do
    echo "Backing up $DB ..." >> $LOG_FILE
    sqlcmd -S localhost -U SA -P 'YourStrongPassword' -C -Q "BACKUP DATABASE [$DB] TO DISK = N'$BACKUP_DIR/${DB}_$TIMESTAMP.bak' WITH INIT;" >> $LOG_FILE 2>&1
done

# Upload to Azure Blob
/usr/bin/azcopy copy "$BACKUP_DIR/*.bak" "$AZURE_URL" --recursive >> $LOG_FILE 2>&1

echo "===== Backup finished at $(date) =====" >> $LOG_FILE
