import 'exercise_images.dart';

List<String> _stringList(Object? value) =>
    (value as List? ?? const []).map((e) => e as String).toList();

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.userId,
    this.category,
    this.equipment,
    this.level,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.instructions = const [],
    this.images = const [],
  });

  final String id;
  final String? userId;
  final String name;
  final String? category;
  final String? equipment;
  final String? level;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final List<String> images;

  bool get isCustom => userId != null;

  List<String> get imageUrls => images.map(exerciseImageUrl).toList();

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      category: json['category'] as String?,
      equipment: json['equipment'] as String?,
      level: json['level'] as String?,
      primaryMuscles: _stringList(json['primary_muscles']),
      secondaryMuscles: _stringList(json['secondary_muscles']),
      instructions: _stringList(json['instructions']),
      images: _stringList(json['images']),
    );
  }
}
