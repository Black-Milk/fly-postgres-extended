#!/bin/bash

psql -U postgres -d postgres -p 5433 -c "CREATE EXTENSION IF NOT EXISTS pg_lakehouse;"
psql -U postgres -d postgres -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgres_fdw;"
psql -U postgres -d postgres -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql -U postgres -d postgres -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"