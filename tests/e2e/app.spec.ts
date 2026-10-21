import { test, expect } from "@playwright/test";
import { createDemo } from "../../src/model";
const key = "tandemry.sprig.workspace.v1";
test("Home and board match the concept layout and load every local asset", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/");
  await page.evaluate(() => document.fonts.ready);
  await expect(
    page.getByRole("heading", { name: "Home", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".recent-note")).toHaveCount(5);
  await page.screenshot({ path: "test-results/home.png", fullPage: true });
  await page.getByRole("button", { name: "Open board" }).click();
  await expect(page.locator(".board-world .sticky")).toHaveCount(6);
  await page.screenshot({ path: "test-results/board.png" });
  expect(
    await page
      .locator("img")
      .evaluateAll((images) =>
        images.every(
          (img) =>
            (img as HTMLImageElement).complete &&
            (img as HTMLImageElement).naturalWidth > 0,
        ),
      ),
  ).toBe(true);
  expect(errors).toEqual([]);
});
test("Markdown edits persist, render maths and remain safe", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("button", { name: "Types of conformity", exact: true })
    .click();
  await page.getByLabel("Note title").fill("My revision note");
  await page
    .getByRole("button", { name: "Markdown source", exact: true })
    .click();
  await page
    .getByLabel("Markdown source", { exact: true })
    .fill(
      "## Definition\n\n**Public acceptance**\n\n- [x] Revised\n\n$x^2$\n\n<script>window.unsafe=true</script>",
    );
  await page.getByRole("button", { name: "Live preview", exact: true }).click();
  await expect(page.locator(".editor-preview strong")).toHaveText(
    "Public acceptance",
  );
  await expect(page.locator(".editor-preview .katex")).toHaveCount(1);
  expect(await page.evaluate(() => Object.hasOwn(window, "unsafe"))).toBe(
    false,
  );
  await page.screenshot({ path: "test-results/editor.png" });
  await page.getByLabel("Return to board").click();
  await page.reload();
  await page
    .getByRole("button", { name: "My revision note", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Markdown source", exact: true })
    .click();
  await expect(page.getByLabel("Markdown source", { exact: true })).toHaveValue(
    /Public acceptance/,
  );
});
test("creates, drags, connects, trashes, restores and undoes notes", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Open board" }).click();
  await page.getByLabel("New sage note", { exact: true }).click();
  await page.getByLabel("Note title").fill("A fresh thought");
  await page.getByLabel("Return to board").click();
  await expect(page.locator(".board-world .sticky")).toHaveCount(7);
  const note = page.locator('[data-note-id="note-0"]');
  const box = (await note.boundingBox())!;
  await page.mouse.move(box.x + 20, box.y + 10);
  await page.mouse.down();
  await page.mouse.move(box.x + 80, box.y + 60, { steps: 10 });
  await page.mouse.up();
  await expect
    .poll(() => note.evaluate((n) => parseFloat((n as HTMLElement).style.left)))
    .toBe(120);
  await page.getByRole("button", { name: "Undo", exact: true }).click();
  await expect
    .poll(() => note.evaluate((n) => parseFloat((n as HTMLElement).style.left)))
    .toBe(60);
  await page.getByRole("button", { name: "Connect", exact: true }).click();
  await page
    .getByRole("button", { name: "Types of conformity", exact: true })
    .click();
  await page.getByRole("button", { name: "Asch (1951)", exact: true }).click();
  await expect(page.locator(".connection-hit")).toHaveCount(1);
  await page.getByRole("button", { name: "Select", exact: true }).click();
  await page
    .getByRole("button", { name: "A fresh thought", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Move to trash", exact: true })
    .click();
  await expect(page.locator(".board-world .sticky")).toHaveCount(6);
  await page.getByRole("button", { name: "Library", exact: true }).click();
  await page.getByRole("button", { name: /^Trash/ }).click();
  await page.getByRole("button", { name: "Restore note" }).click();
  await expect(page.getByText("Your trash is empty.")).toBeVisible();
});
test("nested folders, boards and search work", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Library", exact: true }).click();
  await page.getByRole("button", { name: "+ New folder", exact: true }).click();
  await page.getByLabel("Name", { exact: true }).fill("Exam plans");
  await page.getByRole("button", { name: "Create", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Exam plans", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "+ New board", exact: true }).click();
  await page.getByLabel("Name", { exact: true }).fill("Essay ideas");
  await page.getByRole("button", { name: "Create", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Essay ideas", exact: true }),
  ).toBeVisible();
  await page.getByLabel("New butter note", { exact: true }).click();
  await page.getByLabel("Note title").fill("Distinctive revision thought");
  await page.getByLabel("Return to board").click();
  await page.getByRole("button", { name: "Search", exact: true }).click();
  await page.getByLabel("Search notes").fill("Distinctive");
  await expect(page.locator(".recent-note")).toHaveCount(1);
});
test("backup import is additive and corrupt storage is preserved", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Library", exact: true }).click();
  await page
    .locator("input[type=file]")
    .setInputFiles({
      name: "backup.json",
      mimeType: "application/json",
      buffer: Buffer.from(JSON.stringify(createDemo())),
    });
  await expect(page.getByRole("status")).toContainText("Backup imported");
  expect(
    await page.evaluate(
      (k) => JSON.parse(localStorage.getItem(k)!).notes.length,
      key,
    ),
  ).toBe(12);
  await page.evaluate(
    (k) => localStorage.setItem(k, "corrupted saved data"),
    key,
  );
  await page.reload();
  await expect(page.getByRole("alert")).toContainText("could not be read");
  expect(await page.evaluate((k) => localStorage.getItem(k), key)).toBe(
    "corrupted saved data",
  );
});
test("mobile layout is usable without page overflow", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(
    390,
  );
  await page.screenshot({
    path: "test-results/mobile-home.png",
    fullPage: true,
  });
  await page.getByRole("button", { name: "Open board" }).click();
  await page.getByLabel("New lilac note", { exact: true }).click();
  await expect(page.getByLabel("Note title")).toBeVisible();
  await page.getByLabel("Note title").fill("Mobile note");
  await page.getByLabel("Return to board").click();
});
