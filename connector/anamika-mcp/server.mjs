import express from "express";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";

const __dirname=path.dirname(fileURLToPath(import.meta.url));
const PORT=Number(process.env.PORT||3000);
const DATA_DIR=process.env.ANAMIKA_CONNECTOR_DATA||path.join(__dirname,"data");
const STATE_FILE=path.join(DATA_DIR,"state.json");
const PAIRING_CODE=String(process.env.ANAMIKA_PAIRING_CODE||"");
const MCP_TOKEN=String(process.env.ANAMIKA_MCP_TOKEN||"");

fs.mkdirSync(DATA_DIR,{recursive:true});

function emptyState(){ return {devices:{},commands:{},results:[]}; }
function loadState(){
  try{ return JSON.parse(fs.readFileSync(STATE_FILE,"utf8")); }catch{return emptyState();}
}
function saveState(state){
  const tmp=STATE_FILE+".tmp";
  fs.writeFileSync(tmp,JSON.stringify(state,null,2));
  fs.renameSync(tmp,STATE_FILE);
}
function sha256(s){ return crypto.createHash("sha256").update(String(s)).digest("hex"); }
function now(){ return Date.now(); }
function randomToken(){ return crypto.randomBytes(32).toString("base64url"); }
function randomId(prefix){ return prefix+"_"+crypto.randomUUID(); }
function bearer(req){
  const h=String(req.headers.authorization||"");
  return h.toLowerCase().startsWith("bearer ")?h.slice(7).trim():"";
}
function textResult(obj,isError=false){
  return {content:[{type:"text",text:typeof obj==="string"?obj:JSON.stringify(obj,null,2)}],isError};
}
function newestDevice(state,deviceId){
  if(deviceId&&state.devices[deviceId]) return state.devices[deviceId];
  const all=Object.values(state.devices);
  all.sort((a,b)=>(b.last_seen_ms||0)-(a.last_seen_ms||0));
  return all[0]||null;
}
function authMcp(req,res,next){
  if(!MCP_TOKEN) return res.status(503).json({error:"ANAMIKA_MCP_TOKEN is not configured"});
  if(bearer(req)!==MCP_TOKEN) return res.status(401).json({error:"unauthorized"});
  next();
}
function authDevice(req,res,next){
  const id=String(req.headers["x-anamika-device"]||"");
  const token=bearer(req);
  const state=loadState();
  const d=state.devices[id];
  if(!d||!token||d.token_hash!==sha256(token)) return res.status(401).json({error:"device unauthorized"});
  d.last_seen_ms=now();
  saveState(state);
  req.anamikaDeviceId=id;
  next();
}

function registerTools(server){
  server.registerTool("anamika_status",{
    description:"Read Anamika phone connector state and whether the paired device is online.",
    inputSchema:z.object({device_id:z.string().optional()}),
    annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true}
  },async({device_id})=>{
    const state=loadState();
    const d=newestDevice(state,device_id);
    if(!d) return textResult({connected:false,message:"No Anamika device paired yet."});
    return textResult({
      connected:true,
      device_id:d.device_id,
      device_name:d.device_name,
      last_seen_ms:d.last_seen_ms||0,
      online:(now()-(d.last_seen_ms||0))<15000,
      pending:Object.values(state.commands).filter(c=>c.device_id===d.device_id&&["queued","delivered"].includes(c.status)).length
    });
  });

  server.registerTool("send_anamika_command",{
    description:"Send an owner-approved command or question to the paired Anamika Android app. This queues a command for the phone; Android permissions and owner controls still apply.",
    inputSchema:z.object({
      command:z.string().min(1).max(48000),
      device_id:z.string().optional(),
      wait_seconds:z.number().int().min(0).max(20).optional()
    }),
    annotations:{readOnlyHint:false,destructiveHint:false,idempotentHint:false}
  },async({command,device_id,wait_seconds=10})=>{
    const state=loadState();
    const d=newestDevice(state,device_id);
    if(!d) return textResult({ok:false,error:"No paired Anamika device."},true);
    const id=randomId("cmd");
    state.commands[id]={id,device_id:d.device_id,command,status:"queued",created_ms:now(),delivered_ms:0,completed_ms:0,result:""};
    saveState(state);
    const deadline=now()+wait_seconds*1000;
    while(wait_seconds>0&&now()<deadline){
      await new Promise(r=>setTimeout(r,500));
      const fresh=loadState();
      const c=fresh.commands[id];
      if(c&&c.status==="completed") return textResult({ok:true,command_id:id,status:c.status,result:c.result});
    }
    return textResult({ok:true,command_id:id,status:"queued_or_running",message:"Command queued. Use get_anamika_result with this command_id if the result is not ready yet."});
  });

  server.registerTool("get_anamika_result",{
    description:"Get the result of a command previously sent to Anamika.",
    inputSchema:z.object({command_id:z.string().min(1)}),
    annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true}
  },async({command_id})=>{
    const state=loadState();
    const c=state.commands[command_id];
    if(!c) return textResult({ok:false,error:"Unknown command_id"},true);
    return textResult({ok:true,command_id,status:c.status,result:c.result||"",created_ms:c.created_ms,completed_ms:c.completed_ms||0});
  });

  server.registerTool("recent_anamika_results",{
    description:"Read a small list of recent completed Anamika connector results.",
    inputSchema:z.object({limit:z.number().int().min(1).max(20).optional()}),
    annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true}
  },async({limit=10})=>{
    const state=loadState();
    const done=Object.values(state.commands).filter(c=>c.status==="completed").sort((a,b)=>(b.completed_ms||0)-(a.completed_ms||0)).slice(0,limit);
    return textResult(done.map(c=>({command_id:c.id,command:c.command,result:c.result,completed_ms:c.completed_ms})));
  });
}

function createMcpServer(){
  const server=new McpServer(
    {name:"anamika-ai-13",version:"1.0.0"},
    {instructions:"Use anamika_status before sending device actions when state matters. send_anamika_command queues a command on the owner-paired Android device. Never claim completion until the tool returns a result or get_anamika_result reports completed. Android permission and owner confirmation remain authoritative."}
  );
  registerTools(server);
  return server;
}

const app=express();
app.disable("x-powered-by");
app.use(express.json({limit:"2mb"}));

app.get("/health",(req,res)=>res.json({ok:true,name:"anamika-ai-13-mcp",time_ms:now()}));

app.post("/device/pair",(req,res)=>{
  if(!PAIRING_CODE) return res.status(503).json({error:"ANAMIKA_PAIRING_CODE is not configured"});
  const code=String(req.body?.pairing_code||"");
  if(code!==PAIRING_CODE) return res.status(403).json({error:"pairing code rejected"});
  const deviceId=String(req.body?.device_id||"").trim()||randomId("device");
  const deviceName=String(req.body?.device_name||"Anamika Android").slice(0,120);
  const token=randomToken();
  const state=loadState();
  state.devices[deviceId]={device_id:deviceId,device_name:deviceName,token_hash:sha256(token),paired_ms:now(),last_seen_ms:now()};
  saveState(state);
  res.json({ok:true,device_id:deviceId,device_token:token});
});

app.get("/device/commands/next",authDevice,(req,res)=>{
  const state=loadState();
  const id=req.anamikaDeviceId;
  const list=Object.values(state.commands)
    .filter(c=>c.device_id===id&&(c.status==="queued"||(c.status==="delivered"&&now()-(c.delivered_ms||0)>60000)))
    .sort((a,b)=>a.created_ms-b.created_ms);
  const c=list[0];
  if(!c) return res.json({ok:true,command:null});
  c.status="delivered"; c.delivered_ms=now(); saveState(state);
  res.json({ok:true,command:{id:c.id,text:c.command}});
});

app.post("/device/results",authDevice,(req,res)=>{
  const id=String(req.body?.command_id||"");
  const result=String(req.body?.result||"");
  const state=loadState();
  const c=state.commands[id];
  if(!c||c.device_id!==req.anamikaDeviceId) return res.status(404).json({error:"command not found"});
  c.status="completed"; c.result=result.slice(0,200000); c.completed_ms=now();
  saveState(state);
  res.json({ok:true});
});

async function handleMcp(req,res){
  const server=createMcpServer();
  const transport=new StreamableHTTPServerTransport({sessionIdGenerator:undefined});
  res.on("close",()=>{try{transport.close();}catch{} try{server.close();}catch{}});
  await server.connect(transport);
  await transport.handleRequest(req,res,req.body);
}
app.post("/mcp",authMcp,(req,res)=>handleMcp(req,res).catch(e=>{if(!res.headersSent)res.status(500).json({error:String(e)});}));
app.get("/mcp",authMcp,(req,res)=>handleMcp(req,res).catch(e=>{if(!res.headersSent)res.status(500).json({error:String(e)});}));
app.delete("/mcp",authMcp,(req,res)=>handleMcp(req,res).catch(e=>{if(!res.headersSent)res.status(500).json({error:String(e)});}));

app.listen(PORT,"0.0.0.0",()=>{
  console.log(`Anamika MCP connector listening on :${PORT}`);
  if(!PAIRING_CODE) console.warn("ANAMIKA_PAIRING_CODE missing; device pairing disabled.");
  if(!MCP_TOKEN) console.warn("ANAMIKA_MCP_TOKEN missing; /mcp disabled.");
});
