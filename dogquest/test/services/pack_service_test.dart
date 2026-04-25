import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dogquest/services/pack_service.dart';
import 'package:dogquest/models/pack.dart';

void main() {
  late Box box;
  late PackService service;

  setUp(() async {
    Hive.init('./test_hive_pack');
    box = await Hive.openBox(
        'test_pack_${DateTime.now().millisecondsSinceEpoch}');
    service = PackService(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  group('PackService', () {
    test('starts with no pack', () {
      expect(service.pack, isNull);
      expect(service.hasPack, isFalse);
    });

    test('createPack stores a pack', () {
      final pack = Pack(
        name: 'Test Pack',
        inviteCode: 'ABC123',
        createdAt: DateTime(2026, 3, 1),
        members: [
          PackMember(
              name: 'Alice', role: 'alpha', joinedAt: DateTime(2026, 3, 1)),
        ],
      );
      service.createPack(pack);
      expect(service.hasPack, isTrue);
      expect(service.pack!.name, 'Test Pack');
      expect(service.pack!.members.length, 1);
    });

    test('addMember appends to members list', () {
      service.createPack(Pack(
        name: 'My Pack',
        inviteCode: 'XYZ789',
        createdAt: DateTime.now(),
        members: [
          PackMember(name: 'Owner', role: 'alpha', joinedAt: DateTime.now())
        ],
      ));
      service.addMember(PackMember(name: 'Bob', joinedAt: DateTime.now()));
      expect(service.pack!.members.length, 2);
      expect(service.pack!.members[1].name, 'Bob');
    });

    test('addMember does nothing when no pack exists', () {
      service.addMember(PackMember(name: 'Bob', joinedAt: DateTime.now()));
      expect(service.hasPack, isFalse);
    });

    test('removeMember removes by name', () {
      service.createPack(Pack(
        name: 'Pack',
        inviteCode: 'AAA',
        createdAt: DateTime.now(),
        members: [
          PackMember(name: 'A', role: 'alpha', joinedAt: DateTime.now()),
          PackMember(name: 'B', joinedAt: DateTime.now()),
          PackMember(name: 'C', joinedAt: DateTime.now()),
        ],
      ));
      service.removeMember('B');
      expect(service.pack!.members.length, 2);
      expect(service.pack!.members.map((m) => m.name), isNot(contains('B')));
    });

    test('updateMember replaces member by original name', () {
      service.createPack(Pack(
        name: 'Pack',
        inviteCode: 'BBB',
        createdAt: DateTime.now(),
        members: [
          PackMember(name: 'Alice', role: 'alpha', joinedAt: DateTime.now()),
        ],
      ));
      service.updateMember(
        'Alice',
        PackMember(
            name: 'Alice',
            role: 'alpha',
            avatarEmoji: '\u{1F469}',
            joinedAt: DateTime.now()),
      );
      expect(service.pack!.members[0].avatarEmoji, '\u{1F469}');
    });

    test('deletePack removes all pack data', () {
      service.createPack(Pack(
        name: 'Pack',
        inviteCode: 'CCC',
        createdAt: DateTime.now(),
      ));
      expect(service.hasPack, isTrue);
      service.deletePack();
      expect(service.hasPack, isFalse);
    });

    test('recordWeeklyActivity accumulates within same week', () {
      service.createPack(Pack(
        name: 'Pack',
        inviteCode: 'DDD',
        createdAt: DateTime.now(),
      ));
      service.recordWeeklyActivity(breeds: 3, xp: 100);
      service.recordWeeklyActivity(breeds: 2, xp: 50);
      final p = service.pack!;
      expect(p.weeklyBreedsFound, 5);
      expect(p.weeklyXpEarned, 150);
    });
  });

  group('Pack model', () {
    test('totalDogs sums across members', () {
      final pack = Pack(
        name: 'Test',
        inviteCode: 'X',
        createdAt: DateTime.now(),
        members: [
          PackMember(
              name: 'A', dogNames: ['Rex', 'Max'], joinedAt: DateTime.now()),
          PackMember(name: 'B', dogNames: ['Buddy'], joinedAt: DateTime.now()),
        ],
      );
      expect(pack.totalDogs, 3);
    });

    test('alpha returns alpha member', () {
      final pack = Pack(
        name: 'Test',
        inviteCode: 'X',
        createdAt: DateTime.now(),
        members: [
          PackMember(name: 'Normal', joinedAt: DateTime.now()),
          PackMember(name: 'Lead', role: 'alpha', joinedAt: DateTime.now()),
        ],
      );
      expect(pack.alpha!.name, 'Lead');
    });

    test('alpha returns first member when no alpha role', () {
      final pack = Pack(
        name: 'Test',
        inviteCode: 'X',
        createdAt: DateTime.now(),
        members: [
          PackMember(name: 'First', joinedAt: DateTime.now()),
          PackMember(name: 'Second', joinedAt: DateTime.now()),
        ],
      );
      expect(pack.alpha!.name, 'First');
    });

    test('alpha returns null for empty pack', () {
      final pack = Pack(
        name: 'Empty',
        inviteCode: 'X',
        createdAt: DateTime.now(),
      );
      expect(pack.alpha, isNull);
    });

    test('toJson/fromJson round-trip', () {
      final original = Pack(
        name: 'Round Trip',
        emoji: '\u{1F436}',
        inviteCode: 'RTT123',
        createdAt: DateTime(2026, 3, 1),
        weeklyBreedsFound: 5,
        weeklyXpEarned: 200,
        members: [
          PackMember(
              name: 'Alice', role: 'alpha', joinedAt: DateTime(2026, 3, 1)),
        ],
      );
      final restored = Pack.fromJson(original.toJson());
      expect(restored.name, 'Round Trip');
      expect(restored.inviteCode, 'RTT123');
      expect(restored.weeklyBreedsFound, 5);
      expect(restored.members.length, 1);
      expect(restored.members[0].name, 'Alice');
    });

    test('generateInviteCode produces 6-char codes', () {
      final code = Pack.generateInviteCode();
      expect(code.length, 6);
      // Should only contain allowed characters
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
    });
  });

  group('PackMember model', () {
    test('isAlpha returns true for alpha role', () {
      final m = PackMember(name: 'A', role: 'alpha', joinedAt: DateTime.now());
      expect(m.isAlpha, isTrue);
    });

    test('isAlpha returns false for member role', () {
      final m = PackMember(name: 'A', joinedAt: DateTime.now());
      expect(m.isAlpha, isFalse);
    });

    test('copyWith preserves joinedAt', () {
      final original =
          PackMember(name: 'A', role: 'member', joinedAt: DateTime(2026, 1, 1));
      final updated = original.copyWith(name: 'B');
      expect(updated.name, 'B');
      expect(updated.joinedAt, DateTime(2026, 1, 1));
    });
  });
}
