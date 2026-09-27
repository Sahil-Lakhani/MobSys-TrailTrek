import 'package:claimtrek/location/location_access.dart';
import 'package:claimtrek/ui/tracking/location_access_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('noticeFor', () {
    test('says nothing at all once location is granted', () {
      expect(noticeFor(LocationAccess.granted).message, isEmpty);
    });

    test('every unavailable state explains itself', () {
      for (final access in LocationAccess.values) {
        if (access == LocationAccess.granted) continue;
        expect(
          noticeFor(access).message,
          isNotEmpty,
          reason: '$access must tell the user what is wrong',
        );
      }
    });

    test('offers a retry only where asking again can actually work', () {
      expect(noticeFor(LocationAccess.denied).label, 'Allow location');
      expect(noticeFor(LocationAccess.notRequested).label, 'Allow location');
    });

    test('sends a permanent refusal to app settings', () {
      expect(
        noticeFor(LocationAccess.deniedForever).label,
        'Open app settings',
      );
    });

    test('sends a disabled location service to the system settings instead', () {
      expect(
        noticeFor(LocationAccess.servicesDisabled).label,
        'Open location settings',
      );
    });

    test('offers no button while the system dialogue is already up', () {
      expect(noticeFor(LocationAccess.requesting).label, isEmpty);
    });
  });
}
