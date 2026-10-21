import { EditorState, StateField, StateEffect, Compartment, Prec } from '@codemirror/state';
import { EditorView, Decoration, WidgetType, keymap, placeholder } from '@codemirror/view';
import { defaultKeymap, history, historyKeymap, undo, redo, indentWithTab } from '@codemirror/commands';
import { markdown, markdownLanguage, markdownKeymap } from '@codemirror/lang-markdown';
import { syntaxTree } from '@codemirror/language';
import './editor.css';

// One source document: decorations change its appearance without rewriting Markdown.
export function createLiveEditor(parent, initial, renderMarkdown) {
  let raw = false;
  const mode = StateEffect.define();
  const sourceMode = new Compartment();
  const notify = (view) => {
    window.webkit?.messageHandlers?.sprigEditor?.postMessage({ text: view.state.doc.toString() });
    window.dispatchEvent(new CustomEvent('sprig-edit', { detail: view.state.doc.toString() }));
  };
  class Rendered extends WidgetType {
    constructor(text, from, to, block = false) { super(); Object.assign(this, { text, from, to, block }); }
    eq(other) { return this.text === other.text && this.from === other.from && this.to === other.to; }
    toDOM(view) {
      const dom = document.createElement(this.block ? 'div' : 'span');
      dom.className = this.block ? 'sprig-rendered-block' : 'sprig-rendered-inline';
      dom.innerHTML = renderMarkdown(this.text);
      dom.setAttribute('aria-label', 'Rendered Markdown. Click to edit source.');
      dom.addEventListener('mousedown', e => {
        if (e.target.closest('a')) return;
        if (e.target.closest('summary')) { e.stopPropagation(); return; }
        e.preventDefault();
        view.dispatch({ selection: { anchor: Math.min(this.from, view.state.doc.length) }, scrollIntoView: true });
        view.focus();
      });
      return dom;
    }
    ignoreEvent() { return true; }
  }
  class Bullet extends WidgetType {
    constructor(text) { super(); this.text = text; }
    eq(other) { return this.text === other.text; }
    toDOM() { const el = document.createElement('span'); el.className = 'sprig-bullet'; el.textContent = this.text; return el; }
    ignoreEvent() { return false; }
  }
  class Checkbox extends WidgetType {
    constructor(from, checked) { super(); this.from = from; this.checked = checked; }
    eq(other) { return this.from === other.from && this.checked === other.checked; }
    toDOM(view) {
      const input = document.createElement('input'); input.type = 'checkbox'; input.checked = this.checked;
      input.setAttribute('aria-label', this.checked ? 'Mark task incomplete' : 'Mark task complete');
      input.addEventListener('mousedown', e => e.stopPropagation());
      input.addEventListener('change', () => {
        view.dispatch({ changes: { from: this.from + 1, to: this.from + 2, insert: input.checked ? 'x' : ' ' } });
      }); return input;
    }
    ignoreEvent() { return true; }
  }
  function decorations(state) {
    if (raw) return Decoration.none;
    const ranges = [], replaced = [], quoteLines = new Set();
    const selection = state.selection.main;
    const active = (from, to) => selection.from <= to && selection.to >= from;
    const hidden = (from, to) => { if (to > from) ranges.push(Decoration.replace({}).range(from, to)); };
    const mark = (from, to, cls) => { if (to > from) ranges.push(Decoration.mark({ class: cls }).range(from, to)); };
    // Display maths and recall sections share the full Markdown renderer.
    const source = state.doc.toString();
    const blocks = /\$\$[\s\S]+?\$\$|<details>\s*<summary>[\s\S]*?<\/details>/g;
    for (const match of source.matchAll(blocks)) {
      const from = match.index, to = from + match[0].length;
      if (active(from, to)) continue;
      let node = syntaxTree(state).resolveInner(from, 1), code = false;
      for (; node; node = node.parent) if (['InlineCode','FencedCode','CodeText'].includes(node.name)) code = true;
      if (code) continue;
      const block = state.doc.lineAt(from).from === from && state.doc.lineAt(to).to === to;
      ranges.push(Decoration.replace({ widget: new Rendered(match[0], from, to, block), block }).range(from, to));
      replaced.push([from, to]);
    }
    // Complex blocks render in place when the caret leaves them, then reopen as source on click.
    syntaxTree(state).iterate({ enter(node) {
      const { name, from, to } = node;
      if (replaced.some(r => from >= r[0] && to <= r[1])) return false;
      if (['Table', 'FencedCode', 'HorizontalRule'].includes(name) && !active(from, to)) {
        ranges.push(Decoration.replace({ widget: new Rendered(state.doc.sliceString(from, to), from, to, true), block: true }).range(from, to));
        replaced.push([from, to]); return false;
      }
      const heading = name.match(/^(?:ATX|Setext)Heading([1-6])$/);
      if (heading) ranges.push(Decoration.line({ class: `sprig-heading sprig-h${heading[1]}` }).range(state.doc.lineAt(from).from));
      if (name === 'Blockquote') {
        for (let number = state.doc.lineAt(from).number; number <= state.doc.lineAt(to).number; number++) {
          const line = state.doc.line(number);
          if (!quoteLines.has(number)) {
            ranges.push(Decoration.line({ class: 'sprig-quote-line' }).range(line.from));
            quoteLines.add(number);
          }
        }
      }
      if (name === 'QuoteMark') {
        const space = state.doc.sliceString(to, state.doc.lineAt(from).to).match(/^[ \t]?/)?.[0].length ?? 0;
        hidden(from, to + space);
        return;
      }
      const styles = { StrongEmphasis: 'sprig-bold', Emphasis: 'sprig-italic', Strikethrough: 'sprig-strike', InlineCode: 'sprig-code', Link: 'sprig-link', Blockquote: 'sprig-quote', CodeText: 'sprig-code' };
      if (styles[name]) mark(from, to, styles[name]);
      if (['HeaderMark', 'EmphasisMark', 'StrikethroughMark', 'CodeMark', 'QuoteMark'].includes(name)) {
        if (!active(node.node.parent.from, node.node.parent.to)) {
          // Hide the ATX separator with its hashes so the rendered title starts
          // at the same left edge as body text. The source remains untouched.
          let end = to;
          if (name === 'HeaderMark' && from === state.doc.lineAt(from).from && /^#{1,6}$/.test(state.doc.sliceString(from, to))) {
            end += state.doc.sliceString(to, state.doc.lineAt(from).to).match(/^[ \t]+/)?.[0].length ?? 0;
          }
          hidden(from, end);
        } else mark(from, to, 'sprig-marker');
      }
      if (name === 'Link' && !active(from, to)) {
        const labelEnd = state.doc.sliceString(from, to).indexOf('](');
        if (labelEnd > 0) { hidden(from, from + 1); hidden(from + labelEnd, to); }
      }
      if (name === 'Image' && !active(from, to)) {
        ranges.push(Decoration.replace({ widget: new Rendered(state.doc.sliceString(from, to), from, to) }).range(from, to));
        replaced.push([from, to]); return false;
      }
    }});
    for (let i = 1; i <= state.doc.lines; i++) {
      const line = state.doc.line(i);
      if (replaced.some(([from, to]) => line.from >= from && line.from < to)) continue;
      const task = line.text.match(/^(\s*[-*+] )\[([ xX])\] /);
      if (task && !active(line.from, line.to)) {
        const from = line.from + task[1].length;
        ranges.push(Decoration.replace({ widget: new Checkbox(from, task[2] !== ' ') }).range(from, from + 3));
        hidden(line.from, from);
      } else {
        const bullet = line.text.match(/^\s*([-*+]) /);
        if (bullet && !active(line.from, line.to)) ranges.push(Decoration.replace({ widget: new Bullet('• ') }).range(line.from, line.from + bullet[0].length));
      }
      // A closing emphasis marker after a just-typed space is temporarily invalid
      // Markdown. Keep its active editing appearance until the next word arrives.
      for (const match of line.text.matchAll(/(\*\*|__)(?=\S)((?:(?!\1)[^\n])*?[ \t]+)\1/g)) {
        const from = line.from + match.index, to = from + match[0].length;
        if (!active(from, to)) continue;
        let node = syntaxTree(state).resolveInner(from + 2, 1), code = false;
        for (; node; node = node.parent) if (['InlineCode', 'FencedCode', 'CodeText'].includes(node.name)) code = true;
        if (!code) {
          mark(from + 2, to - 2, 'sprig-bold');
          mark(from, from + 2, 'sprig-marker'); mark(to - 2, to, 'sprig-marker');
        }
      }
      // Inline maths uses the same KaTeX renderer as exported previews.
      const math = /\$([^$\n]+)\$/g;
      for (const match of line.text.matchAll(math)) {
        const from = line.from + match.index, to = from + match[0].length;
        if (active(from, to) || replaced.some(([a,b]) => from < b && to > a)) continue;
        // Never interpret currency/math inside inline or fenced code.
        let node = syntaxTree(state).resolveInner(from, 1), code = false;
        for (; node; node = node.parent) if (['InlineCode','FencedCode','CodeText'].includes(node.name)) code = true;
        if (!code) ranges.push(Decoration.replace({ widget: new Rendered(match[0], from, to) }).range(from, to));
      }
    }
    return Decoration.set(ranges, true);
  }
  const live = StateField.define({
    create: decorations,
    update(value, tr) { return tr.docChanged || tr.selection || tr.effects.some(e => e.is(mode)) ? decorations(tr.state) : value; },
    provide: field => EditorView.decorations.from(field),
  });
  const view = new EditorView({ parent, state: EditorState.create({ doc: initial, extensions: [
    history(), markdown({ base: markdownLanguage }), live, EditorView.lineWrapping,
    Prec.highest(keymap.of([
      { key: 'Mod-b', run: () => { action('bold'); return true; } },
      { key: 'Mod-i', run: () => { action('italic'); return true; } },
      { key: 'Enter', run: view => {
        const selection = view.state.selection.main, line = view.state.doc.lineAt(selection.head);
        if (raw || !selection.empty || !/^\s*(>\s*)+$/.test(line.text)) return false;
        view.dispatch({ changes: { from: line.from, to: line.to, insert: '\n' }, selection: { anchor: line.from + 1 }, userEvent: 'input' });
        return true;
      } },
      ...markdownKeymap, ...historyKeymap, ...defaultKeymap, indentWithTab])),
    placeholder('Write a note…'),
    EditorView.contentAttributes.of({ 'aria-label': 'Note text', spellcheck: 'true' }),
    EditorView.updateListener.of(update => { if (update.docChanged) notify(update.view); }),
    sourceMode.of([]),
  ]}) });
  function action(kind) {
    if (kind === 'focus-start') {
      view.dispatch({ selection: { anchor: 0 }, scrollIntoView: true });
      view.focus();
      return;
    }
    if (kind === 'undo' || kind === 'redo') { (kind === 'undo' ? undo : redo)(view); view.focus(); return; }
    const selection = view.state.selection.main, doc = view.state.doc;
    let from = selection.from, to = selection.to, insert, anchor, head;
    const prefix = { heading: '## ', bullets: '- ', checklist: '- [ ] ', quote: '> ' };
    if (kind in prefix || kind === 'numbered') {
      from = doc.lineAt(from).from;
      to = doc.lineAt(to > selection.from && doc.sliceString(to - 1, to) === '\n' ? to - 1 : to).to;
      insert = doc.sliceString(from, to).split('\n').map((line, i) => (kind === 'numbered' ? `${i + 1}. ` : prefix[kind]) + line.replace(/^(#{1,6} |[-*+] (?:\[[ xX]\] )?|\d+\. |> )/, '')).join('\n');
      anchor = selection.empty ? from + insert.length : from; head = from + insert.length;
    } else {
      const markers = { bold: ['**','**'], italic: ['*','*'], code: ['`','`'], link: ['[','](https://example.com)'] }[kind];
      if (!markers) return;
      const text = doc.sliceString(from, to);
      // Repeating an inline format removes its surrounding markers.
      if (from >= markers[0].length && doc.sliceString(from - markers[0].length, from) === markers[0] && doc.sliceString(to, to + markers[1].length) === markers[1]) {
        from -= markers[0].length; to += markers[1].length; insert = text; anchor = from; head = from + text.length;
      } else { insert = markers[0] + text + markers[1]; anchor = from + markers[0].length; head = anchor + text.length; }
    }
    view.dispatch({ changes: { from, to, insert }, selection: { anchor, head }, scrollIntoView: true, userEvent: 'input.format' });
    view.focus();
  }
  return {
    view, action,
    getText: () => view.state.doc.toString(),
    setText(text) { if (text !== view.state.doc.toString()) view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: text }, selection: { anchor: Math.min(view.state.selection.main.head, text.length) } }); },
    setMode(value) { raw = value; view.dom.classList.toggle("sprig-source", value); view.dispatch({ effects: mode.of(value) }); },
    focus() { view.focus(); },
  };
}
