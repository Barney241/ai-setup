import { h, render, Fragment } from './vendor/preact.mjs';
import { useState, useEffect, useMemo, useRef, useCallback } from './vendor/hooks.mjs';
import { signal, computed, effect, batch, useSignal, useComputed } from './vendor/signals.mjs';
import htm from './vendor/htm.mjs';
import { ICON_PATHS } from './icons.js';

export const html = htm.bind(h);
export { h, render, Fragment, useState, useEffect, useMemo, useRef, useCallback, signal, computed, effect, batch, useSignal, useComputed };

const THEME_KEY = 'lab-ui.theme';

function readStoredTheme() {
  try {
    return localStorage.getItem(THEME_KEY);
  } catch {
    return null;
  }
}

export const theme = signal(readStoredTheme() === 'light' ? 'light' : 'dark');

effect(() => {
  document.documentElement.dataset.theme = theme.value;
  try {
    localStorage.setItem(THEME_KEY, theme.value);
  } catch {}
});

export function toggleTheme() {
  theme.value = theme.value === 'dark' ? 'light' : 'dark';
}

export const route = signal(readRoute());

function readRoute() {
  return location.hash.replace(/^#\/?/, '');
}

addEventListener('hashchange', () => { route.value = readRoute(); });

export function navigate(path) {
  location.hash = '/' + path;
}

export function useInterval(callback, milliseconds) {
  const saved = useRef(callback);
  saved.current = callback;
  useEffect(() => {
    const id = setInterval(() => saved.current(), milliseconds);
    return () => clearInterval(id);
  }, [milliseconds]);
}

export function classes(...names) {
  return names.filter(Boolean).join(' ');
}

const NUMBER = new Intl.NumberFormat('en');
const COMPACT = new Intl.NumberFormat('en', { notation: 'compact', maximumFractionDigits: 1 });

export const format = {
  number: (value) => NUMBER.format(value ?? 0),
  compact: (value) => COMPACT.format(value ?? 0),
  percent: (ratio, digits = 0) => (ratio == null || Number.isNaN(ratio) ? '–' : (ratio * 100).toFixed(digits) + '%'),
  bytes(value) {
    if (value == null) return '–';
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
    let size = value;
    let unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit += 1;
    }
    return (size >= 100 || unit === 0 ? size.toFixed(0) : size.toFixed(1)) + ' ' + units[unit];
  },
  duration(seconds) {
    if (seconds == null) return '–';
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (days > 0) return days + 'd ' + hours + 'h';
    if (hours > 0) return hours + 'h ' + minutes + 'm';
    return Math.max(minutes, 0) + 'm';
  },
  latency(milliseconds) {
    if (milliseconds == null) return '–';
    return milliseconds < 1000 ? Math.round(milliseconds) + ' ms' : (milliseconds / 1000).toFixed(1) + ' s';
  },
  relative(date) {
    if (!date) return '–';
    const seconds = Math.round((new Date(date).getTime() - Date.now()) / 1000);
    const absolute = Math.abs(seconds);
    if (absolute < 5) return 'just now';
    const text = absolute < 60 ? absolute + 's' : absolute < 3600 ? Math.round(absolute / 60) + 'm' : absolute < 86400 ? Math.round(absolute / 3600) + 'h' : Math.round(absolute / 86400) + 'd';
    return seconds >= 0 ? 'in ' + text : text + ' ago';
  },
};

export function toneForUsage(ratio) {
  if (ratio == null) return '';
  if (ratio >= 0.9) return 'critical';
  if (ratio >= 0.75) return 'serious';
  if (ratio >= 0.5) return 'warning';
  return 'good';
}

export function Icon({ name, small }) {
  return html`<svg class=${classes('icon', small && 'small')} viewBox="0 0 24 24" aria-hidden="true">
    ${(ICON_PATHS[name] || ICON_PATHS.box).map((path) => html`<path d=${path} />`)}
  </svg>`;
}

export function Button({ icon, children, variant, size, onClick, href, title, disabled, className: extra, type = 'button' }) {
  const className = classes('button', variant, size, icon && !children && 'icon-only', extra);
  const body = html`${icon && html`<${Icon} name=${icon} small=${size === 'small'} />`}${children}`;
  if (href) return html`<a class=${className} href=${href} title=${title} target="_blank" rel="noreferrer">${body}</a>`;
  return html`<button class=${className} type=${type} onClick=${onClick} title=${title} aria-label=${title} disabled=${disabled}>${body}</button>`;
}

export function Badge({ tone, children, dot }) {
  return html`<span class=${classes('badge', tone)}>${dot && html`<span class=${classes('dot', tone)} />`}${children}</span>`;
}

export function Dot({ tone = 'unknown', title }) {
  return html`<span class=${classes('dot', tone)} title=${title} />`;
}

export function Avatar({ src, icon, label, tone }) {
  return html`<span class=${classes('avatar', tone && 'tone-' + tone)}>
    ${src ? html`<img src=${src} alt="" />` : icon ? html`<${Icon} name=${icon} />` : (label || '?').slice(0, 1).toUpperCase()}
  </span>`;
}

export function Card({ title, subtitle, actions, flush, className, children }) {
  return html`<section class=${classes('card', flush && 'flush', className)}>
    ${(title || actions) && html`<header class="card-head">
      <div class="truncate"><h2>${title}</h2>${subtitle && html`<p class="muted">${subtitle}</p>`}</div>
      <span class="spacer" />${actions}
    </header>`}
    ${children}
  </section>`;
}

export function Section({ title, subtitle, actions, children }) {
  return html`<section class="section">
    <header class="section-head"><h2>${title}</h2>${subtitle && html`<span class="muted">${subtitle}</span>`}<span class="spacer" />${actions}</header>
    ${children}
  </section>`;
}

export function Tile({ label, icon, tone, value, unit, delta, caption, trend }) {
  return html`<section class="card tile">
    <div class="tile-label">${icon && html`<span class=${classes('tile-icon', tone)}><${Icon} name=${icon} /></span>`}${label}</div>
    <div class="tile-value">${value}${unit && html`<small>${unit}</small>`}</div>
    <div class="tile-foot">
      <div>
        ${delta != null && html`<span class=${classes('delta', delta >= 0 ? 'up' : 'down')}><${Icon} name=${delta >= 0 ? 'arrowUp' : 'arrowDown'} small />${Math.abs(delta).toFixed(0)}%</span>`}
        ${caption && html`<span class="muted"> ${caption}</span>`}
      </div>
      <span class="spacer" />
      ${trend && html`<div class="tile-trend"><${Sparkline} values=${trend} /></div>`}
    </div>
  </section>`;
}

export function Meter({ label, ratio, value, caption, tone }) {
  const width = Math.max(0, Math.min(1, ratio ?? 0)) * 100;
  return html`<div class="meter">
    <div class="meter-head"><span class="secondary">${label}</span><span class="meter-value">${value ?? format.percent(ratio)}</span></div>
    <div class="meter-track"><div class=${classes('meter-fill', tone ?? toneForUsage(ratio))} style=${{ width: width + '%' }} /></div>
    ${caption && html`<div class="meter-caption">${caption}</div>`}
  </div>`;
}

export function Stats({ items }) {
  return html`<div class="stats">
    ${items.map((item) => html`<div class="stat" title=${item.title}>
      <div class="stat-value">${item.value ?? '–'}</div>
      <div class="stat-label">${item.label}</div>
    </div>`)}
  </div>`;
}

export function ServiceCard({ name, description, href, icon, iconSrc, tone, status, host, stats, children }) {
  const statusTone = status === 'up' ? 'good' : status === 'down' ? 'critical' : status === 'degraded' ? 'warning' : 'unknown';
  const body = html`
    <div class="service-head">
      <${Avatar} src=${iconSrc} icon=${icon} label=${name} tone=${tone} />
      <div class="truncate">
        <div class="service-name truncate">${name}</div>
        <div class="service-desc truncate">${description}</div>
      </div>
      <${Dot} tone=${statusTone} title=${status || 'unknown'} />
    </div>
    ${stats && stats.length > 0 && html`<${Stats} items=${stats} />`}
    ${children}
    ${host && html`<div class="service-host truncate">${host}</div>`}`;
  const className = classes('service', status === 'down' && 'down');
  if (href) return html`<a class=${className} href=${href} target="_blank" rel="noreferrer">${body}</a>`;
  return html`<div class=${className}>${body}</div>`;
}

export function HostCard({ name, description, online, current, os, kernel, uptime, version, generation, updated, cpu, memory, disk, address, href, onOpen }) {
  const openOnEnter = (event) => { if (event.key === 'Enter' && event.target === event.currentTarget) onOpen(); };
  const opener = onOpen ? { role: 'link', tabIndex: 0, onClick: onOpen, onKeyDown: openOnEnter } : {};
  return html`<section class=${classes('card host', !online && 'offline', current && 'current', onOpen && 'clickable')} ...${opener}>
    <div class="host-head">
      <${Avatar} icon="server" tone=${online ? 1 : null} />
      <div class="truncate">
        <div class="row"><h3>${name}</h3>${current && html`<${Badge} tone="accent">this device</${Badge}>`}</div>
        <div class="muted small truncate">${description}</div>
      </div>
      <span class="spacer" />
      <${Badge} tone=${online ? 'good' : 'critical'} dot>${online ? 'online' : 'offline'}</${Badge}>
    </div>
    <div class="host-meta">
      ${os && html`<span><${Icon} name="layers" small />${os}</span>`}
      ${kernel && html`<span><${Icon} name="terminal" small />${kernel}</span>`}
      ${uptime != null && html`<span><${Icon} name="clock" small />up ${format.duration(uptime)}</span>`}
      ${version && html`<span class="mono"><${Icon} name="hash" small />${version}</span>`}
      ${updated && html`<span><${Icon} name="refresh" small />${generation ? 'gen ' + generation + ' · ' : ''}updated ${format.relative(updated)}</span>`}
      ${address && (href ? html`<a href=${href} class="mono" onClick=${(event) => event.stopPropagation()}><${Icon} name="link" small />${address}</a>` : html`<span class="mono"><${Icon} name="network" small />${address}</span>`)}
    </div>
    <div class="host-meters">
      <${Meter} label="CPU" ratio=${cpu} />
      <${Meter} label="Memory" ratio=${memory?.ratio} caption=${memory && format.bytes(memory.used) + ' of ' + format.bytes(memory.total)} />
      <${Meter} label="Disk" ratio=${disk?.ratio} caption=${disk && format.bytes(disk.free) + ' free'} />
    </div>
  </section>`;
}

export function Table({ columns, rows, empty = 'Nothing here yet', rowKey }) {
  if (!rows || rows.length === 0) return html`<${Empty} icon="box">${empty}</${Empty}>`;
  return html`<div class="table-wrap"><table class="table">
    <thead><tr>${columns.map((column) => html`<th class=${column.align}>${column.label}</th>`)}</tr></thead>
    <tbody>${rows.map((row, index) => html`<tr key=${rowKey ? rowKey(row) : index}>
      ${columns.map((column) => html`<td class=${column.align}>${column.render ? column.render(row) : row[column.key]}</td>`)}
    </tr>`)}</tbody>
  </table></div>`;
}

export function Segmented({ options, value, onChange }) {
  return html`<div class="segmented" role="tablist">
    ${options.map((option) => html`<button type="button" role="tab" aria-selected=${option.value === value} class=${option.value === value ? 'active' : ''} onClick=${() => onChange(option.value)}>${option.label}</button>`)}
  </div>`;
}

export function Switch({ on, onChange, label }) {
  return html`<button type="button" role="switch" aria-checked=${!!on} aria-label=${label} class=${classes('switch', on && 'on')} onClick=${() => onChange(!on)} />`;
}

export function Empty({ icon = 'box', children }) {
  return html`<div class="empty"><${Icon} name=${icon} /><div>${children}</div></div>`;
}

export function Banner({ tone, children }) {
  return html`<div class=${classes('banner', tone)}><${Icon} name="alert" /><div>${children}</div></div>`;
}

export function LogView({ lines, empty = 'No log lines yet' }) {
  const view = useRef(null);
  useEffect(() => {
    if (view.current) view.current.scrollTop = view.current.scrollHeight;
  }, [lines]);
  if (!lines || lines.length === 0 || (lines.length === 1 && lines[0] === '')) return html`<${Empty} icon="terminal">${empty}</${Empty}>`;
  return html`<pre class="log" ref=${view}>${lines.map((line) => {
    const [, time, raw] = line.match(/^(\S+)\s+(.*)$/) || [null, '', line];
    const rest = raw.replace(/^\S+ [^\s:\[]+(\[\d+\])?: /, '');
    const tone = /\b(error|fatal|panic|failed)\b/i.test(rest) ? 'critical' : /\bwarn(ing)?\b/i.test(rest) ? 'warning' : null;
    return html`<div class=${classes('log-line', tone)}><span class="log-time">${time.replace(/^\d{4}-\d{2}-\d{2}T/, '').replace(/[+-]\d{2}:?\d{2}$/, '')}</span>${rest}</div>`;
  })}</pre>`;
}

export function Skeleton({ height = 14, width = '100%' }) {
  return html`<div class="skeleton" style=${{ height: height + 'px', width }} />`;
}

export function Sparkline({ values }) {
  const points = values.filter((value) => value != null);
  if (points.length < 2 || points.every((value) => value === 0)) return null;
  const max = Math.max(...points) || 1;
  const min = Math.min(...points);
  const span = max - min || 1;
  const step = 100 / (points.length - 1);
  const coordinates = points.map((value, index) => [index * step, 28 - ((value - min) / span) * 26]);
  const line = coordinates.map(([x, y], index) => (index ? 'L' : 'M') + x.toFixed(2) + ' ' + y.toFixed(2)).join(' ');
  return html`<svg class="spark" viewBox="0 0 100 30" preserveAspectRatio="none" aria-hidden="true">
    <path class="spark-area" d=${line + ' L100 30 L0 30 Z'} />
    <path class="spark-line" d=${line} vector-effect="non-scaling-stroke" />
  </svg>`;
}

function niceCeiling(value) {
  if (value <= 0) return 1;
  const magnitude = 10 ** Math.floor(Math.log10(value));
  const normalized = value / magnitude;
  const step = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return step * magnitude;
}

export const tooltip = signal(null);

export function TooltipLayer() {
  const current = tooltip.value;
  if (!current) return null;
  const left = Math.min(current.x + 14, innerWidth - 220);
  return html`<div class="tooltip" style=${{ left: left + 'px', top: current.y + 14 + 'px' }}>
    <div class="tooltip-title">${current.title}</div>
    ${current.rows.map((row) => html`<div class="tooltip-row"><span>${row.label}</span><b>${row.value}</b></div>`)}
  </div>`;
}

export function BarChart({ buckets, labels, formatValue = format.compact }) {
  const max = niceCeiling(Math.max(0, ...buckets.map((bucket) => bucket.value)));
  const lines = [0, 0.25, 0.5, 0.75, 1];
  return html`<div class="chart">
    <div class="chart-plot">
      <div class="chart-axis">${lines.map((line) => html`<span style=${{ bottom: line * 100 + '%' }}>${formatValue(max * line)}</span>`)}</div>
      <div class="chart-area">
        ${lines.slice(1).map((line) => html`<div class="chart-grid" style=${{ bottom: line * 100 + '%' }} />`)}
        <div class="chart-bars">
          ${buckets.map((bucket) => html`<div class="chart-bar"
              onMouseMove=${(event) => { tooltip.value = { x: event.clientX, y: event.clientY, title: bucket.label, rows: bucket.rows || [{ label: 'Value', value: formatValue(bucket.value) }] }; }}
              onMouseLeave=${() => { tooltip.value = null; }}>
            ${bucket.critical > 0 && html`<div class="bar-fill critical" style=${{ height: (bucket.critical / max) * 100 + '%' }} />`}
            <div class="bar-fill" style=${{ height: ((bucket.value - (bucket.critical || 0)) / max) * 100 + '%' }} />
          </div>`)}
        </div>
      </div>
    </div>
    ${labels && html`<div class="chart-x"><span /><div>${labels.map((label) => html`<span>${label}</span>`)}</div></div>`}
  </div>`;
}

export function StackBar({ parts }) {
  const total = parts.reduce((sum, part) => sum + part.value, 0) || 1;
  return html`<div class="stackbar">
    ${parts.filter((part) => part.value > 0).map((part, index) => html`<div class=${'s' + (index + 1)} title=${part.label} style=${{ width: (part.value / total) * 100 + '%' }} />`)}
  </div>`;
}

export function Legend({ items }) {
  return html`<div class="legend">
    ${items.map((item, index) => html`<span><i class=${classes('swatch', item.tone || (index > 0 && 's' + (index + 1)))} />${item.label}${item.value != null && html`<b class="num"> ${item.value}</b>`}</span>`)}
  </div>`;
}

export const toasts = signal([]);

export function toast(message, tone = 'good') {
  const entry = { id: Math.random(), message, tone };
  toasts.value = [...toasts.value, entry];
  setTimeout(() => { toasts.value = toasts.value.filter((item) => item !== entry); }, 3500);
}

export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const buffer = document.createElement('textarea');
    buffer.value = text;
    buffer.readOnly = true;
    buffer.className = 'copy-buffer';
    document.body.append(buffer);
    buffer.select();
    document.execCommand('copy');
    buffer.remove();
  }
}

export function CopyButton({ value, label }) {
  const copy = async (event) => {
    event.stopPropagation();
    await copyText(value);
    toast('Copied ' + value);
  };
  return html`<${Button} size="small" variant="ghost" icon="copy" title=${'Copy ' + (label || value)} onClick=${copy} />`;
}

export function ToastLayer() {
  return html`<div class="toast-stack">
    ${toasts.value.map((entry) => html`<div class=${classes('toast', entry.tone)} key=${entry.id}><${Icon} name=${entry.tone === 'critical' ? 'alert' : 'check'} small />${entry.message}</div>`)}
  </div>`;
}

export const paletteOpen = signal(false);

addEventListener('keydown', (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
    event.preventDefault();
    paletteOpen.value = !paletteOpen.value;
  }
  if (event.key === 'Escape') paletteOpen.value = false;
});

export function CommandPalette({ items, placeholder = 'Search services, hosts and pages…' }) {
  const [query, setQuery] = useState('');
  const [active, setActive] = useState(0);
  const input = useRef(null);
  const open = paletteOpen.value;

  useEffect(() => {
    if (open) {
      setQuery('');
      setActive(0);
      setTimeout(() => input.current?.focus(), 0);
    }
  }, [open]);

  const matches = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return items.filter((item) => !needle || [item.label, item.group, item.hint].join(' ').toLowerCase().includes(needle)).slice(0, 50);
  }, [items, query]);

  if (!open) return null;

  function choose(item) {
    paletteOpen.value = false;
    if (item.href) window.open(item.href, '_blank', 'noreferrer');
    if (item.action) item.action();
  }

  function onKey(event) {
    if (event.key === 'ArrowDown') { event.preventDefault(); setActive(Math.min(active + 1, matches.length - 1)); }
    if (event.key === 'ArrowUp') { event.preventDefault(); setActive(Math.max(active - 1, 0)); }
    if (event.key === 'Enter' && matches[active]) choose(matches[active]);
  }

  let lastGroup = null;
  return html`<div class="palette-backdrop" onClick=${(event) => { if (event.target === event.currentTarget) paletteOpen.value = false; }}>
    <div class="palette" role="dialog" aria-label="Search">
      <label class="palette-input"><${Icon} name="search" />
        <input ref=${input} value=${query} placeholder=${placeholder} onInput=${(event) => { setQuery(event.target.value); setActive(0); }} onKeyDown=${onKey} />
        <span class="kbd">esc</span>
      </label>
      <div class="palette-list">
        ${matches.length === 0 && html`<${Empty} icon="search">No matches</${Empty}>`}
        ${matches.map((item, index) => {
          const header = item.group !== lastGroup ? html`<div class="palette-group">${item.group}</div>` : null;
          lastGroup = item.group;
          return html`${header}<div class=${classes('palette-item', index === active && 'active')} onMouseEnter=${() => setActive(index)} onClick=${() => choose(item)}>
            <${Avatar} src=${item.iconSrc} icon=${item.icon} label=${item.label} tone=${item.tone} />
            <span>${item.label}</span><span class="muted">${item.hint}</span>
          </div>`;
        })}
      </div>
    </div>
  </div>`;
}

export function SearchButton() {
  return html`<button type="button" class="search" onClick=${() => { paletteOpen.value = true; }}>
    <${Icon} name="search" small /><span class="label">Search</span><span class="kbd">Ctrl K</span>
  </button>`;
}

export function ThemeButton() {
  return html`<${Button} variant="ghost" icon=${theme.value === 'dark' ? 'sun' : 'moon'} title="Toggle theme" onClick=${toggleTheme} />`;
}

export const navOpen = signal(false);

export function AppShell({ brand, subtitle, logo = 'logo', nav, active, footer, title, description, actions, children }) {
  return html`<div class=${classes('shell', navOpen.value && 'nav-open')}>
    <aside class="sidebar">
      <div class="brand">
        <span class="brand-mark"><${Icon} name=${logo} /></span>
        <div><div class="brand-name">${brand}</div>${subtitle && html`<div class="brand-sub">${subtitle}</div>`}</div>
      </div>
      ${nav.map((group) => html`<nav class="nav">
        ${group.label && html`<div class="nav-label">${group.label}</div>`}
        ${group.items.map((item) => html`<a class=${classes('nav-item', item.id === active && 'active')} href=${item.href || '#/' + item.id} target=${item.external ? '_blank' : null} onClick=${() => { navOpen.value = false; }}>
          <${Icon} name=${item.icon} />${item.label}
          ${item.count != null && html`<span class="count">${item.count}</span>`}
          ${item.tone && html`<span class=${classes('dot', item.tone)} />`}
        </a>`)}
      </nav>`)}
      <div class="sidebar-footer">${footer}</div>
    </aside>
    <div class="main">
      <header class="topbar">
        <${Button} variant="ghost" className="menu-button" icon="menu" title="Menu" onClick=${() => { navOpen.value = !navOpen.value; }} />
        <div class="topbar-title"><h1 class="truncate">${title}</h1>${description && html`<span class="muted truncate">${description}</span>`}</div>
        <span class="spacer" />
        ${actions}
        <${ThemeButton} />
      </header>
      <main class="content">${children}</main>
    </div>
    <${TooltipLayer} />
    <${ToastLayer} />
  </div>`;
}
