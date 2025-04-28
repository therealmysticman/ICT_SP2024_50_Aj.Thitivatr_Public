import 'package:flutter/material.dart';

class SimpleInfoRowWidget extends StatelessWidget {
  final String title;
  final String value;
  final String? imagePath;
  final VoidCallback? onImageTap;

  const SimpleInfoRowWidget({
    super.key, 
    required this.title, 
    required this.value,
    this.imagePath,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (imagePath != null) ...[
                  GestureDetector(
                    onTap: onImageTap,
                    child: Image.asset(
                      imagePath!,
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
