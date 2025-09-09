# SQL Server Automated Backup to Azure Blob Storage

## Overview

This document explains how to configure automated SQL Server backups on
an Ubuntu machine and upload them to **Azure Blob Storage** daily at **2
AM** using `cron`.

------------------------------------------------------------------------

## Task

-   Host SQL Server Express on Ubuntu.
-   Automate **full database backups** for all databases.
-   Store backups locally and upload them to **Azure Blob Storage**.
-   Run this backup daily at **2 AM** via `cron`.

------------------------------------------------------------------------

## Prerequisites

1.  **SQL Server Express** installed on Ubuntu.
2.  **SQLCMD tools** installed (`mssql-tools18`).
3.  **AzCopy** installed for uploading to Azure.
4.  **Azure Storage SAS Token** for authentication.

------------------------------------------------------------------------

## Step 1: Install SQL Tools and AzCopy

``` bash
# Install SQL tools
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update
sudo apt-get install -y mssql-tools18 unixodbc-dev

# Add SQL tools to PATH
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' | sudo tee -a /etc/profile

# Install AzCopy (if not installed)
wget https://aka.ms/downloadazcopy-v10-linux
tar -xvf downloadazcopy-v10-linux
sudo cp ./azcopy_linux_amd64*/azcopy /usr/bin/
```

------------------------------------------------------------------------

## Step 2: Backup Script

Save the following script as `/usr/local/bin/sql_backup.sh`:

``` bash
#!/bin/bash

# Variables
BACKUP_DIR="/var/opt/mssql/backups"
TIMESTAMP=$(date +%F-%H%M%S)
LOG_FILE="/var/log/sqlbackup.log"
AZURE_URL="YOUR_AZURE_SAS_URL"

echo "===== Backup started at $(date) =====" >> $LOG_FILE

# Get all databases
DBS=$(sqlcmd -S localhost -U SA -P 'YourStrongPassword' -C -h -1 -Q "SET NOCOUNT ON; SELECT name FROM sys.databases;")

# Loop through and backup each DB
for DB in $DBS; do
    echo "Backing up $DB ..." >> $LOG_FILE
    sqlcmd -S localhost -U SA -P 'YourStrongPassword' -C -Q "BACKUP DATABASE [$DB] TO DISK = N'$BACKUP_DIR/${DB}_$TIMESTAMP.bak' WITH INIT;" >> $LOG_FILE 2>&1
done

# Upload backups to Azure
/usr/bin/azcopy copy "$BACKUP_DIR/*.bak" "$AZURE_URL" --recursive >> $LOG_FILE 2>&1

echo "===== Backup finished at $(date) =====" >> $LOG_FILE
```

Make script executable:

``` bash
sudo chmod +x /usr/local/bin/sql_backup.sh
```

------------------------------------------------------------------------

## Step 3: Configure Cron Job

Edit root crontab:

``` bash
sudo crontab -e
```

Add this line to run the script daily at **2 AM**:

    0 2 * * * /bin/bash /usr/local/bin/sql_backup.sh >> /var/log/sqlbackup.log 2>&1

------------------------------------------------------------------------

## Step 4: Verify Backups

-   Check log file:

``` bash
cat /var/log/sqlbackup.log
```

-   Check Azure Blob Storage for uploaded `.bak` files.

------------------------------------------------------------------------

## Notes

-   `tempdb` cannot be backed up (SQL Server limitation).
-   Ensure Azure SAS token (`AZURE_URL`) is valid and has **write
    permissions**.
-   Change SA password in script to match your environment.

------------------------------------------------------------------------

## Conclusion

This setup ensures: - **Daily backups of all databases** on SQL Server
Express. - **Automatic upload** to Azure Blob Storage. - **Minimal
manual intervention** required.
