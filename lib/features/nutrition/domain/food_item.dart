class FoodItem {
  const FoodItem({
    required this.name,
    required this.grams,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.usdaFdcId,
    this.needsReview = false,
  });

  final String name;
  final double grams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String? usdaFdcId;
  final bool needsReview;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      grams: (json['grams'] as num).toDouble(),
      calories: (json['calories'] as num? ?? 0).toDouble(),
      proteinG: (json['protein_g'] as num? ?? 0).toDouble(),
      carbsG: (json['carbs_g'] as num? ?? 0).toDouble(),
      fatG: (json['fat_g'] as num? ?? 0).toDouble(),
      usdaFdcId: json['usda_fdc_id'] as String?,
      needsReview: json['needs_review'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'grams': grams,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'usda_fdc_id': usdaFdcId,
      'needs_review': needsReview,
    };
  }

  FoodItem copyWith({
    String? name,
    double? grams,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    String? usdaFdcId,
    bool? needsReview,
  }) {
    return FoodItem(
      name: name ?? this.name,
      grams: grams ?? this.grams,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      usdaFdcId: usdaFdcId ?? this.usdaFdcId,
      needsReview: needsReview ?? this.needsReview,
    );
  }
}
