import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/main.dart';

void main() {
  setUpAll(() async {
    // EasyLocalization persists the selected locale via shared_preferences;
    // mock it so tests don't hit a real platform channel.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('Unauthenticated user sees the login screen', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('tr'),
        child: ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                const AuthState(AuthChangeEvent.signedOut, null),
              ),
            ),
          ],
          child: const SporTakipApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });
}
