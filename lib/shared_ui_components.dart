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
//         color: Colors.green[800],
//         fontSize: 14.0, 
//       ),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: Colors.green[800]!, width: 1),
//       ),
//         focusedBorder: OutlineInputBorder(
//         borderSide: BorderSide(color: Colors.green[800]!, width: 1),
//         borderRadius: BorderRadius.circular(8.0),
//         ),
//       prefixIcon: iconData != null ? Icon(iconData, color: Colors.green[800]) : null,
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
  double height = 40,
  int minLines = 1,
  int maxLines = 1,
  double? width,
  bool isPassword = false,
  String? Function(String?)? validator,
  FocusNode? focusNode,
}) {
  final textField = TextFormField(
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
      labelStyle: TextStyle(
        color: Colors.green[800],
        fontSize: 14.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.green[800]!, width: 1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.green[800]!, width: 1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.green[800]!, width: 1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      prefixIcon: iconData != null
          ? Icon(iconData, color: Colors.green[800])
          : null,
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      // isDense: true, // -> ukloniti ili postaviti na false
    ),
    style: TextStyle(fontSize: 14.0, color: Colors.black),
  );

  if (width != null) {
    return SizedBox(
      width: width,
      child: textField,
    );
  }

  return textField;
}


SizedBox generateButton({
  required String text,
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
  double width = double.infinity
}) {

final Color finalBackgroundColor = backgroundColor ?? Colors.green[800]!;
final Color finalBorderColor = borderColor ?? Colors.orangeAccent[400]!;

  return SizedBox(
    height: height,
    width: width,
    child: ElevatedButton.icon(
    onPressed: onPressed,
    icon: icon != null ? Icon(icon, color: textColor) : Container(), // Ako postoji ikona
    label: Text(
      text,
      style: TextStyle(color: textColor, fontSize: fontSize),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: finalBackgroundColor,
      padding: EdgeInsets.symmetric(vertical: paddingVertical, horizontal: paddingHorizontal),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: finalBorderColor, width: 2),
      ),
      minimumSize: Size(double.infinity, minimumHeight),
    ),
  ));
}
