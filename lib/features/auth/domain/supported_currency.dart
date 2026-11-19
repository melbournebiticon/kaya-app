/// Supported currencies for KAYA user profiles and financial tracking.
///
/// Includes `minorUnits` metadata in preparation for Phase 4's decimal-safe
/// integer minor-unit calculations.
enum SupportedCurrency {
  php(code: 'PHP', symbol: '₱', name: 'Philippine Peso', minorUnits: 2),
  usd(code: 'USD', symbol: r'$', name: 'US Dollar', minorUnits: 2),
  eur(code: 'EUR', symbol: '€', name: 'Euro', minorUnits: 2),
  sgd(code: 'SGD', symbol: r'S$', name: 'Singapore Dollar', minorUnits: 2),
  jpy(code: 'JPY', symbol: '¥', name: 'Japanese Yen', minorUnits: 0),
  aud(code: 'AUD', symbol: r'A$', name: 'Australian Dollar', minorUnits: 2),
  gbp(code: 'GBP', symbol: '£', name: 'British Pound', minorUnits: 2),
  cad(code: 'CAD', symbol: r'C$', name: 'Canadian Dollar', minorUnits: 2);

  const SupportedCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.minorUnits,
  });

  final String code;
  final String symbol;
  final String name;
  final int minorUnits;

  String get displayLabel => '$code ($symbol) — $name';

  static SupportedCurrency? tryFromCode(String? rawCode) {
    if (rawCode == null) {
      return null;
    }
    final String normalized = rawCode.trim().toUpperCase();
    for (final SupportedCurrency currency in SupportedCurrency.values) {
      if (currency.code == normalized) {
        return currency;
      }
    }
    return null;
  }
}
