// Deterministic bridge tests, NOT evidence that SoundCloud audio works.
// Run against HTML actually produced by the Swift document builder.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(process.argv[2] || '.widget-test.html', 'utf8');
const inline = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]).join('\n');
let passed = 0;
function test(name, body) { body(); passed++; console.log('PASS', name); }
function rig() {
  const handlers = {}, messages = [], commands = [];
  const frame = { src: '' };
  let paused = true, now = 1001;
  const widget = {
    bind(event, handler) { handlers[event] = handler; },
    play() { commands.push('play'); },
    pause() { commands.push('pause'); paused = true; },
    isPaused(callback) { callback(paused); }
  };
  const Widget = element => {
    assert.equal(element, frame);
    assert.match(element.src, /^https:\/\/w\.soundcloud\.com\/player\//);
    return widget;
  };
  Widget.Events = Object.fromEntries(['READY', 'PLAY', 'PAUSE', 'FINISH', 'ERROR', 'PLAY_PROGRESS'].map(v => [v, v]));
  const context = {
    document: { getElementById: id => { assert.equal(id, 'soundcloud'); return frame; } },
    SC: { Widget }, Date: { now: () => now },
    webkit: { messageHandlers: { playback: { postMessage: message => messages.push(message) } } }
  };
  context.window = context;
  vm.createContext(context); vm.runInContext(inline, context);
  return { context, messages, commands, frame,
    initialize() { context.vibesWidgetScriptReady(); },
    event(name, data) { handlers[name](data); },
    paused(value) { paused = value; }, now(value) { now = value; } };
}
test('READY invokes play without claiming playing', () => {
  const r = rig(); r.initialize(); r.event('READY');
  assert.deepEqual(r.commands, ['play']);
  assert.deepEqual(r.messages.map(m => m.event), ['ready']);
});
test('initial PAUSE does not cancel a buffering first play', () => {
  const r = rig(); r.initialize(); r.event('READY'); r.event('PAUSE');
  assert.deepEqual(r.messages.map(m => m.event), ['ready']);
  r.paused(false); r.event('PLAY');
  assert.equal(r.messages.at(-1).event, 'playing');
});
test('native pause before READY wins over automatic start', () => {
  const r = rig(); r.context.VibesWidget.pause(); r.initialize(); r.event('READY');
  assert.deepEqual(r.commands, ['pause']);
  assert.equal(r.messages.at(-1).event, 'paused');
});
test('queued PLAY is ignored if widget is actually paused', () => {
  const r = rig(); r.initialize(); r.event('READY'); r.event('PLAY');
  assert.ok(!r.messages.some(m => m.event === 'playing'));
});
test('official widget controls remain functional after native pause', () => {
  const r = rig(); r.initialize(); r.event('READY'); r.paused(false); r.event('PLAY');
  r.context.VibesWidget.pause();
  assert.equal(r.messages.at(-1).event, 'paused');
  r.paused(false); r.event('PLAY');
  assert.equal(r.messages.at(-1).event, 'playing');
});
test('progress uses official event positions and is throttled', () => {
  const r = rig(); r.initialize(); r.event('READY');
  r.event('PLAY_PROGRESS', { currentPosition: 2500 });
  assert.equal(r.messages.at(-1).seconds, 2.5);
  r.now(1100); r.event('PLAY_PROGRESS', { currentPosition: 3000 });
  assert.equal(r.messages.at(-1).seconds, 2.5);
  r.now(2100); r.event('PLAY_PROGRESS', { currentPosition: 4000 });
  assert.equal(r.messages.at(-1).seconds, 4);
  assert.ok(r.messages.every(m => /^[0-9A-F-]{36}$/.test(m.requestID)));
});
test('finish pauses and does not advance any queue', () => {
  const r = rig(); r.initialize(); r.event('READY'); r.event('FINISH');
  assert.equal(r.commands.at(-1), 'pause');
  assert.equal(r.messages.at(-1).event, 'finished');
});
test('widget and script errors are explicit', () => {
  const r = rig(); r.initialize(); r.event('ERROR');
  r.context.vibesWidgetScriptFailed();
  assert.deepEqual(r.messages.map(m => m.event), ['error', 'error']);
});
test('sync only reports actual pause and never initiates playback', () => {
  const r = rig(); r.initialize(); r.event('READY');
  const previous = r.commands.length; r.context.VibesWidget.sync();
  assert.equal(r.commands.length, previous);
  assert.equal(r.messages.at(-1).event, 'paused');
});
console.log(`Passed: ${passed} widget bridge tests`);
