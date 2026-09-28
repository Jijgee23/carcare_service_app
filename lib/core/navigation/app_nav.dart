import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/keys/keys.dart';

/// Builds a page opened by name with [AppNav.toNamed]. The page is
/// full-screen, on the root navigator, so [context] reaches the app-level
/// providers only — not the shell's (`OrderController`,
/// `WorkingBranchController`, ...).
typedef AppPageBuilder = Widget Function(
  BuildContext context,
  Object? arguments,
);

/// The app's one navigation API, built on GetX: pages, bottom sheets and
/// dialogs open and close without a [BuildContext] (`AppNav.to(Page())`,
/// `AppNav.back(result)`, `AppNav.sheet(...)`), the way the timetry app uses
/// `Get.to` / `Get.back` / `Get.bottomSheet`.
///
/// Named pages are GetX-style too: [addPages] registers a builder per name
/// and [toNamed] opens one full-screen with its arguments
/// (`AppNav.toNamed(AppPages.orderDetail, arguments: order.id)`).
///
/// go_router still owns the URL routes — deep links, the auth redirect and
/// the bottom-nav tabs — so [push]/[go] go through it.
///
/// Every tab has its own navigator, registered with GetX as a nested key
/// ([tabKey]). [to] and [back] act on the navigator that is on top, exactly
/// like `Navigator.of(context)` did: the root navigator while anything sits
/// above the shell on it (a sheet, a dialog, a full-screen route such as
/// `/customers`), otherwise the current tab — so a page opened from a tab
/// stays inside it, under the bottom navigation and the shell's providers.
abstract final class AppNav {
  /// The bottom-nav tab on screen. `AppShell` keeps it current; null while
  /// the shell is not showing its tabs.
  static int? currentTab;

  /// Called once per router (`buildRouter`, or a test's own router).
  static void attach(GoRouter router) {
    GlobalKeys.router = router;
    Get.addKey(router.routerDelegate.navigatorKey);
    Get.isLogEnable = false;
  }

  /// The navigator key for bottom-nav tab [tab], shared with its
  /// `StatefulShellBranch`.
  static GlobalKey<NavigatorState> tabKey(int tab) => Get.nestedKey(tab)!;

  /// GetX navigator id of the navigator on top: null means the root.
  static int? get _topId {
    if (Get.key.currentState?.canPop() ?? false) return null;
    final tab = currentTab;
    if (tab == null || Get.keys[tab]?.currentState == null) return null;
    return tab;
  }

  // ─── Pages ────────────────────────────────────────────────────────────────

  /// [name] becomes the route's `settings.name` (GetX adds a leading `/`).
  static Future<T?> to<T>(
    Widget page, {
    String? name,
    bool fullscreenDialog = false,
  }) => _push<T>(
    () => page,
    id: _topId,
    name: name ?? '/${page.runtimeType}',
    fullscreenDialog: fullscreenDialog,
  );

  /// Opens the page registered as [name] (see [addPages]), handing its
  /// builder [arguments] — `Get.toNamed`. The route's `settings` carry both,
  /// so `ModalRoute.of(context)!.settings.arguments` reads them too.
  ///
  /// Unlike [to], it always opens full-screen on the root navigator, above
  /// the tabs and their bottom navigation; pages it opens in turn stack
  /// above it.
  static Future<T?> toNamed<T>(String name, {Object? arguments}) {
    final builder =
        _pages[name] ??
        (throw ArgumentError.value(name, 'name', 'No page registered'));
    return _push<T>(
      () => Builder(builder: (context) => builder(context, arguments)),
      id: null,
      name: name,
      arguments: arguments,
    );
  }

  /// Registers named pages for [toNamed]; a name already there is replaced.
  static void addPages(Map<String, AppPageBuilder> pages) =>
      _pages.addAll(pages);

  static final _pages = <String, AppPageBuilder>{};

  static Future<T?> _push<T>(
    GetPageBuilder page, {
    required int? id,
    required String name,
    Object? arguments,
    bool fullscreenDialog = false,
  }) {
    return Get.to<T>(
          page,
          id: id,
          routeName: name,
          arguments: arguments,
          // GetX tracks the current route name only on navigators it owns;
          // on the tab navigators it would wrongly swallow a push.
          preventDuplicates: false,
          transition: Transition.native,
          fullscreenDialog: fullscreenDialog,
        ) ??
        Future<T?>.value();
  }

  /// Pushes [page] and removes the routes below it until [predicate] holds —
  /// `Navigator.pushAndRemoveUntil`.
  static Future<T?> offUntil<T>(Widget page, RoutePredicate predicate) {
    return Get.offAll<T>(
          () => page,
          predicate: predicate,
          id: _topId,
          routeName: '/${page.runtimeType}',
          opaque: true,
          transition: Transition.native,
        ) ??
        Future<T?>.value();
  }

  /// Closes whatever is on top — a sheet, a dialog or a page — handing
  /// [result] to whoever awaited it.
  static void back<T>([T? result]) => Get.back<T>(result: result, id: _topId);

  /// Pops the navigator on top until [predicate] holds — `Navigator.popUntil`.
  static void until(RoutePredicate predicate) =>
      Get.until(predicate, id: _topId);

  /// Pushes a go_router location onto its own navigator (its tab, or the
  /// root for full-screen routes).
  static Future<T?> push<T>(String location) => _router.push<T>(location);

  /// Replaces the whole stack with a go_router location — including the
  /// pages, sheets and dialogs GetX opened on the root navigator, which
  /// go_router would leave on top of the new location.
  static void go(String location) {
    Get.key.currentState?.popUntil((route) => route.settings is Page);
    _router.go(location);
  }

  static GoRouter get _router =>
      GlobalKeys.router ?? (throw StateError('AppNav.attach was not called'));

  // ─── Sheets and dialogs ───────────────────────────────────────────────────

  /// Every bottom sheet is as tall as its content, up to the full height
  /// below the status bar; taller content scrolls. So sheet content lays out
  /// with `MainAxisSize.min` — header, a `Flexible` scrolling body (lists
  /// `shrinkWrap`), then the actions.
  ///
  /// [backgroundColor] `Colors.transparent` is for sheets that paint their
  /// own rounded surface; null gives the theme's sheet surface.
  static Future<T?> sheet<T>(
    Widget sheet, {
    Color? backgroundColor,
    bool showDragHandle = false,
  }) {
    final theme = Theme.of(Get.context!);
    final sheetTheme = theme.bottomSheetTheme;
    return Get.bottomSheet<T>(
      _SheetFrame(
        background:
            backgroundColor ??
            sheetTheme.modalBackgroundColor ??
            sheetTheme.backgroundColor ??
            theme.colorScheme.surfaceContainerLow,
        showDragHandle: showDragHandle,
        child: sheet,
      ),
      isScrollControlled: true,
      // Keep the status-bar inset visible to [_SheetFrame]; it stops the
      // sheet below the status bar itself.
      ignoreSafeArea: false,
      // [_SheetFrame] paints the surface, below the status bar.
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  static Future<T?> dialog<T>(
    Widget dialog, {
    bool barrierDismissible = true,
  }) => Get.dialog<T>(dialog, barrierDismissible: barrierDismissible);

  static Future<T?> generalDialog<T>({
    required RoutePageBuilder pageBuilder,
    bool barrierDismissible = false,
    String? barrierLabel,
    Color barrierColor = const Color(0x80000000),
    Duration transitionDuration = const Duration(milliseconds: 200),
    RouteTransitionsBuilder? transitionBuilder,
  }) => Get.generalDialog<T>(
    pageBuilder: pageBuilder,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: barrierColor,
    transitionDuration: transitionDuration,
    transitionBuilder: transitionBuilder,
  );
}

/// Frame for [AppNav.sheet]. GetX's sheet route lifts the sheet above the
/// keyboard itself and leaves the status bar to its content, so this caps
/// the sheet below the status bar and hides the keyboard inset from the
/// content (sheets pad for it themselves, which would count it twice).
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.background,
    required this.showDragHandle,
    required this.child,
  });

  final Color background;
  final bool showDragHandle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    Widget content = MediaQuery(
      data: media
          .removeViewInsets(removeBottom: true)
          // Above the keyboard the home indicator is covered anyway.
          .removePadding(removeTop: true, removeBottom: keyboardOpen),
      child: child,
    );
    if (showDragHandle) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          Flexible(child: content),
        ],
      );
    }
    if (background.a > 0) {
      content = Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXL),
          ),
        ),
        child: content,
      );
    }
    // Content-sized, capped below the status bar. A cap rather than top
    // padding, so a short sheet has no dead strip above it.
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (constraints.maxHeight - media.padding.top).clamp(
            0.0,
            double.infinity,
          ),
        ),
        child: content,
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
