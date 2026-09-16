import 'package:claimtrek/location/location_access.dart';
import 'package:claimtrek/ui/tracking/location_access_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('noticeFor', () {
    test('says nothing at all once location is granted', () {
      expect(noticeFor(LocationAccess.granted).message, isEmpty);
    });

    test('every unavailable state explains itself', () {
      // A blank grey map with no explanation is the failure this exists to prevent.
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
      // Offering "try again" to someone who chose "don't ask again" is a button that does
      // nothing, and the platform will not show the dialogue a second time.
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
      // App settings cannot turn the phone's own location switch back on, so pointing there
      // would be a dead end.
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
