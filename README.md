# Fly Postgres Extended

This is based on the timescaledb image defined in `fly-apps/postgres-flex`.

### Extensions to Support

- [x] pg_lakehouse
- [x] timescaledb
- [ ] postgres_fdw
- [ ] pg_search
- [ ] pgvector
- [ ] pg_cron

### TODO

- [ ] Add script to modify postgresql.conf to include extensions
- [ ] Add script to activate extensions in the database
- [ ] Add support for pgxman or trunk for package management --makes
  installation of extensions easier

### Deployment on Fly

Here are the steps that were taken to deploy on Fly successfully:

1. Build the image and push to Docker Hub via the following commands:

```bash
docker build . -t <your-dockerhub-username>/flypg-extended:latest --platform "linux/amd64" -f extended.Dockerfile
docker pushd <your-dockerhub-username>/flypg-extended:latest
```

Feel free to change tags as you see fit.

2. Deploy a new postgres cluster on Fly using the following command:

```bash
fly postgres create --image-ref <your-dockerhub-username>/flypg-extended:latest
```

Follow the interative prompt to configure the deployment settings. Be sure to
copy Consideration
should be made for the following items:

1. Non-shared cpu resources
2. Sufficient volume size for your data
3. The number of nodes in the cluster, typically 3 or more for HA (high
   availability)
4. The region where the cluster will be deployed; if you're using the
   `postgres_fdw` extension, then it's best to have this in the same region as
   the
   source database you're referencing to query data from.
5. The organization for the deployment
6. Your application name

Once the deployment is complete, be sure to copy the fly.toml for the
application via:

```bash
flyctl config save -a <app-name-for-your-pg-deployment> 
```

With the fly.toml saved, you'll want to add the following build section:

 ```toml
 [build]
image = "<your-dockerhub-username>/flypg-extended:latest"
 ```

This will ensure that the image is used for future deployments whenever you
invoke `flyctl deploy` in the project directory where the fly.toml was saved.