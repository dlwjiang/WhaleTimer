// All scenery is generated raster artwork; this module only selects the asset.
const base = import.meta.env?.BASE_URL ?? '/';
const backgrounds = {
  whale: 'whale-scene-v1.webp',
  claude: 'claude-scene-v1.webp',
  chatgpt: 'chatgpt-scene-v1.webp',
};
export function sceneBackground(characterId) {
  return `${base}backgrounds/${backgrounds[characterId] ?? backgrounds.whale}`;
}
