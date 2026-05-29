class EventBus extends EventTarget {
  emit(type, detail = {}) {
    this.dispatchEvent(new CustomEvent(type, { detail }));
    window.dispatchEvent(new CustomEvent(`studygame:${type}`, { detail }));
  }

  on(type, listener) {
    const handler = (event) => listener(event.detail);
    this.addEventListener(type, handler);
    return () => this.removeEventListener(type, handler);
  }
}

export const eventBus = new EventBus();
