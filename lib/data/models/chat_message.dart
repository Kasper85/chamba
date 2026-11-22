enum CounterOfferStatus { pending, accepted, rejected }

enum MessageDeliveryStatus { sending, sent, delivered, failed }

class ChatMessage {
  final String id;
  final String jobId;
  final String senderId;
  final String senderName;
  final bool isFromWorker;
  final String text;
  final double? proposalAmount; // For legacy in-chat counter-offers S/.
  final DateTime timestamp;
  final MessageDeliveryStatus deliveryStatus;
  final String? audioBase64;
  final int? audioDurationSeconds;

  // Phase 2: Interactive Counter-Offers in Chat
  final bool isCounterOffer;
  final double? offerAmount;
  final CounterOfferStatus? counterOfferStatus;

  const ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.senderName,
    required this.isFromWorker,
    required this.text,
    this.proposalAmount,
    required this.timestamp,
    this.deliveryStatus = MessageDeliveryStatus.sent,
    this.audioBase64,
    this.audioDurationSeconds,
    this.isCounterOffer = false,
    this.offerAmount,
    this.counterOfferStatus,
  });

  ChatMessage copyWith({
    MessageDeliveryStatus? deliveryStatus,
    String? text,
    double? proposalAmount,
    bool? isCounterOffer,
    double? offerAmount,
    CounterOfferStatus? counterOfferStatus,
  }) {
    return ChatMessage(
      id: id,
      jobId: jobId,
      senderId: senderId,
      senderName: senderName,
      isFromWorker: isFromWorker,
      text: text ?? this.text,
      proposalAmount: proposalAmount ?? this.proposalAmount,
      timestamp: timestamp,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      audioBase64: audioBase64,
      audioDurationSeconds: audioDurationSeconds,
      isCounterOffer: isCounterOffer ?? this.isCounterOffer,
      offerAmount: offerAmount ?? this.offerAmount,
      counterOfferStatus: counterOfferStatus ?? this.counterOfferStatus,
    );
  }
}
