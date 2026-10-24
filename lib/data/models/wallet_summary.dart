class WalletTransaction {
  final String id;
  final double amount;
  final String type;
  final String? jobRequestId;
  final String? description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    this.jobRequestId,
    this.description,
    required this.createdAt,
  });

  bool get isIncome => amount > 0;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'UNKNOWN',
      jobRequestId: json['jobRequestId'] as String?,
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DailyEarning {
  final String day; // Lun, Mar, Mié, Jue, Vie, Sáb, Dom
  final double amount;
  final bool isBest;

  const DailyEarning({
    required this.day,
    required this.amount,
    this.isBest = false,
  });
}

class WalletSummary {
  final String walletId;
  final String userId;
  final double availableBalance;
  final double inEscrowBalance;
  final double totalBalance;
  final String currency;
  final List<WalletTransaction> recentTransactions;

  const WalletSummary({
    required this.walletId,
    required this.userId,
    required this.availableBalance,
    required this.inEscrowBalance,
    required this.totalBalance,
    required this.currency,
    required this.recentTransactions,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    final rawTx = json['recentTransactions'] as List<dynamic>? ?? [];
    final txList = rawTx
        .map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
        .toList();

    return WalletSummary(
      walletId: json['walletId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0.0,
      inEscrowBalance: (json['inEscrowBalance'] as num?)?.toDouble() ?? 0.0,
      totalBalance: (json['totalBalance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'PEN',
      recentTransactions: txList,
    );
  }

  /// Calcula el desglose semanal derivado estrictamente de recentTransactions reales
  /// de los últimos 7 días. Agrupa ingresos por día.
  List<DailyEarning> calculateWeeklyEarnings() {
    const dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final Map<int, double> earningsByWeekday = {
      1: 0.0, // Lunes
      2: 0.0, // Martes
      3: 0.0, // Miércoles
      4: 0.0, // Jueves
      5: 0.0, // Viernes
      6: 0.0, // Sábado
      7: 0.0, // Domingo
    };

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    for (final tx in recentTransactions) {
      if (tx.isIncome && tx.createdAt.isAfter(sevenDaysAgo)) {
        final weekday = tx.createdAt.weekday;
        earningsByWeekday[weekday] = (earningsByWeekday[weekday] ?? 0.0) + tx.amount;
      }
    }

    double maxVal = 0.0;
    for (final val in earningsByWeekday.values) {
      if (val > maxVal) maxVal = val;
    }

    return List.generate(7, (i) {
      final weekday = i + 1;
      final amount = earningsByWeekday[weekday] ?? 0.0;
      return DailyEarning(
        day: dayNames[i],
        amount: amount,
        isBest: maxVal > 0 && amount == maxVal,
      );
    });
  }

  double get totalWeeklyEarnings {
    final weekly = calculateWeeklyEarnings();
    return weekly.fold(0.0, (sum, item) => sum + item.amount);
  }
}
