import 'package:flutter/material.dart';

// Widget generateTextField({
//     required String labelText,
//     required TextEditingController controller,
//     IconData? iconData,
//     double height = 40,
//     double width = double.infinity,
//     bool isPassword = false
//     }) {
//   return SizedBox(
//     height: height,
//     width: width,
//     child: TextField(
//     obscureText: isPassword,
//     controller: controller,
//     autofocus: false,
//     decoration: InputDecoration(
//       labelText: labelText,
//       labelStyle: TextStyle(
//         color: const Color(0xFF388E3C),
//         fontSize: 14.0,
//       ),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: const Color(0xFF388E3C), width: 1),
//       ),
//         focusedBorder: OutlineInputBorder(
//         borderSide: BorderSide(color: const Color(0xFF388E3C), width: 1),
//         borderRadius: BorderRadius.circular(8.0),
//         ),
//       prefixIcon: iconData != null ? Icon(iconData, color: const Color(0xFF388E3C)) : null,
//       //contentPadding: EdgeInsets.all(1),
//       isDense: true
//     ),
//     style: TextStyle(
//       fontSize: 14.0,
//       color: Colors.black),
//   )
//   );
// }

Widget generateHorizontalLine(String title) {
  return Row(
    children: <Widget>[
      Expanded(child: Divider()), // Left side line
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      Expanded(child: Divider()), // Right side line
    ],
  );
}

Widget generateTextField({
  required String labelText,
  required TextEditingController controller,
  IconData? iconData,
  Widget? sufixIconWidget,
  double height = 40,
  int minLines = 1,
  int maxLines = 1,
  double? width,
  bool isPassword = false,
  bool enabled = true,
  String? Function(String?)? validator,
  FocusNode? focusNode,
}) {
  final textField = TextFormField(
    enabled: enabled,
    minLines: minLines,
    maxLines: maxLines,
    obscureText: isPassword,
    controller: controller,
    focusNode: focusNode,
    autovalidateMode: focusNode != null && focusNode.hasFocus
        ? AutovalidateMode.disabled
        : AutovalidateMode.onUserInteraction,
    validator: validator,
    onTap: () {
      if (focusNode != null) focusNode.requestFocus();
    },
    decoration: InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14.0),
      filled: true,
      fillColor: enabled ? const Color(0xFFF5F7F5) : const Color(0xFFEEEEEE),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFDDE5DE), width: 1),
        borderRadius: BorderRadius.circular(10.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF388E3C), width: 1.5),
        borderRadius: BorderRadius.circular(10.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 1),
        borderRadius: BorderRadius.circular(10.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF388E3C), width: 1.5),
        borderRadius: BorderRadius.circular(10.0),
      ),
      prefixIcon: iconData != null
          ? Icon(iconData, color: const Color(0xFF6B7280), size: 20)
          : null,
      suffixIcon: sufixIconWidget,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    ),
    style: const TextStyle(fontSize: 14.0, color: Color(0xFF111827)),
  );

  if (width != null) {
    return SizedBox(
      width: width,
      child: textField,
    );
  }

  return textField;
}

SizedBox generateButton(
    {required String text,
    required VoidCallback onPressed,
    IconData? icon,
    Color textColor = Colors.white,
    Color? backgroundColor,
    Color? borderColor,
    double fontSize = 14.0,
    double paddingVertical = 16.0,
    double paddingHorizontal = 20.0,
    double borderRadius = 12.0,
    double minimumHeight = 30.0,
    double height = 50,
    double width = double.infinity}) {
  final Color finalBackgroundColor = backgroundColor ?? const Color(0xFF388E3C);

  return SizedBox(
    height: height,
    width: width,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, color: textColor, size: 18) : const SizedBox.shrink(),
      label: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: finalBackgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.symmetric(
            vertical: paddingVertical, horizontal: paddingHorizontal),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        minimumSize: Size(double.infinity, minimumHeight),
      ),
    ),
  );
}

void showErrorDialog(BuildContext context, String message, {int seconds = 3}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      // automatsko zatvaranje nakon n sekundi
      Future.delayed(Duration(seconds: seconds), () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });

      return AlertDialog(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.red[800] ?? Colors.red, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const SizedBox(width: 10),
            Flexible(child: Text(message)),
          ],
        ),
      );
    },
  );
}

String formatChatTime(DateTime timestamp) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final difference = now.difference(timestamp);

  // Ako je danas - prikaži vreme
  if (messageDate == today) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  // Ako je juče
  if (messageDate == yesterday) {
    return 'Juče';
  }

  // Ako je ove nedelje - prikaži dan
  if (difference.inDays < 7) {
    return _getDayName(timestamp.weekday);
  }

  // Ako je ove godine - prikaži datum bez godine
  if (timestamp.year == now.year) {
    return '${timestamp.day}.${timestamp.month}.';
  }

  // Starije - pun datum
  return '${timestamp.day}.${timestamp.month}.${timestamp.year}.';
}

String _getDayName(int weekday) {
  switch (weekday) {
    case 1: return 'Ponedeljak';
    case 2: return 'Utorak';
    case 3: return 'Sreda';
    case 4: return 'Četvrtak';
    case 5: return 'Petak';
    case 6: return 'Subota';
    case 7: return 'Nedelja';
    default: return '';
  }
}