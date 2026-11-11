// Run: node web/test_shared_save.mjs. No browser or production save is touched.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../game/web/shared_save.js', import.meta.url), 'utf8');
const id = 'a'.repeat(24);
const otherId = 'b'.repeat(24);
const raw = coins => JSON.stringify({version: 1, coins, outfit: 'yellow'});
const digest = value => value === null ? 'empty' : createHash('sha256').update(value).digest('hex');
const err = code => Object.assign(new Error(code), {code});
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return {promise, resolve, reject};
};

class Storage {
  values = new Map();
  failWrite = false;
  failRead = false;
  failRemove = false;
  getItem(key) { if (this.failRead) throw new Error('denied'); return this.values.get(key) ?? null; }
  setItem(key, value) { if (this.failWrite) throw new Error('quota'); this.values.set(key, value); }
  removeItem(key) { if (this.failRemove) throw new Error('denied'); this.values.delete(key); }
}

class Service {
  constructor(state = raw(0)) {
    this.state = state;
    this.token = null;
    this.counter = 0;
    this.calls = [];
    this.commits = [];
    this.recoveries = [];
    this.offline = false;
    this.loseSaveResponse = false;
    this.before = null;
  }
  get revision() { return digest(this.state); }
  async api(path, value) {
    const action = path.split('/').at(-1);
    this.calls.push({action, value: value && {...value}});
    if (this.offline) throw new TypeError('network unavailable');
    if (this.before) await this.before(action, value);
    if (action === 'lease') {
      if (value.token) {
        if (value.token !== this.token) throw err('lease_expired');
      } else {
        if (this.token) throw err('profile_busy');
        this.token = 'lease-' + (++this.counter);
      }
      return {token: this.token, revision: this.revision, state: this.state, profile: {id}};
    }
    if (action === 'recoveries') {
      const recovery_id = 'recovery-' + (this.recoveries.length + 1);
      this.recoveries.push({...value, recovery_id});
      return {recovery_id};
    }
    if (!value.token || value.token !== this.token) throw err('lease_expired');
    if (action === 'heartbeat') return {ok: true};
    if (action === 'release') { this.token = null; return {ok: true}; }
    if (action === 'save') {
      if (value.state !== this.state) {
        if (value.revision !== this.revision) throw err('revision_conflict');
        this.state = value.state;
        this.commits.push(value.state);
      }
      if (this.loseSaveResponse) { this.loseSaveResponse = false; throw new TypeError('response lost'); }
      return {revision: this.revision};
    }
    throw new Error('Unexpected action: ' + action);
  }
}

function setup(t, {service = new Service(), storage = new Storage(), profileId = id} = {}) {
  let timerId = 0;
  const timers = new Map();
  const statuses = [];
  const context = vm.createContext({
    setInterval(fn, delay) { assert.equal(delay, 20000); timers.set(++timerId, fn); return timerId; },
    clearInterval(key) { timers.delete(key); }
  });
  vm.runInContext(source, context, {filename: 'shared_save.js'});
  const client = new context.AlphabetSharedSave({
    api: service.api.bind(service), storage, profileId,
    onStatus: state => statuses.push(state)
  });
  t.after(() => client.dispose());
  return {client, service, storage, timers, statuses, Class: context.AlphabetSharedSave};
}

test('queue is durable before returning; uploads are serialized and preserve the latest snapshot', async t => {
  const {client, service, storage} = setup(t);
  await client.acquire();
  const gate = deferred();
  service.before = async action => { if (action === 'save' && !service.commits.length) await gate.promise; };
  assert.equal(client.queue(raw(1)), true);
  assert.equal(JSON.parse(storage.getItem(client.key)).raw, raw(1));
  assert.equal(client.queue(raw(2)), true);
  assert.equal(client.queue(raw(3)), true);
  assert.equal(service.calls.filter(call => call.action === 'save').length, 1);
  gate.resolve();
  await client.flush();
  assert.deepEqual(service.commits, [raw(1), raw(3)]);
  const saves = service.calls.filter(call => call.action === 'save');
  assert.equal(saves[1].value.revision, digest(raw(1)));
  assert.equal(storage.getItem(client.key), null);
  assert.equal(client.status.status, 'synced');
});

test('a lost successful response retains the draft and explicit retry acknowledges identical canonical state', async t => {
  const {client, service, storage} = setup(t);
  await client.acquire();
  service.loseSaveResponse = true;
  client.queue(raw(2));
  await assert.rejects(client.flush(), /response lost/);
  assert.equal(service.state, raw(2));
  assert.equal(JSON.parse(storage.getItem(client.key)).raw, raw(2));
  assert.equal(client.status.status, 'offline');
  const result = await client.retry();
  assert.equal(result.conflict, false);
  assert.equal(storage.getItem(client.key), null);
  assert.equal(service.commits.length, 1);
});

test('offline queue stays durable and flush/close reject until a successful retry', async t => {
  const {client, service, storage} = setup(t);
  await client.acquire();
  service.offline = true;
  assert.equal(client.queue(raw(8)), true);
  await assert.rejects(client.flush(), /network unavailable/);
  assert.equal(client.queue(raw(9)), true);
  await assert.rejects(client.close());
  assert.equal(service.calls.filter(call => call.action === 'release').length, 0);
  assert.equal(JSON.parse(storage.getItem(client.key)).raw, raw(9));
  service.offline = false;
  await client.retry();
  assert.equal(service.state, raw(9));
  await client.close();
  assert.equal(service.token, null);
});

test('same-revision refresh resumes the local draft and dispose retains the lease and draft', async t => {
  const first = setup(t);
  const lease = await first.client.acquire();
  first.service.offline = true;
  first.client.queue(raw(4));
  await assert.rejects(first.client.flush());
  first.client.dispose();
  assert.equal(first.timers.size, 0);
  assert.equal(first.service.token, lease.token);
  first.service.offline = false;
  const next = setup(t, {storage: first.storage, service: first.service});
  const result = await next.client.acquire({token: lease.token});
  assert.equal(result.initialState, raw(4));
  assert.equal(result.conflict, false);
  await next.client.flush();
  assert.equal(next.service.state, raw(4));
});

test('changed canonical revision archives a recovery and blocks launch/uploads without deleting local data', async t => {
  const {client, service, storage} = setup(t);
  storage.setItem(client.key, JSON.stringify({raw: raw(4), base_revision: 'older', timestamp: 100}));
  storage.setItem(client.key.replace(id, otherId), 'another profile');
  const result = await client.acquire();
  assert.equal(result.conflict, true);
  assert.equal(result.draft.raw, raw(4));
  assert.equal(result.draft.updated_at, 100);
  assert.equal(result.recovery_id, 'recovery-1');
  assert.equal(service.recoveries[0].state, raw(4));
  assert.equal(client.queue(raw(5)), true);
  await assert.rejects(client.flush(), error => error.code === 'conflict');
  assert.equal(client.getDraft().base_revision, 'older');
  assert.equal(service.commits.length, 0);
  client.discardLocalDraft();
  assert.equal(client.getDraft(), null);
  assert.equal(storage.getItem(client.key.replace(id, otherId)), 'another profile');
  await assert.rejects(client.flush(), error => error.code === 'conflict');
  await client.retry();
  assert.equal(client.initialState, raw(0));
});

test('failed recovery upload leaves a downloadable local draft and a blocked result', async t => {
  const {client, service, storage} = setup(t);
  storage.setItem(client.key, JSON.stringify({raw: raw(4), base_revision: 'older', timestamp: 100}));
  service.before = async action => { if (action === 'recoveries') throw new TypeError('recovery offline'); };
  const result = await client.acquire();
  assert.equal(result.conflict, true);
  assert.equal(result.recovery_id, null);
  assert.match(result.recovery_error, /recovery offline/);
  assert.equal(client.getDraft().raw, raw(4));
  await assert.rejects(client.close());
});

test('storage quota failure is synchronous and never uploads the unpersisted action', async t => {
  const {client, service, storage} = setup(t);
  await client.acquire();
  storage.failWrite = true;
  assert.equal(client.queue(raw(7)), false);
  assert.equal(client.status.status, 'storage_error');
  await assert.rejects(client.flush(), error => error.code === 'storage_error');
  assert.equal(service.calls.filter(call => call.action === 'save').length, 0);
  storage.failWrite = false;
  assert.equal(client.queue(raw(8)), true);
  await client.flush();
  assert.equal(service.state, raw(8));
});

test('unreadable or malformed local storage cannot be silently replaced', async t => {
  const {client, service, storage} = setup(t);
  storage.setItem(client.key, '{damaged');
  await assert.rejects(client.acquire(), error => error.code === 'storage_error');
  assert.equal(storage.getItem(client.key), '{damaged');
  assert.equal(service.calls.length, 0);
  storage.failRead = true;
  await assert.rejects(client.acquire(), error => error.code === 'storage_error');
});

test('failure to clear an acknowledged draft remains visible and is recoverable', async t => {
  const {client, service, storage} = setup(t);
  await client.acquire();
  storage.failRemove = true;
  client.queue(raw(3));
  await assert.rejects(client.flush(), error => error.code === 'storage_error');
  assert.equal(service.state, raw(3));
  assert.equal(client.getDraft().raw, raw(3));
  storage.failRemove = false;
  await client.retry();
  assert.equal(client.getDraft(), null);
});

test('lease expiry stops uploads, preserves later local actions and retries with a fresh token', async t => {
  const {client, service} = setup(t);
  await client.acquire();
  service.token = null; // Server restart.
  await assert.rejects(client.heartbeat(), error => error.code === 'lease_expired');
  assert.equal(client.status.status, 'expired');
  assert.equal(client.queue(raw(6)), true);
  await assert.rejects(client.flush(), error => error.code === 'expired');
  assert.equal(service.calls.filter(call => call.action === 'save').length, 0);
  await client.retry();
  assert.equal(service.state, raw(6));
  assert.equal(service.calls.filter(call => call.action === 'lease').at(-1).value.token, undefined);
});

test('retry discovers restart itself; if canonical changed, it returns a conflict without overwriting', async t => {
  const {client, service} = setup(t);
  await client.acquire();
  service.offline = true;
  client.queue(raw(4));
  await assert.rejects(client.flush());
  service.offline = false;
  service.token = null;
  service.state = raw(10);
  const result = await client.retry();
  assert.equal(result.conflict, true);
  assert.equal(client.getDraft().raw, raw(4));
  assert.equal(service.state, raw(10));
});

test('a CAS conflict during play blocks uploads and keeps the original draft base', async t => {
  const {client, service} = setup(t);
  await client.acquire();
  const base = client.revision;
  service.state = raw(20); // Simulates an external writer touching the file.
  client.queue(raw(2));
  await assert.rejects(client.flush(), error => error.code === 'revision_conflict');
  client.queue(raw(3));
  assert.equal(client.getDraft().base_revision, base);
  assert.equal(client.status.status, 'conflict');
  assert.equal(service.state, raw(20));
  const result = await client.retry();
  assert.equal(result.conflict, true);
  assert.equal(service.recoveries.at(-1).state, raw(3));
});

test('equivalent JSON after response loss clears only this profile draft', async t => {
  const {client, storage} = setup(t);
  storage.setItem(client.key, JSON.stringify({raw: '{"outfit":"yellow","coins":0,"version":1}', base_revision: 'old', timestamp: 1}));
  const result = await client.acquire();
  assert.equal(result.conflict, false);
  assert.equal(client.getDraft(), null);
});

test('empty canonical allows the existing browser legacy snapshot to be queued', async t => {
  const {client, service} = setup(t, {service: new Service(null)});
  const result = await client.acquire();
  assert.equal(result.initialState, null);
  assert.equal(service.commits.length, 0);
  assert.equal(client.queue(raw(12)), true);
  await client.flush();
  assert.equal(service.state, raw(12));
});

test('failed release never reports successful close or discards the active session', async t => {
  const {client, service, timers} = setup(t);
  await client.acquire();
  service.before = async action => { if (action === 'release') throw new TypeError('release offline'); };
  await assert.rejects(client.close(), /release offline/);
  assert.equal(client.status.status, 'offline');
  assert.equal(timers.size, 1);
  assert.ok(client.token);
});

test('an old heartbeat response cannot expire a newly acquired session', async t => {
  const {client, service} = setup(t);
  const initial = await client.acquire();
  const gate = deferred();
  service.before = async action => { if (action === 'heartbeat') { await gate.promise; throw err('lease_expired'); } };
  const oldHeartbeat = client.heartbeat();
  await client.acquire({token: initial.token});
  gate.resolve();
  await oldHeartbeat;
  assert.equal(client.status.status, 'synced');
  assert.equal(client.token, initial.token);
});

test('retry cannot rebase a running stale game over a newer canonical save when no draft exists', async t => {
  const {client, service} = setup(t);
  await client.acquire();
  client.queue(raw(1));
  await client.flush();
  assert.equal(client.getDraft(), null);
  service.token = null; // Restart releases the old web lease.
  service.state = raw(50); // Native play then changes the canonical progress.
  const result = await client.retry();
  assert.equal(result.reloadRequired, true);
  assert.equal(result.conflict, false);
  assert.equal(result.initialState, raw(50));
  assert.ok(result.token);
  assert.equal(client.queue(raw(2)), false, 'old runtime cannot write with the newly acquired revision');
  await assert.rejects(client.flush(), error => error.code === 'reload_required');
  assert.equal(client.getDraft(), null);
  assert.equal(service.state, raw(50));
});

test('restart with unchanged canonical progress can retry without reloading the game', async t => {
  const {client, service} = setup(t);
  await client.acquire();
  client.queue(raw(1));
  await client.flush();
  service.token = null;
  const result = await client.retry();
  assert.notEqual(result.reloadRequired, true);
  assert.equal(client.queue(raw(2)), true);
  await client.flush();
  assert.equal(service.state, raw(2));
});

test('retry persists the newest quota-failed candidate before acquiring and cannot falsely report synced', async t => {
  const {client, service, storage} = setup(t);
  await client.acquire();
  storage.failWrite = true;
  assert.equal(client.queue(raw(17)), false);
  assert.equal(client.getDraft().raw, raw(17));
  assert.equal(client.getDraft().durable, false);
  await assert.rejects(client.retry(), error => error.code === 'storage_error');
  assert.equal(client.status.status, 'storage_error');
  assert.equal(service.state, raw(0));
  storage.failWrite = false;
  await client.retry();
  assert.equal(service.state, raw(17));
  assert.equal(client.getDraft(), null);
  assert.equal(client.status.status, 'synced');
});

test('an older in-flight acknowledgement cannot discard a newer quota-failed candidate', async t => {
  const {client, service, storage} = setup(t);
  await client.acquire();
  const gate = deferred();
  service.before = async action => { if (action === 'save') await gate.promise; };
  client.queue(raw(1));
  storage.failWrite = true;
  assert.equal(client.queue(raw(19)), false);
  gate.resolve();
  await assert.rejects(client.flush(), error => error.code === 'storage_error');
  assert.equal(service.state, raw(1));
  assert.equal(client.getDraft().raw, raw(19));
  assert.equal(client.getDraft().base_revision, digest(raw(1)));
  assert.equal(client.status.status, 'storage_error');
  storage.failWrite = false;
  await client.retry();
  assert.equal(service.state, raw(19));
});
