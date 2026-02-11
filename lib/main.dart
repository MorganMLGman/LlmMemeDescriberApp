import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
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
  bool _isConnecting = false;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    String url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    // 1. Basic validation
    if (url.isEmpty || token.isEmpty) {
      _showErrorModal('Input Required', 'Please enter both URL and Token');
      return;
    }

    // Ensure URL has a protocol
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showErrorModal('Invalid URL', 'URL must start with http:// or https://');
      return;
    }

    // Remove trailing slash to avoid double slashes like //health
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    setState(() => _isConnecting = true);

    try {
      // 2. Health check (Token is not needed for this endpoint as per requirements)
      final response = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 3. Verify the expected JSON structure
        if (data['status'] == 'ok') {
          // CONNECTION SUCCESSFUL!
          if (!mounted) return;

          // Show success modal
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'Connection Successful!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text('The backend is reachable and healthy.'),
                ],
              ),
            ),
          );

          await Future.delayed(const Duration(seconds: 2));
          await ApiConfig.saveSettings(url, token);

          if (!mounted) return;
          Navigator.pop(context); // Close Dialog
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
          return;
        }
      }

      _showErrorModal('Health Check Failed', 'The server responded, but the health check did not pass.');
    } on TimeoutException {
      _showErrorModal('Connection Timeout', 'The server took too long to respond. Check if the URL is correct and the server is running.');
    } catch (e) {
      _showErrorModal('Connection Error', 'Could not connect to the backend. Please check your network and the provided URL.');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _showErrorModal(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
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
              enabled: !_isConnecting,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://192.168.1.50:8000',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenController,
              enabled: !_isConnecting,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Access Token'),
            ),
            const SizedBox(height: 30),
            _isConnecting
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _handleConnect,
                    child: const Text('Verify & Connect'),
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
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        context.read<MemeProvider>().fetchNextPage();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<MemeProvider>();
      final token = await ApiConfig.getToken();
      provider.setToken(token);
      provider.fetchNextPage();
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
        context.read<MemeProvider>().reset();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meme Feed')),
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
                Navigator.pop(context);
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

          if (provider.errorMessage != null && provider.memes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: provider.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
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
                if (index == provider.memes.length) {
                  if (provider.errorMessage != null) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          children: [
                            Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 8),
                            TextButton(onPressed: provider.fetchNextPage, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    );
                  }
                  return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                }
                return MemeCard(meme: provider.memes[index], token: provider.token);
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
  final String? token;
  const MemeCard({super.key, required this.meme, this.token});

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
            httpHeaders: token != null ? {'Authorization': 'Bearer $token'} : {},
            width: double.infinity,
            height: 250,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
            errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 50),
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: [
                    if (meme.category != null)
                      Chip(
                        label: Text(meme.category!),
                        backgroundColor: Colors.blue[100],
                        labelStyle: const TextStyle(fontSize: 12),
                      ),
                    ...meme.keywords.map((keyword) => Chip(
                      label: Text(keyword),
                      backgroundColor: Colors.grey[200],
                      labelStyle: const TextStyle(fontSize: 12),
                    )),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
