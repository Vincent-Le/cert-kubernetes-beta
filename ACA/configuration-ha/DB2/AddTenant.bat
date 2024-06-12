::
:: Licensed Materials - Property of IBM
:: 5737-I23
:: Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
:: U.S. Government Users Restricted Rights:
:: Use, duplication or disclosure restricted by GSA ADP Schedule
:: Contract with IBM Corp.
::
@echo off

SETLOCAL

SET tenant_type=0
SET daily_limit=0

IF NOT DEFINED skip_create_tenant_db (
    set skip_create_tenant_db=false
)

IF "%skip_create_tenant_db%"=="true" (
    echo.
    echo --
    echo This script will initialize an existing DB2 database for use as a Document Processing Engine Project DB.  There must be an existing non-admin DB2 user for that database.
    set choice="2"
    echo --
) ELSE (
    echo.
    echo --
    echo Enter '1' to create a new DB2 database and initialize the database as a Document Processing Engine Project DB. There must be an existing non-admin DB2 user.
    echo Enter '2' initialize an existing database as a Document Processing Engine Project DB.
    echo Enter '3' to abort.

    set /p choice="Type input: "
)


if /I "%choice%" EQU "3" goto :DOEXIT

set /p tenant_id= Enter the ID for the new project: (eg. t4900) :

IF NOT "%skip_create_tenant_db%"=="true" (
  set /p tenant_db_name= "Enter the name of the new DB2 database to create for the Document Processing Engine Project. Please follow the DB2 naming rules :"
) ELSE (
  set /p tenant_db_name= "Enter the name of the existing DB2 database to use for the Document Processing Engine Project database (eg. t4900) :"
)
set tenant_dsn_name=%tenant_db_name%

:GETUSERNAME
set /p tenant_db_user= "Enter the name of an existing database user for the Project database:" 
IF NOT DEFINED tenant_db_user goto :GETUSERNAME
echo.

REM Use powershell to mask password 
set "psCommand=powershell -Command "$pword = read-host 'Enter the password for the project database user:' -AsSecureString ; ^
    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pword); ^
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)""
for /f "usebackq delims=" %%p in (`%psCommand%`) do set tenant_db_pwd=%%p
REM Alternative way to prompt for pwd without masking
REM set /p tenant_db_pwd= "Enter the password for the project database user:"

set /p tenant_ontology= "Enter the ontology name. If nothing is entered, the default name will be used 'default' :" 
IF NOT DEFINED tenant_ontology SET "tenant_ontology=default"

set /p base_db_name= "Enter the name of Document Processing Engine Base database. If nothing is entered, we will use the default value 'CABASEDB': "
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

set /p base_db_user= "Enter the name of an existing database user for the Document Processing Engine Base database. If nothing is entered, we will use the default value 'CABASEUSER' : "
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"

IF NOT DEFINED rdbmsconnection SET "rdbmsconnection=DSN=%tenant_dsn_name%;UID=%tenant_db_user%;"
set /p ssl= "Please enter if database is enabled for SSL default is false [Y/N] :"
if /I "%ssl%" EQU "Y" (
    SET rdbmsconnection=%rdbmsconnection%Security=SSL;
)

REM Hard code DPE user for Aria
set tenant_company=IBM
set tenant_first_name=DPE
set tenant_last_name=Admin
set tenant_email=acaadmin@ibm.com
set tenant_user_name=acaadmin

echo.
echo "-- Please confirm these are the desired settings:"
echo " - Tenant ID: %tenant_id%"
echo " - Project database name: %tenant_db_name%"
echo " - Project database user: %tenant_db_user%"
echo " - Ontology name: %tenant_ontology%"
echo " - Base database: %base_db_name%"
echo " - Base database user: %base_db_user%"
echo " - DB ssl: %ssl%"
echo.
set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "Y" goto :CREATEDB
if /I "%c%" EQU "N" goto :DOEXIT
if /I "%c%" EQU "n" goto :DOEXIT

echo.

:CREATEDB
    IF "%choice%"=="1" (
        copy /Y sql\CreateDB.sql.template sql\CreateDB.sql
        powershell -Command "(gc sql\CreateDB.sql) -replace '\${tenant_db_name}', '%tenant_db_name%' | Out-File -encoding ascii sql\CreateDB.sql
        powershell -Command "(gc sql\CreateDB.sql) -replace '\$tenant_db_user', '%tenant_db_user%' | Out-File -encoding ascii sql\CreateDB.sql
        echo.
        echo "Creating a database using script sql\CreateDB.sql ...."
        db2 -tvf sql\CreateDB.sql
        goto :INITDB
    )

:INITDB
    REM create schema
    copy /Y sql\CreateBacaSchema.sql.template sql\CreateBacaSchema.sql
    powershell -Command "(gc sql\CreateBacaSchema.sql) -replace '\$tenant_db_name', '%tenant_db_name%' | Out-File -encoding ascii sql\CreateBacaSchema.sql
    powershell -Command "(gc sql\CreateBacaSchema.sql) -replace '\$tenant_ontology', '%tenant_ontology%' | Out-File -encoding ascii sql\CreateBacaSchema.sql
    echo.
    echo "Creating a schema using script sql\CreateBacaSchema.sql ...."
    db2 -tvf sql\CreateBacaSchema.sql

    REM create tables
    echo --
    echo "Creating tables using script sql\CreateBacaTables.sql"
    db2 -stvf sql\CreateBacaTables.sql

    REM table permissions to tenant user
    copy /Y sql\TablePermissions.sql.template sql\TablePermissions.sql
    powershell -Command "(gc sql\TablePermissions.sql) -replace '\$tenant_db_name', '%tenant_db_name%' | Out-File -encoding ascii sql\TablePermissions.sql
    powershell -Command "(gc sql\TablePermissions.sql) -replace '\$tenant_db_user', '%tenant_db_user%' | Out-File -encoding ascii sql\TablePermissions.sql
    powershell -Command "(gc sql\TablePermissions.sql) -replace '\$tenant_ontology', '%tenant_ontology%' | Out-File -encoding ascii sql\TablePermissions.sql
    echo.
    echo "Giving permissions on tables using script sql\TablePermissions.sql ...."
    db2 -tvf sql\TablePermissions.sql

    REM Insert InsertTenant
    copy /Y sql\InsertTenant.sql.template sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$base_db_name', '%base_db_name%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$base_db_user', '%base_db_user%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$tenant_id', '%tenant_id%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$tenant_ontology', '%tenant_ontology%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$tenant_db_name', '%tenant_db_name%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$tenant_db_user', '%tenant_db_user%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$tenant_db_pwd', '%tenant_db_pwd%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$tenant_type', '%tenant_type%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$daily_limit', '%daily_limit%' | Out-File -encoding ascii sql\InsertTenant.sql
    powershell -Command "(gc sql\InsertTenant.sql) -replace '\$rdbmsconnection', '%rdbmsconnection%' | Out-File -encoding ascii sql\InsertTenant.sql
    echo.
    echo "Connecting to base database to insert project database info using script sql\InsertTenant.sql"
    db2 -tvf sql\InsertTenant.sql
    powershell -ExecutionPolicy RemoteSigned -Command ". .\ScriptFunctions.ps1 ; Set-TenantDBVersion %base_db_name% %base_db_user% %tenant_db_name% %tenant_ontology%"

    
    REM Insert InsertUser
    copy /Y sql\InsertUser.sql.template sql\InsertUser.sql
    powershell -Command "(gc sql\InsertUser.sql) -replace '\$tenant_ontology', '%tenant_ontology%' | Out-File -encoding ascii sql\InsertUser.sql
    powershell -Command "(gc sql\InsertUser.sql) -replace '\$tenant_db_name', '%tenant_db_name%' | Out-File -encoding ascii sql\InsertUser.sql
    powershell -Command "(gc sql\InsertUser.sql) -replace '\$tenant_email', '%tenant_email%' | Out-File -encoding ascii sql\InsertUser.sql
    powershell -Command "(gc sql\InsertUser.sql) -replace '\$tenant_first_name', '%tenant_first_name%' | Out-File -encoding ascii sql\InsertUser.sql
    powershell -Command "(gc sql\InsertUser.sql) -replace '\$tenant_last_name', '%tenant_last_name%' | Out-File -encoding ascii sql\InsertUser.sql
    powershell -Command "(gc sql\InsertUser.sql) -replace '\$tenant_user_name', '%tenant_user_name%' | Out-File -encoding ascii sql\InsertUser.sql
    powershell -Command "(gc sql\InsertUser.sql) -replace '\$tenant_company', '%tenant_company%' | Out-File -encoding ascii sql\InsertUser.sql
    powershell -Command "(gc sql\InsertUser.sql) -replace '\$tenant_email', '%tenant_email%' | Out-File -encoding ascii sql\InsertUser.sql
    echo.
    echo "Connecting to project database to insert initial userinfo using script sql\InsertUser.sql"
    db2 -tvf sql\InsertUser.sql
    goto END
:DOEXIT
    echo Exited on user input
    SET skip_create_tenant_db=
    goto END
:END
    SET skip_create_tenant_db=
    echo END
    
ENDLOCAL
