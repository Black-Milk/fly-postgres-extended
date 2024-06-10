#!/bin/bash
set -x

echo "Setting up foreign tables"

db_name="postgres"
s3_server_name="s3_risekit_files_production"
foreign_db_server_name="risekit_production_db_replica"

# Setup pg_lakehouse access to S3

psql -U postgres -d ${db_name} -p 5433 <<-SQL
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

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE SERVER IF NOT EXISTS ${s3_server_name}
  FOREIGN DATA WRAPPER s3_wrapper
  OPTIONS (region '${AWS_REGION}');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER ${s3_server_name}
  OPTIONS (
    access_key_id '${AWS_ACCESS_KEY_ID}',
    secret_access_key '${AWS_SECRET_ACCESS_KEY}'
  );
SQL

# Create S3-backed tables

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS recommendations_original (
    _surrogate_key_hash TEXT,
    job_resource_link_id INTEGER,
    candidate_id INTEGER,
    job_resource_title TEXT,
    job_resource_title_normalized TEXT,
    candidate_job_title TEXT,
    candidate_job_title_normalized TEXT,
    job_created_at DATE,
    job_expire_at TEXT,
    job_zip3 INTEGER,
    candidate_zip3 INTEGER,
    normalized_candidate_job_title_match_score NUMERIC
  )

  SERVER ${s3_server_name}
  OPTIONS (path 's3://rise-kit-files-production/recommendations/json/', extension 'json');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE OR REPLACE VIEW recommendations AS
  SELECT 
      _surrogate_key_hash,
      job_resource_link_id,
      candidate_id,
      job_resource_title,
      job_resource_title_normalized,
      candidate_job_title,
      candidate_job_title_normalized,
      job_created_at,
      CASE
          WHEN job_expire_at = '' THEN NULL
          ELSE job_expire_at::DATE
      END AS job_expire_at,
      job_zip3,
      candidate_zip3,
      normalized_candidate_job_title_match_score
  FROM 
      recommendations_original;
SQL

# Setup FWD access to foreign database tables

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE SERVER IF NOT EXISTS ${foreign_db_server_name}
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host '${APPLICATION_DB_HOSTNAME}', port '${APPLICATION_DB_PORT}', dbname '${APPLICATION_DB_NAME}');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE USER MAPPING IF NOT EXISTS FOR postgres
  SERVER ${foreign_db_server_name}
  OPTIONS (user '${APPLICATION_DB_USERNAME}', password '${APPLICATION_DB_PASSWORD}');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS ahoy_events (
    id bigint NOT NULL,
    visit_id bigint,
    user_id bigint,
    name character varying,
    properties jsonb,
    time timestamp without time zone
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'ahoy_events');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS ahoy_visits (
      id bigint NOT NULL,
      visit_token character varying,
      visitor_token character varying,
      user_id bigint,
      ip character varying,
      user_agent text,
      referrer text,
      referring_domain character varying,
      landing_page text,
      browser character varying,
      os character varying,
      device_type character varying,
      country character varying,
      region character varying,
      city character varying,
      latitude double precision,
      longitude double precision,
      utm_source character varying,
      utm_medium character varying,
      utm_term character varying,
      utm_content character varying,
      utm_campaign character varying,
      app_version character varying,
      os_version character varying,
      platform character varying,
      started_at timestamp without time zone
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'ahoy_visits');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS resumes (
      id bigint NOT NULL,
      file character varying,
      candidate_profile_id bigint NOT NULL,
      revision_date timestamp without time zone,
      data jsonb DEFAULT '{}'::jsonb,
      created_at timestamp(6) without time zone NOT NULL,
      updated_at timestamp(6) without time zone NOT NULL
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'resumes');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
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

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS shared_resources (
    id bigint NOT NULL,
    resource_link_id bigint,
    shared_resourceable_id bigint,
    shared_resourceable_type character varying,
    shared_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    activity jsonb DEFAULT '{}'::jsonb,
    discarded_at timestamp without time zone
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'shared_resources');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS genders (
      id bigint NOT NULL,
      name character varying,
      created_at timestamp(6) without time zone NOT NULL,
      updated_at timestamp(6) without time zone NOT NULL
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'genders');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS ethnicities (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'ethnicities');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS military_statuses (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'military_statuses');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS groups (
    id bigint NOT NULL,
    name character varying,
    description text,
    organization_id bigint,
    pathway_id bigint,
    user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    creator_id bigint,
    active_users_count integer DEFAULT 0,
    discarded_at timestamp without time zone,
    links jsonb DEFAULT '{}'::jsonb,
    slug character varying,
    brand jsonb DEFAULT '{}'::jsonb,
    logo_url character varying
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'groups');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS teams (
    id bigint NOT NULL,
    name character varying,
    organization_id bigint NOT NULL,
    zip_code character varying,
    area_code character varying,
    phone_number character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    description text,
    active_users_count integer DEFAULT 0,
    discarded_at timestamp without time zone,
    phone_number_sid character varying
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'teams');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS criminal_record_options (
    id bigint NOT NULL,
    name character varying,
    hint character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'criminal_record_options');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS resource_links (
      id bigint NOT NULL,
      resource_category_id bigint,
      url character varying,
      title character varying,
      description text,
      remote boolean,
      address character varying,
      zip_code character varying,
      criminal_record_option_id bigint,
      type character varying,
      associated_organization character varying,
      share_with_my_organization boolean,
      share_with_my_sub_orgs boolean,
      share_with_nonprofit_organizations boolean,
      share_with_risekit_nonprofit_network boolean,
      created_at timestamp(6) without time zone NOT NULL,
      updated_at timestamp(6) without time zone NOT NULL,
      user_id bigint,
      organization_id bigint,
      latitude numeric(15,10),
      longitude numeric(15,10),
      expire_at timestamp without time zone,
      discarded_at timestamp without time zone,
      slug character varying,
      public_link character varying,
      last_interested_on timestamp without time zone,
      share_with_teams boolean DEFAULT false,
      limits jsonb DEFAULT '{}'::jsonb,
      pdf_url character varying,
      keywords jsonb DEFAULT '{}'::jsonb,
      merge_data jsonb DEFAULT '{}'::jsonb,
      contact jsonb DEFAULT '{}'::jsonb,
      ukg_data jsonb DEFAULT '{}'::jsonb,
      time_commitment character varying,
      experience_level character varying,
      shift character varying,
      immediate_need character varying,
      kind character varying,
      time_frame character varying,
      lonlat geography(Point,4326)
    )
    SERVER ${foreign_db_server_name}
    OPTIONS (table_name 'resource_links');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS candidate_profiles (
    id bigint NOT NULL,
    home_phone character varying,
    address1 character varying,
    city character varying,
    state character varying,
    country character varying,
    zip_code character varying,
    date_of_birth timestamp without time zone,
    candidate_id bigint,
    referral_code character varying,
    linkedin character varying,
    picture_url character varying,
    drivers_license_number character varying,
    drivers_license_state character varying,
    emergency_contact_name character varying,
    emergency_contact_phone character varying,
    drivers_license_expire timestamp without time zone,
    latitude numeric,
    longitude numeric,
    timezone character varying,
    query character varying,
    rating integer,
    keep_dropdown_open boolean,
    company_name character varying,
    job_title character varying,
    accommodations character varying,
    education character varying,
    lead character varying,
    lead_explain character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    slug character varying,
    search_name character varying,
    is_active boolean,
    send_daily_notification boolean,
    send_document_approve_notification boolean,
    send_document_review_notification boolean,
    last_activated_at timestamp without time zone,
    military character varying,
    failed_attempts integer,
    facility character varying,
    target_release_date timestamp without time zone,
    actual_release_date timestamp without time zone,
    address2 character varying,
    city_of_release character varying,
    county_of_release character varying,
    commitment_length character varying,
    homeless character varying,
    foster_care character varying,
    family_name1 character varying,
    family_relation1 character varying,
    family_email1 character varying,
    family_phone1 character varying,
    family_name2 character varying,
    family_relation2 character varying,
    family_email2 character varying,
    family_phone2 character varying,
    recidivism_roster_date timestamp without time zone,
    recidivism_roster_status1_id character varying,
    recidivism_roster_status3_id character varying,
    ethnicity_id bigint,
    military_status_id bigint,
    gender_id bigint,
    candidate_status_id bigint,
    locale character varying,
    encrypted_inmate_number_ciphertext text,
    encrypted_last_known_address_ciphertext text,
    encrypted_release_address_ciphertext text,
    encrypted_ssn_ciphertext text,
    encrypted_inmate_number_bidx character varying,
    encrypted_last_known_address_bidx character varying,
    encrypted_release_address_bidx character varying,
    encrypted_ssn_bidx character varying,
    age integer,
    secondary_contact_name character varying,
    secondary_contact_relation character varying,
    secondary_contact_email character varying,
    secondary_contact_phone_number character varying,
    is_homeless boolean DEFAULT false,
    has_foster_care boolean DEFAULT false,
    shared_resources jsonb DEFAULT '{}'::jsonb,
    job_ready boolean DEFAULT false,
    resume_url character varying,
    pathway_step_data jsonb DEFAULT '{}'::jsonb,
    drivers_license_number_ciphertext text,
    drivers_license_expire_ciphertext text,
    drivers_license_number_bidx character varying,
    drivers_license_expire_bidx character varying,
    survey_data jsonb DEFAULT '{}'::jsonb,
    criminal_record character varying,
    fact_data jsonb DEFAULT '{}'::jsonb,
    employment_status character varying,
    skills jsonb DEFAULT '[]'::jsonb,
    alumni boolean DEFAULT false,
    keywords jsonb DEFAULT '{}'::jsonb,
    challenges jsonb DEFAULT '[]'::jsonb,
    work_experiences jsonb DEFAULT '[]'::jsonb,
    certifications jsonb DEFAULT '[]'::jsonb,
    barriers jsonb DEFAULT '[]'::jsonb,
    immediate_needs jsonb DEFAULT '[]'::jsonb,
    disability character varying,
    lonlat public.geography(Point,4326),
    address character varying
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'candidate_profiles');
SQL

psql -U postgres -d ${db_name} -p 5433 <<-SQL
  CREATE FOREIGN TABLE IF NOT EXISTS organizations (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    description text,
    user_id bigint,
    image_url character varying,
    parent_id bigint,
    space_token character varying,
    area_code character varying,
    phone_number character varying,
    domain character varying,
    zip_code character varying,
    invite_link character varying,
    employee_count character varying,
    merge_data jsonb DEFAULT '{}'::jsonb,
    links jsonb DEFAULT '{}'::jsonb,
    slug character varying,
    paid boolean DEFAULT false,
    organization_id bigint,
    phone_number_sid character varying,
    notifications jsonb DEFAULT '{}'::jsonb,
    ukg_data jsonb DEFAULT '{}'::jsonb,
    brand jsonb DEFAULT '{}'::jsonb,
    lonlat public.geography(Point,4326),
    address character varying
  )
  SERVER ${foreign_db_server_name}
  OPTIONS (table_name 'organizations');
SQL

echo "Foreign table setup complete"
