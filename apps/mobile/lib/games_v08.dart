import 'dart:math';
import 'package:flutter/material.dart';

enum V08GameMode { soloBot, localMulti }

class GameVoicePlayerV08 {
  const GameVoicePlayerV08({
    required this.name,
    required this.avatar,
    this.userId = '',
    this.micOn = true,
    this.isBot = false,
  });

  final String name;
  final String avatar;
  final String userId;
  final bool micOn;
  final bool isBot;
}

List<GameVoicePlayerV08> _gamePlayersV08(
  List<GameVoicePlayerV08> source,
  bool botMode,
) {
  final result = <GameVoicePlayerV08>[];
  if (botMode) {
    result.add(
      source.isNotEmpty
          ? source.first
          : const GameVoicePlayerV08(
              name: 'You',
              avatar: '🙂',
              userId: '10000050',
            ),
    );
    for (var i = 1; i < 4; i++) {
      result.add(
        GameVoicePlayerV08(
          name: 'Bot $i',
          avatar: '🤖',
          userId: 'BOT$i',
          micOn: false,
          isBot: true,
        ),
      );
    }
    return result;
  }

  result.addAll(source.take(4));
  while (result.length < 4) {
    final seat = result.length + 1;
    result.add(
      GameVoicePlayerV08(
        name: 'Player $seat',
        avatar: '👤',
        userId: 'LOCAL$seat',
      ),
    );
  }
  return result;
}

class _VoiceGameSeatV08 extends StatelessWidget {
  const _VoiceGameSeatV08({
    required this.player,
    required this.active,
    required this.seat,
    required this.keyPrefix,
  });

  final GameVoicePlayerV08 player;
  final bool active;
  final int seat;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    const seatColors = [
      Colors.redAccent,
      Colors.greenAccent,
      Colors.blueAccent,
      Colors.amberAccent,
    ];
    final color = seatColors[seat];
    return AnimatedContainer(
      key: Key('$keyPrefix-seat-${seat + 1}-v08'),
      duration: const Duration(milliseconds: 220),
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xDD151225),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? color : Colors.white24,
          width: active ? 2.5 : 1,
        ),
        boxShadow: [
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
          if (active)
            BoxShadow(
              color: color.withOpacity(.45),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color.withOpacity(.95), color.withOpacity(.35)],
              ),
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: Center(
              child: Text(
                player.avatar,
                style: const TextStyle(fontSize: 19),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      player.micOn
                          ? Icons.mic_rounded
                          : Icons.mic_off_rounded,
                      size: 11,
                      color: player.micOn
                          ? Colors.greenAccent
                          : Colors.white38,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        player.isBot
                            ? 'BOT'
                            : (player.micOn ? 'VOICE' : 'MUTED'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 6.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FourSideVoiceGameStageV08 extends StatelessWidget {
  const FourSideVoiceGameStageV08({
    super.key,
    required this.players,
    required this.activeSeat,
    required this.center,
    required this.keyPrefix,
  });

  final List<GameVoicePlayerV08> players;
  final int activeSeat;
  final Widget center;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final boardSize = max(210.0, width - 82);
          final height = boardSize + 98;
          return SizedBox(
            key: Key('$keyPrefix-four-side-stage-v08'),
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: (width - boardSize) / 2,
                  top: 49,
                  width: boardSize,
                  height: boardSize,
                  child: center,
                ),
                Positioned(
                  top: 0,
                  left: (width - 92) / 2,
                  child: _VoiceGameSeatV08(
                    player: players[2],
                    active: activeSeat == 2,
                    seat: 2,
                    keyPrefix: keyPrefix,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: (height - 50) / 2,
                  child: _VoiceGameSeatV08(
                    player: players[1],
                    active: activeSeat == 1,
                    seat: 1,
                    keyPrefix: keyPrefix,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: (width - 92) / 2,
                  child: _VoiceGameSeatV08(
                    player: players[0],
                    active: activeSeat == 0,
                    seat: 0,
                    keyPrefix: keyPrefix,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: (height - 50) / 2,
                  child: _VoiceGameSeatV08(
                    player: players[3],
                    active: activeSeat == 3,
                    seat: 3,
                    keyPrefix: keyPrefix,
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _GameSceneV08 extends StatelessWidget {
  const _GameSceneV08({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF22103B), Color(0xFF0B1736), Color(0xFF071018)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: child,
  );
}



class GamesCenterV08 extends StatelessWidget {
  const GamesCenterV08({super.key, this.players = const []});
  final List<GameVoicePlayerV08> players;
  static const games = <(String, IconData)>[
    ('Ludo', Icons.casino_rounded),
    ('UNO', Icons.style_rounded),
    ('Carrom', Icons.adjust_rounded),
    ('Lucky Dice', Icons.casino_outlined),
    ('Lucky Wheel', Icons.track_changes_rounded),
    ('Rock Paper Scissors', Icons.back_hand_rounded),
    ('Teen Patti', Icons.style_rounded),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Game Center')),
    body: GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.15, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: games.length,
      itemBuilder: (context, i) {
        final g=games[i];
        return Card(child: InkWell(
          key: Key('game-'+g.$1.toLowerCase().replaceAll(' ','-')+'-v08'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameLauncherV08(game:g.$1, players: players))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
            Icon(g.$2,size:42), const SizedBox(height:10),
            Text(g.$1,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w900)),
          ]),
        ));
      },
    ),
  );
}

class GameLauncherV08 extends StatelessWidget {
  const GameLauncherV08({super.key, required this.game, this.players = const []});
  final String game;
  final List<GameVoicePlayerV08> players;

  bool get supportsFourSeatLocal =>
      game == 'Ludo' || game == 'UNO' || game == 'Carrom';

  void _open(BuildContext context, V08GameMode mode) {
    final Widget page = switch (game) {
      'Ludo' => LudoGameV08(mode: mode, players: players),
      'UNO' => UnoGameV08(mode: mode, players: players),
      'Carrom' => CarromGameV08(mode: mode, players: players),
      'Lucky Dice' => LuckyDiceGameV08(mode: mode),
      'Lucky Wheel' => LuckyWheelGameV08(mode: mode),
      'Rock Paper Scissors' => RpsGameV08(mode: mode),
      'Teen Patti' => TeenPattiGameV08(mode: mode),
      _ => LudoGameV08(mode: mode, players: players),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(game)),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              game + ' Play Mode',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _ModeCard(
              key: const Key('solo-bot-mode-v08'),
              icon: Icons.smart_toy_rounded,
              title: supportsFourSeatLocal ? 'Solo vs Bot' : 'Solo / Practice',
              subtitle: supportsFourSeatLocal
                  ? '4-seat table: aap + 3 bots.'
                  : 'Single-phone practice mode.',
              onTap: () => _open(context, V08GameMode.soloBot),
            ),
            if (supportsFourSeatLocal)
              _ModeCard(
                key: const Key('local-multi-mode-v08'),
                icon: Icons.groups_rounded,
                title: 'Local Multiplayer',
                subtitle: 'Same phone par 4 seats turn-by-turn khel sakti hain.',
                onTap: () => _open(context, V08GameMode.localMulti),
              ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.public_rounded),
                title: Text('Online Multiplayer'),
                subtitle: Text(
                  'Backend/database/real-time server connect hone ke baad enable hoga.',
                ),
                trailing: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
      );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

// ---------------- LUDO 4 PLAYER 3D ----------------

class LudoGameV08 extends StatefulWidget {
  const LudoGameV08({super.key, required this.mode, this.players = const []});
  final V08GameMode mode;
  final List<GameVoicePlayerV08> players;
  @override
  State<LudoGameV08> createState() => _LudoGameV08State();
}

class _LudoGameV08State extends State<LudoGameV08> {
  final rng = Random();
  late final List<GameVoicePlayerV08> gamePlayers;
  final tokens = List<List<int>>.generate(4, (_) => List<int>.filled(4, -1));
  int current = 0;
  int? dice;
  String status = 'Roll the dice';
  bool busy = false;
  int? winner;

  bool get botMode => widget.mode == V08GameMode.soloBot;
  bool get botTurn => botMode && current != 0;

  @override
  void initState() {
    super.initState();
    gamePlayers = _gamePlayersV08(widget.players, botMode);
  }

  String _name(int seat) {
    const colors = ['Red', 'Green', 'Blue', 'Yellow'];
    return gamePlayers[seat].name + ' / ' + colors[seat];
  }

  List<int> movable(int roll) {
    final result = <int>[];
    final list = tokens[current];
    for (var i = 0; i < 4; i++) {
      final p = list[i];
      if (p == -1 && roll == 6) result.add(i);
      if (p >= 0 && p < 56 && p + roll <= 56) result.add(i);
    }
    return result;
  }

  Future<void> rollDice() async {
    if (busy || dice != null || botTurn || winner != null) return;
    final value = rng.nextInt(6) + 1;
    setState(() {
      dice = value;
      status = _name(current) + ' rolled ' + value.toString();
    });
    if (movable(value).isEmpty) {
      await Future.delayed(const Duration(milliseconds: 400));
      _endTurn(extra: false);
    }
  }

  void moveToken(int index) {
    if (dice == null || busy || botTurn || winner != null) return;
    if (!movable(dice!).contains(index)) return;
    _applyMove(index, dice!);
  }

  void _applyMove(int index, int roll) {
    final seat = current;
    final list = tokens[seat];
    setState(() {
      list[index] = list[index] == -1 ? 0 : list[index] + roll;
      status = _name(seat) + ' moved token ' + (index + 1).toString();
      dice = null;
    });
    _captureIfNeeded(seat, index);
    if (list.every((p) => p == 56)) {
      setState(() {
        winner = seat;
        status = _name(seat) + ' wins! 🎉';
      });
      return;
    }
    _endTurn(extra: roll == 6);
  }

  void _captureIfNeeded(int seat, int index) {
    final position = tokens[seat][index];
    if (position <= 0 || position >= 52) return;
    const starts = [0, 13, 26, 39];
    const safe = <int>{0, 8, 13, 21, 26, 34, 39, 47};
    final global = (position + starts[seat]) % 52;
    if (safe.contains(global)) return;

    for (var other = 0; other < 4; other++) {
      if (other == seat) continue;
      for (var i = 0; i < 4; i++) {
        final p = tokens[other][i];
        if (p <= 0 || p >= 52) continue;
        final otherGlobal = (p + starts[other]) % 52;
        if (global == otherGlobal) {
          tokens[other][i] = -1;
          status += ' • captured ' + _name(other) + ' token';
        }
      }
    }
  }

  void _endTurn({required bool extra}) {
    if (winner != null) return;
    setState(() {
      dice = null;
      if (!extra) current = (current + 1) % 4;
      status = extra ? _name(current) + ' gets another turn' : _name(current) + ' turn';
    });
    if (botTurn) Future.delayed(const Duration(milliseconds: 550), _botMove);
  }

  Future<void> _botMove() async {
    if (!mounted || !botTurn || busy || winner != null) return;
    busy = true;
    await Future.delayed(const Duration(milliseconds: 350));
    final roll = rng.nextInt(6) + 1;
    if (!mounted) return;
    setState(() {
      dice = roll;
      status = _name(current) + ' rolled ' + roll.toString();
    });
    await Future.delayed(const Duration(milliseconds: 350));
    final moves = movable(roll);
    busy = false;
    if (moves.isEmpty) {
      _endTurn(extra: false);
      return;
    }
    var pick = moves.first;
    for (final i in moves) {
      final p = tokens[current][i];
      if (p + roll == 56 || (p == -1 && roll == 6)) {
        pick = i;
        break;
      }
    }
    _applyMove(pick, roll);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1022),
      appBar: AppBar(title: const Text('Ludo • 4 Player 3D')),
      body: _GameSceneV08(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                key: const Key('ludo-four-player-v08'),
                child: FourSideVoiceGameStageV08(
                  players: gamePlayers,
                  activeSeat: current,
                  keyPrefix: 'ludo',
                  center: _LudoBoardV08(tokens: tokens),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: Colors.white10,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        winner == null ? _name(current) : _name(winner!) + ' wins! 🎉',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(status, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      if (winner == null)
                        FilledButton.icon(
                          key: const Key('ludo-roll-v08'),
                          onPressed: dice == null && !botTurn ? rollDice : null,
                          icon: const Icon(Icons.casino_rounded),
                          label: Text(dice == null ? 'Roll Dice' : 'Dice: ' + dice.toString()),
                        ),
                    ],
                  ),
                ),
              ),
              if (winner == null)
                _LudoTokenPanelV08(
                  title: _name(current) + ' tokens',
                  values: tokens[current],
                  dice: dice,
                  enabled: !botTurn,
                  onTap: moveToken,
                ),
              if (!botMode && winner == null)
                Text(
                  'Phone ' + _name(current) + ' ko de do • 4-player local turn-by-turn.',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LudoTokenPanelV08 extends StatelessWidget {
  const _LudoTokenPanelV08({
    required this.title,
    required this.values,
    required this.dice,
    required this.enabled,
    required this.onTap,
  });
  final String title;
  final List<int> values;
  final int? dice;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < values.length; i++)
                    ActionChip(
                      onPressed: enabled && dice != null ? () => onTap(i) : null,
                      avatar: const Icon(Icons.circle, size: 14),
                      label: Text(
                        values[i] == -1
                            ? 'Yard'
                            : values[i] == 56
                                ? 'Home'
                                : 'T' + (i + 1).toString() + ': ' + values[i].toString(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _LudoBoardV08 extends StatelessWidget {
  const _LudoBoardV08({required this.tokens});
  final List<List<int>> tokens;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0012)
            ..rotateX(.055)
            ..rotateZ(-.008),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 16)),
                BoxShadow(color: Color(0x664A90E2), blurRadius: 18, spreadRadius: 2),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                key: const Key('ludo-board-v08'),
                painter: _LudoBoardPainterV08(tokens: tokens),
              ),
            ),
          ),
        ),
      );
}

class _LudoBoardPainterV08 extends CustomPainter {
  _LudoBoardPainterV08({required this.tokens});
  final List<List<int>> tokens;

  static const path = <Offset>[
    Offset(6,1),Offset(6,2),Offset(6,3),Offset(6,4),Offset(6,5),
    Offset(5,6),Offset(4,6),Offset(3,6),Offset(2,6),Offset(1,6),Offset(0,6),
    Offset(0,7),Offset(0,8),Offset(1,8),Offset(2,8),Offset(3,8),Offset(4,8),
    Offset(5,8),Offset(6,9),Offset(6,10),Offset(6,11),Offset(6,12),Offset(6,13),
    Offset(6,14),Offset(7,14),Offset(8,14),Offset(8,13),Offset(8,12),Offset(8,11),
    Offset(8,10),Offset(8,9),Offset(9,8),Offset(10,8),Offset(11,8),Offset(12,8),
    Offset(13,8),Offset(14,8),Offset(14,7),Offset(14,6),Offset(13,6),Offset(12,6),
    Offset(11,6),Offset(10,6),Offset(9,6),Offset(8,5),Offset(8,4),Offset(8,3),
    Offset(8,2),Offset(8,1),Offset(8,0),Offset(7,0),Offset(6,0)
  ];

  Offset _track(int relative, int seat, double cell) {
    const starts = [0, 13, 26, 39];
    final p = path[(relative + starts[seat]) % 52];
    return Offset((p.dx + .5) * cell, (p.dy + .5) * cell);
  }

  Offset _homeLane(int progress, int seat, double cell) {
    final lane = (progress - 51).clamp(1, 5);
    if (seat == 0) return Offset(7.5 * cell, (lane + .5) * cell);
    if (seat == 1) return Offset((14 - lane + .5) * cell, 7.5 * cell);
    if (seat == 2) return Offset(7.5 * cell, (14 - lane + .5) * cell);
    return Offset((lane + .5) * cell, 7.5 * cell);
  }

  Offset _yard(int seat, int token, double cell) {
    const bases = [Offset(1.5,1.5), Offset(10.5,1.5), Offset(10.5,10.5), Offset(1.5,10.5)];
    final b = bases[seat];
    return Offset((b.dx + (token % 2) * 2) * cell, (b.dy + (token ~/ 2) * 2) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    final white = Paint()..color = const Color(0xFFF8F5F0);
    final grid = Paint()..color = const Color(0xFF48414E)..style = PaintingStyle.stroke..strokeWidth = .7;
    final colors = [
      const Color(0xFFE53935),
      const Color(0xFF43A047),
      const Color(0xFF1E88E5),
      const Color(0xFFFBC02D),
    ];

    canvas.drawRect(Offset.zero & size, white);
    canvas.drawRect(Rect.fromLTWH(0,0,cell*6,cell*6), Paint()..color=colors[0]);
    canvas.drawRect(Rect.fromLTWH(cell*9,0,cell*6,cell*6), Paint()..color=colors[1]);
    canvas.drawRect(Rect.fromLTWH(cell*9,cell*9,cell*6,cell*6), Paint()..color=colors[2]);
    canvas.drawRect(Rect.fromLTWH(0,cell*9,cell*6,cell*6), Paint()..color=colors[3]);

    for (var row=0; row<15; row++) {
      for (var col=0; col<15; col++) {
        if ((col>=6 && col<=8) || (row>=6 && row<=8)) {
          final rect=Rect.fromLTWH(col*cell,row*cell,cell,cell);
          canvas.drawRect(rect,white);
          canvas.drawRect(rect,grid);
        }
      }
    }

    for (var i=1;i<=5;i++) {
      canvas.drawRect(Rect.fromLTWH(7*cell,i*cell,cell,cell), Paint()..color=colors[0]);
      canvas.drawRect(Rect.fromLTWH((14-i)*cell,7*cell,cell,cell), Paint()..color=colors[1]);
      canvas.drawRect(Rect.fromLTWH(7*cell,(14-i)*cell,cell,cell), Paint()..color=colors[2]);
      canvas.drawRect(Rect.fromLTWH(i*cell,7*cell,cell,cell), Paint()..color=colors[3]);
    }

    final center=Offset(7.5*cell,7.5*cell);
    for (var seat=0; seat<4; seat++) {
      final angle = seat * pi / 2;
      final p=Path()
        ..moveTo(center.dx,center.dy)
        ..lineTo(center.dx + cos(angle-.78)*cell*2.1, center.dy + sin(angle-.78)*cell*2.1)
        ..lineTo(center.dx + cos(angle+.78)*cell*2.1, center.dy + sin(angle+.78)*cell*2.1)
        ..close();
      canvas.drawPath(p,Paint()..color=colors[seat]);
    }

    for (var seat=0; seat<4; seat++) {
      for (var i=0;i<4;i++) {
        final value=tokens[seat][i];
        final pos=value<0
            ? _yard(seat,i,cell)
            : value>=52
                ? _homeLane(value,seat,cell)
                : _track(value,seat,cell);
        final radius=cell*.30;
        canvas.drawCircle(pos+const Offset(1.5,2.5),radius,Paint()..color=Colors.black38);
        canvas.drawCircle(
          pos,
          radius,
          Paint()
            ..shader=RadialGradient(
              colors:[Colors.white.withOpacity(.7),colors[seat],Color.lerp(colors[seat],Colors.black,.3)!],
              stops:const [0,.4,1],
              center:const Alignment(-.35,-.35),
            ).createShader(Rect.fromCircle(center:pos,radius:radius)),
        );
        canvas.drawCircle(pos,radius,Paint()..color=Colors.white70..style=PaintingStyle.stroke..strokeWidth=1.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainterV08 oldDelegate) => true;
}

// ---------------- UNO 4 PLAYER ----------------

class _UnoCardData {
  const _UnoCardData(this.color, this.value);
  final String color;
  final String value;
  bool get wild => color == 'Wild';
  bool canPlayOn(_UnoCardData top, String activeColor) =>
      wild || color == activeColor || value == top.value;
  @override
  String toString() => color + ' ' + value;
}

class UnoGameV08 extends StatefulWidget {
  const UnoGameV08({super.key, required this.mode, this.players = const []});
  final V08GameMode mode;
  final List<GameVoicePlayerV08> players;
  @override
  State<UnoGameV08> createState() => _UnoGameV08State();
}

class _UnoGameV08State extends State<UnoGameV08> {
  final rng = Random();
  late final List<GameVoicePlayerV08> gamePlayers;
  final deck = <_UnoCardData>[];
  final discard = <_UnoCardData>[];
  final hands = List<List<_UnoCardData>>.generate(4, (_) => <_UnoCardData>[]);
  int turn = 0;
  int direction = 1;
  int? winner;
  String activeColor = 'Red';
  String status = 'Player 1 turn';

  bool get botMode => widget.mode == V08GameMode.soloBot;
  bool get currentIsBot => botMode && turn != 0;

  @override
  void initState() {
    super.initState();
    gamePlayers = _gamePlayersV08(widget.players, botMode);
    _newGame();
  }

  String _name(int seat) => gamePlayers[seat].name;

  int _next([int steps = 1]) {
    var value = turn;
    for (var i = 0; i < steps; i++) {
      value = (value + direction) % 4;
      if (value < 0) value += 4;
    }
    return value;
  }

  void _newGame() {
    deck.clear();
    discard.clear();
    for (final hand in hands) {
      hand.clear();
    }
    turn = 0;
    direction = 1;
    winner = null;
    status = botMode ? 'Your turn' : 'Player 1 turn';

    for (final color in ['Red', 'Blue', 'Green', 'Yellow']) {
      for (var n = 0; n <= 9; n++) {
        deck.add(_UnoCardData(color, n.toString()));
        if (n != 0) deck.add(_UnoCardData(color, n.toString()));
      }
      for (final action in ['Skip', 'Reverse', '+2']) {
        deck.add(_UnoCardData(color, action));
        deck.add(_UnoCardData(color, action));
      }
    }
    for (var i = 0; i < 4; i++) {
      deck.add(const _UnoCardData('Wild', 'Wild'));
      deck.add(const _UnoCardData('Wild', '+4'));
    }
    deck.shuffle(rng);
    for (final hand in hands) {
      hand.addAll(List.generate(7, (_) => deck.removeLast()));
    }
    discard.add(deck.removeLast());
    while (discard.last.wild) {
      deck.insert(0, discard.removeLast());
      discard.add(deck.removeLast());
    }
    activeColor = discard.last.color;
  }

  void _drawTo(List<_UnoCardData> hand, int count) {
    for (var i = 0; i < count; i++) {
      if (deck.isEmpty && discard.length > 1) {
        final top = discard.removeLast();
        deck
          ..addAll(discard)
          ..shuffle(rng);
        discard
          ..clear()
          ..add(top);
      }
      if (deck.isNotEmpty) hand.add(deck.removeLast());
    }
  }

  Color _colorFor(String color) {
    if (color == 'Red') return const Color(0xFFE63B52);
    if (color == 'Blue') return const Color(0xFF2D7EF7);
    if (color == 'Green') return const Color(0xFF22B573);
    if (color == 'Yellow') return const Color(0xFFFFBE2E);
    return const Color(0xFF7B4DFF);
  }

  Future<String> _chooseColor(int seat) async {
    if (botMode && seat != 0) {
      final counts = <String, int>{'Red': 0, 'Blue': 0, 'Green': 0, 'Yellow': 0};
      for (final card in hands[seat]) {
        if (counts.containsKey(card.color)) {
          counts[card.color] = counts[card.color]! + 1;
        }
      }
      return counts.entries.reduce((x, y) => x.value >= y.value ? x : y).key;
    }
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_name(seat) + ': choose color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in ['Red', 'Blue', 'Green', 'Yellow'])
              ActionChip(
                avatar: CircleAvatar(backgroundColor: _colorFor(color)),
                label: Text(color),
                onPressed: () => Navigator.pop(dialogContext, color),
              ),
          ],
        ),
      ),
    );
    return result ?? 'Red';
  }

  void _scheduleBot() {
    if (currentIsBot && winner == null) {
      Future.delayed(const Duration(milliseconds: 600), _botPlay);
    }
  }

  Future<void> playCard(int index) async {
    if (winner != null) return;
    final seat = turn;
    final hand = hands[seat];
    if (index < 0 || index >= hand.length) return;
    final card = hand[index];
    if (!card.canPlayOn(discard.last, activeColor)) {
      if (!currentIsBot) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ye card abhi play nahi ho sakta')),
        );
      }
      return;
    }

    setState(() {
      hand.removeAt(index);
      discard.add(card);
      if (!card.wild) activeColor = card.color;
      status = _name(seat) + ' played ' + card.value;
    });

    if (card.wild) {
      final chosen = await _chooseColor(seat);
      if (!mounted) return;
      setState(() => activeColor = chosen);
    }

    if (hand.isEmpty) {
      setState(() {
        winner = seat;
        status = _name(seat) + ' wins! 🎉';
      });
      return;
    }

    var steps = 1;
    if (card.value == 'Reverse') {
      direction = -direction;
    } else if (card.value == 'Skip') {
      steps = 2;
    } else if (card.value == '+2' || card.value == '+4') {
      final victim = _next();
      _drawTo(hands[victim], card.value == '+4' ? 4 : 2);
      steps = 2;
    }

    setState(() {
      turn = _next(steps);
      status = _name(turn) + ' turn';
    });
    _scheduleBot();
  }

  void drawCard() {
    if (winner != null || currentIsBot) return;
    setState(() {
      _drawTo(hands[turn], 1);
      turn = _next();
      status = _name(turn) + ' turn';
    });
    _scheduleBot();
  }

  Future<void> _botPlay() async {
    if (!mounted || !currentIsBot || winner != null) return;
    final seat = turn;
    final hand = hands[seat];
    final playable = <int>[];
    for (var i = 0; i < hand.length; i++) {
      if (hand[i].canPlayOn(discard.last, activeColor)) playable.add(i);
    }
    if (playable.isEmpty) {
      setState(() {
        _drawTo(hand, 1);
        turn = _next();
        status = _name(seat) + ' drew • ' + _name(turn) + ' turn';
      });
      _scheduleBot();
      return;
    }
    await playCard(playable.first);
  }

  Widget _card3d(_UnoCardData card, {VoidCallback? onTap}) {
    final base = _colorFor(card.color);
    return GestureDetector(
      onTap: onTap,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..rotateX(-.07)
          ..rotateY(.045),
        child: Container(
          width: 70,
          height: 104,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [base.withOpacity(.96), base.withOpacity(.52)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white70, width: 2),
            boxShadow: [
              BoxShadow(color: base.withOpacity(.45), blurRadius: 13, offset: const Offset(0, 8)),
              const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 5)),
            ],
          ),
          child: Center(
            child: Container(
              width: 50,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: Text(
                  card.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final humanCanPlay = winner == null && !currentIsBot;
    return Scaffold(
      backgroundColor: const Color(0xFF090E1D),
      appBar: AppBar(title: const Text('UNO • 4 Player 3D')),
      body: _GameSceneV08(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                key: const Key('uno-four-player-v08'),
                child: FourSideVoiceGameStageV08(
                  players: gamePlayers,
                  activeSeat: turn,
                  keyPrefix: 'uno',
                  center: Container(
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: [Color(0xFF263B65), Color(0xFF11182D)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white24, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 22,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Direction: ' +
                              (direction == 1 ? '↻' : '↺') +
                              ' • Active: ' +
                              activeColor,
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _card3d(discard.last),
                            const SizedBox(width: 10),
                            Column(
                              children: [
                                Container(
                                  width: 58,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF32104F),
                                        Color(0xFF11182D),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white38,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 10,
                                        offset: Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      deck.length.toString(),
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                FilledButton(
                                  key: const Key('uno-draw-v08'),
                                  onPressed: humanCanPlay ? drawCard : null,
                                  child: const Text('Draw'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                winner != null ? _name(winner!) + ' won the match' : _name(turn) + ' hand',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(
                height: 122,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < hands[turn].length; i++)
                      _card3d(hands[turn][i], onTap: humanCanPlay ? () => playCard(i) : null),
                  ],
                ),
              ),
              if (!botMode && winner == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Phone ' + _name(turn) + ' ko de do • current player ki hand hi visible hai.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (winner != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    onPressed: () => setState(_newGame),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Play Again'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- CARROM 4 PLAYER 3D ----------------

class _CarromPiece {
  _CarromPiece({required this.p, required this.kind});
  Offset p;
  Offset v = Offset.zero;
  final int kind;
  bool pocketed = false;
}

class CarromGameV08 extends StatefulWidget {
  const CarromGameV08({super.key, required this.mode, this.players = const []});
  final V08GameMode mode;
  final List<GameVoicePlayerV08> players;
  @override
  State<CarromGameV08> createState() => _CarromGameV08State();
}

class _CarromGameV08State extends State<CarromGameV08>
    with SingleTickerProviderStateMixin {
  final pieces = <_CarromPiece>[];
  late final List<GameVoicePlayerV08> gamePlayers;
  final scores = List<int>.filled(4, 0);
  late final AnimationController ticker;
  int turn = 0;
  Offset? dragStart;
  Offset? dragNow;
  bool shotActive = false;
  bool botThinking = false;

  bool get botMode => widget.mode == V08GameMode.soloBot;
  bool get botTurn => botMode && turn != 0;
  _CarromPiece get striker => pieces.last;

  String _name(int seat) => gamePlayers[seat].name;

  Offset _home(int seat) {
    if (seat == 0) return const Offset(.50, .86);
    if (seat == 1) return const Offset(.86, .50);
    if (seat == 2) return const Offset(.50, .14);
    return const Offset(.14, .50);
  }

  @override
  void initState() {
    super.initState();
    gamePlayers = _gamePlayersV08(widget.players, botMode);
    _setup();
    ticker = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_physicsTick)
      ..repeat();
  }

  void _setup() {
    pieces.clear();
    final center = const Offset(.5, .5);
    final offsets = <Offset>[
      Offset.zero,
      const Offset(.055, 0), const Offset(-.055, 0),
      const Offset(0, .055), const Offset(0, -.055),
      const Offset(.042, .042), const Offset(-.042, .042),
      const Offset(.042, -.042), const Offset(-.042, -.042),
      const Offset(.082, 0), const Offset(-.082, 0),
      const Offset(0, .082), const Offset(0, -.082),
      const Offset(.07, .07), const Offset(-.07, .07),
      const Offset(.07, -.07), const Offset(-.07, -.07),
      const Offset(.11, 0), const Offset(-.11, 0),
    ];
    for (var i = 0; i < offsets.length; i++) {
      pieces.add(_CarromPiece(
        p: center + offsets[i],
        kind: i == 0 ? 2 : (i.isEven ? 0 : 1),
      ));
    }
    pieces.add(_CarromPiece(p: _home(0), kind: 3));
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void _physicsTick() {
    if (!mounted || !shotActive) return;
    var moving = false;
    for (final piece in pieces) {
      if (piece.pocketed) continue;
      if (piece.v.distance > .00018) {
        moving = true;
        piece.p += piece.v;
        piece.v *= .984;
        var dx = piece.p.dx;
        var dy = piece.p.dy;
        var vx = piece.v.dx;
        var vy = piece.v.dy;
        const minV = .055;
        const maxV = .945;
        if (dx < minV || dx > maxV) {
          dx = dx.clamp(minV, maxV);
          vx = -vx * .88;
        }
        if (dy < minV || dy > maxV) {
          dy = dy.clamp(minV, maxV);
          vy = -vy * .88;
        }
        piece
          ..p = Offset(dx, dy)
          ..v = Offset(vx, vy);
        for (final hole in const [
          Offset(.065, .065), Offset(.935, .065),
          Offset(.065, .935), Offset(.935, .935),
        ]) {
          if ((piece.p - hole).distance < .055) {
            _pocket(piece);
            break;
          }
        }
      }
    }

    for (var i = 0; i < pieces.length; i++) {
      final x = pieces[i];
      if (x.pocketed) continue;
      for (var j = i + 1; j < pieces.length; j++) {
        final y = pieces[j];
        if (y.pocketed) continue;
        final delta = y.p - x.p;
        final distance = delta.distance;
        if (distance > 0 && distance < .045) {
          final normal = delta / distance;
          final relative = (x.v - y.v).dx * normal.dx + (x.v - y.v).dy * normal.dy;
          if (relative > 0) {
            final impulse = normal * (relative * .94);
            x.v -= impulse;
            y.v += impulse;
          }
        }
      }
    }

    if (shotActive && !moving) {
      shotActive = false;
      _finishTurn();
    }
    setState(() {});
  }

  void _pocket(_CarromPiece piece) {
    if (piece.kind == 3) {
      piece
        ..p = _home(turn)
        ..v = Offset.zero;
      scores[turn] = max(0, scores[turn] - 1);
      return;
    }
    piece
      ..pocketed = true
      ..v = Offset.zero;
    scores[turn] += piece.kind == 2 ? 3 : 1;
  }

  void _finishTurn() {
    if (pieces.where((p) => p.kind != 3 && !p.pocketed).isEmpty) return;
    turn = (turn + 1) % 4;
    striker
      ..pocketed = false
      ..v = Offset.zero
      ..p = _home(turn);
    setState(() {});
    if (botTurn) Future.delayed(const Duration(milliseconds: 650), _botShot);
  }

  void _botShot() {
    if (!mounted || !botTurn || shotActive || botThinking) return;
    botThinking = true;
    final targets = pieces.where((p) => p.kind != 3 && !p.pocketed).toList();
    if (targets.isEmpty) {
      botThinking = false;
      return;
    }
    targets.sort((x, y) =>
        (x.p - striker.p).distance.compareTo((y.p - striker.p).distance));
    final direction = targets.first.p - striker.p;
    final length = max(.001, direction.distance);
    striker.v = direction / length * .019;
    shotActive = true;
    botThinking = false;
    setState(() {});
  }

  void _shoot(Size size, Offset start, Offset end) {
    if (shotActive || botTurn) return;
    final pull = start - end;
    final velocity = Offset(pull.dx / size.width, pull.dy / size.height);
    if (velocity.distance < .01) return;
    final power = min(.032, velocity.distance * .095);
    striker.v = velocity / velocity.distance * power;
    shotActive = true;
    setState(() {});
  }

  int? get winner {
    if (pieces.any((p) => p.kind != 3 && !p.pocketed)) return null;
    var best = 0;
    for (var i = 1; i < 4; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final left = pieces.where((p) => p.kind != 3 && !p.pocketed).length;
    return Scaffold(
      backgroundColor: const Color(0xFF07131A),
      appBar: AppBar(title: const Text('Carrom • 4 Player 3D')),
      body: _GameSceneV08(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  winner != null
                      ? _name(winner!) + ' wins 🎉'
                      : _name(turn) +
                          ' turn • ' +
                          left.toString() +
                          ' coins left',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Container(
                    key: const Key('carrom-four-player-v08'),
                    child: FourSideVoiceGameStageV08(
                      players: gamePlayers,
                      activeSeat: turn,
                      keyPrefix: 'carrom',
                      center: LayoutBuilder(
                        builder: (context, box) {
                          final size = Size(box.maxWidth, box.maxHeight);
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .0014)
                              ..rotateX(.065)
                              ..rotateZ(turn.isEven ? -.008 : .008),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black87,
                                    blurRadius: 26,
                                    offset: Offset(0, 18),
                                  ),
                                  BoxShadow(
                                    color: Color(0x5539FFCE),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: GestureDetector(
                                  key: const Key('carrom-board-v08'),
                                  onPanStart:
                                      shotActive || botTurn || winner != null
                                          ? null
                                          : (d) => setState(() {
                                                dragStart = d.localPosition;
                                                dragNow = d.localPosition;
                                              }),
                                  onPanUpdate:
                                      shotActive || botTurn || winner != null
                                          ? null
                                          : (d) => setState(
                                                () => dragNow = d.localPosition,
                                              ),
                                  onPanEnd:
                                      shotActive || botTurn || winner != null
                                          ? null
                                          : (_) {
                                                final start = dragStart;
                                                final end = dragNow;
                                                dragStart = null;
                                                dragNow = null;
                                                if (start != null &&
                                                    end != null) {
                                                  _shoot(size, start, end);
                                                }
                                              },
                                  child: CustomPaint(
                                    painter: _Carrom3DPainterV08(
                                      pieces: pieces,
                                      dragStart: dragStart,
                                      dragNow: dragNow,
                                      activeSeat: turn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 14),
                child: Text(
                  'Drag striker opposite direction me release karo • Queen = 3 points • 4 seats turn-by-turn.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Carrom3DPainterV08 extends CustomPainter {
  _Carrom3DPainterV08({
    required this.pieces,
    required this.dragStart,
    required this.dragNow,
    required this.activeSeat,
  });
  final List<_CarromPiece> pieces;
  final Offset? dragStart;
  final Offset? dragNow;
  final int activeSeat;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(24)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF5B2D18), Color(0xFFB97432), Color(0xFF3A1E13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(outer),
    );

    final board = Rect.fromLTWH(size.width * .055, size.height * .055, size.width * .89, size.height * .89);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(16)),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFE6B3), Color(0xFFF1C67E), Color(0xFFD99B54)],
          radius: .9,
        ).createShader(board),
    );

    final center = Offset(size.width / 2, size.height / 2);
    final line = Paint()
      ..color = const Color(0xFF7A351F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, size.width * .125, line);
    canvas.drawCircle(center, size.width * .045, Paint()..color = const Color(0x99C43D3D));

    void base(Offset x, Offset y, int seat) {
      final colors = [Colors.cyan, Colors.pinkAccent, Colors.amber, Colors.greenAccent];
      canvas.drawLine(
        x,
        y,
        Paint()
          ..color = seat == activeSeat ? colors[seat] : const Color(0xFF7A351F)
          ..strokeWidth = seat == activeSeat ? 4 : 2,
      );
    }

    base(Offset(size.width*.2,size.height*.86), Offset(size.width*.8,size.height*.86),0);
    base(Offset(size.width*.86,size.height*.2), Offset(size.width*.86,size.height*.8),1);
    base(Offset(size.width*.2,size.height*.14), Offset(size.width*.8,size.height*.14),2);
    base(Offset(size.width*.14,size.height*.2), Offset(size.width*.14,size.height*.8),3);

    for (final hole in const [
      Offset(.065,.065), Offset(.935,.065), Offset(.065,.935), Offset(.935,.935),
    ]) {
      final p = Offset(hole.dx * size.width, hole.dy * size.height);
      canvas.drawCircle(p + const Offset(2, 4), size.width*.048, Paint()..color=Colors.black54);
      canvas.drawCircle(p, size.width*.044, Paint()..color=Colors.black87);
    }

    for (final piece in pieces) {
      if (piece.pocketed) continue;
      final pos = Offset(piece.p.dx * size.width, piece.p.dy * size.height);
      final radius = size.width * (piece.kind == 3 ? .033 : .024);
      final baseColor = piece.kind == 0
          ? const Color(0xFFF9F2DF)
          : piece.kind == 1
              ? const Color(0xFF171717)
              : piece.kind == 2
                  ? const Color(0xFFD92F3D)
                  : const Color(0xFF7E57C2);
      canvas.drawCircle(pos + Offset(1.5, radius*.35), radius*1.05, Paint()..color=Colors.black38);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withOpacity(.75), baseColor, Color.lerp(baseColor, Colors.black, .35)!],
            stops: const [0, .38, 1],
            center: const Alignment(-.35,-.35),
          ).createShader(Rect.fromCircle(center: pos, radius: radius)),
      );
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color=Colors.black45..style=PaintingStyle.stroke..strokeWidth=1.2,
      );
    }

    if (dragStart != null && dragNow != null) {
      canvas.drawLine(
        dragStart!,
        dragNow!,
        Paint()..color=Colors.cyanAccent..strokeWidth=4..strokeCap=StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Carrom3DPainterV08 oldDelegate) => true;
}

class LuckyDiceGameV08 extends StatefulWidget {
  const LuckyDiceGameV08({super.key, required this.mode});
  final V08GameMode mode;
  @override
  State<LuckyDiceGameV08> createState() => _LuckyDiceGameV08State();
}

class _LuckyDiceGameV08State extends State<LuckyDiceGameV08> {
  final r = Random();
  int you = 0;
  int other = 0;
  int round = 0;
  int dieA = 1;
  int dieB = 1;
  String status = 'Roll to start';

  void roll() {
    final a = r.nextInt(6) + 1;
    final b = r.nextInt(6) + 1;
    setState(() {
      dieA = a;
      dieB = b;
      round++;
      if (a > b) you++;
      if (b > a) other++;
      status = a == b ? 'Draw round' : (a > b ? 'You win round' : 'Opponent wins round');
    });
  }

  Widget _die(int value, Color color) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..rotateX(-.12)
          ..rotateY(.16),
        child: Container(
          width: 105,
          height: 105,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(.95), color.withOpacity(.46)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white60, width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(.4), blurRadius: 18, offset: const Offset(0, 12))],
          ),
          child: Center(
            child: Text(value.toString(), style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        appBar: AppBar(title: const Text('Lucky Dice 3D')),
        body: _GameSceneV08(
          child: Center(
            child: Card(
              color: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    Text('Score ' + you.toString() + ' - ' + other.toString() + ' • Round ' + round.toString()),
                    const SizedBox(height: 22),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _die(dieA, Colors.cyan),
                      const SizedBox(width: 20),
                      _die(dieB, Colors.pinkAccent),
                    ]),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('lucky-dice-roll-v08'),
                      onPressed: roll,
                      icon: const Icon(Icons.casino),
                      label: const Text('Roll Dice'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class LuckyWheelGameV08 extends StatefulWidget {
  const LuckyWheelGameV08({super.key, required this.mode});
  final V08GameMode mode;
  @override
  State<LuckyWheelGameV08> createState() => _LuckyWheelGameV08State();
}

class _LuckyWheelGameV08State extends State<LuckyWheelGameV08> {
  final r = Random();
  final prizes = ['10 points', '25 points', '50 points', '100 points', 'Bonus', 'Try Again'];
  String result = 'SPIN';
  double angle = 0;

  void spin() => setState(() {
        angle += 5.5 + r.nextDouble() * 5;
        result = prizes[r.nextInt(prizes.length)];
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        appBar: AppBar(title: const Text('Lucky Wheel 3D')),
        body: _GameSceneV08(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 550),
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0014)
                  ..rotateX(.12)
                  ..rotateZ(angle),
                transformAlignment: Alignment.center,
                width: 245,
                height: 245,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [Colors.pinkAccent, Colors.amber, Colors.greenAccent, Colors.cyan, Colors.purpleAccent, Colors.pinkAccent],
                  ),
                  border: Border.all(color: Colors.white70, width: 7),
                  boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 16))],
                ),
                child: Center(
                  child: Container(
                    width: 115,
                    height: 115,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xDD17132C)),
                    child: Center(
                      child: Text(result, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                key: const Key('lucky-wheel-spin-v08'),
                onPressed: spin,
                child: const Text('SPIN'),
              ),
            ]),
          ),
        ),
      );
}

class RpsGameV08 extends StatefulWidget {
  const RpsGameV08({super.key, required this.mode});
  final V08GameMode mode;
  @override
  State<RpsGameV08> createState() => _RpsGameV08State();
}

class _RpsGameV08State extends State<RpsGameV08> {
  final r = Random();
  final choices = ['Rock', 'Paper', 'Scissors'];
  String result = 'Choose your move';
  int wins = 0;
  int losses = 0;

  void play(String me) {
    final bot = choices[r.nextInt(3)];
    final win = (me == 'Rock' && bot == 'Scissors') ||
        (me == 'Paper' && bot == 'Rock') ||
        (me == 'Scissors' && bot == 'Paper');
    setState(() {
      if (me == bot) {
        result = 'Draw • ' + bot;
      } else if (win) {
        wins++;
        result = 'You win • opponent: ' + bot;
      } else {
        losses++;
        result = 'Opponent wins • ' + bot;
      }
    });
  }

  IconData _icon(String value) {
    if (value == 'Rock') return Icons.circle;
    if (value == 'Paper') return Icons.note_rounded;
    return Icons.content_cut_rounded;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        appBar: AppBar(title: const Text('Rock Paper Scissors 3D')),
        body: _GameSceneV08(
          child: Center(
            child: Card(
              color: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(result, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('Wins ' + wins.toString() + ' • Losses ' + losses.toString()),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < choices.length; i++)
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .0014)
                            ..rotateX(-.08)
                            ..rotateY((i - 1) * .07),
                          child: FilledButton.tonalIcon(
                            onPressed: () => play(choices[i]),
                            icon: Icon(_icon(choices[i]), size: 30),
                            label: Text(choices[i]),
                          ),
                        ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

class TeenPattiGameV08 extends StatefulWidget {
  const TeenPattiGameV08({super.key, required this.mode});
  final V08GameMode mode;
  @override
  State<TeenPattiGameV08> createState() => _TeenPattiGameV08State();
}

class _TeenPattiGameV08State extends State<TeenPattiGameV08> {
  final r = Random();
  List<int> hand = [];
  String rank = '';

  void deal() {
    final cards = <int>{};
    while (cards.length < 3) {
      cards.add(r.nextInt(52));
    }
    final h = cards.toList();
    final vals = h.map((x) => x % 13 + 2).toList()..sort();
    final suits = h.map((x) => x ~/ 13).toList();
    final same = vals.toSet().length == 1;
    final pair = vals.toSet().length == 2;
    final color = suits.toSet().length == 1;
    final seq = vals[2] - vals[1] == 1 && vals[1] - vals[0] == 1;
    setState(() {
      hand = h;
      rank = same
          ? 'Trail'
          : color && seq
              ? 'Pure Sequence'
              : seq
                  ? 'Sequence'
                  : color
                      ? 'Color'
                      : pair
                          ? 'Pair'
                          : 'High Card';
    });
  }

  String card(int x) =>
      ['♠', '♥', '♦', '♣'][x ~/ 13] + ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'][x % 13];

  Widget _card3d(int x, int i) {
    final text = card(x);
    final red = text.startsWith('♥') || text.startsWith('♦');
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0015)
        ..rotateX(-.10)
        ..rotateY((i - 1) * .10),
      child: Container(
        width: 84,
        height: 122,
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFE8E8F1)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 10))],
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: red ? Colors.red : Colors.black),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF071B17),
        appBar: AppBar(title: const Text('Teen Patti Practice 3D')),
        body: _GameSceneV08(
          child: Center(
            child: Card(
              color: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Practice only • no betting or cash rewards'),
                  const SizedBox(height: 18),
                  if (hand.isEmpty)
                    const Icon(Icons.style_rounded, size: 88)
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < hand.length; i++) _card3d(hand[i], i),
                    ]),
                  const SizedBox(height: 10),
                  Text(rank, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const Key('teen-patti-deal-v08'),
                    onPressed: deal,
                    child: const Text('Deal'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
