import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'team_list_screen.dart';
import 'match_history_screen.dart';
import 'match_setup_screen.dart';
import 'scoring_screen.dart';
import '../services/database_service.dart';
import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

import 'dart:convert';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _savedStateJson;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkResumeDialog());
  }

  Future<void> _loadSavedState() async {
    final stateJson = await DatabaseService.instance.getCurrentMatchState();
    if (!mounted) return;
    if (stateJson != null) {
      final map = jsonDecode(stateJson);
      final isComplete = map['isMatchComplete'] as bool? ?? false;
      final hasBalls = (map['currentInningsBalls'] as List?)?.isNotEmpty ?? false;
      if (!isComplete && hasBalls) {
        setState(() => _savedStateJson = stateJson);
      } else {
        await DatabaseService.instance.clearCurrentMatchState();
      }
    }
  }

  Future<void> _checkResumeDialog() async {
    final stateJson = await DatabaseService.instance.getCurrentMatchState();
    if (stateJson != null) {
      if (!mounted) return;
      final teams = await DatabaseService.instance.getAllTeams();
      if (!mounted) return;
      final savedState = MatchState.fromMap(jsonDecode(stateJson), teams);
      if ((savedState.currentInningsBalls.isEmpty && savedState.isInnings1) || savedState.isMatchComplete) {
        await DatabaseService.instance.clearCurrentMatchState();
        if (mounted) setState(() => _savedStateJson = null);
        return;
      }
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppTheme.kBgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppTheme.kGoldDark.withOpacity(0.5))),
          title: const Text('Resume Match?', style: TextStyle(color: AppTheme.kGold, fontWeight: FontWeight.bold)),
          content: const Text('An unfinished match was found. Would you like to resume?', style: TextStyle(color: AppTheme.kTextSecondary)),
          actions: [
            TextButton(
              onPressed: () {
                DatabaseService.instance.clearCurrentMatchState();
                if (mounted) setState(() => _savedStateJson = null);
                Navigator.pop(c);
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () => _resumeAction(c, stateJson),
              child: const Text('RESUME'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _resumeAction(BuildContext? dialogContext, String stateJson) async {
    final teams = await DatabaseService.instance.getAllTeams();
    if (!mounted) return;
    final savedState = MatchState.fromMap(jsonDecode(stateJson), teams);
    ref.read(matchProvider.notifier).resumeMatch(savedState);
    if (dialogContext != null && dialogContext.mounted) Navigator.pop(dialogContext);
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (c) => const ScoringScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), AppTheme.kBgBlack],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // ─── Logo & Brand ────────────────────────────────────────────
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [AppTheme.kGoldDark, Color(0xFF1A1A00)]),
                    border: Border.all(color: AppTheme.kGold.withOpacity(0.6), width: 2),
                  ),
                  child: const Icon(Icons.sports_cricket, size: 44, color: AppTheme.kGold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'VISH_CRIC',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.kGold,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GULLY CRICKET SCORER',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 4,
                    color: AppTheme.kTextSecondary.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 48),

                // ─── Resume Banner ───────────────────────────────────────────
                if (_savedStateJson != null) ...[
                  _ResumeBanner(
                    onResume: () => _resumeAction(null, _savedStateJson!),
                    onDelete: () async {
                      await DatabaseService.instance.clearCurrentMatchState();
                      setState(() => _savedStateJson = null);
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // ─── Main Actions ────────────────────────────────────────────
                _HomeButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Start New Match',
                  gradient: const LinearGradient(colors: [AppTheme.kGoldDark, AppTheme.kGold]),
                  textColor: AppTheme.kBgBlack,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MatchSetupScreen())),
                ),
                const SizedBox(height: 14),
                _HomeButton(
                  icon: Icons.groups_rounded,
                  label: 'Manage Teams',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TeamListScreen())),
                ),
                const SizedBox(height: 14),
                _HomeButton(
                  icon: Icons.history_rounded,
                  label: 'Match History',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MatchHistoryScreen())),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Resume Banner ─────────────────────────────────────────────────────────────

class _ResumeBanner extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onDelete;
  const _ResumeBanner({required this.onResume, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.kGold.withOpacity(0.4), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.kGoldDark.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pause_circle_filled, color: AppTheme.kGold, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Match Paused', style: TextStyle(color: AppTheme.kGold, fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 2),
                Text('Tap to continue from where you left off', style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onResume,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('RESUME', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            tooltip: 'Delete saved match',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── Home Button ───────────────────────────────────────────────────────────────

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color textColor;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
    this.textColor = kTextPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? AppTheme.kBgCard : null,
          borderRadius: BorderRadius.circular(14),
          border: gradient == null ? Border.all(color: AppTheme.kGoldDark.withOpacity(0.3), width: 1) : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: textColor.withOpacity(0.5), size: 14),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
