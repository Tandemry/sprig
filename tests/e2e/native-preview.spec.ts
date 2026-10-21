import { test, expect } from "@playwright/test";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
test("native bundled renderer works from disk without Node or a server", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto(
    pathToFileURL(
      resolve("native/Sources/SprigApp/Resources/Markdown/index.html"),
    ).href,
  );
  await page.evaluate(() => {
    (
      window as unknown as {
        sprigRender: (text: string, colour: string) => void;
      }
    ).sprigRender(
      "## Native preview\n\n**Retained source**\n\n| Topic | Done |\n|---|---|\n| Memory | Yes |\n\n$x^2$\n\n<script>window.unsafe=true</script>",
      "#fbf0bf",
    );
  });
  await expect(page.locator("strong")).toHaveText("Retained source");
  await expect(page.locator("table")).toHaveCount(1);
  await expect(page.locator(".katex")).toHaveCount(1);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => Object.hasOwn(window, "unsafe"))).toBe(
    false,
  );
});
