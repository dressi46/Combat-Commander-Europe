// RS.2–RS.3. Table entries are indexed by the sum of the white and colored dice.
export function rollScenario(die = () => 1 + Math.floor(Math.random() * 6)) {
  const roll = () => die() + die();
  const chooser = roll() % 2 ? 2 : 1;
  const edges = [die(), die()];
  const axisPlayer = die() % 2 ? 1 : 2;
  const axis = roll() < 10 ? "german" : "italian";
  const years = axis === "german" ? [39,43,40,45,41,42,43,44,44,44,44] : [42,43,39,44,43,40,41,42,41,42,42];
  const year = 1900 + years[roll()-2];
  const german = ["FFFFFFFFFFF","FFFFFFFBBBB","FFFRRRRBBBB","RRRRRRRBBBB","FA AARRRRBBB".replaceAll(" ",""),"FRAAARRRBBB","FRAAARRRBBB"];
  const italian = ["FRRRRRRRRRR","FFFFFBBBBRR","FFFBBBBRRRR","BBBBBRRRRRR","BBB AA AARRRR".replaceAll(" ",""),"RRRRRRRRRRR"];
  const nations = {F:"french", R:"russian", B:"british", A:"american"};
  const allies = nations[(axis === "german" ? german : italian)[year-1939][roll()-2]];
  function quality(nation) {
    const r = roll();
    // Last elite roll and last line roll; all higher rolls are green.
    let thresholds;
    switch (nation) {
      case "german": thresholds = year<1942?[6,12]:year===1942?[6,11]:year<1945?[5,10]:[4,8]; break;
      case "italian": thresholds = allies==="russian"?(year<1941?[12,12]:[5,11]):(year===1939?[12,12]:[4,8]); break;
      case "french": thresholds = year===1939?[1,12]:year===1940?[5,9]:year===1941?[1,7]:[12,12]; break;
      case "american": thresholds = year===1943?[3,8]:year===1944?[4,10]:[8,11]; break;
      case "british": thresholds = year===1940?[5,9]:year<=1942?[6,11]:year===1943?[7,11]:year===1944?[8,11]:[4,9]; break;
      default: thresholds = year<=1940?[4,12]:year===1941?[3,8]:year===1942?[4,9]:year===1943?[5,10]:year===1944?[5,11]:[6,12];
    }
    return r<=thresholds[0]?"Elite":r<=thresholds[1]?"Line":"Green";
  }
  return {chooser,edges,axisPlayer,year,axis,allies,axisQuality:quality(axis),alliesQuality:quality(allies)};
}
export function posture(balance, side) {
  if (!balance) return "recon";
  return (balance>0)===(side==="axis") ? "defend" : "attack";
}
export function hand(role) { return {recon:5,defend:4,attack:6}[role]; }
export function depth(role, edge) {
  const narrow = edge===0 || edge===3;
  return {recon:narrow?6:4,defend:narrow?12:8,attack:narrow?3:2}[role];
}

const leaderTables = {
  american:["Cpl. Cassidy","Cpl. Hubbard","Sgt. Divine","Sgt. White","Sgt. Buehler","Sgt. Smith","Lt. Blankenship","Lt. Wray"],
  british:["Cpl. Singh","Cpl. Nettles","Sgt. Casey","Sgt. Hawes","Sgt. Percival","Lt. Lyndhurst","Lt. Chatham","Lt. Forbes"],
  french:["Cpl. Boudreau","Cpl. Girard","Sgt. Binoche","Sgt. Duris","Sgt. Rochefort","Sgt. Russeau","Lt. de Broca","Lt. Serrault"],
  german:["Cpl. Winkler","Cpl. Retterhaus","Sgt. Biermann","Sgt. Esser","Sgt. Ganz","Lt. Schrader","Lt. Lauerbach","Lt. v. Karsties"],
  italian:["Cpl. Aprile","Cpl. Brachette","Cpl. Radovic","Sgt. Marcello","Sgt. Rovena","Sgt. Ottolini","Lt. Pari","Lt. Visconti"],
  russian:["Cpl. Gordov","Cpl. Krylov","Cpl. Bulganin","Sgt. Maisky","Sgt. Kovalev","Sgt. Bikovets","Lt. Gulikevich","Lt. Khukovsky"]
};
const yearModifiers = {
  american:[0,0,0,0,-1,0,1], british:[0,-1,-1,0,0,0,1], french:[1,0,-1,0,0,0,0],
  german:[1,1,1,1,1,0,-1], italian:[0,0,0,0,-1,-1,0], russian:[-2,-2,-1,0,0,1,1]
};
export function leaders(nation, year, quality, count) {
  const modifier=yearModifiers[nation][year-1939]+({Elite:1,Line:0,Green:-1}[quality]);
  // Removing all die faces for a drawn name is equivalent to rerolling duplicates.
  let pool=Array.from({length:6},(_,i)=>leaderTables[nation][Math.min(7,Math.max(0,i+1+modifier))]);
  const result=[];
  while(result.length<count && pool.length){
    const name=pool[Math.floor(Math.random()*pool.length)];result.push(name);
    pool=pool.filter(v=>v!==name);
  }
  return result;
}
export function eligible(nation,code,row,year,quality,allies){
  if(row.quality!==quality || year<row.years[0] || year>row.years[1])return false;
  if(nation!=="italian")return true;
  if(code==="A")return allies==="russian";
  if(code==="H")return allies==="french";
  return code!=="C" || year!==1940;
}
