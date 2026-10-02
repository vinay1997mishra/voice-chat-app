import 'package:flutter/material.dart';

import '../app/tinni_state.dart';
import 'mine_function_screens.dart';

class TinniSettingsScreen extends StatelessWidget {
  const TinniSettingsScreen({super.key, required this.state});

  final TinniState state;

  void _placeholder(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(title + ' will use the Tinni Star account setting.')),
    );
  }

  Widget _row(
    BuildContext context, {
    required Key key,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      key: key,
      dense: true,
      minVerticalPadding: 12,
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4D4942),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFB8B2A8),
      ),
      onTap: onTap ?? () => _placeholder(context, title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('tinni-settings-screen'),
      backgroundColor: const Color(0xFFFFFBF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF4),
        foregroundColor: const Color(0xFF403A32),
        elevation: 0,
        title: const Text(
          'Setting',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          _row(
            context,
            key: const Key('setting-message-notification'),
            title: 'Message notification',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MessageNotificationScreen(state: state),
              ),
            ),
          ),
          _row(
            context,
            key: const Key('setting-bind-account'),
            title: 'Bind account',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BindAccountScreen(state: state),
              ),
            ),
          ),
          _row(
            context,
            key: const Key('setting-language'),
            title: 'Language settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LanguageSettingsScreen(state: state),
              ),
            ),
          ),
          _row(
            context,
            key: const Key('setting-about'),
            title: 'About Tinni Star',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AboutTinniStarScreen(),
              ),
            ),
          ),
          _row(
            context,
            key: const Key('setting-feedback'),
            title: 'Feedback',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeedbackScreen(state: state),
              ),
            ),
          ),
          _row(
            context,
            key: const Key('setting-blocklist'),
            title: 'Blocklist',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocklistScreen(state: state),
              ),
            ),
          ),
          _row(
            context,
            key: const Key('setting-privacy-statement'),
            title: 'Privacy statement',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(
                    initialTab: PrivacyPolicyTab.privacy,
                  ),
                ),
              );
            },
          ),
          _row(
            context,
            key: const Key('setting-sign-out'),
            title: 'Sign out',
            onTap: () => SignOutAction.run(context, state),
          ),
        ],
      ),
    );
  }
}

enum PrivacyPolicyTab { agreement, privacy }

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({
    super.key,
    this.initialTab = PrivacyPolicyTab.privacy,
  });

  final PrivacyPolicyTab initialTab;

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late PrivacyPolicyTab tab;

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3F3A33),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF6D675E),
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required PrivacyPolicyTab value,
  }) {
    final selected = tab == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => tab = value),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFC928) : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE2A900)
                  : const Color(0xFFE8E0D4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF5A4300)
                  : const Color(0xFF6D675E),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> get _privacyContent => [
        _section(
          'Tinni Star Privacy Policy',
          'Effective date: 30 September 2026\n\n'
              'This Privacy Policy explains how Tinni Star handles information when you create an account, use Party rooms, chat, call, purchase or send virtual items, use Family or CP features, submit verification material, or contact support.',
        ),
        _section(
          '1. Information we collect',
          'Account and profile information may include your user ID, display name, email or phone login information, profile photo, age, gender, country, flag, signature, account status and login provider.\n\n'
              'Social and content information may include rooms you create or join, follows, friends, messages, room chat, gifts, Family or CP activity, moderation actions, reports and content you choose to submit.\n\n'
              'If you use voice rooms or calling, audio and connection information is processed as needed to deliver the live communication service. Tinni Star does not describe a voice session as end-to-end encrypted unless that is explicitly shown in the product.\n\n'
              'If you use account verification, we may process the photos, motion-check material and review result you submit for verification and anti-fraud purposes.\n\n'
              'Technical information may include device and app version, network information, crash or diagnostic data, security events and service logs. Wallet and transaction information may include virtual-coin balances, gifts, purchases, transfers, rewards and related ledger records.',
        ),
        _section(
          '2. How we use information',
          'We use information to operate Tinni Star, authenticate accounts, show profiles and rooms, provide live voice and messaging, deliver purchases and virtual items, maintain wallet records, provide Family and CP features, prevent abuse and fraud, enforce room and account rules, investigate reports, provide support, improve reliability and comply with legal obligations.',
        ),
        _section(
          '3. What other users can see',
          'Information you make public in Tinni Star can be visible to other users. Depending on the feature, this can include your profile photo, display name, public user ID, country flag, level, badges, Family tag, room identity, public room activity, seat presence and public chat. Private messages and non-public verification material are not intended to appear as public profile content.',
        ),
        _section(
          '4. Sharing and service providers',
          'Tinni Star may use infrastructure and service providers to operate authentication, hosting, live communication, storage, notifications, security, analytics, payments or support. Those providers receive only the information needed for the service they perform and are expected to handle it under appropriate contractual and security requirements.\n\n'
              'Information may also be disclosed when reasonably necessary to comply with law, respond to valid legal process, protect users, prevent fraud or security abuse, or protect the rights and safety of Tinni Star and its community.',
        ),
        _section(
          '5. Wallet, gifts and purchases',
          'Virtual-coin, diamond, gift, recharge, transfer, reward and settlement activity may be recorded in transaction and audit logs so balances can be verified, disputes can be investigated and unauthorized credits can be detected. Some financial or payment information may be processed by the payment provider rather than stored directly by Tinni Star.',
        ),
        _section(
          '6. Verification information',
          'Verification photos and motion-check material are used for the verification workflow, fraud prevention, safety review and related appeals or investigations. Tinni Star should not use this material for unrelated public display. If a future feature uses biometric identification or a materially different verification method, a separate notice or consent should be provided where required by law.',
        ),
        _section(
          '7. Data retention',
          'Information is kept only for as long as reasonably needed for the purpose for which it was collected, to maintain account and transaction integrity, resolve disputes, prevent fraud, enforce rules, meet legal obligations and protect the service. Retention periods may differ by data type. Some audit, security and transaction records may need to be kept after an account is closed.',
        ),
        _section(
          '8. Security',
          'Tinni Star uses technical and organizational safeguards intended to protect account and service information. No online service can guarantee absolute security. You should protect your login credentials, avoid sharing verification codes and report suspected account misuse through the in-app Feedback option.',
        ),
        _section(
          '9. Permissions and device access',
          'Features may request device permissions such as microphone, camera, notifications, photos or media. Tinni Star should request a permission only when it is needed for a feature that uses it. You can control permissions from your device settings, although disabling a permission can prevent the related feature from working.',
        ),
        _section(
          '10. Your choices and rights',
          'You can update supported profile information, control selected privacy or notification settings, block or unblock users, leave rooms and stop using optional features. Depending on applicable law, you may also have rights to request access, correction, deletion or other action concerning your personal information. Requests can be started through the in-app Feedback section.',
        ),
        _section(
          '11. Children and age requirements',
          'Tinni Star users must satisfy the age and consent requirements that apply in their country and to the features they use. Where parental or guardian consent is legally required, the service should obtain that consent before processing information that requires it.',
        ),
        _section(
          '12. International processing',
          'Tinni Star may operate through service providers located in more than one country. Where personal information is transferred internationally, appropriate safeguards should be used as required by applicable law.',
        ),
        _section(
          '13. Changes to this policy',
          'This policy may be updated when Tinni Star changes its features, technology, legal requirements or data practices. Material changes should be shown in the app or otherwise communicated before they take effect when required.',
        ),
        _section(
          '14. Contact',
          'For privacy questions, account-data requests or complaints, use Mine → Feedback in Tinni Star. An official support email or legal contact can be added here when it is published for Tinni Star.',
        ),
      ];

  List<Widget> get _agreementContent => [
        _section(
          'Tinni Star Service Agreement',
          'Effective date: 30 September 2026\n\n'
              'This Service Agreement describes the basic rules for using Tinni Star. By using the service, you agree to follow the in-app rules, applicable law and the policies shown for specific features.',
        ),
        _section(
          '1. Your account',
          'You are responsible for the activity on your account and for keeping login credentials and verification codes secure. Do not impersonate another person, misuse another account or attempt to bypass account or wallet security.',
        ),
        _section(
          '2. Rooms, chat and calls',
          'Use Party rooms, chat and calling features lawfully and respectfully. Room Owner, Admin and platform moderation powers apply only as defined by Tinni Star. Users must not use the service for harassment, threats, fraud, illegal content or attempts to defeat safety controls.',
        ),
        _section(
          '3. Virtual items and balances',
          'Coins, diamonds, gifts, VIP benefits, frames, vehicles, entries and other virtual items are digital service features. Their use, price, eligibility, duration and transfer rules are controlled by the current Tinni Star economy and the rules shown at the time of use. Unauthorized balance manipulation may result in wallet review, freezing or account action.',
        ),
        _section(
          '4. Purchases and refunds',
          'Purchases and recharges are subject to the price, payment method and refund rules shown at purchase time and to the rules of the payment provider or app store where applicable. Do not use unauthorized payment methods or attempt chargeback abuse.',
        ),
        _section(
          '5. Safety and moderation',
          'Tinni Star may restrict rooms, messages, calls, wallet activity or accounts when reasonably necessary to enforce rules, investigate abuse, prevent fraud, comply with law or protect users and the service. Reports and appeals should be handled through the available in-app support process.',
        ),
        _section(
          '6. Service availability',
          'Tinni Star may update, repair, suspend or discontinue features as the service changes. Live voice, login, payments and other online features can depend on network and third-party infrastructure and may occasionally be unavailable.',
        ),
        _section(
          '7. Privacy',
          'Use of personal information is governed by the Tinni Star Privacy Policy available on this page. Feature-specific notices may apply when a feature collects additional information.',
        ),
        _section(
          '8. Updates to this agreement',
          'This agreement may be updated to reflect new features, economy rules, safety requirements or legal obligations. Material changes should be communicated in the app when required.',
        ),
        _section(
          '9. Contact',
          'For questions about this agreement, use Mine → Feedback in Tinni Star. An official legal or support contact can be added when it is published for the service.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final body = tab == PrivacyPolicyTab.privacy
        ? _privacyContent
        : _agreementContent;

    return Scaffold(
      key: const Key('tinni-privacy-policy-screen'),
      backgroundColor: const Color(0xFFFFFBF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF4),
        foregroundColor: const Color(0xFF403A32),
        elevation: 0,
        title: const Text(
          'Service Agreement & Privacy Policy',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Row(
              children: [
                _tabButton(
                  label: 'Service Agreement',
                  value: PrivacyPolicyTab.agreement,
                ),
                const SizedBox(width: 8),
                _tabButton(
                  label: 'Privacy Policy',
                  value: PrivacyPolicyTab.privacy,
                ),
              ],
            ),
          ),
          ...body,
        ],
      ),
    );
  }
}
