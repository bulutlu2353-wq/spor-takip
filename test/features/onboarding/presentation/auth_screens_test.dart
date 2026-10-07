import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/onboarding/presentation/login_screen.dart';
import 'package:spor_takip/features/onboarding/presentation/register_screen.dart';
import 'package:spor_takip/features/onboarding/presentation/widgets/auth_header.dart';

import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('AuthHeader shows the logo and the LEVELUP FIT wordmark', (tester) async {
    await tester.pumpWidget(testApp(const AuthHeader(tagline: 'Slogan')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_logo')), findsOneWidget);
    final title = tester.widget<Text>(find.byKey(const Key('auth_header_title')));
    final spans = (title.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.text, 'LEVELUP');
    expect(spans.last.text, ' FIT');
    expect(spans.last.style!.color, AppColors.accent);
    expect(find.text('Slogan'), findsOneWidget);
  });

  testWidgets('login screen shows the header, the or divider and a filled submit button', (tester) async {
    await tester.pumpWidget(testApp(const LoginScreen(), scaffold: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_header')), findsOneWidget);
    expect(find.byKey(const Key('auth_or_divider')), findsOneWidget);
    expect(find.byKey(const Key('login_google_button')), findsOneWidget);
    expect(find.byKey(const Key('login_go_to_register_button')), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('login_submit_button'))), isA<FilledButton>());
  });

  testWidgets('register screen shows the header and a filled submit button', (tester) async {
    await tester.pumpWidget(testApp(const RegisterScreen(), scaffold: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_header')), findsOneWidget);
    expect(find.byKey(const Key('register_confirm_password_field')), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('register_submit_button'))), isA<FilledButton>());
  });
}
