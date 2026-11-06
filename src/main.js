import './style.css';
import './flip-clock.css';
import './character-theme.css';
import './glass.css';
import './desktop.css';
import './glass-tuner.css';
import './admin.css';
import { mountApp } from './ui.js';

const app = mountApp(document.querySelector('#app'));
if (import.meta.hot) import.meta.hot.dispose(() => app.destroy());
