import 'package:flutter/material.dart';

class PinchZoom extends StatefulWidget {
  final Widget child;
  final double maxScale;
  final Duration resetDuration;
  final bool zoomEnabled;
  final Function? onZoomStart, onZoomEnd;

  /// Create an PinchZoom.
  ///
  /// * [child] is the widget used for zooming.
  /// This parameter must not be null.
  ///
  /// * [maxScale] is the maximum allowed scale.
  /// Defaults to 3.0.
  /// Cannot be null, and must be greater than zero.
  ///
  /// * [resetDuration] is the length of time this animation should last.
  ///
  /// * [zoomEnabled] can be used to enable/disable zooming.
  ///
  /// * [onZoomStart] called when the widget goes to its zoomed state.
  ///
  /// * [onZoomEnd] called when the widget is back to its idle state.

  PinchZoom(
      {required this.child,
      this.resetDuration = const Duration(milliseconds: 100),
      // This default maxScale value is eyeballed as reasonable limit for common
      // use cases.
      this.maxScale = 3.0,
      this.zoomEnabled = true,
      this.onZoomStart,
      this.onZoomEnd});

  @override
  _PinchZoomState createState() => _PinchZoomState();
}

class _PinchZoomState extends State<PinchZoom>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();

  late Animation<Matrix4> _animationReset;
  late AnimationController _controllerReset;

  var viewerKey = GlobalKey();
  Rect placeholder;
  OverlayEntry entry;
  var controller = TransformationController();
  Matrix4Tween snapTween;
  AnimationController snap;

  @override
  Widget build(BuildContext context) {
    var viewer = placeholder != null
        ? SizedBox.fromSize(size: placeholder.size)
        : buildViewer(context);

    return Card(
      child: viewer,
      clipBehavior: Clip.antiAlias,
    );
  }

  Widget buildViewer(BuildContext context) {
    return InteractiveViewer(
        key: viewerKey,
        transformationController: controller,
        panEnabled: false,
        child: Image.network(
            "https://upload.wikimedia.org/wikipedia/commons/6/6a/Mona_Lisa.jpg"),
        onInteractionStart: (details) {
          if (placeholder != null) return;

          setState(() {
            var renderObject =
                viewerKey.currentContext.findRenderObject() as RenderBox;
            placeholder = Rect.fromPoints(
              renderObject.localToGlobal(Offset.zero),
              renderObject
                  .localToGlobal(renderObject.size.bottomRight(Offset.zero)),
            );
          });

          entry = OverlayEntry(
            builder: (context) {
              return Positioned.fromRect(
                rect: placeholder,
                child: buildViewer(context),
              );
            },
          );

          Overlay.of(context).insert(entry);
        },
        onInteractionEnd: (details) {
          snapTween = Matrix4Tween(
            begin: controller.value,
            end: Matrix4.identity(),
          );
          snap.value = 0;
          snap.animateTo(
            1,
            duration: Duration(milliseconds: 250),
            curve: Curves.ease,
          );
        });
  }

  @override
  void initState() {
    super.initState();
    _controllerReset = AnimationController(
      duration: widget.resetDuration,
      vsync: this,
    );
    snap = AnimationController(vsync: this);
    snap.addListener(() {
      if (snapTween == null) return;
      controller.value = snapTween.evaluate(snap);
      if (snap.isCompleted) {
        entry.remove();
        entry = null;
        setState(() {
          placeholder = null;
        });
      }
    });
  }

  @override
  void dispose() {
    snap.dispose();

    _controllerReset.dispose();
    super.dispose();
  }

  /// Go back to static state after resetting has ended
  void _onAnimateReset() {
    _transformationController.value = _animationReset.value;
    if (!_controllerReset.isAnimating) {
      _animationReset.removeListener(_onAnimateReset);
      _animationReset = Matrix4Tween().animate(_controllerReset);
      _controllerReset.reset();
      if (widget.onZoomEnd != null) {
        widget.onZoomEnd!();
      }
    }
  }

  /// Start resetting the animation
  void _animateResetInitialize() {
    _controllerReset.reset();
    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(_controllerReset);
    _animationReset.addListener(_onAnimateReset);
    _controllerReset.forward();
  }

  /// Stop the reset animation
  void _animateResetStop() {
    _controllerReset.stop();
    _animationReset.removeListener(_onAnimateReset);
    _animationReset = Matrix4Tween().animate(_controllerReset);
    _controllerReset.reset();
  }
}
