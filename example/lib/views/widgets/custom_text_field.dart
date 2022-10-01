import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final Widget? suffix;

  const CustomTextField({
    Key? key,
    this.controller,
    this.focusNode,
    this.hint,
    this.suffix,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w400,
        fontSize: 16,
      ),
      cursorColor: Colors.redAccent,
      decoration: InputDecoration(
        suffixIcon: suffix,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.blueGrey,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Colors.pinkAccent,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Colors.pinkAccent,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Colors.pinkAccent,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Colors.pinkAccent,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}
