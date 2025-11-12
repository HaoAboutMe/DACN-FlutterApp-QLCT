import 'package:flutter_test/flutter_test.dart';
import 'package:app_qlct/providers/currency_provider.dart';
import 'package:app_qlct/utils/currency_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Currency System Tests', () {
    test('CurrencyProvider initializes with VND as default', () async {
      final provider = CurrencyProvider();

      // Wait a moment for async initialization
      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.selectedCurrency, 'VND');
      expect(provider.currencySymbol, '₫');
      expect(provider.currencyName, 'VND (₫)');
    });

    test('CurrencyProvider can switch to USD', () async {
      final provider = CurrencyProvider();

      await provider.setCurrency('USD');

      expect(provider.selectedCurrency, 'USD');
      expect(provider.currencySymbol, '\$');
      expect(provider.currencyName, 'USD (\$)');
    });

    test('Currency conversion works correctly', () async {
      final provider = CurrencyProvider();

      // Test VND (should return same amount)
      double vndAmount = 1000000.0; // 1 million VND
      expect(provider.convertFromVND(vndAmount), vndAmount);
      expect(provider.convertToVND(vndAmount), vndAmount);

      // Switch to USD
      await provider.setCurrency('USD');

      // Test USD conversion (using fallback rate of 25,000)
      double convertedToUSD = provider.convertFromVND(vndAmount);
      expect(convertedToUSD, closeTo(40.0, 1)); // 1,000,000 / 25,000 = 40

      double convertedBackToVND = provider.convertToVND(convertedToUSD);
      expect(convertedBackToVND, closeTo(vndAmount, 1));
    });

    test('CurrencyFormatter works with provider', () async {
      final provider = CurrencyProvider();
      CurrencyFormatter.setCurrencyProvider(provider);

      double testAmount = 1000000.0; // 1 million VND

      // Test VND formatting
      String vndFormatted = CurrencyFormatter.formatAmount(testAmount);
      expect(vndFormatted, contains('₫'));
      expect(vndFormatted, contains('1.000.000'));

      // Switch to USD and test formatting
      await provider.setCurrency('USD');
      CurrencyFormatter.setCurrencyProvider(provider);

      String usdFormatted = CurrencyFormatter.formatAmount(testAmount);
      expect(usdFormatted, contains('\$'));
      // Should be around $40 (1,000,000 VND / 25,000 exchange rate)
      expect(usdFormatted, contains('40'));
    });

    test('Backward compatibility with formatVND still works', () {
      double testAmount = 1000000.0;
      String formatted = CurrencyFormatter.formatVND(testAmount);

      expect(formatted, contains('₫'));
      expect(formatted, contains('1.000.000'));
    });
  });
}
