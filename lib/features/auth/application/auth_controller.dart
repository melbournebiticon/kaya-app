import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/features/auth/domain/auth_profile_repository.dart';
import 'package:kaya/features/auth/domain/auth_session.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/auth/domain/user_profile.dart';
import 'package:material_ui/material_ui.dart';

/// Authentication lifecycle state for KAYA.
enum AuthStatus { initializing, unauthenticated, authenticated }

/// Application state controller for Phase 2 Authentication & User Profiles.
///
/// Enforces:
/// - Duplicate submission prevention (`isSubmitting`).
/// - Stale request cancellation across account switches (`_sessionEpoch`).
/// - Immediate private cache clearing on logout.
class AuthController extends ChangeNotifier {
  AuthController({required this.repository});

  final AuthProfileRepository repository;

  AuthStatus _status = AuthStatus.initializing;
  AuthSession? _session;
  UserProfile? _profile;
  AuthFailure? _lastError;
  String? _lastNoticeMessage;
  bool _isSubmitting = false;
  int _sessionEpoch = 0;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  UserProfile? get profile => _profile;
  AuthFailure? get lastError => _lastError;
  String? get lastNoticeMessage => _lastNoticeMessage;
  bool get isSubmitting => _isSubmitting;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated &&
      _session != null &&
      _profile != null;

  void clearMessages() {
    if (_lastError != null || _lastNoticeMessage != null) {
      _lastError = null;
      _lastNoticeMessage = null;
      notifyListeners();
    }
  }

  /// Restores an existing session on app startup.
  Future<void> restoreSession() async {
    final int requestEpoch = ++_sessionEpoch;
    _status = AuthStatus.initializing;
    _lastError = null;
    notifyListeners();

    try {
      final AuthenticatedContext? restored = await repository.restoreSession();
      if (requestEpoch != _sessionEpoch) {
        return;
      }
      if (restored == null) {
        _clearPrivateState();
        _status = AuthStatus.unauthenticated;
      } else {
        _session = restored.session;
        _profile = restored.profile;
        _status = AuthStatus.authenticated;
      }
    } on AuthFailure catch (failure) {
      if (requestEpoch != _sessionEpoch) {
        return;
      }
      _clearPrivateState();
      _lastError = failure;
      _status = AuthStatus.unauthenticated;
    } catch (_) {
      if (requestEpoch != _sessionEpoch) {
        return;
      }
      _clearPrivateState();
      _lastError = AuthFailure.network();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Registers a new account and signs in the user.
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    SupportedCurrency preferredCurrency = SupportedCurrency.php,
  }) async {
    if (_isSubmitting) {
      return false;
    }
    final int requestEpoch = ++_sessionEpoch;
    _isSubmitting = true;
    _lastError = null;
    _lastNoticeMessage = null;
    notifyListeners();

    try {
      final AuthenticatedContext result = await repository.register(
        email: email,
        password: password,
        displayName: displayName,
        preferredCurrency: preferredCurrency,
      );
      if (requestEpoch != _sessionEpoch) {
        return false;
      }
      _session = result.session;
      _profile = result.profile;
      _status = AuthStatus.authenticated;
      _isSubmitting = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _sessionEpoch) {
        _lastError = failure;
        _status = AuthStatus.unauthenticated;
        _isSubmitting = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _sessionEpoch) {
        _lastError = AuthFailure.network();
        _status = AuthStatus.unauthenticated;
        _isSubmitting = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Signs in an existing user and loads their isolated profile.
  Future<bool> login({required String email, required String password}) async {
    if (_isSubmitting) {
      return false;
    }
    final int requestEpoch = ++_sessionEpoch;
    _isSubmitting = true;
    _lastError = null;
    _lastNoticeMessage = null;
    notifyListeners();

    try {
      final AuthenticatedContext result = await repository.login(
        email: email,
        password: password,
      );
      if (requestEpoch != _sessionEpoch) {
        return false;
      }
      _session = result.session;
      _profile = result.profile;
      _status = AuthStatus.authenticated;
      _isSubmitting = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _sessionEpoch) {
        _clearPrivateState();
        _lastError = failure;
        _status = AuthStatus.unauthenticated;
        _isSubmitting = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _sessionEpoch) {
        _clearPrivateState();
        _lastError = AuthFailure.network();
        _status = AuthStatus.unauthenticated;
        _isSubmitting = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Sends a password recovery link to [email].
  Future<bool> requestPasswordRecovery({required String email}) async {
    if (_isSubmitting) {
      return false;
    }
    _isSubmitting = true;
    _lastError = null;
    _lastNoticeMessage = null;
    notifyListeners();

    try {
      await repository.requestPasswordRecovery(email: email);
      _lastNoticeMessage =
          'If an account exists for ${email.trim().toLowerCase()}, password recovery instructions have been sent.';
      _isSubmitting = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      _lastError = failure;
      _isSubmitting = false;
      notifyListeners();
      return false;
    } catch (_) {
      _lastError = AuthFailure.network();
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates the authenticated user's profile and currency preference.
  ///
  /// Only updates local state and sets a success message AFTER the repository
  /// confirms the write succeeded.
  Future<bool> updateProfile({
    required String displayName,
    required SupportedCurrency preferredCurrency,
  }) async {
    if (_isSubmitting || !isAuthenticated) {
      return false;
    }
    final int requestEpoch = _sessionEpoch;
    _isSubmitting = true;
    _lastError = null;
    _lastNoticeMessage = null;
    notifyListeners();

    try {
      final UserProfile updated = await repository.updateProfile(
        targetUserId: _session!.userId,
        displayName: displayName,
        preferredCurrency: preferredCurrency,
      );
      if (requestEpoch != _sessionEpoch) {
        return false;
      }
      _profile = updated;
      _lastNoticeMessage = 'Profile and currency preferences saved.';
      _isSubmitting = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _sessionEpoch) {
        if (failure.code == AuthFailureCode.sessionExpired ||
            failure.code == AuthFailureCode.unauthorizedAccess) {
          _clearPrivateState();
          _status = AuthStatus.unauthenticated;
        }
        _lastError = failure;
        _isSubmitting = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _sessionEpoch) {
        _lastError = AuthFailure.network();
        _isSubmitting = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Logs out the current user and wipes all private session and profile caches.
  Future<void> logout() async {
    _sessionEpoch++;
    _clearPrivateState();
    _status = AuthStatus.unauthenticated;
    _isSubmitting = false;
    notifyListeners();

    try {
      await repository.logout();
    } catch (_) {
      // Private client caches are already wiped even if remote signout fails.
    }
  }

  void _clearPrivateState() {
    _session = null;
    _profile = null;
    _lastError = null;
    _lastNoticeMessage = null;
  }
}
