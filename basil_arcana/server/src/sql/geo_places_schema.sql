-- Geo places dictionary schema for natal place autocomplete.
-- Designed for PostgreSQL (Railway).

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS geo_places (
  place_id TEXT PRIMARY KEY,
  geoname_id BIGINT NOT NULL UNIQUE,
  country_code TEXT NOT NULL,
  country_name TEXT NOT NULL,
  admin1_code TEXT NOT NULL DEFAULT '',
  admin1_name TEXT NOT NULL DEFAULT '',
  admin2_code TEXT NOT NULL DEFAULT '',
  city_name TEXT NOT NULL,
  city_name_ascii TEXT NOT NULL DEFAULT '',
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  timezone TEXT NOT NULL DEFAULT '',
  population BIGINT NOT NULL DEFAULT 0,
  feature_code TEXT NOT NULL DEFAULT '',
  modification_date DATE NULL
);

CREATE TABLE IF NOT EXISTS geo_place_aliases (
  place_id TEXT NOT NULL REFERENCES geo_places(place_id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  alias_normalized TEXT NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (place_id, alias_normalized)
);

CREATE INDEX IF NOT EXISTS geo_places_country_population_idx
  ON geo_places (country_code, population DESC);

CREATE INDEX IF NOT EXISTS geo_place_aliases_alias_norm_trgm_idx
  ON geo_place_aliases USING GIN (alias_normalized gin_trgm_ops);

CREATE INDEX IF NOT EXISTS geo_place_aliases_place_id_idx
  ON geo_place_aliases (place_id);

-- Import example:
--   \copy geo_places FROM 'server/data/geo/cis_places.csv' CSV HEADER;
--   \copy geo_place_aliases FROM 'server/data/geo/cis_place_aliases.csv' CSV HEADER;

