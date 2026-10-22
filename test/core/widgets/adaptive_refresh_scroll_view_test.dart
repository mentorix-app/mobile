import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentorix_app/core/widgets/adaptive_refresh_scroll_view.dart';

void main() {
  late int refreshCalls;
  // Сливер индикатора в покое нулевой высоты, и `find` считает его невидимым:
  // ищем с `skipOffstage: false`.
  late Completer<void>? gate;

  setUp(() {
    refreshCalls = 0;
    gate = null;
  });

  Future<void> onRefresh() async {
    refreshCalls++;
    await gate?.future;
  }

  Future<void> pump(
    WidgetTester tester,
    TargetPlatform platform, {
    int items = 2,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: AdaptiveRefreshScrollView(
            onRefresh: onRefresh,
            slivers: [
              SliverList.builder(
                itemCount: items,
                itemBuilder: (_, i) => SizedBox(height: 48, child: Text('item $i')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  CustomScrollView scrollView(WidgetTester tester) =>
      tester.widget<CustomScrollView>(find.byType(CustomScrollView));

  group('iOS и macOS: родной индикатор', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      testWidgets('$platform: CupertinoSliverRefreshControl первым сливером', (
        tester,
      ) async {
        await pump(tester, platform);

        expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsNothing);
        expect(
          scrollView(tester).slivers.first,
          isA<CupertinoSliverRefreshControl>(),
        );
        expect(scrollView(tester).slivers, hasLength(2));
      });

      testWidgets('$platform: Bouncing поверх AlwaysScrollable', (tester) async {
        await pump(tester, platform);

        final physics = scrollView(tester).physics!;
        expect(physics, isA<BouncingScrollPhysics>());
        expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
      });
    }

    testWidgets('короткий контент: pull вызывает refresh, индикатор ждёт Future', (
      tester,
    ) async {
      gate = Completer<void>();
      await pump(tester, TargetPlatform.iOS, items: 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(refreshCalls, 1);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      // Future ещё не завершён — индикатор остаётся, контент отъехавший.
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('item 0')).dy,
        greaterThan(30),
        reason: 'контент отъехал вниз, пока идёт обновление',
      );

      gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(tester.getTopLeft(find.text('item 0')).dy, lessThan(30));
      expect(refreshCalls, 1);
    });
  });

  group('Android и остальные: RefreshIndicator', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.fuchsia,
      TargetPlatform.linux,
      TargetPlatform.windows,
    ]) {
      testWidgets('$platform: RefreshIndicator вокруг CustomScrollView', (
        tester,
      ) async {
        await pump(tester, platform);

        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false), findsNothing);
        expect(
          scrollView(tester).physics,
          isA<AlwaysScrollableScrollPhysics>(),
        );
        expect(scrollView(tester).physics, isNot(isA<BouncingScrollPhysics>()));
        expect(scrollView(tester).slivers, hasLength(1));
      });
    }

    testWidgets('короткий контент: pull вызывает refresh, индикатор ждёт Future', (
      tester,
    ) async {
      gate = Completer<void>();
      await pump(tester, TargetPlatform.android, items: 1);

      await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCalls, 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(refreshCalls, 1);
    });
  });

  testWidgets('платформа берётся из темы, а не из defaultTargetPlatform', (
    tester,
  ) async {
    // Тест идёт на Android по умолчанию, но тема говорит iOS.
    expect(defaultTargetPlatform, TargetPlatform.android);

    await pump(tester, TargetPlatform.iOS);

    expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false), findsOneWidget);
  });

  test('usesCupertino: iOS и macOS', () {
    expect(AdaptiveRefreshScrollView.usesCupertino(TargetPlatform.iOS), isTrue);
    expect(AdaptiveRefreshScrollView.usesCupertino(TargetPlatform.macOS), isTrue);
    expect(AdaptiveRefreshScrollView.usesCupertino(TargetPlatform.android), isFalse);
  });
}
