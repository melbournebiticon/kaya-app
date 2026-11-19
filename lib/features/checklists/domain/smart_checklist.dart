/// Individual entry inside a [SmartChecklist].
class ChecklistItemEntry {
  const ChecklistItemEntry({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  final String id;
  final String title;
  final bool isCompleted;

  ChecklistItemEntry copyWith({String? id, String? title, bool? isCompleted}) {
    return ChecklistItemEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ChecklistItemEntry &&
        other.id == id &&
        other.title == title &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode => Object.hash(id, title, isCompleted);
}

/// Reusable Smart Checklist with progress tracking and completion reset
/// (Phase 7).
class SmartChecklist {
  const SmartChecklist({
    required this.id,
    required this.userId,
    required this.title,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final List<ChecklistItemEntry> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalCount => items.length;

  int get completedCount =>
      items.where((ChecklistItemEntry item) => item.isCompleted).length;

  bool get hasCompletedItems => completedCount > 0;

  double get progressRatio =>
      totalCount == 0 ? 0.0 : completedCount / totalCount;

  String get progressLabel =>
      totalCount == 0 ? 'No items yet' : '$completedCount of $totalCount done';

  SmartChecklist copyWith({
    String? id,
    String? userId,
    String? title,
    List<ChecklistItemEntry>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SmartChecklist(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
