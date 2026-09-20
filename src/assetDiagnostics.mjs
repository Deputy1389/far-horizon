export function summarizeSwgAssetLoad(manifest, loadedRoles = []) {
  const assetKeys = Object.keys(manifest?.assets || {});
  const knownKeys = new Set(assetKeys);
  const loaded = new Set(loadedRoles.filter((role) => knownKeys.has(role))).size;
  const total = assetKeys.length;
  return {
    total,
    loaded,
    failed: Math.max(0, total - loaded),
    label: total > 0 ? `SWG LOCAL ${loaded}/${total}` : 'SWG FALLBACK',
  };
}

export function swgMaterialColor(hasLocalTexture, fallbackColor) {
  return hasLocalTexture ? 0xffffff : fallbackColor;
}
