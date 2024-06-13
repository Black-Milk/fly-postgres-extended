#!/bin/bash

psql -U postgres -p 5433 -c "CREATE DATABASE risekit_analytics;"
psql -U postgres -d risekit_analytics -p 5433 -c "CREATE EXTENSION IF NOT EXISTS pg_lakehouse;"
psql -U postgres -d risekit_analytics -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgres_fdw;"
psql -U postgres -d risekit_analytics -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql -U postgres -d risekit_analytics -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"