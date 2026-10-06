import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/tinni_state.dart';
import '../ui/relationship_visuals.dart';

class RelationshipRankingScreen extends StatefulWidget {
  const RelationshipRankingScreen({super.key,required this.state,this.rivalry=false});
  final TinniState state;
  final bool rivalry;
  @override
  State<RelationshipRankingScreen> createState()=>_RelationshipRankingScreenState();
}
class _RelationshipRankingScreenState extends State<RelationshipRankingScreen> {
  List<Map<String,dynamic>> rows=[];
  bool loading=true;
  String? error;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    final account=widget.state.auth.current;
    if(account==null){if(mounted)setState((){loading=false;error='Login required';});return;}
    try {
      final result=widget.rivalry?await widget.state.backend.vsRanking(account.authToken)
        :await widget.state.backend.cpRanking(account.authToken);
      if(mounted)setState((){rows=result;loading=false;error=null;});
    }catch(e){if(mounted)setState((){loading=false;error=widget.state.backend.userSafeError(e);});}
  }
  ImageProvider? avatar(dynamic source) {
    final text=source?.toString()??'';
    if(text.startsWith('data:image/')){try{return MemoryImage(base64Decode(text.split(',').last));}catch(_){return null;}}
    return text.startsWith('https://')?NetworkImage(text):null;
  }
  @override
  Widget build(BuildContext context) {
    final label=widget.rivalry?'VS':'CP';
    final color=widget.rivalry?const Color(0xFFFF3549):const Color(0xFFFFAFCC);
    return Scaffold(key:Key(widget.rivalry?'vs-ranking-screen':'cp-ranking-screen'),
      backgroundColor:widget.rivalry?const Color(0xFF080910):null,
      appBar:AppBar(title:Text('$label Ranking',style:TextStyle(color:color))),
      body:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
        if(loading)const Center(child:CircularProgressIndicator()),
        if(error!=null) ...[Text(error!),TextButton(onPressed:_load,child:const Text('Retry'))],
        if(!loading&&error==null&&rows.isEmpty)Text('No active $label pairs yet.'),
        for(final row in rows) Card(color:widget.rivalry?const Color(0xFF201223):const Color(0xFF401329),
          child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
            Row(children:[
              Text('#${row["rank"]}',style:TextStyle(color:color,fontSize:24,fontWeight:FontWeight.w900)),
              const SizedBox(width:12),
              Expanded(child:Column(children:[
                CircleAvatar(backgroundImage:avatar(row['user_a_avatar']),child:const Icon(Icons.person)),
                Text(row['user_a_name']?.toString()??row['user_a'].toString(),maxLines:1,overflow:TextOverflow.ellipsis),
                Text('ID ${row["user_a"]}',style:const TextStyle(fontSize:10)),
              ])),
              Icon(widget.rivalry?Icons.bolt_rounded:Icons.favorite_rounded,color:color),
              Expanded(child:Column(children:[
                CircleAvatar(backgroundImage:avatar(row['user_b_avatar']),child:const Icon(Icons.person)),
                Text(row['user_b_name']?.toString()??row['user_b'].toString(),maxLines:1,overflow:TextOverflow.ellipsis),
                Text('ID ${row["user_b"]}',style:const TextStyle(fontSize:10)),
              ])),
            ]),
            const SizedBox(height:12),
            RelationshipBadge(level:int.tryParse(row['level'].toString())??1,rivalry:widget.rivalry),
            Text('${row[widget.rivalry?"rivalry":"intimacy"]} confirmed progress'),
          ]))),
      ])));
  }
}
