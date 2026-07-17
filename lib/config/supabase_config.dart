/// Coordonnées du projet Supabase.
/// La clé "anon" est publique par conception : elle est distribuée avec l'app,
/// et la sécurité repose sur les policies RLS côté serveur.
class SupabaseConfig {
  static const String url = 'https://fjuquhbljkfxzvwdkkrh.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqdXF1aGJsamtmeHp2d2Rra3JoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzMDQzNjUsImV4cCI6MjA5OTg4MDM2NX0.wm0z1lHBb9LevGG6BgCPsf5tBLiNJdNceRfijh0PfGc';
}
