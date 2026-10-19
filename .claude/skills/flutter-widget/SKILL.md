---
name: flutter-widget
description: Создать новый виджет Flutter или вынести существующий в отдельный файл по правилам проекта — публичный класс, ValueNotifier вместо setState, dispose, токены темы. Использовать при словах «новый виджет», «вынеси виджет», «разбери экран на виджеты».
---

# Новый виджет

## Куда класть

| Виджет | Путь |
|---|---|
| Только для одной фичи | `lib/features/<feature>/presentation/widgets/<snake_case>.dart` |
| Общий между фичами | `lib/core/widgets/app_<snake_case>.dart` |
| Часть большого экрана | подпапка: `widgets/active_workout/`, `widgets/summary/` |

**Сначала поиск, потом создание.** Прежде чем писать виджет, проверить, нет ли уже такого:

```bash
grep -rln "<ключевое слово из виджета>" lib/core/widgets lib/features/*/presentation/widgets
```

В этом проекте уже находились три копии одного глазка пароля, два аватара и два поля
подхода — копии разошлись и стали выглядеть по-разному.

## Как писать

Один файл — один публичный класс. `StatelessWidget` по умолчанию; `StatefulWidget` только
если виджет сам владеет `ValueNotifier`, контроллером, анимацией или таймером.

```dart
import 'package:mentorix_app/core/theme/app_theme_extension.dart';
import 'package:flutter/material.dart';

/// Одна строка о том, зачем виджет и почему он выглядит именно так.
/// Если это исправление дефекта — упомянуть, что было не так.
class SomeTile extends StatelessWidget {
  const SomeTile({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = context.themeExt;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ext.card,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: ext.border),
        ),
        child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
```

Со своим состоянием:

```dart
class SomeToggle extends StatefulWidget {
  const SomeToggle({super.key, required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  State<SomeToggle> createState() => _SomeToggleState();
}

class _SomeToggleState extends State<SomeToggle> {
  final _value = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: _value,
        builder: (context, value, _) => Switch(
          value: value,
          onChanged: (next) {
            _value.value = next;
            widget.onChanged(next);
          },
        ),
      );
}
```

## Правила

1. Класс **публичный**, без подчёркивания. Приватным остаётся только `State`.
2. Никакого `setState` — `ValueNotifier` + `ValueListenableBuilder`.
3. `dispose()` для каждого созданного notifier, контроллера, анимации, таймера.
4. Данные приходят параметрами, наружу — колбэки. Виджет не читает репозитории
   и не создаёт кубиты; `context.read<XCubit>()` допустим, если виджет принадлежит фиче.
5. Цвета — через `context.themeExt`, отступы и радиусы — `AppSpacing` / `AppRadii`.
   Хардкода hex нет. `withValues(alpha:)` вместо `withOpacity()`.
6. Все пользовательские строки — через `AppLocalizations.of(context)`, во всех локалях сразу.
7. Конструктор с `const`, где возможно; `super.key` первым параметром.
8. Если виджет повторяется в списке из изменяемой коллекции — у вызывающей стороны
   обязателен `key: ValueKey(<стабильный id>)`.

## Вынос существующего виджета

1. Скопировать класс целиком в новый файл, убрать подчёркивание из имени.
2. Добавить `super.key` в конструктор.
3. Поля, которые брались из замыкания родителя (`l10n`, значения, колбэки), стали
   параметрами конструктора.
4. В родителе удалить класс, добавить импорт, передать параметры.
5. `flutter analyze` → убрать импорты, ставшие ненужными, в обоих файлах.
6. Внешний вид не должен измениться: если по дороге захотелось что-то улучшить,
   сделать это отдельным шагом и сказать об этом.
