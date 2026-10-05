import 'package:flutter/material.dart';
import '../app/tinni_state.dart';
import '../auth/auth_service.dart';
import '../infra/app_backend_service.dart';
import '../ui/royal_theme.dart';
class UniqueIdStoreScreen extends StatefulWidget { const UniqueIdStoreScreen({super.key,required this.state}); final TinniState state; @override State<UniqueIdStoreScreen> createState()=>_S(); }
class _S extends State<UniqueIdStoreScreen>{ bool loading=true; bool buying=false; List<Map<String,dynamic>> ids=const[]; String? error; @override void initState(){super.initState();load();}
Future<void> load() async {final t=widget.state.auth.current?.authToken;if(t==null||t.isEmpty){if(mounted)setState((){loading=false;error='Sign in to view Unique IDs.';});return;}try{final v=await widget.state.backend.uniqueIdCatalog(t);if(mounted)setState((){ids=v;loading=false;error=null;});}catch(e){if(mounted)setState((){loading=false;error=e.toString().replaceFirst('Bad state: ','');});}}
Future<void> buy(Map<String,dynamic> x)async{final t=widget.state.auth.current?.authToken;final id=x['public_id']?.toString()??'';if(t==null||t.isEmpty||id.isEmpty||buying)return;setState(()=>buying=true);try{final r=await widget.state.backend.purchaseUniqueId(t,id);final w=r['wallet'];if(w is Map){widget.state.wallet.applyRemote(RemoteWallet.fromServer(w.map((key,value)=>MapEntry(key.toString(),value))));}
final user=r['user'];if(user is Map&&widget.state.auth.current?.authToken==t){
final account=TinniAccount.fromServer(user.map((key,value)=>MapEntry(key.toString(),value)),token:t);
widget.state.auth.setAuthenticatedAccount(account);
widget.state.profile.loadFromAccount(account);
await widget.state.authPersistence?.save(account);
}
if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Unique ID '+id+' activated.')));await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Bad state: ',''))));}finally{if(mounted)setState(()=>buying=false);}}
@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Unique ID Store',style:TextStyle(color:FeaturePalette.vip,fontWeight:FontWeight.w900))),body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(14),children:[if(error!=null)Text(error!,style:const TextStyle(color:Colors.redAccent)),for(final x in ids)Padding(padding:const EdgeInsets.only(bottom:10),child:RoyalPanel(child:ListTile(leading:const Icon(Icons.numbers_rounded),title:Text(x['public_id']?.toString()??'',style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(((x['price_coins'] as num?)?.toInt()??0).toString()+' coins • '+(x['permanent']==true?'Permanent':((x['duration_days'] as num?)?.toInt()??0).toString()+' days')),trailing:x['available']==false?const Text('Taken'):FilledButton(onPressed:buying?null:()=>buy(x),child:const Text('Buy'))))),if(ids.isEmpty&&error==null)const RoyalPanel(child:Text('No Unique IDs are available right now.'))])));}
