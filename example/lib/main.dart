import 'package:flutter/material.dart';
import 'package:demo_rust_native_plugin/demo_rust_native_plugin.dart';

// Import the generated initialization
import 'package:demo_rust_native_plugin/src/rust/frb_generated.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Rust Bridge
  await RustLib.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _greeting = 'Press a button to call Rust!';
  String _fibonacci = '';
  String _addition = '';

  Future<void> _callGreet() async {
    final result = await greet(name: 'Flutter Developer');
    setState(() {
      _greeting = result;
    });
  }

  Future<void> _callFibonacci() async {
    final result = await calculateFibonacci(n: 20);
    setState(() {
      _fibonacci = 'Fibonacci(20) = $result';
    });
  }

  Future<void> _callAddition() async {
    final result = await addNumbers(a: 42, b: 13);
    setState(() {
      _addition = '42 + 13 = $result';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Rust Bridge Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange), useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Rust Native Plugin Demo'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.construction, size: 64, color: Colors.deepOrange),
                const SizedBox(height: 20),
                Text(_greeting, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(_fibonacci, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue)),
                const SizedBox(height: 8),
                Text(_addition, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green)),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _callGreet,
                      icon: const Icon(Icons.waving_hand),
                      label: const Text('Greet'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _callFibonacci,
                      icon: const Icon(Icons.calculate),
                      label: const Text('Fibonacci'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _callAddition,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Text('🦀 Powered by Rust + Flutter', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
