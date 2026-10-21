export const colours = ["butter", "sage", "rose", "lilac", "apricot"] as const;
export type Colour = (typeof colours)[number];
export type Folder = { id: string; name: string; parentId: string | null };
export type Board = {
  id: string;
  title: string;
  folderId: string;
  pinned: boolean;
  colour: Colour;
};
export type Note = {
  id: string;
  boardId: string;
  title: string;
  markdown: string;
  category: string;
  meta: string;
  summary: string;
  colour: Colour;
  x: number;
  y: number;
  updatedAt: number;
  deletedAt?: number;
};
export type Connection = { id: string; from: string; to: string };
export type Workspace = {
  version: 1;
  folders: Folder[];
  boards: Board[];
  notes: Note[];
  connections: Connection[];
};
export const uid = () => crypto.randomUUID();
export function folderPath(folders: Folder[], id: string): Folder[] {
  const path: Folder[] = [],
    seen = new Set<string>();
  let folder = folders.find((f) => f.id === id);
  while (folder && !seen.has(folder.id)) {
    seen.add(folder.id);
    path.unshift(folder);
    folder = folders.find((f) => f.id === folder!.parentId);
  }
  return path;
}
export function validateWorkspace(value: unknown): value is Workspace {
  if (!value || typeof value !== "object") return false;
  const w = value as Workspace;
  if (
    w.version !== 1 ||
    !Array.isArray(w.folders) ||
    !Array.isArray(w.boards) ||
    !Array.isArray(w.notes) ||
    !Array.isArray(w.connections)
  )
    return false;
  if (
    !w.folders.every(
      (f) =>
        f &&
        typeof f.id === "string" &&
        typeof f.name === "string" &&
        (f.parentId === null || typeof f.parentId === "string"),
    )
  )
    return false;
  if (
    !w.boards.every(
      (b) =>
        b &&
        typeof b.id === "string" &&
        typeof b.title === "string" &&
        typeof b.folderId === "string" &&
        typeof b.pinned === "boolean" &&
        colours.includes(b.colour),
    )
  )
    return false;
  if (
    !w.notes.every(
      (n) =>
        n &&
        [
          "id",
          "boardId",
          "title",
          "markdown",
          "category",
          "meta",
          "summary",
        ].every((k) => typeof n[k as keyof Note] === "string") &&
        colours.includes(n.colour) &&
        [n.x, n.y, n.updatedAt].every(Number.isFinite) &&
        (n.deletedAt === undefined || Number.isFinite(n.deletedAt)),
    )
  )
    return false;
  const folderIds = new Set(w.folders.map((f) => f.id)),
    boardIds = new Set(w.boards.map((b) => b.id)),
    noteIds = new Set(w.notes.map((n) => n.id));
  if (
    folderIds.size !== w.folders.length ||
    boardIds.size !== w.boards.length ||
    noteIds.size !== w.notes.length
  )
    return false;
  if (
    !w.folders.every((f) => f.parentId === null || folderIds.has(f.parentId)) ||
    !w.boards.every((b) => folderIds.has(b.folderId)) ||
    !w.notes.every((n) => boardIds.has(n.boardId))
  )
    return false;
  for (const f of w.folders) {
    const seen = new Set([f.id]);
    let parent = f.parentId;
    while (parent) {
      if (seen.has(parent)) return false;
      seen.add(parent);
      parent = w.folders.find((p) => p.id === parent)!.parentId;
    }
  }
  return w.connections.every(
    (c) =>
      c &&
      typeof c.id === "string" &&
      noteIds.has(c.from) &&
      noteIds.has(c.to) &&
      c.from !== c.to &&
      w.notes.find((n) => n.id === c.from)!.boardId ===
        w.notes.find((n) => n.id === c.to)!.boardId,
  );
}
export function createDemo(): Workspace {
  const content = [
    [
      "Types of conformity",
      "Compliance\nIdentification\nInternalisation",
      "01  /  KEY CONCEPT",
      "3 ideas  ·  Markdown",
      "Compliance, identification and internalisation.",
      "butter",
      60,
      12,
    ],
    [
      "Asch (1951)",
      "A unanimous majority can influence an individual’s judgement.\n\nWhy do people go along?",
      "02  /  KEY STUDY",
      "Study  ·  Markdown",
      "How a majority influences our judgement.",
      "sage",
      410,
      40,
    ],
    [
      "Think critically",
      "- Artificial task\n- Cultural context\n- Ethical considerations",
      "03  /  EVALUATION",
      "AO3  ·  Markdown",
      "Consider the strengths and limitations.",
      "rose",
      960,
      2,
    ],
    [
      "Test yourself",
      "What is the difference between compliance and internalisation?\n\nTry answering before looking.\n\n<details>\n<summary>Reveal answer</summary>\n\nCompliance is a public change in behaviour without a private change in belief. Internalisation involves both public and private acceptance.\n\n</details>",
      "04  /  ACTIVE RECALL",
      "Recall prompt  ·  Answer hidden",
      "Compliance or internalisation?",
      "lilac",
      95,
      290,
    ],
    [
      "Why do we conform?",
      "Normative influence: acceptance.\n\nInformational influence: accuracy.",
      "05  /  EXPLANATIONS",
      "Compare  ·  Markdown",
      "Acceptance, or the need to be right?",
      "butter",
      710,
      250,
    ],
    [
      "Build an argument",
      "Outline one explanation of conformity.\n\nLink a study to your explanation, then develop an evaluation point.",
      "06  /  EXAM PRACTICE",
      "Essay plan  ·  Markdown",
      "Turn an explanation into an argument.",
      "sage",
      1035,
      300,
    ],
  ] as const;
  return {
    version: 1,
    folders: [
      { id: "alevels", name: "A-levels", parentId: null },
      { id: "psych", name: "Psychology", parentId: "alevels" },
      { id: "social", name: "Social psychology", parentId: "psych" },
      { id: "law", name: "Law", parentId: "alevels" },
      { id: "environment", name: "Environmental Science", parentId: "alevels" },
    ],
    boards: [
      {
        id: "conformity",
        title: "Conformity",
        folderId: "social",
        pinned: false,
        colour: "butter",
      },
      {
        id: "memory",
        title: "Memory",
        folderId: "psych",
        pinned: true,
        colour: "sage",
      },
      {
        id: "contract",
        title: "Contract law",
        folderId: "law",
        pinned: true,
        colour: "rose",
      },
      {
        id: "carbon",
        title: "Carbon cycle",
        folderId: "environment",
        pinned: true,
        colour: "lilac",
      },
    ],
    notes: content.map(
      ([title, markdown, category, meta, summary, colour, x, y], i) => ({
        id: `note-${i}`,
        boardId: "conformity",
        title,
        markdown,
        category,
        meta,
        summary,
        colour,
        x,
        y,
        updatedAt: Date.now() - [0, 1, 5, 2, 3, 4][i] * 1000,
      }),
    ),
    connections: [],
  };
}
export function boardMarkdown(w: Workspace, boardId: string): string {
  const board = w.boards.find((b) => b.id === boardId)!;
  return (
    `# ${board.title}\n\n${folderPath(w.folders, board.folderId)
      .map((f) => f.name)
      .join(" / ")}\n\n` +
    w.notes
      .filter((n) => n.boardId === boardId && !n.deletedAt)
      .map((n) => `## ${n.title}\n\n${n.markdown}`)
      .join("\n\n---\n\n")
  );
}
