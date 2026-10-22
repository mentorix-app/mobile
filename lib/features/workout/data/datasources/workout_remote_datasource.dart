import 'package:dio/dio.dart';
import 'package:mentorix_app/core/config/api_endpoints.dart';
import 'package:mentorix_app/core/logging/app_logger.dart';
import 'package:mentorix_app/features/auth/data/models/linked_trainer_model.dart';
import 'package:mentorix_app/features/workout/data/mappers/workout_error_mapper.dart';
import 'package:mentorix_app/features/workout/data/models/json_reading.dart';
import 'package:mentorix_app/features/workout/data/models/trainer_program_model.dart';
import 'package:mentorix_app/features/workout/domain/failures/workout_failure.dart';

/// Эндпоинты клиентских тренировок (`docs/backend_client_api.md`). Бросает
/// только [WorkoutFailure]. Идёт через основной `Dio`: Bearer и обновление
/// токена подставляет `AuthInterceptor`.
class WorkoutRemoteDataSource {
  WorkoutRemoteDataSource({required Dio apiDio}) : _dio = apiDio;

  final Dio _dio;

  /// `GET /client/trainers`. `items` обязан быть списком: без него ответ не тот,
  /// и «тренера нет» показывать нельзя. Элемент без `trainer_id` (открыть его всё
  /// равно нечем) пропускается и пишется в debug-лог, остальные остаются.
  Future<List<LinkedTrainerModel>> trainers() => _guard(() async {
    final response = await _dio.get<Object?>(ApiEndpoints.clientTrainers);
    final json = _object(response);
    if (json['items'] is! List) {
      throw const FormatException('items is not a list');
    }

    final trainers = <LinkedTrainerModel>[];
    for (final item in JsonReading.objects(json, 'items')) {
      try {
        trainers.add(LinkedTrainerModel.fromJson(item));
      } on FormatException {
        JsonReading.skip('trainers', 'item without trainer_id');
      }
    }
    return trainers;
  });

  /// `GET /client/trainers/{trainer_id}/program`: назначение, программа и
  /// `completed_days`. `assignment` и `program` — `null`, пока тренер программу не
  /// назначил. Ошибки: 403 `client_not_linked`, 422 `client_blocked`.
  Future<TrainerProgramModel> program(String trainerId) => _guard(() async {
    final response = await _dio.get<Object?>(
      ApiEndpoints.clientTrainerProgram(trainerId),
    );
    return TrainerProgramModel.fromJson(
      _object(response),
      trainerId: trainerId,
    );
  });

  Map<String, dynamic> _object(Response<Object?> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('response body is not a JSON object');
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    WorkoutEndpointMapper? endpoint,
  }) async {
    try {
      return await action();
    } on DioException catch (e, st) {
      AppLogger.dioError(e, st);
      throw WorkoutErrorMapper.map(e, endpoint: endpoint);
    } on FormatException catch (e, st) {
      // Ответ не того вида: сырой текст — в лог, пользователю — «что-то не так».
      AppLogger.error('unexpected workout response', e, st);
      throw const WorkoutUnknownFailure();
    }
  }
}
