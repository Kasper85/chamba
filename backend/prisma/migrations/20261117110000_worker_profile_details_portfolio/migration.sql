-- Add only the profile fields; preserve the existing PostGIS index and all rows.
ALTER TABLE "worker_profiles"
ADD COLUMN "base_rate" DOUBLE PRECISION,
ADD COLUMN "dni" TEXT,
ADD COLUMN "experience_years" INTEGER,
ADD COLUMN "portfolio" JSONB NOT NULL DEFAULT '[]',
ADD COLUMN "service_radius_km" INTEGER,
ADD COLUMN "skills" TEXT[] DEFAULT ARRAY[]::TEXT[];
