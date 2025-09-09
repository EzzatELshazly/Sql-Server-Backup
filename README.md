# SQL Server Automated Backup to Azure Blob Storage (Ubuntu)

## Overview

This document explains how to install **SQL Server Express** on Ubuntu,
configure **SQLCMD** and **AzCopy**, generate an **Azure SAS token**,
and set up a **nightly automated backup** of all SQL Server databases to
Azure Blob Storage.

------------------------------------------------------------------------

## Prerequisites

-   Ubuntu 22.04 server (VM or physical machine)
-   Sudo/root access
-   Azure Storage account with a Blob Container

------------------------------------------------------------------------

## Step 1: Install SQL Server Express on Ubuntu

1.  Import Microsoft repository keys:

``` bash
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2019.list | sudo tee /etc/apt/sources.list.d/mssql-server.list
sudo apt-get update
```

2.  Install SQL Server:

``` bash
sudo apt-get install -y mssql-server
```

3.  Run setup and select **Express (option 3)**:

``` bash
sudo /opt/mssql/bin/mssql-conf setup
```

4.  Verify installation:

``` bash
systemctl status mssql-server
```

------------------------------------------------------------------------

## Step 2: Install SQLCMD Tools

1.  Add Microsoft repo for SQL tools:

``` bash
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update
```

2.  Install tools:

``` bash
sudo apt-get install -y mssql-tools18 unixodbc-dev
```

3.  Add tools to PATH:

``` bash
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' | sudo tee -a /etc/profile
```

4.  Test connection:

``` bash
sqlcmd -S localhost -U SA -P 'YourStrongPassword' -Q "SELECT @@VERSION"
```

------------------------------------------------------------------------

## Step 3: Install AzCopy

1.  Download and install AzCopy:

``` bash
wget https://aka.ms/downloadazcopy-v10-linux -O azcopy.tar.gz
tar -xvf azcopy.tar.gz
sudo cp ./azcopy_linux_amd64*/azcopy /usr/bin/
```

2.  Verify installation:

``` bash
azcopy --version
```

------------------------------------------------------------------------

## Step 4: Generate SAS Token in Azure

1.  Log in to **Azure Portal** → go to your **Storage Account**.\
2.  Navigate to **Storage Browser** → **Blob Containers**.\
3.  Select your container (e.g., `machinesqlubuntubackup`).\
4.  Click **Shared access tokens**.\
5.  Choose permissions: **Read, Add, Create, Write, Delete, List**.\
6.  Set an expiry (e.g., `+10 years`).\
7.  Click **Generate SAS** and copy the **Blob SAS URL**.

The SAS URL looks like:

    https://<storageaccount>.blob.core.windows.net/<container>?sp=racwdli&st=...&se=...&sv=...&sr=c&sig=...

------------------------------------------------------------------------

## Step 5: Backup Script

Create `/usr/local/bin/sql_backup.sh`:

``` bash
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
```

Make it executable:

``` bash
sudo chmod +x /usr/local/bin/sql_backup.sh
```

------------------------------------------------------------------------

## Step 6: Automate with Cron

1.  Edit root's crontab:

``` bash
sudo crontab -e
```

2.  Add entry to run daily at **2 AM**:

```{=html}
<!-- -->
```
    0 2 * * * /bin/bash /usr/local/bin/sql_backup.sh >> /var/log/sqlbackup.log 2>&1

3.  Verify scheduled jobs:

``` bash
sudo crontab -l
```

------------------------------------------------------------------------

## Step 7: Verify Backups

-   Check logs:

``` bash
cat /var/log/sqlbackup.log
```

-   Verify `.bak` files in `/var/opt/mssql/backups`
-   Verify uploads in **Azure Blob Storage**.

------------------------------------------------------------------------


## Conclusion

With this setup: - All SQL Server databases are backed up daily at 2
AM. - Backups are stored locally and uploaded to Azure Blob Storage.\
- Developers and admins have reliable, automated backups.
