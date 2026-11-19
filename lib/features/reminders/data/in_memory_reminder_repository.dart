import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/bill_reminder_validators.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/reminders/domain/reminder_repository.dart';

/// Deterministic, RLS-enforcing implementation of [ReminderRepository].
class InMemoryReminderRepository implements ReminderRepository {
  InMemoryReminderRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, ReminderItem> _remindersById = <String, ReminderItem>{};
  int _nextReminderSeq = 1;

  /// Test hook to simulate network errors and verify error/retry states.
  bool simulateNetworkFailure = false;

  void _checkNetwork() {
    if (simulateNetworkFailure) {
      throw AuthFailure.network(
        'Unable to synchronize reminders. Please check your connection and try again.',
      );
    }
  }

  String _requireAuthenticatedUser(String authenticatedUserId) {
    final String trimmed = authenticatedUserId.trim();
    if (trimmed.isEmpty) {
      throw AuthFailure.unauthorizedAccess();
    }
    return trimmed;
  }

  ReminderItem _requireOwnedReminder({
    required String authenticatedUserId,
    required String reminderId,
  }) {
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final ReminderItem? existing = _remindersById[reminderId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  void _validatePayload({
    required String title,
    required String notes,
    required KayaDateOnly dueDate,
  }) {
    final String? titleError = BillReminderValidators.validateTitle(
      title,
      fieldName: 'Reminder title',
    );
    if (titleError != null) {
      throw AuthFailure.validation(titleError);
    }
    final String? notesError = BillReminderValidators.validateNotes(notes);
    if (notesError != null) {
      throw AuthFailure.validation(notesError);
    }
    final String? dateError = BillReminderValidators.validateDueDate(
      dueDate,
      fieldName: 'Reminder date',
    );
    if (dateError != null) {
      throw AuthFailure.validation(dateError);
    }
  }

  @override
  Future<List<ReminderItem>> fetchReminders({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return _remindersById.values
        .where((ReminderItem r) => r.userId == uid)
        .toList();
  }

  @override
  Future<ReminderItem> createReminder({
    required String authenticatedUserId,
    required String title,
    String notes = '',
    required KayaDateOnly dueDate,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validatePayload(title: title, notes: notes, dueDate: dueDate);

    final DateTime now = _clock().toUtc();
    final String id = 'rem_${_nextReminderSeq++}';
    final ReminderItem created = ReminderItem(
      id: id,
      userId: uid,
      title: title.trim(),
      notes: notes.trim(),
      dueDate: dueDate,
      isCompleted: false,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    _remindersById[id] = created;
    return created;
  }

  @override
  Future<ReminderItem> updateReminder({
    required String authenticatedUserId,
    required String reminderId,
    required String title,
    required String notes,
    required KayaDateOnly dueDate,
  }) async {
    _checkNetwork();
    final ReminderItem existing = _requireOwnedReminder(
      authenticatedUserId: authenticatedUserId,
      reminderId: reminderId,
    );
    _validatePayload(title: title, notes: notes, dueDate: dueDate);

    final ReminderItem updated = existing.copyWith(
      title: title.trim(),
      notes: notes.trim(),
      dueDate: dueDate,
      updatedAt: _clock().toUtc(),
    );
    _remindersById[existing.id] = updated;
    return updated;
  }

  @override
  Future<ReminderItem> setReminderCompleted({
    required String authenticatedUserId,
    required String reminderId,
    required bool isCompleted,
  }) async {
    _checkNetwork();
    final ReminderItem existing = _requireOwnedReminder(
      authenticatedUserId: authenticatedUserId,
      reminderId: reminderId,
    );

    final DateTime now = _clock().toUtc();
    final ReminderItem updated = existing.copyWith(
      isCompleted: isCompleted,
      completedAt: isCompleted ? now : null,
      clearCompletedAt: !isCompleted,
      updatedAt: now,
    );
    _remindersById[existing.id] = updated;
    return updated;
  }

  @override
  Future<void> deleteReminder({
    required String authenticatedUserId,
    required String reminderId,
  }) async {
    _checkNetwork();
    final ReminderItem existing = _requireOwnedReminder(
      authenticatedUserId: authenticatedUserId,
      reminderId: reminderId,
    );
    _remindersById.remove(existing.id);
  }
}
