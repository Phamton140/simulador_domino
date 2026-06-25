import 'dart:async';
import 'package:flutter/material.dart';
import 'domino_game.dart';

void main() {
  runApp(const DominoApp());
}

class DominoApp extends StatelessWidget {
  const DominoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Domino Game',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1a1a1a),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameEngine engine = GameEngine();
  Timer? turnTimer;
  int timeLeft = 5;
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    engine.onStateChanged = () {
      setState(() {});
    };
    engine.onTurnStart = (playerIndex) {
      _startTimer(playerIndex);
    };
  }

  void _startTimer(int playerIndex) {
    turnTimer?.cancel();
    setState(() {
      timeLeft = 5;
    });

    turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
      });

      if (timeLeft <= 0) {
        timer.cancel();
        engine.playAutoMove();
      }
    });

    // Si es un bot, juega más rápido que los 5 segundos, por ejemplo a los 2 segundos
    if (playerIndex != 0) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (engine.currentPlayer == playerIndex && turnTimer != null && turnTimer!.isActive) {
          turnTimer?.cancel();
          engine.playAutoMove();
        }
      });
    }
  }

  @override
  void dispose() {
    turnTimer?.cancel();
    super.dispose();
  }

  void _onPlayerPieceTapped(int index, List<Map<String, dynamic>> validMoves) {
    if (engine.currentPlayer != 0) return;
    var movesForPiece = validMoves.where((m) => m['dominoIndex'] == index).toList();
    if (movesForPiece.isEmpty) return;

    turnTimer?.cancel();
    if (movesForPiece.length == 1) {
      engine.playMove(0, movesForPiece.first['dominoIndex'], movesForPiece.first['end']);
    } else {
      // Tap: juega por el extremo más cercano a la posición del jugador (Sur)
      engine.playMove(0, movesForPiece.first['dominoIndex'],
          engine.getClosestEndForPlayer(0));
    }
  }

  void _onDrop(int dominoIndex, Offset globalDropOffset, List<Map<String, dynamic>> validMoves) {
    if (engine.currentPlayer != 0) return;
    var movesForPiece = validMoves.where((m) => m['dominoIndex'] == dominoIndex).toList();
    if (movesForPiece.isEmpty) return;

    turnTimer?.cancel();
    if (movesForPiece.length == 1) {
      engine.playMove(0, dominoIndex, movesForPiece.first['end']);
      return;
    }

    // Arrastrado: resolver por proximidad al punto donde se soltó
    final RenderBox? boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (boardBox == null) {
      engine.playMove(0, dominoIndex, movesForPiece.first['end']);
      return;
    }
    final Offset localDrop = boardBox.globalToLocal(globalDropOffset);

    // Calcular distancia del punto de drop a cada extremo
    final e1 = engine.ends[1]!;
    final e2 = engine.ends[2]!;
    final d1 = (Offset(e1.x, e1.y) - localDrop).distance;
    final d2 = (Offset(e2.x, e2.y) - localDrop).distance;

    final chosenEnd = d1 <= d2 ? 1 : 2;
    // Verificar que la ficha efectivamente puede jugarse en ese extremo
    final validEnd = movesForPiece.any((m) => m['end'] == chosenEnd)
        ? chosenEnd
        : movesForPiece.first['end'];
    engine.playMove(0, dominoIndex, validEnd);
  }

  Widget _buildDots(int val) {
    List<Widget> dots = [];
    List<bool> active = List.filled(9, false);
    if (val == 1) active[4] = true;
    if (val == 2) { active[0] = true; active[8] = true; }
    if (val == 3) { active[0] = true; active[4] = true; active[8] = true; }
    if (val == 4) { active[0] = true; active[2] = true; active[6] = true; active[8] = true; }
    if (val == 5) { active[0] = true; active[2] = true; active[4] = true; active[6] = true; active[8] = true; }
    if (val == 6) { active[0] = true; active[3] = true; active[6] = true; active[2] = true; active[5] = true; active[8] = true; }

    for (int i = 0; i < 9; i++) {
      dots.add(
        Center(
          child: Container(
            width: 4.5, height: 4.5,
            decoration: BoxDecoration(
              color: active[i] ? const Color(0xFF1A1A1A) : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: active[i] ? const [
                // Un pequeño brillo inferior para simular hendidura 3D en el punto
                BoxShadow(color: Colors.white54, offset: Offset(0.5, 0.5), blurRadius: 0.5)
              ] : null,
            ),
          ),
        )
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(2),
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      physics: const NeverScrollableScrollPhysics(),
      children: dots,
    );
  }

  Widget _buildDomino(int val1, int val2, String flexDir, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFA), // Reflejo de luz (blanco tiza)
            Color(0xFFF5F0E1), // Color base Marfil
            Color(0xFFE3DAC1), // Sombra inferior del material
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD1C7AC), width: 0.5), // Borde suave
      ),
      child: flexDir == 'column' 
        ? Column(
            children: [
              Expanded(child: _buildDots(val1)),
              Container(height: 1.5, color: const Color(0xFFC4B89A)), // Surco central
              Expanded(child: _buildDots(val2)),
            ],
          )
        : Row(
            children: [
              Expanded(child: _buildDots(val1)),
              Container(width: 1.5, color: const Color(0xFFC4B89A)), // Surco central
              Expanded(child: _buildDots(val2)),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> validMoves = [];
    if (engine.isInitialized && engine.currentPlayer == 0) {
      validMoves = engine.getValidMoves(0);
    }

    return Scaffold(
      body: Column(
        children: [
          // Header / Stats
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 10),
            color: Colors.black26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("Oeste: ${engine.isInitialized ? engine.hands[3].length : 0} fichas"),
                Text("Norte: ${engine.isInitialized ? engine.hands[2].length : 0} fichas"),
                Text("Este: ${engine.isInitialized ? engine.hands[1].length : 0} fichas"),
              ],
            ),
          ),
          
          // Timer e Indicador de Turno
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  !engine.isInitialized || engine.currentPlayer == -1 
                    ? "Iniciando..." 
                    : (engine.currentPlayer == 0 ? "¡Tu Turno!" : "Turno del Jugador ${engine.currentPlayer}"),
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: engine.currentPlayer == 0 ? Colors.amber : Colors.white
                  ),
                ),
                const SizedBox(width: 20),
                if (engine.isInitialized && engine.currentPlayer != -1)
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.redAccent),
                      const SizedBox(width: 5),
                      Text("$timeLeft s", style: const TextStyle(fontSize: 20)),
                    ],
                  ),
              ],
            ),
          ),

          // Mesa
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (!engine.isInitialized) {
                  Future.microtask(() {
                    engine.initGame(constraints.maxWidth, constraints.maxHeight);
                    setState(() {});
                  });
                  return const Center(child: CircularProgressIndicator());
                }

                return Center(
                  child: Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: [Color(0xFF10522e), Color(0xFF0b3820)]
                      ),
                      border: Border.all(color: const Color(0xFF3e2723), width: 15),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)
                      ]
                    ),
                    child: DragTarget<int>(
                      key: _boardKey,
                      onWillAcceptWithDetails: (details) => engine.currentPlayer == 0,
                      onAcceptWithDetails: (details) {
                        _onDrop(details.data, details.offset, validMoves);
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Stack(
                          children: [
                            ...engine.board.map((pd) {
                              return Positioned(
                                left: pd.x,
                                top: pd.y,
                                child: _buildDomino(pd.renderVal1, pd.renderVal2, pd.flexDir, pd.width, pd.height),
                              );
                            }),
                            // Indicador visual cuando se está arrastrando una ficha
                            if (candidateData.isNotEmpty)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              }
            ),
          ),

          // Mano del jugador (Sur / 0)
          Container(
            height: 100,
            padding: const EdgeInsets.all(10),
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: engine.hands[0].asMap().entries.map((entry) {
                int idx = entry.key;
                Domino d = entry.value;
                bool isPlayable = engine.currentPlayer == 0 && validMoves.any((m) => m['dominoIndex'] == idx);

                final pieceWidget = AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  transform: isPlayable ? Matrix4.translationValues(0, -10, 0) : Matrix4.identity(),
                  child: _buildDomino(d.val1, d.val2, 'column', GameEngine.PIECE_W, GameEngine.PIECE_L),
                );

                return GestureDetector(
                  onTap: () => _onPlayerPieceTapped(idx, validMoves),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: engine.currentPlayer == 0 ? (isPlayable ? 1.0 : 0.5) : 1.0,
                    child: isPlayable
                      ? Draggable<int>(
                          data: idx,
                          feedback: Opacity(
                            opacity: 0.85,
                            child: Material(
                              color: Colors.transparent,
                              child: _buildDomino(d.val1, d.val2, 'column', GameEngine.PIECE_W, GameEngine.PIECE_L),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _buildDomino(d.val1, d.val2, 'column', GameEngine.PIECE_W, GameEngine.PIECE_L),
                          ),
                          child: pieceWidget,
                        )
                      : pieceWidget,
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}
