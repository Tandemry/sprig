import { test, expect, _electron as electron } from "@playwright/test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("packaged macOS app loads from local files and retains notes after quitting", async () => {
  test.setTimeout(45000);
  const profile = await mkdtemp(join(tmpdir(), "sprig-desktop-test-"));
  const executablePath = join(
    process.cwd(),
    `releases/Sprig-darwin-${process.arch}/Sprig.app/Contents/MacOS/Sprig`,
  );
  const launch = () =>
    electron.launch({
      executablePath,
      env: { ...process.env, SPRIG_USER_DATA: profile },
    });
  let app = await launch();
  try {
    const page = await app.firstWindow();
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await expect(
      page.getByRole("heading", { name: "Home", exact: true }),
    ).toBeVisible();
    expect(page.url()).toMatch(/^file:\/\/.*index.html\?native=1$/);
    await page.getByRole("button", { name: "Open board" }).click();
    await page.getByLabel("New sage note", { exact: true }).click();
    await page.getByLabel("Note title").fill("Desktop persistence check");
    await page
      .getByRole("button", { name: "Markdown source", exact: true })
      .click();
    await page
      .getByLabel("Markdown source", { exact: true })
      .fill("## Local study note\n\n**Saved without a server.**");
    await page
      .getByRole("button", { name: "Live preview", exact: true })
      .click();
    await expect(page.locator(".editor-preview strong")).toHaveText(
      "Saved without a server.",
    );
    await page.getByLabel("Return to board").click();
    await page.evaluate(() => document.fonts.ready);
    expect(
      await page
        .locator("img")
        .evaluateAll((imgs) =>
          imgs.every((i) => (i as HTMLImageElement).naturalWidth > 0),
        ),
    ).toBe(true);
    expect(errors).toEqual([]);
    await app.close();
    app = await launch();
    const reopened = await app.firstWindow();
    await expect(
      reopened.getByRole("button", {
        name: "Desktop persistence check",
        exact: true,
      }),
    ).toBeVisible();
    await reopened
      .getByRole("button", { name: "Desktop persistence check", exact: true })
      .click();
    await expect(reopened.locator(".editor-preview strong")).toHaveText(
      "Saved without a server.",
    );
    await reopened.screenshot({ path: "test-results/desktop.png" });
  } finally {
    await app.close();
    await rm(profile, { recursive: true, force: true });
  }
});
