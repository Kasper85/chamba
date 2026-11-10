-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('CLIENT', 'WORKER', 'SUPPORT', 'ADMIN');

-- CreateEnum
CREATE TYPE "JobStatus" AS ENUM ('BUSCANDO', 'NEGOCIANDO', 'ACEPTADA', 'EN_CAMINO', 'EN_SITIO', 'EN_EJECUCION', 'POR_CONFIRMAR', 'COMPLETADA', 'EN_DISPUTA', 'CANCELADA', 'REEMBOLSADA');

-- CreateEnum
CREATE TYPE "BidStatus" AS ENUM ('PENDIENTE', 'ACEPTADA', 'RECHAZADA', 'CONTRAOFERTA');

-- CreateEnum
CREATE TYPE "DisputeStatus" AS ENUM ('ABIERTA', 'EN_REVISION', 'RESUELTA_TRABAJADOR', 'RESUELTA_CLIENTE', 'RESUELTA_DIVIDIDA');

-- CreateEnum
CREATE TYPE "TicketStatus" AS ENUM ('ABIERTO', 'EN_PROCESO', 'CERRADO');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "LedgerEntryType" ADD VALUE 'COMMISSION';
ALTER TYPE "LedgerEntryType" ADD VALUE 'SERVICE_FEE';
ALTER TYPE "LedgerEntryType" ADD VALUE 'COMPENSATION';


-- AlterTable
ALTER TABLE "users" ADD COLUMN     "role" "UserRole" NOT NULL DEFAULT 'CLIENT';

-- AlterTable
ALTER TABLE "worker_profiles" ADD COLUMN     "incidents_count" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "job_requests" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "worker_id" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "budget" DECIMAL(12,2) NOT NULL,
    "agreed_price" DECIMAL(12,2),
    "status" "JobStatus" NOT NULL DEFAULT 'BUSCANDO',
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "district" TEXT NOT NULL,
    "address" TEXT,
    "reference" TEXT,
    "is_sos" BOOLEAN NOT NULL DEFAULT false,
    "urgency" TEXT NOT NULL DEFAULT 'MEDIA',
    "security_pin" TEXT,
    "is_pin_verified" BOOLEAN NOT NULL DEFAULT false,
    "before_photo_url" TEXT,
    "after_photo_url" TEXT,
    "accepted_at" TIMESTAMP(3),
    "deposit_deadline" TIMESTAMP(3),
    "confirmed_at" TIMESTAMP(3),
    "auto_release_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "job_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bids" (
    "id" TEXT NOT NULL,
    "job_request_id" TEXT NOT NULL,
    "worker_id" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "message" TEXT,
    "voice_note_url" TEXT,
    "estimated_eta_minutes" INTEGER,
    "status" "BidStatus" NOT NULL DEFAULT 'PENDIENTE',
    "counter_amount" DECIMAL(12,2),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "bids_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "disputes" (
    "id" TEXT NOT NULL,
    "job_request_id" TEXT NOT NULL,
    "opened_by_id" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "client_statement" TEXT,
    "worker_statement" TEXT,
    "status" "DisputeStatus" NOT NULL DEFAULT 'ABIERTA',
    "ai_recommendation" TEXT,
    "ai_confidence" DOUBLE PRECISION,
    "resolution_notes" TEXT,
    "resolved_by_id" TEXT,
    "worker_split_percent" DOUBLE PRECISION,
    "appeals_count" INTEGER NOT NULL DEFAULT 0,
    "appeal_reason" TEXT,
    "resolved_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "disputes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ratings" (
    "id" TEXT NOT NULL,
    "job_request_id" TEXT NOT NULL,
    "from_user_id" TEXT NOT NULL,
    "to_user_id" TEXT NOT NULL,
    "stars" INTEGER NOT NULL,
    "comment" TEXT,
    "tip_amount" DECIMAL(12,2) DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ratings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "support_tickets" (
    "id" TEXT NOT NULL,
    "job_request_id" TEXT,
    "user_id" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "status" "TicketStatus" NOT NULL DEFAULT 'ABIERTO',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "job_requests_client_id_idx" ON "job_requests"("client_id");

-- CreateIndex
CREATE INDEX "job_requests_worker_id_idx" ON "job_requests"("worker_id");

-- CreateIndex
CREATE INDEX "job_requests_status_idx" ON "job_requests"("status");

-- CreateIndex
CREATE INDEX "bids_job_request_id_idx" ON "bids"("job_request_id");

-- CreateIndex
CREATE INDEX "bids_worker_id_idx" ON "bids"("worker_id");

-- CreateIndex
CREATE INDEX "disputes_job_request_id_idx" ON "disputes"("job_request_id");

-- CreateIndex
CREATE INDEX "disputes_opened_by_id_idx" ON "disputes"("opened_by_id");

-- CreateIndex
CREATE INDEX "ratings_job_request_id_idx" ON "ratings"("job_request_id");

-- CreateIndex
CREATE INDEX "ratings_to_user_id_idx" ON "ratings"("to_user_id");

-- CreateIndex
CREATE INDEX "support_tickets_job_request_id_idx" ON "support_tickets"("job_request_id");

-- CreateIndex
CREATE INDEX "support_tickets_user_id_idx" ON "support_tickets"("user_id");

-- AddForeignKey
ALTER TABLE "job_requests" ADD CONSTRAINT "job_requests_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "job_requests" ADD CONSTRAINT "job_requests_worker_id_fkey" FOREIGN KEY ("worker_id") REFERENCES "worker_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bids" ADD CONSTRAINT "bids_job_request_id_fkey" FOREIGN KEY ("job_request_id") REFERENCES "job_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bids" ADD CONSTRAINT "bids_worker_id_fkey" FOREIGN KEY ("worker_id") REFERENCES "worker_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "disputes" ADD CONSTRAINT "disputes_job_request_id_fkey" FOREIGN KEY ("job_request_id") REFERENCES "job_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "disputes" ADD CONSTRAINT "disputes_opened_by_id_fkey" FOREIGN KEY ("opened_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_job_request_id_fkey" FOREIGN KEY ("job_request_id") REFERENCES "job_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_job_request_id_fkey" FOREIGN KEY ("job_request_id") REFERENCES "job_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

