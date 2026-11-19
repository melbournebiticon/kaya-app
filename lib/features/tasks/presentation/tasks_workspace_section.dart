import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';
import 'package:kaya/features/tasks/presentation/quick_add_task_bar.dart';
import 'package:kaya/features/tasks/presentation/task_card_tile.dart';
import 'package:kaya/features/tasks/presentation/task_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Complete Phase 3 Task Management workspace section.
class TasksWorkspaceSection extends StatefulWidget {
  const TasksWorkspaceSection({super.key, required this.controller});

  final TaskController controller;

  @override
  State<TasksWorkspaceSection> createState() => _TasksWorkspaceSectionState();
}

class _TasksWorkspaceSectionState extends State<TasksWorkspaceSection> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final TaskController ctrl = widget.controller;
        final List<TaskItem> visibleTasks = ctrl.filteredTasks;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            KayaSectionHeader(
              title: 'Task Management',
              subtitle: 'Plan what needs to happen today and what comes next',
              trailing: KayaButton(
                key: const ValueKey<String>('open_new_task_dialog_button'),
                label: 'New Task',
                icon: Icons.add,
                onPressed: () => TaskFormDialog.show(context, controller: ctrl),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                Text(
                  'Today: ${ctrl.todayTasks.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ctrl.todayTasks.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.warning,
                  ),
                ),
                Text(
                  'Overdue: ${ctrl.overdueTasks.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ctrl.overdueTasks.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.error,
                  ),
                ),
                Text(
                  'Upcoming: ${ctrl.upcomingTasks.length}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.info),
                ),
                Text(
                  'Completed: ${ctrl.completedTasks.length}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            QuickAddTaskBar(controller: ctrl),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('task_search_field'),
              controller: _searchController,
              onChanged: ctrl.setSearchQuery,
              decoration: InputDecoration(
                labelText: 'Search tasks',
                hintText: 'Filter by title or notes...',
                prefixIcon: const Icon(Icons.search_outlined),
                suffixIcon: ctrl.searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ctrl.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final TaskFilterView view in TaskFilterView.values)
                  ChoiceChip(
                    key: ValueKey<String>('task_view_tab_${view.name}'),
                    label: Text(view.label),
                    selected: ctrl.selectedView == view,
                    onSelected: (_) => ctrl.setFilterView(view),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<TaskCategory?>(
                    key: const ValueKey<String>('task_category_filter'),
                    initialValue: ctrl.selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: <DropdownMenuItem<TaskCategory?>>[
                      const DropdownMenuItem<TaskCategory?>(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      for (final TaskCategory c in TaskCategory.values)
                        DropdownMenuItem<TaskCategory?>(
                          value: c,
                          child: Text(c.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: ctrl.setCategoryFilter,
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<TaskPriority?>(
                    key: const ValueKey<String>('task_priority_filter'),
                    initialValue: ctrl.selectedPriority,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: <DropdownMenuItem<TaskPriority?>>[
                      const DropdownMenuItem<TaskPriority?>(
                        value: null,
                        child: Text('All Priorities'),
                      ),
                      for (final TaskPriority p in TaskPriority.values)
                        DropdownMenuItem<TaskPriority?>(
                          value: p,
                          child: Text(p.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: ctrl.setPriorityFilter,
                  ),
                ),
                if (ctrl.selectedCategory != null ||
                    ctrl.selectedPriority != null ||
                    ctrl.searchQuery.isNotEmpty ||
                    ctrl.selectedView != TaskFilterView.all)
                  KayaButton(
                    label: 'Reset Filters',
                    variant: KayaButtonVariant.ghost,
                    onPressed: () {
                      _searchController.clear();
                      ctrl.clearFilters();
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTaskListBody(context, ctrl, visibleTasks),
          ],
        );
      },
    );
  }

  Widget _buildTaskListBody(
    BuildContext context,
    TaskController ctrl,
    List<TaskItem> visibleTasks,
  ) {
    if (ctrl.isLoading) {
      return const KayaLoadingState(
        title: 'Loading your tasks...',
        subtitle: 'Checking due dates and priorities.',
      );
    }

    if (ctrl.hasLoadError) {
      return KayaErrorState(
        title: 'Unable to Load Tasks',
        message:
            ctrl.errorMessage ??
            'Failed queries are never treated as empty data. Retry when ready.',
        onRetry: ctrl.loadTasks,
      );
    }

    if (visibleTasks.isEmpty) {
      final bool hasActiveFilters =
          ctrl.selectedCategory != null ||
          ctrl.selectedPriority != null ||
          ctrl.searchQuery.trim().isNotEmpty ||
          ctrl.selectedView != TaskFilterView.all;

      return KayaEmptyState(
        icon: Icons.task_alt_outlined,
        title: hasActiveFilters
            ? 'No Matching Tasks Found'
            : 'No Tasks Recorded Yet',
        description: hasActiveFilters
            ? 'No tasks match your current search or filter selection.'
            : 'Create your first task using Quick Add above or the New Task button.',
        actionLabel: hasActiveFilters ? 'Clear Filters' : 'Create Task',
        onAction: hasActiveFilters
            ? () {
                _searchController.clear();
                ctrl.clearFilters();
              }
            : () => TaskFormDialog.show(context, controller: ctrl),
      );
    }

    return Column(
      children: <Widget>[
        for (final TaskItem task in visibleTasks) ...<Widget>[
          TaskCardTile(
            key: ValueKey<String>('task_card_${task.id}'),
            task: task,
            controller: ctrl,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
