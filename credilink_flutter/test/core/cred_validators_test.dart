import 'package:credilink_flutter/core/utils/cred_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CredValidators.email', () {
    test('requires a value when required', () {
      expect(CredValidators.email(null), 'Enter your email');
      expect(CredValidators.email('  '), 'Enter your email');
    });

    test('allows empty when not required', () {
      expect(CredValidators.email('', required: false), isNull);
    });

    test('rejects invalid addresses', () {
      expect(CredValidators.email('not-an-email'), 'Enter a valid email');
      expect(CredValidators.email('a@b'), 'Enter a valid email');
    });

    test('accepts a valid address', () {
      expect(CredValidators.email('owner@store.com'), isNull);
    });
  });

  group('CredValidators.password', () {
    test('requires a value and does not enforce length', () {
      expect(CredValidators.password(null), 'Enter your password');
      expect(CredValidators.password(''), 'Enter your password');
      expect(CredValidators.password('12345'), isNull);
    });
  });

  group('CredValidators.newPassword', () {
    test('enforces min length for new passwords', () {
      expect(CredValidators.newPassword(null), 'Use at least 6 characters');
      expect(CredValidators.newPassword(''), 'Use at least 6 characters');
      expect(CredValidators.newPassword('12345'), 'Use at least 6 characters');
      expect(CredValidators.newPassword('123456'), isNull);
    });
  });

  group('CredValidators.confirmPassword', () {
    test('matches the original password', () {
      expect(CredValidators.confirmPassword('secret1', 'secret1'), isNull);
      expect(CredValidators.confirmPassword('other', 'secret1'), "Passwords don't match");
      expect(CredValidators.confirmPassword('', 'secret1'), 'Confirm your password');
    });
  });

  group('CredValidators.phPhone', () {
    test('allows empty when optional', () {
      expect(CredValidators.phPhone(null), isNull);
      expect(CredValidators.phPhone(''), isNull);
    });

    test('requires a value when required', () {
      expect(CredValidators.phPhone('', required: true), 'Enter your phone number');
    });

    test('accepts PH mobile formats', () {
      expect(CredValidators.phPhone('09171234567'), isNull);
      expect(CredValidators.phPhone('+639171234567'), isNull);
      expect(CredValidators.phPhone('639171234567'), isNull);
      expect(CredValidators.phPhone('0917 123 4567'), isNull);
    });

    test('rejects invalid numbers', () {
      expect(CredValidators.phPhone('12345'), 'Enter a valid phone number');
      expect(CredValidators.phPhone('08171234567'), 'Enter a valid phone number');
    });
  });

  group('CredValidators.required', () {
    test('rejects blank values', () {
      expect(CredValidators.required(null), 'Enter this field');
      expect(CredValidators.required('  '), 'Enter this field');
      expect(CredValidators.required('ok'), isNull);
      expect(CredValidators.required('', message: 'Enter your username'), 'Enter your username');
    });
  });
}
