class AiDiagnosticResult {
  final String category;
  final String technicalDescription;
  final double minPrice;
  final double maxPrice;
  final String currency;
  final String formattedPrice;
  final List<String> materialsNeeded;
  final String source;
  final double confidence;

  const AiDiagnosticResult({
    required this.category,
    required this.technicalDescription,
    required this.minPrice,
    required this.maxPrice,
    required this.currency,
    required this.formattedPrice,
    required this.materialsNeeded,
    required this.source,
    required this.confidence,
  });

  /// Regla de honestidad: solo se considera IA real si el source proviene de Gemini
  bool get isAiGenerated => source.toLowerCase().contains('gemini');

  /// Etiqueta obligatoria para la UI
  String get badgeLabel =>
      isAiGenerated ? 'Diagnóstico con IA' : 'Sugerencia automática (sin IA)';

  double get averagePrice => (minPrice + maxPrice) / 2.0;

  factory AiDiagnosticResult.fromJson(Map<String, dynamic> json) {
    final priceObj = json['estimatedPriceRange'] as Map<String, dynamic>? ?? {};
    final rawMaterials = json['materialsNeeded'] as List<dynamic>? ?? [];

    return AiDiagnosticResult(
      category: json['category'] as String? ?? 'General',
      technicalDescription: json['technicalDescription'] as String? ?? '',
      minPrice: (priceObj['min'] as num?)?.toDouble() ?? 50.0,
      maxPrice: (priceObj['max'] as num?)?.toDouble() ?? 65.0,
      currency: priceObj['currency'] as String? ?? 'PEN',
      formattedPrice: priceObj['formatted'] as String? ?? 'S/. 50 - S/. 65',
      materialsNeeded: rawMaterials.map((e) => e.toString()).toList(),
      source: json['source'] as String? ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }
}
