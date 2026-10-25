import 'package:flutter/material.dart';

import '../../../core/ui/zoo_font.dart';
import '../../../core/ui/zoo_ui.dart';
import '../../zoo/presentation/zoo_screen.dart';
import 'demo_tutorial_controller.dart';
import 'presentation_repository.dart';

/// Can be launched before auth/Firebase initialization using a compile-time flag.
class PresentationDemoApp extends StatelessWidget {
  const PresentationDemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ZooっとStudy 発表デモ',
    theme: ThemeData(fontFamily: ZooFont.family),
    builder: (context, child) =>
        PixelUiTheme(child: child ?? const SizedBox.shrink()),
    home: const DemoTutorialScreen(),
  );
}

class DemoTutorialScreen extends StatefulWidget {
  const DemoTutorialScreen({super.key});
  @override
  State<DemoTutorialScreen> createState() => _DemoTutorialScreenState();
}

class _DemoTutorialScreenState extends State<DemoTutorialScreen> {
  int _session = 0;
  @override
  Widget build(BuildContext context) => _TutorialSession(
    key: ValueKey(_session),
    onRestart: () => setState(() => _session++),
  );
}

class _TutorialSession extends StatefulWidget {
  const _TutorialSession({super.key, required this.onRestart});
  final VoidCallback onRestart;
  @override
  State<_TutorialSession> createState() => _TutorialSessionState();
}

class _TutorialSessionState extends State<_TutorialSession> {
  late final _repository = PresentationRepository();
  late final _controller = DemoTutorialController(_repository);
  bool _started = false;
  @override
  void dispose() {
    _controller.dispose();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: _started
        ? ZooScreen(
            gameRepository: _repository,
            assignmentStore: _repository,
            presentation: _controller,
            onDemoRestart: widget.onRestart,
            accountName: 'デモ生徒',
            accountStorageDescription: _repository.storageExplanation,
          )
        : Scaffold(
            backgroundColor: const Color(0xFFFAF9F0),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SpritePanel(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                              child: ZooCharacterSprite(
                                part: ZooCharacterPart.panda,
                                scale: 4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const WoodPanel(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  '学びが動物園に変わる体験',
                                  style: TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '先生役と生徒役を交代しながら、課題・ごほうび・動物園の成長を順番に体験できます。',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '① 課題を配布・提出・承認\n② ウサギを購入して囲いへ\n③ 池や研究所を配置\n④ 炎狐への進化と図鑑\n⑤ 育った動物園の完成イメージ',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '通信・ログイン不要の発表デモです。最初の囲いを無料で用意しています。後半は明示した体験用コインを使います。実アカウントや保存済みデータには反映しません。',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              key: const ValueKey('demo-start'),
                              onPressed: () => setState(() => _started = true),
                              child: const Text('体験をはじめる'),
                            ),
                            if (Navigator.of(context).canPop())
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('通常のアプリに戻る'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}
