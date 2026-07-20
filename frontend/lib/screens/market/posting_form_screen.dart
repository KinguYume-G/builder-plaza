import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/project_card.dart';
import '../../models/role_posting.dart';
import '../../state/market_provider.dart';
import '../../state/projects_provider.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../widgets/brutal_badge.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_field.dart';
import '../../widgets/brutal_scaffold.dart';

/// F8: create a posting. A type toggle switches between the two shapes:
/// maintainer (link one of YOUR repo-backed projects + access tier) and
/// team_role (stage + tech stack + commitment all required).
class PostingFormScreen extends StatefulWidget {
  const PostingFormScreen({super.key});

  @override
  State<PostingFormScreen> createState() => _PostingFormScreenState();
}

class _PostingFormScreenState extends State<PostingFormScreen> {
  String _type = 'team_role';
  final _descController = TextEditingController();
  final _skillsController = TextEditingController();
  final _stageController = TextEditingController();
  final _stackController = TextEditingController();
  final _commitmentController = TextEditingController();
  String? _projectId;
  String _accessTier = 'claim_an_issue';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Maintainer postings need the user's own projects to link.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<ProjectsProvider>().fetchMine());
  }

  @override
  void dispose() {
    _descController.dispose();
    _skillsController.dispose();
    _stageController.dispose();
    _stackController.dispose();
    _commitmentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final skills = _skillsController.text
        .split(',')
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toList();
    final data = <String, dynamic>{
      'posting_type': _type,
      'role_desc': _descController.text.trim(),
      'skills': skills,
      if (_type == 'maintainer') ...{
        'project_id': _projectId,
        'access_tier': _accessTier,
      } else ...{
        'stage': _stageController.text.trim(),
        'tech_stack': _stackController.text.trim(),
        'commitment': _commitmentController.text.trim(),
      },
    };
    final provider = context.read<MarketProvider>();
    final posting = await provider.createPosting(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (posting != null) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posting published.')),
      );
    } else {
      setState(() => _error = provider.error ?? 'Could not publish.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myProjects = context
        .watch<ProjectsProvider>()
        .mine
        .where((project) =>
            !project.isArchived && project.repoFullNames.isNotEmpty)
        .toList();

    return BrutalScaffold(
      title: 'Post a role',
      titleBarColor: Palette.mustard,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BrutalBadge(
                      label: 'TEAM ROLE',
                      color: Palette.mustard,
                      selected: _type == 'team_role',
                      onTap: () => setState(() => _type = 'team_role'),
                    ),
                    const SizedBox(width: 8),
                    BrutalBadge(
                      label: 'MAINTAINER',
                      color: Palette.lime,
                      selected: _type == 'maintainer',
                      onTap: () => setState(() => _type = 'maintainer'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                BrutalField(
                  label: 'ROLE DESCRIPTION *',
                  controller: _descController,
                  hintText: 'What the role owns, what success looks like…',
                  maxLines: 4,
                ),
                const SizedBox(height: 14),
                BrutalField(
                  label: 'SKILLS (comma-separated)',
                  controller: _skillsController,
                  hintText: 'Flutter, FastAPI, Postgres',
                ),
                const SizedBox(height: 14),
                if (_type == 'team_role') ...[
                  BrutalField(
                    label: 'STAGE *',
                    controller: _stageController,
                    hintText: 'idea / mvp / launched…',
                  ),
                  const SizedBox(height: 14),
                  BrutalField(
                    label: 'TECH STACK *',
                    controller: _stackController,
                    hintText: 'Flutter + FastAPI + Postgres',
                  ),
                  const SizedBox(height: 14),
                  BrutalField(
                    label: 'COMMITMENT *',
                    controller: _commitmentController,
                    hintText: '10h/week, evenings…',
                  ),
                ] else ...[
                  Text('LINK YOUR PROJECT *',
                      style: AppType.mono(
                          size: 11,
                          color: Palette.ink400,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (myProjects.isEmpty)
                    BrutalCard(
                      background: Palette.cream100,
                      child: Text(
                        'You need a project with linked repositories to '
                        'post a maintainer role.',
                        style: AppType.body(
                            size: 13, color: Palette.ink600),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ProjectCard project in myProjects)
                          BrutalBadge(
                            label: project.title,
                            color: Palette.cobalt,
                            textColor: _projectId == project.id
                                ? Palette.paper
                                : Palette.ink,
                            selected: _projectId == project.id,
                            onTap: () => setState(
                                () => _projectId = project.id),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  Text('ACCESS TIER *',
                      style: AppType.mono(
                          size: 11,
                          color: Palette.ink400,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tier in kAccessTiers)
                        BrutalBadge(
                          label: kAccessTierLabels[tier] ?? tier,
                          color: Palette.lime,
                          selected: _accessTier == tier,
                          onTap: () =>
                              setState(() => _accessTier = tier),
                        ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  BrutalCard(
                    accent: Palette.tomato,
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!,
                        style: AppType.body(
                            size: 13, color: Palette.tomato)),
                  ),
                ],
                const SizedBox(height: 20),
                BrutalButton(
                  label: 'Publish posting',
                  color: Palette.cobalt,
                  loading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
