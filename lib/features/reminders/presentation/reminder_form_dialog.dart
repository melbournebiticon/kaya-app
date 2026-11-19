import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/bill_reminder_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:material_ui/material_ui.dart';

/// Modal dialog for creating or editing a reminder in Phase 5.
class ReminderFormDialog extends StatefulWidget {
  const ReminderFormDialog({
    super.key,
    required this.controller,
    this.existingReminder,
  });

  final ReminderController controller;
  final ReminderItem? existingReminder;

  static Future<bool> show(
    BuildContext context, {
    required ReminderController controller,
    ReminderItem? existingReminder,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => ReminderFormDialog(
        controller: controller,
        existingReminder: existingReminder,
      ),
    );
    return saved ?? false;
  }

  @override
  State<ReminderFormDialog> createState() => _ReminderFormDialogState();
}

class _ReminderFormDialogState extends State<ReminderFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late KayaDateOnly _dueDate;

  bool get _isEditing => widget.existingReminder != null;

  @override
  void initState() {
    super.initState();
    final ReminderItem? existing = widget.existingReminder;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _dueDate = existing?.dueDate ?? widget.controller.referenceToday;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.toLocalDateTime(),
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
      success = await widget.controller.updateReminder(
        reminderId: widget.existingReminder!.id,
        title: _titleController.text,
        notes: _notesController.text,
        dueDate: _dueDate,
      );
    } else {
      success = await widget.controller.createReminder(
        title: _titleController.text,
        notes: _notesController.text,
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
          title: Text(_isEditing ? 'Edit Reminder' : 'Add Reminder'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
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
                      key: const ValueKey<String>('reminder_form_title_field'),
                      controller: _titleController,
                      enabled: !isMutating,
                      maxLength: BillReminderValidators.maxTitleLength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Reminder Title',
                        hintText: 'e.g., Renew Driver License',
                      ),
                      validator: (String? val) =>
                          BillReminderValidators.validateTitle(
                            val,
                            fieldName: 'Reminder title',
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Reminder Date', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: _dueDate == today,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() => _dueDate = today),
                        ),
                        ChoiceChip(
                          label: const Text('Tomorrow'),
                          selected: _dueDate == tomorrow,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() => _dueDate = tomorrow),
                        ),
                        ChoiceChip(
                          label: const Text('Next Week'),
                          selected: _dueDate == nextWeek,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() => _dueDate = nextWeek),
                        ),
                        ActionChip(
                          key: const ValueKey<String>(
                            'reminder_form_date_picker_button',
                          ),
                          avatar: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          label: Text(_dueDate.formatReadable()),
                          onPressed: isMutating ? null : _pickDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('reminder_form_notes_field'),
                      controller: _notesController,
                      enabled: !isMutating,
                      maxLength: BillReminderValidators.maxNotesLength,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Important requirements or time notes',
                      ),
                      validator: BillReminderValidators.validateNotes,
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
              key: const ValueKey<String>('reminder_form_save_button'),
              label: _isEditing ? 'Save Changes' : 'Save Reminder',
              isLoading: isMutating,
              onPressed: isMutating ? null : _handleSave,
            ),
          ],
        );
      },
    );
  }
}
