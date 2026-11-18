import 'package:flutter/widgets.dart';
import 'package:prism_ui/card_surface.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/press_surface.dart';
import 'package:prism_ui/shape.dart';
import 'package:prism_ui/surface.dart';
import 'package:prism_ui/typography.dart';

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  static const double _height = 44;
  static const double _inset = 4;
  static const double _denseHeight = 26;
  static const double _denseInset = 2;
  static const double _densePadding = 10;

  final List<(T, String)> segments;

  /// A small control for a section title's end: 26 tall, 12-point labels
  /// 10 in from each segment's sides, as wide as its labels need.
  final bool dense;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final count = segments.length;
    final index = segments.indexWhere((segment) => segment.$1 == value);
    final control = Container(
      height: dense ? _denseHeight : _height,
      padding: EdgeInsets.all(dense ? _denseInset : _inset),
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.full,
      ),
      child: Stack(
        children: [
          if (index >= 0)
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional(
                count == 1 ? 0 : index * 2 / (count - 1) - 1,
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colorScheme.primary,
                    shape: AppShape.full,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final (option, label) in segments)
                Expanded(
                  child: PressSurface(
                    fill: const Color(0x00000000),
                    shape: AppShape.full,
                    look: option == value ? PressLook.none : PressLook.ink,
                    ringStandsOff: option == value,
                    selected: option == value,
                    childFills: true,
                    // A null onPressed would unfocus the selected segment.
                    onPressed: option == value
                        ? () {}
                        : () => onChanged(option),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: dense ? _densePadding : 0,
                      ),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style:
                              (dense
                                      ? AppTextStyle.caption1
                                      : AppTextStyle.subheadline)
                                  .of(context, emphasized: option == value)
                                  .copyWith(
                                    color: option == value
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return dense ? IntrinsicWidth(child: control) : control;
  }
}
