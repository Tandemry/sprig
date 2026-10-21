import { describe, it, expect } from "vitest";
import {
  createDemo,
  validateWorkspace,
  folderPath,
  boardMarkdown,
} from "../src/model";
describe("workspace data integrity", () => {
  it("accepts the demo and resolves its nested folder path", () => {
    const w = createDemo();
    expect(validateWorkspace(w)).toBe(true);
    expect(folderPath(w.folders, "social").map((f) => f.name)).toEqual([
      "A-levels",
      "Psychology",
      "Social psychology",
    ]);
  });
  it("rejects cycles, orphan notes and unsupported backups", () => {
    const cycle = createDemo();
    cycle.folders[0].parentId = "social";
    expect(validateWorkspace(cycle)).toBe(false);
    const orphan = createDemo();
    orphan.notes[0].boardId = "missing";
    expect(validateWorkspace(orphan)).toBe(false);
    expect(validateWorkspace({ version: 2 })).toBe(false);
  });
  it("rejects connections across boards", () => {
    const w = createDemo();
    w.notes[0].boardId = "memory";
    w.connections = [{ id: "c", from: "note-0", to: "note-1" }];
    expect(validateWorkspace(w)).toBe(false);
  });
  it("exports exact Markdown and excludes trashed notes", () => {
    const w = createDemo();
    w.notes[0].markdown = "**Keep source**\n\n$x^2$";
    w.notes[1].deletedAt = 1;
    const md = boardMarkdown(w, "conformity");
    expect(md).toContain("**Keep source**\n\n$x^2$");
    expect(md).not.toContain("## Asch (1951)");
    expect(md).toContain("A-levels / Psychology / Social psychology");
  });
});
