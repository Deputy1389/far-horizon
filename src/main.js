import * as THREE from 'https://unpkg.com/three@0.180.0/build/three.module.js';

const WORLD_SIZE = 3200;
const CITY_RADIUS = 900;
const seedParam = Number(new URLSearchParams(location.search).get('seed'));
let WORLD_SEED = Number.isFinite(seedParam) && seedParam > 0 ? Math.floor(seedParam) : 1389;

const ui = {
  seed: document.getElementById('seedLabel'),
  location: document.getElementById('locationLabel'),
  scan: document.getElementById('scanLabel'),
  drones: document.getElementById('droneLabel'),
  toast: document.getElementById('toast'),
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
document.getElementById('game').appendChild(renderer.domElement);

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
  const mat = new THREE.MeshStandardMaterial({ color: 0xa86e43, roughness: 1, metalness: 0 });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = true;
  scene.add(mesh);

  const rockMat = new THREE.MeshStandardMaterial({ color: 0x6e4833, roughness: 1 });
  const rockGeo = new THREE.DodecahedronGeometry(1, 0);
  const rocks = new THREE.InstancedMesh(rockGeo, rockMat, 260);
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
  const mat = new THREE.MeshStandardMaterial({ color, roughness:.87, metalness:.05 });
  const y = terrainHeight(x,z) + h/2 + yOffset;
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.set(x,y,z);
  mesh.castShadow = true; mesh.receiveShadow = true;
  scene.add(mesh);
  blockers.push({x,z,hw:w/2+1.2,hd:d/2+1.2});
  buildingMeshes.push(mesh);
  return mesh;
}

function addRoad(x,z,w,d,rot=0) {
  const g = new THREE.PlaneGeometry(w,d); g.rotateX(-Math.PI/2);
  const m = new THREE.MeshStandardMaterial({color:0x6b5543, roughness:1});
  const road = new THREE.Mesh(g,m);
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
      const w=rrange(22,55), d=rrange(20,52);
      const h=rrange(12,32) * (1+density*2.5);
      const palette=[0xbda477,0x987a5b,0xc2b18b,0x8f7968,0xb58f66];
      const b=addBox(x,z,w,d,h,palette[Math.floor(rand()*palette.length)]);
      if (density>.55 && rand()>.62) {
        const top=addBox(x+rrange(-w*.15,w*.15),z+rrange(-d*.15,d*.15),w*.55,d*.55,rrange(5,14),0x756c63,h*.5);
        blockers.pop();
      }
      if (rand()>.7) {
        const antenna = new THREE.Mesh(new THREE.CylinderGeometry(.6,.8,rrange(10,30),6), new THREE.MeshStandardMaterial({color:0x443f3a,metalness:.6,roughness:.5}));
        antenna.position.set(x, terrainHeight(x,z)+h+8, z); scene.add(antenna);
      }
    }
  }

  // Monumental starport core.
  const port = addBox(0,0,190,190,52,0x827769);
  const tower = addBox(0,0,64,64,165,0x6d6860,52/2);
  blockers.pop();
  const ring = new THREE.Mesh(new THREE.TorusGeometry(105,8,10,48), new THREE.MeshStandardMaterial({color:0x55565b,metalness:.65,roughness:.35}));
  ring.rotation.x=Math.PI/2; ring.position.set(0,terrainHeight(0,0)+95,0); ring.castShadow=true; scene.add(ring);

  // Landing pads and grounded ships.
  for (let i=0;i<8;i++) {
    const a=i/8*Math.PI*2, rad=rrange(270,430), x=Math.cos(a)*rad,z=Math.sin(a)*rad;
    const pad=new THREE.Mesh(new THREE.CylinderGeometry(45,45,2,32),new THREE.MeshStandardMaterial({color:0x56504a,metalness:.25,roughness:.75}));
    pad.position.set(x,terrainHeight(x,z)+1,z); scene.add(pad);
    if(i%2===0) addShip(x,terrainHeight(x,z)+9,z,a+Math.PI/2,rrange(.7,1.15));
  }

  // Outskirts become progressively sparse.
  for(let i=0;i<190;i++){
    const a=rrange(0,Math.PI*2),rad=rrange(900,1450),x=Math.cos(a)*rad,z=Math.sin(a)*rad;
    if(rand()<.52){ const w=rrange(12,28),d=rrange(12,30),h=rrange(7,18); addBox(x,z,w,d,h,rand()>.5?0x9d7958:0x806653); }
  }
}

function addShip(x,y,z,rot=0,scale=1){
  const group=new THREE.Group();
  const mat=new THREE.MeshStandardMaterial({color:0x4f5559,metalness:.75,roughness:.35});
  const body=new THREE.Mesh(new THREE.BoxGeometry(30,6,70),mat); group.add(body);
  const wing=new THREE.Mesh(new THREE.BoxGeometry(68,2.5,26),mat); wing.position.z=5; group.add(wing);
  const nose=new THREE.Mesh(new THREE.ConeGeometry(8,22,6),mat); nose.rotation.x=Math.PI/2; nose.position.z=-45; group.add(nose);
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

const player = new THREE.Group();
const bodyMat=new THREE.MeshStandardMaterial({color:0x2c3131,roughness:.8});
const torso=new THREE.Mesh(new THREE.CapsuleGeometry(2.2,5.8,4,8),bodyMat); torso.position.y=5.2; torso.castShadow=true; player.add(torso);
const head=new THREE.Mesh(new THREE.SphereGeometry(1.7,12,10),new THREE.MeshStandardMaterial({color:0x8b6956,roughness:1})); head.position.y=10.2; head.castShadow=true; player.add(head);
const rifle=new THREE.Mesh(new THREE.BoxGeometry(.7,.7,6),new THREE.MeshStandardMaterial({color:0x24272a,metalness:.55,roughness:.45})); rifle.position.set(2.4,6.5,-1.6); rifle.rotation.x=.2; player.add(rifle);
// Three.js meshes conventionally face local -Z; our camera-forward basis below is +Z at yaw 0.
// Start the avatar aligned with the direction the camera/player will consider forward.
player.rotation.y = Math.PI;
scene.add(player);

let yaw=0, pitch=-0.16;
const keys={};
let pointerLocked=false;
let toastTimer=0;
function toast(msg){ ui.toast.textContent=msg; ui.toast.style.opacity=1; toastTimer=2.2; }

document.addEventListener('keydown',e=>{
  keys[e.code]=true;
  if(e.code==='KeyQ') survey();
  if(e.code==='KeyR') location.href=`?seed=${Math.floor(Math.random()*900000+1)}`;
});
document.addEventListener('keyup',e=>keys[e.code]=false);
document.addEventListener('mousemove',e=>{
  if(!pointerLocked)return;
  yaw-=e.movementX*.0023; pitch-=e.movementY*.0018; pitch=THREE.MathUtils.clamp(pitch,-1.05,1.22);
});
document.addEventListener('pointerlockchange',()=>pointerLocked=document.pointerLockElement===renderer.domElement);
renderer.domElement.addEventListener('mousedown',e=>{ if(!pointerLocked){renderer.domElement.requestPointerLock();return;} if(e.button===0) fire(); });
ui.startButton.addEventListener('click',()=>{ui.startCard.classList.add('hidden');renderer.domElement.requestPointerLock();});

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
    g.userData.phase=rrange(0,10); g.userData.alive=true; scene.add(g); enemies.push(g);
  }
  ui.drones.textContent=`${kills} / ${enemies.length}`;
}

const raycaster=new THREE.Raycaster();
function fire(){
  raycaster.setFromCamera(new THREE.Vector2(0,0),camera);
  const targets=enemies.filter(e=>e.userData.alive).flatMap(e=>e.children);
  const hits=raycaster.intersectObjects(targets,false);
  if(hits.length){
    const enemy=enemies.find(e=>e.children.includes(hits[0].object));
    if(enemy){ enemy.userData.alive=false; enemy.visible=false; kills++; ui.drones.textContent=`${kills} / ${enemies.length}`; toast('Patrol drone disabled'); }
  }
  const start=camera.position.clone(); const end=start.clone().add(raycaster.ray.direction.clone().multiplyScalar(180));
  const geo=new THREE.BufferGeometry().setFromPoints([start,end]); const line=new THREE.Line(geo,new THREE.LineBasicMaterial({color:0xffd6a0,transparent:true,opacity:.9})); scene.add(line); setTimeout(()=>{scene.remove(line);geo.dispose();line.material.dispose()},70);
}

const deposits=[
  {x:-640,z:510,name:'Ferric glass-sand',quality:82},
  {x:720,z:-430,name:'Conductive basalt',quality:93},
  {x:1050,z:830,name:'Volatile crystal salts',quality:76},
];
let scanReady=true;
function survey(){
  if(!scanReady)return;
  scanReady=false; ui.scan.textContent='Pulsing…';
  const ring=new THREE.Mesh(new THREE.RingGeometry(2,4,48),new THREE.MeshBasicMaterial({color:0x8be5ff,transparent:true,opacity:.9,side:THREE.DoubleSide}));
  ring.rotation.x=-Math.PI/2; ring.position.copy(player.position); ring.position.y+=.5; scene.add(ring);
  const started=performance.now();
  const anim=()=>{ const t=(performance.now()-started)/850; ring.scale.setScalar(1+t*55); ring.material.opacity=1-t; if(t<1)requestAnimationFrame(anim); else{scene.remove(ring);ring.geometry.dispose();ring.material.dispose();} }; anim();
  let best=null,bestD=Infinity; for(const d of deposits){const dist=Math.hypot(player.position.x-d.x,player.position.z-d.z);if(dist<bestD){bestD=dist;best=d;}}
  if(bestD<450) toast(`${best.name} · quality ${best.quality} · ${Math.round(bestD)}m`); else toast(`No strong deposit nearby · nearest anomaly ${Math.round(bestD)}m`);
  setTimeout(()=>{scanReady=true;ui.scan.textContent='Ready'},1800);
}

function collides(x,z){ for(const b of blockers) if(Math.abs(x-b.x)<b.hw && Math.abs(z-b.z)<b.hd) return true; return false; }
function updatePlayer(dt){
  const f=(keys.KeyW?1:0)-(keys.KeyS?1:0), s=(keys.KeyD?1:0)-(keys.KeyA?1:0);
  if(f||s){
    const len=Math.hypot(f,s), ff=f/len, ss=s/len; const speed=keys.ShiftLeft||keys.ShiftRight?34:18;
    // Camera-relative movement. Horizontal camera forward is (sin(yaw), cos(yaw)).
    // Its screen-right vector is forward x world-up = (-cos(yaw), sin(yaw)).
    // This keeps W toward the reticle and A/D on the correct visual side of the screen.
    const dx=(Math.sin(yaw)*ff-Math.cos(yaw)*ss)*speed*dt;
    const dz=(Math.cos(yaw)*ff+Math.sin(yaw)*ss)*speed*dt;
    if(!collides(player.position.x+dx,player.position.z))player.position.x+=dx;
    if(!collides(player.position.x,player.position.z+dz))player.position.z+=dz;
    // The placeholder avatar's modeled forward axis is -Z, so rotate it 180 degrees
    // from our yaw basis to face the same direction as the reticle/camera.
    player.rotation.y=yaw+Math.PI;
  }
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

function updateWorld(t,dt){
  traffic.forEach((s,i)=>{s.position.addScaledVector(s.userData.velocity,dt); if(Math.abs(s.position.x)>1700)s.userData.velocity.x*=-1;if(Math.abs(s.position.z)>1700)s.userData.velocity.z*=-1;});
  enemies.forEach((e,i)=>{if(!e.userData.alive)return; e.position.y=terrainHeight(e.position.x,e.position.z)+18+Math.sin(t*1.7+e.userData.phase)*3; e.rotation.y=t*.5+i;});
  if(toastTimer>0){toastTimer-=dt;if(toastTimer<=0)ui.toast.style.opacity=0;}
}

function addAtmosphere(){
  const sunDisc=new THREE.Mesh(new THREE.SphereGeometry(70,24,16),new THREE.MeshBasicMaterial({color:0xffd18b})); sunDisc.position.set(-1150,520,-2400); scene.add(sunDisc);
  const moon=new THREE.Mesh(new THREE.SphereGeometry(28,18,12),new THREE.MeshBasicMaterial({color:0xf1c88f})); moon.position.set(-850,440,-2300); scene.add(moon);
}

buildTerrain(); buildCity(); buildSkyTraffic(); spawnDrones(); addAtmosphere();
player.position.set(40,terrainHeight(40,1150),1150);

const clock=new THREE.Clock();
function loop(){
  requestAnimationFrame(loop); const dt=Math.min(clock.getDelta(),.05),t=clock.elapsedTime;
  updatePlayer(dt); updateCamera(); updateWorld(t,dt); renderer.render(scene,camera);
}
loop();

addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
