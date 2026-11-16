import 'student_model.dart';

class ClassModel {
  final String id;
  final String name;
  final String? section;
  final List<StudentModel> students;

  ClassModel({
    required this.id,
    required this.name,
    this.section,
    List<StudentModel>? students,
  }) : students = students ?? [];

  String get displayName =>
      (section != null && section!.isNotEmpty) ? '$name $section' : name;

  ClassModel copyWith({
    String? id,
    String? name,
    String? section,
    List<StudentModel>? students,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      section: section ?? this.section,
      students: students ?? this.students,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'section': section,
    'students': students.map((s) => s.toJson()).toList(),
  };

  factory ClassModel.fromJson(Map<String, dynamic> json) => ClassModel(
    id: json['id'] as String,
    name: json['name'] as String,
    section: json['section'] as String?,
    students: (json['students'] as List<dynamic>?)
            ?.map((s) => StudentModel.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
  );

  factory ClassModel.fromMap(Map<String, dynamic> map, List<StudentModel> students) =>
      ClassModel(
        id: map['id'] as String,
        name: map['name'] as String,
        section: map['section'] as String?,
        students: students,
      );
}
