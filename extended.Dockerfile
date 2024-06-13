ARG PG_VERSION=15.6
FROM flyio/postgres-flex-timescaledb:${PG_VERSION}

ARG PG_MAJOR_VERSION=15
ARG PG_LAKEHOUSE_VERSION=0.7.5

ARG RELEASE_NAME="pg_lakehouse-v${PG_LAKEHOUSE_VERSION}-ubuntu-22.04-amd64-pg${PG_MAJOR_VERSION}.deb"
ARG RELEASE_URL="https://github.com/paradedb/paradedb/releases/download/v${PG_LAKEHOUSE_VERSION}/${RELEASE_NAME}"

RUN curl -L $RELEASE_URL -o /tmp/pg_lakehouse.deb

RUN apt-get install -y /tmp/pg_lakehouse.deb \
    && apt autoremove -y \
    && rm /tmp/pg_lakehouse.deb

COPY postgresql.preload_libraries.conf /data/postgresql/
RUN echo "include 'postgresql.preload_libraries.conf'" >> /data/postgresql/postgresql.conf

COPY init_db.sh /docker-entrypoint-initdb.d/