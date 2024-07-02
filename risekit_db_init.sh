#!/bin/bash
set -e

db_name="postgres"
s3_server_name="s3_risekit_files_production"
foreign_db_server_name="risekit_production_db_replica"

echo "Setting up extensions"

psql -U postgres -d ${db_name} -p 5433 -c "CREATE EXTENSION IF NOT EXISTS pg_lakehouse;"
psql -U postgres -d ${db_name} -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgres_fdw;"
psql -U postgres -d ${db_name} -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql -U postgres -d ${db_name} -p 5433 -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"
psql -U postgres -d ${db_name} -p 5433 -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"

echo "Setting up pg_lakehouse access to S3"

psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  DO
  \$\$
  BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_foreign_data_wrapper
        WHERE fdwname = 's3_wrapper'
    ) THEN
        CREATE FOREIGN DATA WRAPPER s3_wrapper
        HANDLER s3_fdw_handler
        VALIDATOR s3_fdw_validator;
    END IF;
  END
  \$\$;
SQL

psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  CREATE SERVER IF NOT EXISTS ${s3_server_name}
  FOREIGN DATA WRAPPER s3_wrapper
  OPTIONS (region '${AWS_REGION}');
SQL

psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER ${s3_server_name}
  OPTIONS (
    access_key_id '${AWS_ACCESS_KEY_ID}',
    secret_access_key '${AWS_SECRET_ACCESS_KEY}'
  );
SQL

echo "Setting up foreign S3 tables"

psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  DROP FOREIGN TABLE IF EXISTS recommendations_dictionaries;

  CREATE FOREIGN TABLE IF NOT EXISTS recommendations_dictionaries (
    Json_record TEXT
  )
  SERVER ${s3_server_name}
  OPTIONS (path 's3://rise-kit-files-production/recommendations/parquet/', extension 'parquet');
SQL

echo "Setting up foreign database tables"

psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  CREATE SERVER IF NOT EXISTS ${foreign_db_server_name}
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host '${APPLICATION_DB_HOSTNAME}', port '${APPLICATION_DB_PORT}', dbname '${APPLICATION_DB_NAME}');
SQL

psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER ${foreign_db_server_name}
  OPTIONS (user '${APPLICATION_DB_USERNAME}', password '${APPLICATION_DB_PASSWORD}');
SQL

psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  IMPORT FOREIGN SCHEMA public
  LIMIT TO (
    ahoy_events,
    ahoy_visits,
    resumes,
    shared_resources,
    genders,
    ethnicities,
    military_statuses,
    groups,
    teams,
    criminal_record_options,
    resource_links,
    candidate_profiles,
    organizations
  )
  FROM SERVER ${foreign_db_server_name} INTO public
SQL

# We need to create a foreign table for the users table because
# the users table includes encryted columns that we don't need
psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS users (
      id bigint NOT NULL,
      email character varying DEFAULT ''::character varying,
      reset_password_sent_at timestamp without time zone,
      remember_created_at timestamp without time zone,
      sign_in_count integer DEFAULT 0 NOT NULL,
      current_sign_in_at timestamp without time zone,
      last_sign_in_at timestamp without time zone,
      current_sign_in_ip character varying,
      last_sign_in_ip character varying,
      confirmed_at timestamp without time zone,
      confirmation_sent_at timestamp without time zone,
      unconfirmed_email character varying,
      unlock_token character varying,
      locked_at timestamp without time zone,
      created_at timestamp(6) without time zone NOT NULL,
      updated_at timestamp(6) without time zone NOT NULL,
      first_name character varying,
      last_name character varying,
      mobile_phone character varying,
      phone_verified boolean DEFAULT false,
      phone_code_expire_at timestamp without time zone,
      risekit_username character varying,
      account_type_id bigint DEFAULT 0,
      organization_id bigint,
      middle_name character varying,
      agree_terms_privacy_policy boolean DEFAULT false,
      admin boolean DEFAULT false,
      one_time_code_expire_at timestamp without time zone,
      one_time_code_verified boolean DEFAULT false,
      merge_data jsonb DEFAULT '{}'::jsonb,
      referrer_data jsonb DEFAULT '{}'::jsonb,
      success_plan jsonb DEFAULT '{}'::jsonb,
      referrer_id bigint,
      ukg_data jsonb DEFAULT '{}'::jsonb,
      discarded_at timestamp without time zone,
      slug character varying
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'users');
SQL

echo "Setting up views"

psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  CREATE MATERIALIZED VIEW recommendations_view AS
  SELECT "json_record"::jsonb AS data
  FROM recommendations_dictionaries;
SQL

# at minute 0 of every hour
once_every_hour="0 * * * *"

# NOTE: overwrites the existing cron job with the same name
psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  SELECT cron.schedule('refresh_recommendations_view',
         '${once_every_hour}',
         'REFRESH MATERIALIZED VIEW recommendations_view');
SQL

# needed to that pg_cron switches to a domain socket connection when connecting
# to the local database; see https://github.com/citusdata/pg_cron/issues/48#issuecomment-386207327
psql -U postgres -d ${db_name} -p 5433 --set ON_ERROR_STOP=on <<-SQL
  UPDATE cron.job SET nodename = '';
SQL