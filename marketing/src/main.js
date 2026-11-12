import { mountTimer } from './web-timer.js';

const root = document.querySelector('[data-web-timer]');
if (root) mountTimer(root);
