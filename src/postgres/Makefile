$(OBJS): Makefile
PG_VERSION_MAJOR=16
PG_CONFIG=/usr/lib/postgresql/${PG_VERSION_MAJOR}/bin/pg_config
DATA = $(wildcard *--*.sql)
EXTENSION = pg_curl
MODULE_big = $(EXTENSION)
OBJS = $(EXTENSION).o
#PG_CONFIG = pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
REGRESS = $(patsubst sql/%.sql,%,$(TESTS))
SHLIB_LINK = -lcurl
TESTS = $(wildcard sql/*.sql)
include $(PGXS)
