import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';

final dbProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());

final appProvider =
    StateNotifierProvider<AppNotifier, List<ClassModel>>((ref) {
  return AppNotifier(ref.watch(dbProvider));
});

class AppNotifier extends StateNotifier<List<ClassModel>> {
  final DatabaseHelper _db;

  AppNotifier(this._db) : super([]) {
    loadData();
  }

  Future<void> loadData() async {
    state = await _db.getAllClasses();
  }

  ClassModel? getClass(String classId) {
    try {
      return state.firstWhere((c) => c.id == classId);
    } catch (_) {
      return null;
    }
  }

  Future<void> addClass(ClassModel cls) async {
    await _db.insertClass(cls);
    state = [...state, cls];
  }

  Future<void> updateClass(ClassModel updated) async {
    await _db.updateClass(updated);
    state = state.map((c) => c.id == updated.id ? updated : c).toList();
  }

  Future<void> deleteClass(String classId) async {
    await _db.deleteClass(classId);
    state = state.where((c) => c.id != classId).toList();
  }

  Future<void> addStudent(String classId, StudentModel student) async {
    await _db.insertStudent(classId, student);
    state = state.map((c) {
      if (c.id == classId) {
        return c.copyWith(students: [...c.students, student]);
      }
      return c;
    }).toList();
  }

  Future<void> updateStudent(String classId, StudentModel updated) async {
    await _db.updateStudentInfo(updated);
    state = state.map((c) {
      if (c.id == classId) {
        return c.copyWith(
          students:
              c.students.map((s) => s.id == updated.id ? updated : s).toList(),
        );
      }
      return c;
    }).toList();
  }

  Future<void> deleteStudent(String classId, String studentId) async {
    await _db.deleteStudent(studentId);
    state = state.map((c) {
      if (c.id == classId) {
        return c.copyWith(
          students: c.students.where((s) => s.id != studentId).toList(),
        );
      }
      return c;
    }).toList();
  }

  Future<void> updateScore(
      String classId, String studentId, int delta) async {
    final cls = state.firstWhere((c) => c.id == classId);
    final student = cls.students.firstWhere((s) => s.id == studentId);
    final newScore = student.score + delta;
    await _db.updateScore(studentId, newScore);
    state = state.map((c) {
      if (c.id == classId) {
        return c.copyWith(
          students: c.students.map((s) {
            if (s.id == studentId) return s.copyWith(score: newScore);
            return s;
          }).toList(),
        );
      }
      return c;
    }).toList();
  }

  Future<void> setScore(
      String classId, String studentId, int score) async {
    await _db.updateScore(studentId, score);
    state = state.map((c) {
      if (c.id == classId) {
        return c.copyWith(
          students: c.students.map((s) {
            if (s.id == studentId) return s.copyWith(score: score);
            return s;
          }).toList(),
        );
      }
      return c;
    }).toList();
  }

  Future<void> resetScores(String classId) async {
    await _db.resetScores(classId);
    state = state.map((c) {
      if (c.id == classId) {
        return c.copyWith(
          students: c.students.map((s) => s.copyWith(score: 0)).toList(),
        );
      }
      return c;
    }).toList();
  }
}
