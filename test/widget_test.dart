import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trashquest/core/widgets/category_badge.dart';
import 'package:trashquest/core/widgets/trashquest_logo.dart';
import 'package:trashquest/data/models/achievement.dart';
import 'package:trashquest/data/models/waste_item.dart';
import 'package:trashquest/services/currency_service.dart';
import 'package:trashquest/services/supabase_service.dart';
import 'package:trashquest/services/timezone_service.dart';
import 'package:trashquest/features/quest/paw_toss_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('TrashQuestLogo renders wordmark and symbol correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TrashQuestLogo(size: 64, showWordmark: true),
      ),
    );
    expect(find.byType(TrashQuestLogo), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Quest'), findsOneWidget);
  });

  testWidgets('CategoryBadge renders waste category correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: CategoryBadge(category: WasteCategory.organik),
      ),
    );
    expect(find.byType(CategoryBadge), findsOneWidget);
    expect(find.text('Organik'), findsOneWidget);
  });

  test('Achievement SHA-256 blockchain verification hash generation', () {
    final hash = Achievement.generateCertificateHash(
      achievementCode: 'SORTING_MASTER',
      userId: 'usr-123',
      timestamp: DateTime(2026, 1, 1),
    );
    expect(hash.length, 66); // Valid Ethereum Sepolia 66-char EVM hex string (0x...)
  });

  test('Currency conversion calculates correctly', () {
    final usdRate = CurrencyService.instance.rates['USD']!.rateToIdr;
    final converted = CurrencyService.instance.convert(usdRate, 'IDR', 'USD');
    expect(converted, closeTo(1.0, 0.001));
  });

  test('TimezoneService returns 4 timezones including London', () {
    final tzs = TimezoneService.instance.getAllTimezones();
    expect(tzs.length, 4);
    expect(tzs.any((tz) => tz.code == 'WIB'), isTrue);
    expect(tzs.any((tz) => tz.code == 'London'), isTrue);
  });

  test('SupabaseService updates full name and notifies listeners in real-time', () async {
    final service = SupabaseService.instance;
    bool listenerCalled = false;
    void listener() {
      listenerCalled = true;
    }

    service.addListener(listener);
    await service.updateFullName('Eco Champion');
    expect(service.currentUser.fullName, 'Eco Champion');
    expect(listenerCalled, isTrue);
    service.removeListener(listener);
  });

  test('SupabaseService addXp updates points and level in real-time', () {
    final service = SupabaseService.instance;
    final initialXp = service.currentUser.xp;
    bool listenerCalled = false;
    void listener() {
      listenerCalled = true;
    }

    service.addListener(listener);
    service.addXp(100);
    expect(service.currentUser.xp, initialXp + 100);
    expect(listenerCalled, isTrue);
    service.removeListener(listener);
  });

  test('Paw Toss game arsenal configuration verification', () {
    expect(kArsenal.length, 4);
    expect(kArsenal.any((w) => w.type == ThrowableType.classic), isTrue);
    expect(kArsenal.any((w) => w.type == ThrowableType.basketball), isTrue);
    expect(kArsenal.any((w) => w.type == ThrowableType.slipper), isTrue);
    expect(kArsenal.any((w) => w.type == ThrowableType.heavySplash), isTrue);
  });

  testWidgets('BackyardBattleScreen renders properly with fighters and HUD', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BackyardBattleScreen(),
      ),
    );
    await tester.pump();

    // Verify Bobi and Mochi HUD cards are present
    expect(find.text('BOBI (ANJING)'), findsOneWidget);
    expect(find.textContaining('MOCHI'), findsOneWidget);
    expect(find.textContaining('ANGIN'), findsOneWidget);
  });
}
