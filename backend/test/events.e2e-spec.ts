import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { io, Socket } from 'socket.io-client';
import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

describe('CHAMBA Real-Time WebSockets & Bids Flow (e2e)', () => {
  let app: INestApplication;
  let jwtService: JwtService;
  let serverAddress: string;
  let clientSocket: Socket;
  let workerSocket: Socket;

  let clientToken: string;
  let workerToken: string;

  const mockPrisma = {
    $connect: vi.fn(),
    $disconnect: vi.fn(),
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrisma)
      .compile();

    app = moduleFixture.createNestApplication();
    jwtService = moduleFixture.get<JwtService>(JwtService);

    await app.listen(0); // Puerto aleatorio disponible
    const httpServer = app.getHttpServer();
    const port = httpServer.address().port;
    serverAddress = `http://localhost:${port}`;

    // Generar tokens JWT válidos para el cliente y el técnico
    clientToken = jwtService.sign({
      sub: 'client-lucia-1',
      email: 'lucia@chamba.pe',
      fullName: 'Lucía Fernández',
    });

    workerToken = jwtService.sign({
      sub: 'worker-jorge-1',
      email: 'jorge.quispe@chamba.pe',
      fullName: 'Jorge Quispe Baldera',
    });
  });

  afterAll(async () => {
    if (clientSocket?.connected) clientSocket.disconnect();
    if (workerSocket?.connected) workerSocket.disconnect();
    await app.close();
  });

  it('1. Debe rechazar la conexión WebSocket si no se envía token JWT', async () => {
    const unauthSocket = io(serverAddress, {
      transports: ['websocket'],
      autoConnect: false,
    });

    const disconnectPromise = new Promise<string>((resolve) => {
      unauthSocket.on('connect_error', (err) => resolve(err.message));
      unauthSocket.on('disconnect', (reason) => resolve(reason));
    });

    unauthSocket.connect();
    const result = await disconnectPromise;
    expect(result).toBeDefined();

    unauthSocket.close();
  });

  it('2. Debe conectar clientes y trabajadores autenticados mediante handshake auth token', async () => {
    clientSocket = io(serverAddress, {
      transports: ['websocket'],
      auth: { token: clientToken },
    });

    workerSocket = io(serverAddress, {
      transports: ['websocket'],
      auth: { token: workerToken },
    });

    await Promise.all([
      new Promise<void>((resolve) => clientSocket.on('connect', () => resolve())),
      new Promise<void>((resolve) => workerSocket.on('connect', () => resolve())),
    ]);

    expect(clientSocket.connected).toBe(true);
    expect(workerSocket.connected).toBe(true);
  });

  it('3. El cliente y técnico se suscriben a la sala job:job-101 (joinJobRoom)', async () => {
    const joinPromiseClient = new Promise<any>((resolve) => {
      clientSocket.once('joinedJobRoom', (response: any) => {
        resolve(response);
      });
      clientSocket.emit('joinJobRoom', { jobRequestId: 'job-101' });
    });

    const joinPromiseWorker = new Promise<any>((resolve) => {
      workerSocket.once('joinedJobRoom', (response: any) => {
        resolve(response);
      });
      workerSocket.emit('joinJobRoom', { jobRequestId: 'job-101' });
    });

    const [clientRes, workerRes] = await Promise.all([joinPromiseClient, joinPromiseWorker]);

    expect(clientRes.success).toBe(true);
    expect(clientRes.room).toBe('job:job-101');
    expect(workerRes.success).toBe(true);
  });

  it('4. Cuando el trabajador emite sendBid, el cliente en la sala recibe newBidReceived en tiempo real', async () => {
    const bidPayload = {
      jobRequestId: 'job-101',
      amount: 70.0,
      message: 'Incluye accesorios y tubo PVC 1/2 pulgada',
      estimatedArrival: '18 min',
      includesMaterials: true,
      hasVoiceNote: true,
      voiceDurationSeconds: 10,
      voiceTranscriptPreview: 'Hola vecina, voy con empaques y pegamento listo',
    };

    const newBidPromise = new Promise<any>((resolve) => {
      clientSocket.on('newBidReceived', (bid) => {
        resolve(bid);
      });
    });

    // El trabajador emite la oferta
    workerSocket.emit('sendBid', bidPayload);

    // El cliente debe recibir el evento instantáneamente
    const receivedBid = await newBidPromise;

    expect(receivedBid).toBeDefined();
    expect(receivedBid.jobRequestId).toBe('job-101');
    expect(receivedBid.amount).toBe(70.0);
    expect(receivedBid.workerName).toBe('Jorge Quispe Baldera');
    expect(receivedBid.workerId).toBe('worker-jorge-1');
    expect(receivedBid.includesMaterials).toBe(true);
    expect(receivedBid.hasVoiceNote).toBe(true);
  });

  it('5. Flujo de contraoferta: el cliente contraoferta y la sala recibe counterOfferReceived', async () => {
    const counterOfferPromise = new Promise<any>((resolve) => {
      workerSocket.on('counterOfferReceived', (data) => {
        resolve(data);
      });
    });

    clientSocket.emit('counterOffer', {
      jobRequestId: 'job-101',
      counterAmount: 65.0,
      note: '¿Lo dejamos en 65?',
    });

    const receivedCounter = await counterOfferPromise;

    expect(receivedCounter).toBeDefined();
    expect(receivedCounter.jobRequestId).toBe('job-101');
    expect(receivedCounter.counterAmount).toBe(65.0);
    expect(receivedCounter.senderName).toBe('Lucía Fernández');
  });

  it('6. Debe verificar que el usuario está online consultando Redis (checkUserOnline)', async () => {
    const checkPromise = new Promise<any>((resolve) => {
      clientSocket.emit('checkUserOnline', { userId: 'worker-jorge-1' }, (res: any) => {
        resolve(res);
      });
    });

    const status = await checkPromise;
    expect(status.userId).toBe('worker-jorge-1');
    expect(status.isOnline).toBe(true);
  });
});
