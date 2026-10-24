import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../data/zoo_repository.dart';
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
import '../../shop/presentation/shop_panel.dart';

class ZooScreen extends StatefulWidget {
  const ZooScreen({super.key, this.gameRepository});

  final GameRepository? gameRepository;

  @override
  State<ZooScreen> createState() => _ZooScreenState();
}

class _ZooScreenState extends State<ZooScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ZooController? _controller;
  late final GameSession _game;
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
    _ownedMock = MockGameRepository(scenario: DemoScenario.values.byName(name));
    return _ownedMock!;
  }

  void _onGameChanged() {
    if (!mounted) return;
    final snapshot = _game.snapshot;
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
      if (!mounted) return;
      setState(
        () => _controller = ZooController(
          world,
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
        ListTile(
          contentPadding: EdgeInsets.zero,
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
    showZooSheet(
      context,
      title: '課題',
      children: [GameStatus(session: _game)],
    );
  }

  void _showAnimals() {
    final controller = _controller;
    if (controller == null) return;
    showZooSheet(
      context,
      title: '動物一覧',
      children: [
        const Text('いま動物園にいる仲間たち', style: TextStyle(color: zooGreen)),
        const SizedBox(height: 8),
        for (final animal in controller.animals)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Color(animal.definition.placeholderColor),
              child: const Icon(Icons.pets, color: zooInk),
            ),
            title: Text(animal.definition.name),
            subtitle: const Text('動物園で暮らしています'),
          ),
        const SizedBox(height: 8),
        if (controller.animals.isEmpty)
          const Text('まだ動物はいません。ショップから仲間を迎えましょう。'),
        const Text('動物の見た目は仮素材です。', style: TextStyle(fontSize: 12)),
      ],
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
      children: [
        if (kDebugMode &&
            _game.repository is MockGameRepository &&
            _game.snapshot != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.science_outlined, color: zooGreen),
            title: const Text('連携デモ'),
            subtitle: const Text('外部の確定結果を模擬受信'),
            onTap: () {
              Navigator.pop(context);
              _showDemoResults();
            },
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const ZooUiSprite(part: ZooUiPart.encyclopediaRed, scale: 3),
          title: const Text('動物一覧'),
          subtitle: const Text('動物園にいる仲間を見る'),
          trailing: const Icon(Icons.chevron_right),
          enabled: _controller != null,
          onTap: () {
            Navigator.pop(context);
            _showAnimals();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined, color: zooGreen),
          title: const Text('ショップ'),
          subtitle: const Text('動物や施設を迎える'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(context);
            showZooSheet(
              context,
              title: 'ショップ',
              children: [ShopPanel(session: _game)],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
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
                    ),
            ),
            ZooBottomBar(
              onHome: () => _viewportKey.currentState?.resetView(),
              onStudy: _showStudy,
              onMore: _showMore,
            ),
          ],
        ),
      ),
    );
  }
}
