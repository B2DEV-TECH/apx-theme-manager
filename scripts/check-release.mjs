// Read-only provenance hygiene. This supplements human review; it is not a
// complete secret detector, license audit, or Oracle integration test.
import fs from 'node:fs/promises';
import path from 'node:path';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const exec=promisify(execFile);
const git=async args=>(await exec('git',args,{maxBuffer:20*1024*1024})).stdout;
const files=[...new Set((await git(['ls-files','--cached','--others','--exclude-standard','-z'])).split('\0').filter(Boolean))];
const rules=[
 ['GitHub token',/\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}\b/],
 ['GitHub fine-grained token',/\bgithub_pat_[A-Za-z0-9_]{40,}\b/],
 ['private key',/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/],
 ['AWS access key',/\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/],
 ['OpenAI key',/\bsk-(?:proj-)?[A-Za-z0-9_-]{40,}\b/],
];
const localSecrets=[];
for(const config of ['.local/lab.json','.local/verify-config.json']){
 try{const j=JSON.parse((await fs.readFile(config,'utf8')).replace(/^\uFEFF/,''));
  for(const key of ['password','adminPassword'])if(typeof j[key]==='string'&&j[key].length>=8)localSecrets.push(j[key]);
 }catch(e){if(e.code!=='ENOENT')throw e;}
}
const issues=[];
function scan(name,bytes){
 if(bytes.includes(0))return;
 const text=bytes.toString('utf8');
 for(const [label,regex] of rules)if(regex.test(text))issues.push(`${name}: potential ${label}`);
 if(localSecrets.some(s=>text.includes(s)))issues.push(`${name}: local lab secret`);
}
for(const name of files){
 const bytes=await fs.readFile(name);scan(name,bytes);
 if(/\.(?:sql|pks|pkb|apx|mjs|md|json|css)$/.test(name)&&bytes.includes(13))issues.push(`${name}: non-LF text`);
 if(/(?:^|\/)(?:node_modules|\.local|\.env)(?:\/|$)/.test(name))issues.push(`${name}: excluded development material`);
 if(name.endsWith('.md')){
  const text=bytes.toString('utf8');
  for(const match of text.matchAll(/\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)){
   const href=match[1];if(/^(?:https?:|mailto:|#)/.test(href))continue;
   const target=decodeURIComponent(href.split('#')[0]);if(!target||target.startsWith('/'))continue;
   try{await fs.access(path.resolve(path.dirname(name),target));}catch{issues.push(`${name}: missing relative link ${target}`);}
  }
 }
}
let historyBlobs=0;
const objects=(await git(['rev-list','--objects','--all'])).trim().split('\n');
for(const item of objects){
 const hash=item.split(' ')[0];if(!hash)continue;
 const type=(await git(['cat-file','-t',hash])).trim();if(type!=='blob')continue;
 const bytes=(await exec('git',['cat-file','blob',hash],{encoding:'buffer',maxBuffer:20*1024*1024})).stdout;
 scan(`history:${hash.slice(0,12)}`,bytes);historyBlobs++;
}
console.log(JSON.stringify({files:files.length,historyBlobs,issues},null,2));
process.exitCode=issues.length?1:0;
