/// Transaction direction for actual financial entries in KAYA Phase 4.
enum TransactionType {
  income(dbValue: 'income', label: 'Income', shortLabel: 'In'),
  expense(dbValue: 'expense', label: 'Expense', shortLabel: 'Out');

  const TransactionType({
    required this.dbValue,
    required this.label,
    required this.shortLabel,
  });

  final String dbValue;
  final String label;
  final String shortLabel;

  static TransactionType? tryFromDbValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.trim().toLowerCase();
    for (final TransactionType value in TransactionType.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// Supported income and expense categories matching PostgreSQL CHECK constraints.
enum MoneyCategory {
  salary(
    dbValue: 'salary',
    label: 'Salary & Payroll',
    transactionType: TransactionType.income,
  ),
  freelance(
    dbValue: 'freelance',
    label: 'Freelance & Side Income',
    transactionType: TransactionType.income,
  ),
  business(
    dbValue: 'business',
    label: 'Business Income',
    transactionType: TransactionType.income,
  ),
  investment(
    dbValue: 'investment',
    label: 'Investments & Dividends',
    transactionType: TransactionType.income,
  ),
  gift(
    dbValue: 'gift',
    label: 'Gift & Allowance',
    transactionType: TransactionType.income,
  ),
  otherIncome(
    dbValue: 'other_income',
    label: 'Other Income',
    transactionType: TransactionType.income,
  ),
  food(
    dbValue: 'food',
    label: 'Food & Dining',
    transactionType: TransactionType.expense,
  ),
  housing(
    dbValue: 'housing',
    label: 'Housing & Rent',
    transactionType: TransactionType.expense,
  ),
  utilities(
    dbValue: 'utilities',
    label: 'Utilities & Bills',
    transactionType: TransactionType.expense,
  ),
  transport(
    dbValue: 'transport',
    label: 'Transport & Fuel',
    transactionType: TransactionType.expense,
  ),
  healthcare(
    dbValue: 'healthcare',
    label: 'Healthcare & Wellness',
    transactionType: TransactionType.expense,
  ),
  shopping(
    dbValue: 'shopping',
    label: 'Shopping & Personal',
    transactionType: TransactionType.expense,
  ),
  entertainment(
    dbValue: 'entertainment',
    label: 'Entertainment & Leisure',
    transactionType: TransactionType.expense,
  ),
  education(
    dbValue: 'education',
    label: 'Education & Growth',
    transactionType: TransactionType.expense,
  ),
  savings(
    dbValue: 'savings',
    label: 'Savings & Emergency Fund',
    transactionType: TransactionType.expense,
  ),
  otherExpense(
    dbValue: 'other_expense',
    label: 'Other Expense',
    transactionType: TransactionType.expense,
  );

  const MoneyCategory({
    required this.dbValue,
    required this.label,
    required this.transactionType,
  });

  final String dbValue;
  final String label;
  final TransactionType transactionType;

  bool get isIncomeCategory => transactionType == TransactionType.income;
  bool get isExpenseCategory => transactionType == TransactionType.expense;

  static List<MoneyCategory> forType(TransactionType type) {
    return MoneyCategory.values
        .where((MoneyCategory c) => c.transactionType == type)
        .toList(growable: false);
  }

  static MoneyCategory defaultForType(TransactionType type) {
    return type == TransactionType.income
        ? MoneyCategory.salary
        : MoneyCategory.food;
  }

  static MoneyCategory? tryFromDbValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.trim().toLowerCase();
    for (final MoneyCategory value in MoneyCategory.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// Filter tabs in the Money transactions list.
enum TransactionFilterType {
  all(label: 'All'),
  income(label: 'Income'),
  expense(label: 'Expenses');

  const TransactionFilterType({required this.label});

  final String label;
}
