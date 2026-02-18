# Geo Cities Reference (CIS)

This guide builds a city/place reference for natal chart birth place selection from public GeoNames dumps.

## What it generates

- `basil_arcana/server/data/geo/cis_places.csv`
- `basil_arcana/server/data/geo/cis_place_aliases.csv`
- `basil_arcana/server/data/geo/cis_places_meta.json`

Default country scope:

- `RU, KZ, BY, KG, UZ, TJ, TM, AM, AZ, MD`

## Build

```bash
python3 basil_arcana/tools/build_cis_cities_reference.py
```

Useful options:

```bash
python3 basil_arcana/tools/build_cis_cities_reference.py \
  --countries RU,KZ,BY,KG,UZ,TJ,TM,AM,AZ,MD \
  --min-population 0 \
  --max-places-per-country 0
```

Quick test run:

```bash
python3 basil_arcana/tools/build_cis_cities_reference.py \
  --countries RU,KZ \
  --max-places-per-country 500
```

## Railway Postgres import

Run SQL schema:

```sql
\i basil_arcana/server/src/sql/geo_places_schema.sql
```

Load CSV files:

```sql
\copy geo_places FROM 'basil_arcana/server/data/geo/cis_places.csv' CSV HEADER;
\copy geo_place_aliases FROM 'basil_arcana/server/data/geo/cis_place_aliases.csv' CSV HEADER;
```

## Search query example

```sql
SELECT
  p.place_id,
  p.city_name,
  p.admin1_name,
  p.country_code,
  p.latitude,
  p.longitude,
  p.timezone,
  p.population
FROM geo_place_aliases a
JOIN geo_places p ON p.place_id = a.place_id
WHERE a.alias_normalized % lower($1)
ORDER BY similarity(a.alias_normalized, lower($1)) DESC, p.population DESC
LIMIT 20;
```

