import '../../study/student_assignments_screen.dart';
import '../../study/student_learning_menu.dart';
import '../../study/study_detector/study_mode_screen.dart';
import '../../study/study_detector/study_records_screen.dart';
import '../../study/study_repository.dart';
import '../../study/teacher_assignments_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../data/zoo_repository.dart';
import '../data/session_facility_placement_repository.dart';
import '../../game/presentation/layout_transactions.dart';
import 'enclosure_screens.dart';
import '../domain/facility_placement_repository.dart';
import 'facility_placement_screen.dart';
import '../../game/data/mock_game_repository.dart';
import '../../game/domain/game_repository.dart';
import '../../game/presentation/game_session.dart';
import '../../game/presentation/game_status.dart';
import '../../game/domain/game_snapshot.dart';
import '../../game/presentation/game_notice_banner.dart';
import 'zoo_controller.dart';
import '../../../core/ui/zoo_ui.dart';
import 'zoo_chrome.dart';
import 'zoo_viewport.dart';
import '../../shop/presentation/shop_screen.dart';
import '../../shop/presentation/shop_purchase_controller.dart';
import '../domain/zoo_world.dart';
import '../../animals/presentation/animal_art.dart';

class ZooScreen extends StatefulWidget {
  const ZooScreen({
    super.key,
    this.gameRepository,
    this.isTeacher = false,
    this.assignmentStore,
    this.placementRepository,
    this.onSignOut,
  });

  final GameRepository? gameRepository;
  final bool isTeacher;
  final StudyRepository? assignmentStore;
  final Future<void> Function()? onSignOut;
  final FacilityPlacementRepository? placementRepository;

  @override
  State<ZooScreen> createState() => _ZooScreenState();
}

class _ZooScreenState extends State<ZooScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ZooController? _controller;
  late final _placementRepository =
      widget.placementRepository ??
      SessionFacilityPlacementRepository(_layoutTransactions);
  late final GameSession _game;
  late final LayoutTransactions _layoutTransactions;
  late final ShopPurchaseController _purchases;
  MockGameRepository? _ownedMock;
  late final Ticker _ticker;
  Duration? _lastFrame;
  bool _failed = false;
  final _viewportKey = GlobalKey<ZooViewportState>();

  @override
  void initState() {
    super.initState();
    _game = GameSession(widget.gameRepository ?? _defaultGameRepository())
      ..addListener(_onGameChanged);
    _purchases = ShopPurchaseController(_game);
    _layoutTransactions = LayoutTransactions(_game);
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick);
    _load();
  }

  GameRepository _defaultGameRepository() {
    if (!kDebugMode || !const bool.fromEnvironment('ZOOSTUDY_DEMO')) {
      return const DisconnectedGameRepository();
    }
    const name = String.fromEnvironment(
      'ZOOSTUDY_DEMO_SCENARIO',
      defaultValue: 'assigned',
    );
    const bonusCoins = int.fromEnvironment(
      'ZOOSTUDY_DEMO_BONUS_COINS',
      defaultValue: 1000,
    );
    _ownedMock = MockGameRepository(
      scenario: DemoScenario.values.byName(name),
      bonusCoins: bonusCoins,
    );
    return _ownedMock!;
  }

  void _onGameChanged() {
    if (!mounted) return;
    final snapshot = _game.snapshot;
    if (snapshot != null) {
      _controller?.synchronizeLayout(
        snapshot.layout,
        preserveFacilityPlacements: widget.placementRepository != null,
      );
    }
    _controller?.synchronizeOwnership(
      snapshot?.ownedAnimalIds ?? {},
      snapshot?.ownedFacilityIds ?? {},
    );
    setState(() {});
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final world = await ZooRepository().load();
      final placements = await _placementRepository.load();
      if (!mounted) return;
      setState(
        () => _controller = ZooController(
          world,
          initialPlacements: placements,
          layout: _game.snapshot?.layout,
          ownedAnimalIds: _game.snapshot?.ownedAnimalIds ?? {},
          ownedFacilityIds: _game.snapshot?.ownedFacilityIds ?? {},
        ),
      );
      if (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _ticker.start();
      }
    } catch (error, stackTrace) {
      debugPrint('Zoo data could not be loaded: $error\n$stackTrace');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _tick(Duration elapsed) {
    final previous = _lastFrame;
    _lastFrame = elapsed;
    if (previous != null) {
      _controller?.advance((elapsed - previous).inMicroseconds / 1000000);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastFrame = null;
    if (state == AppLifecycleState.resumed && _controller != null) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _purchases.dispose();
    _layoutTransactions.dispose();
    _game.removeListener(_onGameChanged);
    _game.dispose();
    _ownedMock?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _showProfile() {
    showZooSheet(
      context,
      title: 'プロフィール',
      children: const [
        SpriteTile(
          leading: ZooUiSprite(part: ZooUiPart.smile, scale: 3),
          title: Text('ゲスト'),
          subtitle: Text('レベル 1'),
        ),
        Text('ユーザー名とレベルはサンプル表示です。アカウントや成長データにはまだ接続していません。'),
      ],
    );
  }

  void _showWallet() {
    showZooSheet(
      context,
      title: '所持金',
      children: [GameStatus(session: _game, walletOnly: true)],
    );
  }

  void _showStudy() {
    if (widget.isTeacher) {
      _showAssignments();
      return;
    }
    showZooSheet(
      context,
      title: '学習',
      children: [
        StudentLearningMenu(
          onStudyMode: () => _openLearningFeature(true),
          onRecords: () => _openLearningFeature(false),
          onAssignments: () {
            Navigator.pop(context);
            _showAssignments();
          },
        ),
      ],
    );
  }

  void _openLearningFeature(bool mode) {
    Navigator.pop(context);
    final store = widget.assignmentStore;
    if (store == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学習データに接続してください')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => mode
            ? StudyModeScreen(store: store)
            : StudyRecordsScreen(store: store),
      ),
    );
  }

  void _showAssignments() {
    final store = widget.assignmentStore;
    if (widget.isTeacher && store != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TeacherAssignmentsScreen(store: store),
        ),
      );
      return;
    }
    if (store != null && widget.gameRepository is StudyRepository) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentAssignmentsScreen(store: store),
        ),
      );
      return;
    }
    showZooSheet(
      context,
      title: '課題',
      children: [
        GameStatus(session: _game),
        if (store != null) DemoAssignmentList(store: store),
      ],
    );
  }

  void _showAnimals() {
    final controller = _controller;
    if (controller == null) return;
    showZooSheet(
      context,
      title: '動物一覧',
      children: [
        for (final animal in controller.world.animals)
          SpriteTile(
            key: ValueKey('encyclopedia-${animal.id}'),
            leading: AnimalArt(animalId: animal.id),
            title: Text(animal.name),
            subtitle: Text(
              !controller.ownedAnimals.contains(animal.id)
                  ? '未所持・ロック中'
                  : controller.layout.animalEnclosures.containsKey(animal.id)
                  ? '囲いに配置済み'
                  : '未配置',
            ),
            trailing: !controller.ownedAnimals.contains(animal.id)
                ? const ZooUiSprite(
                    part: ZooUiPart.lock,
                    scale: 3,
                    semanticLabel: '未所持・ロック中',
                  )
                : const ZooUiSprite(part: ZooUiPart.arrowRight, scale: 2),
            enabled: controller.ownedAnimals.contains(animal.id),
            onTap: controller.ownedAnimals.contains(animal.id)
                ? () {
                    Navigator.pop(context);
                    _showAnimal(animal);
                  }
                : null,
          ),
        if (controller.ownedAnimals.isEmpty)
          const Text('まだ動物はいません。ショップから仲間を迎えましょう。'),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
            _openEnclosures();
          },
          child: const Text('囲いの購入・拡張'),
        ),
      ],
    );
  }

  void _openEnclosures({bool create = false}) {
    final controller = _controller;
    if (controller == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EnclosureScreen(
          controller: controller,
          transactions: _layoutTransactions,
          createInitially: create,
        ),
      ),
    );
  }

  void _assignAnimal(AnimalDefinition animal) {
    showZooSheet(
      context,
      title: '${animal.name}の配置',
      children: [
        AnimalEnclosurePicker(
          animal: animal,
          transactions: _layoutTransactions,
        ),
      ],
    );
  }

  void _showAnimal(AnimalDefinition animal) {
    if (_controller?.ownedAnimals.contains(animal.id) != true) return;
    final world = _controller?.world;
    showZooSheet(
      context,
      title: animal.name,
      children: [
        SpriteTile(
          leading: AnimalArt(animalId: animal.id, size: 40),
          title: Text(
            _controller?.layout.animalEnclosures.containsKey(animal.id) == true
                ? '動物園で暮らしています'
                : '未配置',
          ),
          subtitle: const Text('解放済み'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _assignAnimal(animal);
          },
          child: const Text('囲いに配置する'),
        ),
        if (animal.evolutionIds.isNotEmpty) ...[
          const Text('進化先', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final id in animal.evolutionIds)
            SpriteTile(
              title: Text(
                world?.animals.where((a) => a.id == id).firstOrNull?.name ?? id,
              ),
              subtitle: Text(
                _game.snapshot?.ownedAnimalIds.contains(id) == true
                    ? '解放済み'
                    : '未解放',
              ),
            ),
          const Text('進化しても元の動物は残ります。'),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showShop();
          },
          icon: const ZooArtSprite(part: ZooArtPart.shop, scale: 2),
          label: const Text('ショップを見る'),
        ),
      ],
    );
  }

  void _showShop() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShopScreen(
          session: _game,
          purchases: _purchases,
          onPlaceFacility: _startPlacement,
          onCreateEnclosure: () => _openEnclosures(create: true),
        ),
      ),
    );
  }

  void _showFacilities() {
    final controller = _controller;
    if (controller == null) return;
    showZooSheet(
      context,
      title: '施設の配置・移動',
      children: [
        const Text('購入済みの施設を選んで、配置する場所を決めましょう。'),
        const Text('建築物は購入後にここから配置できます。', style: TextStyle(fontSize: 12)),
        for (final definition in controller.world.facilities)
          if (controller.ownedFacilities.contains(definition.id))
            SpriteTile(
              title: Text(definition.displayName),
              subtitle: Text(
                '${definition.width}×${definition.height}マス${definition.tile == 'sprite' && !controller.placements.containsKey(definition.id) ? '・未配置' : ''}',
              ),
              trailing: const ZooUiSprite(part: ZooUiPart.arrowRight, scale: 2),
              onTap: () {
                Navigator.pop(context);
                _startPlacement(definition.id);
              },
            ),
        if (controller.ownedFacilities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('配置できる施設がありません。ショップで購入してください。'),
          ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
            _showShop();
          },
          child: const Text('ショップを見る'),
        ),
      ],
    );
  }

  void _startPlacement(String facilityId) {
    final controller = _controller;
    if (controller == null ||
        !controller.ownedFacilities.contains(facilityId)) {
      return;
    }
    final definition = controller.world.facilities
        .where((f) => f.id == facilityId)
        .firstOrNull;
    if (definition == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FacilityPlacementScreen(
          controller: controller,
          definition: definition,
          name: definition.displayName,
          onSave: (placement) async {
            if (controller.placementIssue(placement) != null) {
              throw StateError('Invalid placement');
            }
            await _placementRepository.save(placement);
            if (!mounted || !controller.placeFacility(placement)) {
              throw StateError('Placement state changed');
            }
          },
        ),
      ),
    );
  }

  void _showDemoResults() {
    final repository = _game.repository;
    final snapshot = _game.snapshot;
    if (!kDebugMode || repository is! MockGameRepository || snapshot == null) {
      return;
    }
    final state = snapshot.assignments.single.state;
    void receive(DemoScenario scenario) {
      repository.receiveDemoScenario(scenario);
      Navigator.pop(context);
    }

    showZooSheet(
      context,
      title: '連携デモ',
      children: [
        const Text('外部で確定した結果の受信を模擬します。実際の提出・講師承認・報酬付与ではありません。'),
        const SizedBox(height: 12),
        if (state == AssignmentState.notSubmitted)
          FilledButton(
            onPressed: () => receive(DemoScenario.submitted),
            child: const Text('初回提出の確定結果を受信'),
          ),
        if (state == AssignmentState.pendingReview) ...[
          FilledButton(
            onPressed: () => receive(DemoScenario.approved),
            child: const Text('承認の確定結果を受信'),
          ),
          OutlinedButton(
            onPressed: () => receive(DemoScenario.needsRevision),
            child: const Text('再提出依頼を受信'),
          ),
        ],
        if (state == AssignmentState.needsRevision)
          FilledButton(
            onPressed: () => receive(DemoScenario.resubmitted),
            child: const Text('再提出の確定結果を受信'),
          ),
        OutlinedButton(
          onPressed: () {
            repository.receiveConfirmedSnapshot(snapshot);
            Navigator.pop(context);
          },
          child: const Text('同じ確定結果を再受信'),
        ),
        if (state == AssignmentState.approved)
          const Text('この課題は承認済みです。デモを最初から見る場合はアプリを再起動してください。'),
      ],
    );
  }

  void _showMore() {
    showZooSheet(
      context,
      title: 'その他',
      patternedBackground: true,
      children: [
        if (kDebugMode &&
            _game.repository is MockGameRepository &&
            _game.snapshot != null)
          SpriteTile(
            leading: const Icon(Icons.science_outlined, color: zooGreen),
            title: const Text('連携デモ'),
            subtitle: const Text('外部の確定結果を模擬受信'),
            onTap: () {
              Navigator.pop(context);
              _showDemoResults();
            },
          ),
        SpriteTile(
          leading: const ZooUiSprite(part: ZooUiPart.encyclopediaRed, scale: 3),
          title: const Text('動物一覧'),
          subtitle: const Text('動物園にいる仲間を見る'),
          trailing: const ZooUiSprite(part: ZooUiPart.arrowRight, scale: 2),
          enabled: _controller != null,
          onTap: () {
            Navigator.pop(context);
            _showAnimals();
          },
        ),
        SpriteTile(
          leading: const ZooArtSprite(part: ZooArtPart.shop, scale: 2),
          title: const Text('ショップ'),
          subtitle: const Text('動物や施設を迎える'),
          trailing: const ZooUiSprite(part: ZooUiPart.arrowRight, scale: 2),
          onTap: () {
            Navigator.pop(context);
            _showShop();
          },
        ),
        SpriteTile(
          title: const Text('囲いの購入・拡張'),
          leading: const TerrainSprite(part: TerrainPart.fence),
          onTap: () {
            Navigator.pop(context);
            _openEnclosures();
          },
        ),
        SpriteTile(
          title: const Text('施設の配置・移動'),
          leading: const ZooArtSprite(part: ZooArtPart.pond, scale: 2),
          trailing: const ZooUiSprite(part: ZooUiPart.arrowRight, scale: 2),
          enabled: _controller != null,
          onTap: () {
            Navigator.pop(context);
            _showFacilities();
          },
        ),
        SpriteTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(widget.isTeacher ? '先生として利用中' : '生徒として利用中'),
        ),
        if (widget.onSignOut != null)
          SpriteTile(
            leading: const Icon(Icons.logout),
            title: const Text('ログアウト'),
            onTap: () async {
              Navigator.of(context).pop();
              await widget.onSignOut!();
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PixelUiTheme(
      child: Scaffold(
        backgroundColor: zooPaper,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ZooHeader(
                onProfile: _showProfile,
                onWallet: _showWallet,
                coins: _game.snapshot?.coins,
                connectionLabel: _game.failed
                    ? '更新停止'
                    : switch (_game.repository.connection) {
                        GameConnection.demo => 'デモ',
                        GameConnection.connected => '',
                        GameConnection.disconnected => '未接続',
                      },
              ),
              GameNoticeBanner(session: _game, onDetails: _showWallet),
              Expanded(
                child: _failed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('動物園データを読み込めませんでした'),
                            TextButton(
                              onPressed: _load,
                              child: const Text('再読み込み'),
                            ),
                          ],
                        ),
                      )
                    : controller == null
                    ? const Center(
                        child: CircularProgressIndicator(color: zooGreen),
                      )
                    : ZooViewport(
                        key: _viewportKey,
                        controller: controller,
                        onAnimals: _showAnimals,
                        onShop: _showShop,
                        onAnimalSelected: _showAnimal,
                      ),
              ),
              ZooBottomBar(
                onHome: () => _viewportKey.currentState?.resetView(),
                onStudy: _showStudy,
                studyLabel: widget.isTeacher ? '課題' : '学習',
                onMore: _showMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
