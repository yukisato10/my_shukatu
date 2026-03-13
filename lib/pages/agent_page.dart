import 'package:flutter/material.dart';
import '../widgets/ad_scaffold.dart';

class AgentPage extends StatelessWidget {
  const AgentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdScaffold(
      body: SafeArea(
        child: Center(
          child: Text("COMING SOON..."),
        ),
      ),
    );
  }
}