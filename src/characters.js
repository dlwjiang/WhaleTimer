const base = import.meta.env?.BASE_URL ?? '/';

export const EXPRESSIONS = ['idle', 'happy', 'cute', 'angry', 'frustrated', 'bell'];
export const CHARACTERS = [
  {
    id: 'whale', name: '鲸鱼女仆',
    description: '蓝发鲸鱼女仆，身穿藏蓝色裙子和白色围裙',
    images: Object.fromEntries(EXPRESSIONS.map(name => [name, `avatars/${name}.webp`])),
  },
  {
    id: 'claude', name: 'Claude',
    description: '橙发Q版学者，身穿象牙白裙子，手持书本',
    images: Object.fromEntries(EXPRESSIONS.map(name => [name, `avatars/claude/${name}.webp`])),
  },
  {
    id: 'chatgpt', name: 'ChatGPT',
    description: '白发Q版小龙，带淡紫色翅膀和蓝色云朵伙伴',
    images: Object.fromEntries(EXPRESSIONS.map(name => [name, `avatars/chatgpt/${name}.webp`])),
  },
];

export function getCharacter(id) {
  return CHARACTERS.find(character => character.id === id) ?? CHARACTERS[0];
}

export function characterImage(character, expression = 'idle') {
  return `${base}${character.images[expression] ?? character.images.idle}`;
}
