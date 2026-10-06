import 'package:flutter/material.dart';
import '../app/tinni_state.dart';
import 'relationship_ranking_screen.dart';

class CpRankingScreen extends StatelessWidget {
  const CpRankingScreen({super.key,required this.state});
  final TinniState state;
  @override
  Widget build(BuildContext context)=>RelationshipRankingScreen(state:state);
}
