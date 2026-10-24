import 'package:flutter/foundation.dart';

enum AssignmentSubject {
  japanese('国語'),
  mathematics('算数・数学'),
  english('英語'),
  science('理科'),
  socialStudies('社会'),
  other('その他');

  const AssignmentSubject(this.label);
  final String label;
}

class DemoAssignment {
  const DemoAssignment({
    required this.subject,
    required this.title,
    required this.description,
    required this.dueAt,
  });
  final AssignmentSubject subject;
  final String title;
  final String description;
  final DateTime dueAt;
}

/// Local demo only: all roles share one demo class until the app exits.
class DemoAssignmentStore extends ChangeNotifier {
  final _assignments = <DemoAssignment>[];
  List<DemoAssignment> get assignments => List.unmodifiable(_assignments);

  void publish(DemoAssignment assignment) {
    if (assignment.title.trim().isEmpty ||
        assignment.title.length > 100 ||
        assignment.description.trim().isEmpty ||
        assignment.description.length > 3000) {
      throw ArgumentError('Invalid assignment');
    }
    _assignments.add(assignment);
    notifyListeners();
  }
}
