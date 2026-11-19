import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/task_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:material_ui/material_ui.dart';

enum _QuickDuePreset { today, tomorrow, none }

/// Quick Add bar for rapidly creating tasks from the Today or Life screens.
class QuickAddTaskBar extends StatefulWidget {
  const QuickAddTaskBar({super.key, required this.controller});

  final TaskController controller;

  @override
  State<QuickAddTaskBar> createState() => _QuickAddTaskBarState();
}

class _QuickAddTaskBarState extends State<QuickAddTaskBar> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  _QuickDuePreset _duePreset = _QuickDuePreset.today;
  TaskPriority _priority = TaskPriority.medium;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  KayaDateOnly? _resolveDueDate() {
    final KayaDateOnly today = widget.controller.referenceToday;
    return switch (_duePreset) {
      _QuickDuePreset.today => today,
      _QuickDuePreset.tomorrow => today.addDays(1),
      _QuickDuePreset.none => null,
    };
  }

  Future<void> _submitQuickAdd() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final bool created = await widget.controller.createTask(
      title: _titleController.text,
      priority: _priority,
      category: TaskCategory.personal,
      dueDate: _resolveDueDate(),
    );

    if (created && mounted) {
      _titleController.clear();
      setState(() {
        _duePreset = _QuickDuePreset.today;
        _priority = TaskPriority.medium;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final bool isMutating = widget.controller.isMutating;

        return KayaCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: const ValueKey<String>('quick_add_task_field'),
                  controller: _titleController,
                  enabled: !isMutating,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitQuickAdd(),
                  decoration: const InputDecoration(
                    labelText: 'Quick Add Task',
                    hintText: 'Add a task for today...',
                    prefixIcon: Icon(Icons.add_task_outlined),
                  ),
                  validator: TaskValidators.validateTitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        KayaButton(
                          label: 'Due Today',
                          variant: _duePreset == _QuickDuePreset.today
                              ? KayaButtonVariant.secondary
                              : KayaButtonVariant.outline,
                          onPressed: isMutating
                              ? null
                              : () => setState(() {
                                  _duePreset = _QuickDuePreset.today;
                                }),
                        ),
                        KayaButton(
                          label: 'Tomorrow',
                          variant: _duePreset == _QuickDuePreset.tomorrow
                              ? KayaButtonVariant.secondary
                              : KayaButtonVariant.outline,
                          onPressed: isMutating
                              ? null
                              : () => setState(() {
                                  _duePreset = _QuickDuePreset.tomorrow;
                                }),
                        ),
                        KayaButton(
                          label: 'High Priority',
                          variant: _priority == TaskPriority.high
                              ? KayaButtonVariant.secondary
                              : KayaButtonVariant.outline,
                          onPressed: isMutating
                              ? null
                              : () => setState(() {
                                  _priority = _priority == TaskPriority.high
                                      ? TaskPriority.medium
                                      : TaskPriority.high;
                                }),
                        ),
                      ],
                    ),
                    KayaButton(
                      key: const ValueKey<String>('quick_add_submit_button'),
                      label: 'Quick Add',
                      icon: Icons.add,
                      isLoading: isMutating,
                      onPressed: _submitQuickAdd,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
