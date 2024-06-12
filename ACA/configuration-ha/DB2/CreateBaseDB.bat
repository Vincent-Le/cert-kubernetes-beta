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

IF NOT DEFINED skip_create_base_db (
    set skip_create_base_db=false
)

IF "%skip_create_base_db%"=="true" (
    echo --
    echo This script will initialize an existing DB2 database for use as a Document Processing Engine base database. There must be an existing non-admin DB2 user.
    echo --
) ELSE (
    echo --
    echo This script will create and initialize a new DB2 database for use as a Document Processing Engine base database. There must be an existing non-admin DB2 user for that database.
    echo --
)

    
set /p base_db_name= Enter the name of the Document Processing Engine Base database. If nothing is entered, we will use the following default value 'CABASEDB': 
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

set /p base_db_user= Enter the name of an existing database user for the Document Processing Engine Base database. If nothing is entered, we will use the following default value 'CABASEUSER' : 
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"

set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "N" goto :DOEXIT
if /I "%c%" EQU "n" goto :DOEXIT

IF "%skip_create_base_db%"=="true" (
    goto :DOCREATETABLE
) ELSE (
    goto :DOCREATE
)

:DOCREATE
    copy /Y sql\CreateBaseDB.sql.template sql\CreateBaseDB.sql
    powershell -Command "(gc sql\CreateBaseDB.sql) -replace '\$base_db_name', '%base_db_name%' | Out-File -encoding ascii sql\CreateBaseDB.sql
    powershell -Command "(gc sql\CreateBaseDB.sql) -replace '\$base_db_user', '%base_db_user%' | Out-File -encoding ascii sql\CreateBaseDB.sql
    echo "Creating a database using script sql\CreateBaseDB.sql"
    db2 -tvf sql\CreateBaseDB.sql
    goto DOCREATETABLE
:DOCREATETABLE
    copy /Y sql\CreateBaseTable.sql.template sql\CreateBaseTable.sql
    powershell -Command "(gc sql\CreateBaseTable.sql) -replace '\$base_db_name', '%base_db_name%' | Out-File -encoding ascii sql\CreateBaseTable.sql
    powershell -Command "(gc sql\CreateBaseTable.sql) -replace '\$base_db_user', '%base_db_user%' | Out-File -encoding ascii sql\CreateBaseTable.sql
    echo "Creating table TENANTINFO using script sql\CreateBaseTable.sql"
    db2 -tvf sql\CreateBaseTable.sql
    powershell -ExecutionPolicy RemoteSigned -Command ". .\ScriptFunctions.ps1 ; Set-BaseDBVersion %base_db_name% %base_db_user%"
    goto END
:DOEXIT
    echo "Exited on user input"
    goto END
:END
    set skip_create_base_db=
    echo "END"

ENDLOCAL