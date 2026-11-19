import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/money_repository.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/domain/monthly_budget.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:material_ui/material_ui.dart';

/// Loading status for financial queries.
enum MoneyLoadStatus { idle, loading, loaded, error }

/// Application state controller for Phase 4 Money Management.
///
/// Enforces centralized calculations via [SafeToSpendCalculator], validates
/// inputs, enforces duplicate-submission locking, and wipes all cached records
/// on logout or account switch.
class MoneyController extends ChangeNotifier {
  MoneyController({
    required this.repository,
    DateTime Function()? clock,
    String? initialUserId,
    SupportedCurrency initialCurrency = SupportedCurrency.php,
  }) : _clock = clock ?? DateTime.now,
       _activeUserId = initialUserId,
       _activeCurrency = initialCurrency {
    final KayaDateOnly today = KayaDateOnly.fromDateTime(_clock());
    _selectedYear = today.year;
    _selectedMonth = today.month;
  }

  final MoneyRepository repository;
  final DateTime Function() _clock;

  String? _activeUserId;
  SupportedCurrency _activeCurrency;
  late int _selectedYear;
  late int _selectedMonth;
  int _userEpoch = 0;

  MoneyLoadStatus _loadStatus = MoneyLoadStatus.idle;
  bool _isMutating = false;
  String? _errorMessage;

  final List<MoneyTransaction> _transactions = <MoneyTransaction>[];
  final List<MonthlyBudget> _budgets = <MonthlyBudget>[];

  TransactionFilterType _selectedFilter = TransactionFilterType.all;
  MoneyCategory? _selectedCategory;
  String _searchQuery = '';

  PurchaseAffordabilityVerdict? _lastPurchaseVerdict;
  String? _purchaseValidationError;

  int Function(int year, int month, SupportedCurrency currency)?
  _unpaidObligationsResolver;
  Listenable? _unpaidObligationsListenable;

  String? get activeUserId => _activeUserId;
  SupportedCurrency get activeCurrency => _activeCurrency;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  MoneyLoadStatus get loadStatus => _loadStatus;
  bool get isLoading => _loadStatus == MoneyLoadStatus.loading;
  bool get hasLoadError => _loadStatus == MoneyLoadStatus.error;
  bool get isMutating => _isMutating;
  String? get errorMessage => _errorMessage;

  TransactionFilterType get selectedFilter => _selectedFilter;
  MoneyCategory? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  PurchaseAffordabilityVerdict? get lastPurchaseVerdict => _lastPurchaseVerdict;
  String? get purchaseValidationError => _purchaseValidationError;

  KayaDateOnly get referenceToday => KayaDateOnly.fromDateTime(_clock());

  String get selectedPeriodLabel {
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_selectedMonth - 1]} $_selectedYear';
  }

  MonthlyBudget? get activeMonthlyBudget {
    for (final MonthlyBudget b in _budgets) {
      if (b.year == _selectedYear &&
          b.month == _selectedMonth &&
          b.currency == _activeCurrency) {
        return b;
      }
    }
    return null;
  }

  /// Single authoritative monthly financial summary from [SafeToSpendCalculator].
  FinancialOverviewSummary calculateCurrentOverview({
    int unpaidObligationsMinor = 0,
  }) {
    return SafeToSpendCalculator.calculateOverview(
      transactions: _transactions,
      year: _selectedYear,
      month: _selectedMonth,
      currency: _activeCurrency,
      monthlyBudget: activeMonthlyBudget,
      unpaidObligationsMinor: unpaidObligationsMinor,
    );
  }

  FinancialOverviewSummary get currentOverview {
    final int obligationsMinor =
        _unpaidObligationsResolver?.call(
          _selectedYear,
          _selectedMonth,
          _activeCurrency,
        ) ??
        0;
    return calculateCurrentOverview(unpaidObligationsMinor: obligationsMinor);
  }

  /// Connects live unpaid bills totals from [BillController] into the
  /// centralized [SafeToSpendCalculator] overview without duplicating formulas.
  void bindUnpaidObligationsSource({
    required int Function(int year, int month, SupportedCurrency currency)
    resolver,
    Listenable? listenable,
  }) {
    _unpaidObligationsListenable?.removeListener(
      _handleUnpaidObligationsChanged,
    );
    _unpaidObligationsResolver = resolver;
    _unpaidObligationsListenable = listenable;
    listenable?.addListener(_handleUnpaidObligationsChanged);
    _refreshPurchaseVerdict();
    notifyListeners();
  }

  void _handleUnpaidObligationsChanged() {
    _refreshPurchaseVerdict();
    notifyListeners();
  }

  @override
  void dispose() {
    _unpaidObligationsListenable?.removeListener(
      _handleUnpaidObligationsChanged,
    );
    _unpaidObligationsListenable = null;
    super.dispose();
  }

  List<MoneyTransaction> get periodTransactions {
    final List<MoneyTransaction> matching =
        _transactions
            .where(
              (MoneyTransaction tx) =>
                  tx.currency == _activeCurrency &&
                  tx.transactionDate.year == _selectedYear &&
                  tx.transactionDate.month == _selectedMonth,
            )
            .toList()
          ..sort(MoneyTransaction.compareByDateDesc);
    return List<MoneyTransaction>.unmodifiable(matching);
  }

  List<MoneyTransaction> get filteredTransactions {
    final String normalizedSearch = _searchQuery.trim().toLowerCase();

    return periodTransactions
        .where((MoneyTransaction tx) {
          final bool matchesType = switch (_selectedFilter) {
            TransactionFilterType.all => true,
            TransactionFilterType.income => tx.type == TransactionType.income,
            TransactionFilterType.expense => tx.type == TransactionType.expense,
          };
          if (!matchesType) {
            return false;
          }
          if (_selectedCategory != null && tx.category != _selectedCategory) {
            return false;
          }
          if (normalizedSearch.isNotEmpty) {
            final bool inTitle = tx.title.toLowerCase().contains(
              normalizedSearch,
            );
            final bool inNotes = tx.notes.toLowerCase().contains(
              normalizedSearch,
            );
            final bool inCategory = tx.category.label.toLowerCase().contains(
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

  /// Binds the controller to the authenticated user and currency, clearing all
  /// private financial caches immediately on logout or account switch.
  Future<void> bindAuthenticatedUser(
    String? userId, {
    SupportedCurrency? preferredCurrency,
  }) async {
    final String? normalized = (userId?.trim().isEmpty ?? true)
        ? null
        : userId!.trim();

    if (_activeUserId == normalized && _loadStatus != MoneyLoadStatus.idle) {
      if (preferredCurrency != null && preferredCurrency != _activeCurrency) {
        _activeCurrency = preferredCurrency;
        _refreshPurchaseVerdict();
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
      _loadStatus = MoneyLoadStatus.idle;
      notifyListeners();
      return;
    }

    await loadMoneyData();
  }

  void setCurrency(SupportedCurrency currency) {
    if (_activeCurrency != currency) {
      _activeCurrency = currency;
      _refreshPurchaseVerdict();
      notifyListeners();
    }
  }

  void setFilterType(TransactionFilterType filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      notifyListeners();
    }
  }

  void setCategoryFilter(MoneyCategory? category) {
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
    _selectedFilter = TransactionFilterType.all;
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

  void clearPurchaseEvaluation() {
    if (_lastPurchaseVerdict != null || _purchaseValidationError != null) {
      _lastPurchaseVerdict = null;
      _purchaseValidationError = null;
      notifyListeners();
    }
  }

  /// Evaluates a hypothetical purchase using [SafeToSpendCalculator] without
  /// recording an actual expense transaction.
  PurchaseAffordabilityVerdict? evaluateCanIBuyThis({
    required String rawAmountInput,
    String itemLabel = '',
  }) {
    final String? validationError = MoneyValidators.validatePositiveAmountInput(
      rawAmountInput,
      _activeCurrency,
      fieldName: 'Planned purchase amount',
    );
    if (validationError != null) {
      _purchaseValidationError = validationError;
      _lastPurchaseVerdict = null;
      notifyListeners();
      return null;
    }

    final int plannedMinor = MoneyFormatter.tryParseMinorUnits(
      rawAmountInput,
      _activeCurrency,
    )!;
    final PurchaseAffordabilityVerdict verdict =
        SafeToSpendCalculator.evaluatePurchase(
          overview: currentOverview,
          plannedAmountMinor: plannedMinor,
          itemLabel: itemLabel,
        );
    _purchaseValidationError = null;
    _lastPurchaseVerdict = verdict;
    notifyListeners();
    return verdict;
  }

  Future<void> loadMoneyData() async {
    final String? uid = _activeUserId;
    if (uid == null) {
      _clearPrivateCaches();
      _loadStatus = MoneyLoadStatus.idle;
      notifyListeners();
      return;
    }

    final int requestEpoch = ++_userEpoch;
    _loadStatus = MoneyLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<MoneyTransaction> txs = await repository.fetchTransactions(
        authenticatedUserId: uid,
      );
      final List<MonthlyBudget> budgets = await repository.fetchMonthlyBudgets(
        authenticatedUserId: uid,
      );
      if (requestEpoch != _userEpoch) {
        return;
      }
      _transactions
        ..clear()
        ..addAll(txs);
      _budgets
        ..clear()
        ..addAll(budgets);
      _refreshPurchaseVerdict();
      _loadStatus = MoneyLoadStatus.loaded;
    } on AuthFailure catch (failure) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = failure.message;
      _loadStatus = MoneyLoadStatus.error;
    } catch (_) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = 'Unable to load financial records. Please check your connection and try again.';
      _loadStatus = MoneyLoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> createTransaction({
    required TransactionType type,
    required MoneyCategory category,
    required String title,
    String notes = '',
    required int amountMinor,
    required KayaDateOnly transactionDate,
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
      final MoneyTransaction created = await repository.createTransaction(
        authenticatedUserId: uid,
        type: type,
        category: category,
        title: title,
        notes: notes,
        amountMinor: amountMinor,
        currency: _activeCurrency,
        transactionDate: transactionDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _transactions.add(created);
      _loadStatus = MoneyLoadStatus.loaded;
      _refreshPurchaseVerdict();
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
        _errorMessage = 'Failed to save transaction. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateTransaction({
    required String transactionId,
    required TransactionType type,
    required MoneyCategory category,
    required String title,
    required String notes,
    required int amountMinor,
    required KayaDateOnly transactionDate,
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
      final MoneyTransaction updated = await repository.updateTransaction(
        authenticatedUserId: uid,
        transactionId: transactionId,
        type: type,
        category: category,
        title: title,
        notes: notes,
        amountMinor: amountMinor,
        currency: _activeCurrency,
        transactionDate: transactionDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _transactions.indexWhere(
        (MoneyTransaction tx) => tx.id == transactionId,
      );
      if (idx != -1) {
        _transactions[idx] = updated;
      }
      _refreshPurchaseVerdict();
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
        _errorMessage = 'Failed to update transaction. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteTransaction(
        authenticatedUserId: uid,
        transactionId: transactionId,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _transactions.removeWhere(
        (MoneyTransaction tx) => tx.id == transactionId,
      );
      _refreshPurchaseVerdict();
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
        _errorMessage = 'Failed to delete transaction. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> saveMonthlyBudget({required int overallLimitMinor}) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final MonthlyBudget saved = await repository.upsertMonthlyBudget(
        authenticatedUserId: uid,
        year: _selectedYear,
        month: _selectedMonth,
        currency: _activeCurrency,
        overallLimitMinor: overallLimitMinor,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _budgets.indexWhere(
        (MonthlyBudget b) =>
            b.year == saved.year &&
            b.month == saved.month &&
            b.currency == saved.currency,
      );
      if (idx != -1) {
        _budgets[idx] = saved;
      } else {
        _budgets.add(saved);
      }
      _loadStatus = MoneyLoadStatus.loaded;
      _refreshPurchaseVerdict();
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
        _errorMessage = 'Failed to save monthly budget. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  void _refreshPurchaseVerdict() {
    final PurchaseAffordabilityVerdict? prev = _lastPurchaseVerdict;
    if (prev == null) {
      return;
    }
    _lastPurchaseVerdict = SafeToSpendCalculator.evaluatePurchase(
      overview: currentOverview,
      plannedAmountMinor: prev.plannedAmountMinor,
      itemLabel: prev.itemLabel,
    );
  }

  void _clearPrivateCaches() {
    _transactions.clear();
    _budgets.clear();
    _selectedFilter = TransactionFilterType.all;
    _selectedCategory = null;
    _searchQuery = '';
    _lastPurchaseVerdict = null;
    _purchaseValidationError = null;
    _errorMessage = null;
    _isMutating = false;
  }
}
