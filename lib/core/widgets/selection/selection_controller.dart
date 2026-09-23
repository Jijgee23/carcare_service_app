import 'package:flutter/foundation.dart';

/// Generic multi-selection state for list/grid surfaces — new in P6-F2,
/// reusable by any feature that needs tap/long-press multi-select with a
/// bottom action bar. This slice drives it in flat list mode (Employees
/// bulk role/branch reassignment); a later slice (P6-F4) is expected to
/// drive the same controller in rectangular "range" mode over an
/// employee×day schedule grid — see the extension point at the bottom of
/// this file.
///
/// Ids are generic (`Id`) rather than a fixed `String` so a grid cell key
/// (e.g. a `(userId, date)` record/string) can reuse this controller
/// unmodified.
class SelectionController<Id> extends ChangeNotifier {
  SelectionController();

  final Set<Id> _selected = {};
  bool _active = false;

  /// The ids currently selected. A defensive copy — mutate only through
  /// this controller's methods so [notifyListeners] always fires on a
  /// change and callers can never desync the controller's own state.
  Set<Id> get selected => Set<Id>.of(_selected);

  /// Whether selection mode is active. A screen typically shows checkboxes
  /// and the bottom action bar only while this is true.
  bool get isActive => _active;

  int get count => _selected.length;

  bool get isEmpty => _selected.isEmpty;

  bool isSelected(Id id) => _selected.contains(id);

  /// Enters selection mode without selecting anything — e.g. an explicit
  /// "select" affordance. Long-press should instead call [toggle], which
  /// enters selection mode implicitly on its first call.
  void enter() {
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  /// Tap/long-press on one row. The first toggle also enters selection
  /// mode. Toggling the last selected id back off does **not** leave
  /// selection mode automatically — [clear] is the explicit exit, so a
  /// stray tap that empties the set does not silently drop the user back
  /// to the plain list mid-gesture.
  void toggle(Id id) {
    _active = true;
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  /// Select-all over the currently *visible* ids (a filtered/paginated
  /// screen must pass only what it renders — this controller never fetches
  /// or knows about pagination itself). Toggles: if every visible id is
  /// already selected this clears just those ids (a partial deselect of the
  /// visible set, leaving any selection outside it untouched); otherwise it
  /// adds all of them. [isAllSelected]/[isIndeterminate] read against the
  /// same `visibleIds` list a caller passes here.
  void selectAllVisible(Iterable<Id> visibleIds) {
    final ids = visibleIds.toList(growable: false);
    if (ids.isEmpty) return;
    _active = true;
    final allSelected = ids.every(_selected.contains);
    if (allSelected) {
      _selected.removeAll(ids);
    } else {
      _selected.addAll(ids);
    }
    notifyListeners();
  }

  bool isAllSelected(Iterable<Id> visibleIds) {
    final ids = visibleIds.toList(growable: false);
    return ids.isNotEmpty && ids.every(_selected.contains);
  }

  /// True when some but not all of [visibleIds] are selected — drives a
  /// tri-state "select all" checkbox's indeterminate visual.
  bool isIndeterminate(Iterable<Id> visibleIds) {
    final ids = visibleIds.toList(growable: false);
    if (ids.isEmpty) return false;
    final selectedCount = ids.where(_selected.contains).length;
    return selectedCount > 0 && selectedCount < ids.length;
  }

  /// Clears the selection and exits selection mode — the explicit exit
  /// point (bottom bar's close button, or after a bulk action completes).
  void clear() {
    if (_selected.isEmpty && !_active) return;
    _selected.clear();
    _active = false;
    notifyListeners();
  }

  /// Removes ids no longer present after a reload (e.g. a row was deleted
  /// or paged out) without otherwise disturbing the selection or exiting
  /// selection mode. Call after any full refresh with the fresh id set.
  void pruneMissing(Iterable<Id> stillPresent) {
    final present = stillPresent.toSet();
    final before = _selected.length;
    _selected.removeWhere((id) => !present.contains(id));
    if (_selected.length != before) notifyListeners();
  }

  // ─── Extension point: rectangular range selection ────────────────────────
  //
  // P6-F4 (the employee×day schedule grid) is expected to need a
  // "start cell → end cell" rectangular tap-tap mode layered on this same
  // controller, deliberately without a mouse-drag dependency (touch-first,
  // per the slice brief). The shape below is the intended extension point;
  // it is NOT wired to [toggle] above, and implementing the full gesture is
  // optional for this slice (P6-F2 only needs flat list multi-select). A
  // grid screen would drive it like this:
  //
  //   1. On the first tapped cell, call [beginRange] with that cell's id as
  //      the anchor.
  //   2. On each subsequent cell tap, call [extendRange] with the full
  //      ordered set of ids the grid enumerates between the anchor and the
  //      newly-tapped cell (the grid — not this controller — knows its own
  //      row/column geometry; this controller only ever holds a flat
  //      `Set<Id>` and has no notion of rows or columns).
  //   3. Call [endRange] to commit the preview into [selected], or
  //      [cancelRange] to discard it.
  //
  // This keeps [SelectionController] geometry-agnostic: it never computes
  // "which cells lie in the rectangle between two corners" itself, since
  // that math depends entirely on the grid's own coordinate system
  // (employee row order × date column order), which only the grid screen
  // knows. Cancelling a range never touches ids selected before
  // [beginRange] was called, and [endRange] adds to (rather than replaces)
  // any pre-existing selection, so range mode composes with plain
  // tap-to-toggle selection.

  Id? _rangeAnchor;
  Set<Id> _rangePreview = const {};

  /// The anchor cell of an in-progress range gesture, or `null` outside one.
  Id? get rangeAnchor => _rangeAnchor;

  /// The ids currently previewed by an in-progress range gesture (not yet
  /// committed to [selected]).
  Set<Id> get rangePreview => Set<Id>.of(_rangePreview);

  bool get isRangeActive => _rangeAnchor != null;

  void beginRange(Id anchor) {
    _rangeAnchor = anchor;
    _rangePreview = {anchor};
    notifyListeners();
  }

  /// [cellsBetween] is the full rectangle the caller computed between
  /// [rangeAnchor] and the newly-touched cell, inclusive of both ends.
  void extendRange(Iterable<Id> cellsBetween) {
    if (_rangeAnchor == null) return;
    _rangePreview = cellsBetween.toSet();
    notifyListeners();
  }

  /// Commits the current preview into [selected] and exits range mode.
  void endRange() {
    if (_rangeAnchor == null) return;
    _active = true;
    _selected.addAll(_rangePreview);
    _rangeAnchor = null;
    _rangePreview = const {};
    notifyListeners();
  }

  void cancelRange() {
    if (_rangeAnchor == null) return;
    _rangeAnchor = null;
    _rangePreview = const {};
    notifyListeners();
  }
}
