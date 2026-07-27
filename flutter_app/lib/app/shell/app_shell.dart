import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/settings_manager.dart';
import '../../core/storage/json_settings_store.dart';
import '../../features/dictation/dictation_page.dart';
import '../../features/history/history_page.dart';
import '../../features/models/models_page.dart';
import '../../features/settings/settings_page.dart';
import '../theme/app_theme.dart';
import 'shell_navigation.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialPage = ShellPage.home});

  final ShellPage initialPage;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ShellPage _page;
  final _dictationKey = GlobalKey<DictationPageState>();
  final _historyKey = GlobalKey<HistoryPageState>();
  final _settings = SettingsManager(JsonSettingsStore());
  bool _sidebarCollapsed = false;
  bool _sidebarHidden = false;

  static const _order = [
    ShellPage.home,
    ShellPage.models,
    ShellPage.history,
    ShellPage.settings,
  ];

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    unawaited(_loadSidebarPref());
  }

  Future<void> _loadSidebarPref() async {
    await _settings.load();
    if (!mounted) return;
    setState(() => _sidebarCollapsed = _settings.sidebarCollapsed);
  }

  Future<void> _persistSidebarCollapsed(bool collapsed) async {
    _settings.sidebarCollapsed = collapsed;
    await _settings.save();
  }

  Future<void> _goTo(ShellPage page) async {
    if (page == _page) return;
    final leaving = _page;
    setState(() => _page = page);
    if (page == ShellPage.home &&
        (leaving == ShellPage.settings || leaving == ShellPage.models)) {
      await _dictationKey.currentState?.reloadAfterExternalEdit(
        showModelDownload: leaving == ShellPage.models,
      );
    }
    if (page == ShellPage.history) {
      await _historyKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _order.indexOf(_page);
    return ShellNavigation(
      current: _page,
      goTo: (page) {
        unawaited(_goTo(page));
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Row(
              children: [
                if (!_sidebarHidden)
                  _Sidebar(
                    current: _page,
                    collapsed: _sidebarCollapsed,
                    onSelect: (page) {
                      unawaited(_goTo(page));
                    },
                    onToggleCollapsed: () {
                      final next = !_sidebarCollapsed;
                      setState(() => _sidebarCollapsed = next);
                      unawaited(_persistSidebarCollapsed(next));
                    },
                    onHide: () => setState(() => _sidebarHidden = true),
                  ),
                Expanded(
                  child: ColoredBox(
                    color: FluidColors.contentBackground,
                    child: IndexedStack(
                      index: index < 0 ? 0 : index,
                      children: [
                        DictationPage(key: _dictationKey),
                        const ModelsPage(),
                        HistoryPage(key: _historyKey),
                        const SettingsPage(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_sidebarHidden)
              Positioned(
                left: FluidSpacing.sm,
                top: FluidSpacing.sm,
                child: Material(
                  color: FluidColors.elevatedCardBackground.withValues(
                    alpha: 0.92,
                  ),
                  borderRadius: BorderRadius.circular(FluidRadii.md),
                  child: IconButton(
                    tooltip: 'Show sidebar',
                    onPressed: () => setState(() => _sidebarHidden = false),
                    icon: const Icon(Icons.menu_rounded),
                    color: FluidColors.primaryText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.collapsed,
    required this.onSelect,
    required this.onToggleCollapsed,
    required this.onHide,
  });

  final ShellPage current;
  final bool collapsed;
  final ValueChanged<ShellPage> onSelect;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 64.0 : 220.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: FluidColors.sidebarBackground,
        border: const Border(
          right: BorderSide(color: FluidColors.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? FluidSpacing.sm : FluidSpacing.lg,
              FluidSpacing.xl,
              collapsed ? FluidSpacing.sm : FluidSpacing.lg,
              FluidSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: collapsed
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                _BrandMark(compact: collapsed),
                const SizedBox(height: FluidSpacing.sm),
                if (collapsed)
                  IconButton(
                    tooltip: 'Expand sidebar',
                    onPressed: onToggleCollapsed,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: FluidColors.secondaryText,
                  )
                else
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Collapse sidebar',
                        onPressed: onToggleCollapsed,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: FluidColors.secondaryText,
                      ),
                      IconButton(
                        tooltip: 'Hide sidebar',
                        onPressed: onHide,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: const Icon(Icons.keyboard_double_arrow_left),
                        color: FluidColors.secondaryText,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FluidSpacing.sm),
            child: Column(
              children: [
                _NavItem(
                  label: 'Home',
                  icon: Icons.mic_none_rounded,
                  selected: current == ShellPage.home,
                  collapsed: collapsed,
                  onTap: () => onSelect(ShellPage.home),
                ),
                _NavItem(
                  label: 'Models',
                  icon: Icons.model_training_outlined,
                  selected: current == ShellPage.models,
                  collapsed: collapsed,
                  onTap: () => onSelect(ShellPage.models),
                ),
                _NavItem(
                  label: 'History',
                  icon: Icons.history_rounded,
                  selected: current == ShellPage.history,
                  collapsed: collapsed,
                  onTap: () => onSelect(ShellPage.history),
                ),
                _NavItem(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  selected: current == ShellPage.settings,
                  collapsed: collapsed,
                  onTap: () => onSelect(ShellPage.settings),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.all(FluidSpacing.lg),
              child: Text(
                'Hold hotkey to dictate',
                style: fluidText(
                  color: FluidColors.tertiaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(FluidRadii.sm),
      child: Image.asset(
        'assets/branding/fluidvoice_logo.png',
        width: compact ? 32 : 28,
        height: compact ? 32 : 28,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          color: FluidColors.accent.withValues(alpha: 0.18),
          child: Text(
            'F',
            style: fluidText(
              color: FluidColors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
    if (compact) return mark;
    return Row(
      children: [
        mark,
        const SizedBox(width: FluidSpacing.md),
        Flexible(
          child: Text(
            'FluidVoice',
            overflow: TextOverflow.ellipsis,
            style: fluidText(
              color: FluidColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = selected
        ? FluidColors.accent.withValues(alpha: 0.14)
        : (_hovered
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.transparent);
    final fg = selected ? FluidColors.accent : FluidColors.secondaryText;

    return Padding(
      padding: const EdgeInsets.only(bottom: FluidSpacing.xs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(FluidRadii.md),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(FluidRadii.md),
            hoverColor: Colors.transparent,
            child: Tooltip(
              message: widget.collapsed ? widget.label : '',
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : FluidSpacing.md,
                  vertical: 10,
                ),
                child: widget.collapsed
                    ? Center(child: Icon(widget.icon, size: 18, color: fg))
                    : Row(
                        children: [
                          Icon(widget.icon, size: 18, color: fg),
                          const SizedBox(width: FluidSpacing.md),
                          Text(
                            widget.label,
                            style: fluidText(
                              color: selected
                                  ? FluidColors.primaryText
                                  : FluidColors.secondaryText,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
