import '../../../core/storage/draft_storage.dart';
import 'zoo_navigation.dart';
import '../../game/experience/game_experience.dart';
import '../../game/experience/experience_widgets.dart';
import '../../shop/domain/shop_catalog.dart';
import '../../shop/domain/shop_repository.dart';
import '../../shop/data/shop_catalog_loader.dart';
import '../../shop/presentation/shop_panel.dart';
import '../../animals/presentation/animal_encyclopedia.dart';
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
    this.gamePreferences,
    this.accountName,
    this.accountEmail,
  });

  final DraftStorage? gamePreferences;
  final String? accountName, accountEmail;
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
  late final GameExperience _experience;
  ShopCatalog? _experienceCatalog;
  bool _studyHistoryStarted = false;
  Future<void> _studyQueue = Future.value();
  String? _experienceError;
  String? _welcomedReward;
  int _reactionRevision = 0;
  late final Ticker _ticker;
  Duration? _lastFrame;
  bool _failed = false;
  final _viewportKey = GlobalKey<ZooViewportState>();
  final _contentKey = GlobalKey<NavigatorState>();
  final _shopKey = GlobalKey<ShopScreenState>();
  final _homeRevision = ValueNotifier(0);
  late final _contentObserver = ZooContentObserver(_contentChanged);
  BuildContext? _homeContext;
  int _homeSection = 0;
  bool _shopOpened = false,
      _navUpdateScheduled = false,
      _learningFeatureOpen = false;
  String _shopQuery = '';
  ShopItemKind _shopKind = ShopItemKind.animal;
  VoidCallback? _deferredNavigation;
  BuildContext get _navContext => _homeContext ?? context;
  ZooMainTab get _mainTab => switch (_contentObserver.section) {
    '/study' => ZooMainTab.study,
    '/more' => ZooMainTab.more,
    _ => ZooMainTab.home,
  };
  bool get _contentCanPop => _contentObserver.routes.length > 1;

  @override
  void initState() {
    super.initState();
    _experience = GameExperience(
      storage: widget.gamePreferences ?? widget.assignmentStore?.drafts,
    )..addListener(_experienceChanged);
    _game = GameSession(widget.gameRepository ?? _defaultGameRepository())
      ..addListener(_onGameChanged);
    _purchases = ShopPurchaseController(_game);
    _layoutTransactions = LayoutTransactions(_game);
    _loadExperienceCatalog();
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
      _experience
          .receive(snapshot)
          .then((_) {
            if (!mounted || _studyHistoryStarted || !_experience.ready) return;
            _studyHistoryStarted = true;
            _refreshStudyRewards();
          })
          .catchError((Object _) {});
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
      _homeRevision.value++;
      _syncGameTicker();
    } catch (error, stackTrace) {
      debugPrint('Zoo data could not be loaded: $error\n$stackTrace');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _tick(Duration elapsed) {
    if (_homeSection != 0 || _contentCanPop) {
      _lastFrame = null;
      return;
    }
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
    _homeRevision.dispose();
    _purchases.dispose();
    _layoutTransactions.dispose();
    _experience.removeListener(_experienceChanged);
    _experience.dispose();
    _game.removeListener(_onGameChanged);
    _game.dispose();
    _ownedMock?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _experienceChanged() {
    if (!mounted) return;
    final id = _experience.reward?.transactionId;
    if (id != null && id != _welcomedReward) {
      _welcomedReward = id;
      _reactionRevision++;
    }
    setState(() {});
  }

  Future<void> _loadExperienceCatalog() async {
    try {
      final repository = _game.repository;
      final catalog = await (repository is ShopRepository
          ? (repository as ShopRepository).loadCatalog()
          : loadShopCatalog());
      if (mounted) {
        setState(() => _experienceCatalog = catalog);
        _homeRevision.value++;
      }
    } catch (_) {
      if (mounted) setState(() => _experienceError = '商品を読み込めませんでした');
    }
  }

  Future<void> _refreshStudyRewards() {
    _studyQueue = _studyQueue.then((_) async {
      final store = widget.assignmentStore;
      final snapshot = _game.snapshot;
      if (store == null || snapshot == null || widget.isTeacher || !mounted) {
        return;
      }
      try {
        final records = await store.loadStudyRecords();
        if (!mounted) return;
        await _experience.receiveStudyHistory([
          for (final record in records)
            if (record.rewardCoins > 0 &&
                record.studentId == snapshot.studentId)
              ConfirmedGameReward(
                organizationId: snapshot.organizationId,
                studentId: record.studentId,
                transactionId: 'study:${record.id}',
                amount: record.rewardCoins,
                source: '自習',
              ),
        ]);
        if (mounted) setState(() => _experienceError = null);
      } catch (_) {
        if (mounted) {
          setState(() => _experienceError = 'ごほうび履歴を確認できませんでした。次回再確認します');
        }
      }
    });
    return _studyQueue;
  }

  Future<void> _showGoalPicker() async {
    if (!_experience.ready && _game.snapshot != null) {
      await _experience.receive(_game.snapshot!);
    }
    if (!mounted) return;
    final catalog = _experienceCatalog;
    final state = _game.snapshot;
    showZooSheet(
      _navContext,
      title: '目標の動物',
      children: [
        if (_experienceError != null) Text(_experienceError!),
        if (_experience.persistenceError != null)
          Text(_experience.persistenceError!),
        if (catalog == null)
          OutlinedButton(
            onPressed: () {
              Navigator.pop(_navContext);
              _loadExperienceCatalog().then((_) {
                if (mounted) _showGoalPicker();
              });
            },
            child: const Text('商品を再読み込み'),
          ),
        if (state == null) const Text('ゲームデータへの接続を確認してください'),
        if (state != null && !_experience.ready)
          TextButton(
            onPressed: () {
              Navigator.pop(_navContext);
              _showGoalPicker();
            },
            child: const Text('ゲーム設定を再読み込み'),
          ),
        if (catalog != null && state != null && _experience.ready) ...[
          const Text('図鑑の目標を選びましょう。選択だけではコインを消費しません。'),
          for (final item in catalog.items.where(
            (i) => i.kind == ShopItemKind.animal,
          ))
            SpriteTile(
              leading: AnimalArt(animalId: item.targetId),
              title: Text(item.name),
              subtitle: Text(
                '${item.priceLabel}・${unlockDescription(item, catalog, state)}',
              ),
              trailing: _experience.goalId == item.targetId
                  ? const ZooUiSprite(part: ZooUiPart.check, scale: 2)
                  : null,
              enabled: !item.isOwned(state),
              onTap: item.isOwned(state)
                  ? null
                  : () async {
                      await _experience.setGoal(item.targetId);
                      if (mounted) _finishGoalSelection();
                    },
            ),
          TextButton(
            onPressed: () async {
              await _experience.setGoal(null);
              if (mounted) _finishGoalSelection();
            },
            child: const Text('目標を解除'),
          ),
        ],
      ],
    );
  }

  void _finishGoalSelection() {
    final error = _experience.persistenceError;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.pop(_navContext);
    }
  }

  void _showResearch() {
    final catalog = _experienceCatalog;
    final controller = _controller;
    if (catalog == null || controller == null) {
      _showGoalPicker();
      return;
    }
    final targets = controller.world.animals
        .expand((animal) => animal.evolutionIds)
        .toSet();
    showZooSheet(
      _navContext,
      title: '研究所',
      children: [
        const Text('進化しても元の動物は残ります。解放条件と価格を確認できます。'),
        ListenableBuilder(
          listenable: _game,
          builder: (context, _) {
            final state = _game.snapshot;
            if (state == null) return const Text('ゲームデータに接続してください');
            if (!state.ownedFacilityIds.contains('laboratory')) {
              return Column(
                children: [
                  const Text('研究所を購入・配置すると利用できます'),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(_navContext);
                      _showShop(query: '研究所');
                    },
                    child: const Text('研究所をショップで見る'),
                  ),
                ],
              );
            }
            if (!state.layout.facilities.containsKey('laboratory')) {
              return OutlinedButton(
                onPressed: () {
                  Navigator.pop(_navContext);
                  _startPlacement('laboratory');
                },
                child: const Text('研究所を配置する'),
              );
            }
            return Column(
              children: [
                for (final item in catalog.items.where(
                  (i) => targets.contains(i.targetId),
                ))
                  SpriteTile(
                    leading: AnimalArt(animalId: item.targetId),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.priceLabel}・${unlockDescription(item, catalog, state)}${item.isOwned(state) ? '・解放済み' : ''}',
                    ),
                    enabled: !item.isOwned(state),
                    onTap: item.isOwned(state)
                        ? null
                        : () {
                            Navigator.pop(_navContext);
                            showZooSheet(
                              _navContext,
                              title: item.name,
                              children: [
                                ShopPanel(
                                  session: _game,
                                  purchases: _purchases,
                                  item: item,
                                  catalog: catalog,
                                  onViewZoo: () => Navigator.pop(_navContext),
                                ),
                              ],
                            );
                          },
                  ),
                if (!catalog.items.any((i) => targets.contains(i.targetId)))
                  const Text('研究対象はまだ登録されていません'),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showProfile() {
    showZooSheet(
      _navContext,
      title: 'プロフィール',
      children: [
        SpriteTile(
          leading: const ZooUiSprite(part: ZooUiPart.smile, scale: 3),
          title: Text(widget.accountName ?? 'ゲスト'),
          subtitle: Text(widget.accountEmail ?? 'レベル 1'),
        ),
        Text(
          widget.accountName == null
              ? '端末内デモのプロフィールです。'
              : 'このアカウントのデータをFirebaseに保存します。',
        ),
      ],
    );
  }

  void _showWallet() {
    showZooSheet(
      _navContext,
      title: '所持金',
      children: [GameStatus(session: _game, walletOnly: true)],
    );
  }

  void _showStudy() {
    if (widget.isTeacher && widget.assignmentStore != null) {
      Navigator.of(_navContext).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/study'),
          builder: (_) =>
              TeacherAssignmentsScreen(store: widget.assignmentStore!),
        ),
      );
      return;
    }
    _showMenuPage('/study', '学習メニュー', [
      StudentLearningMenu(
        onStudyMode: () => _openLearningFeature(true),
        onRecords: () => _openLearningFeature(false),
        onAssignments: _showAssignments,
      ),
    ]);
  }

  Future<void> _openLearningFeature(bool mode) async {
    final store = widget.assignmentStore;
    if (store == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('学習データに接続してください')));
      return;
    }
    // The inner route retains the shared navigation and study's own PopScope.
    _learningFeatureOpen = true;
    await Navigator.push(
      _navContext,
      MaterialPageRoute<void>(
        builder: (_) => mode
            ? StudyModeScreen(store: store)
            : StudyRecordsScreen(store: store),
      ),
    );
    _learningFeatureOpen = false;
    final deferred = _deferredNavigation;
    _deferredNavigation = null;
    if (mounted) deferred?.call();
    if (mounted) await _refreshStudyRewards();
  }

  void _showAssignments() {
    final store = widget.assignmentStore;
    if (widget.isTeacher && store != null) {
      Navigator.of(_navContext).push(
        MaterialPageRoute<void>(
          builder: (_) => TeacherAssignmentsScreen(store: store),
        ),
      );
      return;
    }
    if (store != null && widget.gameRepository is StudyRepository) {
      Navigator.of(_navContext).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentAssignmentsScreen(store: store),
        ),
      );
      return;
    }
    showZooSheet(
      _navContext,
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
    showDialog<void>(
      context: _navContext,
      useRootNavigator: false,
      builder: (_) => AnimalEncyclopedia(
        animals: controller.world.animals,
        ownedIds: controller.ownedAnimals,
        onChooseGoal: () {
          Navigator.pop(_navContext);
          _showGoalPicker();
        },
        onSelect: (animal) {
          Navigator.pop(_navContext);
          _showAnimal(animal);
        },
      ),
    );
  }

  void _openEnclosures({bool create = false}) {
    final controller = _controller;
    if (controller == null) return;
    Navigator.of(_navContext).push<void>(
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
      _navContext,
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
    setState(() => _reactionRevision++);
    final world = _controller?.world;
    showZooSheet(
      _navContext,
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
            Navigator.pop(_navContext);
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
            Navigator.pop(_navContext);
            _showShop();
          },
          icon: const ZooArtSprite(part: ZooArtPart.shop, scale: 2),
          label: const Text('ショップを見る'),
        ),
      ],
    );
  }

  Future<void> _showShop({String? query, ShopItemKind? kind}) async {
    if (!await _leaveContent()) {
      if (_learningFeatureOpen) {
        _deferredNavigation = () => _showShop(query: query, kind: kind);
      }
      return;
    }
    if (!mounted) return;
    if (query != null) _shopQuery = query;
    if (kind != null) _shopKind = kind;
    _shopKey.currentState?.browse(query: query, kind: kind);
    _setHomeSection(1);
  }

  void _showFacilities() {
    final controller = _controller;
    if (controller == null) return;
    showZooSheet(
      _navContext,
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
                Navigator.pop(_navContext);
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
            Navigator.pop(_navContext);
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
    Navigator.of(_navContext).push<void>(
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
      Navigator.pop(_navContext);
    }

    showZooSheet(
      _navContext,
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
            Navigator.pop(_navContext);
          },
          child: const Text('同じ確定結果を再受信'),
        ),
        if (state == AssignmentState.approved)
          const Text('この課題は承認済みです。デモを最初から見る場合はアプリを再起動してください。'),
      ],
    );
  }

  void _showMore() {
    _showMenuPage('/more', '設定・プロフィール', [
      SpriteTile(
        title: const Text('プロフィール'),
        leading: const ZooUiSprite(part: ZooUiPart.smile, scale: 2),
        onTap: _showProfile,
      ),
      SpriteTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(widget.isTeacher ? '先生として利用中' : '生徒として利用中'),
      ),
      if (kDebugMode &&
          _game.repository is MockGameRepository &&
          _game.snapshot != null)
        SpriteTile(
          title: const Text('連携デモ'),
          subtitle: const Text('外部の確定結果を模擬受信'),
          onTap: _showDemoResults,
        ),
      if (widget.onSignOut != null)
        SpriteTile(
          title: const Text('ログアウト'),
          leading: const Icon(Icons.logout),
          onTap: widget.onSignOut,
        ),
    ]);
  }

  void _contentChanged() {
    if (_navUpdateScheduled) return;
    _navUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navUpdateScheduled = false;
      if (!mounted) return;
      _lastFrame = null;
      _syncGameTicker();
      setState(() {});
    });
  }

  void _syncGameTicker() {
    final visible =
        _homeSection == 0 &&
        !_contentCanPop &&
        _controller != null &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed);
    if (visible && !_ticker.isActive) _ticker.start();
    if (!visible && _ticker.isActive) _ticker.stop();
  }

  Future<bool> _leaveContent() async {
    final navigator = _contentKey.currentState;
    if (navigator == null) return false;
    while (_contentObserver.routes.length > 1) {
      final before = _contentObserver.routes.last;
      await navigator.maybePop();
      if (!mounted) return false;
      if (_contentObserver.routes.last == before) return false;
    }
    return true;
  }

  Future<void> _switchMain(ZooMainTab tab) async {
    if (tab == _mainTab && tab != ZooMainTab.home) return;
    if (!await _leaveContent()) {
      if (_learningFeatureOpen) _deferredNavigation = () => _switchMain(tab);
      return;
    }
    if (!mounted) return;
    if (tab == ZooMainTab.home) {
      _setHomeSection(0);
    } else if (tab == ZooMainTab.study) {
      _showStudy();
    } else {
      _showMore();
    }
  }

  void _setHomeSection(int section) {
    if (section == 1) _shopOpened = true;
    _homeSection = section;
    _lastFrame = null;
    _syncGameTicker();
    _homeRevision.value++;
    setState(() {});
  }

  void _showMenuPage(String route, String title, List<Widget> children) {
    Navigator.of(_navContext).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: route),
        builder: (_) => ZooMenuPage(title: title, children: children),
      ),
    );
  }

  Widget _buildConstructionMenu() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        '購入する',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      SpriteTile(
        panelStyle: SpritePanelStyle.cream,
        title: const Text('施設を購入'),
        subtitle: const Text('池・研究所・ベンチなどをショップで選ぶ'),
        leading: const ZooArtSprite(part: ZooArtPart.shop, scale: 2),
        onTap: () => _showShop(kind: ShopItemKind.facility, query: ''),
      ),
      SpriteTile(
        panelStyle: SpritePanelStyle.cream,
        title: const Text('囲いの購入・拡張'),
        subtitle: const Text('サイズと場所を決めて購入・拡張する'),
        leading: const TerrainSprite(part: TerrainPart.fence),
        onTap: _openEnclosures,
      ),
      const SizedBox(height: 12),
      const Text(
        '配置・育成する',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      SpriteTile(
        panelStyle: SpritePanelStyle.cream,
        title: const Text('施設の配置・移動'),
        leading: const ZooArtSprite(part: ZooArtPart.pond, scale: 2),
        onTap: _showFacilities,
      ),
      SpriteTile(
        panelStyle: SpritePanelStyle.cream,
        title: const Text('研究所'),
        leading: const ZooBuildingSprite(
          part: ZooBuildingPart.laboratory,
          scale: 1,
        ),
        onTap: _showResearch,
      ),
      SpriteTile(
        panelStyle: SpritePanelStyle.cream,
        title: const Text('動物一覧'),
        subtitle: const Text('図鑑・動物の配置'),
        leading: const ZooUiSprite(part: ZooUiPart.encyclopediaRed, scale: 3),
        onTap: _showAnimals,
      ),
      SpriteTile(
        panelStyle: SpritePanelStyle.cream,
        title: const Text('目標の動物'),
        leading: const ZooUiSprite(part: ZooUiPart.check, scale: 2),
        onTap: _showGoalPicker,
      ),
    ],
  );

  Widget _buildHomeContent() => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        if (constraints.maxHeight >= 220)
          ZooHomeTabs(selected: _homeSection, onSelect: _setHomeSection),
        Expanded(
          child: IndexedStack(
            index: _homeSection,
            children: [
              _buildZooViewport(),
              if (_shopOpened)
                ShopScreen(
                  key: _shopKey,
                  session: _game,
                  purchases: _purchases,
                  embedded: true,
                  initialQuery: _shopQuery,
                  initialKind: _shopKind,
                  onViewZoo: () => _setHomeSection(0),
                  onPlaceFacility: _startPlacement,
                  onCreateEnclosure: () => _openEnclosures(create: true),
                )
              else
                const SizedBox.shrink(),
              _buildConstructionMenu(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildZooViewport() {
    final controller = _controller;
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('動物園データを読み込めませんでした'),
            TextButton(onPressed: _load, child: const Text('再読み込み')),
          ],
        ),
      );
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator(color: zooGreen));
    }
    return ZooViewport(
      key: _viewportKey,
      controller: controller,
      onAnimals: _showAnimals,
      onShop: _showShop,
      reactionRevision: _reactionRevision,
      onAnimalSelected: _showAnimal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showHomeInfo =
        _mainTab == ZooMainTab.home && _homeSection == 0 && !_contentCanPop;
    return PopScope(
      canPop: !_contentCanPop && _homeSection == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_contentCanPop) {
            _contentKey.currentState?.maybePop();
          } else {
            _setHomeSection(0);
          }
        }
      },
      child: PixelUiTheme(
        child: Scaffold(
          backgroundColor: zooPaper,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    if (_mainTab == ZooMainTab.home)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * .30,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ZooHeader(
                                displayName: widget.accountName ?? 'ゲスト',
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
                              if (showHomeInfo)
                                GameNoticeBanner(
                                  session: _game,
                                  onDetails: _showWallet,
                                ),
                              if (showHomeInfo &&
                                  _experienceCatalog != null &&
                                  _game.snapshot != null &&
                                  _experience.goalId != null)
                                ..._experienceCatalog!.items
                                    .where(
                                      (item) =>
                                          item.kind == ShopItemKind.animal &&
                                          item.targetId == _experience.goalId,
                                    )
                                    .map(
                                      (item) => GoalBanner(
                                        item: item,
                                        catalog: _experienceCatalog!,
                                        state: _game.snapshot!,
                                        onChange: _showGoalPicker,
                                        onShop: () =>
                                            _showShop(query: item.name),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: MediaQuery.removeViewInsets(
                        context: context,
                        removeBottom: true,
                        child: Navigator(
                          key: _contentKey,
                          observers: [_contentObserver],
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            settings: const RouteSettings(name: '/home'),
                            builder: (routeContext) {
                              _homeContext = routeContext;
                              return AnimatedBuilder(
                                animation: Listenable.merge([
                                  _game,
                                  _experience,
                                  _homeRevision,
                                ]),
                                builder: (_, _) => _buildHomeContent(),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    ZooBottomBar(
                      selectedTab: _mainTab,
                      onHome: () => _switchMain(ZooMainTab.home),
                      onStudy: () => _switchMain(ZooMainTab.study),
                      studyLabel: widget.isTeacher ? '課題' : '学習',
                      onMore: () => _switchMain(ZooMainTab.more),
                    ),
                  ],
                ),
              ),
              if (!widget.isTeacher &&
                  _experience.reward != null &&
                  !_contentCanPop &&
                  _homeSection == 0 &&
                  ModalRoute.of(context)?.isCurrent != false)
                Positioned.fill(
                  child: RewardCelebration(
                    reward: _experience.reward!,
                    onClose: () => _experience.dismissReward(
                      _experience.reward!.transactionId,
                    ),
                    onShop: () {
                      _experience.dismissReward(
                        _experience.reward!.transactionId,
                      );
                      _showShop();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
