// Constantes con los nombres de colecciones de Firestore. Centralizar los
// strings evita errores de tipeo silenciosos y facilita renombrar colecciones.
class FirestorePaths {
  const FirestorePaths._();

  static const String usersCollection = 'users';

  // Subcolecciones de `users/{elderId}` (ADR-0029, ADR-0031, ADR-0032). Las
  // escribe solo el servidor; el cliente solo las lee.
  static const String conversationsCollection = 'conversations';
  static const String conversationContentsCollection = 'conversationContents';
  static const String memoryCollection = 'memory';
  static const String memoryProfileDoc = 'profile';
}
