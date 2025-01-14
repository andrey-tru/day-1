import 'package:surf_practice_chat_flutter/features/auth/exceptions/auth_exception.dart';
import 'package:surf_practice_chat_flutter/features/auth/models/token_dto.dart';
import 'package:surf_study_jam/surf_study_jam.dart';

/// Basic interface of authorization logic.
///
/// Has 2 methods: [signIn] & [signOut].
abstract class IAuthRepository {
  /// Signs the user in via [login] & [password].
  ///
  /// [login] is a `String` representation of login,
  /// that was used in registration.
  ///
  /// [password] is a `String` representation of a password,
  /// that was used in registration.
  ///
  /// [TokenDto] is a model, containing its' value, that should be
  /// retrieved in the end of authorization process.
  ///
  /// May throw an [AuthException].
  Future<TokenDto> signIn({
    required String login,
    required String password,
  });

  /// Signs the user out, clearing all unneeded credentials.
  Future<void> signOut();
}

/// Simple implementation of [IAuthRepository], using [StudyJamClient].
class AuthRepository implements IAuthRepository {
  AuthRepository(this._studyJamClient);

  final StudyJamClient _studyJamClient;

  @override
  Future<TokenDto> signIn({
    required String login,
    required String password,
  }) async {
    try {
      final String token = await _studyJamClient.signin(login, password);

      return TokenDto(token: token);
    } on Exception catch (e) {
      return TokenDto(error: e.toString());
    }
  }

  @override
  Future<void> signOut() {
    return _studyJamClient.logout();
  }
}
