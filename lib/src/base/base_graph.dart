import 'dart:async';
import 'dart:math';

import 'package:custom_interactive_viewer/custom_interactive_viewer.dart';
import 'package:flutter/material.dart';
import 'package:org_chart/src/base/base_controller.dart';
import 'package:org_chart/src/base/edge_painter_utils.dart';
import 'package:org_chart/src/common/node.dart';
import 'package:org_chart/src/common/node_builder_details.dart';

/// Base abstract graph widget that provides common functionality for all graph types
abstract class BaseGraph<E> extends StatefulWidget {
  /// The controller that manages the data and layout
  final BaseGraphController<E> controller;

  /// The builder function used to build the nodes
  final Widget Function(NodeBuilderDetails<E> details) builder;

  // Graph configurations
  final bool isDraggable;
  final Curve curve;
  final Duration duration;
  final Paint linePaint;
  final double cornerRadius;
  final GraphArrowStyle arrowStyle;
  final LineEndingType lineEndingType;

  // Callback functions
  final List<PopupMenuEntry<dynamic>> Function(E item)? optionsBuilder;
  final void Function(E item, dynamic value)? onOptionSelect;

  /// Callback to expose the interactive viewer controller
  final CustomInteractiveViewerController? viewerController;

  // Interactive viewer configurations
  final InteractionConfig? interactionConfig;
  final KeyboardConfig? keyboardConfig;
  final ZoomConfig? zoomConfig;
  final FocusNode? focusNode;

  BaseGraph({
    super.key,
    required this.controller,
    required this.builder,
    this.isDraggable = true,
    this.curve = Curves.elasticOut,
    this.duration = const Duration(milliseconds: 700),
    Paint? linePaint,
    this.optionsBuilder,
    this.onOptionSelect,
    this.arrowStyle = const SolidGraphArrow(),
    this.cornerRadius = 10.0,
    this.lineEndingType = LineEndingType.arrow,
    this.viewerController,
    this.interactionConfig,
    this.keyboardConfig,
    this.zoomConfig,
    this.focusNode,
  }) : linePaint = linePaint ??
            (Paint()
              ..color = Colors.black
              ..strokeWidth = 0.5
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round);
}

/// Base state class for graph widgets
abstract class BaseGraphState<E, T extends BaseGraph<E>> extends State<T> {
  @protected
  List<Node<E>> overlapping = [];
  @protected
  String? draggedID;
  @protected
  Offset? panDownPosition;
  @protected
  late final CustomInteractiveViewerController viewerController;

  // Drag operations state
  @protected
  Node<E>? lastDraggedNode;

  // Protected getters for subclasses
  @protected
  List<Node<E>> get overlappingNodes => overlapping;

  @override
  void initState() {
    super.initState();
    viewerController =
        widget.viewerController ?? CustomInteractiveViewerController();
    _initializeController();
  }

  void _initializeController() {
    widget.controller.setState = setState;
    widget.controller.centerGraph = viewerController.center;
    widget.controller.setViewerController(viewerController);

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   viewerController.center();
    // });
  }

  @override
  void dispose() {
    if (widget.viewerController == null) {
      viewerController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.controller.getSize();
    return CustomInteractiveViewer(
      controller: viewerController,
      contentSize: size,
      interactionConfig: widget.interactionConfig ?? const InteractionConfig(),
      keyboardConfig: widget.keyboardConfig ?? const KeyboardConfig(),
      zoomConfig: widget.zoomConfig ?? const ZoomConfig(),
      focusNode: widget.focusNode,
      child: RepaintBoundary(
        key: widget.controller.repaintBoundaryKey,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: buildGraphElements(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the elements of the graph
  List<Widget> buildGraphElements(BuildContext context);

  /// Build the nodes of the graph
  List<Widget> buildNodes(BuildContext context,
      {List<Node<E>>? nodesToDraw, bool hidden = false, int level = 1});

  /// Build the lines/edges between nodes
  Widget buildEdges();

  // Common node interaction methods
  void handleTapDown(TapDownDetails details) {
    panDownPosition = details.globalPosition;
  }

  void toggleHideNodes(Node<E> node, bool? hide, bool center) {
    final newValue = hide ?? !node.hideNodes;
    if (newValue == node.hideNodes) return;

    setState(() {
      node.hideNodes = newValue;
      widget.controller.calculatePosition(center: center);
    });
  }

  void startDragging(Node<E> node) {
    draggedID = widget.controller.idProvider(node.data);
    setState(() {});
  }

  void updateDragging(Node<E> node, DragUpdateDetails details,
      {bool dragHorizontally = false}) {
    // Update position immediately for smooth visual feedback
    node.position = Offset(
      max(0, node.position.dx + details.delta.dx),
      dragHorizontally
          ? node.position.dy
          : max(0, node.position.dy + details.delta.dy),
    );

    // Calculate overlapping immediately for real-time visual feedback
    overlapping = widget.controller.getOverlapping(node);

    // Store the node for any additional operations
    lastDraggedNode = node;

    // Trigger UI update with immediate overlap calculation
    setState(() {});
  }

  Future<void> showNodeMenu(BuildContext context, Node<E> node) async {
    final options = widget.optionsBuilder?.call(node.data) ?? [];
    if (options.isEmpty) return;

    final RenderObject? overlay =
        Overlay.of(context).context.findRenderObject();
    if (panDownPosition == null || overlay == null) return;

    final result = await showMenu(
      context: context,
      position: RelativeRect.fromRect(
          Rect.fromLTWH(panDownPosition!.dx, panDownPosition!.dy, 0, 0),
          Rect.fromLTWH(0, 0, overlay.paintBounds.size.width,
              overlay.paintBounds.size.height)),
      items: options,
    );

    widget.onOptionSelect?.call(node.data, result);
  }

  // Getter for accessing the controller with the correct type
  BaseGraphController<E> get controller => widget.controller;
}
