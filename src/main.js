import './style.css';
import './flip-clock.css';
import './character-theme.css';
import './glass.css';
import './desktop.css';
import './timer-action.css';
import './glass-tuner.css';
import './admin.css';
import { inject } from '@vercel/analytics';
import { mountApp } from './ui.js';

const app = mountApp(document.querySelector('#app'));
inject({ mode: import.meta.env.DEV ? 'development' : 'production' });
if (import.meta.hot) import.meta.hot.dispose(() => app.destroy());
