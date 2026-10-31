import 'package:flutter/material.dart';

import '../l10n/global_locale_controller.dart';
import '../services/app_controller.dart';

/// A private route belongs to the login that opened it. Once invalidated it
/// never adopts the next account; removing the child also disposes its caches,
/// controllers and drafts. Late completions see an unmounted child.
class GlobalAccountBoundary extends StatefulWidget {
  const GlobalAccountBoundary({
    required this.controller,
    required this.builder,
    super.key,
  });
  final AppController controller;
  final WidgetBuilder builder;

  @override
  State<GlobalAccountBoundary> createState() => _GlobalAccountBoundaryState();
}

class _GlobalAccountBoundaryState extends State<GlobalAccountBoundary> {
  Object? _owner;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _owner = widget.controller.accountViewIdentity;
    _invalid = _owner == null;
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!_invalid && widget.controller.accountViewIdentity != _owner) {
      setState(() => _invalid = true);
      // Dialogs and pushed routes live outside the child subtree. Close that
      // old navigation stack as well, otherwise a private form/photo dialog
      // could survive removal of the page that opened it.
      final navigator = Navigator.maybeOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator?.mounted == true) {
          navigator!.popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant GlobalAccountBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _invalid = true;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _invalid
      ? Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.signInToShopHint,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        )
      : widget.builder(context);
}
