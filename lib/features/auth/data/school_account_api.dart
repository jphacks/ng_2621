import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/storage/draft_storage.dart';
import '../../../core/storage/request_id.dart';
import '../../study/study_repository.dart' show StudyFailure;

abstract interface class SchoolAccountApi {
  bool get preview;
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]);
}

class FirebaseSchoolAccountApi implements SchoolAccountApi {
  FirebaseSchoolAccountApi({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast1');
  final FirebaseFunctions _functions;
  final _pending = <String, String>{};
  @override
  bool get preview => false;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final key = name + jsonEncode(data);
    final requestId = _pending.putIfAbsent(key, newRequestId);
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<dynamic>({...data, 'requestId': requestId})
          .timeout(const Duration(seconds: 25));
      _pending.remove(key);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw StudyFailure(e.message ?? '操作できませんでした。再試行してください');
    } on TimeoutException {
      throw const StudyFailure('結果を確認できませんでした。同じ操作を再試行してください');
    }
  }
}

/// Device-only accounts for the local demo; never creates Firebase accounts.
class LocalSchoolAccountApi implements SchoolAccountApi {
  LocalSchoolAccountApi(this.storage);
  final DraftStorage? storage;
  Map<String, dynamic>? _state;
  @override
  bool get preview => true;
  String _random(int length) {
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    _state ??=
        await storage?.read('school-accounts-preview') ??
        {'currentClassId': '', 'classes': <dynamic>[], 'students': <dynamic>[]};
    final state = _state!,
        classes = state['classes'] as List,
        students = state['students'] as List;
    if (name == 'loginWithStudentCode') {
      final code = (data['code'] as String? ?? '').toUpperCase().replaceAll(
        RegExp(r'[\s-]'),
        '',
      );
      final student = students
          .where((s) => (s['code'] as String).replaceAll('-', '') == code)
          .firstOrNull;
      if (student == null) throw const StudyFailure('コードをかくにんするか、せんせいにきいてね');
      return {
        'student': {
          ...Map<String, dynamic>.from(student as Map)..remove('code'),
          'className': classes
              .where((c) => c['id'] == student['classId'])
              .firstOrNull?['name'],
        },
      };
    }
    if (name == 'restoreStudentSession') {
      final student = students
          .where((s) => s['id'] == data['studentId'])
          .firstOrNull;
      if (student == null) throw const StudyFailure('せんせいにもらったコードで、もういちどはいってね');
      return {
        'student': {
          ...Map<String, dynamic>.from(student as Map)..remove('code'),
          'className': classes
              .where((c) => c['id'] == student['classId'])
              .firstOrNull?['name'],
        },
      };
    }
    if (name == 'listManagedClasses') {
      return {
        'currentClassId': state['currentClassId'],
        'classes': List.of(classes),
      };
    }
    if (name == 'listManagedStudents') {
      return {
        'students': students
            .where((s) => s['classId'] == data['classId'])
            .map((s) => {'id': s['id'], 'name': s['name'], 'hasCode': true})
            .toList(),
      };
    }
    Map<String, dynamic> result = {};
    if (name == 'createManagedClass') {
      final id = newRequestId(), prefix = _random(6);
      classes.add({'id': id, 'name': data['name'], 'prefix': prefix});
      if (state['currentClassId'] == '') state['currentClassId'] = id;
      result = {'classId': id, 'prefix': prefix};
    } else if (name == 'selectManagedClass') {
      state['currentClassId'] = data['classId'];
    } else if (name == 'createManagedStudent' || name == 'reissueStudentCode') {
      final room = classes.firstWhere((c) => c['id'] == data['classId']);
      final student = name == 'createManagedStudent'
          ? <String, dynamic>{
              'id': newRequestId(),
              'name': data['name'],
              'classId': data['classId'],
            }
          : students.firstWhere((s) => s['id'] == data['studentId'])
                as Map<String, dynamic>;
      final random = _random(16);
      final code =
          '${room['prefix'] as String}-${[for (var i = 0; i < 16; i += 4) random.substring(i, i + 4)].join('-')}';
      student['code'] = code;
      if (name == 'createManagedStudent') students.add(student);
      result = {
        'studentId': student['id'],
        'loginCode': code,
        'codeUnavailable': false,
      };
    } else {
      throw const StudyFailure('この操作はプレビューでは利用できません');
    }
    await storage?.write('school-accounts-preview', state);
    return result;
  }
}
