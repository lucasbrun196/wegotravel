import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/app/auth_action_link.dart';

void main() {
  group('AuthActionLink', () {
    test('lê o link de redefinição que o Firebase manda para a raiz', () {
      final link = AuthActionLink.fromUri(Uri.parse(
        'https://wegotravel.app/?mode=resetPassword&oobCode=ABC123&apiKey=k&lang=pt-BR',
      ))!;
      expect(link.isPasswordReset, isTrue);
      expect(link.code, 'ABC123');
      expect(link.query['apiKey'], 'k');
    });

    test('outros modos são reconhecidos, mas não são redefinição', () {
      final link = AuthActionLink.fromUri(
        Uri.parse('https://wegotravel.app/?mode=verifyEmail&oobCode=X'),
      )!;
      expect(link.isPasswordReset, isFalse);
    });

    test('abertura normal do app não é link nenhum', () {
      expect(AuthActionLink.fromUri(Uri.parse('https://wegotravel.app/#/viagens')), isNull);
      expect(AuthActionLink.fromUri(Uri.parse('https://wegotravel.app/?mode=resetPassword')), isNull);
    });
  });
}
