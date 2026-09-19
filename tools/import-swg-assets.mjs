import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const TARGETS = {
  sand: 'texture/tatt_sand_bumpy_a1.dds',
  sandNormal: 'texture/tatt_sand_bumpy_a1_n.dds',
  wall: 'texture/tatt_stco_player_wall.dds',
  wallDetail: 'texture/tatt_stco_player_wall_detlb.dds',
  floor: 'texture/tatt_stco_player_floor_c.dds',
  capitalWall: 'texture/intr_cptl_tatt_wall_trim_a1.dds',
  capitalStair: 'texture/intr_cptl_tatt_stair.dds',
  concrete: 'texture/impl_concrete_a.dds',
  concreteDetail: 'texture/impl_concrete_detail_a.dds',
  metal: 'texture/ins_all_metl_gray.dds',
  metalVents: 'texture/ins_all_metl_gray_vents_a1.dds',
};

function parseArgs(){
  const out={};
  for(let i=2;i<process.argv.length;i++){
    const a=process.argv[i];
    if(a==='--source'||a==='-s') out.source=process.argv[++i];
  }
  return out;
}
function candidateRoots(explicit){
  const roots=[];
  if(explicit) roots.push(explicit);
  for(const p of [
    'C:\\SWG Restoration',
    'C:\\Program Files\\SWG Restoration',
    'C:\\Program Files (x86)\\SWG Restoration',
    process.env.ProgramFiles && path.join(process.env.ProgramFiles,'SWG Restoration'),
    process.env['ProgramFiles(x86)'] && path.join(process.env['ProgramFiles(x86)'],'SWG Restoration'),
  ]) if(p) roots.push(p);
  for(const drive of 'DEFGHIJKLMNOPQRSTUVWXYZ') roots.push(`${drive}:\\SWG Restoration`);
  return [...new Set(roots)].filter(p=>fs.existsSync(p));
}
function walk(root,maxDepth=3,depth=0,out=[]){
  if(depth>maxDepth)return out;
  let entries=[];
  try{ entries=fs.readdirSync(root,{withFileTypes:true}); }catch{return out;}
  for(const e of entries){
    const full=path.join(root,e.name);
    if(e.isDirectory()) walk(full,maxDepth,depth+1,out);
    else if(e.isFile() && e.name.toLowerCase().endsWith('.tre')) out.push(full);
  }
  return out;
}
function inflateMaybe(buf,type){
  if(type===0)return buf;
  if(type===2)return zlib.inflateSync(buf);
  throw new Error(`Unsupported TRE compression type ${type}`);
}
function readArchiveIndex(file){
  const fd=fs.openSync(file,'r');
  try{
    const header=Buffer.alloc(36);
    if(fs.readSync(fd,header,0,36,0)!==36) return null;
    if(header.readUInt32LE(0)!==0x54524545) return null; // on-disk EERT / little-endian TREE
    const recordCount=header.readUInt32LE(8);
    const tocOffset=header.readUInt32LE(12);
    const tocCompression=header.readUInt32LE(16);
    const tocSize=header.readUInt32LE(20);
    const nameCompression=header.readUInt32LE(24);
    const nameSize=header.readUInt32LE(28);
    const nameUncompressed=header.readUInt32LE(32);
    if(!recordCount||recordCount>2_000_000||!tocSize||!nameSize)return null;

    const tocPacked=Buffer.alloc(tocSize);
    fs.readSync(fd,tocPacked,0,tocSize,tocOffset);
    const toc=inflateMaybe(tocPacked,tocCompression);

    const namePacked=Buffer.alloc(nameSize);
    fs.readSync(fd,namePacked,0,nameSize,tocOffset+tocSize);
    const names=inflateMaybe(namePacked,nameCompression);
    if(nameUncompressed && names.length<Math.min(nameUncompressed,32))return null;

    const stride=Math.floor(toc.length/recordCount);
    if(stride<24) return null;
    const entries=[];
    for(let i=0;i<recordCount;i++){
      const off=i*stride;
      if(off+24>toc.length)break;
      const uncompressedSize=toc.readUInt32LE(off+4);
      const fileOffset=toc.readUInt32LE(off+8);
      const compression=toc.readUInt32LE(off+12);
      const compressedSize=toc.readUInt32LE(off+16);
      const nameOffset=toc.readUInt32LE(off+20);
      if(nameOffset>=names.length)continue;
      let end=nameOffset;
      while(end<names.length&&names[end]!==0)end++;
      const virtualPath=names.toString('utf8',nameOffset,end).replaceAll('\\','/').toLowerCase();
      entries.push({virtualPath,uncompressedSize,fileOffset,compression,compressedSize});
    }
    return {fd,entries,stride,close:()=>fs.closeSync(fd)};
  }catch(err){
    try{fs.closeSync(fd);}catch{}
    return null;
  }
}
function copyLoose(root,target,dest){
  const normalized=target.split('/');
  const candidates=[
    path.join(root,...normalized),
    path.join(root,...normalized.map((p,i)=>i===0?'texture':p)),
  ];
  for(const c of candidates){
    if(fs.existsSync(c)&&fs.statSync(c).isFile()){
      fs.mkdirSync(path.dirname(dest),{recursive:true});
      fs.copyFileSync(c,dest);
      return true;
    }
  }
  return false;
}

const args=parseArgs();
const roots=candidateRoots(args.source);
if(!roots.length){
  console.error('Could not find an SWG Restoration install automatically.');
  console.error('Run: node tools/import-swg-assets.mjs --source "C:\\path\\to\\SWG Restoration"');
  process.exit(2);
}
const source=roots[0];
console.log(`Using SWG client: ${source}`);

const projectRoot=path.resolve(import.meta.dirname,'..');
const outputRoot=path.join(projectRoot,'assets','local-swg');
const textureRoot=path.join(outputRoot,'texture');
fs.mkdirSync(textureRoot,{recursive:true});

const pending=new Map(Object.entries(TARGETS));
const found={};

// Prefer loose override files when Restoration has them.
for(const [role,virtualPath] of [...pending]){
  const dest=path.join(textureRoot,path.basename(virtualPath));
  if(copyLoose(source,virtualPath,dest)){
    found[role]=`./assets/local-swg/texture/${path.basename(virtualPath)}`;
    pending.delete(role);
    console.log(`loose  ${virtualPath}`);
  }
}

const archives=walk(source,4).sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));
console.log(`Scanning ${archives.length} TRE archives for ${pending.size} texture(s)...`);

// Later archives overwrite earlier matches, mirroring patch-style client lookup well enough
// for this curated texture set.
for(const archive of archives){
  if(!pending.size)break;
  const index=readArchiveIndex(archive);
  if(!index)continue;
  try{
    const byPath=new Map(index.entries.map(e=>[e.virtualPath,e]));
    for(const [role,virtualPath] of [...pending]){
      const entry=byPath.get(virtualPath.toLowerCase());
      if(!entry)continue;
      const packed=Buffer.alloc(entry.compressedSize);
      fs.readSync(index.fd,packed,0,entry.compressedSize,entry.fileOffset);
      let data;
      try{data=inflateMaybe(packed,entry.compression);}catch{continue;}
      const dest=path.join(textureRoot,path.basename(virtualPath));
      fs.writeFileSync(dest,data);
      found[role]=`./assets/local-swg/texture/${path.basename(virtualPath)}`;
      pending.delete(role);
      console.log(`TRE    ${virtualPath} <- ${path.basename(archive)}`);
    }
  }finally{index.close();}
}

const manifest={
  source:'local SWG client',
  generatedAt:new Date().toISOString(),
  assets:found,
};
fs.writeFileSync(path.join(outputRoot,'manifest.json'),JSON.stringify(manifest,null,2));

console.log('');
console.log(`Imported ${Object.keys(found).length}/${Object.keys(TARGETS).length} curated SWG textures.`);
if(pending.size){
  console.log('Not found:');
  for(const [,p] of pending)console.log(`  ${p}`);
}
console.log(`Manifest: ${path.join(outputRoot,'manifest.json')}`);
if(Object.keys(found).length<3)process.exitCode=1;
