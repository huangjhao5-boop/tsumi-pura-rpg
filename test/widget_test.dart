import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TsumiPuraApp initial load and UI elements smoke test', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TsumiPuraApp());
    await tester.pump();

    // Verify Title Header
    expect(find.text('TSUMI-PURA RPG'), findsOneWidget);

    // Verify Boss Card Information
    expect(find.textContaining('HG 1/144'), findsOneWidget);
    expect(find.textContaining('綠色普通盒怪'), findsOneWidget);

    // Verify Process / Craft Phase Selector presence
    expect(find.text('素組\n1.0x'), findsOneWidget);
    expect(find.text('打磨\n1.2x'), findsOneWidget);
    expect(find.text('刻線\n1.5x'), findsOneWidget);
    expect(find.text('噴塗\n2.0x'), findsOneWidget);
    expect(find.text('水貼\n🔒20%'), findsOneWidget);

    // Verify Pomodoro Mode Selector
    expect(find.text('標準 25m/5m'), findsOneWidget);
    expect(find.text('深度 50m/10m'), findsOneWidget);
    expect(find.text('除錯 5s/3s'), findsOneWidget);

    // Verify Timer HUD and Start Button
    expect(find.text('00:00'), findsOneWidget);
    expect(find.textContaining('開始開工'), findsOneWidget);

    // Verify CraftLog Button presence
    expect(find.byKey(const Key('btn_craft_log')), findsOneWidget);
  });

  testWidgets('Opening and navigating back from CraftLogScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TsumiPuraApp());
    await tester.pump();

    // Tap CraftLog button
    await tester.tap(find.byKey(const Key('btn_craft_log')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify CraftLogScreen title and sections
    expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
    expect(find.text('【討伐與施工統計總覽】'), findsOneWidget);
    expect(find.text('【5 大工序傷害與工時分佈】'), findsOneWidget);
    expect(find.text('【詳細施工歷史清單】'), findsOneWidget);

    // Tap Back button
    await tester.tap(find.byKey(const Key('btn_craft_log_back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify return to Battle Screen
    expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
    expect(find.textContaining('綠色普通盒怪'), findsOneWidget);
  });
}
