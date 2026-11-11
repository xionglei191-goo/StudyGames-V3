(function (global) {
  'use strict';

  const DRAFT_PREFIX = 'alphabet-island-shared-draft-v1:';
  const messages = {
    synced: '进度已保存到这台电脑，单机与网页均可继续。',
    pending: '进度已保存在此浏览器，正在同步到这台电脑…',
    offline: '连接暂时中断，进度仍保存在此浏览器，请重试同步。',
    conflict: '另一份进度已经更新。本地草稿已保留，请回入口选择要继续的进度。',
    expired: '共享存档连接已失效。本地草稿已保留，请回入口重新连接。',
    storage_error: '浏览器未能持久保存最新进度，请勿刷新；请重试或先下载恢复副本。'
  };

  function failure(code, message) {
    const error = new Error(message || messages[code] || '共享存档暂时不可用。');
    error.code = code;
    return error;
  }

  function validRevision(value) {
    return value === null || typeof value === 'string';
  }

  function sameState(left, right) {
    if (left === right) return true;
    if (typeof left !== 'string' || typeof right !== 'string') return false;
    // Godot and the service can format the same JSON differently. Object order
    // is immaterial; array order and every stored value remain significant.
    function ordered(value) {
      if (Array.isArray(value)) return value.map(ordered);
      if (value && typeof value === 'object') {
        return Object.fromEntries(Object.keys(value).sort().map(key => [key, ordered(value[key])]));
      }
      return value;
    }
    try { return JSON.stringify(ordered(JSON.parse(left))) === JSON.stringify(ordered(JSON.parse(right))); }
    catch (_) { return false; }
  }

  class AlphabetSharedSave {
    constructor({api, storage, onStatus = () => {}, profileId}) {
      if (typeof api !== 'function' || typeof profileId !== 'string' || !profileId) {
        throw new TypeError('api and profileId are required');
      }
      this.api = api;
      this.profileId = profileId;
      this.onStatus = onStatus;
      this.key = DRAFT_PREFIX + profileId;
      this.path = '/api/profiles/' + encodeURIComponent(profileId);
      try { this.storage = storage === undefined ? global.localStorage : storage; }
      catch (_) { this.storage = null; }
      this.token = null;
      this.revision = null;
      this.profile = null;
      this.initialState = null;
      this.recoveryId = null;
      this._draft = null;
      this._unpersistedCandidate = null;
      this._running = null;
      this._timer = null;
      this._heartbeating = false;
      this._acquired = false;
      this._disposed = false;
      this._blocked = null;
      this._offline = false;
      this._storageError = null;
      this._lastError = null;
      this._epoch = 0;
      this._runtimeState = undefined;
      this._reloadRequired = false;
      this.status = {status: 'pending', message: '正在连接这台电脑的共享存档…'};
    }

    _status(status, message) {
      this.status = {status, message: message || messages[status]};
      // A rendering callback must never turn a durable write into a failed save.
      try { this.onStatus({...this.status}); } catch (_) {}
    }

    _storageFailure() {
      const error = failure('storage_error');
      this._storageError = error;
      this._status('storage_error');
      return error;
    }

    _readDraft() {
      try {
        if (!this.storage) throw new Error('Storage unavailable');
        const raw = this.storage.getItem(this.key);
        if (raw === null) return null;
        const draft = JSON.parse(raw);
        if (!draft || typeof draft.raw !== 'string' || !validRevision(draft.base_revision)
            || !Number.isFinite(draft.timestamp)) throw new Error('Invalid draft');
        const state = JSON.parse(draft.raw);
        if (!state || typeof state !== 'object' || Array.isArray(state)) throw new Error('Invalid state');
        return {raw: draft.raw, base_revision: draft.base_revision, timestamp: draft.timestamp};
      } catch (_) { throw this._storageFailure(); }
    }

    _writeDraft(draft) {
      try {
        if (!this.storage) throw new Error('Storage unavailable');
        this.storage.setItem(this.key, JSON.stringify(draft));
      } catch (_) { throw this._storageFailure(); }
      this._draft = draft;
      if (!this._unpersistedCandidate || this._unpersistedCandidate.raw === draft.raw) this._storageError = null;
    }

    _removeDraft() {
      try {
        if (!this.storage) throw new Error('Storage unavailable');
        this.storage.removeItem(this.key);
      } catch (_) { throw this._storageFailure(); }
      this._draft = null;
      if (!this._unpersistedCandidate) this._storageError = null;
    }

    getDraft() {
      if (this._unpersistedCandidate) {
        return {...this._unpersistedCandidate, updated_at: this._unpersistedCandidate.timestamp, durable: false};
      }
      this._draft = this._readDraft();
      return this._draft ? {...this._draft, updated_at: this._draft.timestamp} : null;
    }

    // The caller obtains consent only after preserving/downloading the draft.
    // This deliberately does not clear lease expiry or a conflict authorization.
    discardLocalDraft() {
      this._removeDraft();
      this._unpersistedCandidate = null;
      this._storageError = null;
      return true;
    }

    _persistCandidate() {
      if (!this._unpersistedCandidate) return;
      // A failed synchronous write still belongs to the live game's latest
      // state. Never replace it with an older durable draft during retry.
      this._writeDraft(this._unpersistedCandidate);
      this._unpersistedCandidate = null;
      this._storageError = null;
    }

    _networkFailure(error) {
      this._lastError = error;
      const code = error && error.code;
      if (code === 'storage_error') return;
      if (code === 'revision_conflict' || code === 'conflict') {
        this._blocked = 'conflict';
        this._status('conflict');
      } else if (code === 'lease_expired' || code === 'profile_busy' || code === 'profile_missing'
                 || code === 'expired') {
        this._blocked = 'expired';
        this.token = null;
        this._status('expired', code === 'profile_busy'
          ? '这个角色正在其他窗口游玩。本地草稿已保留，请稍后重新连接。' : undefined);
      } else if (code === 'invalid_save' || code === 'save_corrupt' || code === 'legacy_corrupt') {
        this._blocked = 'conflict';
        this._status('conflict', '这份进度需要检查，本地草稿已保留，请回入口处理。');
      } else {
        this._offline = true;
        this._status('offline');
      }
    }

    _startHeartbeat() {
      if (this._timer !== null) global.clearInterval(this._timer);
      this._timer = global.setInterval(() => { this.heartbeat().catch(() => {}); }, 20000);
    }

    async heartbeat() {
      if (this._disposed || !this._acquired || this._blocked || this._heartbeating) return;
      this._heartbeating = true;
      const epoch = this._epoch;
      try {
        await this.api(this.path + '/heartbeat', {token: this.token});
        if (epoch !== this._epoch || this._disposed) return;
        this._offline = false;
        this._lastError = null;
        if (!this._storageError && !this._blocked) {
          this._status(this._draft ? 'pending' : 'synced');
          this._schedule();
        }
      } catch (error) {
        if (epoch !== this._epoch || this._disposed) return;
        this._networkFailure(error);
        throw error;
      } finally { this._heartbeating = false; }
    }

    async acquire(options = {}) {
      if (this._running) await this._running.catch(() => {});
      this._epoch++;
      this._persistCandidate();
      const draft = this._readDraft();
      this._draft = draft;
      let lease;
      try {
        lease = await this.api(this.path + '/lease', options.token ? {token: options.token} : {});
        if (!lease || typeof lease.token !== 'string' || !validRevision(lease.revision)
            || !(lease.state === null || typeof lease.state === 'string')) {
          throw failure('invalid_response', '共享存档返回的数据不完整，请重新连接。');
        }
      } catch (error) {
        this._networkFailure(error);
        throw error;
      }
      this.token = lease.token;
      this.revision = lease.revision;
      this.profile = lease.profile;
      this.initialState = lease.state;
      this.recoveryId = null;
      this._acquired = true;
      this._disposed = false;
      this._blocked = null;
      this._offline = false;
      this._lastError = null;
      this._storageError = null;
      this._reloadRequired = false;
      this._startHeartbeat();
      if (draft && sameState(draft.raw, lease.state)) {
        // Covers a successful upload whose HTTP response was lost.
        this._removeDraft();
      } else if (draft && draft.base_revision !== lease.revision) {
        this._blocked = 'conflict';
        this._status('conflict');
        let recoveryError = null;
        try {
          const recovery = await this.api(this.path + '/recoveries', {
            token: this.token, state: draft.raw, base_revision: draft.base_revision,
            reason: 'browser_revision_conflict'
          });
          this.recoveryId = recovery.recovery_id || recovery.id || null;
        } catch (error) { recoveryError = error.message || '恢复副本暂未保存到这台电脑。'; }
        return {...lease, initialState: this.initialState, conflict: true,
          recovery_id: this.recoveryId, recovery_error: recoveryError,
          draft: {...draft, updated_at: draft.timestamp}};
      } else if (draft) {
        this.initialState = draft.raw;
      }
      if (!draft && this._runtimeState !== undefined && !sameState(this._runtimeState, lease.state)) {
        // A running Godot instance still has its old in-memory state. Adopting
        // a newer revision here would let its next action overwrite that newer
        // canonical save. The caller must reload the runtime before queueing.
        this._reloadRequired = true;
        this._blocked = 'conflict';
        this._status('conflict', '另一端的进度已经更新，需要重新载入后继续。');
        return {...lease, initialState: this.initialState, conflict: false,
          reloadRequired: true, draft: null};
      }
      this._runtimeState = this.initialState;
      this._status(this._draft ? 'pending' : 'synced');
      this._schedule();
      return {...lease, initialState: this.initialState, conflict: false,
        draft: this._draft ? {...this._draft, updated_at: this._draft.timestamp} : null};
    }

    // Synchronous durability is the game's success boundary. Uploads happen
    // afterward, so an offline network never silently discards a local action.
    queue(raw) {
      if (!this._acquired || this._disposed || this._reloadRequired) return false;
      try {
        if (typeof raw !== 'string') throw new Error('Invalid state');
        const state = JSON.parse(raw);
        if (!state || typeof state !== 'object' || Array.isArray(state)) throw new Error('Invalid state');
        const base = this._blocked && this._draft ? this._draft.base_revision : this.revision;
        this._unpersistedCandidate = {raw, base_revision: base, timestamp: Date.now()};
        this._runtimeState = raw;
        this._persistCandidate();
      } catch (_) {
        if (!this._storageError) this._storageFailure();
        return false;
      }
      this._status(this._blocked || (this._offline ? 'offline' : 'pending'));
      this._schedule();
      return true;
    }

    _schedule() {
      if (this._running || !this._draft || !this._acquired || this._disposed
          || this._blocked || this._offline || this._storageError) return this._running;
      this._running = this._drain().finally(() => { this._running = null; });
      // queue() cannot await. flush() still receives this same rejecting promise.
      this._running.catch(() => {});
      return this._running;
    }

    async _drain() {
      while (this._draft && !this._blocked && !this._disposed) {
        const sent = this._draft;
        let response;
        try {
          response = await this.api(this.path + '/save', {
            token: this.token, revision: this.revision, state: sent.raw
          });
          if (!response || typeof response.revision !== 'string') {
            throw failure('invalid_response', '共享存档未确认写入，请重试同步。');
          }
        } catch (error) {
          this._networkFailure(error);
          throw error;
        }
        this.revision = response.revision;
        this._offline = false;
        this._lastError = null;
        if (this._unpersistedCandidate) {
          this._unpersistedCandidate = {...this._unpersistedCandidate, base_revision: this.revision};
        }
        // Never delete a newer snapshot queued while this request was running.
        if (this._draft && this._draft.raw !== sent.raw) {
          this._writeDraft({...this._draft, base_revision: this.revision});
        } else {
          this._removeDraft();
        }
      }
      if (!this._blocked && !this._storageError && !this._offline) {
        this._status(this._draft ? 'pending' : 'synced');
      }
    }

    async flush() {
      if (this._running) await this._running;
      if (this._reloadRequired) throw failure('reload_required', '另一端的进度已经更新，需要重新载入后继续。');
      if (this._unpersistedCandidate) throw this._storageError || failure('storage_error');
      if (this._storageError) throw this._storageError;
      if (this._blocked) throw failure(this._blocked);
      if (this._offline) throw this._lastError || failure('offline');
      if (!this._acquired || this._disposed) throw failure('expired');
      while (this._draft) {
        const running = this._schedule();
        if (!running) throw failure(this._blocked || 'offline');
        await running;
      }
      return true;
    }

    async retry() {
      if (this._running) await this._running.catch(() => {});
      const token = this._blocked === 'expired' ? null : this.token;
      let lease;
      try { lease = await this.acquire(token ? {token} : {}); }
      catch (error) {
        // retry() is an explicit action. A restart may only be discovered here;
        // one fresh acquisition still respects the other writer's process lock.
        if (!token || error.code !== 'lease_expired') throw error;
        lease = await this.acquire();
      }
      if (!lease.conflict && !lease.reloadRequired) await this.flush();
      return lease;
    }

    async close() {
      await this.flush();
      try { await this.api(this.path + '/release', {token: this.token}); }
      catch (error) { this._networkFailure(error); throw error; }
      this.token = null;
      this._acquired = false;
      this.dispose();
      return true;
    }

    dispose() {
      this._disposed = true;
      this._epoch++;
      if (this._timer !== null) global.clearInterval(this._timer);
      this._timer = null;
    }
  }

  AlphabetSharedSave.DRAFT_PREFIX = DRAFT_PREFIX;
  global.AlphabetSharedSave = AlphabetSharedSave;
})(typeof window === 'object' ? window : globalThis);
