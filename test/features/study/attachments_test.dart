import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:zoo_study/core/storage/attachments/attachment_vault.dart';
import 'package:zoo_study/core/storage/attachments/attachment_vault_io.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/study/attachments/study_file_picker.dart';
import 'package:zoo_study/features/study/assignment_detail_screen.dart';
import 'package:zoo_study/features/study/study_repository.dart';

import 'memory_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = File('test/fixtures/submission.png').readAsBytesSync();
  final pdf = File('test/fixtures/submission.pdf').readAsBytesSync();
  test('Android photo selection uses the direct Photos bridge and handles cancellation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('zoostudy/photos');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pickPhoto');
      return {'name': 'photo.png', 'bytes': png};
    });
    final selected = await pickStudyPhotos();
    expect(selected.single.name, 'photo.png');
    expect(selected.single.bytes, png);
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await pickStudyPhotos(), isEmpty);
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'photo_read_failed',
        message: '写真を読み込めませんでした',
      );
    });
    await expectLater(pickStudyPhotos(), throwsA(isA<StudyFailure>()));
  });
  test(
    'PDF attachments open and render a page with the actual PDF engine',
    () async {
      Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
      await pdfrxFlutterInitialize();
      final document = await PdfDocument.openData(pdf);
      try {
        expect(document.pages, hasLength(1));
        final image = await document.pages.first.render(width: 64, height: 64);
        expect(image, isNotNull);
        expect(image!.pixels.length, 64 * 64 * 4);
        image.dispose();
      } finally {
        await document.dispose();
      }
    },
  );
  void task(DemoAssignmentStore store) => store.publish(
    DemoAssignment(
      id: 'files-task',
      subject: AssignmentSubject.science,
      title: 'ファイルで提出',
      description: '写真かPDFを添付',
      dueAt: DateTime(2026, 11, 1),
    ),
  );

  test('file-only submission survives restart and revision without duplicate coins', () async {
    final disk = MemoryStorage(), vault = MemoryAttachmentVault();
    var store = await DemoAssignmentStore.open(disk, attachmentVault: vault);
    task(store);
    final image = await store.addAttachment('files-task', 'answer.png', png);
    expect(store.coins, 0);
    expect(
      store.submit(
        'files-task',
        '',
        role: DemoStudyRole.student,
        attachments: [image],
      ),
      30,
    );
    expect(
      store.submit(
        'files-task',
        '',
        role: DemoStudyRole.student,
        attachments: [image],
      ),
      0,
    );
    await store.flush();
    store.dispose();
    store = await DemoAssignmentStore.open(disk, attachmentVault: vault);
    expect(
      await store.readAttachment(
        store.submissionFor('files-task')!.attachments.single,
      ),
      png,
    );
    store.review('files-task', role: DemoStudyRole.teacher, approve: false);
    final document = await store.addAttachment('files-task', 'answer.pdf', pdf);
    expect(
      store.submit(
        'files-task',
        '',
        role: DemoStudyRole.student,
        attachments: [document],
      ),
      0,
    );
    store.review('files-task', role: DemoStudyRole.teacher, approve: true);
    expect(store.coins, 100);
    expect(store.submissionFor('files-task')!.attachments.single.isPdf, isTrue);
    await store.flush();
    store.dispose();
  });
  test('prepared attachment and draft remain valid after restart before submitting', () async {
    final disk = MemoryStorage(), vault = MemoryAttachmentVault();
    var store = await DemoAssignmentStore.open(disk, attachmentVault: vault);
    task(store);
    final file = await store.addAttachment('files-task', 'scan.pdf', pdf);
    store.dispose();
    store = await DemoAssignmentStore.open(disk, attachmentVault: vault);
    expect(
      store.submit(
        'files-task',
        '',
        role: DemoStudyRole.student,
        attachments: [file],
      ),
      30,
    );
    await store.flush();
    store.dispose();
  });
  test('invalid content, empty submission, excessive files and unknown uploads are rejected', () async {
    final store = DemoAssignmentStore();
    task(store);
    await expectLater(
      store.addAttachment('files-task', 'fake.pdf', png),
      throwsA(isA<StudyFailure>()),
    );
    await expectLater(
      store.addAttachment('files-task', 'file.exe', png),
      throwsA(isA<StudyFailure>()),
    );
    await expectLater(
      store.addAttachment('files-task', '../scan.pdf', pdf),
      throwsA(isA<StudyFailure>()),
    );
    await expectLater(
      store.addAttachment(
        'files-task',
        'large.pdf',
        Uint8List(maxStudyFileBytes + 1),
      ),
      throwsA(isA<StudyFailure>()),
    );
    expect(
      () => store.submit('files-task', ' ', role: DemoStudyRole.student),
      throwsA(isA<StudyFailure>()),
    );
    final file = await store.addAttachment('files-task', 'answer.png', png);
    expect(
      () => store.submit(
        'files-task',
        '',
        role: DemoStudyRole.student,
        attachments: [file, file, file, file],
      ),
      throwsA(isA<StudyFailure>()),
    );
    final unknown = StudyAttachment(
      id: 'a' * 64,
      name: 'scan.pdf',
      size: 100,
      contentType: 'application/pdf',
      storagePath: 'files-task/unknown',
    );
    expect(
      () => store.submit(
        'files-task',
        '',
        role: DemoStudyRole.student,
        attachments: [unknown],
      ),
      throwsA(isA<StudyFailure>()),
    );
    expect(store.coins, 0);
    store.dispose();
  });
  test(
    'native vault copies binary data and rejects arbitrary file paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zoostudy-attachments-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final vault = FileAttachmentVault(directory.path);
      final id = studyFileId(png);
      await vault.put(id, png);
      expect(await FileAttachmentVault(directory.path).get(id), png);
      expect(() => vault.get('../outside'), throwsArgumentError);
    },
  );
  for (final source in ['files', 'photos']) {
    testWidgets(
      'student attaches image via $source, submits and teacher can view it',
      (tester) async {
        final store = DemoAssignmentStore();
        task(store);
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: AssignmentDetailScreen(
              store: store,
              assignmentId: 'files-task',
              isTeacher: false,
              pickFiles: source == 'files'
                  ? () async => [PickedStudyFile('answer.png', png)]
                  : () async => throw StateError('wrong picker'),
              pickPhotos: source == 'photos'
                  ? () async => [PickedStudyFile('answer.png', png)]
                  : () async => throw StateError('wrong picker'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(source == 'photos' ? 'フォトから選ぶ' : '画像・PDFを添付'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(
          find.text(source == 'photos' ? 'フォトから選ぶ' : '画像・PDFを添付'),
        );
        await tester.pumpAndSettle();
        expect(find.text('answer.png'), findsOneWidget);
        await tester.tap(find.text('answer.png'));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        expect(find.text('画像を表示できませんでした'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('課題を提出する'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('課題を提出する'));
        await tester.pumpAndSettle();
        expect(store.coins, 30);
        expect(store.submissionFor('files-task')!.attachments.length, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: AssignmentDetailScreen(
              store: store,
              assignmentId: 'files-task',
              isTeacher: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('answer.png'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('answer.png'));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
