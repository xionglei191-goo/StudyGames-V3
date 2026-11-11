// Pure Node VM integration: real lobby/shared-save scripts, fake DOM/engine/API.
// Run: node web/test_lobby.mjs
// Optional incident reproduction: node web/test_lobby.mjs --compare-legacy
// The optional old source is evidence only, never needed by the normal suite.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../game/web/lobby.js', import.meta.url), 'utf8');
const saveSource = await readFile(new URL('../game/web/shared_save.js', import.meta.url), 'utf8');
const PROFILE = 'a'.repeat(24);
const SESSION_KEY = 'alphabet-island-room-v2';
const digest = raw => createHash('sha256').update(raw).digest('hex');
const rawState = outfit => JSON.stringify({version: 1, coins: 48, day: 1, outfit});
const settle = async () => { for (let i = 0; i < 16; i++) await Promise.resolve(); };
const deferred = () => {
  let resolve;
  const promise = new Promise(done => resolve = done);
  return {promise, resolve};
};

class Storage {
  values = new Map();
  getItem(key) { return this.values.get(key) ?? null; }
  setItem(key, value) { this.values.set(key, String(value)); }
  removeItem(key) { this.values.delete(key); }
}

class Element {
  constructor(owner, tag = 'div', id = '') {
    Object.assign(this, {owner, tagName: tag.toUpperCase(), id, value: '', hidden: true,
      disabled: false, dataset: {}, children: [], attributes: {}, listeners: {},
      textContent: '', innerHTML: '', clientWidth: 960, clientHeight: 640});
  }
  addEventListener(type, callback) { (this.listeners[type] ||= []).push(callback); }
  async emit(type) {
    const event = {type, target: this, currentTarget: this, preventDefault() {}};
    for (const callback of this.listeners[type] || []) await callback(event);
    if (this['on' + type]) await this['on' + type](event);
  }
  appendChild(child) {
    this.children.push(child);
    if (this.tagName === 'SELECT' && !this.value) this.value = child.value;
    return child;
  }
  append(...children) { for (const child of children) this.appendChild(child); }
  replaceChildren(...children) {
    this.children = [];
    if (this.tagName === 'SELECT') this.value = '';
    this.append(...children);
  }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  removeAttribute(name) { delete this.attributes[name]; }
  focus() { this.owner.activeElement = this; }
  blur() { if (this.owner.activeElement === this) this.owner.activeElement = this.owner.body; }
  click() { return this.emit('click'); }
  reportValidity() { return true; }
}

function fakeDocument() {
  const nodes = new Map();
  const doc = {
    title: '', activeElement: null,
    getElementById(id) {
      if (!nodes.has(id)) nodes.set(id, new Element(doc, ['profile', 'playing-outfit'].includes(id) ? 'select' : 'div', id));
      return nodes.get(id);
    },
    createElement(tag) { return new Element(doc, tag); },
    querySelector(selector) {
      if (selector === '.small-brand') return doc.getElementById('small-brand');
      if (selector === 'input[name=outfit]:checked') return doc.radios.find(item => item.checked);
      const match = selector.match(/^input\[name=outfit\]\[value=(yellow|pink|blue)\]$/);
      if (match) return doc.radios.find(item => item.value === match[1]);
      throw new Error('Unexpected selector: ' + selector);
    },
    querySelectorAll(selector) {
      assert.equal(selector, 'input[name=outfit]');
      return doc.radios;
    }
  };
  doc.body = new Element(doc, 'body');
  doc.activeElement = doc.body;
  doc.radios = ['yellow', 'pink', 'blue'].map(value => {
    const input = new Element(doc, 'input');
    input.value = value;
    Object.defineProperty(input, 'checked', {
      get() { return !!this._checked; },
      set(selected) {
        if (selected) for (const sibling of doc.radios || []) sibling._checked = false;
        this._checked = !!selected;
      }
    });
    return input;
  });
  doc.radios[0].checked = true;
  doc.getElementById('enter').disabled = true;
  return doc;
}

async function harness(t, {lobbySource = source, canonical = 'blue', catalogue = 'blue', startupFailure = null} = {}) {
  const document = fakeDocument();
  const localStorage = new Storage();
  const sessionStorage = new Storage();
  const trace = [];
  const locks = new Map();
  const timers = new Map();
  const listeners = new Map();
  const engines = [];
  let timerId = 0;
  const service = {
    state: rawState(canonical), token: null, saves: [], saveGate: null,
    profile: {id: PROFILE, nickname: '测试角色', outfit: catalogue, has_save: true, default: true},
    async fetch(path, options = {}) {
      const action = path.split('/').at(-1);
      const value = options.body ? JSON.parse(options.body) : undefined;
      trace.push({kind: 'request', action, value});
      let data, status = 200;
      if (path === '/api/profiles' && options.method === 'GET') {
        data = {profiles: [{...this.profile}], default_id: PROFILE};
      } else if (action === 'lease') {
        if (value.token && value.token !== this.token) { status = 409; data = {code: 'lease_expired'}; }
        else if (!value.token && this.token) { status = 409; data = {code: 'profile_busy'}; }
        else {
          this.token ||= 'fake-lease';
          data = {token: this.token, revision: digest(this.state), state: this.state, profile: {...this.profile}};
        }
      } else if (action === 'heartbeat' || action === 'release' || action === 'save') {
        if (!value.token || value.token !== this.token) { status = 409; data = {code: 'lease_expired'}; }
        else if (action === 'heartbeat') data = {ok: true};
        else if (action === 'release') {
          this.token = null;
          trace.push({kind: 'released'});
          data = {ok: true};
        } else {
          if (this.saveGate) await this.saveGate.promise;
          if (value.revision !== digest(this.state) && value.state !== this.state) {
            status = 409; data = {code: 'revision_conflict'};
          } else {
            this.state = value.state;
            this.profile.outfit = JSON.parse(value.state).outfit;
            this.saves.push(JSON.parse(value.state));
            trace.push({kind: 'saved', state: JSON.parse(value.state)});
            data = {revision: digest(this.state)};
          }
        }
      } else throw new Error('Unexpected API endpoint: ' + path);
      return {ok: status === 200, status, json: async () => data};
    }
  };
  const location = {
    href: 'http://127.0.0.1:4189/', protocol: 'http:', hostname: '127.0.0.1', host: '127.0.0.1:4189', origin: 'http://127.0.0.1:4189', pathname: '/',
    reload() { trace.push({kind: 'reload'}); }, replace(url) { trace.push({kind: 'navigation', url}); }
  };
  let context;
  class FakeEngine {
    static isWebGLAvailable() { return true; }
    constructor(options) {
      this.options = options;
      this.state = null;
      this.config = null;
      this.rtenv = {
        flushPersistentFiles: async () => {
          trace.push({kind: 'idb-start'});
          await Promise.resolve();
          trace.push({kind: 'idb-end'});
        }
      };
      engines.push(this);
    }
    async startGame() {
      this.config = JSON.parse(context.AlphabetIslandOnline.readConfig());
      this.state = JSON.parse(context.AlphabetIslandOnline.initialSave());
      if (startupFailure) { await context.AlphabetIslandOnline.startupFailed(startupFailure); return; }
      if (this.config.apply_outfit) {
        this.state.outfit = this.config.outfit;
        context.AlphabetIslandOnline.saveProgress(JSON.stringify(this.state));
      }
      trace.push({kind: 'engine-start', state: {...this.state}});
    }
    consume() {
      const commands = JSON.parse(context.AlphabetIslandOnline.takeCommands());
      for (const command of commands) {
        if (command.type === 'outfit') {
          this.state.outfit = command.outfit;
          context.AlphabetIslandOnline.saveProgress(JSON.stringify(this.state));
        }
      }
      trace.push({kind: 'commands', commands});
      return commands;
    }
  }
  context = vm.createContext({
    document, localStorage, sessionStorage, location,
    console: {error: (...args) => trace.push({kind: 'error', message: String(args[0])})},
    navigator: {
      locks: {async request(name, _options, callback) {
        if (locks.has(name)) return callback(null);
        locks.set(name, true);
        try { return await callback({name}); }
        finally { locks.delete(name); }
      }}, clipboard: {writeText: async () => {}}
    },
    fetch: service.fetch.bind(service), Engine: FakeEngine,
    Option: function(text, value) { const element = new Element(document, 'option'); element.textContent = text; element.value = value; return element; },
    URL, Blob, Uint8Array, AbortSignal: {timeout: () => ({})},
    history: {replaceState: (...args) => trace.push({kind: 'history', args})},
    setTimeout(fn, delay) { const id = ++timerId; timers.set(id, {fn, delay}); return id; },
    clearTimeout(id) { timers.delete(id); },
    setInterval(fn, delay) { const id = ++timerId; timers.set(id, {fn, delay}); return id; },
    clearInterval(id) { timers.delete(id); },
    addEventListener(type, callback) { (listeners.get(type) || listeners.set(type, []).get(type)).push(callback); }
  });
  context.window = context;
  vm.runInContext(saveSource, context, {filename: 'shared_save.js'});
  vm.runInContext(lobbySource, context, {filename: 'lobby.js'});
  await settle();
  assert.equal(document.getElementById('profile').value, PROFILE, 'catalogue selects the shared profile');
  assert.equal(document.getElementById('enter').disabled, false, 'startup catalogue completed');
  t.after(() => { for (const callback of listeners.get('pagehide') || []) callback(); });
  const bridge = context.AlphabetIslandOnline;
  const report = (outfit, scene = 'village') => bridge.report(JSON.stringify({
    id: 'self', host: 'self', status: 'solo', message: '单人游玩',
    members: [{id: 'self', nickname: '测试角色', online: true, outfit, pose: {scene}}]
  }));
  return {
    document, service, trace, timers, locks, bridge, context, sessionStorage,
    async enter() { await document.getElementById('entry-form').emit('submit'); await settle(); return engines.at(-1); },
    report
  };
}

test('solo launch loads canonical JSON without applying an unchanged stale catalogue outfit', async t => {
  const h = await harness(t, {canonical: 'pink', catalogue: 'blue'});
  const engine = await h.enter();
  assert.equal(engine.config.shared_save, true);
  assert.equal(engine.config.apply_outfit, false);
  assert.equal(engine.state.outfit, 'pink');
  assert.equal(JSON.parse(h.service.state).outfit, 'pink');
  assert.equal(h.service.saves.length, 0);
  assert.equal(h.service.token, 'fake-lease');
});

test('input captures pink once; delayed blue presence and blur/change cannot enqueue blue', async t => {
  const h = await harness(t);
  const engine = await h.enter();
  h.report('blue');
  const select = h.document.getElementById('playing-outfit');
  select.focus();
  select.value = 'pink';
  await select.emit('input');
  assert.deepEqual(engine.consume(), [{type: 'outfit', outfit: 'pink'}]);
  await settle();
  assert.equal(JSON.parse(h.service.state).outfit, 'pink', 'the service received pink');
  h.report('blue', 'home_hall'); // Change scene so renderRoster cannot short-circuit.
  assert.equal(select.value, 'pink', 'delayed presence cannot replace the selected DOM value');
  select.blur();
  await select.emit('change');
  assert.deepEqual(engine.consume(), []);
  h.report('pink', 'home_hall');
  await select.emit('change');
  assert.deepEqual(engine.consume(), []);
  await settle();
  assert.deepEqual(h.service.saves.map(state => state.outfit), ['pink']);
});

test('change-only selection remains supported and matching acknowledgement permits the next real selection', async t => {
  const h = await harness(t);
  const engine = await h.enter();
  h.report('blue');
  const select = h.document.getElementById('playing-outfit');
  select.value = 'pink';
  await select.emit('change');
  assert.deepEqual(engine.consume(), [{type: 'outfit', outfit: 'pink'}]);
  await settle();
  h.report('pink');
  select.value = 'yellow';
  await select.emit('input');
  await select.emit('change');
  assert.deepEqual(engine.consume(), [{type: 'outfit', outfit: 'yellow'}]);
  await settle();
  assert.deepEqual(h.service.saves.map(state => state.outfit), ['pink', 'yellow']);
});

test('finishSession waits for IDB and shared save, releases once, and does not requeue stale presence', async t => {
  const h = await harness(t);
  const engine = await h.enter();
  h.report('blue');
  const gate = deferred();
  h.service.saveGate = gate;
  const select = h.document.getElementById('playing-outfit');
  select.value = 'pink';
  await select.emit('input');
  assert.deepEqual(engine.consume(), [{type: 'outfit', outfit: 'pink'}]);
  h.report('blue', 'home_hall');
  const finishing = h.bridge.finishSession();
  await settle();
  assert.ok(h.trace.some(item => item.kind === 'idb-end'));
  assert.equal(h.trace.some(item => item.kind === 'released'), false, 'release waits for the in-flight save');
  gate.resolve();
  await finishing;
  await settle();
  assert.equal(JSON.parse(h.service.state).outfit, 'pink');
  assert.deepEqual(h.service.saves.map(state => state.outfit), ['pink']);
  const index = kind => h.trace.findIndex(item => item.kind === kind);
  assert.ok(index('idb-end') < index('released'));
  assert.ok(index('saved') < index('released'));
  assert.equal(h.trace.filter(item => item.kind === 'released').length, 1);
  assert.equal(h.service.token, null);
  assert.equal(h.locks.size, 0);
  assert.equal(h.sessionStorage.getItem(SESSION_KEY), null);
  assert.deepEqual(JSON.parse(h.bridge.takeCommands()), []);
  assert.equal(h.bridge.saveProgress(rawState('blue')), false, 'after release there is no manager to queue stale state');
  await h.bridge.finishSession();
  assert.equal(h.service.saves.length, 1);
});

test('startupFailed releases the acquired lease and browser lock without writing canonical progress', async t => {
  const h = await harness(t, {startupFailure: '测试：存档注入失败'});
  await h.enter();
  assert.equal(h.service.token, null);
  assert.equal(h.locks.size, 0);
  assert.equal(h.sessionStorage.getItem(SESSION_KEY), null);
  assert.equal(h.service.saves.length, 0);
  assert.equal(JSON.parse(h.service.state).outfit, 'blue');
  assert.equal(h.document.getElementById('entry').hidden, false);
  assert.equal(h.document.getElementById('play').hidden, true);
  assert.equal(h.document.getElementById('enter').disabled, false);
  assert.equal(h.trace.filter(item => item.kind === 'released').length, 1);
});

if (process.argv.includes('--compare-legacy')) {
  const legacySource = await readFile(new URL('../.local/shared-save-acceptance/lobby-before-outfit-fix.js', import.meta.url), 'utf8');
  test('incident evidence: previous exported shell can enqueue blue after pink on a delayed report/change sequence', async t => {
    const h = await harness(t, {lobbySource: legacySource});
    const engine = await h.enter();
    h.report('blue');
    const select = h.document.getElementById('playing-outfit');
    select.focus();
    select.value = 'pink';
    await select.emit('input');
    await select.emit('change');
    const first = engine.consume();
    await settle();
    assert.equal(JSON.parse(h.service.state).outfit, 'pink');
    h.report('blue', 'home_hall');
    assert.equal(select.value, 'blue');
    select.blur();
    await select.emit('change');
    const second = engine.consume();
    await settle();
    assert.deepEqual([...first, ...second], [{type: 'outfit', outfit: 'pink'}, {type: 'outfit', outfit: 'blue'}]);
    assert.deepEqual(h.service.saves.map(state => state.outfit), ['pink', 'blue']);
    assert.equal(JSON.parse(h.service.state).outfit, 'blue');
    console.log('Legacy source SHA256:', digest(legacySource), '| fake API persisted outfits: pink -> blue');
  });
}
