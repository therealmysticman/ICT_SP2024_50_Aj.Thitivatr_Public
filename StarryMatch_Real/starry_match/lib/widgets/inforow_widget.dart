import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

class InfoRowWidget extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTestAgain;

  const InfoRowWidget({
    super.key,
    required this.title,
    required this.value,
    required this.onTestAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$title: $value",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12, fontFamily: 'MainFonts'),
            ),
            onPressed: onTestAgain,
            child: Text(AppLocalizations.of(context)!.translate('test_again')),
          ),
        ],
      ),
    );
  }
}
