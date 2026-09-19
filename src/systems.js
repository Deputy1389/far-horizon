export const RESOURCE_CATALOG = {
  ferric: {
    name: 'Ferric glass-sand',
    color: '#d9b06d',
    stats: { purity: 82, conductivity: 28, toughness: 64, malleability: 75 },
  },
  basalt: {
    name: 'Conductive basalt',
    color: '#7aa2a8',
    stats: { purity: 76, conductivity: 95, toughness: 88, malleability: 31 },
  },
  salts: {
    name: 'Volatile crystal salts',
    color: '#c9a6ff',
    stats: { purity: 91, conductivity: 72, toughness: 34, malleability: 42 },
  },
  biofiber: {
    name: 'Desert biofiber',
    color: '#91b67b',
    stats: { purity: 85, conductivity: 12, toughness: 52, malleability: 89 },
  },
};

export const SKILLS = [
  { id:'marksman_1', tree:'Marksman', rank:1, name:'Ranged Fundamentals', pool:'combat', xp:20, cost:10, prereq:null, desc:'+25% blaster damage.' },
  { id:'marksman_2', tree:'Marksman', rank:2, name:'Pistol Handling', pool:'combat', xp:70, cost:15, prereq:'marksman_1', desc:'Faster follow-up shots and another +25% damage.' },
  { id:'scout_1', tree:'Scout', rank:1, name:'Surveying', pool:'scouting', xp:15, cost:10, prereq:null, desc:'+125m survey range and reveals detailed resource stats.' },
  { id:'scout_2', tree:'Scout', rank:2, name:'Field Harvesting', pool:'scouting', xp:60, cost:15, prereq:'scout_1', desc:'+50% hand-sampling yield and unlocks field camps.' },
  { id:'artisan_1', tree:'Artisan', rank:1, name:'Assembly', pool:'crafting', xp:10, cost:10, prereq:null, desc:'Unlocks field crafting recipes.' },
  { id:'artisan_2', tree:'Artisan', rank:2, name:'Experimentation', pool:'crafting', xp:55, cost:15, prereq:'artisan_1', desc:'Crafted upgrades gain a quality bonus from exceptional resources.' },
  { id:'medic_1', tree:'Medic', rank:1, name:'Field Medicine', pool:'medical', xp:10, cost:10, prereq:null, desc:'Medkits heal 60 instead of 40.' },
  { id:'medic_2', tree:'Medic', rank:2, name:'Trauma Care', pool:'medical', xp:45, cost:15, prereq:'medic_1', desc:'Medkits heal 85.' },
];

export const RECIPES = [
  {
    id:'medkit', name:'Field Medkit', description:'A compact emergency treatment kit.',
    requires:{ biofiber:10, salts:4 }, unlock:'artisan_1', output:{ item:'medkit', qty:1 }, xp:14,
  },
  {
    id:'survey_amp', name:'Survey Amplifier', description:'Permanent survey-range upgrade.',
    requires:{ basalt:12, salts:8 }, unlock:'artisan_1', unique:'surveyTier', output:{ upgrade:'surveyTier', amount:1, max:3 }, xp:24,
  },
  {
    id:'precision_coil', name:'Precision Blaster Coil', description:'Permanent weapon-damage upgrade.',
    requires:{ ferric:16, basalt:10 }, unlock:'artisan_1', unique:'weaponTier', output:{ upgrade:'weaponTier', amount:1, max:4 }, xp:26,
  },
  {
    id:'field_camp_kit', name:'Field Camp Kit', description:'Packed shelter and medical supplies for a temporary camp.',
    requires:{ biofiber:8, ferric:6, scrap:3 }, unlock:'artisan_1', output:{ item:'campKit', qty:1 }, xp:18,
  },
];

export function missionBoard(seed=1) {
  const suffix = String(seed).slice(-3).padStart(3,'0');
  return [
    { id:`sweep-${suffix}`, type:'kill', title:'Perimeter Sweep', description:'Disable 4 patrol drones operating around Keshar.', target:4, rewardCredits:240, rewardXp:{combat:35} },
    { id:`prospect-${suffix}`, type:'harvest', title:'Prospector Contract', description:'Hand-sample 24 units from deposits of quality 80 or better.', target:24, minQuality:80, rewardCredits:210, rewardXp:{scouting:30,crafting:8} },
    { id:`salvage-${suffix}`, type:'salvage', title:'Salvage Requisition', description:'Recover 7 units of droid scrap from disabled patrols.', target:7, rewardCredits:280, rewardXp:{combat:18,crafting:18} },
  ];
}

const DEFAULT_STATE = {
  version:2,
  credits:250,
  health:100,
  maxHealth:100,
  skillPoints:80,
  xp:{ combat:0, scouting:0, crafting:0, medical:0 },
  skills:[],
  items:{ medkit:1, scrap:0, campKit:0 },
  resources:{},
  upgrades:{ weaponTier:0, surveyTier:0 },
  activeMission:null,
  completedMissions:[],
  stats:{ dronesKilled:0, resourcesHarvested:0, scrapCollected:0 },
};

function clone(v){ return JSON.parse(JSON.stringify(v)); }

export class CharacterState {
  constructor(storageKey='far-horizon-character-v2') {
    this.storageKey = storageKey;
    this.data = clone(DEFAULT_STATE);
    this.listeners = new Set();
    this.load();
  }

  load(){
    try {
      const raw = localStorage.getItem(this.storageKey);
      if (!raw) return;
      const saved = JSON.parse(raw);
      this.data = {
        ...clone(DEFAULT_STATE), ...saved,
        xp:{...DEFAULT_STATE.xp,...(saved.xp||{})},
        items:{...DEFAULT_STATE.items,...(saved.items||{})},
        resources:{...(saved.resources||{})},
        upgrades:{...DEFAULT_STATE.upgrades,...(saved.upgrades||{})},
        stats:{...DEFAULT_STATE.stats,...(saved.stats||{})},
      };
    } catch (err) { console.warn('Could not load save', err); }
  }

  save(){
    try { localStorage.setItem(this.storageKey, JSON.stringify(this.data)); } catch(err){ console.warn('Could not save',err); }
    this.emit();
  }
  emit(){ for(const fn of this.listeners) fn(this.data); }
  subscribe(fn){ this.listeners.add(fn); fn(this.data); return ()=>this.listeners.delete(fn); }

  hasSkill(id){ return this.data.skills.includes(id); }
  skill(id){ return SKILLS.find(s=>s.id===id); }
  canTrain(id){
    const s=this.skill(id); if(!s||this.hasSkill(id)) return false;
    if(s.prereq&&!this.hasSkill(s.prereq)) return false;
    return this.data.skillPoints>=s.cost && (this.data.xp[s.pool]||0)>=s.xp;
  }
  train(id){
    if(!this.canTrain(id)) return {ok:false,message:'Requirements not met'};
    const s=this.skill(id); this.data.skillPoints-=s.cost; this.data.skills.push(id); this.save();
    return {ok:true,message:`Trained ${s.name}`};
  }

  addItem(id,qty=1){ this.data.items[id]=(this.data.items[id]||0)+qty; this.save(); }
  consumeItem(id,qty=1){ if((this.data.items[id]||0)<qty)return false; this.data.items[id]-=qty; this.save(); return true; }

  addResource(id,qty,quality,stats={}){
    const r=this.data.resources[id] || {qty:0,quality:0,stats:{}};
    const total=r.qty+qty;
    r.quality=total?((r.quality*r.qty)+(quality*qty))/total:quality;
    const keys=new Set([...Object.keys(r.stats||{}),...Object.keys(stats||{})]);
    const merged={};
    for(const k of keys){
      const old=r.stats?.[k]??0, incoming=stats?.[k]??old;
      merged[k]=total?((old*r.qty)+(incoming*qty))/total:incoming;
    }
    r.qty=total; r.stats=merged; this.data.resources[id]=r;
    this.data.stats.resourcesHarvested+=qty;
    this.progressMission('harvest',qty,{quality});
    this.save();
  }

  heal(amount){ const before=this.data.health; this.data.health=Math.min(this.data.maxHealth,this.data.health+amount); this.save(); return this.data.health-before; }
  damage(amount){ this.data.health=Math.max(0,this.data.health-amount); this.save(); return this.data.health; }
  revive(){ this.data.health=this.data.maxHealth; this.data.credits=Math.max(0,this.data.credits-25); this.save(); }

  weaponDamage(){
    let v=1 + this.data.upgrades.weaponTier*0.45;
    if(this.hasSkill('marksman_1'))v+=0.5;
    if(this.hasSkill('marksman_2'))v+=0.75;
    return v;
  }
  fireCooldown(){ return this.hasSkill('marksman_2') ? 0.14 : 0.24; }
  surveyRange(){ return 450 + this.data.upgrades.surveyTier*120 + (this.hasSkill('scout_1')?125:0); }
  harvestMultiplier(){ return this.hasSkill('scout_2')?1.5:1; }
  medkitHeal(){ return this.hasSkill('medic_2')?85:this.hasSkill('medic_1')?60:40; }

  craft(recipeId){
    const recipe=RECIPES.find(r=>r.id===recipeId); if(!recipe)return {ok:false,message:'Unknown recipe'};
    if(recipe.unlock&&!this.hasSkill(recipe.unlock))return {ok:false,message:'Train Artisan: Assembly first'};
    if(recipe.unique && this.data.upgrades[recipe.unique] >= (recipe.output.max||1))return {ok:false,message:'Upgrade is already maxed'};
    for(const [id,qty] of Object.entries(recipe.requires)){
      const have=id==='scrap'?(this.data.items.scrap||0):(this.data.resources[id]?.qty||0);
      if(have<qty)return {ok:false,message:`Need ${qty} ${id}`};
    }
    for(const [id,qty] of Object.entries(recipe.requires)){
      if(id==='scrap')this.data.items.scrap-=qty; else this.data.resources[id].qty-=qty;
    }
    let qualityBonus=0;
    if(this.hasSkill('artisan_2')){
      const resourceIds=Object.keys(recipe.requires).filter(id=>id!=='scrap');
      if(resourceIds.length) qualityBonus=resourceIds.reduce((n,id)=>n+(this.data.resources[id]?.quality||70),0)/resourceIds.length;
    }
    if(recipe.output.item)this.data.items[recipe.output.item]=(this.data.items[recipe.output.item]||0)+(recipe.output.qty||1);
    if(recipe.output.upgrade){
      const extra=qualityBonus>=88?0.15:0;
      this.data.upgrades[recipe.output.upgrade]=Math.min(recipe.output.max||99,this.data.upgrades[recipe.output.upgrade]+recipe.output.amount+extra);
    }
    this.data.xp.crafting+=recipe.xp; this.save();
    return {ok:true,message:`Crafted ${recipe.name}${qualityBonus>=88?' with exceptional materials':''}`};
  }

  acceptMission(mission){
    this.data.activeMission={...clone(mission),progress:0}; this.save();
    return {ok:true,message:`Accepted ${mission.title}`};
  }
  progressMission(type,amount=1,meta={}){
    const m=this.data.activeMission; if(!m||m.type!==type)return;
    if(type==='harvest' && (meta.quality||0)<(m.minQuality||0))return;
    m.progress=Math.min(m.target,(m.progress||0)+amount);
  }
  completeMission(){
    const m=this.data.activeMission; if(!m||m.progress<m.target)return {ok:false,message:'Mission not complete'};
    this.data.credits+=m.rewardCredits;
    for(const [pool,amt] of Object.entries(m.rewardXp||{}))this.data.xp[pool]=(this.data.xp[pool]||0)+amt;
    this.data.completedMissions.push(m.id); this.data.activeMission=null; this.save();
    return {ok:true,message:`Contract complete +${m.rewardCredits} credits`};
  }

  recordDroneKill(){
    this.data.stats.dronesKilled++;
    this.data.xp.combat+=8;
    this.progressMission('kill',1);
    this.save();
  }

  recordSalvage(scrap){
    this.data.items.scrap=(this.data.items.scrap||0)+scrap;
    this.data.stats.scrapCollected+=scrap;
    this.progressMission('salvage',scrap);
    this.save();
  }
}
