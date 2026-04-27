import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A Stack variant that keeps hit-testing lower siblings after an upper child
/// has been hit.
///
/// Use this only for layered gesture surfaces that intentionally need to share
/// the gesture arena, such as Flutter map bubbles above a PlatformView map.
class GesturePassthroughStack extends Stack {
  const GesturePassthroughStack({
    super.key,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
    super.children,
  });

  @override
  RenderStack createRenderObject(BuildContext context) {
    return _RenderGesturePassthroughStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderStack renderObject,
  ) {
    renderObject
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..fit = fit
      ..clipBehavior = clipBehavior;
  }
}

class _RenderGesturePassthroughStack extends RenderStack {
  _RenderGesturePassthroughStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var isHit = false;
    var child = lastChild;
    while (child != null) {
      final currentChild = child;
      final childParentData = currentChild.parentData! as StackParentData;
      final childHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return currentChild.hitTest(result, position: transformed);
        },
      );
      isHit = isHit || childHit;
      child = childParentData.previousSibling;
    }
    return isHit;
  }
}
