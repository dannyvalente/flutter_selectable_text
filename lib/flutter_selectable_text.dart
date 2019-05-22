library flutter_selectable_text;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// InputlessFocusNode is a FocusNode that does not consume the keyboard token,
/// thereby preventing the keyboard from coming up when the node is focused
class InputlessFocusNode extends FocusNode {

  // this is a special override needed, because the EditableText class creates
  // a TextInputConnection if the node has focus to force the keyboard to come up
  // this override will cause our FocusNode to pretend it doesn't have focus
  // when needed
  bool _overrideFocus;

  @override
  bool get hasFocus => _overrideFocus ?? super.hasFocus;

  @override
  bool consumeKeyboardToken() {
    return false;
  }
}

/// SelectableText widget
/// It allows to display text given the style, text alignment, and text direction
/// It will also allow the user to select text, and stop that selection by tapping anywhere
/// on the text widget
/// It will also allow to copy the text, and unfortunately, the Paste action will also appear
/// but will be a no-op
class SelectableText extends StatefulWidget {

  const SelectableText(this.text, {
    Key key,
    this.focusNode,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.cursorRadius,
    this.cursorColor,
    this.dragStartBehavior = DragStartBehavior.down,
    this.enableInteractiveSelection = true,
    this.onTap
  }) : super(key: key);

  final String text;
  final InputlessFocusNode focusNode;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Radius cursorRadius;
  final Color cursorColor;
  final bool enableInteractiveSelection;
  final DragStartBehavior dragStartBehavior;
  final GestureTapCallback onTap;

  _SelectableTextState createState() => _SelectableTextState();
}

class _SelectableTextState extends State<SelectableText> {

  final GlobalKey<EditableTextState> _editableTextKey = GlobalKey<EditableTextState>();

  TextEditingController _controller;

  InputlessFocusNode _focusNode;
  InputlessFocusNode get _effectiveFocusNode => widget.focusNode ?? (_focusNode ??= InputlessFocusNode());

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(SelectableText oldWidget) {

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  RenderEditable get _renderEditable => _editableTextKey.currentState.renderEditable;

  void _handleTapDown(TapDownDetails details) {
    _renderEditable.handleTapDown(details);
  }

  void _handleSingleTapUp(TapUpDetails details) {
    _effectiveFocusNode.unfocus();
    if (widget.onTap != null) {
      widget.onTap();
    }
  }

  void _handleSingleLongTapStart(LongPressStartDetails details) {
    // the EditableText widget will force the keyboard to come up if our focus node
    // is already focused. It does this by using a TextInputConnection
    // In order to tool it not to do that, we override our focus while selecting text
    _effectiveFocusNode._overrideFocus = false;

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        _renderEditable.selectPositionAt(
          from: details.globalPosition,
          cause: SelectionChangedCause.longPress,
        );
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        _renderEditable.selectWord(cause: SelectionChangedCause.longPress);
        Feedback.forLongPress(context);
        break;
    }

    // Stop overriding our focus
    _effectiveFocusNode._overrideFocus = null;
  }

  void _handleSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    // the EditableText widget will force the keyboard to come up if our focus node
    // is already focused. It does this by using a TextInputConnection
    // In order to tool it not to do that, we override our focus while selecting text
    _effectiveFocusNode._overrideFocus = false;

    _renderEditable.selectWordsInRange(
      from: details.globalPosition - details.offsetFromOrigin,
      to: details.globalPosition,
      cause: SelectionChangedCause.longPress,
    );

    //Stop overriding our focus
    _effectiveFocusNode._overrideFocus = null;
  }

  void _handleSingleLongTapEnd(LongPressEndDetails details) {
    _editableTextKey.currentState.showToolbar();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _renderEditable.selectWord(cause: SelectionChangedCause.doubleTap);
    _editableTextKey.currentState.showToolbar();
  }

  void _handleSelectionChanged(TextSelection selection, SelectionChangedCause cause) {
    // iOS cursor doesn't move via a selection handle. The scroll happens
    // directly from new text selection changes.
    if (Theme.of(context).platform == TargetPlatform.iOS
        && cause == SelectionChangedCause.longPress) {
      _editableTextKey.currentState?.bringIntoView(selection.base);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    // TODO(jonahwilliams): uncomment out this check once we have migrated tests.
    // assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));
    assert(
    !(widget.style != null && widget.style.inherit == false &&
        (widget.style.fontSize == null || widget.style.textBaseline == null)),
    'inherit false style must supply fontSize and textBaseline',
    );

    final ThemeData themeData = Theme.of(context);
    final TextStyle style = themeData.textTheme.subhead.merge(widget.style);
    final FocusNode focusNode = _effectiveFocusNode;

    TextSelectionControls textSelectionControls;
    bool paintCursorAboveText;
    bool cursorOpacityAnimates;
    Offset cursorOffset;
    Color cursorColor = widget.cursorColor;
    Radius cursorRadius = widget.cursorRadius;

    switch (themeData.platform) {
      case TargetPlatform.iOS:
        textSelectionControls = _TextSelectionControls(cupertinoTextSelectionControls);
        paintCursorAboveText = true;
        cursorOpacityAnimates = true;
        cursorColor ??= CupertinoTheme.of(context).primaryColor;
        cursorRadius ??= const Radius.circular(2.0);
        // An eyeballed value that moves the cursor slightly left of where it is
        // rendered for text on Android so its positioning more accurately matches the
        // native iOS text cursor positioning.
        //
        // This value is in device pixels, not logical pixels as is typically used
        // throughout the codebase.
        const int _iOSHorizontalOffset = -2;
        cursorOffset = Offset(_iOSHorizontalOffset / MediaQuery.of(context).devicePixelRatio, 0);
        break;

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        textSelectionControls = _TextSelectionControls(materialTextSelectionControls);
        paintCursorAboveText = false;
        cursorOpacityAnimates = false;
        cursorColor ??= themeData.cursorColor;
        break;
    }

    Widget child = RepaintBoundary(
      child: _EditableText(
        key: _editableTextKey,
        controller: _controller,
        focusNode: focusNode,
        style: style,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        maxLines: null,
        selectionColor: themeData.textSelectionColor,
        selectionControls: widget.enableInteractiveSelection ? textSelectionControls : null,
        onSelectionChanged: _handleSelectionChanged,
        rendererIgnoresPointer: true,
        cursorWidth: 0,
        cursorRadius: cursorRadius,
        cursorColor: cursorColor,
        cursorOpacityAnimates: cursorOpacityAnimates,
        cursorOffset: cursorOffset,
        paintCursorAboveText: paintCursorAboveText,
        backgroundCursorColor: CupertinoColors.inactiveGray,
        enableInteractiveSelection: widget.enableInteractiveSelection,
        dragStartBehavior: widget.dragStartBehavior,
      ),
    );

    return Semantics(
      child: TextSelectionGestureDetector(
        onTapDown: _handleTapDown,
        onSingleTapUp: _handleSingleTapUp,
        onSingleLongTapStart: _handleSingleLongTapStart,
        onSingleLongTapMoveUpdate: _handleSingleLongTapMoveUpdate,
        onSingleLongTapEnd: _handleSingleLongTapEnd,
        onDoubleTapDown: _handleDoubleTapDown,
        behavior: HitTestBehavior.translucent,
        child: child,
      ),
    );
  }
}

/// The _EditableText class extends the [EditableText] class because
/// for two reasons
/// 1) The [EditableText] widget adds a [Scrollable] widget in the subtree
/// so that it can scroll the text if needed (remember, it's supposed to be an input field)
/// This doesn't seem to cause any problems when the TextStyle's line height
/// is set to 1.0, but when it's greater, the text springs up and down when selecting
/// text. We actually remove the [Scrollable] from the subtree, and instead, just
/// place it in a Column widget (because a scroll controller still exists in the [Editabletext]
/// so we need it to be attached to an actual [Scrollable].
/// Then, we create our own FakeRenderBox so that it can set the viewport to 0.0
/// on the [Scrollable]
/// 2) When the selection toolbar does a copy or paste operation, it then calls
/// hideToolbar() on the EditableTextState, but that method doesn't unfocus our node
/// so we do
class _EditableText extends EditableText {

  _EditableText({
    Key key,
    @required TextEditingController controller,
    @required FocusNode focusNode,
    @required TextStyle style,
    @required Color cursorColor,
    @required Color backgroundCursorColor,
    TextAlign textAlign = TextAlign.start,
    TextDirection textDirection,
    int maxLines = 1,
    Color selectionColor,
    TextSelectionControls selectionControls,
    SelectionChangedCallback onSelectionChanged,
    bool rendererIgnoresPointer = false,
    double cursorWidth = 2.0,
    Radius cursorRadius,
    bool cursorOpacityAnimates = false,
    Offset cursorOffset,
    bool paintCursorAboveText = false,
    DragStartBehavior dragStartBehavior = DragStartBehavior.down,
    bool enableInteractiveSelection,
  }) : super(
    key: key,
    controller: controller,
    focusNode: focusNode,
    style: style,
    cursorColor: cursorColor,
    backgroundCursorColor: backgroundCursorColor,
    textAlign: textAlign,
    textDirection: textDirection,
    maxLines: maxLines,
    selectionColor: selectionColor,
    selectionControls: selectionControls,
    onSelectionChanged: onSelectionChanged,
    rendererIgnoresPointer: rendererIgnoresPointer,
    cursorWidth: cursorWidth,
    cursorRadius: cursorRadius,
    cursorOpacityAnimates: cursorOpacityAnimates,
    cursorOffset: cursorOffset,
    paintCursorAboveText: paintCursorAboveText,
    dragStartBehavior: dragStartBehavior,
    enableInteractiveSelection: enableInteractiveSelection,
  );

  _EditableTextState createState() => _EditableTextState();
}

class _EditableTextState extends EditableTextState {

  @override
  void hideToolbar() {
    // unfocus our node instead of just hiding the toolbar because we don't
    // want to keep focus anymore
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    Widget widget = super.build(context);
    assert(widget is Scrollable);
    Scrollable scrollable = widget;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Scrollable(
            excludeFromSemantics: true,
            axisDirection: AxisDirection.right,
            controller: scrollable.controller,
            physics: const NeverScrollableScrollPhysics(),
            dragStartBehavior: scrollable.dragStartBehavior,
            viewportBuilder: (context, offset) {
              // create a _FakeRenderObject so that it can safely set
              // a viewport of 0.0 on the Scrollable so that everything is
              // happy
              return _FakeRenderObject(offset: offset);
            }
        ),
        scrollable.viewportBuilder(context, ViewportOffset.zero())
      ],
    );
  }
}

/// FakeRenderObject
class _FakeRenderObject extends LeafRenderObjectWidget {

  _FakeRenderObject({@required this.offset});

  final ViewportOffset offset;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _FakeRenderBox(offset: offset);
  }

  @override
  void updateRenderObject(BuildContext context, _FakeRenderBox renderObject) {
    renderObject
      ..offset = offset;
  }
}

/// FakeRenderBox
class _FakeRenderBox extends RenderBox {

  _FakeRenderBox({
    @required ViewportOffset offset
  }) : assert(offset != null),
       _offset = offset;

  ViewportOffset get offset => _offset;
  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    assert(value != null);
    if (_offset == value)
      return;
    if (attached)
      _offset.removeListener(markNeedsPaint);
    _offset = value;
    if (attached)
      _offset.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _offset.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    assert(_offset != null);
    size = Size(constraints.minWidth, constraints.minHeight);
    _offset.applyViewportDimension(0.0);
    _offset.applyContentDimensions(0.0, 0.0);
  }
}

/// _TextSelectionDelegateHelper is used to ensure the Cut option in the toolbar
/// doesn't show, and a Paste operation does nothing
class _TextSelectionDelegateHelper extends TextSelectionDelegate {

  _TextSelectionDelegateHelper(this.delegate);

  final TextSelectionDelegate delegate;

  int _overridenCollapsed = 0;

  TextEditingValue get textEditingValue {
    // as soon as this helper class is instantiated, canCut(), canCopy(), and canPaste()
    // will get called. Both canCut() and canCopy() will call this delegate getter
    // so we can return a collapsed value on the first call
    // Unfortunately, the canPaste() call returns true and there's no way to do anything
    // to prevent that, short of copying all the code from cupertino/text_selection.dart
    if (_overridenCollapsed < 1) {
      _overridenCollapsed++;
      return delegate.textEditingValue.copyWith(selection: TextSelection.collapsed(offset: 0));
    }
    return delegate.textEditingValue;
  }

  set textEditingValue(TextEditingValue value) {
    // because we can't disable the Paste toolbar option, let's make sure we don't
    // allow to actually paste data by always keeping the same text we had before
    delegate.textEditingValue = value.copyWith(text: delegate.textEditingValue.text);
  }

  void hideToolbar() {
    delegate.hideToolbar();
  }

  void bringIntoView(TextPosition position) {
    delegate.bringIntoView(position);
  }
}


/// _TextSelectionControls just wraps the platform specific controls object
/// and passes it our own _TextSelectionDelegateHelper delegate
class _TextSelectionControls extends TextSelectionControls {

  _TextSelectionControls(this._platformTextSelectionControls);

  final TextSelectionControls _platformTextSelectionControls;

  @override
  Size get handleSize => _platformTextSelectionControls.handleSize;

  /// Builder for iOS-style copy/paste text selection toolbar.
  @override
  Widget buildToolbar(
      BuildContext context,
      Rect globalEditableRegion,
      Offset position,
      List<TextSelectionPoint> endpoints,
      TextSelectionDelegate delegate) {
    return _platformTextSelectionControls.buildToolbar(
        context,
        globalEditableRegion,
        position,
        endpoints,
        _TextSelectionDelegateHelper(delegate));
  }

  /// Builder for iOS text selection edges.
  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight) {
    return _platformTextSelectionControls.buildHandle(context, type, textLineHeight);
  }
}
