import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickButton extends StatelessWidget {
  QuickButton(
      {super.key,
      required this.ontap,
      required this.iconData,
      required this.text});

  final Function ontap;
  final IconData iconData;
  final String text;

  @override
  Widget build(BuildContext context) {
    TextStyle style = GoogleFonts.poppins(
        fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: GestureDetector(
        onTap: () {
          ontap();
        },
        child: Container(
          padding: EdgeInsets.all(15),
          width: double.infinity,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.blueAccent),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon(
              //   iconData,
              //   size: 20,
              //   color: Colors.white,
              // ),
              // SizedBox(
              //   width: 5,
              // ),
              Text(
                '$text',
                style: style,
              )
            ],
          ),
        ),
      ),
    );
  }
}
