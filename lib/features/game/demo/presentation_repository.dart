import 'presentation_scenario.dart';

import 'dart:async';
import 'dart:typed_data';

import '../../study/demo_assignment_store.dart';
import '../../study/study_detector/study_record.dart';
import '../../study/study_repository.dart';
import '../../shop/domain/shop_catalog.dart';
import '../../shop/domain/shop_repository.dart';
import '../../zoo/domain/zoo_world.dart';
import '../../zoo/domain/facility_placement.dart';
import '../../zoo/data/zoo_repository.dart';
import '../domain/zoo_layout.dart';
import '../domain/layout_rules.dart';
import '../data/mock_game_repository.dart';
import '../domain/game_repository.dart';
import '../domain/game_snapshot.dart';

/// A disposable, offline sandbox. No auth, cloud, preferences or real wallet.
/// Assignment logic is reused; only this sandbox's game inventory is funded.
class PresentationRepository extends StudyRepository {
  PresentationRepository({
    Future<ShopCatalog> Function()? catalogLoader,
    Future<ZooWorld> Function()? worldLoader,
  }) {
    _worldLoader = worldLoader ?? ZooRepository().load;
    final data = _study.snapshot.toJson();
    data['coins'] = PresentationScenario.initialCoins;
    data['layout'] = {
      'enclosures': [
        {'id': starterPen, 'left': 0, 'top': 0, 'width': 4, 'height': 4},
      ],
      'animalEnclosures': <String, String>{},
      'facilities': [],
    };
    _game = MockGameRepository(
      initialSnapshot: GameSnapshot.fromJson(data),
      catalogLoader: catalogLoader,
      worldLoader: _worldLoader,
    );
    _study.addListener(_projectStudy);
    _subscription = _game.watchGameState().listen((_) {
      if (!_disposed) notifyListeners();
    });
  }
  static const starterPen = 'presentation_pen';

  final _study = DemoAssignmentStore(
    studentId: 'presentation_student',
    studentName: 'デモ生徒',
  );
  late final MockGameRepository _game;
  late final Future<ZooWorld> Function() _worldLoader;
  bool _grownShown = false;
  bool get grownShown => _grownShown;
  late final StreamSubscription<GameSnapshot> _subscription;
  int _studyCoins = 0, _studyRevision = 1;
  bool _disposed = false;
  GameSnapshot get snapshot => _game.currentSnapshot;

  void _projectStudy() {
    if (_disposed || _study.snapshot.revision <= _studyRevision) return;
    final incoming = _study.snapshot;
    final increase = incoming.coins - _studyCoins;
    if (increase < 0) {
      throw StateError('Presentation study projection cannot spend game coins');
    }
    _studyCoins = incoming.coins;
    _studyRevision = incoming.revision;
    final rewards = {
      for (final r in snapshot.rewards) r.transactionId: r,
      for (final r in incoming.rewards) r.transactionId: r,
    };
    final data = snapshot.toJson();
    data['coins'] = snapshot.coins + increase;
    data['revision'] = snapshot.revision + 1;
    data['assignments'] = incoming.assignments.map((a) => a.toJson()).toList();
    data['rewards'] = rewards.values.map((r) => r.toJson()).toList();
    data['confirmedAt'] = incoming.confirmedAt.toIso8601String();
    _game.receiveConfirmedSnapshot(GameSnapshot.fromJson(data));
  }

  /// Prepared finale, explicitly distinct from earned coins and purchases.
  Future<void> showGrownZoo() async {
    if (grownShown || _disposed) return;
    final world = await _worldLoader();
    if (_disposed) return;
    const pens = {
      starterPen: Enclosure(
        id: starterPen,
        left: 0,
        top: 0,
        width: 8,
        height: 7,
      ),
      'meadow': Enclosure(id: 'meadow', left: 0, top: 9, width: 8, height: 7),
      'fox_garden': Enclosure(
        id: 'fox_garden',
        left: 10,
        top: 4,
        width: 10,
        height: 4,
      ),
      'little_garden': Enclosure(
        id: 'little_garden',
        left: 10,
        top: 9,
        width: 4,
        height: 7,
      ),
    };
    final placements = {
      for (final f in world.facilities)
        f.id: FacilityPlacement(facilityId: f.id, left: f.left, top: f.top),
      'fountain': const FacilityPlacement(
        facilityId: 'fountain',
        left: 14,
        top: 0,
      ),
      'flowerArch': const FacilityPlacement(
        facilityId: 'flowerArch',
        left: 17,
        top: 0,
      ),
      'bench': const FacilityPlacement(facilityId: 'bench', left: 11, top: 3),
      'topiary': const FacilityPlacement(
        facilityId: 'topiary',
        left: 13,
        top: 3,
      ),
    };
    final ownedFacilities = world.facilities.map((f) => f.id).toSet();
    final layout = ZooLayout(
      enclosures: pens,
      facilities: placements,
      animalEnclosures: {
        for (var i = 0; i < world.animals.length; i++)
          world.animals[i].id: pens.keys.elementAt(i % pens.length),
      },
    );
    for (final pen in pens.values) {
      if (validateEnclosure(world, layout, pen, ownedFacilities) != null) {
        throw StateError('Invalid presentation enclosure');
      }
    }
    for (final placement in placements.values) {
      if (validateFacilityPlacement(
            world: world,
            placement: placement,
            ownedFacilityIds: ownedFacilities,
            placements: placements,
            animalAreas: pens.values.map((p) => p.movementArea).toList(),
          ) !=
          null) {
        throw StateError('Invalid presentation facility');
      }
    }
    final data = snapshot.toJson();
    data['layout'] = layout.toJson();
    data['ownedAnimalIds'] = world.animals.map((a) => a.id).toList();
    data['ownedFacilityIds'] = ownedFacilities.toList();
    data['revision'] = snapshot.revision + 1;
    _grownShown = true;
    _game.receiveConfirmedSnapshot(GameSnapshot.fromJson(data));
  }

  @override
  GameConnection get connection => GameConnection.demo;
  @override
  Stream<GameSnapshot> watchGameState() => _game.watchGameState();
  @override
  Future<ShopCatalog> loadCatalog() => _game.loadCatalog();
  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) =>
      _game.purchase(request);
  @override
  int get coins => snapshot.coins;
  @override
  List<StudyStudent> get students => _study.students;
  @override
  List<DemoAssignment> get assignments => _study.assignments;
  @override
  String get storageLabel => '発表デモ・保存しません';
  @override
  String get storageExplanation => 'この体験だけのデータです。実アカウントには反映せず、終了すると消えます。';
  @override
  DemoAssignment assignmentFor(String id) => _study.assignmentFor(id);
  @override
  DemoSubmission? submissionFor(String id, {String? studentId}) =>
      _study.submissionFor(id, studentId: studentId);
  @override
  List<DemoSubmission> submissionsFor(String id) => _study.submissionsFor(id);
  @override
  void publish(
    DemoAssignment assignment, {
    DemoStudyRole role = DemoStudyRole.teacher,
  }) {
    _study.publish(assignment, role: role);
    _projectStudy();
  }

  @override
  int submit(
    String id,
    String answer, {
    required DemoStudyRole role,
    List<StudyAttachment> attachments = const [],
  }) {
    final amount = _study.submit(
      id,
      answer,
      role: role,
      attachments: attachments,
    );
    _projectStudy();
    return amount;
  }

  @override
  int review(
    String id, {
    required DemoStudyRole role,
    required bool approve,
    String feedback = '',
    String? studentId,
    int? expectedVersion,
  }) {
    final amount = _study.review(
      id,
      role: role,
      approve: approve,
      feedback: feedback,
      studentId: studentId,
      expectedVersion: expectedVersion,
    );
    _projectStudy();
    return amount;
  }

  @override
  Future<List<StudyRecord>> loadStudyRecords() => _study.loadStudyRecords();
  @override
  Future<int> saveStudyRecord(StudyRecord record) async {
    final amount = await _study.saveStudyRecord(record);
    _projectStudy();
    return amount;
  }

  @override
  Future<StudyAttachment> addAttachment(
    String assignmentId,
    String name,
    Uint8List bytes,
  ) => _study.addAttachment(assignmentId, name, bytes);
  @override
  Future<Uint8List> readAttachment(StudyAttachment file) =>
      _study.readAttachment(file);
  @override
  Future<List<StudyAdvice>> loadStudyAdvice({required bool teacher}) =>
      _study.loadStudyAdvice(teacher: teacher);
  @override
  Future<StudyAdvice> generateStudyAdvice(String studentId) =>
      _study.generateStudyAdvice(studentId);
  @override
  Future<void> publishStudyAdvice(String id, String message) =>
      _study.publishStudyAdvice(id, message);
  @override
  void dispose() {
    _disposed = true;
    _study.removeListener(_projectStudy);
    unawaited(_subscription.cancel());
    _study.dispose();
    unawaited(_game.dispose());
    super.dispose();
  }
}
