import 'dart:math';
import 'package:flutter/material.dart';

enum V08GameMode { soloBot, localMulti }

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



class _FourSeatHeaderV08 extends StatelessWidget {
  const _FourSeatHeaderV08({required this.game});
  final String game;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _seat('P1', Icons.person, true),
        _seat('P2', Icons.smart_toy, false),
        Column(children:[Text(game,style:const TextStyle(fontWeight:FontWeight.w900)),const Text('4-seat table',style:TextStyle(fontSize:11))]),
        _seat('P3', Icons.smart_toy, false),
        _seat('P4', Icons.smart_toy, false),
      ]),
    ),
  );
  Widget _seat(String n, IconData i, bool active)=>Column(children:[
    CircleAvatar(radius:18,child:Icon(i,size:20)),
    Text(n,style:TextStyle(fontSize:11,fontWeight:active?FontWeight.w900:FontWeight.w500))
  ]);
}

class GamesCenterV08 extends StatelessWidget {
  const GamesCenterV08({super.key});
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameLauncherV08(game:g.$1))),
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
  const GameLauncherV08({super.key, required this.game});
  final String game;

  void _open(BuildContext context, V08GameMode mode) {
    final Widget page = switch (game) {
      'Ludo' => LudoGameV08(mode: mode),
      'UNO' => UnoGameV08(mode: mode),
      'Carrom' => CarromGameV08(mode: mode),
      'Lucky Dice' => LuckyDiceGameV08(mode: mode),
      'Lucky Wheel' => LuckyWheelGameV08(mode: mode),
      'Rock Paper Scissors' => RpsGameV08(mode: mode),
      'Teen Patti' => TeenPattiGameV08(mode: mode),
      _ => LudoGameV08(mode: mode),
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
              title: 'Solo vs Bot',
              subtitle: '4-seat table: aap + 3 bots.',
              onTap: () => _open(context, V08GameMode.soloBot),
            ),
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

// ---------------- LUDO ----------------

class LudoGameV08 extends StatefulWidget {
  const LudoGameV08({super.key, required this.mode});
  final V08GameMode mode;

  @override
  State<LudoGameV08> createState() => _LudoGameV08State();
}

class _LudoGameV08State extends State<LudoGameV08> {
  final rng = Random();
  final red = List<int>.filled(4, -1);
  final blue = List<int>.filled(4, -1);
  int current = 0;
  int? dice;
  String status = 'Roll the dice';
  bool busy = false;

  bool get botTurn => widget.mode == V08GameMode.soloBot && current == 1;
  String get currentName => current == 0
      ? 'You / Red'
      : (widget.mode == V08GameMode.soloBot ? 'Bot / Blue' : 'Player 2 / Blue');

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
      backgroundColor: const Color(0xFF0C1022),
      appBar: AppBar(title: const Text('Ludo 3D')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const _FourSeatHeaderV08(game: 'Ludo'),
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
                      key: const Key('ludo-roll-v08'),
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
                painter: _LudoBoardPainter(red: red, blue: blue),
              ),
            ),
          ),
        ),
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
  const UnoGameV08({super.key, required this.mode});
  final V08GameMode mode;
  @override
  State<UnoGameV08> createState() => _UnoGameV08State();
}

class _UnoGameV08State extends State<UnoGameV08> {
  final rng = Random();
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
    _newGame();
  }

  String _name(int seat) {
    if (!botMode) return 'Player ' + (seat + 1).toString();
    return seat == 0 ? 'You' : 'Bot ' + seat.toString();
  }

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

  Widget _seat(int seat) {
    final active = turn == seat && winner == null;
    final colors = [Colors.cyanAccent, Colors.pinkAccent, Colors.amberAccent, Colors.greenAccent];
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        key: Key('uno-seat-' + (seat + 1).toString() + '-v08'),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
        decoration: BoxDecoration(
          color: active ? colors[seat].withOpacity(.16) : Colors.black26,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: active ? colors[seat] : Colors.white24, width: active ? 2 : 1),
          boxShadow: active ? [BoxShadow(color: colors[seat].withOpacity(.3), blurRadius: 12)] : null,
        ),
        child: Column(
          children: [
            Icon(botMode && seat != 0 ? Icons.smart_toy_rounded : Icons.person_rounded, size: 18),
            Text(_name(seat), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            Text(hands[seat].length.toString() + ' cards', style: const TextStyle(fontSize: 9)),
          ],
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
                child: Row(children: [for (var i = 0; i < 4; i++) _seat(i)]),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.white10,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Text(status, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('Direction: ' + (direction == 1 ? '↻' : '↺') + ' • Active: ' + activeColor),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _card3d(discard.last),
                          const SizedBox(width: 16),
                          Column(
                            children: [
                              Container(
                                width: 62,
                                height: 92,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF32104F), Color(0xFF11182D)]),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white38, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 7))],
                                ),
                                child: Center(child: Text(deck.length.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                              ),
                              const SizedBox(height: 7),
                              FilledButton.icon(
                                key: const Key('uno-draw-v08'),
                                onPressed: humanCanPlay ? drawCard : null,
                                icon: const Icon(Icons.add_box_rounded),
                                label: const Text('Draw'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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

class CarromGameV08 extends StatefulWidget {
  const CarromGameV08({super.key, required this.mode});
  final V08GameMode mode;
  @override
  State<CarromGameV08> createState() => _CarromGameV08State();
}

class _CarromGameV08State extends State<CarromGameV08>
    with SingleTickerProviderStateMixin {
  final pieces = <_CarromPiece>[];
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

  String _name(int seat) {
    if (!botMode) return 'P' + (seat + 1).toString();
    return seat == 0 ? 'You' : 'Bot ' + seat.toString();
  }

  Offset _home(int seat) {
    if (seat == 0) return const Offset(.50, .86);
    if (seat == 1) return const Offset(.86, .50);
    if (seat == 2) return const Offset(.50, .14);
    return const Offset(.14, .50);
  }

  @override
  void initState() {
    super.initState();
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
    if (!mounted) return;
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

  Widget _seat(int seat) {
    final active = turn == seat && winner == null;
    final colors = [Colors.cyanAccent, Colors.pinkAccent, Colors.amberAccent, Colors.greenAccent];
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        key: Key('carrom-seat-' + (seat + 1).toString() + '-v08'),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
        decoration: BoxDecoration(
          color: active ? colors[seat].withOpacity(.16) : Colors.black26,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: active ? colors[seat] : Colors.white24, width: active ? 2 : 1),
          boxShadow: active ? [BoxShadow(color: colors[seat].withOpacity(.3), blurRadius: 12)] : null,
        ),
        child: Column(
          children: [
            Icon(botMode && seat != 0 ? Icons.smart_toy_rounded : Icons.person_rounded, size: 18),
            Text(_name(seat), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            Text(scores[seat].toString() + ' pts', style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
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
              Container(
                key: const Key('carrom-four-player-v08'),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                child: Row(children: [for (var i = 0; i < 4; i++) _seat(i)]),
              ),
              Text(
                winner != null
                    ? _name(winner!) + ' wins 🎉'
                    : _name(turn) + ' turn • ' + left.toString() + ' coins left',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
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
                                  BoxShadow(color: Colors.black87, blurRadius: 26, offset: Offset(0, 18)),
                                  BoxShadow(color: Color(0x5539FFCE), blurRadius: 20, spreadRadius: 2),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: GestureDetector(
                                  key: const Key('carrom-board-v08'),
                                  onPanStart: shotActive || botTurn || winner != null
                                      ? null
                                      : (d) => setState(() {
                                            dragStart = d.localPosition;
                                            dragNow = d.localPosition;
                                          }),
                                  onPanUpdate: shotActive || botTurn || winner != null
                                      ? null
                                      : (d) => setState(() => dragNow = d.localPosition),
                                  onPanEnd: shotActive || botTurn || winner != null
                                      ? null
                                      : (_) {
                                          final start = dragStart;
                                          final end = dragNow;
                                          dragStart = null;
                                          dragNow = null;
                                          if (start != null && end != null) _shoot(size, start, end);
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
  const LuckyDiceGameV08({super.key, required this.mode}); final V08GameMode mode;
  @override State<LuckyDiceGameV08> createState()=>_LuckyDiceGameV08State();
}
class _LuckyDiceGameV08State extends State<LuckyDiceGameV08> {
  final r=Random(); int you=0,other=0,round=0; String status='Roll to start';
  void roll(){ final a=r.nextInt(6)+1,b=r.nextInt(6)+1; setState((){round++; if(a>b)you++; if(b>a)other++; status='You: $a • ${widget.mode==V08GameMode.soloBot?'Bot':'P2'}: $b';});}
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Lucky Dice')),body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(status,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),Text('Score $you - $other • Round $round'),const SizedBox(height:18),FilledButton.icon(key:const Key('lucky-dice-roll-v08'),onPressed:roll,icon:const Icon(Icons.casino),label:const Text('Roll Dice'))])));
}
class LuckyWheelGameV08 extends StatefulWidget {
 const LuckyWheelGameV08({super.key,required this.mode}); final V08GameMode mode;
 @override State<LuckyWheelGameV08> createState()=>_LuckyWheelGameV08State();
}
class _LuckyWheelGameV08State extends State<LuckyWheelGameV08>{
 final r=Random(); final prizes=['10 points','25 points','50 points','100 points','Bonus','Try Again']; String result='Spin the wheel';
 void spin()=>setState(()=>result=prizes[r.nextInt(prizes.length)]);
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Lucky Wheel')),body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:220,height:220,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(width:10)),child:Center(child:Text(result,textAlign:TextAlign.center,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)))),const SizedBox(height:20),FilledButton(key:const Key('lucky-wheel-spin-v08'),onPressed:spin,child:const Text('SPIN'))])));
}
class RpsGameV08 extends StatefulWidget {const RpsGameV08({super.key,required this.mode});final V08GameMode mode;@override State<RpsGameV08> createState()=>_RpsGameV08State();}
class _RpsGameV08State extends State<RpsGameV08>{
 final r=Random(); final choices=['Rock','Paper','Scissors']; String result='Choose your move'; int wins=0,losses=0;
 void play(String me){final bot=choices[r.nextInt(3)]; final win=(me=='Rock'&&bot=='Scissors')||(me=='Paper'&&bot=='Rock')||(me=='Scissors'&&bot=='Paper'); setState((){if(me==bot)result='Draw • $bot';else if(win){wins++;result='You win • opponent: $bot';}else{losses++;result='Opponent wins • $bot';}});}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Rock Paper Scissors')),body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(result,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),Text('Wins $wins • Losses $losses'),const SizedBox(height:16),Wrap(spacing:10,children:[for(final x in choices)FilledButton(onPressed:()=>play(x),child:Text(x))])])));
}
class TeenPattiGameV08 extends StatefulWidget {const TeenPattiGameV08({super.key,required this.mode});final V08GameMode mode;@override State<TeenPattiGameV08> createState()=>_TeenPattiGameV08State();}
class _TeenPattiGameV08State extends State<TeenPattiGameV08>{
 final r=Random(); List<int> hand=[]; String rank='';
 void deal(){final cards=<int>{};while(cards.length<3)cards.add(r.nextInt(52)); final h=cards.toList(); final vals=h.map((x)=>x%13+2).toList()..sort(); final suits=h.map((x)=>x~/13).toList(); final same=vals.toSet().length==1,pair=vals.toSet().length==2,color=suits.toSet().length==1,seq=(vals[2]-vals[1]==1&&vals[1]-vals[0]==1); setState((){hand=h;rank=same?'Trail':color&&seq?'Pure Sequence':seq?'Sequence':color?'Color':pair?'Pair':'High Card';});}
 String card(int x)=>['♠','♥','♦','♣'][x~/13]+(['2','3','4','5','6','7','8','9','10','J','Q','K','A'][x%13]);
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Teen Patti Practice')),body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Practice only • no betting or cash rewards'),const SizedBox(height:14),Text(hand.isEmpty?'Deal cards':hand.map(card).join('   '),style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),Text(rank,style:const TextStyle(fontSize:22)),const SizedBox(height:18),FilledButton(key:const Key('teen-patti-deal-v08'),onPressed:deal,child:const Text('Deal'))])));
}
