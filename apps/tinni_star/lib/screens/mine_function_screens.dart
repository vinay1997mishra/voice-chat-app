import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app/tinni_state.dart';
import '../auth/app_auth_api.dart';
import '../i18n/tinni_localization.dart';
import 'login_screen.dart';

const _mineBg = Color(0xFF030201);
const _minePanel = Color(0xFF0B0804);
const _minePanel2 = Color(0xFF151006);
const _mineText = Color(0xFFC18A00);
const _mineMuted = Color(0xFF9C7000);
const _mineBorder = Color(0xFF5F4600);

ImageProvider? _avatarProvider(String? value) {
  final source = value?.trim() ?? '';
  if (source.isEmpty) return null;
  if (source.startsWith('data:image/')) {
    try {
      return MemoryImage(base64Decode(source.split(',').last));
    } catch (_) {
      return null;
    }
  }
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return NetworkImage(source);
  }
  return null;
}

String _dateText(dynamic value) {
  final ms = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  if (ms == null || ms <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}


class _MineSubpageBackground extends StatelessWidget {
  const _MineSubpageBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF070502),
            Color(0xFF030201),
            Color(0xFF000000),
          ],
        ),
      ),
      child: CustomPaint(
        painter: const _MineSubpageStarsPainter(),
        child: child,
      ),
    );
  }
}

class _MineSubpageStarsPainter extends CustomPainter {
  const _MineSubpageStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..style = PaintingStyle.fill;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65;

    for (var i = 0; i < 72; i += 1) {
      final x = (((i * 43) % 983) / 983) * size.width;
      final y = (((i * 79) % 977) / 977) * size.height;
      final bright = i % 12 == 0;
      dot.color = bright
          ? const Color(0xFFC18A00)
          : Color.fromARGB(90 + (i % 4) * 18, 170, 120, 0);
      canvas.drawCircle(
        Offset(x, y),
        bright ? 1.35 : 0.45 + (i % 3) * 0.18,
        dot,
      );
      if (bright) {
        glow.color = const Color(0x55C18A00);
        canvas.drawLine(Offset(x - 3.2, y), Offset(x + 3.2, y), glow);
        canvas.drawLine(Offset(x, y - 3.2), Offset(x, y + 3.2), glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MineSubpageStarsPainter oldDelegate) => false;
}

class MedalOfHonorScreen extends StatefulWidget {
  const MedalOfHonorScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<MedalOfHonorScreen> createState() => _MedalOfHonorScreenState();
}

class _MedalOfHonorScreenState extends State<MedalOfHonorScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> medals = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final data = await widget.state.backend.userTagsAndMedals(
        account.authToken,
        account.userId,
      );
      final raw = data['medals'];
      final values = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        medals = values;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('medal-of-honor-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Medal of Honor'),
      ),
      body: _MineSubpageBackground(
        child: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _mineText))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  if (medals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'No medals yet',
                          style: TextStyle(color: _mineMuted),
                        ),
                      ),
                    ),
                  for (final medal in medals)
                    Card(
                      color: _minePanel,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _colorFromHex(
                            medal['color']?.toString(),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          medal['name']?.toString() ?? 'Medal',
                          style: const TextStyle(
                            color: _mineText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        ),
      ),
    );
  }

  Color _colorFromHex(String? value) {
    final hex = (value ?? '').replaceFirst('#', '');
    final parsed = int.tryParse(
      hex.length == 6 ? 'FF$hex' : hex,
      radix: 16,
    );
    return parsed == null ? const Color(0xFFFFB300) : Color(parsed);
  }
}

class RewardRecordsScreen extends StatefulWidget {
  const RewardRecordsScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<RewardRecordsScreen> createState() => _RewardRecordsScreenState();
}

class _RewardRecordsScreenState extends State<RewardRecordsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final result = await widget.state.backend.walletTransactions(
        account.authToken,
      );
      if (!mounted) return;
      setState(() {
        rows = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('reward-records-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Reward Records'),
      ),
      body: _MineSubpageBackground(
        child: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _mineText))
            : rows.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No reward or wallet records yet',
                          style: TextStyle(color: _mineMuted),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final coins = (row['coins_delta'] as num?)?.toInt() ?? 0;
                      final diamonds =
                          (row['diamonds_delta'] as num?)?.toInt() ?? 0;
                      final note = row['note']?.toString().trim() ?? '';
                      final kind = row['kind']?.toString() ?? 'record';
                      final amount = coins != 0
                          ? (coins > 0 ? '+$coins Coins' : '$coins Coins')
                          : (diamonds > 0
                              ? '+$diamonds Diamonds'
                              : '$diamonds Diamonds');
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFFE69A),
                          child: Icon(
                            coins >= 0
                                ? Icons.card_giftcard_rounded
                                : Icons.shopping_bag_rounded,
                            color: const Color(0xFF8A6200),
                          ),
                        ),
                        title: Text(
                          note.isEmpty ? kind.replaceAll('_', ' ') : note,
                          style: const TextStyle(
                            color: _mineText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(_dateText(row['created_at'])),
                        trailing: Text(
                          amount,
                          style: TextStyle(
                            color: coins >= 0
                                ? const Color(0xFF198754)
                                : const Color(0xFFC44C4C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> tasks = const [];
  String? claiming;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final values = await widget.state.backend.tasks(account.authToken);
      if (!mounted) return;
      setState(() {
        tasks = values;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  Future<void> _claim(Map<String, dynamic> task) async {
    final account = widget.state.auth.current;
    final id = task['id']?.toString() ?? '';
    if (account == null || id.isEmpty || claiming != null) return;
    setState(() => claiming = id);
    try {
      final result = await widget.state.backend.claimTask(
        account.authToken,
        id,
      );
      final rawTasks = result['tasks'];
      final wallet = result['wallet'];
      if (wallet is Map) {
        final remote = await widget.state.backend.wallet(account.authToken);
        widget.state.wallet.applyRemote(remote);
      }
      if (!mounted) return;
      setState(() {
        tasks = rawTasks is List
            ? rawTasks
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : tasks;
        claiming = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task reward claimed: ' +
                ((task['reward_coins'] as num?)?.toInt() ?? 0).toString() +
                ' coins',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => claiming = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('task-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Task'),
      ),
      body: _MineSubpageBackground(
        child: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _mineText))
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  for (final task in tasks)
                    Card(
                      color: _minePanel,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: task['completed'] == true
                              ? const Color(0xFFDFF3E5)
                              : const Color(0xFFFFEFD0),
                          child: Icon(
                            task['completed'] == true
                                ? Icons.task_alt_rounded
                                : Icons.bolt_rounded,
                            color: task['completed'] == true
                                ? const Color(0xFF198754)
                                : const Color(0xFFC48500),
                          ),
                        ),
                        title: Text(
                          task['title']?.toString() ?? 'Task',
                          style: const TextStyle(
                            color: _mineText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Reward: ' +
                              ((task['reward_coins'] as num?)?.toInt() ?? 0)
                                  .toString() +
                              ' coins',
                        ),
                        trailing: task['claimed'] == true
                            ? const Text(
                                'Claimed',
                                style: TextStyle(
                                  color: Color(0xFF198754),
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : FilledButton(
                                onPressed: task['completed'] == true &&
                                        claiming == null
                                    ? () => _claim(task)
                                    : null,
                                child: Text(
                                  claiming == task['id'] ? 'Claiming…' : 'Claim',
                                ),
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

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final controller = TextEditingController();
  String category = 'General';
  bool sending = false;
  bool loading = true;
  List<Map<String, dynamic>> history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final values = await widget.state.backend.feedbackHistory(
        account.authToken,
      );
      if (mounted) {
        setState(() {
          history = values;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submit() async {
    final account = widget.state.auth.current;
    final message = controller.text.trim();
    if (account == null || sending) return;
    if (message.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write your feedback first.')),
      );
      return;
    }
    setState(() => sending = true);
    try {
      await widget.state.backend.submitFeedback(
        account.authToken,
        category: category,
        message: message,
      );
      controller.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted to Tinni Star.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(e))),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('feedback-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Feedback'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'General', child: Text('General')),
              DropdownMenuItem(value: 'Bug', child: Text('Bug')),
              DropdownMenuItem(value: 'Account', child: Text('Account')),
              DropdownMenuItem(value: 'Room', child: Text('Room')),
              DropdownMenuItem(value: 'Payment', child: Text('Payment')),
              DropdownMenuItem(value: 'Safety', child: Text('Safety')),
            ],
            onChanged: sending
                ? null
                : (value) => setState(() => category = value ?? 'General'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('feedback-message'),
            controller: controller,
            maxLength: 2000,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Tell us what happened',
              alignLabelWithHint: true,
            ),
          ),
          FilledButton.icon(
            key: const Key('feedback-submit'),
            onPressed: sending ? null : _submit,
            icon: const Icon(Icons.send_rounded),
            label: Text(sending ? 'Submitting…' : 'Submit'),
          ),
          const SizedBox(height: 20),
          const Text(
            'My feedback',
            style: TextStyle(
              color: _mineText,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (loading) const LinearProgressIndicator(),
          for (final row in history)
            Card(
              color: _minePanel,
              child: ListTile(
                title: Text(row['category']?.toString() ?? 'General'),
                subtitle: Text(
                  (row['message']?.toString() ?? '') +
                      '\n' +
                      _dateText(row['created_at']),
                ),
                isThreeLine: true,
                trailing: Text(
                  row['status']?.toString() ?? 'submitted',
                  style: const TextStyle(
                    color: Color(0xFF198754),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MessageNotificationScreen extends StatefulWidget {
  const MessageNotificationScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<MessageNotificationScreen> createState() =>
      _MessageNotificationScreenState();
}

class _MessageNotificationScreenState extends State<MessageNotificationScreen> {
  bool loading = true;
  bool voice = true;
  bool vibration = true;
  bool floatingOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final row = await widget.state.backend.accountPreferences(
        account.authToken,
      );
      if (!mounted) return;
      setState(() {
        voice = row['message_voice'] != false;
        vibration = row['message_vibration'] != false;
        floatingOnly = row['room_floating_only'] == true;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save({
    bool? nextVoice,
    bool? nextVibration,
    bool? nextFloatingOnly,
  }) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    final previous = (voice, vibration, floatingOnly);
    setState(() {
      if (nextVoice != null) voice = nextVoice;
      if (nextVibration != null) vibration = nextVibration;
      if (nextFloatingOnly != null) floatingOnly = nextFloatingOnly;
    });
    try {
      await widget.state.backend.updateAccountPreferences(
        account.authToken,
        <String, dynamic>{
          'message_voice': voice,
          'message_vibration': vibration,
          'room_floating_only': floatingOnly,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        voice = previous.$1;
        vibration = previous.$2;
        floatingOnly = previous.$3;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('message-notification-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Message notification'),
      ),
      body: _MineSubpageBackground(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: _mineText),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Voice',
                      style: TextStyle(
                        color: _mineText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    activeThumbColor: _mineText,
                    activeTrackColor: Color(0x665F4600),
                    inactiveThumbColor: _mineMuted,
                    inactiveTrackColor: _minePanel2,
                    value: voice,
                    onChanged: (v) => _save(nextVoice: v),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Vibration',
                      style: TextStyle(
                        color: _mineText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    activeThumbColor: _mineText,
                    activeTrackColor: Color(0x665F4600),
                    inactiveThumbColor: _mineMuted,
                    inactiveTrackColor: _minePanel2,
                    value: vibration,
                    onChanged: (v) => _save(nextVibration: v),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Only receive floating screen in the room',
                      style: TextStyle(
                        color: _mineText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    activeThumbColor: _mineText,
                    activeTrackColor: Color(0x665F4600),
                    inactiveThumbColor: _mineMuted,
                    inactiveTrackColor: _minePanel2,
                    value: floatingOnly,
                    onChanged: (v) => _save(nextFloatingOnly: v),
                  ),
                ],
              ),
      ),
    );
  }
}

class BindAccountScreen extends StatefulWidget {
  const BindAccountScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<BindAccountScreen> createState() => _BindAccountScreenState();
}

class _BindAccountScreenState extends State<BindAccountScreen> {
  bool loading = true;
  bool binding = false;
  List<Map<String, dynamic>> identities = const [];
  final AppAuthApi authApi = AppAuthApi();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    authApi.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final values = await widget.state.backend.accountIdentities(
        account.authToken,
      );
      if (!mounted) return;
      setState(() {
        identities = values;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _hasProvider(String provider) =>
      identities.any((row) => row['provider']?.toString() == provider);

  Future<void> _bindGoogle() async {
    final account = widget.state.auth.current;
    if (account == null || binding || _hasProvider('google')) return;
    setState(() => binding = true);
    try {
      final config = await authApi.loadConfig();
      if (config.googleServerClientId == null) {
        throw StateError('Google login setup is not configured yet.');
      }
      await GoogleSignIn.instance.initialize(
        serverClientId: config.googleServerClientId,
      );
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw StateError('Google sign-in is not supported on this device.');
      }
      final google = await GoogleSignIn.instance.authenticate();
      final idToken = google.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google did not return a valid ID token.');
      }
      final values = await widget.state.backend.linkGoogleAccount(
        account.authToken,
        idToken: idToken,
      );
      if (!mounted) return;
      setState(() => identities = values);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google account bound successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(e))),
      );
    } finally {
      if (mounted) setState(() => binding = false);
    }
  }

  Future<void> _bindEmail() async {
    final account = widget.state.auth.current;
    if (account == null || binding || _hasProvider('email')) return;

    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final setup = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bind email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('bind-email-address'),
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email / Gmail ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('bind-email-password'),
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Create Tinni password',
                helperText: '8 to 128 characters',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final email = emailController.text.trim();
              final password = passwordController.text;
              if (!email.contains('@') ||
                  password.length < 8 ||
                  password.length > 128) {
                return;
              }
              Navigator.pop(dialogContext, (email, password));
            },
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
    emailController.dispose();
    passwordController.dispose();
    if (setup == null || !mounted) return;

    setState(() => binding = true);
    try {
      final started = await widget.state.backend.startEmailAccountLink(
        account.authToken,
        email: setup.$1,
      );
      final requestId = started['request_id']?.toString() ?? '';
      if (requestId.isEmpty) {
        throw StateError('Email OTP request did not start.');
      }
      if (!mounted) return;

      final otpController = TextEditingController();
      final otp = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verify email'),
          content: TextField(
            key: const Key('bind-email-otp'),
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: '6-digit OTP',
              helperText:
                  'Sent to ' + (started['email']?.toString() ?? setup.$1),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = otpController.text.trim();
                if (!RegExp(r'^\d{6}$').hasMatch(value)) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Verify & Bind'),
            ),
          ],
        ),
      );
      otpController.dispose();
      if (otp == null || otp.isEmpty) return;

      final values = await widget.state.backend.verifyEmailAccountLink(
        account.authToken,
        requestId: requestId,
        otp: otp,
        password: setup.$2,
      );
      if (!mounted) return;
      setState(() => identities = values);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email account bound successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(e))),
      );
    } finally {
      if (mounted) setState(() => binding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.state.auth.current;
    return Scaffold(
      key: const Key('bind-account-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Bind account'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mineText))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                if (account != null)
                  Text(
                    'Tinni ID ' + account.userId,
                    style: const TextStyle(
                      color: _mineMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 12),
                _providerTile(
                  'Google',
                  Icons.g_mobiledata_rounded,
                  _hasProvider('google'),
                  _bindGoogle,
                ),
                _providerTile(
                  'Email',
                  Icons.mail_rounded,
                  _hasProvider('email'),
                  _bindEmail,
                  subtitle: _hasProvider('email')
                      ? 'Bound to this Tinni account'
                      : 'Bind with email OTP and a Tinni password',
                ),
              ],
            ),
    );
  }

  Widget _providerTile(
    String label,
    IconData icon,
    bool bound,
    VoidCallback? action, {
    String? subtitle,
  }) {
    return Card(
      color: _minePanel,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFE8A3),
          child: Icon(icon, color: const Color(0xFF8B6500)),
        ),
        title: Text(label),
        subtitle: Text(
          subtitle ?? (bound ? 'Bound to this Tinni account' : 'Not bound'),
        ),
        trailing: bound
            ? const Icon(Icons.verified_rounded, color: Color(0xFF198754))
            : action == null
                ? null
                : FilledButton(
                    onPressed: binding ? null : action,
                    child: Text(binding ? 'Binding…' : 'Bind'),
                  ),
      ),
    );
  }
}

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  bool loading = true;
  String selected = 'English';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final row = await widget.state.backend.accountPreferences(
        account.authToken,
      );
      if (!mounted) return;
      setState(() {
        selected = row['language']?.toString() ?? 'English';
        widget.state.setLanguagePreference(selected);
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _select(String value) async {
    final account = widget.state.auth.current;
    if (account == null) return;
    final old = selected;
    setState(() => selected = value);
    try {
      await widget.state.backend.updateAccountPreferences(
        account.authToken,
        <String, dynamic>{'language': value},
      );
      widget.state.setLanguagePreference(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language preference saved: $value')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => selected = old);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const values = tinniSupportedLanguages;
    return Scaffold(
      key: const Key('language-settings-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Language settings'),
      ),
      body: _MineSubpageBackground(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: _mineText),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
                children: [
                  for (final value in values)
                    ListTile(
                      key: Key('language-' + value.toLowerCase()),
                      title: Text(
                        value,
                        style: TextStyle(
                          color:
                              selected == value ? _mineText : _mineMuted,
                          fontWeight: selected == value
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                      trailing: Icon(
                        selected == value
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected == value ? _mineText : _mineMuted,
                      ),
                      onTap: () => _select(value),
                    ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'This preference is saved to your Tinni Star account. '
                      'Screen translations follow this preference where localized text is available.',
                      style: TextStyle(
                        color: _mineMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AboutTinniStarScreen extends StatelessWidget {
  const AboutTinniStarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('about-tinni-star-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('About Tinni Star'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TINNI STAR',
              style: TextStyle(
                color: Color(0xFF7E5A00),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Version 0.5.23 (44)',
              style: TextStyle(color: _mineMuted),
            ),
            SizedBox(height: 18),
            Text(
              'Tinni Star is a social live voice-room app with Party rooms, '
              'messages, gifts, games, VIP, Family, CP, calls and account safety features.',
              style: TextStyle(
                color: _mineText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlocklistScreen extends StatefulWidget {
  const BlocklistScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<BlocklistScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = const [];
  String? movingOut;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      await widget.state.social.syncBlocked(account.authToken);
      final values = await widget.state.backend.blockedProfiles(
        account.authToken,
      );
      if (!mounted) return;
      setState(() {
        rows = values;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  Future<void> _unblock(String userId) async {
    final account = widget.state.auth.current;
    if (account == null || movingOut != null) return;
    setState(() => movingOut = userId);
    try {
      await widget.state.social.setBlockedRemote(
        authToken: account.authToken,
        targetUserId: userId,
        value: false,
      );
      if (!mounted) return;
      setState(() {
        rows = rows
            .where((row) => row['user_id']?.toString() != userId)
            .toList(growable: false);
        movingOut = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => movingOut = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('blocklist-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Blocklist'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _mineText))
            : rows.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          error ?? 'Blocklist is empty',
                          style: TextStyle(
                            color:
                                error == null ? _mineMuted : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final userId = row['user_id']?.toString() ?? '';
                      final name =
                          row['display_name']?.toString() ?? userId;
                      final avatar =
                          _avatarProvider(row['avatar_data_url']?.toString());
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatar,
                          child: avatar == null
                              ? Text(
                                  name.trim().isEmpty
                                      ? '?'
                                      : name.trim()[0].toUpperCase(),
                                )
                              : null,
                        ),
                        title: Text(name),
                        subtitle: Text('ID: $userId'),
                        trailing: OutlinedButton(
                          key: Key('blocklist-move-out-$userId'),
                          onPressed: movingOut == null
                              ? () => _unblock(userId)
                              : null,
                          child: Text(
                            movingOut == userId ? 'Moving…' : 'Move out',
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class PropsScreen extends StatefulWidget {
  const PropsScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<PropsScreen> createState() => _PropsScreenState();
}

class _PropsScreenState extends State<PropsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> owned = const [];
  Map<String, String> names = const {};
  String? busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final inventory = await widget.state.backend.inventory(account.authToken);
      widget.state.inventory.applyRemote(inventory);
      final rawOwned = inventory['owned'];
      final lookup = <String, String>{};
      if (rawOwned is List) {
        for (final raw in rawOwned.whereType<Map>()) {
          final id = raw['item_id']?.toString() ?? '';
          final name = raw['name']?.toString() ?? '';
          if (id.isNotEmpty) lookup[id] = name.isEmpty ? id : name;
        }
      }
      if (!mounted) return;
      setState(() {
        owned = rawOwned is List
            ? rawOwned
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        names = lookup;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  Future<void> _equip(String kind, String itemId) async {
    final account = widget.state.auth.current;
    if (account == null || busyId != null) return;
    setState(() => busyId = itemId);
    try {
      final result = kind == 'frame'
          ? await widget.state.backend.equipFrame(account.authToken, itemId)
          : await widget.state.backend.equipStoreItem(
              account.authToken,
              kind: kind,
              itemId: itemId,
            );
      final inventory = result['inventory'];
      if (inventory is Map) {
        widget.state.inventory.applyRemote(
          Map<String, dynamic>.from(inventory),
        );
      }
      if (mounted) setState(() => busyId = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.backend.userSafeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('props-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Props'),
      ),
      body: _MineSubpageBackground(
        child: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _mineText))
            : owned.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          error ?? 'No props in your inventory',
                          style: TextStyle(
                            color:
                                error == null ? _mineMuted : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: owned.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.95,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemBuilder: (_, index) {
                      final row = owned[index];
                      final id = row['item_id']?.toString() ?? '';
                      final kind = row['item_kind']?.toString() ?? 'prop';
                      final equipped =
                          widget.state.inventory.isEquipped(kind, id);
                      return Card(
                        color: _minePanel,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: _mineBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFFE1A700),
                                size: 34,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                names[id] ?? id,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _mineText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                kind.replaceAll('_', ' '),
                                style: const TextStyle(
                                  color: _mineMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: equipped || busyId != null
                                    ? null
                                    : () => _equip(kind, id),
                                child: Text(
                                  equipped
                                      ? 'Using'
                                      : busyId == id
                                          ? 'Applying…'
                                          : 'Use',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }
}

class WealthLevelScreen extends StatefulWidget {
  const WealthLevelScreen({super.key, required this.state});
  final TinniState state;

  @override
  State<WealthLevelScreen> createState() => _WealthLevelScreenState();
}

class _WealthLevelScreenState extends State<WealthLevelScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> stats = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;
    try {
      final value = await widget.state.backend.accountStats(account.authToken);
      if (!mounted) return;
      setState(() {
        stats = value;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = widget.state.backend.userSafeError(e);
      });
    }
  }

  String _compact(int value) {
    if (value >= 1000000000) {
      return (value / 1000000000).toStringAsFixed(1) + 'B';
    }
    if (value >= 1000000) {
      return (value / 1000000).toStringAsFixed(1) + 'M';
    }
    if (value >= 1000) {
      return (value / 1000).toStringAsFixed(1) + 'K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final wealth = stats['wealth'] is Map
        ? Map<String, dynamic>.from(stats['wealth'] as Map)
        : const <String, dynamic>{};
    final level = (wealth['level'] as num?)?.toInt() ?? 0;
    final sent = (stats['lifetime_sent_coins'] as num?)?.toInt() ?? 0;
    final next = (wealth['next_threshold'] as num?)?.toInt();

    return Scaffold(
      key: const Key('wealth-level-screen'),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: const Text('Wealth level'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _mineText))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2ECF67), Color(0xFF0D7F3D)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.diamond_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LV.' + level.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Lifetime sending: ' + _compact(sent) + ' coins',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    color: _minePanel,
                    child: ListTile(
                      title: const Text('Next level'),
                      subtitle: Text(
                        next == null
                            ? 'Highest configured level reached'
                            : _compact(next) + ' lifetime sending coins required',
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Wealth level follows the level thresholds configured by the Tinni Star Owner Panel. '
                      'Sending total is calculated from real gift transactions.',
                      style: TextStyle(color: _mineMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class HostDataScreen extends StatefulWidget {
  const HostDataScreen({
    super.key,
    required this.state,
    this.roleLabel = 'Host',
    this.onTransfer,
  });

  final TinniState state;
  final String roleLabel;
  final Future<void> Function()? onTransfer;

  @override
  State<HostDataScreen> createState() => _HostDataScreenState();
}

class _HostDataScreenState extends State<HostDataScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> transfers = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = widget.state.auth.current;
    if (account == null) return;

    String? nextError;
    List<Map<String, dynamic>> nextTransfers = transfers;

    try {
      final remoteWallet =
          await widget.state.backend.wallet(account.authToken);
      widget.state.wallet.applyRemote(remoteWallet);
    } catch (e) {
      nextError = widget.state.backend.userSafeError(e);
    }

    try {
      nextTransfers =
          await widget.state.backend.settlementTransfers(account.authToken);
    } catch (e) {
      // A secondary history failure must never blank the Host/Agency/BD
      // panel after wallet/diamond changes. Keep the live role wallet visible.
      nextError ??= widget.state.backend.userSafeError(e);
    }

    if (!mounted) return;
    setState(() {
      transfers = nextTransfers;
      loading = false;
      error = nextError;
    });
  }

  String _usd(int cents) => '\$' + (cents / 100).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final wallet = widget.state.wallet;
    final roleText = widget.roleLabel;

    return Scaffold(
      key: Key('role-data-screen-' + widget.roleLabel.toLowerCase()),
      backgroundColor: _mineBg,
      appBar: AppBar(
        backgroundColor: _mineBg,
        foregroundColor: _mineText,
        elevation: 0,
        title: Text(widget.roleLabel + ' Panel'),
      ),
      body: _MineSubpageBackground(
        child: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _mineText))
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  Card(
                    color: _minePanel,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: _mineBorder),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ListTileTheme(
                      data: const ListTileThemeData(
                        textColor: _mineText,
                        iconColor: _mineText,
                        subtitleTextStyle: TextStyle(color: _mineMuted),
                      ),
                      child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.badge_rounded),
                          title: const Text('Role'),
                          trailing: Text(
                            roleText,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: Text(
                            widget.roleLabel == 'Host'
                                ? 'Host diamonds'
                                : widget.roleLabel + ' balance',
                          ),
                          trailing: Text(wallet.diamonds.toString()),
                        ),
                        ListTile(
                          title: const Text('Diamond value'),
                          trailing: Text(_usd(wallet.diamondUsdCents)),
                        ),
                        ListTile(
                          title: const Text('Commission balance'),
                          trailing: Text(_usd(wallet.commissionUsdCents)),
                        ),
                        ListTile(
                          title: const Text('Withdrawable / transferable'),
                          trailing: Text(
                            _usd(wallet.withdrawableUsdCents),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                  if (wallet.canTransferSettlement && widget.onTransfer != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        key: const Key('host-data-transfer'),
                        onPressed: () async {
                          await widget.onTransfer!();
                          await _load();
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Transfer settlement'),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Text(
                    'Settlement transfer history',
                    style: TextStyle(
                      color: _mineText,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (transfers.isEmpty)
                    Card(
                      color: _minePanel,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: _mineBorder),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No settlement transfers yet',
                            style: TextStyle(color: _mineMuted),
                          ),
                        ),
                      ),
                    ),
                  for (final row in transfers)
                    Card(
                      color: _minePanel,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: _mineBorder),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        iconColor: _mineText,
                        textColor: _mineText,
                        leading: const Icon(Icons.payments_rounded),
                        title: Text(
                          _usd((row['usd_cents'] as num?)?.toInt() ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'To ID ' +
                              (row['recipient_user_id']?.toString() ?? '') +
                              ' • ' +
                              (row['recipient_role']
                                      ?.toString()
                                      .replaceAll('_', ' ') ??
                                  '') +
                              '\n' +
                              _dateText(row['created_at']),
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              ),
        ),
      ),
    );
  }
}

class SignOutAction {
  const SignOutAction._();

  static Future<void> run(BuildContext context, TinniState state) async {
    final account = state.auth.current;
    if (account == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Sign out from this Tinni Star account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await state.backend.logout(account.authToken);
    } catch (_) {
      // Local sign-out still proceeds if the network is temporarily unavailable.
    }
    await state.roomSession.close();
    await state.push.unregister();
    await state.authPersistence?.clear();
    state.profile.clear();
    state.auth.forcedLogout();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(state: state)),
      (_) => false,
    );
  }
}
