const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('fs');const os=require('os');const path=require('path');
const {atomicWrite,parse}=require('./integration_checkpoint.cjs');
test('PowerShell UTF-8 BOM JSON updates are accepted',()=>assert.deepEqual(parse('\uFEFF{"phase":4}'),{phase:4}));
function cleanup(dir) {
 const target=path.resolve(dir),base=path.resolve(os.tmpdir())+path.sep;
 if(!target.startsWith(base)||!path.basename(target).startsWith('rider-checkpoint-')) throw Error('Unsafe test cleanup path');
 fs.rmSync(target,{recursive:true,force:true});
}
test('complete atomic replacement verifies content',()=> {
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rider-checkpoint-'));
 const file=path.join(dir,'CHECKPOINT.md');
 try{atomicWrite(file,'old valid checkpoint');atomicWrite(file,'new complete checkpoint');assert.equal(fs.readFileSync(file,'utf8'),'new complete checkpoint');}
 finally{cleanup(dir);}
});
test('interruption before replacement preserves original and complete temporary file',()=> {
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rider-checkpoint-'));
 const file=path.join(dir,'CHECKPOINT.md');
 try{atomicWrite(file,'old valid checkpoint');assert.throws(()=>atomicWrite(file,'complete replacement',()=>{throw Error('simulated interruption');}));
 assert.equal(fs.readFileSync(file,'utf8'),'old valid checkpoint');assert.equal(fs.readFileSync(file+'.tmp-'+process.pid,'utf8'),'complete replacement');}
 finally{cleanup(dir);}
});
