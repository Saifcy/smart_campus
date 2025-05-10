import 'package:flutter/material.dart';

class ScreenUtils {
  static late double width;
  static late double height;
  static late double topPadding;
  static late double bottomPadding;
  static late double statusBarHeight;
  
  static void init(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    width = mediaQuery.size.width;
    height = mediaQuery.size.height;
    topPadding = mediaQuery.padding.top;
    bottomPadding = mediaQuery.padding.bottom;
    statusBarHeight = mediaQuery.viewPadding.top;
  }
  
  // Get proportionate height according to screen size
  static double getProportionateScreenHeight(double inputHeight) {
    return (inputHeight / 812.0) * height;
  }
  
  // Get proportionate width according to screen size
  static double getProportionateScreenWidth(double inputWidth) {
    return (inputWidth / 375.0) * width;
  }
}