import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/storage/attachments/attachment_vault.dart';
import 'package:zoo_study/features/auth/data/account_scoped_storage.dart';
import 'package:zoo_study/features/auth/data/school_account_api.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/study/local_class_study_repository.dart';
import 'package:zoo_study/features/study/study_detector/study_record.dart';
import 'package:zoo_study/features/study/study_detector/study_session.dart';

import 'memory_storage.dart';

void main() {
  test('class delivery, new enrolment, submissions, attachments, review and study records survive role switching', () async {
    final disk = MemoryStorage(), api = LocalSchoolAccountApi(MemoryStorage());
    final vault = MemoryAttachmentVault();
    final room =
        (await api.call('createManagedClass', {'name': 'ひまわり組'}))['classId']
            as String;
    final other =
        (await api.call('createManagedClass', {'name': 'さくら組'}))['classId']
            as String;
    Future<String> enrol(String room, String name) async =>
        (await api.call('createManagedStudent', {
              'classId': room,
              'name': name,
            }))['studentId']
            as String;
    final hana = await enrol(room, 'はなこ'), taro = await enrol(room, 'たろう');
    final outside = await enrol(other, 'さくら');
    Future<DemoAssignmentStore> student(
      String id,
      String name,
      String classId,
    ) => DemoAssignmentStore.open(
      StudentAccountStorage(disk, id),
      studentId: id,
      studentName: name,
      assignmentSource: ClassAccountStorage(disk, classId),
      attachmentVault: vault,
    );
    var teacher = await LocalClassStudyRepository.open(
      storage: disk,
      api: api,
      classId: room,
      vault: vault,
    );
    const assignmentId = 'class-assignment';
    await teacher.publish(
      DemoAssignment(
        id: assignmentId,
        subject: AssignmentSubject.mathematics,
        title: '計算',
        description: '問題を解こう',
        dueAt: DateTime(2030),
      ),
    );
    expect(teacher.students.map((s) => s.id), containsAll([hana, taro]));
    teacher.dispose();
    var child = await student(hana, 'はなこ', room);
    expect(child.assignments.single.title, '計算');
    final pdf = Uint8List.fromList('%PDF-test'.codeUnits);
    final file = await child.addAttachment(assignmentId, 'answer.pdf', pdf);
    child.submit(
      assignmentId,
      '',
      role: DemoStudyRole.student,
      attachments: [file],
    );
    await child.saveStudyRecord(
      StudyRecord.fromReport(
        'record-1',
        SessionReport(DateTime(2026, 10, 25), const Duration(minutes: 3), []),
        subject: '算数',
        samples: 0,
        completed: true,
      ),
    );
    await child.flush();
    child.dispose();
    teacher = await LocalClassStudyRepository.open(
      storage: disk,
      api: api,
      classId: room,
      vault: vault,
    );
    expect(
      teacher
          .submissionFor(assignmentId, studentId: hana)!
          .attachments
          .single
          .name,
      'answer.pdf',
    );
    expect(await teacher.readAttachment(file), pdf);
    expect(teacher.submissionFor(assignmentId, studentId: taro), isNull);
    final records = await teacher.loadStudyRecords();
    expect(records.single.studentId, hana);
    expect(records.single.studentName, 'はなこ');
    await teacher.review(
      assignmentId,
      role: DemoStudyRole.teacher,
      approve: true,
      studentId: hana,
      expectedVersion: 1,
    );
    final advice = await teacher.generateStudyAdvice(hana);
    await teacher.publishStudyAdvice(advice.id, 'がんばったね');
    teacher.dispose();
    child = await student(hana, 'はなこ', room);
    expect(child.submissionFor(assignmentId)!.status.name, 'approved');
    expect(child.coins, 100);
    expect(
      (await child.loadStudyAdvice(teacher: false)).single.message,
      'がんばったね',
    );
    child.dispose();
    final late = await enrol(room, 'あとから');
    final lateStudent = await student(late, 'あとから', room);
    expect(lateStudent.assignments.single.id, assignmentId);
    lateStudent.dispose();
    final outsider = await student(outside, 'さくら', other);
    expect(outsider.assignments, isEmpty);
    expect(await outsider.loadStudyRecords(), isEmpty);
    outsider.dispose();
    final otherTeacher = await LocalClassStudyRepository.open(
      storage: disk,
      api: api,
      classId: other,
      vault: vault,
    );
    expect(otherTeacher.assignments, isEmpty);
    expect(await otherTeacher.loadStudyRecords(), isEmpty);
    expect(
      () => otherTeacher.generateStudyAdvice(hana),
      throwsA(isA<StudyFailure>()),
    );
    otherTeacher.dispose();
  });
}
