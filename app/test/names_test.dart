import 'package:booking_manager/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest names shorten sensibly for calendar bars', () {
    expect(shortName('Kavya Nair'), 'Kavya N.');
    expect(shortName('Mr Arjun Mehta'), 'Arjun M.');
    expect(shortName('Mr Rao'), 'Rao');
    expect(shortName('K P Sharma'), 'K P Sharma');
    expect(shortName('MM Gill'), 'MM Gill');
    expect(shortName('Asha/Ravi'), 'Asha/Ravi');
    expect(shortName('Mr'), 'Mr');
    expect(shortName(''), 'Guest');
    expect(firstName('Mr Arjun Mehta'), 'Arjun');
    expect(firstName('MM Gill'), 'Gill');
    expect(firstName('Ms Lata Menon'), 'Lata');
    expect(initials('Gopal Das'), 'GD');
    expect(initials('Mr Rao'), 'R');
    expect(initials(''), '?');
  });
}
