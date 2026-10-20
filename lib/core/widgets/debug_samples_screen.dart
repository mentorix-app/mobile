import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mentorix_app/core/logging/debug_sample_fetcher.dart';
import 'package:mentorix_app/core/theme/app_spacing.dart';
import 'package:mentorix_app/core/widgets/app_snack_bar.dart';

/// Экран разработчика (только debug): снимает сырой JSON клиентского API и
/// кладёт в буфер обмена, чтобы вставить в `docs/samples/*.json`.
///
/// Подписи — это сами адреса запросов и статус ответа, без прозы, поэтому в
/// ARB они не заводятся: экран в release не попадает (см. `DebugSamplesEntry`).
class DebugSamplesScreen extends StatefulWidget {
  const DebugSamplesScreen({super.key, required this.fetcher});

  final DebugSampleFetcher fetcher;

  @override
  State<DebugSamplesScreen> createState() => _DebugSamplesScreenState();
}

class _DebugSamplesScreenState extends State<DebugSamplesScreen> {
  final _busy = ValueNotifier<bool>(false);
  final _sample = ValueNotifier<DebugSample?>(null);
  final _error = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _busy.dispose();
    _sample.dispose();
    _error.dispose();
    super.dispose();
  }

  Future<void> _run(Future<DebugSample> Function() load) async {
    _busy.value = true;
    _error.value = null;

    try {
      final sample = await load();
      if (!mounted) return;

      _sample.value = sample;
      await Clipboard.setData(ClipboardData(text: sample.body));
      if (!mounted) return;
      AppSnackBar.showInfo(context, '${sample.status} ${sample.path} → clipboard');
    } on Object catch (error) {
      if (!mounted) return;
      // Только тип сбоя: текст исключения и ответа не показывается.
      _error.value = error.runtimeType.toString();
    } finally {
      _busy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('API samples')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ValueListenableBuilder<bool>(
            valueListenable: _busy,
            builder: (context, busy, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => _run(widget.fetcher.trainers),
                  child: const Text('GET /client/trainers'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: busy ? null : () => _run(widget.fetcher.program),
                  child: const Text('GET /client/trainers/{id}/program'),
                ),
                SizedBox(
                  height: AppSpacing.xs,
                  child: busy ? const LinearProgressIndicator() : null,
                ),
                const SizedBox(height: AppSpacing.md),
                ValueListenableBuilder<String?>(
                  valueListenable: _error,
                  builder: (context, error, _) => error == null
                      ? const SizedBox.shrink()
                      : Text(error, style: textTheme.bodyMedium),
                ),
                Expanded(
                  child: ValueListenableBuilder<DebugSample?>(
                    valueListenable: _sample,
                    builder: (context, sample, _) => sample == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            child: SelectableText(
                              '${sample.status} ${sample.path}\n\n${sample.body}',
                              style: textTheme.bodySmall,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
