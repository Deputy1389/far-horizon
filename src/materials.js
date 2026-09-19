import * as THREE from 'https://unpkg.com/three@0.180.0/build/three.module.js';
import { DDSLoader } from 'https://unpkg.com/three@0.180.0/examples/jsm/loaders/DDSLoader.js';

function seeded(seed=1){
  let s=seed>>>0;
  return ()=>{ s=(Math.imul(s,1664525)+1013904223)>>>0; return s/4294967296; };
}
function colorRGB(hex){
  const c=new THREE.Color(hex);
  return [Math.round(c.r*255),Math.round(c.g*255),Math.round(c.b*255)];
}
function clamp(v){ return Math.max(0,Math.min(255,Math.round(v))); }
function canvasTexture(size, paint, repeatX=1, repeatY=1){
  const canvas=document.createElement('canvas');
  canvas.width=canvas.height=size;
  const ctx=canvas.getContext('2d');
  paint(ctx,size);
  const tex=new THREE.CanvasTexture(canvas);
  tex.wrapS=tex.wrapT=THREE.RepeatWrapping;
  tex.repeat.set(repeatX,repeatY);
  tex.colorSpace=THREE.SRGBColorSpace;
  tex.needsUpdate=true;
  return tex;
}
function monoTexture(size, paint, repeatX=1, repeatY=1){
  const tex=canvasTexture(size,paint,repeatX,repeatY);
  tex.colorSpace=THREE.NoColorSpace;
  return tex;
}
function fillNoise(ctx,size,base,seed,amount=22){
  const rand=seeded(seed);
  const [r,g,b]=colorRGB(base);
  const img=ctx.createImageData(size,size);
  for(let i=0;i<img.data.length;i+=4){
    const coarse=(rand()-.5)*amount;
    const fine=(rand()-.5)*amount*.45;
    img.data[i]=clamp(r+coarse+fine);
    img.data[i+1]=clamp(g+coarse*.82+fine);
    img.data[i+2]=clamp(b+coarse*.58+fine);
    img.data[i+3]=255;
  }
  ctx.putImageData(img,0,0);
}
function addDust(ctx,size,seed,count=70){
  const rand=seeded(seed);
  for(let i=0;i<count;i++){
    const x=rand()*size,y=rand()*size,rx=4+rand()*34,ry=2+rand()*14;
    ctx.save();ctx.translate(x,y);ctx.rotate(rand()*Math.PI);
    ctx.fillStyle=`rgba(72,46,28,${.025+rand()*.07})`;
    ctx.beginPath();ctx.ellipse(0,0,rx,ry,0,0,Math.PI*2);ctx.fill();ctx.restore();
  }
}
function makeSand(){
  const map=canvasTexture(512,(ctx,s)=>{
    fillNoise(ctx,s,0xa97045,9138,28);
    const rand=seeded(1221);
    ctx.lineCap='round';
    for(let i=0;i<90;i++){
      const y=rand()*s;
      ctx.strokeStyle=`rgba(245,205,150,${.025+rand()*.06})`;
      ctx.lineWidth=.6+rand()*1.7;
      ctx.beginPath();ctx.moveTo(-20,y);ctx.bezierCurveTo(s*.25,y+rand()*8-4,s*.7,y+rand()*8-4,s+20,y+rand()*4-2);ctx.stroke();
    }
    for(let i=0;i<180;i++){
      const rr=rand()*2.2+.4;
      ctx.fillStyle=rand()>.5?'rgba(84,54,38,.16)':'rgba(222,165,103,.16)';
      ctx.beginPath();ctx.arc(rand()*s,rand()*s,rr,0,Math.PI*2);ctx.fill();
    }
    addDust(ctx,s,3451,55);
  },34,34);
  const bump=monoTexture(256,(ctx,s)=>{
    const rand=seeded(2718),img=ctx.createImageData(s,s);
    for(let i=0;i<img.data.length;i+=4){
      const v=clamp(128+(rand()-.5)*52);
      img.data[i]=img.data[i+1]=img.data[i+2]=v;img.data[i+3]=255;
    }
    ctx.putImageData(img,0,0);
  },34,34);
  return {map,bump};
}
function makeRock(){
  const map=canvasTexture(256,(ctx,s)=>{
    fillNoise(ctx,s,0x654531,8123,38);
    const rand=seeded(4499);
    for(let i=0;i<90;i++){
      ctx.strokeStyle=`rgba(35,25,19,${.05+rand()*.12})`;
      ctx.lineWidth=.4+rand()*1.3;
      ctx.beginPath();const x=rand()*s,y=rand()*s;ctx.moveTo(x,y);ctx.lineTo(x+rand()*28-14,y+rand()*24-12);ctx.stroke();
    }
  },4,4);
  return map;
}
function makeRoad(){
  return canvasTexture(256,(ctx,s)=>{
    fillNoise(ctx,s,0x5c5147,4001,24);
    const rand=seeded(9801);
    // dusty wheel traffic
    for(const x of [s*.22,s*.38,s*.62,s*.78]){
      const grad=ctx.createLinearGradient(x-12,0,x+12,0);
      grad.addColorStop(0,'rgba(30,26,23,0)');grad.addColorStop(.5,'rgba(30,26,23,.18)');grad.addColorStop(1,'rgba(30,26,23,0)');
      ctx.fillStyle=grad;ctx.fillRect(x-13,0,26,s);
    }
    // patched sections
    for(let i=0;i<18;i++){
      const x=rand()*s,y=rand()*s,w=15+rand()*45,h=4+rand()*18;
      ctx.fillStyle=`rgba(34,32,31,${.05+rand()*.08})`;ctx.fillRect(x,y,w,h);
    }
    // cracks
    for(let i=0;i<22;i++){
      let x=rand()*s,y=rand()*s;
      ctx.strokeStyle='rgba(28,25,22,.24)';ctx.lineWidth=.7;ctx.beginPath();ctx.moveTo(x,y);
      for(let j=0;j<4;j++){x+=rand()*14-7;y+=6+rand()*13;ctx.lineTo(x,y);}ctx.stroke();
    }
    addDust(ctx,s,2331,35);
  });
}
function makeMetal(base=0x4d5458,seed=7331){
  return canvasTexture(256,(ctx,s)=>{
    fillNoise(ctx,s,base,seed,16);
    const rand=seeded(seed+71);
    // panel seams
    ctx.strokeStyle='rgba(17,20,22,.30)';ctx.lineWidth=2;
    for(let x=0;x<=s;x+=64){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,s);ctx.stroke();}
    for(let y=0;y<=s;y+=64){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(s,y);ctx.stroke();}
    ctx.strokeStyle='rgba(220,225,220,.13)';ctx.lineWidth=1;
    for(let x=1;x<=s;x+=64){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,s);ctx.stroke();}
    // rivets and rust
    for(let x=8;x<s;x+=32)for(let y=8;y<s;y+=32){
      ctx.fillStyle='rgba(20,22,22,.45)';ctx.beginPath();ctx.arc(x,y,1.25,0,Math.PI*2);ctx.fill();
    }
    for(let i=0;i<34;i++){
      ctx.fillStyle=`rgba(115,58,33,${.04+rand()*.14})`;
      ctx.beginPath();ctx.arc(rand()*s,rand()*s,1+rand()*6,0,Math.PI*2);ctx.fill();
    }
  },3,3);
}
function makeFacade(base,seed){
  return canvasTexture(256,(ctx,s)=>{
    fillNoise(ctx,s,base,seed,20);
    const rand=seeded(seed+300);
    // plaster bands / repaired patches
    for(let i=0;i<20;i++){
      const x=rand()*s,y=rand()*s,w=12+rand()*60,h=6+rand()*28;
      ctx.fillStyle=rand()>.5?'rgba(245,224,188,.035)':'rgba(70,48,34,.045)';
      ctx.fillRect(x,y,w,h);
    }
    // inset windows / vents; warm windows are sparse
    for(let row=0;row<4;row++)for(let col=0;col<4;col++){
      if(rand()<.26)continue;
      const x=15+col*61+(rand()*4-2),y=18+row*59+(rand()*4-2);
      const lit=rand()<.17;
      ctx.fillStyle=lit?'rgba(255,190,92,.75)':'rgba(35,39,40,.72)';
      ctx.fillRect(x,y,24,10);
      ctx.strokeStyle='rgba(30,24,20,.5)';ctx.strokeRect(x-.5,y-.5,25,11);
      ctx.fillStyle='rgba(225,218,195,.09)';ctx.fillRect(x+2,y+2,20,2);
    }
    addDust(ctx,s,seed+901,30);
  },2.5,2.5);
}
function makeRoof(base,seed){
  return canvasTexture(256,(ctx,s)=>{
    fillNoise(ctx,s,base,seed,18);
    const rand=seeded(seed+14);
    ctx.strokeStyle='rgba(45,39,33,.20)';ctx.lineWidth=1.5;
    for(let x=0;x<s;x+=42){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,s);ctx.stroke();}
    for(let i=0;i<24;i++){
      ctx.fillStyle='rgba(80,57,38,.08)';
      ctx.beginPath();ctx.arc(rand()*s,rand()*s,3+rand()*16,0,Math.PI*2);ctx.fill();
    }
  },2.2,2.2);
}
function makePad(){
  return canvasTexture(512,(ctx,s)=>{
    fillNoise(ctx,s,0x4b4d4c,7712,20);
    ctx.translate(s/2,s/2);
    for(const [radius,width,alpha] of [[205,8,.55],[150,3,.4],[78,5,.45]]){
      ctx.strokeStyle=`rgba(211,184,122,${alpha})`;ctx.lineWidth=width;ctx.beginPath();ctx.arc(0,0,radius,0,Math.PI*2);ctx.stroke();
    }
    ctx.strokeStyle='rgba(235,209,151,.52)';ctx.lineWidth=7;
    for(let i=0;i<8;i++){const a=i*Math.PI/4;ctx.beginPath();ctx.moveTo(Math.cos(a)*100,Math.sin(a)*100);ctx.lineTo(Math.cos(a)*215,Math.sin(a)*215);ctx.stroke();}
    ctx.rotate(-.1);ctx.fillStyle='rgba(220,193,137,.4)';ctx.fillRect(-62,-12,124,24);
  });
}
function makeShip(){
  return canvasTexture(512,(ctx,s)=>{
    fillNoise(ctx,s,0x4b555b,6201,18);
    const rand=seeded(421);
    ctx.strokeStyle='rgba(18,24,28,.40)';ctx.lineWidth=2;
    const cell=64;
    for(let x=0;x<=s;x+=cell){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,s);ctx.stroke();}
    for(let y=0;y<=s;y+=cell){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(s,y);ctx.stroke();}
    // irregular hull plates
    for(let i=0;i<24;i++){
      const x=Math.floor(rand()*8)*cell,y=Math.floor(rand()*8)*cell,w=cell*(1+Math.floor(rand()*2)),h=cell*(1+Math.floor(rand()*2));
      ctx.fillStyle=rand()>.5?'rgba(220,230,228,.035)':'rgba(10,15,18,.055)';ctx.fillRect(x+3,y+3,w-6,h-6);
    }
    // faded identification/caution stripes
    ctx.fillStyle='rgba(171,112,62,.52)';
    for(let i=-s;i<s*2;i+=52){ctx.save();ctx.translate(i,s*.76);ctx.rotate(-.65);ctx.fillRect(0,0,18,96);ctx.restore();}
    addDust(ctx,s,553,45);
  },2,2);
}

async function loadLocalSwgTextures(prep){
  let manifest;
  try{
    const response=await fetch('./assets/local-swg/manifest.json',{cache:'no-store'});
    if(!response.ok)return null;
    manifest=await response.json();
  }catch{return null;}
  const loader=new DDSLoader();
  const result={};
  const entries=Object.entries(manifest.assets||{});
  await Promise.all(entries.map(([role,url])=>new Promise(resolve=>{
    loader.load(url,tex=>{
      tex.wrapS=tex.wrapT=THREE.RepeatWrapping;
      tex.colorSpace=role.toLowerCase().includes('normal')?THREE.NoColorSpace:THREE.SRGBColorSpace;
      prep(tex);result[role]=tex;resolve();
    },undefined,()=>resolve());
  })));
  return Object.keys(result).length?result:null;
}

export async function createMaterialLibrary(renderer){
  const maxAniso=Math.min(8,renderer.capabilities.getMaxAnisotropy());
  const prep=(t)=>{ if(t){t.anisotropy=maxAniso;t.needsUpdate=true;} return t; };
  const local=await loadLocalSwgTextures(prep);

  const sand=makeSand(); prep(sand.map); prep(sand.bump);
  const rock=prep(makeRock());
  const road=prep(makeRoad());
  const metal=prep(makeMetal());
  const ship=prep(makeShip());
  const pad=prep(makePad());
  const facadeCache=new Map();

  const terrainMap=local?.sand||sand.map;
  const terrainNormal=local?.sandNormal||null;
  if(local?.sand){terrainMap.repeat.set(42,42);}
  if(terrainNormal){terrainNormal.repeat.set(42,42);}
  const wallA=local?.wall||null;
  const wallB=local?.capitalWall||wallA;
  const floor=local?.floor||null;
  const concrete=local?.concrete||null;
  const metalMap=local?.metal||metal;

  function localClone(tex,repeat=2){
    if(!tex)return null;
    const t=tex.clone();t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(repeat,repeat);prep(t);return t;
  }

  function building(hex){
    const key=Number(hex);
    if(facadeCache.has(key))return facadeCache.get(key);
    const useSwg=!!wallA;
    const source=(key%2===0?wallA:wallB)||wallA;
    const sideTex=useSwg?localClone(source,2.2):prep(makeFacade(key,4000+key%997));
    const roofTex=floor?localClone(floor,2.4):prep(makeRoof(key,7000+key%991));
    const side=new THREE.MeshStandardMaterial({
      map:sideTex,
      color:useSwg?new THREE.Color(hex).lerp(new THREE.Color(0xffffff),.72):0xffffff,
      roughness:.93,
      metalness:.01,
    });
    const roof=new THREE.MeshStandardMaterial({
      map:roofTex,
      color:floor?0xbca98e:0xe0d2bb,
      roughness:.98,
      metalness:.01,
    });
    const arr=[side,side,roof,roof,side,side];
    facadeCache.set(key,arr);
    return arr;
  }

  return {
    usesSwgAssets:!!local,
    swgAssetCount:local?Object.keys(local).length:0,
    terrain:new THREE.MeshStandardMaterial({
      map:terrainMap,
      color:local?.sand?0xd0a16f:0xffffff,
      roughness:1,
      metalness:0,
      normalMap:terrainNormal,
      normalScale:terrainNormal?new THREE.Vector2(.7,.7):undefined,
      bumpMap:terrainNormal?null:sand.bump,
      bumpScale:terrainNormal?0:2.1
    }),
    rock:new THREE.MeshStandardMaterial({
      map:concrete?localClone(concrete,2.5):rock,
      color:concrete?0x806854:0xffffff,
      roughness:.96,
      metalness:.02
    }),
    building,
    roadTexture:road,
    metal:new THREE.MeshStandardMaterial({map:metalMap,color:local?.metal?0xb1aaa0:0xd1d1ca,metalness:.68,roughness:.48}),
    antenna:new THREE.MeshStandardMaterial({map:metalMap,color:0x55504a,metalness:.75,roughness:.42}),
    ship:new THREE.MeshStandardMaterial({map:local?.metal?metalMap:ship,color:0xc0c7c8,metalness:.78,roughness:.38,bumpMap:local?.metal?null:ship,bumpScale:.08}),
    pad:new THREE.MeshStandardMaterial({map:local?.floor?localClone(floor,3):pad,color:local?.floor?0x8f8778:0xc2b9a9,metalness:.3,roughness:.72}),
    roadMaterial(w,d){
      const base=local?.floor||road;
      const tex=base.clone();
      tex.wrapS=tex.wrapT=THREE.RepeatWrapping;
      tex.repeat.set(Math.max(1,w/18),Math.max(1,d/18));
      tex.anisotropy=maxAniso;tex.needsUpdate=true;
      return new THREE.MeshStandardMaterial({map:tex,color:local?.floor?0x72695f:0xb8aa98,roughness:.98,metalness:.02,bumpMap:local?.floor?null:tex,bumpScale:.08});
    },
    terminal:new THREE.MeshStandardMaterial({map:metalMap,color:0x74716a,metalness:.62,roughness:.46}),
  };
}
