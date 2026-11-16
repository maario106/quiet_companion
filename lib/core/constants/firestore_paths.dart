class FirestorePaths {
  const FirestorePaths._();

  static const String usersCollection = 'users';

  // Subcolecciones de users/{elderId}; solo las escribe el servidor.
  static const String conversationsCollection = 'conversations';
  static const String conversationContentsCollection = 'conversationContents';
  static const String memoryCollection = 'memory';
  static const String memoryProfileDoc = 'profile';
}
