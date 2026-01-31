class OffiboxApp extends StatelessWidget {
  const OffiboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OffiboxWindow(),
    );
  }
}
