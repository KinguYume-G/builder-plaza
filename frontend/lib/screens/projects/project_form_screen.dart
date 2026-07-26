import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/project_card.dart';
import '../../state/projects_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_field.dart';
import '../../widgets/brutal_scaffold.dart';

/// Create OR edit a project. When [projectId] is null this is a create form;
/// otherwise it loads the existing project and PATCHes changes.
///
/// Screenshots can only be uploaded once a project exists (the upload endpoints
/// are keyed by id), so in create mode that section is disabled until the first
/// save — after which the form flips into edit mode in place.
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key, this.projectId});

  final String? projectId;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _titleController = TextEditingController();
  final _needsController = TextEditingController();
  final _demoController = TextEditingController();
  final _divisionController = TextEditingController();
  final _repoController = TextEditingController();

  String? _stage;
  final List<String> _repos = [];

  /// The current server-side card (null until an existing one is loaded or a
  /// create succeeds). Drives the screenshot gallery.
  ProjectCard? _card;

  bool _loading = false;
  bool _saving = false;
  bool _submitted = false; // show validation only after a save attempt

  // Inline validation errors.
  String? _titleError;
  String? _stageError;
  String? _demoError;
  String? _repoError;

  bool get _isEdit => _card != null;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _needsController.dispose();
    _demoController.dispose();
    _divisionController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final card =
          await context.read<ProjectsProvider>().fetchOne(widget.projectId!);
      if (!mounted) return;
      _adopt(card);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Populate the form from a card and switch into edit mode.
  void _adopt(ProjectCard card) {
    setState(() {
      _card = card;
      _titleController.text = card.title;
      _needsController.text = card.needs ?? '';
      _demoController.text = card.demoUrl ?? '';
      _divisionController.text = card.teamDivision ?? '';
      _stage = card.stage;
      _repos
        ..clear()
        ..addAll(card.repoFullNames);
    });
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  bool _validate() {
    final title = _titleController.text.trim();
    final demo = _demoController.text.trim();

    String? titleErr;
    if (title.isEmpty) {
      titleErr = 'Title is required.';
    } else if (title.length > 120) {
      titleErr = 'Keep the title under 120 characters.';
    }

    final stageErr = _stage == null ? 'Pick a stage.' : null;

    String? demoErr;
    if (demo.isNotEmpty && !_looksLikeUrl(demo)) {
      demoErr = 'Enter a valid http(s) URL.';
    }

    setState(() {
      _titleError = titleErr;
      _stageError = stageErr;
      _demoError = demoErr;
    });
    return titleErr == null && stageErr == null && demoErr == null;
  }

  bool _looksLikeUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Repo chips
  // ---------------------------------------------------------------------------

  void _addRepo() {
    final raw = _repoController.text.trim();
    if (raw.isEmpty) return;
    final parts = raw.split('/');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      setState(() => _repoError = 'Use the form owner/repo.');
      return;
    }
    if (_repos.contains(raw)) {
      _repoController.clear();
      return;
    }
    setState(() {
      _repos.add(raw);
      _repoController.clear();
      _repoError = null;
    });
  }

  void _removeRepo(String repo) => setState(() => _repos.remove(repo));

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_validate()) return;

    final provider = context.read<ProjectsProvider>();
    setState(() => _saving = true);

    ProjectCard? result;
    if (_isEdit) {
      result = await provider.updateProject(_card!.id, {
        'title': _titleController.text.trim(),
        'stage': _stage,
        'needs': _needsController.text.trim(),
        'demo_url': _demoController.text.trim(),
        'team_division': _divisionController.text.trim(),
        'repo_full_names': _repos,
      });
    } else {
      result = await provider.createProject(
        title: _titleController.text.trim(),
        stage: _stage!,
        needs: _needsController.text.trim(),
        demoUrl: _demoController.text.trim(),
        teamDivision: _divisionController.text.trim(),
        repoFullNames: _repos,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) return; // provider.error is shown inline

    if (_isEdit) {
      _goToDetail(result.id);
    } else {
      // Adopt so the user can now add screenshots without leaving.
      _adopt(result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project created — add screenshots below, '
              'or view the project.'),
        ),
      );
    }
  }

  void _goToDetail(String id) {
    if (context.canPop()) {
      context.pop();
    }
    context.go('/projects/$id');
  }

  // ---------------------------------------------------------------------------
  // Screenshots
  // ---------------------------------------------------------------------------

  Future<void> _pickScreenshot() async {
    final card = _card;
    if (card == null) return;
    final XFile? file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final updated =
        await context.read<ProjectsProvider>().uploadScreenshot(card.id, file);
    if (!mounted) return;
    if (updated != null) setState(() => _card = updated);
  }

  Future<void> _removeScreenshot(String key) async {
    final card = _card;
    if (card == null) return;
    final updated =
        await context.read<ProjectsProvider>().removeScreenshot(card.id, key);
    if (!mounted) return;
    if (updated != null) setState(() => _card = updated);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectsProvider>();

    return BrutalScaffold(
      title: _isEdit ? 'Edit Project' : 'New Project',
      titleBarColor: Palette.teal,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Palette.ink))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BrutalField(
                        label: 'Title',
                        controller: _titleController,
                        hintText: 'What are you building?',
                        maxLength: 120,
                        errorText: _titleError,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_submitted) _validate();
                        },
                      ),
                      const SizedBox(height: 20),
                      _StagePicker(
                        selected: _stage,
                        errorText: _stageError,
                        onSelect: (s) => setState(() {
                          _stage = s;
                          if (_submitted) _stageError = null;
                        }),
                      ),
                      const SizedBox(height: 20),
                      BrutalField(
                        label: 'Needs (optional)',
                        controller: _needsController,
                        hintText: 'Who or what are you looking for?',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      BrutalField(
                        label: 'Demo URL (optional)',
                        controller: _demoController,
                        hintText: 'https://…',
                        keyboardType: TextInputType.url,
                        errorText: _demoError,
                        onChanged: (_) {
                          if (_submitted) _validate();
                        },
                      ),
                      const SizedBox(height: 20),
                      BrutalField(
                        label: 'Team division (optional)',
                        controller: _divisionController,
                        hintText: 'How is the work split?',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      _RepoChipsInput(
                        controller: _repoController,
                        repos: _repos,
                        errorText: _repoError,
                        onAdd: _addRepo,
                        onRemove: _removeRepo,
                      ),
                      const SizedBox(height: 24),
                      _ScreenshotSection(
                        card: _card,
                        uploading: provider.uploading,
                        onAdd: _pickScreenshot,
                        onRemove: _removeScreenshot,
                      ),
                      if (provider.error != null) ...[
                        const SizedBox(height: 20),
                        BrutalCard(
                          accent: Palette.tomato,
                          background: const Color(0xFFFFF1EE),
                          child: Text(provider.error!,
                              style: AppType.body(
                                  size: 14, color: Palette.tomato)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      BrutalButton(
                        label: _isEdit ? 'Save changes' : 'Create project',
                        color: Palette.teal,
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                      if (_isEdit) ...[
                        const SizedBox(height: 12),
                        BrutalButton(
                          label: 'View project',
                          color: Palette.cream100,
                          textColor: Palette.ink,
                          onPressed: () => _goToDetail(_card!.id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Stage picker rendered as a wrap of selectable brutalist badges.
class _StagePicker extends StatelessWidget {
  const _StagePicker({
    required this.selected,
    required this.onSelect,
    this.errorText,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STAGE',
            style: AppType.mono(
                size: 11,
                color: hasError ? Palette.tomato : Palette.ink400,
                weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stage in kStages)
              BrutalBadge(
                label: stageLabel(stage),
                color: Palette.teal,
                textColor: Palette.paper,
                selected: selected == stage,
                onTap: () => onSelect(stage),
              ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(errorText!,
              style: AppType.mono(
                  size: 12, color: Palette.tomato, weight: FontWeight.w700)),
        ],
      ],
    );
  }
}

/// Repo input: type `owner/repo`, press enter (or ＋) to add a badge chip.
class _RepoChipsInput extends StatelessWidget {
  const _RepoChipsInput({
    required this.controller,
    required this.repos,
    required this.onAdd,
    required this.onRemove,
    this.errorText,
  });

  final TextEditingController controller;
  final List<String> repos;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LINKED REPOS (optional)'.toUpperCase(),
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: AppType.mono(size: 14, weight: FontWeight.w600),
                cursorColor: Palette.teal,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  hintText: 'owner/repo',
                  hintStyle: AppType.mono(size: 14, color: Palette.ink400),
                  filled: true,
                  fillColor: Palette.paper,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                        color: hasError ? Palette.tomato : Palette.ink,
                        width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        const BorderSide(color: Palette.teal, width: 2.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            BrutalButton(
              label: '＋ Add',
              expand: false,
              color: Palette.teal,
              onPressed: onAdd,
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(errorText!,
              style: AppType.mono(
                  size: 12, color: Palette.tomato, weight: FontWeight.w700)),
        ],
        if (repos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final repo in repos)
                GestureDetector(
                  onTap: () => onRemove(repo),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Palette.paper,
                      border: Border.all(color: Palette.ink, width: 2),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                            color: Palette.ink,
                            offset: Offset(2, 2),
                            blurRadius: 0),
                      ],
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(repo,
                            style: AppType.mono(
                                size: 12, weight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Icon(Icons.close, size: 14, color: Palette.ink400),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Screenshot gallery + upload control. Disabled (with a hint) until the
/// project exists.
class _ScreenshotSection extends StatelessWidget {
  const _ScreenshotSection({
    required this.card,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final ProjectCard? card;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCREENSHOTS',
            style: AppType.mono(
                size: 11, color: Palette.ink400, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (card == null)
          BrutalCard(
            background: Palette.cream100,
            padding: const EdgeInsets.all(12),
            child: Text(
              'Save the project first to add screenshots.',
              style: AppType.body(size: 13, color: Palette.ink600),
            ),
          )
        else ...[
          if (card!.screenshots.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final shot in card!.screenshots)
                  _Thumb(
                    url: shot.url,
                    onRemove: () => onRemove(shot.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          BrutalButton(
            label: uploading ? 'Uploading…' : '＋ Add screenshot',
            expand: false,
            color: Palette.mustard,
            textColor: Palette.ink,
            loading: uploading,
            onPressed: uploading ? null : onAdd,
          ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: Palette.cream100,
              border: Border.all(color: Palette.ink, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image, color: Palette.ink400),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.tomato,
                  border: Border.all(color: Palette.ink, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close,
                    size: 14, color: Palette.paper),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
