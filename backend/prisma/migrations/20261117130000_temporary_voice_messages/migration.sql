-- Voice content shares the lifecycle and deletion triggers of each message.
ALTER TABLE "messages" ADD COLUMN "audio_base64" TEXT,
ADD COLUMN "audio_duration_seconds" INTEGER;
