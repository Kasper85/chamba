-- Migration: 20261020180000_enable_postgis_and_worker_location
-- Description: Enable PostGIS extension and add geospatial Point column with GiST index to worker_profiles

-- 1. Enable PostGIS extension for spatial queries (ST_DWithin, ST_MakePoint, ST_Distance)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Add geometry(Point, 4326) column to worker_profiles
ALTER TABLE "worker_profiles" ADD COLUMN IF NOT EXISTS "location" geometry(Point, 4326);

-- 3. Create spatial GiST index for sub-millisecond proximity queries
CREATE INDEX IF NOT EXISTS "worker_profiles_location_idx" ON "worker_profiles" USING GIST ("location");
