import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/tinni_state.dart';
import '../auth/auth_service.dart';
import '../ui/royal_theme.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, String?> media = const <String, String?>{};
  bool loadingMedia = true;
  bool savingProfile = false;
  String? uploadingSlot;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final value = await widget.state.backend.profileMedia(account.authToken);
      if (!mounted) return;
      setState(() {
        media = value;
        loadingMedia = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingMedia = false);
    }
  }

  ImageProvider? _provider(String? value) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return null;
    if (source.startsWith('data:image/')) {
      try {
        return MemoryImage(base64Decode(source.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return NetworkImage(source);
    }
    return null;
  }

  Future<void> _copyUserId(String userId) async {
    await Clipboard.setData(ClipboardData(text: userId));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('ID copy ho gaya'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: RoyalPalette.gold,
              ),
              title: const Text('Select from phone album'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: RoyalPalette.gold,
              ),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadMedia(String slot) async {
    final account = widget.state.auth.current;
    if (account == null || uploadingSlot != null) return;
    final source = await _pickSource();
    if (source == null) return;
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 68,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 650000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a photo smaller than 650 KB.')),
      );
      return;
    }
    setState(() => uploadingSlot = slot);
    try {
      final url = await widget.state.backend.uploadProfileMedia(
        account.authToken,
        slot: slot,
        dataUrl: 'data:image/jpeg;base64,${base64Encode(bytes)}',
      );
      if (!mounted) return;
      setState(() {
        media = <String, String?>{...media, slot: url};
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => uploadingSlot = null);
    }
  }

  Future<void> _removeCover() async {
    final account = widget.state.auth.current;
    if (account == null || uploadingSlot != null || media['cover'] == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove cover photo?'),
        content: const Text(
          'The cover will stay on your profile until you explicitly remove '
          'or replace it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('profile-cover-remove-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => uploadingSlot = 'cover');
    try {
      await widget.state.backend.deleteProfileMedia(
        account.authToken,
        'cover',
      );
      if (!mounted) return;
      setState(() {
        media = <String, String?>{...media, 'cover': null};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Cover photo removed.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => uploadingSlot = null);
    }
  }

  Future<void> _editProfile() async {
    final account = widget.state.auth.current;
    if (account == null || savingProfile) return;

    final name = TextEditingController(text: account.displayName);
    final signature = TextEditingController(text: account.signature);
    String gender = account.gender == 'female' ? 'female' : 'male';
    String? birthday = account.birthday;
    String? avatarDataUrl = account.avatarDataUrl;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: RoyalPalette.nearBlack,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> chooseAvatar() async {
            final source = await _pickSource();
            if (source == null) return;
            final picked = await _picker.pickImage(
              source: source,
              imageQuality: 64,
              maxWidth: 512,
              maxHeight: 512,
            );
            if (picked == null) return;
            final bytes = await picked.readAsBytes();
            if (bytes.length > 320000) {
              if (!sheetContext.mounted) return;
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(
                  content: Text('Choose a smaller profile photo.'),
                ),
              );
              return;
            }
            setSheetState(() {
              avatarDataUrl =
                  'data:image/jpeg;base64,${base64Encode(bytes)}';
            });
          }

          final avatar = _provider(avatarDataUrl);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Edit profile',
                    style: TextStyle(
                      color: RoyalPalette.cream,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    key: const Key('profile-edit-avatar'),
                    onTap: chooseAvatar,
                    borderRadius: BorderRadius.circular(50),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: RoyalPalette.panel2,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? const Icon(
                              Icons.add_a_photo_rounded,
                              color: RoyalPalette.gold,
                              size: 30,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('profile-edit-name'),
                    controller: name,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'male',
                        icon: Icon(Icons.male_rounded),
                        label: Text('Male'),
                      ),
                      ButtonSegment(
                        value: 'female',
                        icon: Icon(Icons.female_rounded),
                        label: Text('Female'),
                      ),
                    ],
                    selected: <String>{gender},
                    onSelectionChanged: (value) {
                      setSheetState(() => gender = value.first);
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    key: const Key('profile-edit-birthday'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(
                      Icons.cake_rounded,
                      color: RoyalPalette.gold,
                    ),
                    title: const Text(
                      'Birthday',
                      style: TextStyle(color: RoyalPalette.cream),
                    ),
                    subtitle: Text(
                      birthday == null || birthday!.isEmpty
                          ? 'Set birthday'
                          : birthday!,
                      style: const TextStyle(color: RoyalPalette.muted),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: RoyalPalette.gold,
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      DateTime initial = DateTime(now.year - account.age, 1, 1);
                      if (birthday != null && birthday!.isNotEmpty) {
                        initial = DateTime.tryParse(birthday!) ?? initial;
                      }
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: initial,
                        firstDate: DateTime(now.year - 100),
                        lastDate: DateTime(now.year - 18, now.month, now.day),
                      );
                      if (picked == null) return;
                      final value =
                          '${picked.year.toString().padLeft(4, '0')}-'
                          '${picked.month.toString().padLeft(2, '0')}-'
                          '${picked.day.toString().padLeft(2, '0')}';
                      setSheetState(() => birthday = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('profile-edit-signature'),
                    controller: signature,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Signature / About me',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final value = name.text.trim();
                        if (value.isEmpty) return;
                        Navigator.pop(
                          sheetContext,
                          <String, dynamic>{
                            'display_name': value,
                            'signature': signature.text.trim(),
                            'gender': gender,
                            'birthday': birthday,
                            'avatar_data_url': avatarDataUrl,
                          },
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save profile'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    name.dispose();
    signature.dispose();
    if (result == null || !mounted) return;

    setState(() => savingProfile = true);
    try {
      final values = Map<String, dynamic>.from(result);
      final avatarValue = values['avatar_data_url']?.toString() ?? '';
      if (avatarValue.startsWith('data:image/')) {
        values['avatar_data_url'] =
            await widget.state.backend.uploadProfileMedia(
          account.authToken,
          slot: 'avatar',
          dataUrl: avatarValue,
        );
      }
      final row = await widget.state.backend.updateProfile(
        account.authToken,
        values,
      );
      final updated = TinniAccount.fromServer(
        row,
        token: account.authToken,
      );
      widget.state.auth.setAuthenticatedAccount(updated);
      widget.state.profile.loadFromAccount(updated);
      await widget.state.authPersistence?.save(updated);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.state.auth.current;
    if (account == null) {
      return const Scaffold(body: Center(child: Text('Login required')));
    }

    final avatar = _provider(account.avatarDataUrl);
    final cover = _provider(media['cover']);

    return Scaffold(
      key: const Key('personal-profile-screen'),
      backgroundColor: RoyalPalette.black,
      appBar: AppBar(
        title: const Text('Personal information'),
        actions: [
          IconButton(
            key: const Key('personal-profile-edit'),
            onPressed: savingProfile ? null : _editProfile,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          InkWell(
            key: const Key('profile-cover-photo'),
            onTap: () => _uploadMedia('cover'),
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: RoyalPalette.panel,
                image: cover == null
                    ? null
                    : DecorationImage(
                        image: cover,
                        fit: BoxFit.cover,
                      ),
              ),
              child: Stack(
                children: [
                  if (cover == null)
                    const Center(
                      child: Icon(
                        Icons.add_photo_alternate_rounded,
                        color: RoyalPalette.gold,
                        size: 42,
                      ),
                    ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: RoyalPalette.nearBlack,
                          backgroundImage: avatar,
                          child: avatar == null
                              ? Text(
                                  account.displayName.isEmpty
                                      ? '?'
                                      : account.displayName.characters.first
                                          .toUpperCase(),
                                  style: const TextStyle(
                                    color: RoyalPalette.gold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .58),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.displayName,
                                style: const TextStyle(
                                  color: RoyalPalette.cream,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              GestureDetector(
                                key: const Key('personal-profile-uid-long-press'),
                                behavior: HitTestBehavior.opaque,
                                onLongPress: () =>
                                    _copyUserId(account.userId),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Text(
                                    'UID: ${account.userId}',
                                    style: const TextStyle(
                                      color: RoyalPalette.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _UploadBadge(
                      busy: uploadingSlot == 'cover',
                      label: cover == null ? 'Add cover' : 'Change cover',
                    ),
                  ),
                  if (cover != null)
                    Positioned(
                      right: 12,
                      top: 52,
                      child: IconButton.filledTonal(
                        key: const Key('profile-cover-remove'),
                        tooltip: 'Remove cover',
                        onPressed:
                            uploadingSlot == null ? _removeCover : null,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: RoyalPanel(
              accentColor: RoyalPalette.deepGold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photos',
                    style: TextStyle(
                      color: RoyalPalette.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _ProfileMediaTile(
                          key: const Key('profile-life-1'),
                          label: 'Photos of life',
                          image: _provider(media['life_1']),
                          busy: uploadingSlot == 'life_1',
                          height: 150,
                          onTap: () => _uploadMedia('life_1'),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          children: [
                            _ProfileMediaTile(
                              key: const Key('profile-travel'),
                              label: 'Travel photo',
                              image: _provider(media['travel']),
                              busy: uploadingSlot == 'travel',
                              height: 70,
                              onTap: () => _uploadMedia('travel'),
                            ),
                            const SizedBox(height: 9),
                            _ProfileMediaTile(
                              key: const Key('profile-life-2'),
                              label: 'Life',
                              image: _provider(media['life_2']),
                              busy: uploadingSlot == 'life_2',
                              height: 70,
                              onTap: () => _uploadMedia('life_2'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  _ProfileMediaTile(
                    key: const Key('profile-life-3'),
                    label: 'Add another life photo',
                    image: _provider(media['life_3']),
                    busy: uploadingSlot == 'life_3',
                    height: 92,
                    onTap: () => _uploadMedia('life_3'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: RoyalPanel(
              accentColor: RoyalPalette.deepGold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Basic information',
                    style: TextStyle(
                      color: RoyalPalette.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Name', value: account.displayName),
                  _InfoRow(label: 'Age', value: account.age.toString()),
                  _InfoRow(
                    label: 'Birthday',
                    value: account.birthday == null || account.birthday!.isEmpty
                        ? 'Not set'
                        : account.birthday!,
                  ),
                  _InfoRow(
                    label: 'Gender',
                    value: account.gender.isEmpty ? 'Not set' : account.gender,
                  ),
                  _InfoRow(
                    label: 'Country',
                    value: '${account.flagEmoji} ${account.countryName}',
                  ),
                  _InfoRow(
                    label: 'Signature',
                    value: account.signature.trim().isEmpty
                        ? 'Nothing is written'
                        : account.signature,
                    multiline: true,
                  ),
                ],
              ),
            ),
          ),
          if (loadingMedia)
            const Padding(
              padding: EdgeInsets.all(18),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _UploadBadge extends StatelessWidget {
  const _UploadBadge({required this.busy, required this.label});

  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RoyalPalette.gold.withValues(alpha: .5),
        ),
      ),
      child: Text(
        busy ? 'Uploading…' : label,
        style: const TextStyle(
          color: RoyalPalette.gold,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileMediaTile extends StatelessWidget {
  const _ProfileMediaTile({
    super.key,
    required this.label,
    required this.image,
    required this.busy,
    required this.height,
    required this.onTap,
  });

  final String label;
  final ImageProvider? image;
  final bool busy;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: RoyalPalette.nearBlack,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: RoyalPalette.deepGold.withValues(alpha: .52),
          ),
          image: image == null
              ? null
              : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image == null)
              const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: RoyalPalette.gold,
                  size: 28,
                ),
              ),
            if (busy)
              const ColoredBox(
                color: Color(0x99000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            Positioned(
              left: 7,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .64),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: RoyalPalette.cream,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: RoyalPalette.muted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: multiline ? 4 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RoyalPalette.cream,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
