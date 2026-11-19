import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_organization_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:material_ui/material_ui.dart';

/// Daily Routines workspace inside [LifeScreen] (Phase 7).
class RoutinesWorkspaceSection extends StatefulWidget {
  const RoutinesWorkspaceSection({super.key, required this.controller});

  final LifeOrganizationController controller;

  @override
  State<RoutinesWorkspaceSection> createState() =>
      _RoutinesWorkspaceSectionState();
}

class _RoutinesWorkspaceSectionState extends State<RoutinesWorkspaceSection> {
  final Map<String, TextEditingController> _stepControllers =
      <String, TextEditingController>{};

  @override
  void dispose() {
    for (final TextEditingController ctrl in _stepControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController _stepControllerFor(String routineId) {
    return _stepControllers.putIfAbsent(routineId, TextEditingController.new);
  }

  Future<void> _showCreateRoutineDialog() async {
    final _RoutineDialogResult? result = await showDialog<_RoutineDialogResult>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateRoutineDialog(),
    );

    if (result != null) {
      await widget.controller.createRoutine(
        title: result.title,
        scheduledWeekdays: result.scheduledWeekdays,
        initialSteps: result.firstStep.isNotEmpty
            ? <String>[result.firstStep]
            : const <String>[],
      );
    }
  }

  Future<void> _handleAddStep(String routineId) async {
    final TextEditingController ctrl = _stepControllerFor(routineId);
    final String? err = LifeOrganizationValidators.validateTitle(
      ctrl.text,
      fieldName: 'Routine step',
    );
    if (err != null) {
      return;
    }
    final bool ok = await widget.controller.addRoutineStep(
      routineId: routineId,
      title: ctrl.text,
    );
    if (ok && mounted) {
      ctrl.clear();
    }
  }

  Future<void> _handleDeleteRoutine(DailyRoutine routine) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Routine?',
      message:
          'Are you sure you want to delete "${routine.title}" and its streak history?',
      confirmLabel: 'Delete Routine',
    );
    if (confirmed) {
      await widget.controller.deleteRoutine(routine.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) =>
          _buildContent(context, widget.controller),
    );
  }

  Widget _buildContent(BuildContext context, LifeOrganizationController ctrl) {
    final List<DailyRoutine> routines = ctrl.routines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KayaSectionHeader(
          title: 'Daily Routines',
          subtitle: 'Build consistent habits on your chosen days',
          trailing: KayaButton(
            key: const ValueKey<String>('routines_create_button'),
            label: 'New Routine',
            icon: Icons.add,
            onPressed: ctrl.isMutating ? null : _showCreateRoutineDialog,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (ctrl.isLoading && routines.isEmpty)
          const KayaLoadingState(
            title: 'Loading routines...',
            subtitle: 'Checking today\'s schedule and streaks.',
          )
        else if (ctrl.hasLoadError)
          KayaErrorState(
            title: 'Unable to Load Routines',
            message:
                ctrl.errorMessage ??
                'Could not fetch routines. Please try again.',
            onRetry: ctrl.loadAll,
          )
        else if (routines.isEmpty)
          KayaEmptyState(
            icon: Icons.repeat_outlined,
            title: 'No Daily Routines Yet',
            description: 'Set up morning, evening, or weekday routines with ordered steps and automatic streak tracking.',
            actionLabel: 'Create Routine',
            onAction: _showCreateRoutineDialog,
          )
        else
          Column(
            children: <Widget>[
              for (final DailyRoutine routine in routines) ...<Widget>[
                _buildRoutineCard(context, ctrl, routine),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildRoutineCard(
    BuildContext context,
    LifeOrganizationController ctrl,
    DailyRoutine routine,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final KayaDateOnly today = ctrl.referenceToday;
    final bool scheduledToday = routine.isScheduledOn(today);
    final int doneCount = routine.completedStepsCountOn(today);
    final int totalSteps = routine.steps.length;
    final int streak = routine.currentStreak(today);
    final TextEditingController stepCtrl = _stepControllerFor(routine.id);

    return KayaCard(
      key: ValueKey<String>('routine_card_${routine.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(routine.title, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 2,
                      children: <Widget>[
                        Text(
                          RoutineWeekday.formatScheduleSummary(
                            routine.scheduledWeekdays,
                          ),
                          style: textTheme.bodySmall,
                        ),
                        Text(
                          '$streak day${streak == 1 ? '' : 's'} streak',
                          key: ValueKey<String>('routine_streak_${routine.id}'),
                          style: textTheme.bodySmall?.copyWith(
                            color: streak > 0
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: streak > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (scheduledToday && totalSteps > 0)
                          Text(
                            routine.isCompletedOn(today)
                                ? 'Done today'
                                : '$doneCount/$totalSteps today',
                            style: textTheme.bodySmall?.copyWith(
                              color: routine.isCompletedOn(today)
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          )
                        else if (!scheduledToday)
                          Text('Rest day today', style: textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey<String>('routine_delete_${routine.id}'),
                tooltip: 'Delete routine',
                icon: const Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: AppColors.textMuted,
                ),
                onPressed: ctrl.isMutating
                    ? null
                    : () => _handleDeleteRoutine(routine),
              ),
            ],
          ),
          if (totalSteps > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: routine.progressRatioOn(today),
                minHeight: 5,
                backgroundColor: AppColors.background,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.secondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (routine.steps.isEmpty)
            Text(
              'No steps yet. Add the steps for this routine below.',
              style: textTheme.bodySmall,
            )
          else
            Column(
              children: <Widget>[
                for (final RoutineStep step in routine.steps)
                  Row(
                    children: <Widget>[
                      IconButton(
                        key: ValueKey<String>('routine_step_toggle_${step.id}'),
                        tooltip: routine.isStepCompletedOn(step.id, today)
                            ? 'Mark incomplete today'
                            : 'Complete step today',
                        onPressed: ctrl.isMutating
                            ? null
                            : () => ctrl.toggleRoutineStepToday(
                                routineId: routine.id,
                                stepId: step.id,
                                isCompleted: !routine.isStepCompletedOn(
                                  step.id,
                                  today,
                                ),
                              ),
                        icon: Icon(
                          routine.isStepCompletedOn(step.id, today)
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: routine.isStepCompletedOn(step.id, today)
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step.title,
                          style: textTheme.bodyMedium?.copyWith(
                            decoration:
                                routine.isStepCompletedOn(step.id, today)
                                ? TextDecoration.lineThrough
                                : null,
                            color: routine.isStepCompletedOn(step.id, today)
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove step',
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        onPressed: ctrl.isMutating
                            ? null
                            : () => ctrl.deleteRoutineStep(
                                routineId: routine.id,
                                stepId: step.id,
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: ValueKey<String>('routine_add_step_field_${routine.id}'),
                  controller: stepCtrl,
                  enabled: !ctrl.isMutating,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleAddStep(routine.id),
                  decoration: const InputDecoration(
                    labelText: 'Add step',
                    hintText: 'e.g., Stretch for 5 minutes',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              KayaButton(
                key: ValueKey<String>('routine_add_step_button_${routine.id}'),
                label: 'Add Step',
                variant: KayaButtonVariant.secondary,
                onPressed: ctrl.isMutating
                    ? null
                    : () => _handleAddStep(routine.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineDialogResult {
  const _RoutineDialogResult({
    required this.title,
    required this.scheduledWeekdays,
    required this.firstStep,
  });

  final String title;
  final Set<int> scheduledWeekdays;
  final String firstStep;
}

class _CreateRoutineDialog extends StatefulWidget {
  const _CreateRoutineDialog();

  @override
  State<_CreateRoutineDialog> createState() => _CreateRoutineDialogState();
}

class _CreateRoutineDialogState extends State<_CreateRoutineDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _firstStepCtrl = TextEditingController();
  final Set<int> _selectedWeekdays = Set<int>.from(RoutineWeekday.allWeekdays);
  String? _dayError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _firstStepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Routine'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: const ValueKey<String>('routine_form_title_field'),
                  controller: _titleCtrl,
                  autofocus: true,
                  maxLength: LifeOrganizationValidators.maxTitleLength,
                  decoration: const InputDecoration(
                    labelText: 'Routine Name',
                    hintText: 'e.g., Morning Reset',
                  ),
                  validator: (String? val) =>
                      LifeOrganizationValidators.validateTitle(
                        val,
                        fieldName: 'Routine name',
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Scheduled Days',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final RoutineWeekday day in RoutineWeekday.values)
                      FilterChip(
                        key: ValueKey<String>('routine_day_${day.isoWeekday}'),
                        label: Text(day.shortLabel),
                        selected: _selectedWeekdays.contains(day.isoWeekday),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedWeekdays.add(day.isoWeekday);
                            } else {
                              _selectedWeekdays.remove(day.isoWeekday);
                            }
                            _dayError = null;
                          });
                        },
                      ),
                  ],
                ),
                if (_dayError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _dayError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const ValueKey<String>('routine_form_step_field'),
                  controller: _firstStepCtrl,
                  maxLength: LifeOrganizationValidators.maxTitleLength,
                  decoration: const InputDecoration(
                    labelText: 'First Step (Optional)',
                    hintText: 'e.g., Drink 500ml water',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        KayaButton(
          label: 'Cancel',
          variant: KayaButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        KayaButton(
          key: const ValueKey<String>('routine_form_save_button'),
          label: 'Create',
          onPressed: () {
            final String? err =
                LifeOrganizationValidators.validateScheduledWeekdays(
                  _selectedWeekdays,
                );
            setState(() {
              _dayError = err;
            });
            if ((_formKey.currentState?.validate() ?? false) && err == null) {
              Navigator.of(context).pop(
                _RoutineDialogResult(
                  title: _titleCtrl.text,
                  scheduledWeekdays: Set<int>.from(_selectedWeekdays),
                  firstStep: _firstStepCtrl.text.trim(),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
