import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/bill_reminder_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/bills/domain/bill_repository.dart';

/// Deterministic, RLS-enforcing implementation of [BillRepository].
///
/// Enforces ownership isolation, input validation, and non-duplicating
/// recurring bill creation when bills are marked paid.
class InMemoryBillRepository implements BillRepository {
  InMemoryBillRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, BillItem> _billsById = <String, BillItem>{};
  int _nextBillSequence = 1;

  /// Test hook to simulate network errors and verify error/retry states.
  bool simulateNetworkFailure = false;

  void _checkNetwork() {
    if (simulateNetworkFailure) {
      throw AuthFailure.network(
        'Unable to synchronize bills. Please check your connection and try again.',
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

  BillItem _requireOwnedBill({
    required String authenticatedUserId,
    required String billId,
  }) {
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final BillItem? existing = _billsById[billId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  void _validateBillPayload({
    required String title,
    required String notes,
    required int amountMinor,
    required KayaDateOnly dueDate,
  }) {
    final String? titleError = BillReminderValidators.validateTitle(
      title,
      fieldName: 'Bill name',
    );
    if (titleError != null) {
      throw AuthFailure.validation(titleError);
    }
    final String? notesError = BillReminderValidators.validateNotes(notes);
    if (notesError != null) {
      throw AuthFailure.validation(notesError);
    }
    final String? amountError = BillReminderValidators.validateBillAmountMinor(
      amountMinor,
    );
    if (amountError != null) {
      throw AuthFailure.validation(amountError);
    }
    final String? dateError = BillReminderValidators.validateDueDate(
      dueDate,
      fieldName: 'Bill due date',
    );
    if (dateError != null) {
      throw AuthFailure.validation(dateError);
    }
  }

  @override
  Future<List<BillItem>> fetchBills({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return _billsById.values.where((BillItem b) => b.userId == uid).toList();
  }

  @override
  Future<BillItem> createBill({
    required String authenticatedUserId,
    required String title,
    String notes = '',
    BillCategory category = BillCategory.utilities,
    required int amountMinor,
    required SupportedCurrency currency,
    required KayaDateOnly dueDate,
    BillRecurrence recurrence = BillRecurrence.oneTime,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validateBillPayload(
      title: title,
      notes: notes,
      amountMinor: amountMinor,
      dueDate: dueDate,
    );

    final DateTime now = _clock().toUtc();
    final String billId = 'bil_${_nextBillSequence++}';
    final BillItem created = BillItem(
      id: billId,
      userId: uid,
      recurrenceGroupId: billId,
      title: title.trim(),
      notes: notes.trim(),
      category: category,
      amountMinor: amountMinor,
      currency: currency,
      dueDate: dueDate,
      recurrence: recurrence,
      isPaid: false,
      paidAt: null,
      createdAt: now,
      updatedAt: now,
    );
    _billsById[billId] = created;
    return created;
  }

  @override
  Future<BillItem> updateBill({
    required String authenticatedUserId,
    required String billId,
    required String title,
    required String notes,
    required BillCategory category,
    required int amountMinor,
    required SupportedCurrency currency,
    required KayaDateOnly dueDate,
    required BillRecurrence recurrence,
  }) async {
    _checkNetwork();
    final BillItem existing = _requireOwnedBill(
      authenticatedUserId: authenticatedUserId,
      billId: billId,
    );
    _validateBillPayload(
      title: title,
      notes: notes,
      amountMinor: amountMinor,
      dueDate: dueDate,
    );

    // Ensure recurrence group uniqueness if user moves dueDate manually.
    final bool conflictsWithSibling = _billsById.values.any(
      (BillItem other) =>
          other.id != existing.id &&
          other.userId == existing.userId &&
          other.recurrenceGroupId == existing.recurrenceGroupId &&
          other.dueDate == dueDate,
    );
    if (conflictsWithSibling) {
      throw AuthFailure.validation(
        'Another cycle of this recurring bill is already scheduled for ${dueDate.formatReadable()}.',
      );
    }

    final BillItem updated = existing.copyWith(
      title: title.trim(),
      notes: notes.trim(),
      category: category,
      amountMinor: amountMinor,
      currency: currency,
      dueDate: dueDate,
      recurrence: recurrence,
      updatedAt: _clock().toUtc(),
    );
    _billsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<BillStatusUpdateResult> setBillPaid({
    required String authenticatedUserId,
    required String billId,
    required bool isPaid,
  }) async {
    _checkNetwork();
    final BillItem existing = _requireOwnedBill(
      authenticatedUserId: authenticatedUserId,
      billId: billId,
    );

    final DateTime now = _clock().toUtc();
    final BillItem updated = existing.copyWith(
      isPaid: isPaid,
      paidAt: isPaid ? now : null,
      clearPaidAt: !isPaid,
      updatedAt: now,
    );
    _billsById[existing.id] = updated;

    BillItem? spawnedNextBill;
    if (isPaid && updated.recurrence != BillRecurrence.oneTime) {
      final KayaDateOnly? nextDate = updated.recurrence.nextDueDate(
        updated.dueDate,
      );
      if (nextDate != null &&
          !nextDate.isAfter(BillReminderValidators.maxSupportedDate)) {
        final bool cycleAlreadyExists = _billsById.values.any(
          (BillItem candidate) =>
              candidate.userId == updated.userId &&
              candidate.recurrenceGroupId == updated.recurrenceGroupId &&
              candidate.dueDate == nextDate,
        );
        if (!cycleAlreadyExists) {
          final String nextId = 'bil_${_nextBillSequence++}';
          spawnedNextBill = BillItem(
            id: nextId,
            userId: updated.userId,
            recurrenceGroupId: updated.recurrenceGroupId,
            title: updated.title,
            notes: updated.notes,
            category: updated.category,
            amountMinor: updated.amountMinor,
            currency: updated.currency,
            dueDate: nextDate,
            recurrence: updated.recurrence,
            isPaid: false,
            paidAt: null,
            createdAt: now,
            updatedAt: now,
          );
          _billsById[nextId] = spawnedNextBill;
        }
      }
    }

    return BillStatusUpdateResult(
      updatedBill: updated,
      spawnedNextBill: spawnedNextBill,
    );
  }

  @override
  Future<void> deleteBill({
    required String authenticatedUserId,
    required String billId,
  }) async {
    _checkNetwork();
    final BillItem existing = _requireOwnedBill(
      authenticatedUserId: authenticatedUserId,
      billId: billId,
    );
    _billsById.remove(existing.id);
  }
}
