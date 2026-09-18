import 'dart:math';
import 'package:flutter/material.dart';

enum V07GameMode { soloBot, localMulti }

class GameLauncherV07 extends StatelessWidget {
  const GameLauncherV07({super.key, required this.game});
  final String game;

  void _open(BuildContext context, V07GameMode mode) {
    final Widget page = game == 'Ludo'
        ? LudoGameV07(mode: mode)
        : game == 'UNO'
            ? UnoGameV07(mode: mode)
            : CarromGameV07(mode: mode);
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
              key: const Key('solo-bot-mode-v07'),
              icon: Icons.smart_toy_rounded,
              title: 'Solo vs Bot',
              subtitle: 'Akele khelo, opponent bot hoga.',
              onTap: () => _open(context, V07GameMode.soloBot),
            ),
            _ModeCard(
              key: const Key('local-multi-mode-v07'),
              icon: Icons.groups_rounded,
              title: 'Local Multiplayer',
              subtitle: 'Same phone par 2 players turn-by-turn khel sakte hain.',
              onTap: () => _open(context, V07GameMode.localMulti),
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

// ---------------- LUDO ----------------

class LudoGameV07 extends StatefulWidget {
  const LudoGameV07({super.key, required this.mode});
  final V07GameMode mode;

  @override
  State<LudoGameV07> createState() => _LudoGameV07State();
}

class _LudoGameV07State extends State<LudoGameV07> {
  final rng = Random();
  final red = List<int>.filled(4, -1);
  final blue = List<int>.filled(4, -1);
  int current = 0;
  int? dice;
  String status = 'Roll the dice';
  bool busy = false;

  bool get botTurn => widget.mode == V07GameMode.soloBot && current == 1;
  String get currentName => current == 0
      ? 'You / Red'
      : (widget.mode == V07GameMode.soloBot ? 'Bot / Blue' : 'Player 2 / Blue');

  List<int> get tokens => current == 0 ? red : blue;

  List<int> movable(int roll) {
    final result = <int>[];
    for (var i = 0; i < 4; i++) {
      final p = tokens[i];
      if (p == -1 && roll == 6) result.add(i);
      if (p >= 0 && p < 56 && p + roll <= 56) result.add(i);
    }
    return result;
  }

  Future<void> rollDice() async {
    if (busy || dice != null || botTurn) return;
    final value = rng.nextInt(6) + 1;
    setState(() {
      dice = value;
      status = currentName + ' rolled ' + value.toString();
    });
    if (movable(value).isEmpty) {
      await Future.delayed(const Duration(milliseconds: 450));
      _endTurn(extra: false);
    }
  }

  void moveToken(int index) {
    if (dice == null || busy || botTurn) return;
    if (!movable(dice!).contains(index)) return;
    _applyMove(index, dice!);
  }

  void _applyMove(int index, int roll) {
    final list = current == 0 ? red : blue;
    setState(() {
      list[index] = list[index] == -1 ? 0 : list[index] + roll;
      status = currentName + ' moved token ' + (index + 1).toString();
      dice = null;
    });
    _captureIfNeeded(index);
    if (list.every((p) => p == 56)) {
      setState(() => status = currentName + ' wins! 🎉');
      return;
    }
    _endTurn(extra: roll == 6);
  }

  void _captureIfNeeded(int index) {
    final mine = current == 0 ? red[index] : blue[index];
    if (mine <= 0 || mine >= 52) return;
    final opponent = current == 0 ? blue : red;
    final mineTrack = current == 0 ? mine : (mine + 26) % 52;
    for (var i = 0; i < opponent.length; i++) {
      final p = opponent[i];
      if (p <= 0 || p >= 52) continue;
      final oppTrack = current == 0 ? (p + 26) % 52 : p;
      if (mineTrack == oppTrack &&
          !{0, 8, 13, 21, 26, 34, 39, 47}.contains(mineTrack)) {
        opponent[i] = -1;
        status += ' • captured opponent token!';
      }
    }
  }

  void _endTurn({required bool extra}) {
    if (red.every((p) => p == 56) || blue.every((p) => p == 56)) return;
    setState(() {
      dice = null;
      if (!extra) current = 1 - current;
      status = extra ? currentName + ' gets another turn' : currentName + ' turn';
    });
    if (botTurn) {
      Future.delayed(const Duration(milliseconds: 650), _botMove);
    }
  }

  Future<void> _botMove() async {
    if (!mounted || !botTurn || busy) return;
    busy = true;
    await Future.delayed(const Duration(milliseconds: 450));
    final roll = rng.nextInt(6) + 1;
    if (!mounted) return;
    setState(() {
      dice = roll;
      status = 'Bot rolled ' + roll.toString();
    });
    await Future.delayed(const Duration(milliseconds: 450));
    final moves = movable(roll);
    busy = false;
    if (moves.isEmpty) {
      _endTurn(extra: false);
      return;
    }
    var pick = moves.first;
    for (final i in moves) {
      if (blue[i] + roll == 56 || (blue[i] == -1 && roll == 6)) {
        pick = i;
        break;
      }
    }
    _applyMove(pick, roll);
  }

  @override
  Widget build(BuildContext context) {
    final winner = red.every((p) => p == 56)
        ? 'Red'
        : blue.every((p) => p == 56)
            ? 'Blue'
            : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Ludo')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _LudoBoard(red: red, blue: blue),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    winner == null ? currentName : winner + ' wins! 🎉',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(status, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  if (winner == null)
                    FilledButton.icon(
                      key: const Key('ludo-roll-v07'),
                      onPressed: dice == null && !botTurn ? rollDice : null,
                      icon: const Icon(Icons.casino_rounded),
                      label: Text(dice == null ? 'Roll Dice' : 'Dice: ' + dice.toString()),
                    ),
                ],
              ),
            ),
          ),
          _TokenPanel(
            title: 'Red tokens',
            values: red,
            active: current == 0,
            dice: dice,
            onTap: current == 0 ? moveToken : null,
          ),
          _TokenPanel(
            title: 'Blue tokens',
            values: blue,
            active: current == 1,
            dice: dice,
            onTap: current == 1 && !botTurn ? moveToken : null,
          ),
        ],
      ),
    );
  }
}

class _TokenPanel extends StatelessWidget {
  const _TokenPanel({
    required this.title,
    required this.values,
    required this.active,
    required this.dice,
    this.onTap,
  });
  final String title;
  final List<int> values;
  final bool active;
  final int? dice;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < 4; i++)
                    ActionChip(
                      onPressed: active && dice != null && onTap != null ? () => onTap!(i) : null,
                      avatar: const Icon(Icons.circle, size: 16),
                      label: Text(
                        values[i] == -1
                            ? 'T' + (i + 1).toString() + ': Yard'
                            : values[i] == 56
                                ? 'T' + (i + 1).toString() + ': Home'
                                : 'T' + (i + 1).toString() + ': ' + values[i].toString() + '/56',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _LudoBoard extends StatelessWidget {
  const _LudoBoard({required this.red, required this.blue});
  final List<int> red;
  final List<int> blue;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(key: const Key('ludo-board-v07'), painter: _LudoBoardPainter(red: red, blue: blue)),
      );
}

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter({required this.red, required this.blue});
  final List<int> red;
  final List<int> blue;

  static const safe = <int>{0, 8, 13, 21, 26, 34, 39, 47};

  Offset _trackPoint(int step, Size size, bool bluePlayer) {
    final n = bluePlayer ? (step + 26) % 52 : step % 52;
    final cell = size.width / 15;
    // 52-cell loop mapped around the standard 15x15 cross.
    const path = <Offset>[
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
    final p = path[n % 52];
    return Offset((p.dx + .5) * cell, (p.dy + .5) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    final grid = Paint()..color = const Color(0xFF4D4655)..style = PaintingStyle.stroke..strokeWidth = .7;
    final white = Paint()..color = const Color(0xFFF7F4F0);
    final redP = Paint()..color = const Color(0xFFE53935);
    final blueP = Paint()..color = const Color(0xFF1E88E5);
    final greenP = Paint()..color = const Color(0xFF43A047);
    final yellowP = Paint()..color = const Color(0xFFFDD835);
    canvas.drawRect(Offset.zero & size, white);

    // Four recognizable Ludo yards.
    canvas.drawRect(Rect.fromLTWH(0,0,cell*6,cell*6), redP);
    canvas.drawRect(Rect.fromLTWH(cell*9,0,cell*6,cell*6), greenP);
    canvas.drawRect(Rect.fromLTWH(0,cell*9,cell*6,cell*6), yellowP);
    canvas.drawRect(Rect.fromLTWH(cell*9,cell*9,cell*6,cell*6), blueP);
    for (final o in const [Offset(1.2,1.2),Offset(3.7,1.2),Offset(1.2,3.7),Offset(3.7,3.7)]) {
      canvas.drawCircle(Offset(o.dx*cell,o.dy*cell),cell*.55,white);
      canvas.drawCircle(Offset((15-o.dx)*cell,(15-o.dy)*cell),cell*.55,white);
    }

    // Cross track and grid.
    for (var r=0;r<15;r++) {
      for (var col=0;col<15;col++) {
        if ((col>=6&&col<=8)||(r>=6&&r<=8)) {
          final rect=Rect.fromLTWH(col*cell,r*cell,cell,cell);
          canvas.drawRect(rect, white); canvas.drawRect(rect, grid);
        }
      }
    }
    // Home lanes for the two playable colors.
    for (var i=1;i<=5;i++) {
      canvas.drawRect(Rect.fromLTWH(7*cell,i*cell,cell,cell), redP);
      canvas.drawRect(Rect.fromLTWH(7*cell,(14-i)*cell,cell,cell), blueP);
    }
    // Center home triangles.
    final center=Offset(7.5*cell,7.5*cell);
    final redTri=Path()..moveTo(6*cell,6*cell)..lineTo(9*cell,6*cell)..lineTo(center.dx,center.dy)..close();
    final blueTri=Path()..moveTo(6*cell,9*cell)..lineTo(9*cell,9*cell)..lineTo(center.dx,center.dy)..close();
    canvas.drawPath(redTri,redP); canvas.drawPath(blueTri,blueP);

    void token(List<int> vals,bool blue,Paint paint) {
      for(var i=0;i<4;i++) {
        final p=vals[i];
        Offset pos;
        if(p<0) {
          final base=blue?const Offset(10.5,10.5):const Offset(1.5,1.5);
          pos=Offset((base.dx+(i%2)*2)*cell,(base.dy+(i~/2)*2)*cell);
        } else if(p>=52) {
          final lane=(p-51).clamp(1,5);
          pos=blue?Offset(7.5*cell,(14-lane+.5)*cell):Offset(7.5*cell,(lane+.5)*cell);
        } else {
          pos=_trackPoint(p,size,blue);
        }
        canvas.drawCircle(pos,cell*.31,paint);
        canvas.drawCircle(pos,cell*.31,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=2);
      }
    }
    token(red,false,redP); token(blue,true,blueP);
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) => true;
}

// ---------------- UNO ----------------

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

class UnoGameV07 extends StatefulWidget {
  const UnoGameV07({super.key, required this.mode});
  final V07GameMode mode;

  @override
  State<UnoGameV07> createState() => _UnoGameV07State();
}

class _UnoGameV07State extends State<UnoGameV07> {
  final rng = Random();
  final deck = <_UnoCardData>[];
  final player = <_UnoCardData>[];
  final opponent = <_UnoCardData>[];
  final discard = <_UnoCardData>[];
  int turn = 0;
  String activeColor = 'Red';
  String status = 'Your turn';

  bool get botMode => widget.mode == V07GameMode.soloBot;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
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
    player.addAll(List.generate(7, (_) => deck.removeLast()));
    opponent.addAll(List.generate(7, (_) => deck.removeLast()));
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

  Future<String> _chooseColor() async {
    if (botMode && turn == 1) {
      final counts = <String, int>{'Red': 0, 'Blue': 0, 'Green': 0, 'Yellow': 0};
      for (final c in opponent) {
        if (counts.containsKey(c.color)) counts[c.color] = counts[c.color]! + 1;
      }
      return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Choose color'),
        content: Wrap(
          spacing: 8,
          children: [
            for (final color in ['Red', 'Blue', 'Green', 'Yellow'])
              ActionChip(
                label: Text(color),
                onPressed: () => Navigator.pop(context, color),
              ),
          ],
        ),
      ),
    );
    return result ?? 'Red';
  }

  Future<void> playCard(int index) async {
    final hand = turn == 0 ? player : opponent;
    if (index < 0 || index >= hand.length) return;
    final card = hand[index];
    if (!card.canPlayOn(discard.last, activeColor)) return;

    setState(() {
      hand.removeAt(index);
      discard.add(card);
      if (!card.wild) activeColor = card.color;
      status = (turn == 0 ? 'You' : (botMode ? 'Bot' : 'Player 2')) +
          ' played ' +
          card.toString();
    });

    if (card.wild) {
      final chosen = await _chooseColor();
      if (!mounted) return;
      setState(() => activeColor = chosen);
    }

    if (hand.isEmpty) {
      setState(() {
        status = (turn == 0 ? 'You' : (botMode ? 'Bot' : 'Player 2')) +
            ' wins! 🎉';
      });
      return;
    }

    var skip = false;
    if (card.value == '+4') {
      setState(() => _drawTo(turn == 0 ? opponent : player, 4));
      skip = true;
    } else if (card.value == '+2') {
      setState(() => _drawTo(turn == 0 ? opponent : player, 2));
      skip = true;
    } else if (card.value == 'Skip' || card.value == 'Reverse') {
      // In a two-player match Reverse acts like Skip.
      skip = true;
    }
    if (!skip) setState(() => turn = 1 - turn);

    if (botMode && turn == 1) {
      Future.delayed(const Duration(milliseconds: 650), _botPlay);
    }
  }

  void drawCard() {
    if (botMode && turn == 1) return;
    setState(() {
      _drawTo(turn == 0 ? player : opponent, 1);
      turn = 1 - turn;
      status = turn == 0 ? 'Player 1 turn' : (botMode ? 'Bot turn' : 'Player 2 turn');
    });
    if (botMode && turn == 1) {
      Future.delayed(const Duration(milliseconds: 650), _botPlay);
    }
  }

  Future<void> _botPlay() async {
    if (!mounted || turn != 1) return;
    final playable = <int>[];
    for (var i = 0; i < opponent.length; i++) {
      if (opponent[i].canPlayOn(discard.last, activeColor)) playable.add(i);
    }
    if (playable.isEmpty) {
      setState(() {
        _drawTo(opponent, 1);
        turn = 0;
        status = 'Bot drew • Your turn';
      });
      return;
    }
    await playCard(playable.first);
    if (mounted && turn == 0 && !status.contains('wins')) {
      setState(() => status = 'Your turn');
    }
  }

  Color _colorFor(String color) {
    if (color == 'Red') return Colors.red;
    if (color == 'Blue') return Colors.blue;
    if (color == 'Green') return Colors.green;
    if (color == 'Yellow') return Colors.amber;
    return Colors.deepPurple;
  }

  Widget _card(_UnoCardData card, {VoidCallback? onTap, bool hidden = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 102,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: hidden ? const Color(0xFF2C1640) : _colorFor(card.color),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white70, width: 2),
        ),
        child: Center(
          child: Text(
            hidden ? 'UNO' : card.value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = discard.last;
    return Scaffold(
      appBar: AppBar(title: const Text('UNO')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(status, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(botMode ? 'Bot cards: ' + opponent.length.toString() : 'Player 2 cards: ' + opponent.length.toString()),
          SizedBox(
            height: 116,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < opponent.length; i++)
                  _card(
                    opponent[i],
                    hidden: botMode || turn == 0,
                    onTap: !botMode && turn == 1 ? () => playCard(i) : null,
                  ),
              ],
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _card(top),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text('Active: ' + activeColor),
                  FilledButton.icon(
                    key: const Key('uno-draw-v07'),
                    onPressed: !botMode || turn == 0 ? drawCard : null,
                    icon: const Icon(Icons.add_box_rounded),
                    label: const Text('Draw'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          Text(
            turn == 0 ? 'Your hand' : (botMode ? 'Waiting for bot...' : 'Player 1 hand'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(
            height: 116,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < player.length; i++)
                  _card(
                    player[i],
                    hidden: !botMode && turn == 1,
                    onTap: turn == 0 ? () => playCard(i) : null,
                  ),
              ],
            ),
          ),
          if (!botMode && turn == 1)
            const Text(
              'Phone Player 2 ko de do. Upar wali cards se play kare.',
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

// ---------------- CARROM ----------------

class _CarromPiece {
  _CarromPiece({
    required this.p,
    required this.kind,
    this.v = Offset.zero,
    this.pocketed = false,
  });
  Offset p;
  Offset v;
  final int kind;
  bool pocketed;
}

class CarromGameV07 extends StatefulWidget {
  const CarromGameV07({super.key, required this.mode});
  final V07GameMode mode;

  @override
  State<CarromGameV07> createState() => _CarromGameV07State();
}

class _CarromGameV07State extends State<CarromGameV07>
    with SingleTickerProviderStateMixin {
  final pieces = <_CarromPiece>[];
  late final AnimationController ticker;
  int turn = 0;
  int score1 = 0;
  int score2 = 0;
  Offset? dragStart;
  Offset? dragNow;
  bool shotActive = false;
  bool botThinking = false;

  bool get botTurn => widget.mode == V07GameMode.soloBot && turn == 1;
  _CarromPiece get striker => pieces.last;

  @override
  void initState() {
    super.initState();
    _setup();
    ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )
      ..addListener(_physicsTick)
      ..repeat();
  }

  void _setup() {
    final center = const Offset(.5, .5);
    final offsets = [
      Offset.zero,
      const Offset(.055, 0),
      const Offset(-.055, 0),
      const Offset(0, .055),
      const Offset(0, -.055),
      const Offset(.042, .042),
      const Offset(-.042, .042),
      const Offset(.042, -.042),
      const Offset(-.042, -.042),
    ];
    for (var i = 0; i < offsets.length; i++) {
      pieces.add(
        _CarromPiece(
          p: center + offsets[i],
          kind: i == 0 ? 2 : (i.isEven ? 0 : 1),
        ),
      );
    }
    pieces.add(_CarromPiece(p: const Offset(.5, .86), kind: 3));
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  void _physicsTick() {
    if (!mounted) return;
    var anyMoving = false;
    for (final p in pieces) {
      if (p.pocketed) continue;
      if (p.v.distance > .0002) {
        anyMoving = true;
        p.p += p.v;
        p.v *= .985;
        var dx = p.p.dx;
        var dy = p.p.dy;
        var vx = p.v.dx;
        var vy = p.v.dy;
        const minV = .055;
        const maxV = .945;
        if (dx < minV || dx > maxV) {
          dx = dx.clamp(minV, maxV);
          vx = -vx * .86;
        }
        if (dy < minV || dy > maxV) {
          dy = dy.clamp(minV, maxV);
          vy = -vy * .86;
        }
        p.p = Offset(dx, dy);
        p.v = Offset(vx, vy);
        for (final hole in const [
          Offset(.065, .065),
          Offset(.935, .065),
          Offset(.065, .935),
          Offset(.935, .935),
        ]) {
          if ((p.p - hole).distance < .055) {
            _pocket(p);
            break;
          }
        }
      }
    }

    for (var i = 0; i < pieces.length; i++) {
      final a = pieces[i];
      if (a.pocketed) continue;
      for (var j = i + 1; j < pieces.length; j++) {
        final b = pieces[j];
        if (b.pocketed) continue;
        final d = b.p - a.p;
        final dist = d.distance;
        if (dist > 0 && dist < .045) {
          final n = d / dist;
          final rel = (a.v - b.v).dx * n.dx + (a.v - b.v).dy * n.dy;
          if (rel > 0) {
            final impulse = n * (rel * .92);
            a.v -= impulse;
            b.v += impulse;
          }
        }
      }
    }

    if (shotActive && !anyMoving) {
      shotActive = false;
      _finishTurn();
    }
    setState(() {});
  }

  void _pocket(_CarromPiece p) {
    if (p.kind == 3) {
      p.p = turn == 0 ? const Offset(.5, .86) : const Offset(.5, .14);
      p.v = Offset.zero;
      if (turn == 0) score1 = max(0, score1 - 1);
      if (turn == 1) score2 = max(0, score2 - 1);
      return;
    }
    p.pocketed = true;
    p.v = Offset.zero;
    final points = p.kind == 2 ? 3 : 1;
    if (turn == 0) {
      score1 += points;
    } else {
      score2 += points;
    }
  }

  void _finishTurn() {
    if (pieces.where((p) => p.kind != 3 && !p.pocketed).isEmpty) return;
    turn = 1 - turn;
    striker
      ..pocketed = false
      ..v = Offset.zero
      ..p = turn == 0 ? const Offset(.5, .86) : const Offset(.5, .14);
    setState(() {});
    if (botTurn) {
      Future.delayed(const Duration(milliseconds: 700), _botShot);
    }
  }

  void _botShot() {
    if (!mounted || !botTurn || shotActive || botThinking) return;
    botThinking = true;
    final targets = pieces.where((p) => p.kind != 3 && !p.pocketed).toList();
    if (targets.isEmpty) return;
    final target = targets.first;
    final dir = target.p - striker.p;
    final len = max(.001, dir.distance);
    striker.v = dir / len * .018;
    shotActive = true;
    botThinking = false;
    setState(() {});
  }

  void _shoot(Size size, Offset start, Offset end) {
    if (shotActive || botTurn) return;
    final pull = start - end;
    final velocity = Offset(pull.dx / size.width, pull.dy / size.height);
    if (velocity.distance < .01) return;
    final capped = min(.03, velocity.distance * .09);
    striker.v = velocity / velocity.distance * capped;
    shotActive = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final remaining = pieces.where((p) => p.kind != 3 && !p.pocketed).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Carrom')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: Text('P1: ' + score1.toString())),
                Text(
                  remaining == 0
                      ? (score1 >= score2 ? 'P1 wins 🎉' : 'P2 wins 🎉')
                      : (turn == 0
                          ? 'Player 1 turn'
                          : (botTurn ? 'Bot turn' : 'Player 2 turn')),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Expanded(
                  child: Text(
                    'P2: ' + score2.toString(),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = Size(box.maxWidth, box.maxHeight);
                    return GestureDetector(
                      key: const Key('carrom-board-v07'),
                      onPanStart: shotActive || botTurn
                          ? null
                          : (d) => setState(() {
                                dragStart = d.localPosition;
                                dragNow = d.localPosition;
                              }),
                      onPanUpdate: shotActive || botTurn
                          ? null
                          : (d) => setState(() => dragNow = d.localPosition),
                      onPanEnd: shotActive || botTurn
                          ? null
                          : (_) {
                              final start = dragStart;
                              final end = dragNow;
                              dragStart = null;
                              dragNow = null;
                              if (start != null && end != null) {
                                _shoot(size, start, end);
                              }
                            },
                      child: CustomPaint(
                        painter: _CarromPainter(
                          pieces: pieces,
                          dragStart: dragStart,
                          dragNow: dragNow,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Text(
              'Striker se opposite direction me drag karke release karo. Corners me coins pocket karo. Queen = 3 points.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarromPainter extends CustomPainter {
  _CarromPainter({
    required this.pieces,
    required this.dragStart,
    required this.dragNow,
  });
  final List<_CarromPiece> pieces;
  final Offset? dragStart;
  final Offset? dragNow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFFD9B77A),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .05, size.height * .05, size.width * .9, size.height * .9),
      Paint()..color = const Color(0xFFF0D19B),
    );
    final line = Paint()
      ..color = const Color(0xFF6B3A1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * .12, line);
    canvas.drawLine(
      Offset(size.width * .2, size.height * .86),
      Offset(size.width * .8, size.height * .86),
      line,
    );
    canvas.drawLine(
      Offset(size.width * .2, size.height * .14),
      Offset(size.width * .8, size.height * .14),
      line,
    );

    for (final hole in const [
      Offset(.065, .065),
      Offset(.935, .065),
      Offset(.065, .935),
      Offset(.935, .935),
    ]) {
      canvas.drawCircle(
        Offset(hole.dx * size.width, hole.dy * size.height),
        size.width * .042,
        Paint()..color = Colors.black87,
      );
    }

    for (final p in pieces) {
      if (p.pocketed) continue;
      final color = p.kind == 0
          ? Colors.white
          : p.kind == 1
              ? Colors.black
              : p.kind == 2
                  ? Colors.red
                  : const Color(0xFF673AB7);
      final pos = Offset(p.p.dx * size.width, p.p.dy * size.height);
      final radius = size.width * (p.kind == 3 ? .032 : .024);
      canvas.drawCircle(pos, radius, Paint()..color = color);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (dragStart != null && dragNow != null) {
      canvas.drawLine(
        dragStart!,
        dragNow!,
        Paint()
          ..color = Colors.deepPurple
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CarromPainter oldDelegate) => true;
}
