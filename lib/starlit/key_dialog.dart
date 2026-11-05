import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/material.dart'
    show
        InputDecoration,
        Material,
        MaterialType,
        OutlineInputBorder,
        SpellCheckConfiguration,
        TextField,
        TextInputAction,
        TextInputType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum StarlitAuthSource { telegram, cabinet, manual }

Future<String?> showStarlitKeyDialog(
  BuildContext context, {
  required StarlitAuthSource source,
  String? initial,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: const Color(0xCC05070D),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, anim, secondary) {
      return SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: anim,
            child: _KeyDialogBody(source: source, initial: initial),
          ),
        ),
      );
    },
  );
}

class _KeyDialogBody extends StatefulWidget {
  const _KeyDialogBody({required this.source, this.initial});

  final StarlitAuthSource source;
  final String? initial;

  @override
  State<_KeyDialogBody> createState() => _KeyDialogBodyState();
}

class _KeyDialogBodyState extends State<_KeyDialogBody> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _title => switch (widget.source) {
    StarlitAuthSource.telegram => 'Ссылка из Telegram-бота',
    StarlitAuthSource.cabinet => 'Ссылка из кабинета',
    StarlitAuthSource.manual => 'Ключ подписки',
  };

  String get _hint => switch (widget.source) {
    StarlitAuthSource.telegram =>
      'В боте @starlitvpnbot получите ссылку подписки и вставьте её сюда.',
    StarlitAuthSource.cabinet =>
      'Войдите в кабинет почтой или Telegram, скопируйте ссылку подписки и вставьте сюда.',
    StarlitAuthSource.manual =>
      'Вставьте ссылку вида https://$subscriptionHost/...',
  };

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      _error = null;
    });
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Вставьте ссылку подписки');
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.toLowerCase() != subscriptionHost) {
      setState(() => _error = 'Нужна ссылка с $subscriptionHost');
      return;
    }
    Navigator.of(context).pop(uri.replace(scheme: 'https', fragment: '').toString());
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StarlitCard(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StarlitText(
                        _title,
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: StarlitText(
                          'Закрыть',
                          size: 13,
                          color: StarlitColors.muted,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StarlitText(
                  _hint,
                  size: 13,
                  color: StarlitColors.muted,
                  height: 1.4,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  spellCheckConfiguration:
                      const SpellCheckConfiguration.disabled(),
                  style: starlitText(size: 14, color: StarlitColors.text),
                  cursorColor: StarlitColors.accent,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  maxLines: 3,
                  minLines: 2,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: StarlitColors.field,
                    hintText: 'https://$subscriptionHost/...',
                    hintStyle: starlitText(
                      size: 13,
                      color: StarlitColors.muted2,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: StarlitColors.stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: StarlitColors.accent,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  StarlitText(
                    _error!,
                    size: 13,
                    color: StarlitColors.danger,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StarlitGhostButton(
                        label: 'Из буфера',
                        onPressed: _pasteClipboard,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StarlitPrimaryButton(
                        label: 'Подключить',
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
