import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/task_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';
import 'package:material_ui/material_ui.dart';

/// Dialog for creating a new task or editing an existing task.
class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({
    super.key,
    required this.controller,
    this.existingTask,
  });

  final TaskController controller;
  final TaskItem? existingTask;

  static Future<bool> show(
    BuildContext context, {
    required TaskController controller,
    TaskItem? existingTask,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) =>
          TaskFormDialog(controller: controller, existingTask: existingTask),
    );
    return saved ?? false;
  }

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late TaskPriority _priority;
  late TaskCategory _category;
  KayaDateOnly? _dueDate;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final TaskItem? existing = widget.existingTask;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _priority = existing?.priority ?? TaskPriority.medium;
    _category = existing?.category ?? TaskCategory.personal;
    _dueDate = existing?.dueDate ?? widget.controller.referenceToday;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDate() async {
    final KayaDateOnly today = widget.controller.referenceToday;
    final KayaDateOnly initial = _dueDate ?? today;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.toLocalDateTime(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = KayaDateOnly.fromDateTime(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final bool success;
    if (_isEditing) {
      success = await widget.controller.updateTask(
        taskId: widget.existingTask!.id,
        title: _titleController.text,
        notes: _notesController.text,
        priority: _priority,
        category: _category,
        dueDate: _dueDate,
      );
    } else {
      success = await widget.controller.createTask(
        title: _titleController.text,
        notes: _notesController.text,
        priority: _priority,
        category: _category,
        dueDate: _dueDate,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final KayaDateOnly today = widget.controller.referenceToday;
    final KayaDateOnly tomorrow = today.addDays(1);
    final KayaDateOnly nextWeek = today.addDays(7);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final bool isMutating = widget.controller.isMutating;
        final String? errorMessage = widget.controller.errorMessage;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text(_isEditing ? 'Edit Task' : 'Create New Task'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (errorMessage != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.errorSurface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Text(
                          errorMessage,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      key: const ValueKey<String>('task_form_title_field'),
                      controller: _titleController,
                      enabled: !isMutating,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        hintText: 'What needs to be done?',
                        prefixIcon: Icon(Icons.task_alt_outlined),
                      ),
                      validator: TaskValidators.validateTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('task_form_notes_field'),
                      controller: _notesController,
                      enabled: !isMutating,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Add context or details',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      validator: TaskValidators.validateNotes,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<TaskPriority>(
                      key: const ValueKey<String>('task_form_priority_field'),
                      initialValue: _priority,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: TaskPriority.values
                          .map(
                            (TaskPriority p) => DropdownMenuItem<TaskPriority>(
                              value: p,
                              child: Text(
                                p.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isMutating
                          ? null
                          : (TaskPriority? next) {
                              if (next != null) {
                                setState(() {
                                  _priority = next;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<TaskCategory>(
                      key: const ValueKey<String>('task_form_category_field'),
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: TaskCategory.values
                          .map(
                            (TaskCategory c) => DropdownMenuItem<TaskCategory>(
                              value: c,
                              child: Text(
                                c.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isMutating
                          ? null
                          : (TaskCategory? next) {
                              if (next != null) {
                                setState(() {
                                  _category = next;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Due Date', style: textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    KayaStatusBadge(
                      label: _dueDate == null
                          ? 'No due date set'
                          : 'Due: ${_dueDate!.formatReadable()} (${_dueDate!.toIsoDateString()})',
                      type: _dueDate == null
                          ? KayaStatusType.neutral
                          : KayaStatusType.info,
                      customIcon: Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        KayaButton(
                          label: 'Today',
                          variant: _dueDate == today
                              ? KayaButtonVariant.primary
                              : KayaButtonVariant.outline,
                          onPressed: isMutating
                              ? null
                              : () => setState(() {
                                  _dueDate = today;
                                }),
                        ),
                        KayaButton(
                          label: 'Tomorrow',
                          variant: _dueDate == tomorrow
                              ? KayaButtonVariant.primary
                              : KayaButtonVariant.outline,
                          onPressed: isMutating
                              ? null
                              : () => setState(() {
                                  _dueDate = tomorrow;
                                }),
                        ),
                        KayaButton(
                          label: '+7 Days',
                          variant: _dueDate == nextWeek
                              ? KayaButtonVariant.primary
                              : KayaButtonVariant.outline,
                          onPressed: isMutating
                              ? null
                              : () => setState(() {
                                  _dueDate = nextWeek;
                                }),
                        ),
                        KayaButton(
                          label: 'Pick Date',
                          icon: Icons.event_outlined,
                          variant: KayaButtonVariant.secondary,
                          onPressed: isMutating ? null : _pickCustomDate,
                        ),
                        if (_dueDate != null)
                          KayaButton(
                            label: 'Clear Date',
                            variant: KayaButtonVariant.ghost,
                            onPressed: isMutating
                                ? null
                                : () => setState(() {
                                    _dueDate = null;
                                  }),
                          ),
                      ],
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
              onPressed: isMutating
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
            KayaButton(
              key: const ValueKey<String>('task_form_save_button'),
              label: _isEditing ? 'Save Changes' : 'Create Task',
              icon: Icons.check,
              isLoading: isMutating,
              onPressed: _handleSave,
            ),
          ],
        );
      },
    );
  }
}
