import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:mentorix_app/core/di/service_locator.dart';
import 'package:mentorix_app/core/logging/debug_log.dart';
import 'package:mentorix_app/core/logging/debug_sample_fetcher.dart';
import 'package:mentorix_app/core/widgets/debug_samples_screen.dart';

/// Иконка в `AppBar` для входа на [DebugSamplesScreen]. Только в debug-сборке:
/// в release возвращает пустое место — ни кнопки, ни экрана.
class DebugSamplesEntry extends StatelessWidget {
  const DebugSamplesEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (!DebugLog.enabled) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.data_object),
      tooltip: 'Debug: API samples',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DebugSamplesScreen(
            fetcher: DebugSampleFetcher(
              GetIt.I<Dio>(instanceName: DioNames.api),
            ),
          ),
        ),
      ),
    );
  }
}
