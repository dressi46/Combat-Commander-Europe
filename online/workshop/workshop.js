import {rollScenario, posture, hand, depth, leaders, eligible} from "./rules.js";
const $ = id => document.getElementById(id);
const language = new URLSearchParams(location.search).get("lang") || localStorage.getItem("cc.lang") || navigator.language.slice(0,2);
const languages=await (await fetch("languages.json")).json();
// The game and the native launcher both pass the active profile to the workshop.
const builtins = new Set(Object.keys(languages));
function validProfile(p) {
  return p && builtins.has(p.base) && typeof p.name==="string" && p.name.length<=48
    && (p.code===p.base || /^x-[a-f0-9]{12}$/.test(p.code))
    && p.overrides && typeof p.overrides==="object" && !Array.isArray(p.overrides);
}
const profiles = new Map();
try {
  for (const entry of JSON.parse(localStorage.getItem("cc.languageProfiles") || "[]")) {
    if(validProfile(entry)) profiles.set(entry.code,entry);
  }
} catch { /* Use the shipped catalog when browser storage is unavailable. */ }
const incoming = new URLSearchParams(location.hash.slice(1)).get("language");
if(incoming){
  try {
    const entry = JSON.parse(incoming);
    if(validProfile(entry) && entry.code===language){
      profiles.set(entry.code,entry);
      localStorage.setItem("cc.languageProfiles",JSON.stringify([...profiles.values()]));
    }
  } catch { /* The incoming profile remains usable for the current session. */ }
  history.replaceState(null,"",location.pathname+location.search);
}
for(const [code,profile] of profiles) if(!builtins.has(code)) languages[code]=profile.name;
const lang = Object.hasOwn(languages,language)?language:"en";
const profile = profiles.get(lang);
const languageOptions=Object.entries(languages);
$("language").replaceChildren(...languageOptions.map(([code,name])=>new Option(name,code)));
const data = await (await fetch("data.json")).json();
const formations = await (await fetch("formations.json")).json();
const messages = await (await fetch((profile?.base || lang)+".json")).json();
if(profile) for(const [key,value] of Object.entries(profile.overrides)){
  if(Object.hasOwn(messages,key) && typeof value==="string") messages[key]=value;
}
const t = key => messages[key] || key;
document.documentElement.lang=lang;
document.title=t("Workshop")+" · Combat Commander";
document.querySelectorAll("[data-t]").forEach(el=>el.textContent=t(el.textContent));
$("language").value=lang;
$("language").onchange=()=>{ localStorage.setItem("cc.lang",$("language").value); location.search="?lang="+$("language").value; };
const status = message => $("status").textContent=message;
function action(fn) {return async event=>{try {await fn(event);}catch(error){status(t("Could not complete the operation")+" · "+error.message);}};}
function el(tag,text,parent){const node=document.createElement(tag);if(text)node.textContent=text;if(parent)parent.append(node);return node;}
function button(parent,key,fn){const b=el("button",t(key),parent);b.type="button";b.onclick=action(fn);return b;}
function option(input,value,caption){input.add(new Option(caption,value));}
function field(parent,id,caption,options,min,max){
  const label=el("label","",parent);el("span",t(caption),label);
  const input=el(options?"select":"input","",label);input.id=id;
  if(options) for(const [value,name] of options) option(input,value,t(name));
  else {input.type="number";input.min=min;input.max=max;input.required=true;input.value=min;}
  return input;
}
const range=(n)=>Array.from({length:n},(_,i)=>[i+1,String(i+1)]);
const pairs=list=>list.map(v=>[v,v]);
const sides=["axis","allies"], nations={axis:["german","italian"],allies:["russian","american","british","french"]};
const number=id=>Number($(id).value);
let current,rollInfo,filesVersion=0;
function tab(mission){$("missions").hidden=!mission;$("cards").hidden=mission;
  $("missionTab").setAttribute("aria-pressed",mission);$("cardTab").setAttribute("aria-pressed",!mission);status("");}
$("missionTab").onclick=()=>tab(true);$("cardTab").onclick=()=>tab(false);tab(true);
field($("settings"),"map","Map",range(24));
field($("settings"),"year","Year",null,1939,1945);
field($("settings"),"edge","Axis edge",[[0,"East"],[1,"South"],[2,"North"],[3,"West"]]);
field($("settings"),"initiative","Initiative",pairs(sides));
field($("settings"),"human","Play as",pairs(sides));
function addForce(side,type,count=1){
  const list=$(side+"Forces"),nation=$(side+"Nation").value;
  const row=el("div","",list);row.className="force";
  const unit=el("select","",row);unit.setAttribute("aria-label",t("Unit"));
  const choices=new Set(data[nation]);if(type)choices.add(type);
  for(const name of choices)option(unit,name,t(name));unit.value=type||data[nation][0];
  const amount=el("input","",row);Object.assign(amount,{type:"number",min:1,max:30,value:count,required:true});amount.setAttribute("aria-label",t("Quantity"));
  button(row,"Remove",()=>row.remove());
}
for(const side of sides){
  const box=el("fieldset","",$("teams"));el("legend",t(side),box);
  const ns=field(box,side+"Nation","Nation",pairs(nations[side]));
  field(box,side+"Quality","Troop quality",pairs(["Elite","Line","Green"]));
  const ob=field(box,side+"OB","Formation",[]);
  ob.onchange=()=>applyFormation(side);
  field(box,side+"Initiative","OB initiative",null,-20,30);
  field(box,side+"Cost","Order of battle cost (VP)",null,0,99);
  field(box,side+"Support","Support cost (VP)",null,0,99);
  field(box,side+"Extra","Fortifications or radio (VP)",null,0,99);
  field(box,side+"Orders","Orders",null,1,6);
  field(box,side+"Surrender","Surrender",null,1,30);
  const links=el("div","",box);links.className="row";
  function references(){
    links.replaceChildren();
    for(const [label,path] of [["Order of battle",ns.value+"-ob"],["Support table",ns.value+"-support"],["Leaders","leaders"]]){
      const a=el("a",t(label),links);a.href="charts/"+path+".jpg";a.target="_blank";a.rel="noopener";
    }
  }
  ns.addEventListener("change",references);references();
  const diceOut=el("output","",box);
  const purchase=el("div","",box);
  const supportChoices=field(purchase,side+"SupportChoice","Available purchases",[]);
  const points=field(purchase,side+"Price","Price from the support table",null,1,99);
  let candidates=[];
  function rollSupport(){
    const white=1+Math.floor(Math.random()*6), colored=1+Math.floor(Math.random()*6);
    diceOut.textContent=t("White")+" "+white+" · "+t("Colored")+" "+colored;
    const nation=ns.value, year=number("year");
    candidates=data.support[nation].filter(item=>(item.col[white+colored]||[]).some(([lo,hi])=>lo<=year && year<=hi));
    supportChoices.replaceChildren();
    for(const [i,item] of candidates.entries())option(supportChoices,i,[item.unita,item.arma].filter(Boolean).map(t).join(" + "));
    purchase.hidden=false;
  }
  purchase.hidden=true;
  ns.addEventListener("change",()=>{purchase.hidden=true;});
  $("year").addEventListener("change",()=>{purchase.hidden=true;});
  button(purchase,"Add purchase",()=>{
    const item=candidates[supportChoices.value];if(!item||!points.reportValidity())return;
    for(const type of [item.unita,item.arma].filter(Boolean))addForce(side,type);
    const cost=$(side+(item.tipo==="radio"?"Extra":"Support"));cost.value=Number(cost.value)+Number(points.value);
    calculate();
  });
  button(box,"Roll support / leader dice",rollSupport);
  const group=el("div","",box);group.id=side+"Forces";button(box,"Add unit",()=>addForce(side));
  ns.onchange=()=>{group.replaceChildren();addForce(side);refreshFormations();};
  $(side+"Quality").onchange=refreshFormations;
}
function refreshFormations(){
  for(const side of sides){
    const select=$(side+"OB");if(!select || !$("alliesNation"))continue;
    const previous=select.value,nation=$(side+"Nation").value;
    select.replaceChildren();option(select,"",t("Custom forces"));
    for(const [code,row] of Object.entries(formations[nation])){
      if(!eligible(nation,code,row,number("year"),$(side+"Quality").value,$("alliesNation").value))continue;
      ["Company","Detachment","Platoon"].forEach((size,index)=>{
        option(select,code+index,code+" · "+t(size)+" · "+row.cost[index]+" VP");
      });
    }
    if([...select.options].some(o=>o.value===previous))select.value=previous;
  }
}
function applyFormation(side){
  const choice=$(side+"OB").value;if(!choice)return;
  const nation=$(side+"Nation").value,year=number("year");
  const row=formations[nation][choice[0]],index=Number(choice[1]);
  for(const [field,values] of Object.entries({Cost:row.cost,Orders:row.orders,Initiative:row.initiative,Surrender:row.surrender}))$(side+field).value=values[index];
  $(side+"Support").value=0;$(side+"Extra").value=0;
  $(side+"Forces").replaceChildren();
  for(const leader of leaders(nation,year,row.quality,row.leaders[index]))addForce(side,leader,1);
  const forces={...row.forces};
  if(nation==="german" && choice[0]==="F")forces[year<=1943?"Light Mortar":"Medium Mortar"]=year<=1943?[3,0,0]:[2,0,0];
  if(nation==="british" && choice[0]==="S"){
    forces["Light Mortar"]=year===1943?[0,0,1]:[3,2,1];
    if(year===1943)forces["Medium Mortar"]=[2,1,0];
  }
  for(const [type,counts] of Object.entries(forces))if(counts[index])addForce(side,type,counts[index]);
  calculate();
}
$("year").onchange=refreshFormations;
function calculate(){
  const obDiff=number("alliesCost")-number("axisCost");
  const diff=obDiff+number("alliesSupport")-number("axisSupport");
  const initiative=number("axisInitiative")-number("alliesInitiative");
  $("initiative").disabled=initiative!==0;
  if(initiative)$("initiative").value=initiative>0?"axis":"allies";
  const vp=diff+number("alliesExtra")-number("axisExtra");
  $("balance").textContent=sides.map(side=>t(side)+" · "+t(posture(diff,side))).join(" / ")+" · VP "+vp+" · "+t("Sudden death")+" "+(number("axisOrders")+number("alliesOrders"));
  return {diff,vp};
}
$("editor").oninput=calculate;
function savedList(){
  const select=$("saved");select.replaceChildren();option(select,"",t("New mission"));
  for(const key of Object.keys(localStorage).filter(k=>/^cc\.mission\.\d+$/.test(k))){
    const m=JSON.parse(localStorage[key]);option(select,m.numero,m.nome);
  }
  select.value=current||"";
}
function showRoll(){
  $("rollResult").textContent=rollInfo?t("Map choice: player")+" "+rollInfo.chooser+" · "+t("Axis player")+" "+rollInfo.axisPlayer+" · "+t("Edge dice")+" "+rollInfo.edges.join(" / ")+". "+t("Other player chooses a die: 1 north, 2–3 east, 4 south, 5–6 west. Enter the corresponding Axis edge."):"";
}
function loadMission(id){
  const m=id?JSON.parse(localStorage["cc.mission."+id]):{};current=id?Number(id):null;
  $("title").value=m.nome||"";$("map").value=(m.mappa||"map1").slice(3);
  $("year").value=m.anno||1941;$("edge").value=m.edge_mode??0;$("initiative").value=m.iniziativa||"axis";$("human").value=m.human||"axis";
  rollInfo=m.rollInfo;showRoll();
  for(const side of sides){$(side+"Nation").value=m["fazione_"+side]||nations[side][0];
    $(side+"Nation").dispatchEvent(new Event("change"));
    $(side+"Quality").value=m["quality_"+side]||"Line";
    for(const [id,key,def] of [["Initiative","initiative_rating",0],["Support","support",0],["Orders","ordini",2],["Surrender","resa",6],["Cost","cost",0],["Extra","extra",0]])$(side+id).value=m[key+"_"+side]??def;
    $(side+"Forces").replaceChildren();
    for(const f of m["forze_"+side]||[{n:3}])addForce(side,f.tipo,f.n);
  }
  refreshFormations();
  for(const side of sides)$(side+"OB").value=m["ob_"+side]||"";
  savedList();calculate();showDocuments().catch(e=>status(e.message));
}
$("saved").onchange=()=>loadMission($("saved").value);$("newMission").onclick=()=>loadMission("");
$("roll").onclick=()=>{
  rollInfo=rollScenario();$("year").value=rollInfo.year;
  for(const side of sides){$(side+"Nation").value=rollInfo[side];$(side+"Nation").dispatchEvent(new Event("change"));$(side+"Quality").value=rollInfo[side+"Quality"];}
  refreshFormations();
  for(const side of sides){const ob=$(side+"OB");if(ob.options.length>1){ob.selectedIndex=1;applyFormation(side);}}
  showRoll();calculate();
};
function save(){
  if(!$("editor").reportValidity())return false;
  const {diff,vp}=calculate();
  const m={numero:current||Date.now(),nome:$("title").value.trim(),mappa:"map"+number("map"),anno:number("year"),edge_mode:number("edge"),iniziativa:$("initiative").value,human:$("human").value,vp_iniziali:vp,tempo_iniziale:0,sudden_death:number("axisOrders")+number("alliesOrders"),rollInfo};
  if(m.sudden_death<3)throw Error(t("The combined order allowance must be at least three"));
  if(rollInfo){
    const obDiff=number("alliesCost")-number("axisCost");
    const first=obDiff>0?"axis":"allies", other=first==="axis"?"allies":"axis";
    if(!obDiff && (number("axisSupport")||number("alliesSupport")))throw Error(t("Equal OB costs skip the support step"));
    if(obDiff && (!number(first+"Support") || (number(first+"Support")<=Math.abs(obDiff) && number(other+"Support"))))throw Error(t("Check support purchases in RS.7"));
    if(diff===0 && (number("axisExtra")||number("alliesExtra")))throw Error(t("Recon sides cannot purchase fortifications or a radio"));
    const defender=diff>0?"axis":"allies";
    if(diff && number(defender+"Extra")>Math.abs(diff))throw Error(t("Fortification cost exceeds the defender’s VP"));
  }
  if(!m.nome)throw Error(t("Enter a mission name"));
  for(const side of sides){
    const role=posture(diff,side);
    for(const [key,val] of Object.entries({posture:role,mano:hand(role),ob:$(side+"OB").value,quality:$(side+"Quality").value,fazione:$(side+"Nation").value,ordini:number(side+"Orders"),resa:number(side+"Surrender"),cost:number(side+"Cost"),extra:number(side+"Extra"),initiative_rating:number(side+"Initiative"),support:number(side+"Support")}))m[key+"_"+side]=val;
    m["setup_"+side+"_depth"]=depth(role,m.edge_mode);
    const forces=[...$(side+"Forces").children].map(row=>({tipo:row.querySelector("select").value,n:Number(row.querySelector("input").value)}));
    if(!forces.some(f=>data.troops[m["fazione_"+side]].includes(f.tipo)))throw Error(t("Add troops to both sides"));
    m["forze_"+side]=forces;
  }
  localStorage.setItem("cc.mission."+m.numero,JSON.stringify(m));current=m.numero;savedList();status(t("Mission saved"));return true;
}
$("editor").onsubmit=action(e=>{e.preventDefault();save();});
$("play").onclick=action(()=>{if(save())location.assign("../?mission="+current);});
const db=window.CCArt.access;
const validFile=f=>f && f.size<=32*1024*1024 && ["image/jpeg","image/png","image/webp","application/pdf"].includes(f.type);
let urls=[];
async function showDocuments(){
  const version=++filesVersion,id=current;
  const entries=id?(await db("files",s=>s.getAllKeys())).filter(k=>String(k).startsWith(id+"/")):[];
  const rows=[];
  for(const key of entries)rows.push([key,await db("files",s=>s.get(key))]);
  if(version!==filesVersion)return;
  urls.forEach(URL.revokeObjectURL);urls=[];$("documents").replaceChildren();
  for(const [key,f] of rows){
    const row=el("div","",$("documents")),a=el("a",f.name,row);
    a.href=URL.createObjectURL(f);urls.push(a.href);a.target="_blank";a.rel="noopener";
    button(row,"Remove",async()=>{await db("files",s=>s.delete(key),true);await showDocuments();});
  }
}
$("attachments").onchange=action(async()=>{
  const files=[...$("attachments").files];if(!files.every(validFile))throw Error(t("Choose a PDF, JPEG, PNG or WebP up to 32 MB"));
  if(!save())return;const id=current;
  for(const f of files)await db("files",s=>s.put(f,id+"/"+crypto.randomUUID()),true);
  $("attachments").value="";await showDocuments();status(t("Documents saved"));
});
field($("cardFields"),"deck","Deck",pairs([...nations.axis,...nations.allies]));
field($("cardFields"),"card","Card number",null,1,72);
field($("cardFields"),"artLang","Illustration language",languageOptions).value=lang;
for(const [id,key,max] of [["page","PDF page",1],["cols","Columns",12],["rows","Rows",12],["cell","Cell (from top left)",1]])field($("crop"),id,key,null,1,max);
let raster=null,pdf=null,version=0,pdfjs;
async function render(){
  const turn=++version;$("importFace").disabled=true;$("face").hidden=true;
  $("cell").max=number("cols")*number("rows");
  if(![...$("crop").querySelectorAll("input")].every(i=>i.checkValidity()))return;
  let src=raster;
  if(pdf){
    const page=await pdf.getPage(number("page"));const size=page.getViewport({scale:1});
    const vp=page.getViewport({scale:Math.min(3,2400/Math.max(size.width,size.height))});
    src=document.createElement("canvas");src.width=Math.ceil(vp.width);src.height=Math.ceil(vp.height);
    await page.render({canvasContext:src.getContext("2d"),viewport:vp}).promise;
  }
  if(!src||turn!==version)return;
  const w=src.width/number("cols"),h=src.height/number("rows"),cell=number("cell")-1,scale=Math.min(1,720/Math.max(w,h));
  const canvas=$("face");canvas.width=Math.max(1,Math.round(w*scale));canvas.height=Math.max(1,Math.round(h*scale));
  const ctx=canvas.getContext("2d");ctx.fillStyle="white";ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(src,(cell%number("cols"))*w,Math.floor(cell/number("cols"))*h,w,h,0,0,canvas.width,canvas.height);
  canvas.hidden=false;$("importFace").disabled=false;
}
let fileVersion=0;
$("source").onchange=action(async()=>{
  const turn=++fileVersion;++version;$("face").hidden=true;$("importFace").disabled=true;
  const file=$("source").files[0];raster?.close();raster=null;if(pdf){pdf.destroy();pdf=null;}
  if(!validFile(file))throw Error(t("Choose a PDF, JPEG, PNG or WebP up to 32 MB"));
  if(file.type==="application/pdf"){
    pdfjs ||= await import("./vendor/pdf.min.mjs");pdfjs.GlobalWorkerOptions.workerSrc="./vendor/pdf.worker.min.mjs";
    const doc=await pdfjs.getDocument({data:await file.arrayBuffer(),isEvalSupported:false}).promise;
    if(turn!==fileVersion){doc.destroy();return;}pdf=doc;
  }else{const img=await createImageBitmap(file);if(turn!==fileVersion){img.close();return;}raster=img;}
  $("page").max=pdf?.numPages||1;$("page").value=1;await render();
});
$("crop").onchange=action(render);
async function listFaces(){
  const keys=await db("faces",s=>s.getAllKeys());$("imported").replaceChildren();
  for(const k of keys){const row=el("div","",$("imported"));el("span",k,row);
    button(row,"Remove",async()=>{await db("faces",s=>s.delete(k),true);await listFaces();});}
}
$("importFace").onclick=action(async()=>{
  if(!$("card").reportValidity()||$("face").hidden)return;
  const key=$("artLang").value+"/"+$("deck").value+"-"+number("card");
  const encoded=$("face").toDataURL("image/jpeg",.88).split(",")[1];
  await db("faces",s=>s.put(encoded,key),true);await listFaces();status(t("Illustration saved"));
});
loadMission("");listFaces().catch(e=>status(e.message));
