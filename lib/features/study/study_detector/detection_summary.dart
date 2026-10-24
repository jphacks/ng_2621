// COCO IDs apply to the current standard YOLO26s model only.
const _targetNames = {'book': '本', 'laptop': 'ノートPC', 'cell phone': 'スマホ'};
const _cocoTargets = {63: 'laptop', 67: 'cell phone', 73: 'book'};

class DetectionSummary {
  final Map<String, double> scores;

  const DetectionSummary(this.scores);

  Set<String> get targets =>
      scores.keys.where(_targetNames.containsKey).toSet();

  String get targetText => targets.isEmpty
      ? '対象物体なし'
      : targets.map((name) => _describe(name)).join('、');

  String get diagnosticText {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.isEmpty
        ? '検出なし（信頼度10%以上）'
        : entries.map((entry) => _describe(entry.key)).join('\n');
  }

  String _describe(String name) =>
      '${_targetNames[name] ?? name} ${(scores[name]! * 100).toStringAsFixed(1)}%';
}

DetectionSummary summarizeDetections(List<dynamic> boxes) {
  final scores = <String, double>{};
  for (final raw in boxes) {
    if (raw is! Map) continue;
    String? label;
    for (final key in ['className', 'name', 'class', 'classIndex']) {
      final value = raw[key];
      if (value == null) continue;
      final text = value.toString().trim().toLowerCase();
      if (text.isEmpty) continue;
      final id = num.tryParse(text);
      label = id == null ? text : _cocoTargets[id] ?? 'class ${id.toInt()}';
      break;
    }
    final value = raw['confidence'];
    final score = value is num ? value.toDouble() : double.tryParse('$value');
    if (label == null ||
        score == null ||
        !score.isFinite ||
        score < 0 ||
        score > 1) {
      continue;
    }
    if (score > (scores[label] ?? -1)) scores[label] = score;
  }
  return DetectionSummary(Map.unmodifiable(scores));
}
