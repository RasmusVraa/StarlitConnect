import 'dart:async';

import 'package:fl_clash/state.dart';
import 'package:fl_clash/starlit/mode_page.dart';
import 'package:fl_clash/starlit/prefs.dart';
import 'package:fl_clash/starlit/profile_page.dart';
import 'package:fl_clash/starlit/subscription_page.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/vpn_home.dart';
import 'package:fl_clash/starlit/whats_new.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StarlitTab { vpn, mode, subscription, profile }

class StarlitShell extends ConsumerStatefulWidget {
  const StarlitShell({super.key});

  @override
  ConsumerState<StarlitShell> createState() => _StarlitShellState();
}

class _StarlitShellState extends ConsumerState<StarlitShell> {
  var _tab = StarlitTab.vpn;
  var _showWhatsNew = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeWhatsNew());
  }

  Future<void> _maybeWhatsNew() async {
    final version = globalState.packageInfo.version;
    final seen = await StarlitPrefs.whatsNewSeen(version);
    if (!seen && mounted) {
      setState(() => _showWhatsNew = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StarlitScaffold(
      child: Stack(
        children: [
          Row(
            children: [
              _Sidebar(
                tab: _tab,
                onSelect: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: switch (_tab) {
                  StarlitTab.vpn => const StarlitVpnHome(),
                  StarlitTab.mode => const StarlitModePage(),
                  StarlitTab.subscription => const StarlitSubscriptionPage(),
                  StarlitTab.profile => const StarlitProfilePage(),
                },
              ),
            ],
          ),
          if (_showWhatsNew)
            StarlitWhatsNew(
              version: globalState.packageInfo.version,
              onClose: () async {
                await StarlitPrefs.setWhatsNewSeen(
                  globalState.packageInfo.version,
                );
                if (mounted) setState(() => _showWhatsNew = false);
              },
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.tab, required this.onSelect});

  final StarlitTab tab;
  final ValueChanged<StarlitTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: StarlitColors.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: StarlitColors.stroke),
      ),
      child: Column(
        children: [
          const StarlitMoonMark(size: 40),
          const SizedBox(height: 22),
          _NavItem(
            label: 'VPN',
            selected: tab == StarlitTab.vpn,
            glyph: '◈',
            onTap: () => onSelect(StarlitTab.vpn),
          ),
          _NavItem(
            label: 'Режим',
            selected: tab == StarlitTab.mode,
            glyph: '⇄',
            onTap: () => onSelect(StarlitTab.mode),
          ),
          _NavItem(
            label: 'Подписка',
            selected: tab == StarlitTab.subscription,
            glyph: '▣',
            onTap: () => onSelect(StarlitTab.subscription),
          ),
          _NavItem(
            label: 'Профиль',
            selected: tab == StarlitTab.profile,
            glyph: '◎',
            onTap: () => onSelect(StarlitTab.profile),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.glyph,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? StarlitColors.accent.withValues(alpha: 0.16)
                  : const Color(0x00000000),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: StarlitColors.accent.withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  glyph,
                  style: TextStyle(
                    fontSize: 18,
                    color: selected
                        ? StarlitColors.accent
                        : StarlitColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? StarlitColors.accent
                        : StarlitColors.muted2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
