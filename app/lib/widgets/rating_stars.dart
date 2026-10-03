import 'package:flutter/material.dart';

/// Read-only star display, e.g. "★★★★☆ 4.2 (18)".
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool showCount;
  final int count;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.showCount = false,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final filled = rating >= i + 0.75;
          final half = !filled && rating >= i + 0.25;
          return Icon(
            filled ? Icons.star : (half ? Icons.star_half : Icons.star_border),
            size: size,
            color: Colors.amber.shade700,
          );
        }),
        if (showCount) ...[
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: TextStyle(fontSize: size * 0.8, color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }
}

/// Tappable star input for the rating screens.
class RatingInput extends StatefulWidget {
  final int initial;
  final ValueChanged<int> onChanged;

  const RatingInput({super.key, this.initial = 5, required this.onChanged});

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState extends State<RatingInput> {
  late int _stars;

  @override
  void initState() {
    super.initState();
    _stars = widget.initial.clamp(1, 5);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final index = i + 1;
        return IconButton(
          onPressed: () {
            setState(() => _stars = index);
            widget.onChanged(_stars);
          },
          icon: Icon(
            index <= _stars ? Icons.star : Icons.star_border,
            size: 40,
            color: Colors.amber.shade700,
          ),
        );
      }),
    );
  }
}
