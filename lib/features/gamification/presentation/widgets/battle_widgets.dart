import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../workout/domain/exercise_taxonomy.dart';
import '../../domain/battle.dart';
import '../../domain/monsters.dart';

/// Portre görünümü (O2 cila spec §2).
enum MonsterLook { normal, defeated, fogged, lowHp }

/// Aşama halkası ve yer tutucu renkleri: bronz, gümüş, mor, altın (O2 cila spec §4).
const _tierColors = [Color(0xFFCD7F32), Color(0xFFC0C7D0), Color(0xFF9C4DFF), Color(0xFFFFC83D)];
const _tierIcons = [Icons.pest_control, Icons.pets, Icons.bolt, Icons.local_fire_department];
const _stampRed = Color(0xFFE53935);

const _grayscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Canavarın daire portresi: kadraj, vinyet, aşama halkası ve [look]'a göre katman;
/// görsel yoksa aşama renginde simge ve adının baş harfi.
class MonsterAvatar extends StatefulWidget {
  const MonsterAvatar({
    super.key,
    required this.index,
    this.size = 64,
    this.look = MonsterLook.normal,
    this.stampScale = 1,
  });

  final int index;
  final double size;
  final MonsterLook look;

  /// Yenilme anında mührün "vurulma" ölçeği.
  final double stampScale;

  @override
  State<MonsterAvatar> createState() => _MonsterAvatarState();
}

class _MonsterAvatarState extends State<MonsterAvatar> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(MonsterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final on = widget.look == MonsterLook.lowHp && !MediaQuery.disableAnimationsOf(context);
    if (on && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!on && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final look = widget.look;
    final monster = monsterAt(widget.index);
    final tier = monsterTier(widget.index);
    final tierColor = _tierColors[tier - 1];
    final ring = switch (look) {
      MonsterLook.defeated => Colors.grey,
      MonsterLook.lowHp => Theme.of(context).colorScheme.error,
      _ => tierColor,
    };
    final name = monster.nameKey.tr();
    final framed = size * monster.zoom;

    Widget portrait = OverflowBox(
      minWidth: framed,
      maxWidth: framed,
      minHeight: framed,
      maxHeight: framed,
      alignment: Alignment(monster.focus.$1, monster.focus.$2),
      child: Image.asset(
        monster.imageAsset,
        width: framed,
        height: framed,
        fit: BoxFit.cover,
        cacheWidth: (framed * MediaQuery.devicePixelRatioOf(context)).ceil(),
        errorBuilder: (context, error, stackTrace) => Stack(
          alignment: Alignment.center,
          children: [
            Icon(_tierIcons[tier - 1], size: size * 0.5, color: tierColor),
            Positioned(
              right: size * 0.12,
              bottom: size * 0.08,
              child: Text(
                name.isEmpty ? '' : name.characters.first,
                style: TextStyle(fontSize: size * 0.2, fontWeight: FontWeight.w900, color: tierColor),
              ),
            ),
          ],
        ),
      ),
    );
    if (look == MonsterLook.defeated) {
      portrait = Opacity(opacity: 0.6, child: ColorFiltered(colorFilter: _grayscale, child: portrait));
    } else if (look == MonsterLook.fogged) {
      portrait = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: size * 0.08, sigmaY: size * 0.08),
        child: portrait,
      );
    }

    final avatar = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = switch (look) {
          MonsterLook.defeated => 0.0,
          MonsterLook.lowHp => size * 0.2 * _pulse.value,
          _ => size * 0.12,
        };
        return Container(
          key: Key('monster_avatar_${monster.id}'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tierColor.withValues(alpha: 0.18),
            border: Border.all(color: ring, width: math.max(2, size * 0.04)),
            boxShadow: [if (glow > 0) BoxShadow(color: ring.withValues(alpha: 0.6), blurRadius: glow)],
          ),
          child: child,
        );
      },
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            portrait,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [Colors.transparent, Color(0xB3000000)], stops: [0.6, 1.0]),
              ),
            ),
            if (look == MonsterLook.fogged) ...[
              const ColoredBox(key: Key('monster_fog'), color: Color(0x8C000000)),
              Center(
                child: Text('?', style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w900, color: tierColor)),
              ),
            ],
            if (look == MonsterLook.defeated)
              Center(
                key: const Key('monster_stamp'),
                child: Transform.scale(
                  scale: widget.stampScale,
                  child: Transform.rotate(
                    angle: -20 * math.pi / 180,
                    child: size < 56
                        ? Icon(Icons.close, color: _stampRed, size: size * 0.6)
                        : Container(
                            width: size * 0.9,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: _stampRed, width: 2),
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                            ),
                            child: FittedBox(
                              child: Text(
                                'gamification.battle.stamp'.tr(),
                                style: const TextStyle(color: _stampRed, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return look == MonsterLook.lowHp ? KeyedSubtree(key: const Key('monster_pulse'), child: avatar) : avatar;
  }
}

/// Aktif canavar: canı %30'un altındaysa nabız (O2 cila spec §5).
MonsterLook activeLook(BattleState battle) =>
    battle.hpLeft / battle.hp < 0.3 ? MonsterLook.lowHp : MonsterLook.normal;

/// Canavar yolunda ad: yenilenler, aktif ve sıradaki açık; ötesi "???".
bool pathNameVisible(int i, int active) => i <= active + 1;

/// Kalan can çubuğu ve "kalan / tam".
class BattleHpBar extends StatelessWidget {
  const BattleHpBar({super.key, required this.battle, this.value});

  final BattleState battle;

  /// Animasyonda gösterilen can oranı; null → güncel.
  final double? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              key: const Key('battle_hp_bar'),
              value: value ?? battle.hpLeft / battle.hp,
              minHeight: 8,
              color: theme.colorScheme.error,
              backgroundColor: theme.colorScheme.error.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${battle.hpLeft} / ${battle.hp}', style: theme.textTheme.labelMedium),
      ],
    );
  }
}

/// Canavarın iki zayıf kası.
class WeakMuscleChips extends StatelessWidget {
  const WeakMuscleChips({super.key, required this.monster});

  final Monster monster;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final muscle in monster.weakMuscles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Text(muscleLabelKey(muscle).tr(), style: TextStyle(fontSize: 12, color: scheme.tertiary)),
          ),
      ],
    );
  }
}

/// "5 Ekim".
String battleHitDay(DateTime d) => '${d.day} ${'home.month_${d.month}'.tr()}';

/// "%40 kritik".
String critText(double share) => 'gamification.battle.crit'.tr(namedArgs: {'n': '${(share * 100).round()}'});
