import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import '../owner/owner_panel_service.dart';
import '../ui/royal_theme.dart';

class OwnerPanelScreen extends StatefulWidget {
  const OwnerPanelScreen({super.key, required this.state});

  final TinniState state;

  @override
  State<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

class _OwnerPanelScreenState extends State<OwnerPanelScreen> {
  final TextEditingController _search = TextEditingController();

  OwnerPanelService get owner => widget.state.ownerPanel;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: owner,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Owner Panel',
              style: TextStyle(
                color: RoyalPalette.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _hero(),
              const SizedBox(height: 12),
              _searchPanel(),
              const SizedBox(height: 12),
              _section(
                'Live overview',
                [
                  _stat('Treasury', _compact(owner.treasuryCoins), Icons.account_balance_wallet_rounded),
                  _stat('Features', owner.featureFlags.length.toString(), Icons.tune_rounded),
                  _stat('VIP levels', owner.vips.length.toString(), Icons.workspace_premium_rounded),
                  _stat('Custom panels', owner.customPanels.length.toString(), Icons.dashboard_customize_rounded),
                ],
              ),
              const SizedBox(height: 12),
              _treasury(),
              const SizedBox(height: 12),
              _featureControls(),
              const SizedBox(height: 12),
              _quickControlGrid(),
              const SizedBox(height: 12),
              _policyEditor(),
              const SizedBox(height: 12),
              _vipManager(),
              const SizedBox(height: 12),
              _customPanels(),
              const SizedBox(height: 12),
              _auditLog(),
            ],
          ),
        );
      },
    );
  }

  Widget _hero() {
    return RoyalPanel(
      gradient: const LinearGradient(
        colors: [Color(0xFF3B2607), Color(0xFF0A0704)],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: RoyalPalette.gold, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tinni Star Master Control',
                  style: TextStyle(
                    color: RoyalPalette.cream,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Platform-owner controls only. Room owners do not get this panel.',
            style: TextStyle(color: RoyalPalette.muted),
          ),
        ],
      ),
    );
  }

  Widget _searchPanel() {
    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GoldSectionTitle('User / Room investigation'),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Current ID, old ID, room ID, transaction ID…',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final q = _search.text.trim();
                    if (q.isEmpty) return;
                    owner.recordOwnerAction(
                      action: 'owner_search',
                      target: q,
                      details: 'Search requested from Owner Panel',
                    );
                    _showInfo('Search', 'Backend search hook ready for: $q');
                  },
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('Search'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showInfo(
                    'Live profile',
                    'Online status, session duration, current room, sending, purchases, diamonds, dollar value and game stats will load here from the server.',
                  ),
                  icon: const Icon(Icons.monitor_heart_rounded),
                  label: const Text('Live details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GoldSectionTitle(title),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RoyalPalette.deepGold.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Icon(icon, color: RoyalPalette.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: RoyalPalette.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _treasury() {
    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GoldSectionTitle('Owner Treasury Wallet'),
          const SizedBox(height: 8),
          Text(
            '${owner.treasuryCoins} coins',
            style: const TextStyle(
              color: RoyalPalette.gold,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Owner Panel has no normal-user wallet. Treasury is separate.',
            style: TextStyle(color: RoyalPalette.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _addTreasuryCoins,
                  icon: const Icon(Icons.add_circle_rounded),
                  label: const Text('Add Coins'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sendTreasuryCoins,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Coins'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureControls() {
    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GoldSectionTitle('Master feature switches'),
          const SizedBox(height: 6),
          ...owner.featureFlags.entries.map(
            (e) => SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_pretty(e.key)),
              subtitle: const Text('Start / stop without changing app code'),
              value: e.value,
              onChanged: (v) => owner.setFeature(e.key, v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickControlGrid() {
    final items = <(IconData, String, String)>[
      (Icons.person_off_rounded, 'User controls', 'ID ban/unban • invisible • locked-room bypass'),
      (Icons.devices_rounded, 'Device controls', 'Device ban/unban and device history'),
      (Icons.meeting_room_rounded, 'Room controls', 'Ban/unban • name • DP • background'),
      (Icons.account_balance_wallet_rounded, 'Wallet controls', 'User • Coin Seller • Merchant wallets'),
      (Icons.hub_rounded, 'BD / Agency / Host', 'Direct add/remove/move with owner override'),
      (Icons.sell_rounded, 'Tags / Roles / Posts', 'Add/remove multiple concurrent tags and posts'),
      (Icons.card_giftcard_rounded, 'Gift catalog', 'Add/edit/remove gifts and assets'),
      (Icons.campaign_rounded, 'Banner manager', 'Schedule start/end and remove banners'),
      (Icons.directions_car_rounded, 'Entries & Frames', 'Vehicle/animal/3D entries and frames'),
      (Icons.casino_rounded, 'Game control', 'Stats • bets • profit/loss • feature switches'),
      (Icons.report_problem_rounded, 'Complaints', 'Host exit complaints and moderation queue'),
      (Icons.history_rounded, 'Audit & rollback', 'Before/after values and owner action history'),
    ];

    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GoldSectionTitle('A-to-Z controls'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.32,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, i) {
              final item = items[i];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  owner.recordOwnerAction(
                    action: 'open_owner_module',
                    target: item.$2,
                    details: item.$3,
                  );
                  _showInfo(item.$2, item.$3);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RoyalPalette.deepGold.withValues(alpha: 0.65)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$1, color: RoyalPalette.gold),
                      const Spacer(),
                      Text(item.$2, style: const TextStyle(color: RoyalPalette.cream, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: RoyalPalette.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _policyEditor() {
    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GoldSectionTitle('Policy & economy editor'),
          const SizedBox(height: 6),
          ...owner.policyValues.entries.map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_pretty(e.key)),
              subtitle: Text(e.value.toString(), style: const TextStyle(color: RoyalPalette.gold)),
              trailing: const Icon(Icons.edit_rounded, color: RoyalPalette.gold),
              onTap: () => _editPolicy(e.key, e.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vipManager() {
    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: GoldSectionTitle('VIP manager')),
              IconButton(
                tooltip: 'Add VIP',
                onPressed: _addVip,
                icon: const Icon(Icons.add_circle_rounded, color: RoyalPalette.gold),
              ),
            ],
          ),
          const Text(
            'Create new VIP levels or change every function of old VIP levels.',
            style: TextStyle(color: RoyalPalette.muted),
          ),
          const SizedBox(height: 6),
          ...owner.vips.map(
            (vip) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: RoyalPalette.deepGold,
                child: Text(
                  vip.level.toString(),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                ),
              ),
              title: Text(vip.name),
              subtitle: Text(
                'Price ${vip.priceCoins} • ${vip.durationDays} days • Entry: ${vip.entryName.isEmpty ? "Not set" : vip.entryName}',
              ),
              trailing: Switch(
                value: vip.enabled,
                onChanged: (v) => owner.updateVip(vip, enabled: v),
              ),
              onTap: () => _editVip(vip),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customPanels() {
    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: GoldSectionTitle('Custom admin panels')),
              IconButton(
                tooltip: 'Create panel',
                onPressed: _addCustomPanel,
                icon: const Icon(Icons.add_box_rounded, color: RoyalPalette.gold),
              ),
            ],
          ),
          const Text(
            'Create 10–20+ panels and choose exact permissions from Owner Panel.',
            style: TextStyle(color: RoyalPalette.muted),
          ),
          if (owner.customPanels.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('No custom panels yet.', style: TextStyle(color: RoyalPalette.muted)),
            ),
          ...owner.customPanels.map(
            (panel) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(panel.name),
              subtitle: Text('${panel.permissions.length} permissions'),
              value: panel.enabled,
              onChanged: (v) => owner.setPanelEnabled(panel, v),
              secondary: IconButton(
                icon: const Icon(Icons.tune_rounded, color: RoyalPalette.gold),
                onPressed: () => _editPanelPermissions(panel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditLog() {
    final entries = owner.audit.take(15).toList();
    return RoyalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GoldSectionTitle('Owner audit log'),
          const SizedBox(height: 6),
          if (entries.isEmpty)
            const Text('No owner actions yet.', style: TextStyle(color: RoyalPalette.muted)),
          ...entries.map(
            (e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, color: RoyalPalette.gold, size: 20),
              title: Text('${e.action} • ${e.target}'),
              subtitle: Text('${e.details}\n${e.at.toLocal()}'),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTreasuryCoins() async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Coins to Treasury'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Coin amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) owner.addTreasuryCoins(amount);
  }

  Future<void> _sendTreasuryCoins() async {
    final id = TextEditingController();
    final amount = TextEditingController();
    String wallet = 'normal';

    final result = await showDialog<(String, int, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Send Treasury Coins'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: id, decoration: const InputDecoration(labelText: 'Receiver user ID')),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Coin amount'),
              ),
              DropdownButtonFormField<String>(
                value: wallet,
                decoration: const InputDecoration(labelText: 'Receiver wallet'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal User Wallet')),
                  DropdownMenuItem(value: 'coin_seller', child: Text('Coin Seller Wallet')),
                  DropdownMenuItem(value: 'merchant', child: Text('Merchant Wallet')),
                ],
                onChanged: (v) => setLocal(() => wallet = v ?? 'normal'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final coins = int.tryParse(amount.text.trim());
                if (id.text.trim().isEmpty || coins == null) return;
                Navigator.pop(context, (id.text.trim(), coins, wallet));
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final ok = owner.debitTreasury(
      amount: result.$2,
      receiverId: result.$1,
      walletType: result.$3,
    );
    if (!ok && mounted) {
      _showInfo('Transfer failed', 'Check amount and Treasury balance.');
    }
  }

  Future<void> _editPolicy(String key, num current) async {
    final c = TextEditingController(text: current.toString());
    final value = await showDialog<num>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_pretty(key)),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'New value'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, num.tryParse(c.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null) owner.setPolicy(key, value);
  }

  Future<void> _addVip() async {
    final c = TextEditingController(text: 'VIP ${owner.vips.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create VIP'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'VIP name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) owner.addVip(name: name);
  }

  Future<void> _editVip(OwnerVipDefinition vip) async {
    final name = TextEditingController(text: vip.name);
    final price = TextEditingController(text: vip.priceCoins.toString());
    final days = TextEditingController(text: vip.durationDays.toString());
    final entry = TextEditingController(text: vip.entryName);
    final frame = TextEditingController(text: vip.frameName);

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit VIP ${vip.level}'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price coins')),
              TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration days')),
              TextField(controller: entry, decoration: const InputDecoration(labelText: 'Vehicle / animal / 3D entry')),
              TextField(controller: frame, decoration: const InputDecoration(labelText: 'Frame')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              owner.removeVip(vip.level);
              Navigator.pop(context, false);
            },
            child: const Text('Remove'),
          ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (save == true) {
      owner.updateVip(
        vip,
        name: name.text.trim(),
        priceCoins: int.tryParse(price.text.trim()) ?? vip.priceCoins,
        durationDays: int.tryParse(days.text.trim()) ?? vip.durationDays,
        entryName: entry.text.trim(),
        frameName: frame.text.trim(),
      );
    }
  }

  Future<void> _addCustomPanel() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Custom Panel'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Panel name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) owner.addCustomPanel(name: name);
  }

  Future<void> _editPanelPermissions(OwnerCustomPanel panel) async {
    const permissions = <String>[
      'view_online_users',
      'view_user_stats',
      'ban_user',
      'ban_room',
      'ban_wallet',
      'manage_tags',
      'manage_host_agency',
      'manage_bd_agency',
      'manage_gifts',
      'manage_vip',
      'manage_banners',
      'manage_games',
      'manage_coin_seller',
      'manage_merchant',
    ];

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(panel.name),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: permissions.map((p) {
                final checked = panel.permissions.contains(p);
                return CheckboxListTile(
                  value: checked,
                  title: Text(_pretty(p)),
                  onChanged: (v) {
                    owner.setPanelPermission(panel, p, v ?? false);
                    setLocal(() {});
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  void _showInfo(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  String _pretty(String key) {
    return key
        .split('_')
        .where((e) => e.isNotEmpty)
        .map((e) => '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }

  String _compact(int value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}
