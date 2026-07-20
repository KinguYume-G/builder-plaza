// Pure model-parsing tests: every fromJson must survive complete, partial and
// wrongly-typed payloads (the app's defensive-parsing contract).
import 'package:flutter_test/flutter_test.dart';

import 'package:builder_plaza/models/activity.dart';
import 'package:builder_plaza/models/collab.dart';
import 'package:builder_plaza/models/growth_post.dart';
import 'package:builder_plaza/models/match.dart';
import 'package:builder_plaza/models/role_posting.dart';
import 'package:builder_plaza/models/trust_score.dart';

void main() {
  group('GrowthPost', () {
    test('parses full payload', () {
      final post = GrowthPost.fromJson({
        'id': 'g1',
        'project_id': 'p1',
        'summary': 'Shipped things.',
        'trigger': 'manual',
        'source_events': [
          {'type': 'PushEvent', 'repo': 'a/b', 'detail': '3 commit(s)'},
          {'type': 'ReleaseEvent', 'repo': 'a/b'},
        ],
        'created_at': '2026-07-19T12:00:00Z',
      });
      expect(post.summary, 'Shipped things.');
      expect(post.sourceEvents, hasLength(2));
      expect(post.sourceEvents.first.typeLabel, 'PUSH');
      expect(post.createdAt, isNotNull);
    });

    test('degrades on empty payload', () {
      final post = GrowthPost.fromJson(const {});
      expect(post.summary, '');
      expect(post.sourceEvents, isEmpty);
    });
  });

  group('MatchItem', () {
    test('parses candidate + reason', () {
      final match = MatchItem.fromJson({
        'id': 'm1',
        'candidate': {
          'id': 'u1',
          'github_login': 'aisha',
          'primary_role': 'collaborator',
          'trust_score': 71.5,
        },
        'score': 0.83,
        'exploratory': true,
        'match_reason': 'Shared skills: Python.',
        'state': 'active',
      });
      expect(match.candidate.githubLogin, 'aisha');
      expect(match.candidate.trustScore, 71.5);
      expect(match.exploratory, isTrue);
      expect(match.matchReason, contains('Python'));
    });

    test('missing candidate degrades to placeholder', () {
      final match = MatchItem.fromJson(const {'id': 'm2'});
      expect(match.candidate.githubLogin, '');
      expect(match.score, 0);
    });
  });

  group('TrustScore', () {
    test('parses components with availability flags', () {
      final score = TrustScore.fromJson({
        'github_login': 'x',
        'total': 83.0,
        'components': [
          {
            'key': 'payment',
            'label': 'Payment identity',
            'score': 100.0,
            'weight': 0.1,
            'available': true,
            'simulated': true,
          },
          {
            'key': 'peer',
            'label': 'Peer reviews',
            'weight': 0.25,
            'available': false,
          },
        ],
      });
      expect(score.total, 83.0);
      expect(score.components.first.simulated, isTrue);
      expect(score.components.last.score, isNull);
    });
  });

  group('CollabRequestItem', () {
    test('parses states and intent label', () {
      final request = CollabRequestItem.fromJson({
        'id': 'r1',
        'from_user': {'id': 'a', 'github_login': 'a', 'primary_role': 'builder'},
        'to_user': {'id': 'b', 'github_login': 'b', 'primary_role': 'founder'},
        'intent_type': 'cofounder',
        'pitch': 'Let us build.',
        'state': 'accepted',
        'conversation_id': 'c1',
      });
      expect(request.intentLabel, 'Co-founder');
      expect(request.conversationId, 'c1');
    });
  });

  group('RolePosting', () {
    test('maintainer flags and tier labels', () {
      final posting = RolePosting.fromJson({
        'id': 'p1',
        'posting_type': 'maintainer',
        'role_desc': 'Triage.',
        'skills': ['C'],
        'status': 'open',
        'owner': {'id': 'o', 'github_login': 'o', 'primary_role': 'builder'},
        'access_tier': 'claim_an_issue',
      });
      expect(posting.isMaintainer, isTrue);
      expect(kAccessTierLabels[posting.accessTier], 'Claim an issue');
    });
  });

  group('OwnershipEvidence', () {
    test('parses weekly buckets and roles', () {
      final evidence = OwnershipEvidence.fromJson({
        'github_login': 'x',
        'weekly_activity': [
          {'week_start': '2026-07-13', 'count': 3},
        ],
        'active_weeks': 1,
        'total_weeks': 12,
        'repo_roles': [
          {'repo': 'x/y', 'role': 'owner', 'stars': 5},
        ],
      });
      expect(evidence.weeklyActivity.single.count, 3);
      expect(evidence.repoRoles.single.role, 'owner');
    });
  });
}
