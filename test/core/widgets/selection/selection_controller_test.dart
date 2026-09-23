import 'package:carcare_service/core/widgets/selection/selection_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelectionController — flat list mode', () {
    test('starts empty and inactive', () {
      final c = SelectionController<String>();
      expect(c.isActive, isFalse);
      expect(c.isEmpty, isTrue);
      expect(c.count, 0);
    });

    test('toggle enters selection mode implicitly and notifies', () {
      final c = SelectionController<String>();
      var notified = 0;
      c.addListener(() => notified++);

      c.toggle('a');
      expect(c.isActive, isTrue);
      expect(c.isSelected('a'), isTrue);
      expect(c.count, 1);
      expect(notified, 1);

      c.toggle('a');
      expect(c.isSelected('a'), isFalse);
      expect(c.isEmpty, isTrue);
      // Deselecting the last item does NOT leave selection mode — clear()
      // is the explicit exit.
      expect(c.isActive, isTrue);
      expect(notified, 2);
    });

    test('enter() activates without selecting anything', () {
      final c = SelectionController<String>();
      c.enter();
      expect(c.isActive, isTrue);
      expect(c.isEmpty, isTrue);
    });

    test(
      'selectAllVisible selects, then a repeat call deselects the same set',
      () {
        final c = SelectionController<String>();
        c.selectAllVisible(['a', 'b', 'c']);
        expect(c.selected, {'a', 'b', 'c'});
        expect(c.isAllSelected(['a', 'b', 'c']), isTrue);
        expect(c.isIndeterminate(['a', 'b', 'c']), isFalse);

        c.selectAllVisible(['a', 'b', 'c']);
        expect(c.isEmpty, isTrue);
      },
    );

    test('selectAllVisible ignores an empty visible list', () {
      final c = SelectionController<String>();
      c.selectAllVisible(const []);
      expect(c.isActive, isFalse);
    });

    test(
      'indeterminate is true for a partial selection of the visible set',
      () {
        final c = SelectionController<String>();
        c.toggle('a');
        expect(c.isIndeterminate(['a', 'b', 'c']), isTrue);
        expect(c.isAllSelected(['a', 'b', 'c']), isFalse);
      },
    );

    test(
      'selection outside the visible set survives a partial selectAllVisible',
      () {
        final c = SelectionController<String>();
        c.toggle('outside');
        c.selectAllVisible(['a', 'b']);
        expect(c.selected, {'outside', 'a', 'b'});
        // Now every visible id is selected — a repeat call clears only those,
        // leaving the id outside the visible set untouched.
        c.selectAllVisible(['a', 'b']);
        expect(c.selected, {'outside'});
      },
    );

    test('clear empties the selection and exits selection mode', () {
      final c = SelectionController<String>();
      c.toggle('a');
      c.toggle('b');
      c.clear();
      expect(c.isEmpty, isTrue);
      expect(c.isActive, isFalse);
    });

    test('clear() is a no-op (no notify) when already empty and inactive', () {
      final c = SelectionController<String>();
      var notified = 0;
      c.addListener(() => notified++);
      c.clear();
      expect(notified, 0);
    });

    test('pruneMissing drops stale ids without exiting selection mode', () {
      final c = SelectionController<String>();
      c.toggle('a');
      c.toggle('b');
      c.pruneMissing(['a']);
      expect(c.selected, {'a'});
      expect(c.isActive, isTrue);
    });

    test('pruneMissing does not notify when nothing changes', () {
      final c = SelectionController<String>();
      c.toggle('a');
      var notified = 0;
      c.addListener(() => notified++);
      c.pruneMissing(['a', 'b']);
      expect(notified, 0);
    });
  });

  group('SelectionController — range extension point', () {
    test(
      'beginRange/extendRange/endRange commits the preview into selected',
      () {
        final c = SelectionController<String>();
        c.beginRange('r1');
        expect(c.isRangeActive, isTrue);
        expect(c.rangeAnchor, 'r1');
        expect(c.rangePreview, {'r1'});

        c.extendRange(['r1', 'r2', 'r3']);
        expect(c.rangePreview, {'r1', 'r2', 'r3'});
        // Not yet committed to the real selection.
        expect(c.selected, isEmpty);

        c.endRange();
        expect(c.selected, {'r1', 'r2', 'r3'});
        expect(c.isRangeActive, isFalse);
        expect(c.isActive, isTrue);
      },
    );

    test('cancelRange discards the preview and pre-existing selection is untouched', () {
      final c = SelectionController<String>();
      c.toggle('pre-existing');
      c.beginRange('r1');
      c.extendRange(['r1', 'r2']);
      c.cancelRange();
      expect(c.isRangeActive, isFalse);
      expect(c.selected, {'pre-existing'});
    });

    test('endRange composes with (adds to) a pre-existing selection', () {
      final c = SelectionController<String>();
      c.toggle('pre-existing');
      c.beginRange('r1');
      c.extendRange(['r1', 'r2']);
      c.endRange();
      expect(c.selected, {'pre-existing', 'r1', 'r2'});
    });

    test('extendRange/endRange are no-ops outside an active range', () {
      final c = SelectionController<String>();
      c.extendRange(['x']);
      expect(c.rangePreview, isEmpty);
      c.endRange();
      expect(c.selected, isEmpty);
    });
  });
}
