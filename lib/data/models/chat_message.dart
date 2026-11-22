enum CounterOfferStatus {
  pending,
  accepted,
  rejected,
}

class ChatMessage {
  final String id;
  final String jobId;
  final String senderId;
  final String senderName;
  final bool isFromWorker;
  final String text;
  final double? proposalAmount; // For legacy in-chat counter-offers S/.
  final DateTime timestamp;

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
    this.isCounterOffer = false,
    this.offerAmount,
    this.counterOfferStatus,
  });

  ChatMessage copyWith({
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
      isCounterOffer: isCounterOffer ?? this.isCounterOffer,
      offerAmount: offerAmount ?? this.offerAmount,
      counterOfferStatus: counterOfferStatus ?? this.counterOfferStatus,
    );
  }
}
