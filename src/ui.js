import { RESOURCE_CATALOG, SKILLS, RECIPES, missionBoard } from './systems.js';

const ITEM_NAMES = {
  medkit:'Field Medkit', scrap:'Droid Scrap', campKit:'Field Camp Kit',
};

export function createSystemsUI({ character, seed, onToast=()=>{}, onPanelChange=()=>{} }) {
  const root = document.getElementById('panelRoot');
  const healthFill = document.getElementById('healthFill');
  const healthText = document.getElementById('healthText');
  const creditsText = document.getElementById('creditsText');
  const xpText = document.getElementById('xpText');
  let activePanel = null;
  let vendorOpen = false;

  function close(){
    activePanel=null; vendorOpen=false; root.classList.remove('open'); root.innerHTML=''; onPanelChange(false);
  }

  function shell(title, subtitle=''){
    root.classList.add('open');
    root.innerHTML = `<div class="panelHead"><div><h2>${title}</h2>${subtitle?`<p>${subtitle}</p>`:''}</div><button class="panelClose" aria-label="Close">×</button></div><div class="panelBody"></div>`;
    root.querySelector('.panelClose').onclick=close;
    onPanelChange(true);
    return root.querySelector('.panelBody');
  }

  function requirementText(skill){
    const parts=[`${skill.cost} skill points`, `${skill.xp} ${skill.pool} XP`];
    if(skill.prereq){ const req=SKILLS.find(s=>s.id===skill.prereq); parts.push(req?.name||skill.prereq); }
    return parts.join(' · ');
  }

  function renderInventory(){
    const body=shell('Inventory & Resources','Persistent character inventory. Resource batches preserve average quality and material properties.');
    const d=character.data;
    body.innerHTML += `<section><h3>Equipment & cargo</h3><div class="inventoryGrid"></div></section>`;
    const grid=body.querySelector('.inventoryGrid');
    for(const [id,qty] of Object.entries(d.items)){
      grid.insertAdjacentHTML('beforeend',`<div class="itemCard"><b>${ITEM_NAMES[id]||id}</b><strong>× ${Math.floor(qty)}</strong></div>`);
    }
    body.insertAdjacentHTML('beforeend','<section><h3>Surveyed material batches</h3><div class="resourceList"></div></section>');
    const list=body.querySelector('.resourceList');
    const entries=Object.entries(d.resources).filter(([,r])=>r.qty>0.01);
    if(!entries.length) list.innerHTML='<p class="muted">No sampled resources yet. Survey with Q, move near a deposit, and press H to hand-sample it.</p>';
    for(const [id,r] of entries){
      const cat=RESOURCE_CATALOG[id]||{name:id,stats:{}};
      const stats=Object.entries(r.stats||{}).map(([k,v])=>`<span>${k} ${Math.round(v)}</span>`).join('');
      list.insertAdjacentHTML('beforeend',`<div class="resourceCard"><div><i style="background:${cat.color||'#aaa'}"></i><b>${cat.name}</b><small>${Math.floor(r.qty)} units · quality ${Math.round(r.quality)}</small></div><div class="statChips">${stats}</div></div>`);
    }
  }

  function renderSkills(){
    const body=shell('Professions & Skills',`${character.data.skillPoints} unspent skill points. Earn profession XP by doing the associated activity.`);
    const trees=[...new Set(SKILLS.map(s=>s.tree))];
    for(const tree of trees){
      const section=document.createElement('section'); section.innerHTML=`<h3>${tree}</h3><div class="skillTrack"></div>`;
      const track=section.querySelector('.skillTrack');
      for(const s of SKILLS.filter(x=>x.tree===tree)){
        const trained=character.hasSkill(s.id), can=character.canTrain(s.id);
        const el=document.createElement('div'); el.className=`skillCard ${trained?'trained':''}`;
        el.innerHTML=`<div><small>Rank ${s.rank}</small><b>${s.name}</b><p>${s.desc}</p><em>${trained?'Trained':requirementText(s)}</em></div>${trained?'<span class="trainedMark">✓</span>':`<button ${can?'':'disabled'}>Train</button>`}`;
        if(!trained){ el.querySelector('button').onclick=()=>{const r=character.train(s.id);onToast(r.message);renderSkills();}; }
        track.appendChild(el);
      }
      body.appendChild(section);
    }
  }

  function haveForRecipe(id){ return id==='scrap'?(character.data.items.scrap||0):(character.data.resources[id]?.qty||0); }
  function renderCrafting(){
    const body=shell('Field Crafting','Material batches feed directly into useful equipment and permanent upgrades.');
    if(!character.hasSkill('artisan_1')) body.insertAdjacentHTML('beforeend','<div class="callout">Train <b>Artisan: Assembly</b> to unlock field crafting.</div>');
    const list=document.createElement('div'); list.className='recipeList'; body.appendChild(list);
    for(const r of RECIPES){
      const materials=Object.entries(r.requires).map(([id,qty])=>{
        const cat=RESOURCE_CATALOG[id]; const have=haveForRecipe(id); return `<span class="${have>=qty?'enough':'short'}">${cat?.name||ITEM_NAMES[id]||id}: ${Math.floor(have)}/${qty}</span>`;
      }).join('');
      const el=document.createElement('div'); el.className='recipeCard';
      const maxed=r.unique && character.data.upgrades[r.unique]>=(r.output.max||1);
      el.innerHTML=`<div><b>${r.name}</b><p>${r.description}</p><div class="requirements">${materials}</div></div><button ${maxed?'disabled':''}>${maxed?'Maxed':'Craft'}</button>`;
      el.querySelector('button').onclick=()=>{const result=character.craft(r.id);onToast(result.message);renderCrafting();}; list.appendChild(el);
    }
    body.insertAdjacentHTML('beforeend',`<div class="upgradeStrip"><span>Weapon tier <b>${character.data.upgrades.weaponTier.toFixed(2)}</b></span><span>Survey tier <b>${character.data.upgrades.surveyTier.toFixed(2)}</b></span></div>`);
  }

  function renderMissions(){
    const body=shell('Mission Terminal','Procedural contracts are tied to activities already happening in the sandbox.');
    const d=character.data;
    if(d.activeMission){
      const m=d.activeMission; const complete=m.progress>=m.target;
      body.innerHTML+=`<div class="activeMission"><small>ACTIVE CONTRACT</small><h3>${m.title}</h3><p>${m.description}</p><div class="progress"><i style="width:${Math.min(100,(m.progress/m.target)*100)}%"></i></div><b>${Math.floor(m.progress)} / ${m.target}</b><p>Reward: ${m.rewardCredits} credits</p><button id="claimMission" ${complete?'':'disabled'}>${complete?'Collect reward':'In progress'}</button></div>`;
      body.querySelector('#claimMission').onclick=()=>{const r=character.completeMission();onToast(r.message);renderMissions();};
      return;
    }
    const available=missionBoard(seed).filter(m=>!d.completedMissions.includes(m.id));
    if(!available.length){body.innerHTML+='<p class="muted">All contracts for this world seed are complete. Reseed the world for a new local contract board.</p>';return;}
    for(const m of available){
      const el=document.createElement('div'); el.className='missionCard';
      el.innerHTML=`<div><b>${m.title}</b><p>${m.description}</p><small>${m.rewardCredits} credits · ${Object.entries(m.rewardXp).map(([p,x])=>`${x} ${p} XP`).join(' · ')}</small></div><button>Accept</button>`;
      el.querySelector('button').onclick=()=>{const r=character.acceptMission(m);onToast(r.message);renderMissions();}; body.appendChild(el);
    }
  }

  function openVendor(){
    activePanel='vendor'; vendorOpen=true;
    const body=shell('Keshar Supply Kiosk','Buy field supplies or liquidate salvage and sampled resources.');
    body.innerHTML=`
      <section><h3>Buy</h3><div class="shopRow"><div><b>Field Medkit</b><small>Emergency healing consumable.</small></div><button id="buyMedkit">75 cr</button></div></section>
      <section><h3>Sell</h3><div class="shopRow"><div><b>Droid Scrap</b><small>${Math.floor(character.data.items.scrap||0)} in cargo · 18 cr each</small></div><button id="sellScrap">Sell all</button></div><div id="resourceSales"></div></section>`;
    body.querySelector('#buyMedkit').onclick=()=>{
      if(character.data.credits<75){onToast('Not enough credits');return;}
      character.data.credits-=75; character.data.items.medkit=(character.data.items.medkit||0)+1; character.save(); onToast('Purchased Field Medkit'); openVendor();
    };
    body.querySelector('#sellScrap').onclick=()=>{
      const qty=Math.floor(character.data.items.scrap||0); if(!qty){onToast('No scrap to sell');return;}
      character.data.items.scrap-=qty; character.data.credits+=qty*18; character.save(); onToast(`Sold ${qty} scrap for ${qty*18} credits`); openVendor();
    };
    const sales=body.querySelector('#resourceSales');
    for(const [id,r] of Object.entries(character.data.resources).filter(([,x])=>x.qty>=1)){
      const cat=RESOURCE_CATALOG[id]||{name:id}; const qty=Math.floor(r.qty); const unit=Math.max(2,Math.round(r.quality/18));
      const row=document.createElement('div');row.className='shopRow';row.innerHTML=`<div><b>${cat.name}</b><small>${qty} units · quality ${Math.round(r.quality)} · ${unit} cr/unit</small></div><button>Sell all</button>`;
      row.querySelector('button').onclick=()=>{character.data.resources[id].qty-=qty;character.data.credits+=qty*unit;character.save();onToast(`Sold ${qty} ${cat.name} for ${qty*unit} credits`);openVendor();}; sales.appendChild(row);
    }
  }

  function toggle(name){
    if(activePanel===name && root.classList.contains('open')){close();return;}
    activePanel=name; vendorOpen=false;
    if(name==='inventory')renderInventory();
    if(name==='skills')renderSkills();
    if(name==='crafting')renderCrafting();
    if(name==='missions')renderMissions();
  }

  function refreshHud(d=character.data){
    healthFill.style.width=`${Math.max(0,Math.min(100,d.health/d.maxHealth*100))}%`;
    healthText.textContent=`${Math.ceil(d.health)} / ${d.maxHealth}`;
    creditsText.textContent=`${Math.floor(d.credits)} cr`;
    xpText.textContent=`Combat ${Math.floor(d.xp.combat)} · Scout ${Math.floor(d.xp.scouting)} · Craft ${Math.floor(d.xp.crafting)}`;
  }

  character.subscribe(refreshHud);
  return { toggle, close, openVendor, refreshHud, get isOpen(){return root.classList.contains('open');} };
}
