import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/player_identity.dart';
import '../../data/providers.dart';
import '../theme/app_colors.dart';
import '../tracking/tracking_map.dart' show parseHex;
import 'account_action.dart' show PlayerAvatar;
import 'profile_banner.dart';

/// The colours a player can fly.
///
/// A fixed set rather than a full picker: these are drawn over a map, so they have to stay
/// legible against it and distinct from the seeded rivals.
const List<String> playerColours = [
  '#FF6B35',
  '#E8412C',
  '#F2B705',
  '#2E86DE',
  '#27AE60',
  '#8E44AD',
];

/// Everything about your profile, edited in one place and saved together.
///
/// Nothing is written until Save: the fields are a draft, so closing with ✕ really does leave
/// the profile as it was — including a picture that was picked but not kept.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({required this.player, super.key});

  final PlayerIdentity player;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();

  late final PlayerIdentity _player = widget.player;
  late final TextEditingController _name = TextEditingController(
    text: _player.usesAccountName ? '' : _player.name,
  );
  late final TextEditingController _handle = TextEditingController(
    text: _player.handle ?? '',
  );
  late final TextEditingController _status = TextEditingController(
    text: _player.status ?? '',
  );
  late final TextEditingController _bio = TextEditingController(
    text: _player.bio ?? '',
  );
  late String _colour = _player.colorHex;

  /// A newly picked picture, still in the picker's cache until Save keeps it.
  String? _pickedPhoto;
  bool _removePhoto = false;
  bool _saving = false;

  late final String _initialName = _name.text;
  late final String _initialHandle = _handle.text;
  late final String _initialStatus = _status.text;
  late final String _initialBio = _bio.text;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _handle, _status, _bio]) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _handle, _status, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _dirty =>
      _name.text.trim() != _initialName.trim() ||
      _handle.text.trim() != _initialHandle.trim() ||
      _status.text.trim() != _initialStatus.trim() ||
      _bio.text.trim() != _initialBio.trim() ||
      _colour.toUpperCase() != _player.colorHex.toUpperCase() ||
      _pickedPhoto != null ||
      _removePhoto;

  /// What the avatar shows right now, draft included.
  String? get _previewPhoto =>
      _removePhoto ? null : (_pickedPhoto ?? _player.photoPath);

  Future<void> _changePhoto() async {
    final hasPhoto = _previewPhoto != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Profile picture')),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text('Remove picture'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      setState(() {
        _pickedPhoto = null;
        _removePhoto = true;
      });
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        // An avatar is drawn at most a few hundred pixels across.
        maxWidth: 800,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _pickedPhoto = picked.path;
        _removePhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the picture: $error')),
      );
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final store = ref.read(profilePhotoStoreProvider);
      if (_pickedPhoto != null) {
        final kept = await store.replace(
          _pickedPhoto!,
          previousPath: _player.photoPath,
        );
        await _player.setPhotoPath(kept);
      } else if (_removePhoto && _player.photoPath != null) {
        await store.remove(_player.photoPath!);
        await _player.setPhotoPath(null);
      }

      await _player.setName(_name.text);
      await _player.setHandle(_handle.text);
      await _player.setStatus(_status.text);
      await _player.setBio(_bio.text);
      await _player.setColorHex(_colour);

      // Name, colour and picture are stamped onto every claim and leaderboard row, so
      // everything built from the identity is rebuilt.
      ref.invalidate(playerIdentityProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $error')),
      );
    }
  }

  /// Closing with unsaved changes asks first; with none it just closes.
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits to the profile have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dirty = _dirty;
    final draftName = _name.text.trim().isEmpty ? _player.name : _name.text.trim();

    return PopScope(
      canPop: !dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Edit profile'),
          actions: [
            TextButton(
              // Greyed out until there is something to save.
              onPressed: dirty && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ProfileBanner(
                colorHex: _colour,
                avatar: Semantics(
                  button: true,
                  label: 'Change profile picture',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: kIsWeb || _saving ? null : _changePhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ProfileAvatarRing(
                          child: PlayerAvatar(
                            name: draftName,
                            colorHex: _colour,
                            photoUrl: _removePhoto ? null : _player.photoUrl,
                            photoPath: _previewPhoto,
                            radius: 46,
                          ),
                        ),
                        if (!kIsWeb)
                          const Positioned(
                            right: 4,
                            top: 4,
                            child: _EditBadge(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(
                      label: 'Display name',
                      child: TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        maxLength: 30,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: _player.usesAccountName
                              ? _player.name
                              : 'How you appear on the leaderboard',
                          counterText: '',
                          suffixIcon: _ClearButton(controller: _name),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Username',
                      child: TextFormField(
                        controller: _handle,
                        enabled: !_saving,
                        maxLength: 20,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          prefixText: '@',
                          hintText: 'trail_runner',
                          counterText: '',
                          suffixIcon: _ClearButton(controller: _handle),
                        ),
                        validator: (value) {
                          final raw = (value ?? '').trim();
                          if (raw.isEmpty) return null;
                          final handle = PlayerIdentity.normaliseHandle(raw);
                          return PlayerIdentity.handlePattern.hasMatch(handle)
                              ? null
                              : '2–20 characters: letters, numbers, . and _';
                        },
                      ),
                    ),
                    _Field(
                      label: 'Status',
                      child: TextFormField(
                        controller: _status,
                        enabled: !_saving,
                        maxLength: 60,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'Training for a 10k',
                          prefixIcon: const Icon(Icons.bolt_rounded),
                          counterText: '',
                          suffixIcon: _ClearButton(controller: _status),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'About me',
                      child: TextFormField(
                        controller: _bio,
                        enabled: !_saving,
                        maxLength: 190,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Favourite routes, goals, anything.',
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Colour',
                      helper: 'The ground you hold is drawn in this colour.',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final hex in playerColours)
                            _ColourDot(
                              hex: hex,
                              selected: hex.toUpperCase() == _colour.toUpperCase(),
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _colour = hex),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      'Your picture, username, status and bio are kept on this device.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.helper});

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// The ⓧ inside a field, shown only when there is something to clear.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.text.isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Clear',
      icon: const Icon(Icons.cancel_rounded, size: 20),
      onPressed: controller.clear,
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.bg, width: 3),
      ),
      child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.text),
    );
  }
}

class _ColourDot extends StatelessWidget {
  const _ColourDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(hex, AppColors.accent);

    return Semantics(
      selected: selected,
      button: true,
      label: 'Colour $hex',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // A lime ring for the chosen one, reading as "selected" in the app's own voice
            // rather than in the swatch's colour.
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : null,
          ),
        ),
      ),
    );
  }
}
