import 'animated_emoji.dart';

enum SeatEmoteGroup { panda, enemy }
enum EnemyPersona { male, female, clash }

class SeatEmoteDefinition {
  const SeatEmoteDefinition({
    required this.id, required this.name, required this.glyph,
    required this.group, required this.effect, this.enemyScene = '',
    this.expression = '', this.enemyPersona,
  });
  final String id, name, glyph, enemyScene, expression;
  final SeatEmoteGroup group;
  final EmojiEffect effect;
  final EnemyPersona? enemyPersona;
}

const pandaSeatEmotes = <SeatEmoteDefinition>[
  SeatEmoteDefinition(id: 'panda-01', name: 'Panda Happy', glyph: '😀',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.laugh, expression: 'happy'),
  SeatEmoteDefinition(id: 'panda-02', name: 'Panda Laugh', glyph: '😂',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.laugh, expression: 'laugh'),
  SeatEmoteDefinition(id: 'panda-03', name: 'Panda Love', glyph: '❤️',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.love, expression: 'love'),
  SeatEmoteDefinition(id: 'panda-04', name: 'Panda Kiss', glyph: '💋',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.love, expression: 'kiss'),
  SeatEmoteDefinition(id: 'panda-05', name: 'Panda Sad', glyph: '😢',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.tears, expression: 'sad'),
  SeatEmoteDefinition(id: 'panda-06', name: 'Panda Angry', glyph: '💢',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.anger, expression: 'angry'),
  SeatEmoteDefinition(id: 'panda-07', name: 'Panda Sleepy', glyph: '💤',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.sleepy, expression: 'sleepy'),
  SeatEmoteDefinition(id: 'panda-08', name: 'Panda Party', glyph: '🥳',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.party, expression: 'party'),
  SeatEmoteDefinition(id: 'panda-09', name: 'Panda Dance', glyph: '🎵',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.dance, expression: 'dance'),
  SeatEmoteDefinition(id: 'panda-10', name: 'Panda Wink', glyph: '😉',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.wave, expression: 'wink'),
  SeatEmoteDefinition(id: 'panda-11', name: 'Panda Shy', glyph: '🌸',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.love, expression: 'shy'),
  SeatEmoteDefinition(id: 'panda-12', name: 'Panda Cool', glyph: '😎',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.sparkle, expression: 'cool'),
  SeatEmoteDefinition(id: 'panda-13', name: 'Panda Wave', glyph: '👋',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.wave, expression: 'wave'),
  SeatEmoteDefinition(id: 'panda-14', name: 'Panda Clap', glyph: '👏',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.wave, expression: 'clap'),
  SeatEmoteDefinition(id: 'panda-15', name: 'Panda Hug', glyph: '🫶',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.love, expression: 'hug'),
  SeatEmoteDefinition(id: 'panda-16', name: 'Panda Surprise', glyph: '❗',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.surprise, expression: 'surprise'),
  SeatEmoteDefinition(id: 'panda-17', name: 'Panda Think', glyph: '❓',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.surprise, expression: 'think'),
  SeatEmoteDefinition(id: 'panda-18', name: 'Panda Salute', glyph: '🫡',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.wave, expression: 'salute'),
  SeatEmoteDefinition(id: 'panda-19', name: 'Panda Victory', glyph: '✌️',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.party, expression: 'victory'),
  SeatEmoteDefinition(id: 'panda-20', name: 'Panda Heartbreak', glyph: '💔',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.tears, expression: 'heartbreak'),
  SeatEmoteDefinition(id: 'panda-21', name: 'Panda Fire', glyph: '🔥',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.fire, expression: 'fire'),
  SeatEmoteDefinition(id: 'panda-22', name: 'Panda Thunder', glyph: '⚡',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.fire, expression: 'thunder'),
  SeatEmoteDefinition(id: 'panda-23', name: 'Panda Royal', glyph: '👑',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.sparkle, expression: 'royal'),
  SeatEmoteDefinition(id: 'panda-24', name: 'Panda Rose', glyph: '🌹',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.love, expression: 'rose'),
  SeatEmoteDefinition(id: 'panda-25', name: 'Panda Confetti', glyph: '🎊',
    group: SeatEmoteGroup.panda, effect: EmojiEffect.party, expression: 'confetti'),
];

const enemySeatEmotes = <SeatEmoteDefinition>[
  SeatEmoteDefinition(id: 'enemy-01', name: 'Male Skull', glyph: '💀',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.sleepy, enemyScene: 'smoke', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-02', name: 'Female Demon', glyph: '👿',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.fire, enemyScene: 'fire', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-03', name: 'Male Ghost', glyph: '👻',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.sleepy, enemyScene: 'smoke', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-04', name: 'Female Rage', glyph: '😈',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.anger, enemyScene: 'impact', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-05', name: 'Male Dragon', glyph: '🐉',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.fire, enemyScene: 'fire', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-06', name: 'Female Venom', glyph: '🐍',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.sleepy, enemyScene: 'smoke', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-07', name: 'Male Scorpion', glyph: '🦂',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.sleepy, enemyScene: 'smoke', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-08', name: 'Female Dagger', glyph: '🗡️',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.anger, enemyScene: 'impact', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-09', name: 'Male Swords', glyph: '⚔️',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.anger, enemyScene: 'clash', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-10', name: 'Female Hammer', glyph: '🔨',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.anger, enemyScene: 'impact', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-11', name: 'Male Axe', glyph: '🪓',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.anger, enemyScene: 'clash', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-12', name: 'Female Hellfire', glyph: '🔥',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.fire, enemyScene: 'fire', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-13', name: 'Male Thunder', glyph: '⚡',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.fire, enemyScene: 'lightning', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-14', name: 'Female Bomb', glyph: '💣',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.anger, enemyScene: 'impact', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-15', name: 'Male Poison', glyph: '🧪',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.sleepy, enemyScene: 'smoke', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-16', name: 'Female Chains', glyph: '⛓️',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.surprise, enemyScene: 'cracks', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-17', name: 'Male Broken Crown', glyph: '👑',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.surprise, enemyScene: 'cracks', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-18', name: 'Female Dark Wolf', glyph: '🐺',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.sleepy, enemyScene: 'smoke', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-19', name: 'Male Panther', glyph: '🐈‍⬛',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.sleepy, enemyScene: 'smoke', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-20', name: 'Female Bat', glyph: '🦇',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.sleepy, enemyScene: 'smoke', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-21', name: 'Male Demon Mask', glyph: '👹',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.fire, enemyScene: 'fire', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-22', name: 'Female Warrior', glyph: '🥷',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.anger, enemyScene: 'clash', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-23', name: 'Male Rival Clash', glyph: '⚔️',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.fire, enemyScene: 'lightning', enemyPersona: EnemyPersona.male),
  SeatEmoteDefinition(id: 'enemy-24', name: 'Female Dark Throne', glyph: '🪑',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.surprise, enemyScene: 'cracks', enemyPersona: EnemyPersona.female),
  SeatEmoteDefinition(id: 'enemy-25', name: 'Male & Female Apocalypse', glyph: '☄️',
    group: SeatEmoteGroup.enemy, effect: EmojiEffect.surprise, enemyScene: 'apocalypse', enemyPersona: EnemyPersona.clash),
];

SeatEmoteDefinition? seatEmoteFor(String id) {
  for (final definition in [...pandaSeatEmotes, ...enemySeatEmotes]) {
    if (definition.id == id) return definition;
  }
  return null;
}
