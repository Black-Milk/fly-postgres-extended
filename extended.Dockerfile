ARG PG_VERSION=15.6
ARG PG_MAJOR_VERSION=15

FROM flyio/postgres-flex-timescaledb:${PG_VERSION}

ARG PG_LAKEHOUSE_VERSION=0.7.1
ARG PG_SEARCH_VERSION=0.7.1
ARG PG_MAJOR_VERSION

# pg_lakehouse
RUN curl -L "https://github.com/paradedb/paradedb/releases/download/v${PG_LAKEHOUSE_VERSION}/pg_lakehouse-v${PG_LAKEHOUSE_VERSION}-pg${PG_MAJOR_VERSION}-amd64-ubuntu2204.deb" -o /tmp/pg_lakehouse.deb \
    && apt-get install -y /tmp/pg_lakehouse.deb \
    && apt autoremove -y \
    && rm /tmp/pg_lakehouse.deb

# pg_search
RUN curl -L "https://github.com/paradedb/paradedb/releases/download/v${PG_SEARCH_VERSION}/pg_search-v${PG_SEARCH_VERSION}-pg${PG_MAJOR_VERSION}-amd64-ubuntu2204.deb" -o /tmp/pg_search.deb \
    && apt-get install -y /tmp/pg_search.deb \
    && apt autoremove -y \
    && rm /tmp/pg_search.deb

# pgxman
COPY pgxman-packfiles /tmp/pgxman

RUN curl -sfL https://install.pgx.sh | sh -s -- /tmp/pgxman/pgxman_${PG_MAJOR_VERSION}.yaml && \
  rm -rf /tmp/pgxman