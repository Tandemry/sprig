import { test, expect } from '@playwright/test';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const modifier = process.platform === 'darwin' ? 'Meta' : 'Control';
const file = pathToFileURL(resolve('native/Sources/SprigApp/Resources/Markdown/index.html')).href;
async function start(page: any, text = '') {
  const errors: string[] = [];
  page.on('pageerror', (e: Error) => errors.push(e.message));
  await page.goto(file);
  await page.evaluate((text: string) => (window as any).sprigStartEditor(text), text);
  return errors;
}
async function source(page: any) { return page.evaluate(() => (window as any).sprigEditor.getText()); }

test('blank note is editable, heading and bold render while typing, source stays intact', async ({ page }) => {
  const errors = await start(page);
  const editor = page.getByRole('textbox', { name: 'Note text' });
  await expect(editor).toBeEditable();
  await page.keyboard.type('## Study notes');
  await expect(page.locator('.sprig-h2')).toContainText('Study notes');
  await page.keyboard.press('Enter');
  await page.keyboard.type('**Important** and *useful*');
  await expect(page.locator('.sprig-bold')).toContainText('Important');
  await expect(page.locator('.sprig-italic')).toContainText('useful');
  expect(await source(page)).toContain('**Important** and *useful*');
  await page.keyboard.press('Enter');
  await expect(page.locator('.sprig-marker').filter({ hasText: '**' })).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('formatting, source mode and undo share one document and selection', async ({ page }) => {
  const errors = await start(page, 'First line\nSecond line');
  await page.keyboard.press(`${modifier}+a`);
  await page.evaluate(() => (window as any).sprigEditor.action('bullets'));
  expect(await source(page)).toBe('- First line\n- Second line');
  await page.evaluate(() => { (window as any).sprigEditor.setMode(true); (window as any).sprigEditor.setMode(false); (window as any).sprigEditor.action('undo'); });
  expect(await source(page)).toBe('First line\nSecond line');
  await page.evaluate(() => (window as any).sprigEditor.action('redo'));
  expect(await source(page)).toBe('- First line\n- Second line');
  expect(errors).toEqual([]);
});

test('inactive tables, maths and tasks render in place and remain editable', async ({ page }) => {
  const text = 'Intro\n\n| Topic | Done |\n|---|---|\n| Memory | Yes |\n\n- [ ] Recall\n\n$x^2$\n\nEnd';
  const errors = await start(page, text);
  await expect(page.locator('.cm-editor table')).toHaveCount(1);
  await expect(page.locator('.cm-editor .katex')).toHaveCount(1);
  await page.getByRole('checkbox').check();
  expect(await source(page)).toContain('- [x] Recall');
  await page.locator('.sprig-rendered-block').first().click();
  await expect(page.locator('.cm-editor table')).toHaveCount(0);
  expect(await source(page)).toContain('| Topic | Done |');
  expect(errors).toEqual([]);
});

test('rapid typing and Unicode survive without replacing the selection or leaking HTML', async ({ page }) => {
  const errors = await start(page);
  await page.keyboard.insertText('🧠 café **memory**\n<script>window.unsafe=true</script>');
  expect(await source(page)).toBe('🧠 café **memory**\n<script>window.unsafe=true</script>');
  expect(await page.evaluate(() => Object.hasOwn(window, 'unsafe'))).toBe(false);
  expect(errors).toEqual([]);
});

test('display maths, recall sections and code render without changing their source', async ({ page }) => {
  const text = 'Intro\n\n$$\nx^2 + y^2\n$$\n\n<details><summary>Answer</summary>\n\n**Recall**\n\n</details>\n\n```swift\nlet answer = 42\n```\n\nEnd';
  const errors = await start(page, text);
  await expect(page.locator('.cm-editor .katex-display')).toHaveCount(1);
  await expect(page.locator('.cm-editor details')).toHaveCount(1);
  await expect(page.locator('.cm-editor pre code')).toContainText('let answer = 42');
  await page.locator('.cm-editor summary').click();
  await expect(page.locator('.cm-editor details')).toHaveAttribute('open', '');
  expect(await source(page)).toBe(text);
  expect(errors).toEqual([]);
});

test('live editor uses the interface font and toggles source without losing edits', async ({ page }) => {
  const errors = await start(page, '**Memory**');
  expect(await page.locator('.cm-scroller').evaluate(el => getComputedStyle(el).fontFamily)).toContain('Inter');
  await page.evaluate(() => (window as any).sprigEditor.setMode(true));
  await page.keyboard.press('End');
  await page.keyboard.type(' and recall');
  await page.evaluate(() => (window as any).sprigEditor.setMode(false));
  expect(await source(page)).toBe('**Memory** and recall');
  expect(errors).toEqual([]);
});

test('inactive headings align with body text without changing Markdown source', async ({ page }) => {
  const text = Array.from({ length: 6 }, (_, i) => `${'#'.repeat(i + 1)} Aligned heading`).join('\n\n') + '\n\nAligned body';
  const errors = await start(page, text);
  await page.keyboard.press(`${modifier}+End`);
  await page.evaluate(() => document.fonts.ready);
  const starts = await page.locator('.cm-line').evaluateAll(lines => {
    const start = (line: Element) => {
      const walker = document.createTreeWalker(line, NodeFilter.SHOW_TEXT);
      let node;
      while ((node = walker.nextNode())) {
        const offset = node.textContent?.search(/\S/) ?? -1;
        if (offset < 0) continue;
        const range = document.createRange();
        range.setStart(node, offset); range.setEnd(node, offset + 1);
        return range.getBoundingClientRect().left;
      }
      return null;
    };
    return {
      headings: lines.filter(el => el.classList.contains('sprig-heading')).map(start),
      body: start(lines.find(el => el.textContent === 'Aligned body')!),
    };
  });
  expect(starts.headings).toHaveLength(6);
  for (const left of starts.headings) expect(Math.abs(left! - starts.body!)).toBeLessThan(0.5);
  expect(await source(page)).toBe(text);
  expect(errors).toEqual([]);
});

test('italic shortcut formats the selection instead of selecting the parent line', async ({ page }) => {
  await start(page, 'A line ending here');
  await page.keyboard.press(`${modifier}+End`);
  await page.keyboard.press('Shift+ArrowLeft');
  await page.keyboard.press(`${modifier}+i`);
  expect(await source(page)).toBe('A line ending her*e*');
  await expect(page.locator('.sprig-italic')).toContainText('e');
});

test('bold remains styled when a space is typed before the closing markers', async ({ page }) => {
  await start(page);
  await page.evaluate(() => (window as any).sprigEditor.action('bold'));
  await page.keyboard.type('Bold');
  await page.keyboard.type(' ');
  await expect(page.locator('.sprig-bold')).toContainText('Bold ');
  await page.keyboard.type('word');
  await expect(page.locator('.sprig-bold')).toContainText('Bold word');
  expect(await source(page)).toBe('**Bold word**');
});

test('quotes display a bar and Enter on an empty quote returns to body text', async ({ page }) => {
  await start(page, '> Quoted text');
  await page.keyboard.press(`${modifier}+End`);
  await expect(page.locator('.sprig-quote-line')).toContainText('Quoted text');
  expect(await page.locator('.cm-content').innerText()).not.toContain('>');
  await page.keyboard.press('Enter');
  await page.keyboard.press('Enter');
  await page.keyboard.type('Normal text');
  expect(await source(page)).toBe('> Quoted text\n\nNormal text');
  const content = page.locator('.cm-content');
  const body = page.locator('.cm-line').filter({ hasText: 'Normal text' });
  await expect(body).not.toHaveClass(/sprig-quote-line/);
  expect((await body.boundingBox())!.x).toBe((await content.boundingBox())!.x);
});

test('temporary bold styling does not span intervening plain text or code', async ({ page }) => {
  await start(page, '**First** plain **Next **');
  await page.keyboard.press(`${modifier}+End`);
  const styles = await page.locator('.sprig-bold').allTextContents();
  expect(styles.join('')).not.toContain('plain');
  await page.evaluate(() => (window as any).sprigEditor.setText('`**code **`'));
  await page.keyboard.press(`${modifier}+End`);
  await expect(page.locator('.sprig-bold')).toHaveCount(0);
});

test('title handoff focuses the first body line without selecting or changing its text', async ({ page }) => {
  await start(page, 'Existing body');
  await page.keyboard.press(`${modifier}+End`);
  await page.evaluate(() => (window as any).sprigEditor.action('focus-start'));
  expect(await source(page)).toBe('Existing body');
  await expect(page.getByRole('textbox', { name: 'Note text' })).toBeFocused();
  await page.keyboard.type('First ');
  expect(await source(page)).toBe('First Existing body');
});
