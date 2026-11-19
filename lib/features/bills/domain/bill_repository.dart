import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';

/// Result returned when toggling paid/unpaid status on a bill.
///
/// When marking a recurring bill paid generates the next cycle's bill for the
/// first time, [spawnedNextBill] carries that new entry without creating
/// duplicates on subsequent toggles.
class BillStatusUpdateResult {
  const BillStatusUpdateResult({
    required this.updatedBill,
    this.spawnedNextBill,
  });

  final BillItem updatedBill;
  final BillItem? spawnedNextBill;
}

/// Repository contract for Phase 5 Bills Management.
///
/// Mirrors PostgreSQL constraints and RLS policies in
/// `supabase/migrations/20261114000004_phase5_bills_and_reminders.sql`.
abstract class BillRepository {
  Future<List<BillItem>> fetchBills({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<BillItem> createBill({
    required String authenticatedUserId,
    required String title,
    String notes = '',
    BillCategory category = BillCategory.utilities,
    required int amountMinor,
    required SupportedCurrency currency,
    required KayaDateOnly dueDate,
    BillRecurrence recurrence = BillRecurrence.oneTime,
  });

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
  });

  Future<BillStatusUpdateResult> setBillPaid({
    required String authenticatedUserId,
    required String billId,
    required bool isPaid,
  });

  Future<void> deleteBill({
    required String authenticatedUserId,
    required String billId,
  });
}
