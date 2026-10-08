/// Semilla para un cuento nuevo. Se inyecta para poder probar la app.
typedef SeedProvider = int Function();

/// Semilla por defecto: cambia en cada llamada.
int timeSeed() => DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
