import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../data/zoo_repository.dart';
import '../../game/data/mock_game_repository.dart';
import '../../game/domain/game_repository.dart';
import '../../game/presentation/game_session.dart';
import '../../game/presentation/game_status.dart';
import 'zoo_controller.dart';
import '../../../core/ui/zoo_ui.dart';
import 'zoo_chrome.dart';
import 'zoo_viewport.dart';

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
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final world = await ZooRepository().load();
      if (!mounted) return;
      setState(() => _controller = ZooController(world));
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
        const Text('動物の見た目は仮素材です。収集・進化は準備中です。', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showMore() {
    showZooSheet(
      context,
      title: 'その他',
      children: [
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
          subtitle: const Text('準備中'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(context);
            showZooSheet(
              context,
              title: 'ショップ',
              children: const [
                Text('ショップは準備中です'),
                SizedBox(height: 12),
                Text('動物や施設を迎える機能は、今後追加します。コインは消費しません。'),
              ],
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
