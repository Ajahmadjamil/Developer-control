import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/banking_guard_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../data/models/banking_guard_status.dart';
import '../../../data/services/banking_guard_service.dart';

/// Multi-select installed apps for Banking Guard.
class BankingAppPickerScreen extends StatefulWidget {
  const BankingAppPickerScreen({super.key});

  @override
  State<BankingAppPickerScreen> createState() => _BankingAppPickerScreenState();
}

class _BankingAppPickerScreenState extends State<BankingAppPickerScreen> {
  final _search = TextEditingController();
  List<LaunchableApp> _apps = const [];
  late Set<String> _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = context.read<BankingGuardController>().packages.toSet();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apps = await context.read<BankingGuardService>().listLaunchableApps();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await context.read<BankingGuardController>().savePackages(_selected.toList());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _apps
        : _apps
            .where(
              (a) =>
                  a.label.toLowerCase().contains(q) ||
                  a.packageName.toLowerCase().contains(q),
            )
            .toList();

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Banking apps'),
          actions: [
            TextButton(
              onPressed: _loading ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search apps…',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.panelSolid,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_selected.length} selected',
                        style: const TextStyle(
                          color: AppColors.cyanBright,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final app = filtered[index];
                        final on = _selected.contains(app.packageName);
                        return GlassPanel(
                          highlighted: on,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          onTap: () {
                            setState(() {
                              if (on) {
                                _selected.remove(app.packageName);
                              } else {
                                _selected.add(app.packageName);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.label,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      app.packageName,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                on
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: on
                                    ? AppColors.cyanBright
                                    : AppColors.textMuted,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
