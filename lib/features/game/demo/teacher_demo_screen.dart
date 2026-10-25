import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import 'presentation_scenario.dart';

/// Independent phone script. Updates are deliberately triggered by the presenter.
class TeacherDemoScreen extends StatefulWidget {
  const TeacherDemoScreen({super.key});
  @override
  State<TeacherDemoScreen> createState() => _TeacherDemoScreenState();
}

class _TeacherDemoScreenState extends State<TeacherDemoScreen> {
  final _title = TextEditingController(text: PresentationScenario.title);
  final _description = TextEditingController(
    text: PresentationScenario.description,
  );
  final _advice = TextEditingController(text: PresentationScenario.advice);
  final _form = GlobalKey<FormState>();
  int _stage = 0;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _advice.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _stage = 0;
    _error = null;
    _title.text = PresentationScenario.title;
    _description.text = PresentationScenario.description;
    _advice.text = PresentationScenario.advice;
  });

  Widget _panel(List<Widget> children) => SpritePanel(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _action(String key, String label, VoidCallback action) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton(
      key: ValueKey(key),
      onPressed: action,
      child: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: Scaffold(
      backgroundColor: const Color(0xFFFAF9F0),
      appBar: AppBar(
        title: const Text('先生の発表デモ'),
        actions: [
          IconButton(
            tooltip: 'デモを初期化',
            onPressed: _reset,
            icon: const ZooUiSprite(part: ZooUiPart.back, scale: 2),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const WoodPanel(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ZooCharacterSprite(
                            part: ZooCharacterPart.teacherMale,
                            scale: 3,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '学びを動物園につなげよう',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '通信しない発表デモです。生徒端末と操作タイミングを合わせてください。入力を変更しても他端末には反映されません。',
                  ),
                  const SizedBox(height: 12),
                  if (_stage == 0)
                    _panel([
                      const Text(
                        '1. 課題を作成',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              key: const ValueKey('teacher-task-title'),
                              controller: _title,
                              decoration: const InputDecoration(
                                labelText: '課題名',
                              ),
                              maxLength: 80,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? '課題名を入力してください'
                                  : null,
                            ),
                            TextFormField(
                              key: const ValueKey('teacher-task-description'),
                              controller: _description,
                              decoration: const InputDecoration(
                                labelText: '課題内容',
                              ),
                              minLines: 2,
                              maxLines: 5,
                              maxLength: 500,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? '課題内容を入力してください'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const Text('初回提出 ＋30コイン ／ 承認 ＋70コイン'),
                      _action('teacher-create', '課題を作成する', () {
                        if (_form.currentState!.validate()) {
                          setState(() => _stage = 1);
                        }
                      }),
                    ])
                  else ...[
                    _panel([
                      Text(
                        _title.text.trim(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_description.text.trim()),
                      const SizedBox(height: 8),
                      const Text('報酬：提出30 ＋ 承認70コイン'),
                      Text(_stage == 1 ? '状態：作成済み・未配布' : '状態：配布済み'),
                      if (_stage == 1)
                        _action(
                          'teacher-distribute',
                          '生徒に配布する',
                          () => setState(() => _stage = 2),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    if (_stage >= 2)
                      _panel([
                        Text(
                          _stage < 4 ? '2. 提出状況の確認' : '提出内容・承認結果',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _stage == 2
                              ? 'デモ生徒：未提出'
                              : _stage == 3
                              ? 'デモ生徒：確認待ち'
                              : 'デモ生徒：承認済み ＋70コイン',
                        ),
                        if (_stage == 2) ...[
                          const Text('生徒端末で提出が終わったら更新してください。'),
                          _action(
                            'teacher-refresh-submission',
                            '提出状況を更新する',
                            () => setState(() => _stage = 3),
                          ),
                        ],
                        if (_stage >= 3) ...[
                          const SizedBox(height: 12),
                          const Text('提出された回答'),
                          const SelectableText(PresentationScenario.answer),
                          const Text('初回提出分：30コイン獲得済み'),
                        ],
                        if (_stage == 3)
                          _action(
                            'teacher-approve',
                            '内容を確認して承認 ＋70',
                            () => setState(() => _stage = 4),
                          ),
                      ]),
                    if (_stage >= 4) ...[
                      const SizedBox(height: 16),
                      _panel([
                        const Text(
                          '3. 生徒にアドバイス',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_stage == 4) ...[
                          TextField(
                            key: const ValueKey('teacher-advice'),
                            controller: _advice,
                            decoration: const InputDecoration(
                              labelText: 'アドバイス',
                            ),
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 500,
                          ),
                          if (_error != null)
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          _action(
                            'teacher-send-advice',
                            'アドバイスを送信する',
                            () => setState(() {
                              if (_advice.text.trim().isEmpty) {
                                _error = 'アドバイスを入力してください';
                                return;
                              }
                              _error = null;
                              _stage = 5;
                            }),
                          ),
                        ] else ...[
                          Text(_advice.text.trim()),
                          const SizedBox(height: 12),
                          const Text(
                            '送信済み。生徒端末で「承認結果を確認」を押してください。',
                            key: ValueKey('teacher-advice-sent'),
                          ),
                        ],
                      ]),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
