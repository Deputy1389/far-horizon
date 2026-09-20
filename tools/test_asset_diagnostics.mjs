import assert from 'node:assert/strict';
import { summarizeSwgAssetLoad, swgMaterialColor } from '../src/assetDiagnostics.mjs';

const manifest = {
  assets: {
    sand: { url: './sand.dds' },
    wall: { url: './wall.dds' },
    metal: { url: './metal.dds' },
  },
};

assert.deepEqual(
  summarizeSwgAssetLoad(manifest, ['sand', 'wall', 'metal']),
  { total: 3, loaded: 3, failed: 0, label: 'SWG LOCAL 3/3' },
);
assert.deepEqual(
  summarizeSwgAssetLoad(manifest, ['sand', 'wall']),
  { total: 3, loaded: 2, failed: 1, label: 'SWG LOCAL 2/3' },
);
assert.deepEqual(
  summarizeSwgAssetLoad(null, []),
  { total: 0, loaded: 0, failed: 0, label: 'SWG FALLBACK' },
);
assert.equal(swgMaterialColor(true, 0xd0a16f), 0xffffff);
assert.equal(swgMaterialColor(false, 0xd0a16f), 0xd0a16f);

console.log('asset diagnostics tests passed');
