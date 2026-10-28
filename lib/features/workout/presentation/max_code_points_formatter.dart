import 'package:flutter/services.dart';

/// Ограничивает ввод [maxLength] символами Unicode (code points), как считает
/// сервер. `maxLength` у `TextField` считает графемы, и составной эмодзи (семья
/// из нескольких символов) помещался бы «за один» — сервер счёл бы больше и
/// отклонил результат. Лишнее при вставке обрезается.
class MaxCodePointsFormatter extends TextInputFormatter {
  const MaxCodePointsFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= maxLength) return newValue;

    final truncated = String.fromCharCodes(newValue.text.runes.take(maxLength));
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(
        offset: newValue.selection.baseOffset.clamp(0, truncated.length),
      ),
    );
  }
}
