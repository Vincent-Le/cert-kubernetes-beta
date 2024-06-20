#!/BIN/BASH

###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2022. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

# function for creating the db sql statement file for BAN
function create_ban_postgresql_sql_file(){
    dbname=$1
    dbuser=$2
    dbuserpwd=$3
    dbserver=$4
    dbschema=$5
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")

    # convert to lowercase for postgreSQL dbname
    dbname=$(echo $dbname | tr '[:upper:]' '[:lower:]')
    dbschema=$(echo $dbschema | tr '[:upper:]' '[:lower:]')

    tablespace="${dbname}_tbs"

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
cat << EOF > $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
-- create user ${dbuser}
CREATE ROLE ${dbuser} WITH INHERIT LOGIN ENCRYPTED PASSWORD '${dbuserpwd}';

-- please modify location follow your requirement
create tablespace ${tablespace} owner ${dbuser} location '/pgsqldata/${dbname}';
grant create on tablespace ${tablespace} to ${dbuser};  

-- create database ${dbname}
create database ${dbname} owner ${dbuser} tablespace ${tablespace} template template0 encoding UTF8 ;

\c ${dbname};

CREATE SCHEMA IF NOT EXISTS ${dbschema} AUTHORIZATION ${dbuser};
GRANT ALL ON schema ${dbschema} to ${dbuser};

-- create a schema for ${dbname} and set the default
-- connect to the respective database before executing the below commands
SET ROLE ${dbuser};
ALTER DATABASE ${dbname} SET search_path TO ${dbschema};
revoke connect on database ${dbname} from public;

EOF
}