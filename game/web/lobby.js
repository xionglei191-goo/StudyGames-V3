(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const PROFILE_KEY = 'alphabet-island-profiles-v1';
  const SESSION_KEY = 'alphabet-island-room-v2';
  const sceneNames = {village:'字母岛', school:'山丘学园', home:'家里的客厅', home_estate:'小院与住宅', home_hall:'门厅与走廊', home_bedroom:'卧室', home_kitchen:'厨房', home_bathroom:'浴室', home_balcony:'阳台', home_study:'书房', home_dining:'餐厅', classroom:'阳光教室', playground:'青草操场', football_field:'足球场', art_room:'美术教室', music_room:'音乐教室', science_room:'科学教室', canteen:'校园餐厅'};
  let profiles = [], legacyProfiles = [], mode = 'solo', session = null, config = {}, engine = null;
  let commands = [], releaseLock = null, loading = false, rosterKey = '', leaving = false, exitRequested = false;
  let toastTimer = 0, currentProfile = null, reported = false;
  let sharedSave = null, initialSave = '', activeLease = null, conflict = null;
  let startupFailure = false;
  let outfitEdited = false;
  let pendingOutfit = null;
  const roomDownloads = new Map();
  // The old browser-only catalogue remains intact until its owner imports a role.
  try { legacyProfiles = JSON.parse(localStorage.getItem(PROFILE_KEY) || '[]').filter(p => /^[a-f0-9]{24}$/.test(p.id)).slice(0, 20); } catch (_) { legacyProfiles = []; }
  const escapeCode = code => String(code || '').replace(/[\s-]/g, '').toUpperCase();
  const formattedCode = code => escapeCode(code).replace(/^(.{4})(.{4})$/, '$1 $2');
  const describeScene = scene => sceneNames[scene] || (/^landmark_[A-Z]$/.test(scene || '') ? `字母 ${scene.slice(-1)} 的小屋` : '正在准备小岛');

  function profileOptions() {
    const selected = $('profile').value;
    $('profile').replaceChildren(new Option('＋ 新建自己的角色', 'new'));
    for (const profile of profiles) {
      const option = document.createElement('option');
      option.value = profile.id;
      option.textContent = profile.nickname + (profile.legacy || profile.pending_browser_import ? ' · 等待网页导入' : profile.busy ? ' · 正在游玩' : profile.default ? ' · 原单机角色' : '');
      $('profile').appendChild(option);
    }
    if (profiles.some(p => p.id === selected)) $('profile').value = selected;
  }
  function selectProfile() {
    outfitEdited = false;
    const profile = profiles.find(p => p.id === $('profile').value);
    $('nickname').value = profile ? profile.nickname : '';
    $('nickname').readOnly = !!profile && !profile.legacy;
    $('profile-detail').textContent = !profile ? '新角色拥有独立的物品与学习进度。' : profile.legacy || profile.pending_browser_import ? '请在原浏览器进入一次，把旧进度复制到这台电脑；导入前的副本会保留。' : profile.busy ? '这个角色正在另一端游玩，请保存退出后再接着玩。' : '电脑单机与网页都从这份进度继续。';
    const outfit = profile && ['yellow','pink','blue'].includes(profile.outfit) ? profile.outfit : 'yellow';
    document.querySelector(`input[name=outfit][value=${outfit}]`).checked = true;
  }
  $('profile').addEventListener('change', selectProfile);
  document.querySelectorAll('input[name=outfit]').forEach(input => input.addEventListener('change', () => outfitEdited = true));
  async function refreshProfiles(preferred) {
    const catalogue = await api('/api/profiles');
    profiles = [...catalogue.profiles, ...legacyProfiles.filter(old => !catalogue.profiles.some(p => p.id === old.id)).map(p => ({...p,legacy:true}))];
    profileOptions();
    if (preferred || !$('profile').value || $('profile').value === 'new') $('profile').value = preferred || catalogue.default_id || 'new';
    selectProfile();
  }
  function selectMode(value) {
    mode = value;
    $('solo-tab').setAttribute('aria-selected', String(mode === 'solo'));
    $('create-tab').setAttribute('aria-selected', String(mode === 'create'));
    $('join-tab').setAttribute('aria-selected', String(mode === 'join'));
    $('code-field').hidden = mode !== 'join';
    $('room-code').required = mode === 'join';
    $('enter').innerHTML = (mode === 'solo' ? '在网页继续' : mode === 'join' ? '加入朋友的小岛' : '创建小岛房间') + ' <span aria-hidden="true">→</span>';
    $('entry-error').hidden = true;
  }
  $('solo-tab').onclick = () => selectMode('solo');
  $('create-tab').onclick = () => selectMode('create');
  $('join-tab').onclick = () => selectMode('join');
  const invitedCode = new URL(location.href).searchParams.get('room');
  if (invitedCode) { selectMode('join'); $('room-code').value = formattedCode(invitedCode); }
  if (!['localhost', '127.0.0.1', '[::1]'].includes(location.hostname)) $('local-hint').textContent = '网页联机 · 邀请朋友';

  async function api(path, value) {
    const response = await fetch(path, {method:value === undefined ? 'GET' : 'POST', headers:{'Content-Type':'application/json'}, body:value === undefined ? undefined : JSON.stringify(value), signal:AbortSignal.timeout(12000)});
    const data = await response.json();
    if (!response.ok) { const failure = new Error(data.error || '暂时没有连上小岛，请稍后再试。'); failure.code = data.code; failure.status = response.status; throw failure; }
    return data;
  }
  function error(message) { $('entry-error').textContent = message; $('entry-error').hidden = false; }
  function toast(message) {
    $('game-message').textContent = message;
    $('game-message').hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => $('game-message').hidden = true, 3200);
  }
  async function lockProfile(id) {
    if (!navigator.locks) throw new Error('这个浏览器暂不支持独立角色存档，请使用较新的 Chrome、Edge 或 Firefox。');
    return new Promise((resolve, reject) => {
      navigator.locks.request('alphabet-island-profile-' + id, {ifAvailable:true}, async lock => {
        if (!lock) { reject(new Error('这个角色已在另一个页面中游玩。请选“新建自己的角色”，再加入房间。')); return; }
        resolve();
        await new Promise(done => releaseLock = done);
      }).catch(reject);
    });
  }
  function storeProfile(profile) { profiles = profiles.map(p => p.id === profile.id ? {...p,...profile} : p); }
  function saveStatus(state) {
    $('save-status').textContent = state.message;
    $('save-status').dataset.status = state.status;
    $('retry-save').hidden = !['offline','expired','conflict','storage_error'].includes(state.status);
    $('download-save').hidden = $('retry-save').hidden;
  }
  async function chosenProfile() {
    const existing = profiles.find(p => p.id === $('profile').value);
    const outfit = document.querySelector('input[name=outfit]:checked').value;
    if (existing && !existing.legacy) return {...existing,outfit};
    const created = await api('/api/profiles', {nickname:$('nickname').value.trim(),outfit,...(existing ? {legacy_id:existing.id} : {})});
    return created.profile || created;
  }
  async function releaseShared() {
    if (sharedSave) {
      const token = sharedSave.token || activeLease?.token;
      sharedSave.dispose();
      if (token) await api(`/api/profiles/${currentProfile.id}/release`, {token}).catch(() => {});
    }
    sharedSave = null; activeLease = null;
    if (releaseLock) { releaseLock(); releaseLock = null; }
  }
  async function prepareProfile(profile, token) {
    currentProfile = profile;
    await lockProfile(profile.id);
    sharedSave = new window.AlphabetSharedSave({api,profileId:profile.id,onStatus:saveStatus});
    activeLease = await sharedSave.acquire({token});
    if (activeLease.conflict) {
      conflict = {profile,lease:activeLease};
      $('recovery-panel').hidden = false;
      $('conflict-actions').hidden = false;
      $('recovery-list').replaceChildren();
      $('recovery-message').textContent = '发现上次未同步的进度，而电脑上的存档已经改变。两份进度都已保留，请选择从哪份继续；恢复副本会先备份当前进度。';
      $('restore-draft').disabled = !activeLease.recovery_id;
      throw new Error('请先处理下方保留的进度，再进入小岛。');
    }
    initialSave = activeLease.initialState || activeLease.state || '';
    return activeLease;
  }
  function setCanvasSize() {
    const frame = $('canvas-frame'), canvas = $('canvas');
    canvas.width = Math.round(frame.clientWidth);
    canvas.height = Math.round(frame.clientHeight);
  }
  window.addEventListener('resize', setCanvasSize);

  async function launch(roomSession, profile, applyOutfit = true) {
    session = roomSession;
    currentProfile = profile;
    config = {shared_save:true, profile_id:profile.id, profile_nickname:profile.nickname, nickname:profile.nickname, outfit:profile.outfit,
      pending_browser_import:activeLease.profile?.pending_browser_import === true,
      apply_outfit:applyOutfit, ...(session ? {token:session.token,id:session.id,code:session.room.code,ws_url:`${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/ws`} : {})};
    sessionStorage.setItem(SESSION_KEY, JSON.stringify({session, profile, leaseToken:activeLease.token, applyOutfitOnReload:!!engine && applyOutfit}));
    // An exited instance stays paused behind the lobby; re-enter with a fresh runtime.
    if (engine) { location.reload(); return; }
    $('invite-code').textContent = session ? formattedCode(session.room.code) : '—';
    $('copy-code').hidden = !session; $('wave').hidden = !session;
    $('playing-outfit').value = profile.outfit;
    $('entry').hidden = true;
    $('play').hidden = false;
    $('loading').hidden = false;
    $('loading-label').textContent = '正在加载场景与人物…';
    setCanvasSize();
    // Each profile mounts its own IDBFS database. Two tabs never sync the same directory.
    engine = new Engine({...window.ALPHABET_ENGINE_CONFIG,
      canvas:$('canvas'), canvasResizePolicy:0, locale:'zh_CN',
      persistentPaths:[`/userfs/online-profiles/${profile.id}`],
      onProgress:(current,total) => {
        if (total > 0) {
          $('progress').value = current / total;
          $('loading-label').textContent = current >= total ? '场景已加载，正在铺好小岛…' : `正在加载小岛 · ${Math.floor(current / total * 100)}%`;
        }
      },
      onExit:async () => {
        leaving = true;
        sessionStorage.removeItem(SESSION_KEY);
        if (session) await api('/api/session/leave', {token:session.token}).catch(() => {});
        await releaseShared();
        location.replace(location.pathname);
      },
      onPrintError:(...values) => console.error(...values)
    });
    await engine.startGame();
    if (startupFailure) throw new Error('存档未能安全载入，请查看入口提示。');
    $('canvas').focus();
  }

  $('entry-form').addEventListener('submit', async event => {
    event.preventDefault();
    if (loading) return;
    $('entry-error').hidden = true;
    const code = escapeCode($('room-code').value);
    if (mode === 'join' && !/^[A-HJ-NP-Z2-9]{8}$/.test(code)) { error('请填写朋友给你的 8 位邀请码。'); return; }
    if (!Engine.isWebGLAvailable(2)) { error('这个浏览器暂时无法打开 3D 小岛，请启用硬件加速或使用 Chrome / Edge。'); return; }
    loading = true;
    $('enter').disabled = true;
    let joined = null;
    try {
      const selected = profiles.find(p => p.id === $('profile').value);
      const applyOutfit = outfitEdited || !selected || (!selected.has_save && !selected.legacy && !selected.pending_browser_import);
      const profile = await chosenProfile();
      await prepareProfile(profile);
      if (mode !== 'solo') joined = await api(mode === 'create' ? '/api/rooms' : `/api/rooms/${code}/join`, {nickname:profile.nickname, outfit:profile.outfit});
      await launch(joined, profile, applyOutfit);
    } catch (failure) {
      if (joined) await api('/api/session/leave', {token:joined.token}).catch(() => {});
      sessionStorage.removeItem(SESSION_KEY);
      await releaseShared();
      $('loading').hidden = true; $('entry').hidden = false; $('play').hidden = true;
      error(failure.message || '小岛暂时没有打开，请刷新后再试。');
      loading = false; $('enter').disabled = false;
    }
  });

  function renderRoster(state) {
    const signature = JSON.stringify((state.members || []).map(m => [m.id,m.nickname,m.online,m.outfit,m.pose && m.pose.scene])) + state.host;
    if (signature === rosterKey) return;
    rosterKey = signature;
    $('friends-list').replaceChildren();
    for (const member of state.members || []) {
      const row = document.createElement('div'); row.className = 'friend';
      const chip = document.createElement('span'); chip.className = 'friend-color ' + (['yellow','pink','blue'].includes(member.outfit) ? member.outfit : 'yellow'); chip.textContent = member.nickname.slice(0,1);
      const info = document.createElement('div'); info.className = 'friend-info';
      const name = document.createElement('div'); name.className = 'friend-name'; name.textContent = member.nickname;
      const tag = document.createElement('span'); tag.className = 'friend-tag'; tag.textContent = member.id === state.id ? '你' : member.id === state.host ? '房主' : '';
      name.appendChild(tag);
      const where = document.createElement('div'); where.className = 'friend-location'; where.textContent = member.online ? describeScene(member.pose && member.pose.scene) : '正在进入 / 等待重连';
      info.append(name, where); row.append(chip, info);
      if (member.id !== state.id) {
        const follow = document.createElement('button'); follow.textContent = '去找朋友'; follow.disabled = !member.online || !member.pose;
        follow.setAttribute('aria-label', `去找${member.nickname}`);
        follow.onclick = () => { commands.push({type:'follow',id:member.id}); toggleFriends(false); $('canvas').focus(); };
        row.appendChild(follow);
      } else if (['yellow','pink','blue'].includes(member.outfit)) {
        // A delayed presence report must not replace a selection being edited.
        if (pendingOutfit === member.outfit) pendingOutfit = null;
        if (!pendingOutfit && document.activeElement !== $('playing-outfit')) $('playing-outfit').value = member.outfit;
        if (currentProfile && currentProfile.outfit !== member.outfit) {
          currentProfile.outfit = member.outfit;
          try { storeProfile(currentProfile); } catch (_) { /* Godot's save is still independent. */ }
        }
      }
      $('friends-list').appendChild(row);
    }
    $('friend-count').textContent = `${(state.members || []).filter(m => m.online).length} / 4`;
  }

  window.AlphabetIslandOnline = Object.freeze({
    readConfig:() => JSON.stringify(config),
    initialSave:() => initialSave,
    saveProgress:raw => sharedSave ? sharedSave.queue(raw) : false,
    startupFailed:async message => {
      startupFailure = true; error(message); $('loading').hidden = true; $('entry').hidden = false; $('play').hidden = true;
      sessionStorage.removeItem(SESSION_KEY);
      if (session) await api('/api/session/leave', {token:session.token}).catch(() => {});
      await releaseShared(); loading = false; $('enter').disabled = false;
    },
    takeCommands:() => JSON.stringify(commands.splice(0,32)),
    downloadRoom:async roomId => {
      const entry = window.ALPHABET_ROOM_PACKS?.[roomId];
      if (!entry || !/^[A-Za-z0-9_]+$/.test(roomId)) {
        roomDownloads.set(roomId, {done:true,ok:false}); return;
      }
      roomDownloads.set(roomId, {done:false});
      try {
        const response = await fetch('/' + entry.url, {signal:AbortSignal.timeout(60000)});
        if (!response.ok) throw new Error('Room download HTTP ' + response.status);
        const bytes = new Uint8Array(await response.arrayBuffer());
        if (bytes.byteLength !== entry.bytes) throw new Error('Incomplete room download');
        engine.rtenv.copyToFS(`/userfs/web-room-cache/${roomId}.pck`, bytes);
        roomDownloads.set(roomId, {done:true,ok:true});
      } catch (failure) {
        console.error('Room download failed:', failure);
        roomDownloads.set(roomId, {done:true,ok:false});
      }
    },
    roomDownloadStatus:roomId => JSON.stringify(roomDownloads.get(roomId) || {}),
    finishSession:async () => {
      if (leaving) return;
      leaving = true;
      $('loading').hidden = false;
      $('loading-label').textContent = '正在保存这次的小岛生活…';
      $('progress').removeAttribute('value');
      try {
        // Added to this version's export by prepare_web_runtime.py; fails closed.
        if (!engine?.rtenv?.flushPersistentFiles) throw new Error('缺少浏览器存档接口');
        await engine.rtenv.flushPersistentFiles();
        await sharedSave.close();
        if (session) await api('/api/session/leave', {token:session.token}).catch(() => {});
        sessionStorage.removeItem(SESSION_KEY);
        if (releaseLock) { releaseLock(); releaseLock = null; }
        sharedSave.dispose(); sharedSave = null; activeLease = null;
        $('loading').hidden = true; $('play').hidden = true; $('entry').hidden = false;
        $('enter').disabled = false; loading = false;
        await refreshProfiles(currentProfile.id).catch(() => {});
        selectMode('solo');
        history.replaceState(null, '', location.pathname);
        document.title = '字母岛 · 我的角色与小岛';
        session = null;
      } catch (failure) {
        leaving = false;
        exitRequested = false;
        $('loading').hidden = true;
        commands.push({type:'exit_cancel'});
        toast('进度尚未同步到电脑，请保持此页，恢复本机服务后点“重试同步”，再保存返回。浏览器会保留未同步副本。');
        console.error('Profile persistence failed:', failure);
      }
    },
    roomLoading:(text, visible) => {
      $('loading').hidden = !visible;
      if (visible) {
        $('loading-label').textContent = text;
        $('progress').removeAttribute('value');
      }
    },
    report:raw => {
      const state = JSON.parse(raw);
      // Read-only, token-free observation for the shell and browser acceptance checks.
      window.alphabetIslandState = state;
      if (!reported) { reported = true; $('loading').hidden = true; }
      $('connection').textContent = state.message;
      $('connection').dataset.status = state.status;
      $('wave').disabled = state.status !== 'online';
      if (state.status === 'ended' && !leaving && !exitRequested) {
        $('ended').hidden = false;
        $('ended-message').textContent = state.message;
      }
      renderRoster(state);
    }
  });
  function toggleFriends(open) {
    $('friends-panel').hidden = !open;
    $('friends-toggle').setAttribute('aria-expanded', String(open));
  }
  $('friends-toggle').onclick = () => toggleFriends($('friends-panel').hidden);
  $('friends-close').onclick = () => { toggleFriends(false); $('canvas').focus(); };
  $('wave').onclick = () => { commands.push({type:'wave'}); $('canvas').focus(); };
  function choosePlayingOutfit() {
    const outfit = $('playing-outfit').value;
    if (!['yellow','pink','blue'].includes(outfit) || pendingOutfit === outfit) return;
    if (!pendingOutfit && currentProfile?.outfit === outfit) return;
    pendingOutfit = outfit;
    commands.push({type:'outfit',outfit});
  }
  $('playing-outfit').addEventListener('input', choosePlayingOutfit);
  $('playing-outfit').onchange = choosePlayingOutfit;
  $('copy-code').onclick = async () => {
    const url = new URL(location.pathname, location.origin); url.searchParams.set('room', config.code);
    try { await navigator.clipboard.writeText(url.href); toast('邀请链接已复制，发给朋友就能加入。'); }
    catch (_) { toast('邀请码：' + formattedCode(config.code)); }
  };
  async function exitRoom() {
    if (leaving) return;
    exitRequested = true;
    $('ended').hidden = true;
    // Let the game finish its transaction or ask about an unfinished drawing before leaving.
    if (engine) commands.push({type:'leave'});
    else {
      sessionStorage.removeItem(SESSION_KEY);
      if (session) await api('/api/session/leave', {token:session.token}).catch(() => {});
      location.replace(location.pathname);
    }
  }
  $('leave').onclick = exitRoom;
  $('return-entry').onclick = exitRoom;
  document.querySelector('.small-brand').onclick = event => { event.preventDefault(); exitRoom(); };
  $('retry-save').onclick = async () => {
    if (!sharedSave) return;
    try {
      const result = await sharedSave.retry();
      activeLease = result;
      const remembered = JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null');
      if (remembered && result?.token) { remembered.leaseToken = result.token; sessionStorage.setItem(SESSION_KEY, JSON.stringify(remembered)); }
      if (result?.reloadRequired) { location.reload(); return; }
      if (result?.conflict) throw new Error('两端进度已经不同，未同步副本已保留。请刷新页面，在入口选择要恢复的进度。');
      await sharedSave.flush();
      toast('进度已经同步，可以保存返回。');
    } catch (failure) { toast(failure.message); }
  };
  $('native-launch').onclick = async () => {
    if (!$('nickname').reportValidity() || loading) return;
    const selected = profiles.find(p => p.id === $('profile').value);
    if (selected?.legacy || selected?.pending_browser_import) { error('这个旧角色还在浏览器里。请先在原浏览器进入一次并保存返回，再到电脑端继续。'); return; }
    loading = true; $('native-launch').disabled = true; $('enter').disabled = true;
    try {
      const profile = await chosenProfile();
      await api(`/api/profiles/${profile.id}/launch-native`, {});
      $('profile-detail').textContent = `已为“${profile.nickname}”打开电脑端。保存退出后，可回到此页接着玩。`;
      await refreshProfiles(profile.id);
      error('电脑端已启动。此角色正在电脑端游玩，退出后再进入网页。');
    } catch (failure) { error(failure.message); }
    finally { loading = false; $('native-launch').disabled = false; $('enter').disabled = false; }
  };
  function downloadCopy(raw, id) {
    const url = URL.createObjectURL(new Blob([raw], {type:'application/json'}));
    const link = document.createElement('a'); link.href = url; link.download = `字母岛-${id}-未同步副本.json`; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  $('download-save').onclick = () => {
    try {
      const draft = sharedSave?.getDraft();
      if (draft?.raw) downloadCopy(draft.raw, currentProfile.id);
      else toast('当前没有未同步的进度。');
    } catch (failure) { toast(failure.message); }
  };
  $('download-draft').onclick = () => {
    if (conflict?.lease.draft?.raw) downloadCopy(conflict.lease.draft.raw, conflict.profile.id);
  };
  async function resolveDraft(restore) {
    if (!conflict) return;
    const {profile,lease} = conflict;
    if (!lease.recovery_id) { error('恢复副本尚未写到电脑，请先下载副本，恢复本机服务后再试。'); return; }
    let fresh;
    try {
      fresh = await api(`/api/profiles/${profile.id}/lease`, {});
      if (restore) await api(`/api/profiles/${profile.id}/recoveries/${lease.recovery_id}/restore`, {token:fresh.token,revision:fresh.revision});
      const manager = new window.AlphabetSharedSave({api,profileId:profile.id,onStatus:saveStatus});
      manager.discardLocalDraft(); manager.dispose();
      conflict = null; $('recovery-panel').hidden = true;
      error(restore ? '已恢复所选副本，并保留原进度备份。现在可以进入。' : '已选择电脑上的进度；未同步副本仍可从“恢复记录”找回。');
      await refreshProfiles(profile.id);
    } catch (failure) { error(failure.message); }
    finally { if (fresh) await api(`/api/profiles/${profile.id}/release`, {token:fresh.token}).catch(() => {}); }
  }
  $('keep-synced').onclick = () => resolveDraft(false);
  $('restore-draft').onclick = () => resolveDraft(true);
  $('close-recoveries').onclick = () => $('recovery-panel').hidden = true;
  $('show-recoveries').onclick = async () => {
    const profile = profiles.find(p => p.id === $('profile').value);
    if (!profile || profile.legacy) { error('请先选择这台电脑上已有的角色。'); return; }
    try {
      const result = await api(`/api/profiles/${profile.id}/recoveries`);
      const records = result.recoveries || [];
      $('recovery-panel').hidden = false; $('conflict-actions').hidden = true;
      $('recovery-message').textContent = records.length ? '恢复某份记录前，会自动备份现在的进度。请先退出这个角色的游戏。' : '还没有需要恢复的记录，进度会随游玩自动保存。';
      $('recovery-list').replaceChildren();
      for (const record of records) {
        const row = document.createElement('div'); row.className = 'recovery-row';
        const label = document.createElement('span');
        const when = typeof record.created_at === 'number' ? new Date(record.created_at * 1000).toLocaleString('zh-CN') : record.created_at || '';
        const reason = {browser_revision_conflict:'未同步副本',manual_recovery:'恢复前备份'}[record.reason] || '保留的进度';
        label.textContent = `${when} · ${reason} · ${record.coins ?? '—'} 叶币 / 第 ${record.day ?? '—'} 天`;
        const button = document.createElement('button'); button.className = 'secondary'; button.textContent = '恢复这份';
        button.onclick = async () => {
          let lease;
          button.disabled = true;
          try {
            lease = await api(`/api/profiles/${profile.id}/lease`, {});
            await api(`/api/profiles/${profile.id}/recoveries/${record.recovery_id || record.id}/restore`, {token:lease.token,revision:lease.revision});
            error('已恢复所选进度，当前进度也已备份。'); $('recovery-panel').hidden = true;
          } catch (failure) { error(failure.message); }
          finally { if (lease) await api(`/api/profiles/${profile.id}/release`, {token:lease.token}).catch(() => {}); button.disabled = false; }
        };
        row.append(label,button); $('recovery-list').appendChild(row);
      }
    } catch (failure) { error(failure.message); }
  };
  window.addEventListener('pagehide', () => sharedSave?.dispose());

  // Refresh keeps the same member and profile. A second tab is rejected by the profile lock.
  (async () => {
    try { await refreshProfiles(); }
    catch (failure) { error(failure.message); return; }
    $('enter').disabled = false; $('native-launch').disabled = false;
    let remembered;
    try { remembered = JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null'); } catch (_) { return; }
    if (!remembered || !remembered.profile || !/^[a-f0-9]{24}$/.test(remembered.profile.id)) return;
    loading = true; $('enter').disabled = true;
    try {
      await prepareProfile(remembered.profile, remembered.leaseToken);
      const fresh = remembered.session ? await api('/api/session/resume', {token:remembered.session.token}) : null;
      await launch(fresh, remembered.profile, remembered.applyOutfitOnReload === true);
    } catch (failure) {
      sessionStorage.removeItem(SESSION_KEY);
      await releaseShared();
      $('loading').hidden = true; $('entry').hidden = false; $('play').hidden = true;
      error(failure.message || '这次邀请已结束，可以重新创建或加入房间。');
      loading = false; $('enter').disabled = false;
    }
  })();
})();
