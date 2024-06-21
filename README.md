# Fly Postgres Extended

This is based on the timescaledb image defined in `fly-apps/postgres-flex`.

### Extensions to Support

- [x] pg_lakehouse
- [x] timescaledb
- [x] postgres_fdw
- [ ] pg_search
- [ ] pgvector
- [x] pg_cron

### TODO

- [ ] ~Add script to modify postgresql.conf to include extensions~ This proved not to be possible given the way that Fly aggressively manages config files
- [ ] Add script to activate extensions in the database
- [ ] Add support for pgxman or trunk for package management --makes installation of extensions easier

### Deployment on Fly

1. If not already done, build the image and push to Docker Hub via the following commands:

```bash
docker build . -t <your-dockerhub-username>/flypg-extended:latest --platform "linux/amd64" -f extended.Dockerfile
 
```

2. Deploy a new postgres cluster on Fly using the following command:

```bash
fly postgres create --image-ref <your-dockerhub-username>/flypg-extended:latest
```

### Post-Deployment Setup

#### Establish secrets and environment variables

```
fly secrets set --app risekit-analytics-db \
  APPLICATION_DB_USERNAME=#### \
  APPLICATION_DB_PASSWORD=############### \
  AWS_ACCESS_KEY_ID=#################### \
  AWS_SECRET_ACCESS_KEY=####### \
  AWS_REGION='us-east-2'
```

_Note_: The `APPLICATION_DB_USERNAME` is currently set to `mike`, but should probably be set to `risekit-analytics` or something similar.

#### Setup preload libraries

Because Fly aggressively manages the PostgreSQL configuration files, there does not seem to be a way to set this value at build time. Instead, it must be set post-deployment:

```bash
fly postgres config update --shared-preload-libraries repmgr,timescaledb,pg_lakehouse,pg_cron
```

The following script will initialize extensions and foreign data tables, and will create a materialized views, and a `pg_cron` job to refresh that view:

```bash
fly ssh console --pty -C '/usr/local/bin/risekit_db_init.sh' --machine ##############
```

Note that this command has to be run on the primary node of the cluster.

#### Test queries

You should now be able to connect to the database:

```bash
fly proxy 5433 # connect via wireguard as usual
```

And run the following queries:

```sql
-- Checks if connection to S3 is working
SELECT * from recommendations_dictionaries LIMIT 1;

-- Checks if the materialized view is working
SELECT * FROM recommendations_view LIMIT 1;


-- Checks if the pg_cron job has been created
SELECT * FROM cron.job;

-- Checks if the pg_cron job has been run
-- (should be empty until the first run, which is scheduled on the hour)

SELECT * FROM cron.job_run_details;
```

This is how you would un-schedule the `pg_cron` job:

```sql
SELECT cron.unschedule('refresh_recommendations_view', '0 * * * *', 'refresh materialized view recommendations_view');
```

### Useful pg_cron references

* https://github.com/citusdata/pg_cron
* https://datawookie.dev/blog/2022/03/scheduling-refresh-materialised-view/
* https://medium.com/full-stack-architecture/postgresql-caching-with-pg-cron-and-materialized-views-3403697eadbf
* https://github.com/erichosick/postgresql-cron-example
* https://www.postgresql.org/docs/current/sql-creatematerializedview.html
* https://www.postgresql.org/docs/current/sql-refreshmaterializedview.html

### Example materialized view query

This query illustrates how to extract values from the `jsonb` dictionary in `recommendations_view`:

```sql
SELECT
data->>'_surrogate_key_hash' AS surrogate_key_hash,
data->>'job_title_normalized' AS job_title_normalized,
data->>'job_resource_title' AS job_resource_title,
data->>'job_created_at' AS job_created_at,
data->>'job_zip3' AS job_zip3,
data->>'job_expire_at' AS job_expire_at,
data->>'candidate_id' AS candidate_id,
data->>'candidate_zip3' AS candidate_zip3,
data->>'candidate_job_title' AS candidate_job_title,
data->>'candidate_job_title_normalized' AS candidate_job_title_normalized,
data->>'job_resource_link_id' AS job_resource_link_id,
data->>'normalized_candidate_job_title_match_score' AS normalized_candidate_job_title_match_score
FROM recommendations_view
ORDER BY job_created_at DESC
```