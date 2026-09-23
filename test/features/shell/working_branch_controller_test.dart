import 'dart:async';

import 'package:carcare_service/core/network/working_branch_interceptor.dart';
import 'package:carcare_service/core/domain/working_branch_scope.dart';
import 'package:carcare_service/features/shell/domain/working_branch.dart';
import 'package:carcare_service/features/shell/presentation/controllers/working_branch_controller.dart';
import 'package:carcare_service/features/shell/presentation/widgets/working_branch_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements WorkingBranchSelectionStore {
  String? value;
  int writes = 0;

  _MemoryStore([this.value]);

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? selection) async {
    value = selection;
    writes++;
  }

  @override
  Future<void> clear() => write(null);
}

class _FakeRepository implements WorkingBranchRepository {
  WorkingBranchOptions options;
  _FakeRepository(this.options);

  @override
  Future<WorkingBranchOptions> fetchOptions() async => options;
}

class _QueuedRepository implements WorkingBranchRepository {
  final queue = <Completer<WorkingBranchOptions>>[];

  @override
  Future<WorkingBranchOptions> fetchOptions() {
    final completer = Completer<WorkingBranchOptions>();
    queue.add(completer);
    return completer.future;
  }
}

WorkingBranchOptions options({bool allowAll = false, String? locked}) =>
    WorkingBranchOptions(
      branches: const [
        SwitchableBranch(id: 'branch-a', name: 'A'),
        SwitchableBranch(id: 'branch-b', name: 'B'),
      ],
      allowAll: allowAll,
      lockedBranchId: locked,
    );

void main() {
  test('defensively parses malformed branch payloads and flags', () {
    final parsed = WorkingBranchOptions.fromJson({
      'allowAll': true,
      'lockedBranchId': '  ',
      'branches': [
        {'id': ' a ', 'name': '  Alpha '},
        {'id': 'a', 'name': 'duplicate'},
        {'id': '', 'name': 'empty'},
        {'id': 42, 'name': 'wrong type'},
        null,
      ],
    });

    expect(parsed.allowAll, isTrue);
    expect(parsed.lockedBranchId, isNull);
    expect(parsed.branches.map((branch) => branch.id), ['a']);
    expect(parsed.branches.single.name, 'Alpha');
  });

  test(
    'reconciles invalid persisted selection to the server choices',
    () async {
      final store = _MemoryStore('removed-branch');
      final controller = WorkingBranchController(
        repository: _FakeRepository(options()),
        store: store,
        invalidationBus: WorkingBranchInvalidationBus(),
      );

      await controller.load();

      expect(controller.selection, isNull);
      expect(store.value, isNull);
      controller.dispose();
    },
  );

  test('locked branch forces the selection and rejects changes', () async {
    final store = _MemoryStore('branch-a');
    final controller = WorkingBranchController(
      repository: _FakeRepository(options(allowAll: true, locked: 'branch-b')),
      store: store,
      invalidationBus: WorkingBranchInvalidationBus(),
    );

    await controller.load();

    expect(controller.selection, 'branch-b');
    expect(store.value, 'branch-b');
    expect(await controller.selectAll(), isFalse);
    expect(await controller.selectBranch('branch-a'), isFalse);
    controller.dispose();
  });

  testWidgets('locked switcher disables its dropdown', (tester) async {
    final controller = WorkingBranchController(
      repository: _FakeRepository(options(locked: 'branch-b')),
      store: _MemoryStore('branch-b'),
      invalidationBus: WorkingBranchInvalidationBus(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkingBranchSwitcher(controller: controller)),
      ),
    );
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.onChanged, isNull);
    controller.dispose();
  });

  test('newer overlapping load wins over an older response', () async {
    final repository = _QueuedRepository();
    final controller = WorkingBranchController(
      repository: repository,
      store: _MemoryStore(),
      invalidationBus: WorkingBranchInvalidationBus(),
    );

    final first = controller.load();
    final second = controller.load();
    expect(repository.queue, hasLength(2));
    repository.queue[1].complete(options());
    await second;
    repository.queue[0].complete(
      WorkingBranchOptions(
        branches: const [SwitchableBranch(id: 'old', name: 'Old')],
        allowAll: false,
        lockedBranchId: null,
      ),
    );
    await first;

    expect(
      controller.options.branches.map((branch) => branch.id),
      contains('branch-a'),
    );
    controller.dispose();
  });
}
