import { loadSettings } from "../data/progressStore.js";

let audioContext;

export function playSound(kind) {
  if (!loadSettings().audio) return;
  if (!window.AudioContext && !window.webkitAudioContext) return;

  audioContext = audioContext || new (window.AudioContext || window.webkitAudioContext)();
  if (audioContext.state === "suspended") audioContext.resume();
  const now = audioContext.currentTime;
  const sequence = {
    click: [[520, 0, 0.045, 0.026]],
    place: [[420, 0, 0.04, 0.022], [560, 0.045, 0.045, 0.02]],
    success: [[620, 0, 0.07, 0.028], [820, 0.075, 0.09, 0.032]],
    error: [[230, 0, 0.1, 0.03], [170, 0.08, 0.08, 0.024]],
    reward: [[660, 0, 0.1, 0.03], [880, 0.09, 0.12, 0.036], [1120, 0.19, 0.16, 0.032]],
    hint: [[360, 0, 0.06, 0.02], [520, 0.06, 0.08, 0.022]]
  }[kind] || [[440, 0, 0.06, 0.03]];

  sequence.forEach(([frequency, offset, duration, volume]) => {
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();
    const start = now + offset;
    oscillator.type = kind === "error" ? "triangle" : "sine";
    oscillator.frequency.setValueAtTime(frequency, start);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(volume, start + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    oscillator.connect(gain).connect(audioContext.destination);
    oscillator.start(start);
    oscillator.stop(start + duration + 0.025);
  });
}
