#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE DATABASE exchanges_db;
  CREATE DATABASE prices_db;
  CREATE DATABASE operations_db;
EOSQL
