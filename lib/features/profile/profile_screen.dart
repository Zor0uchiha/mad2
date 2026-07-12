import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/user_model.dart";
import "../../data/services/auth_service.dart";

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: FutureBuilder<UserModel?>(
        future: authService.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_rounded, size: 64),
                  const SizedBox(height: 16),
                  TextButton.icon(onPressed: () => context.push("/auth"), icon: const Icon(Icons.login_rounded), label: const Text("Login / Sign Up")),
                ],
              ),
            );
          }

          return ListView(
            children: [
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? const Icon(Icons.person_rounded, size: 48) : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(user.displayName ?? "Anonymous", style: Theme.of(context).textTheme.headlineSmall)),
              Center(child: Text(user.email, style: Theme.of(context).textTheme.bodyMedium)),
              const SizedBox(height: 24),
              ListTile(title: const Text("Books Read"), trailing: const Text("0")),
              ListTile(title: const Text("Currently Reading"), trailing: const Text("0")),
              ListTile(title: const Text("Want to Read"), trailing: const Text("0")),
              ListTile(title: const Text("Reviews"), trailing: const Text("0")),
              ListTile(title: const Text("Reading Streak"), trailing: const Text("0 days")),
              const Divider(),
              ListTile(title: const Text("Reading Calendar"), trailing: const Icon(Icons.calendar_month_rounded), onTap: () {}),
              ListTile(title: const Text("Reading Lists"), trailing: const Icon(Icons.list_rounded), onTap: () {}),
              ListTile(title: const Text("Collections"), trailing: const Icon(Icons.folder_rounded), onTap: () => context.push(AppConstants.routeCollections)),
              const Divider(),
              ListTile(title: const Text("Privacy"), subtitle: const Text("Public Profile"), trailing: Switch(value: user.isPublicProfile, onChanged: (v) {})),
              ListTile(title: const Text("Export Data"), trailing: const Icon(Icons.download_rounded), onTap: () {}),
              ListTile(title: const Text("Delete Account"), trailing: const Icon(Icons.delete_forever_rounded, color: Colors.red), onTap: () {}),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go(AppConstants.routeHome);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text("Logout"),
              ),
            ],
          );
        },
      ),
    );
  }
}
}
