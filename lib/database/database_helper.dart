import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';

class DatabaseHelper {
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'scorio.db'),
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE classes (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            section TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE students (
            id TEXT PRIMARY KEY,
            class_id TEXT NOT NULL,
            name TEXT NOT NULL,
            roll_number TEXT NOT NULL,
            score INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<List<ClassModel>> getAllClasses() async {
    final db = await database;
    try {
      var classes = await db.query('classes');
      var students = await db.query('students');
      if (classes.isEmpty || students.isEmpty) {
        await db.delete('students');
        await db.delete('classes');
        await _seedDefaultClasses(db);
        classes = await db.query('classes');
        students = await db.query('students');
      } else {
        await db.rawUpdate(
          "UPDATE classes SET section = '' WHERE section = 'Lab'",
        );
      }

      return classes.map((c) {
        final classStudents = students
            .where((s) => s['class_id'] == c['id'])
            .map((s) => StudentModel.fromMap(s))
            .toList();
        return ClassModel.fromMap(c, classStudents);
      }).toList();
    } catch (e, stack) {
      debugPrint('Error in getAllClasses: $e\n$stack');
      return [];
    }
  }

  Future<void> _seedDefaultClasses(Database db) async {
    final sampleClasses = [
      {
        'id': 'class-1',
        'name': 'Class 10',
        'section': 'A',
        'students': [
          {'id': 's1-1', 'name': 'Aarav Sharma', 'roll': '01', 'score': 28},
          {'id': 's1-2', 'name': 'Ananya Sen', 'roll': '02', 'score': 22},
          {'id': 's1-3', 'name': 'Kabir Mehta', 'roll': '03', 'score': 15},
          {'id': 's1-4', 'name': 'Rohan Varma', 'roll': '04', 'score': 8},
        ],
      },
      {
        'id': 'class-2',
        'name': 'Grade VIII',
        'section': 'B',
        'students': [
          {'id': 's2-1', 'name': 'Diya Kapoor', 'roll': '01', 'score': 34},
          {'id': 's2-2', 'name': 'Ishaan Roy', 'roll': '02', 'score': 26},
          {'id': 's2-3', 'name': 'Meera Nair', 'roll': '03', 'score': 18},
        ],
      },
      {
        'id': 'class-3',
        'name': 'Advanced Mathematics',
        'section': '',
        'students': [
          {'id': 's3-1', 'name': 'Siddharth Jain', 'roll': '01', 'score': 45},
          {'id': 's3-2', 'name': 'Pooja Hegde', 'roll': '02', 'score': 38},
          {'id': 's3-3', 'name': 'Tanvi Deshmukh', 'roll': '03', 'score': 30},
        ],
      },
      {
        'id': 'class-4',
        'name': 'Physics & Robotics',
        'section': '',
        'students': [
          {'id': 's4-1', 'name': 'Aditya Chopra', 'roll': '01', 'score': 32},
          {'id': 's4-2', 'name': 'Kavya Menon', 'roll': '02', 'score': 24},
          {'id': 's4-3', 'name': 'Vivaan Joshi', 'roll': '03', 'score': 19},
        ],
      },
      {
        'id': 'class-5',
        'name': '12th Grade Honors',
        'section': '',
        'students': [
          {'id': 's5-1', 'name': 'Riya Sengupta', 'roll': '01', 'score': 40},
          {'id': 's5-2', 'name': 'Arjun Pillai', 'roll': '02', 'score': 31},
          {'id': 's5-3', 'name': 'Neha Bansal', 'roll': '03', 'score': 25},
        ],
      },
    ];

    for (final c in sampleClasses) {
      await db.insert('classes', {
        'id': c['id'],
        'name': c['name'],
        'section': (c['section'] as String).isNotEmpty ? c['section'] : null,
      });
      final studentList = c['students'] as List<Map<String, Object>>;
      for (final s in studentList) {
        await db.insert('students', {
          'id': s['id'],
          'class_id': c['id'],
          'name': s['name'],
          'roll_number': s['roll'],
          'score': s['score'],
        });
      }
    }
  }

  Future<void> insertClass(ClassModel cls) async {
    final db = await database;
    await db.insert('classes', {
      'id': cls.id,
      'name': cls.name,
      'section': cls.section,
    });
  }

  Future<void> updateClass(ClassModel cls) async {
    final db = await database;
    await db.update(
      'classes',
      {'name': cls.name, 'section': cls.section},
      where: 'id = ?',
      whereArgs: [cls.id],
    );
  }

  Future<void> deleteClass(String classId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('students', where: 'class_id = ?', whereArgs: [classId]);
      await txn.delete('classes', where: 'id = ?', whereArgs: [classId]);
    });
  }

  Future<void> insertStudent(String classId, StudentModel student) async {
    final db = await database;
    await db.insert('students', {
      'id': student.id,
      'class_id': classId,
      'name': student.name,
      'roll_number': student.rollNumber,
      'score': student.score,
    });
  }

  Future<void> updateStudentInfo(StudentModel student) async {
    final db = await database;
    await db.update(
      'students',
      {'name': student.name, 'roll_number': student.rollNumber},
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<void> deleteStudent(String studentId) async {
    final db = await database;
    await db.delete('students', where: 'id = ?', whereArgs: [studentId]);
  }

  Future<void> updateScore(String studentId, int score) async {
    final db = await database;
    await db.update(
      'students',
      {'score': score},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  Future<void> resetScores(String classId) async {
    final db = await database;
    await db.update(
      'students',
      {'score': 0},
      where: 'class_id = ?',
      whereArgs: [classId],
    );
  }
}
