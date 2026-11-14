import 'package:booking_manager/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest names shorten sensibly for calendar bars', () {
    expect(shortName('Kavya Nair'), 'Kavya N.');
    expect(shortName('Mr Suraj Khanna'), 'Suraj K.');
    expect(shortName('Mr Pillai'), 'Pillai');
    expect(shortName('R V Singh'), 'R V Singh');
    expect(shortName('MM Khera'), 'MM Khera');
    expect(shortName('Shilpa/Dhruva'), 'Shilpa/Dhruva');
    expect(shortName('Mr'), 'Mr');
    expect(shortName(''), 'Guest');
    expect(firstName('Mr Suraj Khanna'), 'Suraj');
    expect(firstName('MM Khera'), 'Khera');
    expect(firstName('Ms Harsha Myatra'), 'Harsha');
    expect(initials('Siva Prasad'), 'SP');
    expect(initials('Mr Pillai'), 'P');
    expect(initials(''), '?');
  });
}
