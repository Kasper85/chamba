import { describe, it, expect, vi } from 'vitest';
import { ChatService } from '../src/chat/chat.service.js';

function setup(status = 'EN_EJECUCION', userId = 'client') {
  const messages = new Map<string, unknown>();
  const tx = {
    $queryRaw: vi.fn(),
    jobRequest: { findUnique: vi.fn().mockResolvedValue({ id: 'job', status, clientId: 'client', workerId: 'profile', worker: { userId: 'worker' } }) },
    message: {
      findMany: vi.fn().mockResolvedValue([]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      upsert: vi.fn().mockImplementation(({ create }) => {
        const key = `${create.senderId}:${create.clientMessageId}`;
        if (!messages.has(key)) messages.set(key, create);
        return messages.get(key);
      }),
    },
  };
  const prisma = { $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) };
  return { chat: new ChatService(prisma as never), tx, messages, userId };
}

describe('Temporary chat permissions and lifecycle', () => {
  it('validates and stores audio with the same idempotent message key', async () => {
    const { chat, tx } = setup();
    await chat.send('job', 'client', 'voice-id', 'Mensaje de voz', '//FQgAAAAA==', 2);
    expect(tx.message.upsert.mock.calls[0][0].create).toMatchObject({ audioBase64: '//FQgAAAAA==', audioDurationSeconds: 2 });
    await expect(chat.send('job', 'client', 'bad', 'Mensaje de voz', 'AA==', 2)).rejects.toThrow('Audio inválido');
    await expect(chat.send('job', 'client', 'too-long', 'Mensaje de voz', '//FQgAAAAA==', 31)).rejects.toThrow('Audio inválido');
  });
  it('rejects unrelated users on read, send and delivery confirmation', async () => {
    const { chat } = setup();
    await expect(chat.list('job', 'stranger')).rejects.toThrow('No tienes acceso');
    await expect(chat.send('job', 'stranger', 'id', 'hola')).rejects.toThrow('No tienes acceso');
    await expect(chat.delivered('job', 'stranger')).rejects.toThrow('No tienes acceso');
  });
  it.each(['COMPLETADA', 'CANCELADA', 'REEMBOLSADA'])('blocks a closed job %s', async status => {
    const { chat, tx } = setup(status);
    expect(await chat.list('job', 'client')).toMatchObject({ closed: true, messages: [] });
    await expect(chat.send('job', 'client', 'id', 'hola')).rejects.toThrow('cerrado');
    expect(tx.message.upsert).not.toHaveBeenCalled();
  });
  it('allows conversation during dispute', async () => {
    const { chat } = setup('EN_DISPUTA');
    await expect(chat.send('job', 'worker', 'id', 'aclaración')).resolves.toMatchObject({ senderId: 'worker' });
  });
  it('reuses the client identifier on retry', async () => {
    const { chat, messages } = setup();
    await chat.send('job', 'client', 'stable-id', 'hola');
    await chat.send('job', 'client', 'stable-id', 'hola');
    expect(messages.size).toBe(1);
  });
  it('marks only received messages as delivered', async () => {
    const { chat, tx } = setup();
    await chat.delivered('job', 'worker', ['received-id']);
    expect(tx.message.updateMany).toHaveBeenCalledWith({ where: { jobRequestId: 'job', id: { in: ['received-id'] }, senderId: { not: 'worker' }, deliveredAt: null }, data: { deliveredAt: expect.any(Date) } });
  });
  it('rejects blank messages', async () => {
    const { chat } = setup();
    await expect(chat.send('job', 'client', 'id', '  ')).rejects.toThrow('inválido');
  });
});
