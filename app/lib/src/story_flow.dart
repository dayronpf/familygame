import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/foundation.dart';

/// El cuento que se está contando, con sus preguntas al niño. Lo comparten la pantalla de texto, el cine y los
/// demás modos: lo que elige el niño en uno se ve en los otros.
class StoryFlow extends ChangeNotifier {
  StoryFlow(this._run);

  StoryRun _run;

  StoryRun get run => _run;

  /// Lo contado hasta ahora (completo si [isComplete]).
  Story get story => _run.story;
  bool get isComplete => _run.isComplete;
  StoryChoice? get pending => _run.pending;

  /// Responde a la pregunta pendiente. [auto] = la eligió la app y no el niño.
  void choose(String optionId, {bool auto = false}) {
    if (isComplete) return;
    _run = _run.choose(optionId, auto: auto);
    notifyListeners();
  }

  /// «Elige por nosotros»: la app responde por su cuenta.
  void chooseForMe() {
    if (!isComplete) choose(_run.autoOption, auto: true);
  }

  /// Los modos sin pantalla de preguntas (holograma, solo audio) necesitan el cuento entero: lo que falte lo
  /// elige la app.
  Story finish() {
    while (!isComplete) {
      chooseForMe();
    }
    return story;
  }
}
