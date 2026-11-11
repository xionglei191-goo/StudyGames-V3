// Integration acceptance for the real HTTP store and the browser sync module.
// Requires the explicitly isolated service at 4191; never uses the production store.
import assert from 'node:assert/strict';
import {readFile, writeFile} from 'node:fs/promises';
import vm from 'node:vm';

const profileId = process.argv[2];
assert(/^[a-f0-9]{24}$/.test(profileId || ''), 'isolated profile id is required');
const context = {setInterval,clearInterval,Date,JSON,Error,Object,Array,Number,encodeURIComponent};
vm.createContext(context);
vm.runInContext(await readFile(new URL('../game/web/shared_save.js',import.meta.url),'utf8'),context);
const map = new Map();
const storage = {getItem:key => map.get(key) ?? null,setItem:(key,value) => map.set(key,value),removeItem:key => map.delete(key)};
const statuses = [];
const api = async (path,body) => {
  const response = await fetch('http://127.0.0.1:4191' + path, {method:body === undefined ? 'GET':'POST',headers:{'Content-Type':'application/json'},body:body === undefined ? undefined:JSON.stringify(body)});
  const result = await response.json();
  if (!response.ok) {const failure = new Error(result.error); failure.code = result.code; throw failure;}
  return result;
};
const manager = new context.AlphabetSharedSave({api,storage,profileId,onStatus:state => statuses.push(state.status)});
try {
  const lease = await manager.acquire();
  const state = JSON.parse(lease.initialState);
  assert.equal(state.coins,83); assert.equal(state.day,4); assert.equal(state.unit,2);
  assert.equal(Object.keys(state.learning).length,3); assert.equal(state.completed_units['1'],true);
  const before = state.outfit;
  state.outfit = 'pink';
  assert.equal(manager.queue(JSON.stringify(state)),true);
  await manager.flush();
  const confirmation = await api(`/api/profiles/${profileId}/lease`,{token:manager.token});
  const saved = JSON.parse(confirmation.state);
  assert.equal(saved.outfit,'pink'); assert.equal(saved.coins,83);
  await manager.close();
  assert.equal(map.size,0,'only acknowledged drafts are removed');
  await writeFile(new URL('../docs/verification/shared-save/http-js-roundtrip.json',import.meta.url),JSON.stringify({ok:true,scope:'Real HTTP service plus browser synchronization module, no browser UI',before_outfit:before,after_outfit:saved.outfit,coins:saved.coins,day:saved.day,unit:saved.unit,learning_record_count:Object.keys(saved.learning).length,completed_units:saved.completed_units,statuses},null,2));
  console.log('PASS: real HTTP + browser module saved pink with all native fixture progress retained. Lease released.');
} finally {manager.dispose();}
