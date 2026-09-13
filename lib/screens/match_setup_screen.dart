import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import 'scoring_screen.dart';
import '../theme/app_theme.dart';

import 'package:uuid/uuid.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  String? teamAId;
  String? teamBId;
  String? tossWinnerId;
  bool? tossWinnerChoseBat;
  int? overs;
  bool isGoldenOverEnabled = false;
  int? goldenOverNumber;

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(teamProvider);

    final bool canStart = teamAId != null &&
        teamBId != null &&
        tossWinnerId != null &&
        tossWinnerChoseBat != null &&
        overs != null &&
        overs! > 0 &&
        overs! <= 50 &&
        (!isGoldenOverEnabled || (goldenOverNumber != null && goldenOverNumber! >= 1 && goldenOverNumber! <= overs!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Setup'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.kGoldDark.withOpacity(0.3)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Teams ──────────────────────────────────────────────────────
            _sectionLabel('SELECT TEAMS'),
            const SizedBox(height: 10),
            _goldDropdown<String>(
              label: 'Team A',
              value: teamAId,
              items: teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
              onChanged: (v) => setState(() => teamAId = v),
            ),
            const SizedBox(height: 12),
            _goldDropdown<String>(
              label: 'Team B',
              value: teamBId,
              items: teams.where((t) => t.id != teamAId).map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
              onChanged: (v) => setState(() => teamBId = v),
            ),

            // ─── Toss ────────────────────────────────────────────────────────
            if (teamAId != null && teamBId != null) ...[
              const SizedBox(height: 24),
              _sectionLabel('TOSS RESULT'),
              const SizedBox(height: 8),
              _goldCard(
                child: Column(
                  children: [
                    _tossRadio(teams.firstWhere((t) => t.id == teamAId).name, teamAId!),
                    const Divider(height: 1),
                    _tossRadio(teams.firstWhere((t) => t.id == teamBId).name, teamBId!),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionLabel('DECISION'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _choiceButton('BAT 🏏', tossWinnerChoseBat == true, tossWinnerId != null ? () => setState(() => tossWinnerChoseBat = true) : null)),
                  const SizedBox(width: 12),
                  Expanded(child: _choiceButton('BOWL 🥎', tossWinnerChoseBat == false, tossWinnerId != null ? () => setState(() => tossWinnerChoseBat = false) : null)),
                ],
              ),
            ],

            // ─── Overs ───────────────────────────────────────────────────────
            const SizedBox(height: 24),
            _sectionLabel('MATCH OVERS'),
            const SizedBox(height: 10),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Number of Overs (1–50)',
                errorText: (overs != null && (overs! < 1 || overs! > 50)) ? 'Must be 1–50' : null,
                prefixIcon: const Icon(Icons.timer_outlined, color: AppTheme.kGold, size: 20),
              ),
              style: const TextStyle(color: AppTheme.kTextPrimary),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                setState(() {
                  overs = int.tryParse(v);
                  if (overs != null && goldenOverNumber != null && goldenOverNumber! > overs!) goldenOverNumber = null;
                });
              },
            ),

            // ─── Golden Over ─────────────────────────────────────────────────
            const SizedBox(height: 16),
            _goldCard(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('⭐ Golden Over', style: TextStyle(color: AppTheme.kGold, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Doubled runs · Wicket penalties', style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 12)),
                    value: isGoldenOverEnabled,
                    onChanged: (v) => setState(() => isGoldenOverEnabled = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isGoldenOverEnabled) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Golden Over Number (1–${overs ?? 50})',
                        errorText: (goldenOverNumber != null && overs != null && (goldenOverNumber! < 1 || goldenOverNumber! > overs!))
                            ? 'Must be 1–$overs'
                            : null,
                        prefixIcon: const Icon(Icons.star_rounded, color: AppTheme.kGold, size: 20),
                      ),
                      style: const TextStyle(color: AppTheme.kTextPrimary),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() => goldenOverNumber = int.tryParse(v)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),

            // ─── Start Button ─────────────────────────────────────────────────
            const SizedBox(height: 36),
            AnimatedOpacity(
              opacity: canStart ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: canStart ? () {
                  final teamA = teams.firstWhere((t) => t.id == teamAId);
                  final teamB = teams.firstWhere((t) => t.id == teamBId);
                  final match = Match(
                    id: const Uuid().v4(),
                    teamA: teamA,
                    teamB: teamB,
                    maxOvers: overs!,
                    tossWinnerId: tossWinnerId!,
                    tossWinnerBatsFirst: tossWinnerChoseBat!,
                    date: DateTime.now(),
                    goldenOver: isGoldenOverEnabled ? goldenOverNumber : null,
                  );
                  ref.read(matchProvider.notifier).startMatch(match);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ScoringScreen()));
                } : null,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: canStart ? const LinearGradient(colors: [AppTheme.kGoldDark, AppTheme.kGold]) : null,
                    color: canStart ? null : AppTheme.kBgSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'START SCORING',
                      style: TextStyle(color: AppTheme.kBgBlack, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(color: AppTheme.kGoldDark, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
  );

  Widget _goldCard({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.kBgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.kGoldDark.withOpacity(0.3)),
    ),
    child: child,
  );

  Widget _tossRadio(String name, String value) => RadioListTile<String>(
    title: Text(name, style: const TextStyle(color: AppTheme.kTextPrimary, fontSize: 14)),
    value: value,
    groupValue: tossWinnerId,
    onChanged: (v) => setState(() => tossWinnerId = v),
    contentPadding: EdgeInsets.zero,
    dense: true,
  );

  Widget _choiceButton(String label, bool selected, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [AppTheme.kGoldDark, AppTheme.kGold]) : null,
          color: selected ? null : AppTheme.kBgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.kGold : AppTheme.kGoldDark.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.kBgBlack : AppTheme.kTextSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _goldDropdown<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.groups_rounded, color: AppTheme.kGold, size: 20),
      ),
      dropdownColor: AppTheme.kBgSurface,
      style: const TextStyle(color: AppTheme.kTextPrimary),
      items: items,
      onChanged: onChanged,
    );
  }
}
