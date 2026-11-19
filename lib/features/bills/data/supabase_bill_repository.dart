import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/bill_reminder_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/bills/domain/bill_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Supabase implementation of [BillRepository] (Phase 5).
class SupabaseBillRepository implements BillRepository {
  SupabaseBillRepository({required this.client});

  final SupabaseClient client;

  BillItem _fromRow(Map<String, dynamic> row) {
    return BillItem(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      recurrenceGroupId: (row['recurrence_group_id'] as String? ?? '').trim(),
      title: (row['title'] as String? ?? '').trim(),
      notes: (row['notes'] as String? ?? '').trim(),
      category:
          BillCategory.tryFromDbValue(row['category'] as String?) ??
          BillCategory.utilities,
      amountMinor: SupabaseErrorMapper.parseInt(row['amount_minor']),
      currency:
          SupportedCurrency.tryFromCode(row['currency'] as String?) ??
          SupportedCurrency.php,
      dueDate: SupabaseErrorMapper.parseDateOnly(row['due_date']),
      recurrence:
          BillRecurrence.tryFromDbValue(row['recurrence'] as String?) ??
          BillRecurrence.oneTime,
      isPaid: row['is_paid'] as bool? ?? false,
      paidAt: SupabaseErrorMapper.parseOptionalDateTimeUtc(row['paid_at']),
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  void _validateBill({
    required String title,
    required String notes,
    required int amountMinor,
    required KayaDateOnly dueDate,
  }) {
    final String? titleErr = BillReminderValidators.validateTitle(
      title,
      fieldName: 'Bill name',
    );
    if (titleErr != null) {
      throw AuthFailure.validation(titleErr);
    }
    final String? notesErr = BillReminderValidators.validateNotes(notes);
    if (notesErr != null) {
      throw AuthFailure.validation(notesErr);
    }
    final String? amtErr = BillReminderValidators.validateBillAmountMinor(
      amountMinor,
    );
    if (amtErr != null) {
      throw AuthFailure.validation(amtErr);
    }
    final String? dateErr = BillReminderValidators.validateDueDate(dueDate);
    if (dateErr != null) {
      throw AuthFailure.validation(dateErr);
    }
  }

  @override
  Future<List<BillItem>> fetchBills({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> rows = await client
          .from('bills')
          .select()
          .eq('user_id', uid)
          .order('due_date', ascending: true);
      return rows
          .map((dynamic row) => _fromRow(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load bills.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateBill(
      title: title,
      notes: notes,
      amountMinor: amountMinor,
      dueDate: dueDate,
    );
    try {
      final Map<String, dynamic> inserted = await client
          .from('bills')
          .insert(<String, dynamic>{
            'user_id': uid,
            'recurrence_group_id': '',
            'title': title.trim(),
            'notes': notes.trim(),
            'category': category.dbValue,
            'amount_minor': amountMinor,
            'currency': currency.code,
            'due_date': dueDate.toIsoDateString(),
            'recurrence': recurrence.dbValue,
          })
          .select()
          .single();
      return _fromRow(inserted);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to create bill.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateBill(
      title: title,
      notes: notes,
      amountMinor: amountMinor,
      dueDate: dueDate,
    );
    try {
      final Map<String, dynamic> updated = await client
          .from('bills')
          .update(<String, dynamic>{
            'title': title.trim(),
            'notes': notes.trim(),
            'category': category.dbValue,
            'amount_minor': amountMinor,
            'currency': currency.code,
            'due_date': dueDate.toIsoDateString(),
            'recurrence': recurrence.dbValue,
          })
          .eq('id', billId)
          .eq('user_id', uid)
          .select()
          .single();
      return _fromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update bill.');
    }
  }

  @override
  Future<BillStatusUpdateResult> setBillPaid({
    required String authenticatedUserId,
    required String billId,
    required bool isPaid,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      final Map<String, dynamic> updatedRow = await client
          .from('bills')
          .update(<String, dynamic>{
            'is_paid': isPaid,
            'paid_at': isPaid ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('id', billId)
          .eq('user_id', uid)
          .select()
          .single();
      final BillItem updated = _fromRow(updatedRow);

      BillItem? spawnedNext;
      if (isPaid && updated.recurrence != BillRecurrence.oneTime) {
        final KayaDateOnly? nextDue = updated.recurrence.nextDueDate(
          updated.dueDate,
        );
        if (nextDue != null &&
            BillReminderValidators.validateDueDate(nextDue) == null) {
          try {
            final Map<String, dynamic> spawnedRow = await client
                .from('bills')
                .insert(<String, dynamic>{
                  'user_id': uid,
                  'recurrence_group_id': updated.recurrenceGroupId,
                  'title': updated.title,
                  'notes': updated.notes,
                  'category': updated.category.dbValue,
                  'amount_minor': updated.amountMinor,
                  'currency': updated.currency.code,
                  'due_date': nextDue.toIsoDateString(),
                  'recurrence': updated.recurrence.dbValue,
                  'is_paid': false,
                })
                .select()
                .single();
            spawnedNext = _fromRow(spawnedRow);
          } on PostgrestException catch (e) {
            if ((e.code ?? '').trim() != '23505') {
              rethrow;
            }
          }
        }
      }

      return BillStatusUpdateResult(
        updatedBill: updated,
        spawnedNextBill: spawnedNext,
      );
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update bill status.');
    }
  }

  @override
  Future<void> deleteBill({
    required String authenticatedUserId,
    required String billId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client.from('bills').delete().eq('id', billId).eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete bill.');
    }
  }
}
