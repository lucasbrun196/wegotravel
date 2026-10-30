import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Erro de autenticação já traduzido para uma frase que o usuário
/// entende. Mensagem crua do Firebase em português técnico não ajuda
/// ninguém a descobrir o que digitou errado.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;

  factory AuthFailure.fromCode(String code) => AuthFailure(switch (code) {
        'invalid-email' => 'Esse e-mail não parece válido.',
        'user-disabled' => 'Essa conta foi desativada.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'E-mail ou senha incorretos.',
        'email-already-in-use' => 'Já existe uma conta com esse e-mail.',
        'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
        'too-many-requests' => 'Muitas tentativas. Espere um pouco e tente de novo.',
        'network-request-failed' => 'Sem conexão. Verifique sua internet.',
        'operation-not-allowed' =>
          'Esse método de login não está ativado no Firebase.',
        'popup-blocked' =>
          'O navegador bloqueou a janela do Google. Libere pop-ups e tente de novo.',
        'unauthorized-domain' =>
          'Este endereço não está autorizado no Firebase Auth.',
        'account-exists-with-different-credential' =>
          'Esse e-mail já tem conta com senha. Entre com e-mail e senha.',
        'user-mismatch' => 'Escolha a mesma conta Google com que você entrou.',
        'expired-action-code' => 'Esse link expirou. Peça um novo na tela de login.',
        'invalid-action-code' =>
          'Esse link não vale mais. Talvez já tenha sido usado. Peça um novo na tela de login.',
        'requires-recent-login' => 'Faça login de novo para concluir essa ação.',
        _ => 'Não deu para concluir. Tente novamente.',
      });
}

/// A pessoa fechou a janela do Google sem escolher conta.
///
/// Não é erro: quem chama simplesmente para, sem mostrar mensagem.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Autenticação por e-mail e senha ou pela conta Google.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  String? get uid => _auth.currentUser?.uid;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Se a conta tem senha própria. Quem só entrou pelo Google não tem:
  /// trocar senha e confirmar com senha não fazem sentido para ela.
  bool get hasPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

  /// Na web abre a janela do Google; no Android/iOS, o fluxo nativo do
  /// próprio Firebase Auth — sem precisar do pacote `google_sign_in`.
  ///
  /// O espelho em `users/{uid}` sai do nome e do e-mail da conta Google,
  /// por `currentUserProvider`, como em qualquer outro login.
  Future<User> signInWithGoogle() async {
    try {
      final credential = kIsWeb
          ? await _auth.signInWithPopup(_googleProvider())
          : await _auth.signInWithProvider(_googleProvider());
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw _googleFailure(e);
    }
  }

  /// Confirma a identidade pela conta Google, para quem não tem senha.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Faça login de novo para concluir essa ação.');
    }
    try {
      await (kIsWeb
          ? user.reauthenticateWithPopup(_googleProvider())
          : user.reauthenticateWithProvider(_googleProvider()));
    } on FirebaseAuthException catch (e) {
      throw _googleFailure(e);
    }
  }

  /// `select_account` faz o Google perguntar qual conta usar, em vez de
  /// entrar direto na última — quem divide o computador agradece.
  GoogleAuthProvider _googleProvider() =>
      GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});

  Exception _googleFailure(FirebaseAuthException e) => switch (e.code) {
        'popup-closed-by-user' ||
        'cancelled-popup-request' ||
        'web-context-canceled' ||
        'canceled' =>
          const AuthCancelled(),
        _ => AuthFailure.fromCode(e.code),
      };

  Future<User> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  Future<User> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      if (displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
      }
      return _auth.currentUser ?? user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  /// Confere o código que veio no link do e-mail de redefinição e
  /// devolve o e-mail da conta, para a tela mostrar de quem é a senha.
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await _auth.verifyPasswordResetCode(code);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  /// Grava a senha nova. O código vale uma vez só: depois disto o mesmo
  /// link dá `invalid-action-code`.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  /// Confirma a identidade com a senha atual.
  ///
  /// Trocar a senha e excluir a conta são operações sensíveis: o Firebase
  /// só as aceita com login recente. Reautenticar antes evita depender de
  /// quanto tempo faz que a pessoa entrou.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('Faça login de novo para concluir essa ação.');
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      // Aqui o e-mail é o da sessão, então "e-mail ou senha incorretos"
      // só confundiria: o que pode estar errado é a senha.
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthFailure('Senha atual incorreta.');
      }
      throw AuthFailure.fromCode(e.code);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  /// Apaga a conta do Auth. Os dados no Firestore precisam ter sido
  /// removidos antes — depois disso não há mais permissão para escrever.
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  Future<void> signOut() => _auth.signOut();
}
