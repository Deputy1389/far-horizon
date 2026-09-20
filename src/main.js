import * as THREE from 'https://unpkg.com/three@0.180.0/build/three.module.js';
import { GLTFLoader } from 'https://esm.sh/three@0.180.0/examples/jsm/loaders/GLTFLoader.js';
import { clone as cloneSkeleton } from 'https://esm.sh/three@0.180.0/examples/jsm/utils/SkeletonUtils.js';
import { CharacterState, RESOURCE_CATALOG } from './systems.js';
import { createSystemsUI } from './ui.js';
import { createMaterialLibrary } from './materials.js';
import {
  advanceBolt,
  createBoltFlight,
  createLocomotionState,
  facingRotation,
  triggerLocomotionRecoil,
  updateLocomotion,
} from './motion.mjs';

const character = new CharacterState();

const WORLD_SIZE = 3200;
const CITY_RADIUS = 900;
const seedParam = Number(new URLSearchParams(location.search).get('seed'));
let WORLD_SEED = Number.isFinite(seedParam) && seedParam > 0 ? Math.floor(seedParam) : 1389;

const ui = {
  seed: document.getElementById('seedLabel'),
  location: document.getElementById('locationLabel'),
  scan: document.getElementById('scanLabel'),
  drones: document.getElementById('droneLabel'),
  swgAssets: document.getElementById('swgAssetLabel'),
  character: document.getElementById('characterLabel'),
  toast: document.getElementById('toast'),
  prompt: document.getElementById('interactionPrompt'),
  startCard: document.getElementById('startCard'),
  startButton: document.getElementById('startButton'),
};
ui.seed.textContent = WORLD_SEED;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xd8a36d);
scene.fog = new THREE.FogExp2(0xd19b69, 0.00032);

const camera = new THREE.PerspectiveCamera(68, innerWidth / innerHeight, 0.1, 7000);
const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.6));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
document.getElementById('game').appendChild(renderer.domElement);

const materials = await createMaterialLibrary(renderer);
ui.swgAssets.textContent = materials.swgAssetStatus.label;
ui.character.textContent = materials.stormtrooperReady ? 'STORMTROOPER' : 'CAPSULE FALLBACK';

scene.add(new THREE.HemisphereLight(0xffd7aa, 0x554738, 2.1));
const sun = new THREE.DirectionalLight(0xffd2a0, 3.6);
sun.position.set(-900, 1200, 700);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -900; sun.shadow.camera.right = 900;
sun.shadow.camera.top = 900; sun.shadow.camera.bottom = -900;
scene.add(sun);

function mulberry32(seed) {
  return () => {
    let t = seed += 0x6D2B79F5;
    t = Math.imul(t ^ t >>> 15, t | 1);
    t ^= t + Math.imul(t ^ t >>> 7, t | 61);
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(WORLD_SEED);
const rrange = (a, b) => a + (b - a) * rand();

function terrainHeight(x, z) {
  const ridge = 65 * Math.exp(-Math.pow((z - 1120) / 360, 2));
  const broad = 18 * Math.sin(x * 0.0031) + 11 * Math.sin(z * 0.0047) + 8 * Math.sin((x + z) * 0.006);
  const basin = -25 * Math.exp(-(x*x + z*z) / (2 * 700 * 700));
  return broad + ridge + basin;
}

function buildTerrain() {
  const geo = new THREE.PlaneGeometry(WORLD_SIZE, WORLD_SIZE, 150, 150);
  geo.rotateX(-Math.PI / 2);
  const p = geo.attributes.position;
  for (let i = 0; i < p.count; i++) p.setY(i, terrainHeight(p.getX(i), p.getZ(i)));
  geo.computeVertexNormals();
  const mesh = new THREE.Mesh(geo, materials.terrain);
  mesh.receiveShadow = true;
  scene.add(mesh);

  const rockGeo = new THREE.DodecahedronGeometry(1, 0);
  const rocks = new THREE.InstancedMesh(rockGeo, materials.rock, 260);
  const m = new THREE.Matrix4();
  for (let i = 0; i < 260; i++) {
    const x = rrange(-1550, 1550), z = rrange(-1550, 1550);
    if (Math.hypot(x, z) < 760) { i--; continue; }
    const s = rrange(3, 17);
    m.compose(new THREE.Vector3(x, terrainHeight(x,z)+s*.35, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rrange(0,2),rrange(0,2),rrange(0,2))), new THREE.Vector3(s, s*rrange(.5,1.2), s));
    rocks.setMatrixAt(i, m);
  }
  rocks.castShadow = rocks.receiveShadow = true;
  scene.add(rocks);
}

const blockers = [];
const buildingMeshes = [];
function addBox(x,z,w,d,h,color, yOffset=0) {
  const geo = new THREE.BoxGeometry(w,h,d);
  const y = terrainHeight(x,z) + h/2 + yOffset;
  const mesh = new THREE.Mesh(geo, materials.building(color));
  mesh.position.set(x,y,z);
  mesh.castShadow = true; mesh.receiveShadow = true;
  scene.add(mesh);
  blockers.push({x,z,hw:w/2+1.2,hd:d/2+1.2});
  buildingMeshes.push(mesh);
  return mesh;
}

function addRoad(x,z,w,d,rot=0) {
  const g = new THREE.PlaneGeometry(w,d); g.rotateX(-Math.PI/2);
  const road = new THREE.Mesh(g,materials.roadMaterial(w,d));
  road.position.set(x, terrainHeight(x,z)+.25, z); road.rotation.y=rot; road.receiveShadow=true; scene.add(road);
}

function buildCity() {
  const roadStep = 150;
  for (let i=-5;i<=5;i++) { addRoad(i*roadStep,0,38,1700); addRoad(0,i*roadStep,1700,38); }

  for (let gx=-5; gx<=5; gx++) for (let gz=-5; gz<=5; gz++) {
    const cx = gx*roadStep, cz=gz*roadStep;
    const radial = Math.hypot(cx,cz);
    if (radial > CITY_RADIUS || radial < 115) continue;
    const density = THREE.MathUtils.clamp(1.15-radial/CITY_RADIUS, .2, .95);
    const count = Math.max(1, Math.floor(2 + density*6 + rand()*3));
    for (let j=0;j<count;j++) {
      const x=cx+rrange(-50,50), z=cz+rrange(-50,50);
      if (Math.hypot(x-130,z-25)<55 || Math.hypot(x+130,z-25)<55) continue;
      const w=rrange(22,55), d=rrange(20,52);
      const h=rrange(12,32) * (1+density*2.5);
      const palette=[0xbda477,0x987a5b,0xc2b18b,0x8f7968,0xb58f66];
      const b=addBox(x,z,w,d,h,palette[Math.floor(rand()*palette.length)]);
      if (density>.55 && rand()>.62) {
        const top=addBox(x+rrange(-w*.15,w*.15),z+rrange(-d*.15,d*.15),w*.55,d*.55,rrange(5,14),0x756c63,h*.5);
        blockers.pop();
      }
      if (rand()>.7) {
        const antenna = new THREE.Mesh(new THREE.CylinderGeometry(.6,.8,rrange(10,30),6), materials.antenna);
        antenna.position.set(x, terrainHeight(x,z)+h+8, z); scene.add(antenna);
      }
    }
  }

  // Monumental starport core.
  const port = addBox(0,0,190,190,52,0x827769);
  const tower = addBox(0,0,64,64,165,0x6d6860,52/2);
  blockers.pop();
  const ring = new THREE.Mesh(new THREE.TorusGeometry(105,8,10,48), materials.metal);
  ring.rotation.x=Math.PI/2; ring.position.set(0,terrainHeight(0,0)+95,0); ring.castShadow=true; scene.add(ring);

  // Landing pads and grounded ships.
  for (let i=0;i<8;i++) {
    const a=i/8*Math.PI*2, rad=rrange(270,430), x=Math.cos(a)*rad,z=Math.sin(a)*rad;
    const pad=new THREE.Mesh(new THREE.CylinderGeometry(45,45,2,32),materials.pad);
    pad.position.set(x,terrainHeight(x,z)+1,z); scene.add(pad);
    if(i%2===0) addShip(x,terrainHeight(x,z)+9,z,a+Math.PI/2,rrange(.7,1.15));
  }

  // Outskirts become progressively sparse.
  for(let i=0;i<190;i++){
    const a=rrange(0,Math.PI*2),rad=rrange(900,1450),x=Math.cos(a)*rad,z=Math.sin(a)*rad;
    if(rand()<.52){ const w=rrange(12,28),d=rrange(12,30),h=rrange(7,18); addBox(x,z,w,d,h,rand()>.5?0x9d7958:0x806653); }
  }
}

async function addLocalSwgMesh(){
  if(!materials.usesSwgAssets)return;
  try{
    const response=await fetch('./assets/local-swg/manifest.json',{cache:'no-store'});
    if(!response.ok)return;
    const manifest=await response.json();
    const proof=manifest.meshProof;
    if(!proof?.url)return;
    const loader=new GLTFLoader();
    const gltf=await new Promise((resolve,reject)=>loader.load(proof.url,resolve,undefined,reject));
    const object=gltf.scene;
    object.traverse(child=>{
      if(!child.isMesh)return;
      // The glTF keeps the real SWG shader-group boundaries and UVs. The
      // browser-side material deliberately resolves those groups through the
      // local DDS library instead of asking a browser to decode .sht files.
      child.material=materials.metal;
      child.castShadow=true;
      child.receiveShadow=true;
    });
    // Keep the proof object close to the initial spawn so the local conversion
    // is visible immediately instead of being hidden in the far outskirts.
    const x=28,z=1225;
    const displayPad=new THREE.Mesh(new THREE.CylinderGeometry(18,18,.8,32),materials.pad);
    displayPad.position.set(x,terrainHeight(x,z)+.4,z);
    displayPad.receiveShadow=true;
    displayPad.userData.swgSource='spaceport_concrete.dds';
    scene.add(displayPad);
    object.position.set(x,terrainHeight(x,z)+.15,z);
    object.scale.setScalar(1.15);
    object.userData.swgSource=proof.virtualPath;
    object.userData.swgArchive=proof.archive;
    scene.add(object);
    console.info(`Loaded local SWG mesh ${proof.virtualPath} from ${proof.archive}`);
  }catch(error){
    console.warn('Local SWG mesh proof could not be loaded; continuing with procedural geometry.',error);
  }
}

let localStormtrooperPrototype=null;
let localStormtrooperGroundOffset=0;
let localStormtrooperAvatar=null;
let localStormtrooperAnimations=[];
let localStormtrooperRigged=false;
function stormtrooperAnimationClip(name){
  const wanted=String(name||'').toLowerCase();
  return localStormtrooperAnimations.find(clip=>String(clip.name||'').toLowerCase()===wanted)
    || localStormtrooperAnimations.find(clip=>String(clip.name||'').toLowerCase().includes(wanted))
    || localStormtrooperAnimations[0]
    || null;
}
function playStormtrooperAnimation(object,name){
  const mixer=object?.userData?.animationMixer;
  if(!mixer)return;
  const clip=stormtrooperAnimationClip(name);
  if(!clip)return;
  if(object.userData.activeAnimation===clip.name)return;
  const previous=object.userData.activeAction;
  const action=mixer.clipAction(clip);
  action.reset().setEffectiveTimeScale(1).setEffectiveWeight(1).fadeIn(.18).play();
  if(previous&&previous!==action)previous.fadeOut(.18);
  object.userData.activeAction=action;
  object.userData.activeAnimation=clip.name;
}
function updateStormtrooperAnimation(object,dt,moving,sprinting){
  if(!object?.userData?.animationMixer)return;
  playStormtrooperAnimation(object,moving?(sprinting?'run':'walk'):'idle');
  object.userData.animationMixer.update(Math.max(0,dt));
  if(typeof window!=='undefined'&&object===localStormtrooperAvatar){
    window.__farHorizonCharacterStatus={
      rigged:localStormtrooperRigged,
      clips:localStormtrooperAnimations.map(clip=>clip.name),
      active:object.userData.activeAnimation,
      mixerTime:object.userData.activeAction?.time||0,
    };
  }
}
function addStormtrooperBlaster(object){
  if(!object?.userData?.rigged||object.userData.blasterMuzzle)return;
  // The extracted MGN is the weighted armor body and does not contain the
  // equipped weapon. Keep the weapon as a small, deterministic presentation
  // attachment until the SWG appearance/weapon hardpoint chain is converted.
  const mount=object;
  const gun=new THREE.Group();
  const finish=materials.stormtrooperMaterial('weapon');
  const receiver=new THREE.Mesh(new THREE.BoxGeometry(.22,.2,.72),finish);
  receiver.position.set(0,0,-.30); gun.add(receiver);
  const grip=new THREE.Mesh(new THREE.BoxGeometry(.16,.28,.22),finish);
  grip.position.set(0,-.18,-.08); grip.rotation.x=-.25; gun.add(grip);
  const barrel=new THREE.Mesh(new THREE.CylinderGeometry(.045,.06,.62,8),finish);
  barrel.rotation.x=Math.PI/2; barrel.position.set(0,.02,-.92); gun.add(barrel);
  const muzzle=new THREE.Object3D();
  muzzle.position.set(0,.02,-1.28); gun.add(muzzle);
  gun.position.set(-.12,1.48,-.42);
  // In the imported +Z character space the camera sees the rear three-quarter
  // view, so rotate the compact rifle across the chest for a readable held
  // silhouette while preserving its muzzle Object3D for bolt spawning.
  gun.rotation.set(-.06,Math.PI/2,.10);
  gun.scale.setScalar(.48);
  gun.traverse(child=>{if(child.isMesh){child.castShadow=true;child.receiveShadow=true;}});
  mount.add(gun);
  object.userData.blasterMuzzle=muzzle;
}
function localStormtrooperClone(scale=4.6){
  if(!localStormtrooperPrototype)return null;
  const clone=localStormtrooperRigged?cloneSkeleton(localStormtrooperPrototype):localStormtrooperPrototype.clone(true);
  clone.scale.setScalar(scale);
  clone.userData.groundCorrection=-(localStormtrooperGroundOffset*scale);
  clone.userData.motion=createLocomotionState();
  clone.userData.rigged=localStormtrooperRigged;
  clone.userData.animationMixer=localStormtrooperRigged?new THREE.AnimationMixer(clone):null;
  clone.userData.activeAction=null;
  clone.userData.activeAnimation='';
  if(localStormtrooperRigged)playStormtrooperAnimation(clone,'idle');
  clone.position.y=clone.userData.groundCorrection;
  clone.traverse(child=>{
    if(child.isMesh){child.castShadow=true;child.receiveShadow=true;}
  });
  if(localStormtrooperRigged)addStormtrooperBlaster(clone);
  return clone;
}

function applyStormtrooperMotion(object,dt,inputMagnitude,speed,sprinting,baseY=0,allowSway=false){
  const state=object.userData.motion;
  if(!state)return;
  updateLocomotion(state,dt,inputMagnitude,speed,sprinting);
  if(object.userData.rigged){
    // The actual SWG skeleton owns the limbs now. Keep gameplay movement on
    // the parent and let the glTF animation provide the gait, avoiding the
    // old capsule-style root bob that made the statue look like it floated.
    object.position.y=baseY+(object.userData.groundCorrection||0);
    updateStormtrooperAnimation(object,dt,inputMagnitude>0.001,sprinting);
    object.rotation.x=-state.recoil*.025;
    return;
  }
  object.position.y=baseY+(object.userData.groundCorrection||0)+state.bob;
  if(allowSway)object.position.x=state.sway;
  object.rotation.x=state.lean-state.recoil*.04;
  object.rotation.z=state.roll;
}

async function addLocalSwgCharacter(){
  if(!materials.stormtrooperReady)return;
  try{
    const response=await fetch('./assets/local-swg/manifest.json',{cache:'no-store'});
    if(!response.ok){ui.character.textContent='CAPSULE FALLBACK';return;}
    const manifest=await response.json();
    const character=manifest.characters?.stormtrooper;
    if(!character?.url){ui.character.textContent='CAPSULE FALLBACK';return;}
    const loader=new GLTFLoader();
    const gltf=await new Promise((resolve,reject)=>loader.load(character.url,resolve,undefined,reject));
    const object=gltf.scene;
    object.traverse(child=>{
      if(!child.isMesh)return;
      const shaderName=child.material?.name||'';
      child.material=materials.stormtrooperMaterial(shaderName);
      child.castShadow=true;
      child.receiveShadow=true;
      child.userData.swgShader=shaderName;
    });
    object.userData.swgSource=character.virtualPath;
    object.userData.swgArchive=character.archive;
    localStormtrooperAnimations=gltf.animations||[];
    localStormtrooperRigged=character.rigged===true&&localStormtrooperAnimations.length>0;
    object.userData.rigged=localStormtrooperRigged;
    localStormtrooperPrototype=object;
    localStormtrooperGroundOffset=Number(character.groundOffset)||0;
    torso.visible=false;
    head.visible=false;
    rifle.visible=false;
    const playerAvatar=localStormtrooperClone(6.4);
    playerAvatar.name='local-swg-stormtrooper-player';
    player.add(playerAvatar);
    localStormtrooperAvatar=playerAvatar;
    player.rotation.y=facingRotation(yaw,true);
    ui.character.textContent=localStormtrooperRigged?'RIGGED STORMTROOPER':'STORMTROOPER';
    console.info(`Loaded local SWG character ${character.virtualPath} from ${character.archive}`);
  }catch(error){
    ui.character.textContent='CAPSULE FALLBACK';
    console.warn('Local SWG Stormtrooper could not be loaded; keeping the capsule fallback.',error);
  }
}

function addShip(x,y,z,rot=0,scale=1){
  const group=new THREE.Group();
  const body=new THREE.Mesh(new THREE.BoxGeometry(30,6,70),materials.ship); group.add(body);
  const wing=new THREE.Mesh(new THREE.BoxGeometry(68,2.5,26),materials.ship); wing.position.z=5; group.add(wing);
  const nose=new THREE.Mesh(new THREE.ConeGeometry(8,22,6),materials.ship); nose.rotation.x=Math.PI/2; nose.position.z=-45; group.add(nose);
  group.position.set(x,y,z); group.rotation.y=rot; group.scale.setScalar(scale); group.traverse(o=>{if(o.isMesh)o.castShadow=true}); scene.add(group); return group;
}

function buildSkyTraffic(){
  for(let i=0;i<9;i++){
    const ship=addShip(rrange(-1200,1200),rrange(180,420),rrange(-1100,800),rrange(0,Math.PI*2),rrange(.25,.55));
    ship.userData.velocity=new THREE.Vector3(rrange(-14,14),rrange(-1,1),rrange(-14,14));
    traffic.push(ship);
  }
}
const traffic=[];

const crowd=[];
function buildCrowd(){
  const geo=new THREE.CapsuleGeometry(.65,1.6,3,6);
  const mat=new THREE.MeshStandardMaterial({color:0x74695f,roughness:1});
  for(let i=0;i<72;i++){
    const a=rrange(0,Math.PI*2),rad=rrange(150,760);
    const x=Math.cos(a)*rad,z=Math.sin(a)*rad;
    const agent=localStormtrooperPrototype?localStormtrooperClone(4.6):new THREE.Mesh(geo,mat);
    const groundOffset=localStormtrooperPrototype?agent.userData.groundCorrection:1.8;
    agent.position.set(x,terrainHeight(x,z)+groundOffset,z);
    agent.castShadow=true;
    agent.receiveShadow=true;
    agent.userData.groundOffset=groundOffset;
    agent.userData.forwardOffset=localStormtrooperPrototype?0:Math.PI;
    agent.userData.dir=rrange(0,Math.PI*2);
    agent.userData.turn=rrange(2,7);
    scene.add(agent);crowd.push(agent);
  }
}
function updateCrowd(dt){
  for(const a of crowd){
    a.userData.turn-=dt;
    if(a.userData.turn<=0){a.userData.dir+=rrange(-1.1,1.1);a.userData.turn=rrange(2,7);}
    const nx=a.position.x+Math.sin(a.userData.dir)*dt*2.2;
    const nz=a.position.z+Math.cos(a.userData.dir)*dt*2.2;
    const r=Math.hypot(nx,nz);
    if(r>820||r<120||collides(nx,nz)){a.userData.dir+=Math.PI*.7;continue;}
    a.position.x=nx;a.position.z=nz;
    const ground=terrainHeight(nx,nz);
    if(a.userData.motion)applyStormtrooperMotion(a,dt,1,2.2,false,ground);
    else a.position.y=ground+a.userData.groundOffset;
    a.rotation.y=a.userData.dir+a.userData.forwardOffset;
  }
}

let yaw=0, pitch=-0.16;
const player = new THREE.Group();
const bodyMat=new THREE.MeshStandardMaterial({color:0x2c3131,roughness:.8});
const torso=new THREE.Mesh(new THREE.CapsuleGeometry(2.2,5.8,4,8),bodyMat); torso.position.y=5.2; torso.castShadow=true; player.add(torso);
const head=new THREE.Mesh(new THREE.SphereGeometry(1.7,12,10),new THREE.MeshStandardMaterial({color:0x8b6956,roughness:1})); head.position.y=10.2; head.castShadow=true; player.add(head);
const rifle=new THREE.Mesh(new THREE.BoxGeometry(.7,.7,6),new THREE.MeshStandardMaterial({color:0x24272a,metalness:.55,roughness:.45})); rifle.position.set(2.4,6.5,-1.6); rifle.rotation.x=.2; player.add(rifle);
// The procedural fallback faces -Z, while the imported SWG character faces +Z.
// Start the fallback aligned with the direction the camera/player considers forward.
player.rotation.y = facingRotation(yaw,false);
scene.add(player);

const keys={};
let pointerLocked=false;
let toastTimer=0;
let gameStarted=false;
let lastShot=-99;
let lastSample=-99;
let camp=null;
let campHealTimer=0;
function toast(msg){ ui.toast.textContent=msg; ui.toast.style.opacity=1; toastTimer=2.4; }
function requestPointerLockSafe(){
  try{
    const result=renderer.domElement.requestPointerLock();
    if(result&&typeof result.catch==='function')result.catch(()=>{});
  }catch{}
}

const systemsUI=createSystemsUI({
  character,
  seed:WORLD_SEED,
  onToast:toast,
  onPanelChange:(open)=>{ if(open && document.pointerLockElement) document.exitPointerLock(); }
});

document.addEventListener('keydown',e=>{
  if(['KeyI','KeyK','KeyC','KeyM'].includes(e.code)) e.preventDefault();
  keys[e.code]=true;
  if(e.repeat)return;
  if(e.code==='KeyI') systemsUI.toggle('inventory');
  if(e.code==='KeyK') systemsUI.toggle('skills');
  if(e.code==='KeyC') systemsUI.toggle('crafting');
  if(e.code==='KeyM') systemsUI.toggle('missions');
  if(e.code==='KeyQ' && !systemsUI.isOpen) survey();
  if(e.code==='KeyH' && !systemsUI.isOpen) sampleResource();
  if(e.code==='KeyE' && !systemsUI.isOpen) interact();
  if(e.code==='Digit1' && !systemsUI.isOpen) useMedkit();
  if(e.code==='KeyB' && !systemsUI.isOpen) deployCamp();
  if(e.code==='KeyR' && !systemsUI.isOpen) location.href=`?seed=${Math.floor(Math.random()*900000+1)}`;
  if(e.code==='Escape' && systemsUI.isOpen) systemsUI.close();
});
document.addEventListener('keyup',e=>keys[e.code]=false);
document.addEventListener('mousemove',e=>{
  if(!pointerLocked || systemsUI.isOpen)return;
  yaw-=e.movementX*.0023; pitch-=e.movementY*.0018; pitch=THREE.MathUtils.clamp(pitch,-1.05,1.22);
});
document.addEventListener('pointerlockchange',()=>pointerLocked=document.pointerLockElement===renderer.domElement);
renderer.domElement.addEventListener('mousedown',e=>{
  if(systemsUI.isOpen)return;
  if(!pointerLocked){requestPointerLockSafe();return;}
  if(e.button===0) fire();
});
ui.startButton.addEventListener('click',()=>{
  ui.startCard.classList.add('hidden');
  gameStarted=true;
  requestPointerLockSafe();
});

const interactionPoints=[];
function addTerminal(x,z,color,type,label){
  const group=new THREE.Group();
  const base=new THREE.Mesh(new THREE.BoxGeometry(7,8,7),materials.terminal);
  base.position.y=4; group.add(base);
  const screen=new THREE.Mesh(new THREE.BoxGeometry(4.8,2.3,.45),new THREE.MeshStandardMaterial({color:0x222222,emissive:color,emissiveIntensity:2}));
  screen.position.set(0,5.2,-3.7); group.add(screen);
  group.position.set(x,terrainHeight(x,z),z); scene.add(group);
  interactionPoints.push({type,label,x,z,group});
}
function buildHubs(){
  addTerminal(130,25,0x37d8ff,'vendor','Keshar Supply Kiosk');
  addTerminal(-130,25,0xffc55e,'mission','Keshar Mission Terminal');
}

const enemies=[];
let kills=0;
function spawnDrones(){
  const mat=new THREE.MeshStandardMaterial({color:0x903c2f,metalness:.65,roughness:.3,emissive:0x230000});
  for(let i=0;i<12;i++){
    const g=new THREE.Group();
    const core=new THREE.Mesh(new THREE.SphereGeometry(2.3,12,10),mat); g.add(core);
    const bar=new THREE.Mesh(new THREE.BoxGeometry(8,.7,1.2),mat); g.add(bar);
    const a=rrange(0,Math.PI*2),rad=rrange(260,840),x=Math.cos(a)*rad,z=Math.sin(a)*rad;
    g.position.set(x,terrainHeight(x,z)+rrange(14,25),z);
    g.userData.phase=rrange(0,10); g.userData.alive=true; g.userData.hp=3; g.userData.maxHp=3; g.userData.lastAttack=rrange(-3,0); g.userData.salvaged=false; g.userData.scrap=Math.floor(rrange(1,4)); scene.add(g); enemies.push(g);
  }
  ui.drones.textContent=`${kills} / ${enemies.length}`;
}

const raycaster=new THREE.Raycaster();
const blasterBolts=[];
function addShotLine(start,end,color=0xffd6a0,duration=70){
  const geo=new THREE.BufferGeometry().setFromPoints([start,end]);
  const line=new THREE.Line(geo,new THREE.LineBasicMaterial({color,transparent:true,opacity:.9}));
  scene.add(line);
  setTimeout(()=>{scene.remove(line);geo.dispose();line.material.dispose()},duration);
}
function blasterMuzzleWorld(){
  if(localStormtrooperAvatar){
    if(localStormtrooperAvatar.userData.blasterMuzzle){
      return localStormtrooperAvatar.userData.blasterMuzzle.getWorldPosition(new THREE.Vector3());
    }
    // Static/capsule fallback or an older local manifest without a weapon.
    return localStormtrooperAvatar.localToWorld(new THREE.Vector3(-.29,1.27,.31));
  }
  return rifle.localToWorld(new THREE.Vector3(0,0,-3.05));
}
function reportBlasterBoltCount(){
  if(typeof window!=='undefined')window.__farHorizonBlasterBolts=blasterBolts.length;
}
function spawnBlasterBolt(start,end){
  const flight=createBoltFlight(start.toArray(),end.toArray(),360);
  const bolt=new THREE.Mesh(
    new THREE.CylinderGeometry(.14,.14,2.4,8),
    new THREE.MeshBasicMaterial({color:0xff3b24,toneMapped:false}),
  );
  bolt.position.copy(start);
  bolt.quaternion.setFromUnitVectors(
    new THREE.Vector3(0,1,0),
    new THREE.Vector3().fromArray(flight.direction),
  );
  bolt.userData.flight=flight;
  const glow=new THREE.PointLight(0xff3525,3.5,7);
  bolt.add(glow);
  scene.add(bolt);
  blasterBolts.push(bolt);
  reportBlasterBoltCount();
}
function updateBlasterBolts(dt){
  for(let i=blasterBolts.length-1;i>=0;i--){
    const bolt=blasterBolts[i];
    const result=advanceBolt(bolt.userData.flight,dt);
    bolt.position.fromArray(result.position);
    if(result.done){
      scene.remove(bolt);
      bolt.geometry.dispose();
      bolt.material.dispose();
      blasterBolts.splice(i,1);
    }
  }
  reportBlasterBoltCount();
}
function fire(){
  const now=performance.now()/1000;
  if(now-lastShot<character.fireCooldown())return;
  lastShot=now;
  const muzzle=blasterMuzzleWorld();
  raycaster.setFromCamera(new THREE.Vector2(0,0),camera);
  const targets=enemies.filter(e=>e.userData.alive).flatMap(e=>e.children);
  const hits=raycaster.intersectObjects(targets,false);
  let end=camera.position.clone().add(raycaster.ray.direction.clone().multiplyScalar(180));
  if(hits.length){
    end.copy(hits[0].point);
    const enemy=enemies.find(e=>e.children.includes(hits[0].object));
    if(enemy){
      enemy.userData.hp-=character.weaponDamage();
      if(enemy.userData.hp<=0){
        enemy.userData.alive=false;
        kills++;
        character.recordDroneKill();
        ui.drones.textContent=`${kills} / ${enemies.length}`;
        enemy.children.forEach(m=>{
          m.material=m.material.clone();
          m.material.color.setHex(0x3c3532);
          m.material.emissive.setHex(0x000000);
        });
        toast(`Patrol drone disabled · ${enemy.userData.scrap} salvage available`);
      } else toast(`Drone armor ${Math.ceil(enemy.userData.hp)} / ${enemy.userData.maxHp}`);
    }
  }
  spawnBlasterBolt(muzzle,end);
  addShotLine(muzzle,end,0xff3b24,90);
  if(localStormtrooperAvatar)triggerLocomotionRecoil(localStormtrooperAvatar.userData.motion);
}

const deposits=[
  {id:'ferric',x:-640,z:510,quality:82},
  {id:'basalt',x:720,z:-430,quality:93},
  {id:'salts',x:1050,z:830,quality:76},
  {id:'biofiber',x:-1020,z:-720,quality:88},
  {id:'ferric',x:430,z:980,quality:90},
  {id:'basalt',x:-920,z:1010,quality:84},
  {id:'salts',x:880,z:620,quality:91},
  {id:'biofiber',x:-420,z:-960,quality:79},
];
function buildResourceMeshes(){
  for(const d of deposits){
    const cat=RESOURCE_CATALOG[d.id];
    d.stats={};
    for(const [k,v] of Object.entries(cat.stats)) d.stats[k]=THREE.MathUtils.clamp(v+Math.floor(rrange(-8,9)),1,99);
    d.quality=THREE.MathUtils.clamp(d.quality+Math.floor(rrange(-5,6)),55,99);
    d.remaining=250; d.revealedUntil=0;
    d.mesh=new THREE.Mesh(
      new THREE.DodecahedronGeometry(4.5,1),
      new THREE.MeshStandardMaterial({color:new THREE.Color(cat.color),roughness:.7,metalness:.15,emissive:new THREE.Color(cat.color),emissiveIntensity:.06})
    );
    d.mesh.position.set(d.x,terrainHeight(d.x,d.z)+3,d.z);
    d.mesh.visible=false;
    scene.add(d.mesh);
  }
}
function nearestDeposit(max=Infinity){
  let best=null,bestD=Infinity;
  for(const d of deposits){
    const dist=Math.hypot(player.position.x-d.x,player.position.z-d.z);
    if(dist<bestD&&dist<=max){bestD=dist;best=d;}
  }
  return {deposit:best,distance:bestD};
}
let scanReady=true;
function survey(){
  if(!scanReady)return;
  scanReady=false; ui.scan.textContent='Pulsing…';
  const range=character.surveyRange();
  const ring=new THREE.Mesh(new THREE.RingGeometry(2,4,48),new THREE.MeshBasicMaterial({color:0x8be5ff,transparent:true,opacity:.9,side:THREE.DoubleSide}));
  ring.rotation.x=-Math.PI/2; ring.position.copy(player.position); ring.position.y+=.5; scene.add(ring);
  const started=performance.now();
  const anim=()=>{
    const t=(performance.now()-started)/900;
    ring.scale.setScalar(1+t*(range/8)); ring.material.opacity=1-t;
    if(t<1)requestAnimationFrame(anim); else{scene.remove(ring);ring.geometry.dispose();ring.material.dispose();}
  }; anim();
  const found=deposits.filter(d=>Math.hypot(player.position.x-d.x,player.position.z-d.z)<=range);
  const now=performance.now()/1000;
  for(const d of found){d.revealedUntil=now+14;d.mesh.visible=true;}
  character.data.xp.scouting+=Math.max(2,found.length*2); character.save();
  if(found.length){
    found.sort((a,b)=>Math.hypot(player.position.x-a.x,player.position.z-a.z)-Math.hypot(player.position.x-b.x,player.position.z-b.z));
    const d=found[0],dist=Math.hypot(player.position.x-d.x,player.position.z-d.z),cat=RESOURCE_CATALOG[d.id];
    const detail=character.hasSkill('scout_1')?` · ${Object.entries(d.stats).map(([k,v])=>`${k} ${v}`).join(' / ')}`:'';
    toast(`${found.length} deposits found · nearest ${cat.name} · quality ${d.quality} · ${Math.round(dist)}m${detail}`);
  } else toast(`No resource signatures within ${Math.round(range)}m`);
  setTimeout(()=>{scanReady=true;ui.scan.textContent='Ready'},1800);
}
function sampleResource(){
  const now=performance.now()/1000;
  if(now-lastSample<.7)return;
  const {deposit}=nearestDeposit(55);
  if(!deposit){toast('No resource deposit close enough to sample');return;}
  if(deposit.remaining<=0){toast('This surface deposit is exhausted');return;}
  lastSample=now;
  const qty=Math.max(1,Math.floor(Math.floor(rrange(5,9))*character.harvestMultiplier()));
  const take=Math.min(qty,deposit.remaining);
  deposit.remaining-=take;
  character.addResource(deposit.id,take,deposit.quality,deposit.stats);
  character.data.xp.scouting+=3; character.save();
  const cat=RESOURCE_CATALOG[deposit.id];
  toast(`Sampled ${take} ${cat.name} · quality ${deposit.quality} · ${Math.floor(deposit.remaining)} remaining`);
  deposit.revealedUntil=now+10; deposit.mesh.visible=true;
}
function useMedkit(){
  if(character.data.health>=character.data.maxHealth){toast('Health already full');return;}
  if(!character.consumeItem('medkit',1)){toast('No medkits in inventory');return;}
  const healed=character.heal(character.medkitHeal());
  character.data.xp.medical+=4; character.save();
  toast(`Field treatment restored ${Math.round(healed)} health`);
}
function deployCamp(){
  if(!character.hasSkill('scout_2')){toast('Train Scout: Field Harvesting to deploy camps');return;}
  if(!character.consumeItem('campKit',1)){toast('You need a crafted Field Camp Kit');return;}
  if(camp){scene.remove(camp);camp=null;}
  const g=new THREE.Group();
  const pad=new THREE.Mesh(new THREE.CylinderGeometry(12,12,1,16),new THREE.MeshStandardMaterial({color:0x56493d,roughness:1}));
  pad.position.y=.5; g.add(pad);
  const tent=new THREE.Mesh(new THREE.ConeGeometry(6,6,4),new THREE.MeshStandardMaterial({color:0x6f604c,roughness:1}));
  tent.position.set(-3,3,0); tent.rotation.y=Math.PI/4; g.add(tent);
  const lamp=new THREE.PointLight(0xffb36c,16,28); lamp.position.set(5,5,2); g.add(lamp);
  const x=player.position.x,z=player.position.z; g.position.set(x,terrainHeight(x,z),z); scene.add(g); camp=g;
  toast('Field camp deployed · rest nearby to recover health');
}
function nearestDestroyedDrone(max=18){
  let best=null,bestD=Infinity;
  for(const e of enemies){
    if(e.userData.alive||e.userData.salvaged)continue;
    const d=Math.hypot(player.position.x-e.position.x,player.position.z-e.position.z);
    if(d<bestD&&d<=max){best=e;bestD=d;}
  }
  return best;
}
function nearestInteractionPoint(max=18){
  let best=null,bestD=Infinity;
  for(const p of interactionPoints){
    const d=Math.hypot(player.position.x-p.x,player.position.z-p.z);
    if(d<bestD&&d<=max){best=p;bestD=d;}
  }
  return best;
}
function interact(){
  const wreck=nearestDestroyedDrone();
  if(wreck){
    wreck.userData.salvaged=true; character.recordSalvage(wreck.userData.scrap); wreck.visible=false;
    toast(`Recovered ${wreck.userData.scrap} droid scrap`); return;
  }
  const point=nearestInteractionPoint();
  if(point){
    if(point.type==='vendor')systemsUI.openVendor(); else systemsUI.toggle('missions');
    return;
  }
  toast('Nothing nearby to interact with');
}
function respawn(){
  character.revive();
  player.position.set(40,terrainHeight(40,1150),1150);
  toast('Recovered at the South Ridge field station · 25 credit recovery fee');
}

function collides(x,z){ for(const b of blockers) if(Math.abs(x-b.x)<b.hw && Math.abs(z-b.z)<b.hd) return true; return false; }
function updatePlayer(dt){
  if(!gameStarted||systemsUI.isOpen)return;
  const f=(keys.KeyW?1:0)-(keys.KeyS?1:0), s=(keys.KeyD?1:0)-(keys.KeyA?1:0);
  const sprinting=keys.ShiftLeft||keys.ShiftRight;
  const speed=sprinting?34:18;
  if(f||s){
    const len=Math.hypot(f,s), ff=f/len, ss=s/len;
    // Camera-relative movement. Horizontal camera forward is (sin(yaw), cos(yaw)).
    // Its screen-right vector is forward x world-up = (-cos(yaw), sin(yaw)).
    // This keeps W toward the reticle and A/D on the correct visual side of the screen.
    const dx=(Math.sin(yaw)*ff-Math.cos(yaw)*ss)*speed*dt;
    const dz=(Math.cos(yaw)*ff+Math.sin(yaw)*ss)*speed*dt;
    if(!collides(player.position.x+dx,player.position.z))player.position.x+=dx;
    if(!collides(player.position.x,player.position.z+dz))player.position.z+=dz;
    // Face the actual travel vector, including S/A/D. Using camera yaw here
    // made the avatar slide or appear to walk backward when strafing or
    // reversing because the imported SWG body is authored +Z-forward.
    const moveYaw=Math.atan2(dx,dz);
    player.rotation.y=facingRotation(moveYaw,!!localStormtrooperPrototype);
  }
  if(localStormtrooperAvatar)applyStormtrooperMotion(localStormtrooperAvatar,dt,Math.hypot(f,s),speed,sprinting);
  player.position.y=terrainHeight(player.position.x,player.position.z);
  player.position.x=THREE.MathUtils.clamp(player.position.x,-1550,1550); player.position.z=THREE.MathUtils.clamp(player.position.z,-1550,1550);
  const r=Math.hypot(player.position.x,player.position.z);
  ui.location.textContent=r<220?'Keshar Starport':r<800?'Keshar City':r<1100?'Industrial Outskirts':player.position.z>850?'South Ridge':'Open Desert';
}

function updateCamera(){
  const distance=22, height=12;
  const target=player.position.clone().add(new THREE.Vector3(0,7,0));
  const offset=new THREE.Vector3(-Math.sin(yaw)*Math.cos(pitch)*distance, height+Math.sin(-pitch)*distance, -Math.cos(yaw)*Math.cos(pitch)*distance);
  camera.position.lerp(target.clone().add(offset),.16); camera.lookAt(target.clone().add(new THREE.Vector3(Math.sin(yaw)*18,Math.sin(pitch)*18,Math.cos(yaw)*18)));
}

function droneAttack(e,now){
  const dist=e.position.distanceTo(player.position);
  if(dist>150||now-e.userData.lastAttack<2.2||!gameStarted||systemsUI.isOpen)return;
  e.userData.lastAttack=now;
  const hitChance=THREE.MathUtils.clamp(1-dist/230,.25,.8);
  const start=e.position.clone(),end=player.position.clone().add(new THREE.Vector3(0,6,0));
  if(Math.random()<hitChance){
    addShotLine(start,end,0xff5c45,120);
    const remaining=character.damage(7);
    if(remaining<=0)respawn(); else toast(`Patrol hit · ${Math.ceil(remaining)} health`);
  } else {
    end.add(new THREE.Vector3(rrange(-8,8),rrange(-4,8),rrange(-8,8)));
    addShotLine(start,end,0xff5c45,120);
  }
}
function updatePrompt(){
  let text='';
  const wreck=nearestDestroyedDrone();
  if(wreck) text=`E · salvage wreck (${wreck.userData.scrap} scrap)`;
  else {
    const point=nearestInteractionPoint();
    if(point) text=`E · ${point.label}`;
    else {
      const {deposit,distance}=nearestDeposit(55);
      if(deposit&&deposit.remaining>0) text=`H · hand-sample ${RESOURCE_CATALOG[deposit.id].name} (${Math.round(distance)}m)`;
    }
  }
  ui.prompt.textContent=text; ui.prompt.style.opacity=text?1:0;
}
function updateWorld(t,dt){
  traffic.forEach((s,i)=>{s.position.addScaledVector(s.userData.velocity,dt); if(Math.abs(s.position.x)>1700)s.userData.velocity.x*=-1;if(Math.abs(s.position.z)>1700)s.userData.velocity.z*=-1;});
  updateBlasterBolts(dt);
  const now=performance.now()/1000;
  enemies.forEach((e,i)=>{
    if(e.userData.alive){
      e.position.y=terrainHeight(e.position.x,e.position.z)+18+Math.sin(t*1.7+e.userData.phase)*3;
      e.rotation.y=t*.5+i;
      droneAttack(e,now);
    } else if(!e.userData.salvaged){
      e.position.y=THREE.MathUtils.lerp(e.position.y,terrainHeight(e.position.x,e.position.z)+2.5,.025);
      e.rotation.z=THREE.MathUtils.lerp(e.rotation.z,1.1,.02);
    }
  });
  for(const d of deposits){
    if(d.mesh.visible && now>d.revealedUntil)d.mesh.visible=false;
    if(d.mesh.visible)d.mesh.rotation.y+=dt*.8;
  }
  if(camp){
    campHealTimer+=dt;
    const d=Math.hypot(player.position.x-camp.position.x,player.position.z-camp.position.z);
    if(d<30&&campHealTimer>=1&&character.data.health<character.data.maxHealth){
      campHealTimer=0; character.heal(3);
    }
  }
  updateCrowd(dt);
  updatePrompt();
  if(toastTimer>0){toastTimer-=dt;if(toastTimer<=0)ui.toast.style.opacity=0;}
}

function addAtmosphere(){
  const sunDisc=new THREE.Mesh(new THREE.SphereGeometry(70,24,16),new THREE.MeshBasicMaterial({color:0xffd18b})); sunDisc.position.set(-1150,520,-2400); scene.add(sunDisc);
  const moon=new THREE.Mesh(new THREE.SphereGeometry(28,18,12),new THREE.MeshBasicMaterial({color:0xf1c88f})); moon.position.set(-850,440,-2300); scene.add(moon);
}

buildTerrain(); buildCity(); await addLocalSwgMesh(); await addLocalSwgCharacter(); buildSkyTraffic(); buildCrowd(); buildHubs(); buildResourceMeshes(); spawnDrones(); addAtmosphere();
player.position.set(40,terrainHeight(40,1150),1150);

const clock=new THREE.Clock();
function loop(){
  requestAnimationFrame(loop); const dt=Math.min(clock.getDelta(),.05),t=clock.elapsedTime;
  updatePlayer(dt); updateCamera(); updateWorld(t,dt); renderer.render(scene,camera);
}
loop();

addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
