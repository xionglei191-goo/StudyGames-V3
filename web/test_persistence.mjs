// Exercise the exported adapter against successful, busy and failed IDBFS writes.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';

const runtime = await readFile(new URL('../build/web-online/index.js', import.meta.url), 'utf8');
const begin = runtime.indexOf('/* ALPHABET_PROFILE_PERSISTENCE_BEGIN */');
const end = runtime.indexOf('/* ALPHABET_PROFILE_PERSISTENCE_END */', begin);
assert(begin > 0 && end > begin, 'export contains persistence adapter');
function adapter(fs) {
  const context = {Module:{}, GodotFS:fs, setTimeout, Date, Error, Promise};
  vm.runInNewContext(runtime.slice(begin,end), context);
  return context.Module.flushPersistentFiles;
}
let writes = 0;
assert.equal(await adapter({_idbfs:true, _syncing:false, sync:async () => {writes++;}})(), true);
assert.equal(writes, 1);
await assert.rejects(adapter({_idbfs:false})(), /persistence is unavailable/);
await assert.rejects(adapter({_idbfs:true, sync:async () => new Error('quota')})(), /quota/);
const busy = {_idbfs:true, _syncing:true, sync:async () => {assert.equal(busy._syncing,false);}};
setTimeout(() => {busy._syncing=false;}, 20);
assert.equal(await adapter(busy)(),true);
let concurrentWrites=0;
const shared={_idbfs:true,sync:async()=>{concurrentWrites++;await new Promise(done=>setTimeout(done,20));}};
adapter(shared);
await Promise.all([shared.sync(),shared.sync()]);
assert.equal(concurrentWrites,1,'engine and shell share the same pending transaction');
console.log('PASS: successful flush, unavailable persistence, failed write, wait for pending write, concurrent write coalescing');
