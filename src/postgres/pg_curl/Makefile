$(OBJS): Makefile

EXTENSION = pg_curl
MODULE_big = $(EXTENSION)
OBJS = $(EXTENSION).o
DATA = $(wildcard *--*.sql)

# Use the Postgres toolchain available in PATH by default.
# Override if needed: make PG_CONFIG=/usr/lib/postgresql/18/bin/pg_config
PG_CONFIG ?= pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)

SHLIB_LINK = -lcurl

TESTS = $(wildcard sql/*.sql)
REGRESS = $(patsubst sql/%.sql,%,$(TESTS))

include $(PGXS)
