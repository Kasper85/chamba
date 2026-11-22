-- Generated from prisma migrate diff; preserve the existing PostGIS index.
CREATE TABLE "messages" (
  "id" TEXT NOT NULL,
  "client_message_id" TEXT NOT NULL,
  "job_request_id" TEXT NOT NULL,
  "sender_id" TEXT NOT NULL,
  "text" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "delivered_at" TIMESTAMP(3),
  CONSTRAINT "messages_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "messages_job_request_id_created_at_idx" ON "messages"("job_request_id", "created_at");
CREATE UNIQUE INDEX "messages_job_request_id_sender_id_client_message_id_key" ON "messages"("job_request_id", "sender_id", "client_message_id");
ALTER TABLE "messages" ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "messages" ADD CONSTRAINT "messages_job_request_id_fkey" FOREIGN KEY ("job_request_id") REFERENCES "job_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Purge atomically with service closure or dispute resolution. Receipts and ledger are untouched.
CREATE FUNCTION purge_closed_service_messages() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target_id TEXT;
BEGIN
  IF TG_TABLE_NAME = 'job_requests' THEN target_id := NEW.id;
  ELSE target_id := NEW.job_request_id;
  END IF;
  PERFORM id FROM job_requests WHERE id = target_id FOR UPDATE;
  IF EXISTS (SELECT 1 FROM job_requests WHERE id = target_id AND status IN ('COMPLETADA', 'CANCELADA', 'REEMBOLSADA'))
     AND NOT EXISTS (SELECT 1 FROM disputes WHERE job_request_id = target_id AND status IN ('ABIERTA', 'EN_REVISION')) THEN
    DELETE FROM messages WHERE job_request_id = target_id;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER purge_messages_on_job_closure AFTER UPDATE OF status ON job_requests
  FOR EACH ROW EXECUTE FUNCTION purge_closed_service_messages();
CREATE TRIGGER purge_messages_on_dispute_resolution AFTER UPDATE OF status ON disputes
  FOR EACH ROW EXECUTE FUNCTION purge_closed_service_messages();
