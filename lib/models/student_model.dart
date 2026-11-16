class StudentModel {
  final String id;
  final String name;
  final String rollNumber;
  final int score;

  const StudentModel({
    required this.id,
    required this.name,
    required this.rollNumber,
    this.score = 0,
  });

  StudentModel copyWith({
    String? id,
    String? name,
    String? rollNumber,
    int? score,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rollNumber': rollNumber,
    'score': score,
  };

  factory StudentModel.fromJson(Map<String, dynamic> json) => StudentModel(
    id: json['id'] as String,
    name: json['name'] as String,
    rollNumber: json['rollNumber'] as String,
    score: json['score'] as int? ?? 0,
  );

  factory StudentModel.fromMap(Map<String, dynamic> map) => StudentModel(
    id: map['id'] as String,
    name: map['name'] as String,
    rollNumber: map['roll_number'] as String,
    score: map['score'] as int? ?? 0,
  );
}
