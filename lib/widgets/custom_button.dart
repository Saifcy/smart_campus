import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String? text;
  final String? label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isFullWidth;
  final bool? fullWidth;
  final bool isSmall;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Gradient? gradient;
  
  const CustomButton({
    super.key,
    this.text,
    this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isFullWidth = true,
    this.fullWidth,
    this.isSmall = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.gradient,
  }) : assert(text != null || label != null, 'Either text or label must be provided');
  
  @override
  Widget build(BuildContext context) {
    final btnColor = backgroundColor ?? AppTheme.electricBlue;
    final txtColor = textColor ?? Colors.white;
    final buttonText = text ?? label!;
    final useFullWidth = fullWidth ?? isFullWidth;
    
    // If gradient is provided, use a gradient button
    if (gradient != null) {
      return SizedBox(
        width: useFullWidth ? double.infinity : null,
        height: isSmall ? 40 : 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: txtColor,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _buildButtonContent(buttonText, txtColor),
          ),
        ),
      );
    }
    
    return SizedBox(
      width: useFullWidth ? double.infinity : null,
      height: isSmall ? 40 : 50,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: btnColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _buildButtonContent(buttonText, txtColor),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: txtColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _buildButtonContent(buttonText, txtColor),
            ),
    );
  }
  
  Widget _buildButtonContent(String buttonText, Color txtColor) {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    
    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            buttonText,
            style: TextStyle(
              fontSize: isSmall ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: isOutlined ? AppTheme.electricBlue : txtColor,
            ),
          ),
        ],
      );
    }
    
    return Text(
      buttonText,
      style: TextStyle(
        fontSize: isSmall ? 14 : 16,
        fontWeight: FontWeight.bold,
        color: isOutlined ? AppTheme.electricBlue : txtColor,
      ),
    );
  }
} 