ARG PG_VERSION=15.6
ARG PG_MAJOR_VERSION=15

FROM flyio/postgres-flex-timescaledb:${PG_VERSION}

ARG PG_LAKEHOUSE_VERSION=0.7.1
ARG PG_MAJOR_VERSION

# pg_Lakehouse
RUN curl -L "https://github.com/paradedb/paradedb/releases/download/v${PG_LAKEHOUSE_VERSION}/pg_lakehouse-v${PG_LAKEHOUSE_VERSION}-pg${PG_MAJOR_VERSION}-amd64-ubuntu2204.deb" -o /tmp/pg_lakehouse.deb \
    && apt-get install -y /tmp/pg_lakehouse.deb \
    && apt autoremove -y \
    && rm /tmp/pg_lakehouse.deb