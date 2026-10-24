import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

class EventsSocketService {
  final ApiClient apiClient;
  io.Socket? _socket;
  bool _isConnected = false;

  final _connectionController = StreamController<bool>.broadcast();
  final _newBidController = StreamController<Map<String, dynamic>>.broadcast();
  final _counterOfferController = StreamController<Map<String, dynamic>>.broadcast();
  final _bidAcceptedController = StreamController<Map<String, dynamic>>.broadcast();

  EventsSocketService({required this.apiClient});

  bool get isConnected => _isConnected;
  Stream<bool> get onConnectionChange => _connectionController.stream;
  Stream<Map<String, dynamic>> get onNewBidReceived => _newBidController.stream;
  Stream<Map<String, dynamic>> get onCounterOfferReceived => _counterOfferController.stream;
  Stream<Map<String, dynamic>> get onBidAccepted => _bidAcceptedController.stream;

  /// Inicializa la conexión Socket.IO con el token JWT en el handshake
  void connect(String token) {
    if (_socket != null && _socket!.connected) {
      return;
    }

    disconnect();

    final uri = Uri.parse(apiClient.baseUrl);
    final socketUrl = '${uri.scheme}://${uri.host}:${uri.port}';

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(20)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionController.add(true);
      if (kDebugMode) {
        print('⚡ [Socket.IO] Conectado en tiempo real al backend CHAMBA');
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _connectionController.add(false);
      if (kDebugMode) {
        print('🔌 [Socket.IO] Desconectado del backend CHAMBA');
      }
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      _connectionController.add(false);
      if (kDebugMode) {
        print('⚠️ [Socket.IO] Error de conexión: $err');
      }
    });

    // Escuchar eventos en tiempo real
    _socket!.on('newBidReceived', (data) {
      if (data is Map) {
        _newBidController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('counterOfferReceived', (data) {
      if (data is Map) {
        _counterOfferController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('bidAccepted', (data) {
      if (data is Map) {
        _bidAcceptedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Suscribe el cliente a la sala del trabajo
  void joinJobRoom(String jobRequestId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('joinJobRoom', {'jobRequestId': jobRequestId});
    }
  }

  /// Desuscribe el cliente de la sala del trabajo
  void leaveJobRoom(String jobRequestId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leaveJobRoom', {'jobRequestId': jobRequestId});
    }
  }

  /// Emite una oferta en tiempo real desde el técnico
  void emitSendBid({
    required String jobRequestId,
    required double amount,
    String? message,
    String? estimatedArrival,
    bool? includesMaterials,
    List<String>? inclusionTags,
    bool? hasVoiceNote,
    int? voiceDurationSeconds,
    String? voiceTranscriptPreview,
  }) {
    if (_socket != null && _socket!.connected) {
      final payload = <String, dynamic>{
        'jobRequestId': jobRequestId,
        'amount': amount,
      };
      if (message != null) payload['message'] = message;
      if (estimatedArrival != null) payload['estimatedArrival'] = estimatedArrival;
      if (includesMaterials != null) payload['includesMaterials'] = includesMaterials;
      if (inclusionTags != null) payload['inclusionTags'] = inclusionTags;
      if (hasVoiceNote != null) payload['hasVoiceNote'] = hasVoiceNote;
      if (voiceDurationSeconds != null) payload['voiceDurationSeconds'] = voiceDurationSeconds;
      if (voiceTranscriptPreview != null) payload['voiceTranscriptPreview'] = voiceTranscriptPreview;

      _socket!.emit('sendBid', payload);
    }
  }

  /// Emite una contraoferta en tiempo real
  void emitCounterOffer({
    required String jobRequestId,
    required double counterAmount,
    String? note,
  }) {
    if (_socket != null && _socket!.connected) {
      final payload = <String, dynamic>{
        'jobRequestId': jobRequestId,
        'counterAmount': counterAmount,
      };
      if (note != null) payload['note'] = note;

      _socket!.emit('counterOffer', payload);
    }
  }

  /// Emite la aceptación de una oferta
  void emitAcceptBid({
    required String jobRequestId,
    required String bidId,
    required double agreedAmount,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('acceptBid', {
        'jobRequestId': jobRequestId,
        'bidId': bidId,
        'agreedAmount': agreedAmount,
      });
    }
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _newBidController.close();
    _counterOfferController.close();
    _bidAcceptedController.close();
  }
}
