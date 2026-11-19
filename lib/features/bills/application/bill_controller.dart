import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/bills/domain/bill_repository.dart';
import 'package:material_ui/material_ui.dart';

/// Loading status for bills queries.
enum BillLoadStatus { idle, loading, loaded, error }

/// Application state controller for Phase 5 Bills Management.
///
/// Provides overdue/upcoming views, centralized unpaid obligation totals for
/// [MoneyController]/[SafeToSpendCalculator], non-duplicating recurring bill
/// updates, and immediate cache clearing on logout.
class BillController extends ChangeNotifier {
  BillController({
    required this.repository,
    DateTime Function()? clock,
    String? initialUserId,
    SupportedCurrency initialCurrency = SupportedCurrency.php,
  }) : _clock = clock ?? DateTime.now,
       _activeUserId = initialUserId,
       _activeCurrency = initialCurrency;

  final BillRepository repository;
  final DateTime Function() _clock;

  String? _activeUserId;
  SupportedCurrency _activeCurrency;
  int _userEpoch = 0;

  BillLoadStatus _loadStatus = BillLoadStatus.idle;
  bool _isMutating = false;
  String? _errorMessage;

  final List<BillItem> _bills = <BillItem>[];
  BillFilterView _selectedView = BillFilterView.unpaid;
  BillCategory? _selectedCategory;
  String _searchQuery = '';

  String? get activeUserId => _activeUserId;
  SupportedCurrency get activeCurrency => _activeCurrency;
  BillLoadStatus get loadStatus => _loadStatus;
  bool get isLoading => _loadStatus == BillLoadStatus.loading;
  bool get hasLoadError => _loadStatus == BillLoadStatus.error;
  bool get isMutating => _isMutating;
  String? get errorMessage => _errorMessage;

  BillFilterView get selectedView => _selectedView;
  BillCategory? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  KayaDateOnly get referenceToday => KayaDateOnly.fromDateTime(_clock());

  List<BillItem> get allBills {
    final List<BillItem> copy = List<BillItem>.from(_bills);
    copy.sort(
      (BillItem a, BillItem b) =>
          BillItem.compareByUrgency(a, b, referenceToday),
    );
    return List<BillItem>.unmodifiable(copy);
  }

  List<BillItem> get unpaidBills =>
      allBills.where((BillItem b) => !b.isPaid).toList(growable: false);

  List<BillItem> get overdueBills => allBills
      .where((BillItem b) => b.isOverdue(referenceToday))
      .toList(growable: false);

  List<BillItem> get dueTodayBills => allBills
      .where((BillItem b) => b.isDueToday(referenceToday))
      .toList(growable: false);

  List<BillItem> get upcomingBills => allBills
      .where((BillItem b) => b.isUpcoming(referenceToday))
      .toList(growable: false);

  List<BillItem> get paidBills =>
      allBills.where((BillItem b) => b.isPaid).toList(growable: false);

  /// Unpaid bills that are overdue or due today for Today Priority integration.
  List<BillItem> get todayPriorityBills {
    final KayaDateOnly today = referenceToday;
    return allBills
        .where((BillItem b) => b.isOverdue(today) || b.isDueToday(today))
        .toList(growable: false);
  }

  /// Total unpaid obligation minor units in [currency] due in or before the
  /// specified `(year, month)`.
  ///
  /// Paid bills are strictly excluded, and future-month recurring cycles do
  /// not deduct from the current month's Safe to Spend.
  int unpaidObligationsMinorForPeriod({
    required int year,
    required int month,
    required SupportedCurrency currency,
  }) {
    int totalMinor = 0;
    for (final BillItem bill in _bills) {
      if (bill.isPaid || bill.currency != currency) {
        continue;
      }
      final bool isDueInOrBeforePeriod =
          bill.dueDate.year < year ||
          (bill.dueDate.year == year && bill.dueDate.month <= month);
      if (isDueInOrBeforePeriod) {
        totalMinor += bill.amountMinor;
      }
    }
    return totalMinor;
  }

  /// Total unpaid minor units across all unpaid bills in [_activeCurrency].
  int get totalUnpaidInActiveCurrencyMinor {
    int sum = 0;
    for (final BillItem bill in unpaidBills) {
      if (bill.currency == _activeCurrency) {
        sum += bill.amountMinor;
      }
    }
    return sum;
  }

  List<BillItem> get filteredBills {
    final KayaDateOnly today = referenceToday;
    final String normalizedSearch = _searchQuery.trim().toLowerCase();

    return allBills
        .where((BillItem bill) {
          final bool matchesView = switch (_selectedView) {
            BillFilterView.unpaid => !bill.isPaid,
            BillFilterView.overdue => bill.isOverdue(today),
            BillFilterView.upcoming => bill.isUpcoming(today),
            BillFilterView.paid => bill.isPaid,
            BillFilterView.all => true,
          };
          if (!matchesView) {
            return false;
          }
          if (_selectedCategory != null && bill.category != _selectedCategory) {
            return false;
          }
          if (normalizedSearch.isNotEmpty) {
            final bool inTitle = bill.title.toLowerCase().contains(
              normalizedSearch,
            );
            final bool inNotes = bill.notes.toLowerCase().contains(
              normalizedSearch,
            );
            final bool inCategory = bill.category.label.toLowerCase().contains(
              normalizedSearch,
            );
            if (!inTitle && !inNotes && !inCategory) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> bindAuthenticatedUser(
    String? userId, {
    SupportedCurrency? preferredCurrency,
  }) async {
    final String? normalized = (userId?.trim().isEmpty ?? true)
        ? null
        : userId!.trim();
    if (_activeUserId == normalized && _loadStatus != BillLoadStatus.idle) {
      if (preferredCurrency != null && preferredCurrency != _activeCurrency) {
        _activeCurrency = preferredCurrency;
        notifyListeners();
      }
      return;
    }

    _userEpoch++;
    _activeUserId = normalized;
    if (preferredCurrency != null) {
      _activeCurrency = preferredCurrency;
    }
    _clearPrivateCaches();

    if (normalized == null) {
      _loadStatus = BillLoadStatus.idle;
      notifyListeners();
      return;
    }

    await loadBills();
  }

  void setFilterView(BillFilterView view) {
    if (_selectedView != view) {
      _selectedView = view;
      notifyListeners();
    }
  }

  void setCategoryFilter(BillCategory? category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  void clearFilters() {
    _selectedView = BillFilterView.unpaid;
    _selectedCategory = null;
    _searchQuery = '';
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> loadBills() async {
    final String? uid = _activeUserId;
    if (uid == null) {
      _clearPrivateCaches();
      _loadStatus = BillLoadStatus.idle;
      notifyListeners();
      return;
    }

    final int requestEpoch = ++_userEpoch;
    _loadStatus = BillLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<BillItem> loaded = await repository.fetchBills(
        authenticatedUserId: uid,
      );
      if (requestEpoch != _userEpoch) {
        return;
      }
      _bills
        ..clear()
        ..addAll(loaded);
      _loadStatus = BillLoadStatus.loaded;
    } on AuthFailure catch (failure) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = failure.message;
      _loadStatus = BillLoadStatus.error;
    } catch (_) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage =
          'Unable to load bills. Please check your connection and try again.';
      _loadStatus = BillLoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> createBill({
    required String title,
    String notes = '',
    BillCategory category = BillCategory.utilities,
    required int amountMinor,
    required KayaDateOnly dueDate,
    BillRecurrence recurrence = BillRecurrence.oneTime,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final BillItem created = await repository.createBill(
        authenticatedUserId: uid,
        title: title,
        notes: notes,
        category: category,
        amountMinor: amountMinor,
        currency: _activeCurrency,
        dueDate: dueDate,
        recurrence: recurrence,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _bills.add(created);
      _loadStatus = BillLoadStatus.loaded;
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to create bill. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateBill({
    required String billId,
    required String title,
    required String notes,
    required BillCategory category,
    required int amountMinor,
    required SupportedCurrency currency,
    required KayaDateOnly dueDate,
    required BillRecurrence recurrence,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final BillItem updated = await repository.updateBill(
        authenticatedUserId: uid,
        billId: billId,
        title: title,
        notes: notes,
        category: category,
        amountMinor: amountMinor,
        currency: currency,
        dueDate: dueDate,
        recurrence: recurrence,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _bills.indexWhere((BillItem b) => b.id == billId);
      if (idx != -1) {
        _bills[idx] = updated;
      }
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to update bill. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<BillStatusUpdateResult?> setBillPaid({
    required String billId,
    required bool isPaid,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return null;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final BillStatusUpdateResult result = await repository.setBillPaid(
        authenticatedUserId: uid,
        billId: billId,
        isPaid: isPaid,
      );
      if (requestEpoch != _userEpoch) {
        return null;
      }
      final int idx = _bills.indexWhere((BillItem b) => b.id == billId);
      if (idx != -1) {
        _bills[idx] = result.updatedBill;
      }
      final BillItem? nextBill = result.spawnedNextBill;
      if (nextBill != null &&
          !_bills.any((BillItem b) => b.id == nextBill.id)) {
        _bills.add(nextBill);
      }
      _isMutating = false;
      notifyListeners();
      return result;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return null;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to update bill status. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return null;
    }
  }

  Future<bool> deleteBill(String billId) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteBill(authenticatedUserId: uid, billId: billId);
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _bills.removeWhere((BillItem b) => b.id == billId);
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to delete bill. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  void _clearPrivateCaches() {
    _bills.clear();
    _selectedView = BillFilterView.unpaid;
    _selectedCategory = null;
    _searchQuery = '';
    _errorMessage = null;
    _isMutating = false;
  }
}
