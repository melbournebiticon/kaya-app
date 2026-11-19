import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';

/// Client and repository-level input validators for Phase 3 Task Management
/// (Section 6 Input Validation Standards).
abstract final class TaskValidators {
  static const int minTitleLength = 1;
  static const int maxTitleLength = 140;
  static const int maxNotesLength = 1000;
  static const KayaDateOnly minSupportedDate = KayaDateOnly(2000, 1, 1);
  static const KayaDateOnly maxSupportedDate = KayaDateOnly(2100, 12, 31);

  static final RegExp _disallowedControlChars = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  /// Validates a task title after trimming leading and trailing whitespace.
  static String? validateTitle(String? rawTitle) {
    final String trimmed = (rawTitle ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Task title is required.';
    }
    if (trimmed.length < minTitleLength) {
      return 'Task title must be at least $minTitleLength character.';
    }
    if (trimmed.length > maxTitleLength) {
      return 'Task title must not exceed $maxTitleLength characters.';
    }
    if (_disallowedControlChars.hasMatch(trimmed)) {
      return 'Task title contains invalid characters.';
    }
    return null;
  }

  /// Validates optional task notes.
  static String? validateNotes(String? rawNotes) {
    final String trimmed = (rawNotes ?? '').trim();
    if (trimmed.length > maxNotesLength) {
      return 'Notes must not exceed $maxNotesLength characters.';
    }
    if (_disallowedControlChars.hasMatch(trimmed)) {
      return 'Notes contain invalid control characters.';
    }
    return null;
  }

  /// Validates an optional due date falls within a valid calendar range.
  static String? validateDueDate(KayaDateOnly? dueDate) {
    if (dueDate == null) {
      return null;
    }
    if (dueDate.isBefore(minSupportedDate) ||
        dueDate.isAfter(maxSupportedDate)) {
      return 'Due date must be between 2000-01-01 and 2100-12-31.';
    }
    return null;
  }

  static String? validatePriorityId(String? rawId) {
    if (TaskPriority.tryFromId(rawId) == null) {
      return 'Unsupported task priority.';
    }
    return null;
  }

  static String? validateCategoryId(String? rawId) {
    if (TaskCategory.tryFromId(rawId) == null) {
      return 'Unsupported task category.';
    }
    return null;
  }
}
