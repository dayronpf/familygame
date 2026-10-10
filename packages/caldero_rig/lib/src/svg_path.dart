/// Comando de ruta ya interpretado (coordenadas absolutas).
sealed class PathCmd {
  const PathCmd();
}

class MoveTo extends PathCmd {
  const MoveTo(this.x, this.y);
  final double x, y;
}

class LineTo extends PathCmd {
  const LineTo(this.x, this.y);
  final double x, y;
}

class QuadTo extends PathCmd {
  const QuadTo(this.cx, this.cy, this.x, this.y);
  final double cx, cy, x, y;
}

class CubicTo extends PathCmd {
  const CubicTo(this.c1x, this.c1y, this.c2x, this.c2y, this.x, this.y);
  final double c1x, c1y, c2x, c2y, x, y;
}

/// Arco elíptico SVG (`A rx ry rot large sweep x y`).
class ArcTo extends PathCmd {
  const ArcTo(
    this.rx,
    this.ry,
    this.rotation,
    this.largeArc,
    this.sweep,
    this.x,
    this.y,
  );
  final double rx, ry, rotation, x, y;
  final bool largeArc, sweep;
}

class ClosePath extends PathCmd {
  const ClosePath();
}

// Cualquier letra se tokeniza para poder rechazar las que no soportamos (antes se ignoraban sin avisar).
final RegExp _tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+(?:[eE][-+]?\d+)?');

const Map<String, int> _arity = {
  'M': 2,
  'L': 2,
  'Q': 4,
  'C': 6,
  'A': 7,
  'Z': 0,
};

/// Interpreta el atributo `d` de una ruta SVG. Solo comandos absolutos
/// (M L Q C A Z), que son los que emiten los generadores de arte.
List<PathCmd> parseSvgPath(String d) {
  final cmds = <PathCmd>[];
  final toks = _tokens.allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  String? cmd;
  while (i < toks.length) {
    final tok = toks[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(tok) && !_arity.containsKey(tok)) {
      throw FormatException(
        'comando de ruta no soportado «$tok» (solo M L Q C A Z absolutos): "$d"',
      );
    }
    if (_arity.containsKey(tok)) {
      cmd = tok;
      i++;
      if (cmd == 'Z') {
        cmds.add(const ClosePath());
        cmd = null;
        continue;
      }
    } else if (cmd == null) {
      throw FormatException('número inesperado en la ruta: "$d"');
    }
    final n = _arity[cmd]!;
    if (i + n > toks.length) throw FormatException('ruta incompleta: "$d"');
    final v = [for (var k = 0; k < n; k++) _num(toks[i + k], d)];
    i += n;
    switch (cmd) {
      case 'M':
        cmds.add(MoveTo(v[0], v[1]));
        cmd = 'L'; // pares siguientes = líneas
      case 'L':
        cmds.add(LineTo(v[0], v[1]));
      case 'Q':
        cmds.add(QuadTo(v[0], v[1], v[2], v[3]));
      case 'C':
        cmds.add(CubicTo(v[0], v[1], v[2], v[3], v[4], v[5]));
      case 'A':
        cmds.add(ArcTo(v[0], v[1], v[2], v[3] != 0, v[4] != 0, v[5], v[6]));
    }
  }
  return cmds;
}

double _num(String s, String d) =>
    double.tryParse(s) ??
    (throw FormatException('número inválido "$s" en: "$d"'));
