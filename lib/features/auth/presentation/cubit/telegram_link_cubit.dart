import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mentorix_app/core/config/telegram_config.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/core/platform/external_link_launcher.dart';
import 'package:mentorix_app/core/router/onboarding_flow.dart';
import 'package:mentorix_app/features/auth/domain/failures/auth_failure.dart';
import 'package:mentorix_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_cubit.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/session_state.dart';
import 'package:mentorix_app/features/auth/presentation/cubit/telegram_link_state.dart';

/// Предложение привязать Telegram и ввод кода. Один экземпляр на оба экрана.
class TelegramLinkCubit extends Cubit<TelegramLinkState> {
  TelegramLinkCubit(
    this._repository,
    this._session,
    this._flow,
    this._launcher, {
    String botName = TelegramConfig.botName,
  }) : _botName = botName,
       super(const TelegramLinkInitial()) {
    if (!isBotConfigured) {
      AppLogger.warning(
        'TELEGRAM_BOT_NAME не задан в config/stage.json: кнопка «Открыть бота» '
        'неактивна.',
      );
    }
  }

  final AuthRepository _repository;
  final SessionCubit _session;
  final OnboardingFlow _flow;
  final ExternalLinkLauncher _launcher;
  final String _botName;

  /// Код уже принят сервером, но `/auth/me` не получен: повтор не должен
  /// отправлять использованный код ещё раз.
  bool _linked = false;

  bool get isBotConfigured => TelegramConfig.isRealBotName(_botName);

  /// Открывает бота (`https://t.me/<bot>?start=link`) во внешнем приложении.
  /// `false` — имя бота не задано или открыть не удалось.
  Future<bool> openBot() async {
    if (!isBotConfigured) return false;
    return _launcher.open(TelegramConfig.linkUri(_botName));
  }

  Future<void> submit(String code) async {
    if (state is TelegramLinkInProgress) return;
    emit(const TelegramLinkInProgress());

    // Ошибка на шаге привязки тратит код; ошибка уже после неё (профиль) — нет.
    final linkingStep = !_linked;

    try {
      if (!_linked) {
        await _repository.linkTelegram(code);
        _linked = true;
      }

      // user_id мог поменяться: профиль всегда запрашивается заново.
      final profile = await _repository.getProfile(forceRefresh: true);
      if (isClosed) return;

      _session.setAuthenticated(profile);
      emit(const TelegramLinkSuccess());
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      emit(
        TelegramLinkFailed(
          failure,
          codeSpent: linkingStep && failure.spendsTelegramCode,
        ),
      );
    }
  }

  Future<void> skip() async {
    final session = _session.state;
    if (session is SessionAuthenticated) {
      await _flow.skipTelegramOffer(session.profile.userId);
    }
    if (isClosed) return;
    emit(const TelegramLinkSkipped());
  }
}
