import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'api_config.dart';
import 'meme_provider.dart';
import 'meme_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check auth state from local storage (persistence).
  String? savedUrl = await ApiConfig.getUrl();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MemeProvider()),
      ],
      child: MyApp(isLoggedIn: savedUrl != null),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meme Describer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Basic routing: if we have a URL, show the feed, otherwise show setup.
      home: isLoggedIn ? const HomeScreen() : const SetupScreen(),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  Future<void> _handleConnect() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    if (url.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both URL and Token')),
      );
      return;
    }

    await ApiConfig.saveSettings(url, token);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meme backend setup')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'Backend URL', hintText: 'https://api.example.com'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: 'Access Token'),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _handleConnect,
              child: const Text('Save & Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Pagination logic: trigger fetch near the bottom.
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        context.read<MemeProvider>().fetchNextPage();
      }
    });

    // Initial data fetch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MemeProvider>().fetchNextPage();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('This will clear your credentials. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiConfig.clearSettings();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meme Feed')),
      // endDrawer
      endDrawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Center(child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24))),
            ),
            ListTile(leading: const Icon(Icons.history), title: const Text('History'), onTap: () {}),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                _logout();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      body: Consumer<MemeProvider>(
        builder: (context, provider, _) {
          if (provider.memes.isEmpty && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.memes.isEmpty) {
            return const Center(child: Text('No memes found. Check your API settings.'));
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: provider.memes.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                // At the end of the list show a loader.
                if (index == provider.memes.length) {
                  return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                }
                return MemeCard(meme: provider.memes[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class MemeCard extends StatelessWidget {
  final Meme meme;
  const MemeCard({super.key, required this.meme});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedNetworkImage(
            imageUrl: meme.previewUrl,
            width: double.infinity,
            height: 250,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(meme.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    Icon(meme.type == MediaType.video ? Icons.play_circle_outline : Icons.image_outlined, color: Colors.grey),
                  ],
                ),
                if (meme.description != null) ...[
                  const SizedBox(height: 4),
                  Text(meme.description!, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}