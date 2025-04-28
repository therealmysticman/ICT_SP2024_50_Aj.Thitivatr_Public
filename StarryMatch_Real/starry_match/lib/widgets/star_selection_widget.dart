import 'package:flutter/material.dart';

class StarSelectionWidget extends StatefulWidget {
  final String questionId; // Unique identifier for the question
  final int? selectedIndex; // Selected index passed from the parent
  final void Function(int) onStarSelected;
  final String choice1;
  final String choice3;
  final String choice5;

  const StarSelectionWidget({
    super.key,
    required this.questionId,
    required this.onStarSelected,
    this.selectedIndex,
    required this.choice1,
    required this.choice3,
    required this.choice5,
  });

  @override
  _StarSelectionWidgetState createState() => _StarSelectionWidgetState();
}

class _StarSelectionWidgetState extends State<StarSelectionWidget> {
  late int? selectedStarIndex;

  final List<String> starImages = [
    'assets/sparkledarkyellow.png',
    'assets/sparkleyellow.png',
    'assets/sparklegrey.png',
    'assets/sparklepurple.png',
    'assets/sparkledarkpurple.png',
  ];

  final List<String> starHighlightImages = [
    'assets/sparkledarkyellow_highlight.png',
    'assets/sparkleyellow_highlight.png',
    'assets/sparklegrey_highlight.png',
    'assets/sparklepurple_highlight.png',
    'assets/sparkledarkpurple_highlight.png',
  ];

  @override
  void didUpdateWidget(covariant StarSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selectedStarIndex whenever the parent updates the selectedIndex.
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      selectedStarIndex = widget.selectedIndex;
    }
  }

  @override
  void initState() {
    super.initState();
    selectedStarIndex = widget.selectedIndex ?? -1; // Initialize with parent's selectedIndex
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    // Adjust star size and padding based on screen size - reduced even more for very small screens
    final starSize = isSmallScreen ? 35.0 : 45.0;
    final horizontalPadding = isSmallScreen ? 2.0 : 6.0;
    final textSize = isSmallScreen ? 9.0 : 11.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final starAreaWidth = (starSize + (horizontalPadding * 2)) * 5;
        final shouldScaleDown = starAreaWidth > availableWidth;
        
        // Further reduce sizes if needed based on available width
        final adjustedStarSize = shouldScaleDown ? starSize * 0.9 : starSize;
        final adjustedPadding = shouldScaleDown ? 1.0 : horizontalPadding;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star Selection Row - using Wrap for better flexibility
            Wrap(
              alignment: WrapAlignment.center,
              spacing: adjustedPadding,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedStarIndex = index;
                    });
                    widget.onStarSelected(index);
                  },
                  child: SizedBox(
                    width: adjustedStarSize,
                    height: adjustedStarSize,
                    child: Image.asset(
                      selectedStarIndex == index
                          ? starHighlightImages[index]
                          : starImages[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 2),

            // Descriptions Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      widget.choice1,
                      textAlign: TextAlign.left,
                      style: TextStyle(fontSize: textSize),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      widget.choice3,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: textSize),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      widget.choice5,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: textSize),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
