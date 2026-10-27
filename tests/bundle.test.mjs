import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { bundle } from '../tools/build.mjs';

const workspace = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const luau = process.env.LUAU_BIN || 'luau';

test('committed executor bundle matches source', () => {
  assert.equal(readFileSync(join(workspace, 'dist/MacUI.luau'), 'utf8').replace(/\r\n/g, '\n'), bundle(join(workspace, 'src/shared/UILibrary')));
});

test('module paths, cache, errors and executor parenting', () => {
  const root = mkdtempSync(join(tmpdir(), 'macui-test-'));
  try {
    mkdirSync(join(root, 'Core'));
    writeFileSync(join(root, 'init.luau'), `return {
      CreateWindow = function(_, options) return options end,
      First = require(script.Core.Value), Second = require(script.Core.Value),
      Other = require(script.Other),
    }`);
    writeFileSync(join(root, 'Core/Value.luau'), 'return { parent = script.Parent.Name, value = 7 }');
    writeFileSync(join(root, 'Other.luau'), 'return require(script.Parent.Core.Value)');
    const output = join(root, 'check.luau');
    const compiled = bundle(root);
    writeFileSync(output, `local hidden = {}
local typeof = function(value) return if value == hidden then "Instance" else type(value) end
local gethui = function() return hidden end
local MacUI = (function()\n${compiled}\nend)()
assert(MacUI.First == MacUI.Second and MacUI.First == MacUI.Other)
assert(MacUI.First.parent == "Core" and MacUI.First.value == 7)
local options = { Scale = 1 }
assert(MacUI:CreateWindow(options).Parent == hidden and options.Parent == nil)
assert(MacUI:CreateWindow({ Parent = "explicit" }).Parent == "explicit")
gethui = function() error("unavailable") end
assert(MacUI:CreateWindow().Parent == nil)
gethui = function() return "invalid" end
assert(MacUI:CreateWindow().Parent == nil)
gethui = nil
assert(MacUI:CreateWindow().Parent == nil)
`);
    let run = spawnSync(luau, [output], { encoding: 'utf8' });
    assert.equal(run.status, 0, run.error?.message || run.stderr || run.stdout);
    rmSync(output);
    writeFileSync(join(root, 'Core/Value.luau'), 'return require(script.Parent.Value)');
    writeFileSync(output, `local ok, message = pcall(function()\n${bundle(root)}\nend)
assert(not ok and string.find(message, "circular module dependency", 1, true))`);
    run = spawnSync(luau, [output], { encoding: 'utf8' });
    assert.equal(run.status, 0, run.error?.message || run.stderr || run.stdout);
  } finally {
    assert.equal(dirname(realpathSync(root)), realpathSync(tmpdir()));
    assert(basename(root).startsWith('macui-test-'));
    rmSync(root, { recursive: true, force: true });
  }
});
