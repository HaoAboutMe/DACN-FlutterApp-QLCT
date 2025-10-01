import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool isGuest = user == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!isGuest)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context),
              tooltip: 'Sign Out',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        child: Text(
                          isGuest
                              ? 'G'
                              : (user.displayName?.isNotEmpty == true
                                  ? user.displayName![0].toUpperCase()
                                  : user.email?[0].toUpperCase() ?? 'U'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isGuest ? 'Welcome, Guest!' : 'Welcome!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (!isGuest && user.displayName?.isNotEmpty == true)
                              Text(
                                user.displayName!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (!isGuest && user.email != null)
                              Text(
                                'Signed in as: ${user.email}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                ),
                              ),
                            if (isGuest)
                              Text(
                                'You are browsing as a guest. Sign in to access all features.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Status Cards
            Expanded(
              child: Column(
                children: [
                  // Authentication Status Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        isGuest ? Icons.lock_open : Icons.verified_user,
                        color: isGuest ? Colors.orange[600] : Colors.green[600],
                      ),
                      title: Text(
                        isGuest ? 'Guest Mode' : 'Authenticated',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isGuest
                            ? 'Limited access to features'
                            : 'Full access to all features',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Provider Status Card (if authenticated)
                  if (!isGuest) ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          user.providerData.any((p) => p.providerId == 'google.com')
                              ? Icons.g_mobiledata
                              : Icons.email,
                          color: Colors.blue[600],
                        ),
                        title: Text(
                          user.providerData.any((p) => p.providerId == 'google.com')
                              ? 'Google Authentication'
                              : 'Email Authentication',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Authentication method used'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Firebase Status Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.cloud_done,
                        color: Colors.green[600],
                      ),
                      title: const Text(
                        'Firebase Connected',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Authentication service is active'),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            if (isGuest) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const AuthPage()),
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In to Access More Features'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
