import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../online/auth_service.dart';
import '../user/player_display_name.dart';

/// Hỏi tên hiển thị (khách hoặc Google). Trả về tên mới nếu đã lưu.
Future<String?> showEditDisplayNameDialog(
  BuildContext context, {
  String? initial,
}) {
  final auth = AuthService();
  var start = initial ?? auth.displayName;
  if (PlayerDisplayName.isDefaultGuestName(start)) start = '';

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EditDisplayNameDialog(initial: start),
  );
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  /// Đủ cho tên + họ không dấu; vừa ô lobby / avatar.
  static const maxNameLength = 16;
  static final _asciiName = RegExp(r'^[a-zA-Z0-9 ]+$');

  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  static final _fieldDecoration = InputDecoration(
    hintText: 'Ví dụ: Minh, Nguyen, Lan Anh',
    hintStyle: TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Color(0xFF1A0505),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0x44FFD54F)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0x33FFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFFFC400)),
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Tên cần ít nhất 2 ký tự.');
      return;
    }
    if (name.length > maxNameLength) {
      setState(() => _error = 'Tên tối đa $maxNameLength ký tự.');
      return;
    }
    if (!_asciiName.hasMatch(name)) {
      setState(() => _error = 'Chỉ dùng chữ không dấu, số và khoảng trắng.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await AuthService().updateDisplayName(name);
      if (!mounted) return;
      Navigator.of(context).pop(name);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Không lưu được tên. Thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A0707),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x44FFD54F)),
      ),
      title: const Text(
        'Tên hiển thị',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final length = _controller.text.length;
          final nearLimit = length >= maxNameLength - 2;

          return TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
              LengthLimitingTextInputFormatter(maxNameLength),
            ],
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration.copyWith(
              errorText: _error,
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              suffix: Text(
                '$length/$maxNameLength',
                style: TextStyle(
                  color: nearLimit
                      ? const Color(0xFFFFC400)
                      : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            onSubmitted: _saving ? null : (_) => _save(),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Huỷ', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFC400),
                  ),
                )
              : const Text(
                  'Lưu',
                  style: TextStyle(
                    color: Color(0xFFFFC400),
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
