import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/tinni_state.dart';
import '../ui/royal_theme.dart';
import 'moderation_service.dart';

enum _UserSafetyAction {
  blockToggle,
  report,
}

class UserSafetyMenuButton extends StatelessWidget {
  const UserSafetyMenuButton({
    super.key,
    required this.state,
    required this.targetUserId,
    required this.targetDisplayName,
    this.roomId,
    this.iconColor = RoyalPalette.gold,
    this.onBlockChanged,
  });

  final TinniState state;
  final String targetUserId;
  final String targetDisplayName;
  final String? roomId;
  final Color iconColor;
  final VoidCallback? onBlockChanged;

  bool get _isSelf => state.auth.current?.userId == targetUserId;

  @override
  Widget build(BuildContext context) {
    final blocked = state.social.blocked.contains(targetUserId);
    return PopupMenuButton<_UserSafetyAction>(
      key: Key('user-safety-menu-$targetUserId'),
      tooltip: 'More',
      icon: Icon(Icons.more_vert_rounded, color: iconColor),
      onSelected: (action) async {
        if (_isSelf) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Block and report are not available for your own ID.'),
            ),
          );
          return;
        }

        switch (action) {
          case _UserSafetyAction.blockToggle:
            final account = state.auth.current;
            if (account == null) return;
            try {
              await state.social.setBlockedRemote(
                authToken: account.authToken,
                targetUserId: targetUserId,
                value: !blocked,
              );
              onBlockChanged?.call();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    blocked
                        ? '$targetDisplayName unblocked.'
                        : '$targetDisplayName blocked.',
                  ),
                ),
              );
            } catch (error) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    error.toString().replaceFirst('Bad state: ', ''),
                  ),
                ),
              );
            }
            break;
          case _UserSafetyAction.report:
            await showReportUserSheet(
              context: context,
              state: state,
              targetUserId: targetUserId,
              targetDisplayName: targetDisplayName,
              roomId: roomId,
            );
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_UserSafetyAction>>[
        PopupMenuItem<_UserSafetyAction>(
          value: _UserSafetyAction.blockToggle,
          enabled: !_isSelf,
          child: Row(
            children: [
              Icon(
                blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(blocked ? 'Unblock' : 'Block'),
            ],
          ),
        ),
        PopupMenuItem<_UserSafetyAction>(
          value: _UserSafetyAction.report,
          enabled: !_isSelf,
          child: const Row(
            children: [
              Icon(Icons.flag_rounded, size: 20),
              SizedBox(width: 10),
              Text('Report'),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showReportUserSheet({
  required BuildContext context,
  required TinniState state,
  required String targetUserId,
  required String targetDisplayName,
  String? roomId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: RoyalPalette.nearBlack,
    builder: (context) => _ReportUserSheet(
      state: state,
      targetUserId: targetUserId,
      targetDisplayName: targetDisplayName,
      roomId: roomId,
    ),
  );
}

class _ReportUserSheet extends StatefulWidget {
  const _ReportUserSheet({
    required this.state,
    required this.targetUserId,
    required this.targetDisplayName,
    this.roomId,
  });

  final TinniState state;
  final String targetUserId;
  final String targetDisplayName;
  final String? roomId;

  @override
  State<_ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<_ReportUserSheet> {
  final Set<String> _selectedReasons = <String>{};
  final TextEditingController _otherController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<String> _screenshots = <String>[];
  bool _submitting = false;

  bool get _otherSelected => _selectedReasons.contains('other');

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  String _dataPrefixForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'data:image/png;base64,';
    if (lower.endsWith('.webp')) return 'data:image/webp;base64,';
    return 'data:image/jpeg;base64,';
  }

  Future<void> _addScreenshot() async {
    if (_screenshots.length >= 5) return;

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 58,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    if (bytes.length > 700000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a smaller screenshot (under 700 KB).'),
        ),
      );
      return;
    }

    setState(() {
      _screenshots.add(
        _dataPrefixForPath(image.path) + base64Encode(bytes),
      );
    });
  }

  Future<void> _submit() async {
    if (_selectedReasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one report reason.')),
      );
      return;
    }
    if (_otherSelected && _otherController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write the reason in Other.')),
      );
      return;
    }

    final account = widget.state.auth.current;
    if (account == null) return;

    setState(() => _submitting = true);
    try {
      await widget.state.moderation.submitUserReport(
        authToken: account.authToken,
        reporterId: account.userId,
        targetUserId: widget.targetUserId,
        targetDisplayName: widget.targetDisplayName,
        categories: _selectedReasons.toList(growable: false),
        otherDetails: _otherController.text,
        screenshots: _screenshots,
        roomId: widget.roomId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted to Tinni Star moderation.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.88,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Report ${widget.targetDisplayName}',
                  style: const TextStyle(
                    color: RoyalPalette.gold,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ID ${widget.targetUserId} • Select one or more reasons',
                  style: const TextStyle(
                    color: RoyalPalette.muted,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final reason in reportReasons)
                      CheckboxListTile(
                        key: Key('report-reason-${reason.key}'),
                        dense: true,
                        value: _selectedReasons.contains(reason.key),
                        activeColor: RoyalPalette.gold,
                        checkColor: Colors.black,
                        title: Text(
                          reason.label,
                          style: const TextStyle(
                            color: RoyalPalette.cream,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedReasons.add(reason.key);
                            } else {
                              _selectedReasons.remove(reason.key);
                            }
                          });
                        },
                      ),
                    if (_otherSelected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                        child: TextField(
                          key: const Key('report-other-details'),
                          controller: _otherController,
                          maxLength: 600,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Other — write the reason',
                            hintText: 'Describe what happened…',
                          ),
                        ),
                      ),
                    const Divider(color: RoyalPalette.deepGold),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Screenshots (optional)',
                                  style: TextStyle(
                                    color: RoyalPalette.cream,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'You can submit without a screenshot, or add 1 to 5.',
                                  style: TextStyle(
                                    color: RoyalPalette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${_screenshots.length}/5',
                            style: const TextStyle(
                              color: RoyalPalette.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_screenshots.isNotEmpty)
                      SizedBox(
                        height: 82,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: _screenshots.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final raw = _screenshots[index].split(',').last;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    base64Decode(raw),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: -7,
                                  top: -7,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _screenshots.removeAt(index);
                                      });
                                    },
                                    child: const CircleAvatar(
                                      radius: 11,
                                      backgroundColor: Colors.black87,
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: OutlinedButton.icon(
                        key: const Key('report-add-screenshot'),
                        onPressed:
                            _screenshots.length >= 5 ? null : _addScreenshot,
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: Text(
                          _screenshots.length >= 5
                              ? 'Maximum 5 screenshots added'
                              : 'Add screenshot',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('report-submit'),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_rounded),
                  label: Text(
                    _submitting ? 'Submitting…' : 'Submit report',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
