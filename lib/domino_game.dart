import 'dart:math';

class Domino {
  final int val1;
  final int val2;
  Domino(this.val1, this.val2);

  bool get isDouble => val1 == val2;

  bool matches(int value) => val1 == value || val2 == value;

  @override
  String toString() => '[$val1|$val2]';
}

class PlacedDomino {
  final Domino domino;
  final double x;
  final double y;
  final double width;
  final double height;
  final String flexDir; // 'row' or 'column'
  final int renderVal1;
  final int renderVal2;

  PlacedDomino({
    required this.domino,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.flexDir,
    required this.renderVal1,
    required this.renderVal2,
  });
}

class EndState {
  int openValue;
  double x;
  double y;
  Point<int> dir; // (0, -1) UP, (0, 1) DOWN, (-1, 0) LEFT, (1, 0) RIGHT
  PlacedDomino? lastBox;

  EndState(this.openValue, this.x, this.y, this.dir, this.lastBox);
}

class GameEngine {
  List<Domino> pool = [];
  List<List<Domino>> hands = [[], [], [], []];
  List<PlacedDomino> board = [];
  
  Map<int, EndState> ends = {};
  
  int currentPlayer = -1;
  Function()? onStateChanged;
  Function(int)? onTurnStart;

  double tableW = 800;
  double tableH = 600;
  bool isInitialized = false;

  static const double PIECE_L = 50;
  static const double PIECE_W = 25;
  static const double MARGIN = 70; // Reducido un poco para aprovechar mejor pantallas pequeñas

  void initGame(double w, double h) {
    tableW = w;
    tableH = h;
    isInitialized = true;

    pool.clear();
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        pool.add(Domino(i, j));
      }
    }
    pool.shuffle(Random());

    hands = [[], [], [], []];
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 7; j++) {
        hands[i].add(pool.removeLast());
      }
    }

    board.clear();
    ends.clear();

    // Find who has Double 6
    currentPlayer = -1;
    for (int i = 0; i < 4; i++) {
      int idx = hands[i].indexWhere((d) => d.val1 == 6 && d.val2 == 6);
      if (idx != -1) {
        currentPlayer = i;
        Domino d6 = hands[i].removeAt(idx);
        _placeInitialDouble6(d6);
        break;
      }
    }

    // Pass turn to next player
    nextTurn();
  }

  void _placeInitialDouble6(Domino d6) {
    double cx = tableW / 2;
    double cy = tableH / 2;
    double w = PIECE_L;
    double h = PIECE_W;
    double px = cx - w / 2;
    double py = cy - h / 2;

    PlacedDomino pd = PlacedDomino(
      domino: d6,
      x: px, y: py, width: w, height: h,
      flexDir: 'row',
      renderVal1: 6, renderVal2: 6
    );
    board.add(pd);

    ends[1] = EndState(6, cx, cy - h / 2, Point(0, -1), pd); // North
    ends[2] = EndState(6, cx, cy + h / 2, Point(0, 1), pd); // South
  }

  void nextTurn() {
    currentPlayer = (currentPlayer + 1) % 4;
    
    // Check if player has valid moves
    if (getValidMoves(currentPlayer).isEmpty) {
      // Pass
      print("Player $currentPlayer passes!");
      if (onStateChanged != null) onStateChanged!();
      // Pequeña pausa antes de pasar al siguiente
      Future.delayed(Duration(seconds: 1), () {
        nextTurn();
      });
      return;
    }

    if (onStateChanged != null) onStateChanged!();
    if (onTurnStart != null) onTurnStart!(currentPlayer);
  }

  List<Map<String, dynamic>> getValidMoves(int playerIndex) {
    List<Map<String, dynamic>> moves = [];
    for (int i = 0; i < hands[playerIndex].length; i++) {
      Domino d = hands[playerIndex][i];
      if (d.matches(ends[1]!.openValue)) {
        moves.add({'dominoIndex': i, 'end': 1});
      }
      if (d.matches(ends[2]!.openValue)) {
        moves.add({'dominoIndex': i, 'end': 2});
      }
    }
    return moves;
  }

  void playMove(int playerIndex, int dominoIndex, int endId) {
    Domino d = hands[playerIndex].removeAt(dominoIndex);
    EndState end = ends[endId]!;

    int matchVal = end.openValue;
    int newVal = (d.val1 == matchVal) ? d.val2 : d.val1;

    bool isDouble = d.isDouble;
    bool needTurn = false;
    
    // SAFE_PADDING asegura que la ficha termine al menos a 35px del borde físico 
    // (15px de borde de madera + 20px de margen visual)
    double safePadding = 35.0; 
    
    // Calculamos dónde terminaría la punta de la ficha si la colocamos recto
    double nextLength = isDouble ? PIECE_W : PIECE_L;
    double projectedX = end.x + (end.dir.x * nextLength);
    double projectedY = end.y + (end.dir.y * nextLength);

    if (!isDouble) {
      if (end.dir.y == -1 && projectedY < safePadding) needTurn = true;
      if (end.dir.y == 1 && projectedY > tableH - safePadding) needTurn = true;
      if (end.dir.x == -1 && projectedX < safePadding) needTurn = true;
      if (end.dir.x == 1 && projectedX > tableW - safePadding) needTurn = true;
    }

    if (needTurn) {
      _turnCounterClockwise(end);
    }

    Point<int> dir = end.dir;
    double w, h;
    if (dir.y != 0) {
      w = isDouble ? PIECE_L : PIECE_W;
      h = isDouble ? PIECE_W : PIECE_L;
    } else {
      w = isDouble ? PIECE_W : PIECE_L;
      h = isDouble ? PIECE_L : PIECE_W;
    }

    double px = 0, py = 0;
    String flexDir = w > h ? 'row' : 'column';
    int renderVal1 = 0, renderVal2 = 0;

    if (dir.y == -1) {
      px = end.x - w / 2;
      py = end.y - h;
      end.x = px + w / 2;
      end.y = py;
      renderVal1 = newVal;
      renderVal2 = matchVal;
    } else if (dir.y == 1) {
      px = end.x - w / 2;
      py = end.y;
      end.x = px + w / 2;
      end.y = py + h;
      renderVal1 = matchVal;
      renderVal2 = newVal;
    } else if (dir.x == -1) {
      px = end.x - w;
      py = end.y - h / 2;
      end.x = px;
      end.y = py + h / 2;
      renderVal1 = newVal;
      renderVal2 = matchVal;
    } else if (dir.x == 1) {
      px = end.x;
      py = end.y - h / 2;
      end.x = px + w;
      end.y = py + h / 2;
      renderVal1 = matchVal;
      renderVal2 = newVal;
    }

    PlacedDomino pd = PlacedDomino(
      domino: d,
      x: px, y: py, width: w, height: h,
      flexDir: flexDir, renderVal1: renderVal1, renderVal2: renderVal2
    );
    board.add(pd);

    end.openValue = newVal;
    end.lastBox = pd;

    if (hands[playerIndex].isEmpty) {
      // Win!
      if (onStateChanged != null) onStateChanged!();
      print("Player $playerIndex WINS!");
      return;
    }

    nextTurn();
  }

  void _turnCounterClockwise(EndState end) {
    PlacedDomino box = end.lastBox!;
    if (end.dir.y == -1) {
      end.dir = Point(-1, 0);
      end.x = box.x;
      end.y = box.y + 15;
    } else if (end.dir.x == -1) {
      end.dir = Point(0, 1);
      end.x = box.x + 15;
      end.y = box.y + box.height;
    } else if (end.dir.y == 1) {
      end.dir = Point(1, 0);
      end.x = box.x + box.width;
      end.y = box.y + box.height - 15;
    } else if (end.dir.x == 1) {
      end.dir = Point(0, -1);
      end.x = box.x + box.width - 15;
      end.y = box.y;
    }
  }

  void playAutoMove() {
    var moves = getValidMoves(currentPlayer);
    if (moves.isNotEmpty) {
      // Pick random
      var move = moves[Random().nextInt(moves.length)];
      playMove(currentPlayer, move['dominoIndex'], move['end']);
    }
  }
}
