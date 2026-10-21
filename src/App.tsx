import {
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type PointerEvent as ReactPointerEvent,
  type ReactNode,
} from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkMath from "remark-math";
import rehypeKatex from "rehype-katex";
import {
  boardMarkdown,
  colours,
  folderPath,
  uid,
  validateWorkspace,
  type Board,
  type Colour,
  type Note,
  type Workspace,
} from "./model";
import { STORAGE_KEY, useWorkspace } from "./useWorkspace";

type View = "Home" | "Boards" | "Library" | "Search";
type Tool = "Select" | "Pan" | "Connect";
const navIcons = ["Home", "Boards", "Library", "Search"];
function Icon({
  name,
  group = "detail0",
  size = 20,
}: {
  name: string;
  group?: string;
  size?: number;
}) {
  return (
    <img
      className="icon"
      src={`assets/${group}-imgIcon${name}.svg`}
      width={size}
      height={size}
      alt=""
      draggable={false}
    />
  );
}
function download(name: string, body: string, type = "text/markdown") {
  const a = document.createElement("a"),
    url = URL.createObjectURL(new Blob([body], { type }));
  a.href = url;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function filename(title: string) {
  return title.replace(/[/\\:*?"<>|]/g, "-") || "Untitled";
}
function Markdown({ text }: { text: string }) {
  const reveal = text.match(
    /<details>\s*<summary>(.*?)<\/summary>([\s\S]*?)<\/details>/,
  );
  if (reveal)
    return (
      <>
        <Markdown text={text.slice(0, reveal.index)} />
        <details>
          <summary>{reveal[1]}</summary>
          <Markdown text={reveal[2]} />
        </details>
        <Markdown text={text.slice(reveal.index! + reveal[0].length)} />
      </>
    );
  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm, remarkMath]}
      rehypePlugins={[rehypeKatex]}
      components={{
        a: ({ children, ...props }) => (
          <a {...props} target="_blank" rel="noopener noreferrer">
            {children}
          </a>
        ),
      }}
    >
      {text}
    </ReactMarkdown>
  );
}
function Dialog({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    ref.current?.showModal();
  }, []);
  return (
    <dialog
      ref={ref}
      onCancel={onClose}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
      className="form-dialog"
    >
      <header>
        <h2>{title}</h2>
        <button aria-label="Close dialog" onClick={onClose}>
          ×
        </button>
      </header>
      {children}
    </dialog>
  );
}
function NoteCard({
  note,
  compact = false,
  board,
  subject,
  onOpen,
  ...props
}: {
  note: Note;
  compact?: boolean;
  board?: string;
  subject?: string;
  onOpen: () => void;
  style?: CSSProperties;
  onPointerDown?: (e: ReactPointerEvent) => void;
  selected?: boolean;
}) {
  return (
    <article
      className={`sticky ${compact ? "recent-note" : ""} ${note.colour} ${props.selected ? "selected" : ""}`}
      style={props.style}
      data-note-id={note.id}
      onPointerDown={props.onPointerDown}
      onDoubleClick={onOpen}
    >
      <span className="caption">
        {compact ? board?.toUpperCase() : note.category}
      </span>
      <button className="note-title" onClick={onOpen}>
        {note.title || "Untitled note"}
      </button>
      <div className="note-body markdown">
        {compact ? (
          note.summary || note.markdown.slice(0, 100)
        ) : (
          <Markdown text={note.markdown.split("<details>")[0]} />
        )}
      </div>
      <span className="caption note-meta">{compact ? subject : note.meta}</span>
    </article>
  );
}
function Miniature({ notes }: { notes: Note[] }) {
  return (
    <div className="miniature" aria-hidden="true">
      {notes.slice(0, 6).map((n, i) => (
        <div
          key={n.id}
          className={`mini-note ${n.colour}`}
          style={{
            left: `${[4.5, 32.3, 71.4, 7.5, 51.1, 74.8][i]}%`,
            top: `${[7.4, 13.1, 4.9, 57.4, 53.3, 59.4][i]}%`,
          }}
        >
          <span>{n.title}</span>
          <i />
          <i />
          <i />
        </div>
      ))}
    </div>
  );
}
function NoteEditor({
  note,
  update,
  close,
  saved,
  error,
  onDelete,
  onDuplicate,
}: {
  note: Note;
  update: (patch: Partial<Note>) => void;
  close: () => void;
  saved: boolean;
  error: string;
  onDelete: () => void;
  onDuplicate: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    source = useRef<HTMLTextAreaElement>(null);
  const [mode, setMode] = useState<"Preview" | "Source">("Preview");
  useEffect(() => {
    dialog.current?.showModal();
  }, []);
  function format(prefix: string, suffix = "") {
    const start = source.current?.selectionStart ?? note.markdown.length,
      end = source.current?.selectionEnd ?? start;
    const selected = note.markdown.slice(start, end) || "text";
    update({
      markdown:
        note.markdown.slice(0, start) +
        prefix +
        selected +
        suffix +
        note.markdown.slice(end),
    });
    setMode("Source");
    requestAnimationFrame(() => {
      source.current?.focus();
      source.current?.setSelectionRange(
        start + prefix.length,
        start + prefix.length + selected.length,
      );
    });
  }
  return (
    <dialog
      ref={dialog}
      className="editor-dialog"
      onCancel={close}
      onClick={(e) => {
        if (e.target === e.currentTarget) close();
      }}
      aria-label="Edit note"
    >
      <div className={`editor-paper ${note.colour}`}>
        <div className="editor-header">
          <span className="caption">{note.category || "NEW NOTE"}</span>
          <button onClick={close} aria-label="Return to board">
            ×
          </button>
        </div>
        <input
          className="editor-title"
          aria-label="Note title"
          value={note.title}
          onChange={(e) => update({ title: e.target.value })}
          placeholder="Untitled note"
        />
        <div className="editor-content markdown">
          {mode === "Source" ? (
            <textarea
              ref={source}
              autoFocus
              aria-label="Markdown source"
              spellCheck
              value={note.markdown}
              onChange={(e) =>
                update({ markdown: e.target.value, summary: "" })
              }
              placeholder="Write something. Markdown is welcome."
            />
          ) : (
            <div
              className="editor-preview"
              onDoubleClick={() => setMode("Source")}
            >
              <Markdown text={note.markdown} />
              {!note.markdown && (
                <button
                  className="empty-write"
                  onClick={() => setMode("Source")}
                >
                  Write something. Markdown is welcome.
                </button>
              )}
            </div>
          )}
        </div>
        <div className="editor-status">
          <div className="mode-switch" aria-label="Editor mode">
            {(["Preview", "Source"] as const).map((m) => (
              <button
                key={m}
                className={mode === m ? "active" : ""}
                onClick={() => setMode(m)}
              >
                {m === "Preview" ? "Live preview" : "Markdown source"}
              </button>
            ))}
          </div>
          <span>
            {error ? "Not saved" : saved ? "Saved locally" : "Saving…"}
          </span>
        </div>
        <footer className="editor-footer">
          <div className="swatches">
            {colours.map((c) => (
              <button
                key={c}
                aria-label={`Change note to ${c}`}
                aria-pressed={note.colour === c}
                className={c}
                onClick={() => update({ colour: c })}
              />
            ))}
          </div>
          <button
            onClick={() =>
              download(
                `${filename(note.title)}.md`,
                `# ${note.title}\n\n${note.markdown}`,
              )
            }
          >
            Export
          </button>
          <button onClick={onDuplicate}>Duplicate</button>
          <button onClick={onDelete}>Move to trash</button>
        </footer>
      </div>
      <div
        className="formatting glass"
        role="toolbar"
        aria-label="Markdown formatting"
      >
        {[
          { label: "Bold", text: <b>B</b>, prefix: "**", suffix: "**" },
          { label: "Italic", text: <i>I</i>, prefix: "*", suffix: "*" },
          { label: "Heading", text: <b>H</b>, prefix: "## " },
          { label: "Bullets", icon: "Bullets", prefix: "\n- " },
          { label: "Numbered list", icon: "Numbered", prefix: "\n1. " },
          { label: "Checklist", icon: "Checklist", prefix: "\n- [ ] " },
          {
            label: "Link",
            icon: "Link",
            prefix: "[",
            suffix: "](https://example.com)",
          },
          { label: "Quote", icon: "Quote", prefix: "\n> " },
          { label: "Code", icon: "Code", prefix: "`", suffix: "`" },
        ].map((t) => (
          <button
            key={t.label}
            aria-label={t.label}
            title={t.label}
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => format(t.prefix, t.suffix)}
          >
            {t.icon ? <Icon name={t.icon} group="detail2" size={19} /> : t.text}
          </button>
        ))}
      </div>
    </dialog>
  );
}
export default function App() {
  const {
    workspace: w,
    commit,
    undo,
    redo,
    canUndo,
    canRedo,
    error,
  } = useWorkspace();
  const [view, setView] = useState<View>("Home"),
    [boardId, setBoardId] = useState("conformity"),
    [editorId, setEditorId] = useState<string | null>(null),
    [selected, setSelected] = useState<string | null>(null);
  const [menu, setMenu] = useState(false),
    [list, setList] = useState(false),
    [tool, setTool] = useState<Tool>("Select"),
    [zoom, setZoom] = useState(1),
    [pan, setPan] = useState({ x: 0, y: 0 }),
    [query, setQuery] = useState(""),
    [folder, setFolder] = useState<string | null>(null),
    [trash, setTrash] = useState(false);
  const [form, setForm] = useState<"board" | "folder" | "rename" | null>(null),
    [formName, setFormName] = useState(""),
    [formParent, setFormParent] = useState("social"),
    [message, setMessage] = useState("");
  const [size, setSize] = useState({ width: 1470, height: 617 });
  const canvas = useRef<HTMLDivElement>(null),
    importInput = useRef<HTMLInputElement>(null),
    dragged = useRef(false),
    editSession = useRef(0);
  const board = w.boards.find((b) => b.id === boardId) ?? w.boards[0],
    notes = w.notes.filter((n) => n.boardId === board?.id && !n.deletedAt),
    editor = w.notes.find((n) => n.id === editorId && !n.deletedAt);
  const boardPath = board ? folderPath(w.folders, board.folderId) : [];
  const subject = (b: Board) => {
    const p = folderPath(w.folders, b.folderId);
    return p[1]?.name ?? p[0]?.name ?? "";
  };
  const activeNotes = w.notes.filter((n) => !n.deletedAt),
    recent = [...activeNotes]
      .sort((a, b) => b.updatedAt - a.updatedAt)
      .slice(0, 5);
  const scale = Math.min(1, size.width / 1470) * zoom;
  useEffect(() => {
    if (!canvas.current) return;
    const ob = new ResizeObserver(([e]) =>
      setSize({ width: e.contentRect.width, height: e.contentRect.height }),
    );
    ob.observe(canvas.current);
    return () => ob.disconnect();
  }, [view, list]);
  useEffect(() => {
    if (!message) return;
    const t = setTimeout(() => setMessage(""), 4500);
    return () => clearTimeout(t);
  }, [message]);
  const openBoard = (id: string) => {
    setBoardId(id);
    setView("Boards");
    setPan({ x: 0, y: 0 });
    setZoom(1);
    setSelected(null);
    setMenu(false);
    setTrash(false);
  };
  const openNote = (id: string) => {
    if (dragged.current) {
      dragged.current = false;
      return;
    }
    editSession.current++;
    setEditorId(id);
    setSelected(id);
  };
  function patchNote(id: string, patch: Partial<Note>, group = "") {
    commit(
      (s) => ({
        ...s,
        notes: s.notes.map((n) =>
          n.id === id ? { ...n, ...patch, updatedAt: Date.now() } : n,
        ),
      }),
      group,
    );
  }
  function addNote(
    colour: Colour,
    x = 250 + notes.length * 16,
    y = 70 + notes.length * 12,
    edit = true,
  ) {
    if (!board) return;
    const id = uid();
    commit((s) => ({
      ...s,
      notes: [
        ...s.notes,
        {
          id,
          boardId: board.id,
          title: "Untitled note",
          markdown: "",
          category: "NOTE",
          meta: "Markdown  ·  Updated just now",
          summary: "",
          colour,
          x: Math.max(0, x),
          y: Math.max(0, y),
          updatedAt: Date.now(),
        },
      ],
    }));
    setSelected(id);
    if (edit) openNote(id);
  }
  function duplicate(n: Note) {
    const id = uid();
    commit((s) => ({
      ...s,
      notes: [
        ...s.notes,
        {
          ...n,
          id,
          title: `${n.title} copy`,
          x: n.x + 35,
          y: n.y + 35,
          updatedAt: Date.now(),
        },
      ],
    }));
    setEditorId(null);
    setSelected(id);
    setMessage("Note duplicated.");
  }
  function deleteNote(id: string) {
    patchNote(id, { deletedAt: Date.now() });
    setEditorId(null);
    setSelected(null);
    setMessage("Note moved to trash. You can restore it from Library.");
  }
  function selectNote(n: Note) {
    if (tool === "Connect") {
      if (selected && selected !== n.id) {
        const existing = w.connections.some(
          (c) =>
            (c.from === selected && c.to === n.id) ||
            (c.to === selected && c.from === n.id),
        );
        if (!existing)
          commit((s) => ({
            ...s,
            connections: [
              ...s.connections,
              { id: uid(), from: selected, to: n.id },
            ],
          }));
        setSelected(null);
        setMessage("Notes connected.");
      } else setSelected(n.id);
    } else setSelected(n.id);
  }
  function startDrag(e: ReactPointerEvent, n?: Note) {
    if (
      e.button !== 0 ||
      (e.target as HTMLElement).closest("button,a,summary,input")
    )
      return;
    if (n && tool === "Connect") {
      selectNote(n);
      return;
    }
    if (n) setSelected(n.id);
    else if (tool !== "Pan") {
      setSelected(null);
      return;
    }
    if (n && tool === "Pan") n = undefined;
    const el = e.currentTarget as HTMLElement;
    el.setPointerCapture(e.pointerId);
    const sx = e.clientX,
      sy = e.clientY,
      origin = n ? { x: n.x, y: n.y } : pan;
    let dx = 0,
      dy = 0;
    dragged.current = false;
    const move = (event: PointerEvent) => {
      dx = event.clientX - sx;
      dy = event.clientY - sy;
      if (Math.abs(dx) + Math.abs(dy) > 4) dragged.current = true;
      if (n) {
        el.style.left = `${Math.max(0, origin.x + dx / scale)}px`;
        el.style.top = `${Math.max(0, origin.y + dy / scale)}px`;
      } else setPan({ x: origin.x + dx, y: origin.y + dy });
    };
    const end = () => {
      el.removeEventListener("pointermove", move);
      el.removeEventListener("pointerup", end);
      el.removeEventListener("pointercancel", end);
      if (n && dragged.current)
        patchNote(n.id, {
          x: Math.max(0, origin.x + dx / scale),
          y: Math.max(0, origin.y + dy / scale),
        });
      setTimeout(() => {
        dragged.current = false;
      }, 0);
    };
    el.addEventListener("pointermove", move);
    el.addEventListener("pointerup", end);
    el.addEventListener("pointercancel", end);
  }
  function fit() {
    if (!notes.length) {
      setZoom(1);
      setPan({ x: 0, y: 0 });
      return;
    }
    const minX = Math.min(...notes.map((n) => n.x)),
      minY = Math.min(...notes.map((n) => n.y)),
      maxX = Math.max(...notes.map((n) => n.x + 256)),
      maxY = Math.max(...notes.map((n) => n.y + 256));
    const desired = Math.min(
      (size.width - 190) / (maxX - minX + 40),
      (size.height - 85) / (maxY - minY + 40),
      1.5,
    );
    setZoom(desired / Math.min(1, size.width / 1470));
    setPan({ x: 20 - minX * desired, y: 15 - minY * desired });
  }
  function showForm(kind: typeof form) {
    setForm(kind);
    setFormName(kind === "rename" ? (board?.title ?? "") : "");
    setFormParent(folder ?? board?.folderId ?? w.folders[0]?.id ?? "");
    setMenu(false);
  }
  function submitForm(e: React.FormEvent) {
    e.preventDefault();
    const name = formName.trim();
    if (!name) return;
    const id = uid();
    if (form === "folder") {
      commit((s) => ({
        ...s,
        folders: [...s.folders, { id, name, parentId: formParent || null }],
      }));
      setFolder(id);
      setView("Library");
    } else if (form === "board") {
      commit((s) => ({
        ...s,
        boards: [
          ...s.boards,
          {
            id,
            title: name,
            folderId: formParent,
            pinned: false,
            colour: "butter",
          },
        ],
      }));
      openBoard(id);
    } else
      commit((s) => ({
        ...s,
        boards: s.boards.map((b) =>
          b.id === board?.id ? { ...b, title: name } : b,
        ),
      }));
    setForm(null);
  }
  async function importBackup(file?: File) {
    if (!file) return;
    try {
      const data: unknown = JSON.parse(await file.text());
      if (!validateWorkspace(data)) throw new Error();
      const folders = new Map(data.folders.map((f) => [f.id, uid()])),
        boards = new Map(data.boards.map((b) => [b.id, uid()])),
        notes = new Map(data.notes.map((n) => [n.id, uid()]));
      commit((s) => ({
        ...s,
        folders: [
          ...s.folders,
          ...data.folders.map((f) => ({
            ...f,
            id: folders.get(f.id)!,
            parentId: f.parentId ? folders.get(f.parentId)! : null,
          })),
        ],
        boards: [
          ...s.boards,
          ...data.boards.map((b) => ({
            ...b,
            id: boards.get(b.id)!,
            folderId: folders.get(b.folderId)!,
          })),
        ],
        notes: [
          ...s.notes,
          ...data.notes.map((n) => ({
            ...n,
            id: notes.get(n.id)!,
            boardId: boards.get(n.boardId)!,
          })),
        ],
        connections: [
          ...s.connections,
          ...data.connections.map((c) => ({
            ...c,
            id: uid(),
            from: notes.get(c.from)!,
            to: notes.get(c.to)!,
          })),
        ],
      }));
      setMessage(
        "Backup imported into new folders. Your existing notes are kept.",
      );
    } catch {
      setMessage(
        "This file is not a valid Sprig backup. Your notes have not changed.",
      );
    } finally {
      if (importInput.current) importInput.current.value = "";
    }
  }
  useEffect(() => {
    const handle = (e: KeyboardEvent) => {
      const typing = (e.target as HTMLElement).closest(
        "input,textarea,[contenteditable]",
      );
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setView("Search");
        setEditorId(null);
      }
      if (!typing && !editor && !form) {
        if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "z") {
          e.preventDefault();
          e.shiftKey ? redo() : undo();
        }
        if (e.key === "Escape") {
          setSelected(null);
          setMenu(false);
        }
        if (
          e.key.toLowerCase() === "n" &&
          view === "Boards" &&
          !e.metaKey &&
          !e.ctrlKey
        ) {
          e.preventDefault();
          addNote("butter");
        }
      }
    };
    window.addEventListener("keydown", handle);
    return () => window.removeEventListener("keydown", handle);
  });
  const folderTree = (parentId: string | null, depth = 0): ReactNode =>
    w.folders
      .filter((f) => f.parentId === parentId)
      .map((f) => (
        <div key={f.id}>
          <button
            className={`folder-row ${folder === f.id ? "active" : ""}`}
            style={{ paddingLeft: 16 + depth * 15 }}
            onClick={() => {
              setFolder(f.id);
              setTrash(false);
            }}
          >
            ▱ <span>{f.name}</span>
          </button>
          {folderTree(f.id, depth + 1)}
        </div>
      ));
  const selectedNote = notes.find((n) => n.id === selected);
  const libraryBoards = w.boards.filter(
    (b) => !folder || b.folderId === folder,
  );
  const searchResults = activeNotes.filter((n) =>
    (
      n.title +
      " " +
      n.markdown +
      " " +
      w.boards.find((b) => b.id === n.boardId)?.title
    )
      .toLowerCase()
      .includes(query.toLowerCase()),
  );
  return (
    <div
      className={`app-shell ${new URLSearchParams(location.search).has("native") ? "native" : ""}`}
    >
      <div className="native-titlebar" aria-hidden="true" />
      <nav className="top-nav glass" aria-label="Main navigation">
        {navIcons.map((label, i) => (
          <button
            key={label}
            className={view === label ? "active" : ""}
            aria-current={view === label ? "page" : undefined}
            onClick={() => {
              setView(label as View);
              setMenu(false);
              setSelected(null);
            }}
          >
            <Icon
              name={label}
              group={view === "Home" ? "detail0" : "component2"}
            />
            <span>{label}</span>
            {i === 3 && <kbd>⌘K</kbd>}
          </button>
        ))}
      </nav>
      <header className="page-header">
        {view === "Boards" && board ? (
          <>
            <div className="breadcrumb">
              {boardPath.map((f, i) => (
                <span key={f.id}>
                  <button
                    onClick={() => {
                      setFolder(f.id);
                      setView("Library");
                    }}
                  >
                    {f.name}
                  </button>
                  {i < boardPath.length - 1 && <span>/</span>}
                </span>
              ))}
            </div>
            <div className="title-row">
              <h1>{board.title}</h1>
              <button
                className="board-menu glass"
                aria-label="Board options"
                aria-expanded={menu}
                onClick={() => setMenu(!menu)}
              >
                ···
              </button>
            </div>
            <p className="caption">
              {notes.length} notes · {error ? "Not saved" : "Saved locally"}
            </p>
          </>
        ) : (
          <>
            <span className="caption">Sprig</span>
            <h1>{view}</h1>
          </>
        )}
      </header>
      {view === "Home" && (
        <button className="new-board glass" onClick={() => showForm("board")}>
          + &nbsp; New board
        </button>
      )}
      {error && (
        <div className="save-error" role="alert">
          {error}
          <button
            onClick={() =>
              download(
                "sprig-recovery.json",
                localStorage.getItem(STORAGE_KEY) ?? JSON.stringify(w),
                "application/json",
              )
            }
          >
            Export recovery data
          </button>
        </div>
      )}
      {view === "Home" && (
        <main className="home-content">
          <div className="home-headings">
            <h2>Pick up where you left off</h2>
            <h2>Pinned boards</h2>
          </div>
          <div className="home-overview">
            <section className="continue-card">
              <div className="continue-details">
                <span className="caption">
                  {board ? subject(board).toUpperCase() : ""}
                </span>
                <h2>{board?.title ?? "Your first board"}</h2>
                <p>{boardPath.at(-1)?.name}</p>
                <button
                  className="glass open-board"
                  onClick={() =>
                    board ? openBoard(board.id) : showForm("board")
                  }
                >
                  Open board &nbsp; ↗
                </button>
                <span className="caption">
                  {notes.length} notes · Saved locally
                </span>
              </div>
              <Miniature notes={notes} />
            </section>
            <section className="pinned-boards" aria-label="Pinned boards">
              {w.boards
                .filter((b) => b.pinned)
                .slice(0, 3)
                .map((b) => (
                  <button
                    className="pinned-board"
                    key={b.id}
                    onClick={() => openBoard(b.id)}
                  >
                    <span className={`board-thumb ${b.colour}`}>
                      <Icon name="Board" group="component0" size={22} />
                    </span>
                    <span>
                      <strong>{b.title}</strong>
                      <small>
                        {subject(b)} ·{" "}
                        {activeNotes.filter((n) => n.boardId === b.id).length}{" "}
                        notes
                      </small>
                    </span>
                    <span className="pinned-arrow">↗</span>
                  </button>
                ))}
              {!w.boards.some((b) => b.pinned) && (
                <p className="empty">
                  Pin a board from its options to keep it close.
                </p>
              )}
            </section>
          </div>
          <div className="recent-heading">
            <h2>Recent notes</h2>
            <button
              onClick={() => {
                setView("Library");
                setFolder(null);
              }}
            >
              All notes ↗
            </button>
          </div>
          <section className="recent-notes" aria-label="Recent notes">
            {recent.map((n) => {
              const b = w.boards.find((b) => b.id === n.boardId)!;
              return (
                <NoteCard
                  key={n.id}
                  note={n}
                  compact
                  board={b.title}
                  subject={subject(b)}
                  onOpen={() => openNote(n.id)}
                />
              );
            })}
          </section>
        </main>
      )}
      {view === "Boards" && board && (
        <>
          {menu && (
            <div className="board-popover glass">
              <button onClick={() => showForm("rename")}>Rename board</button>
              <button
                onClick={() => {
                  commit((s) => ({
                    ...s,
                    boards: s.boards.map((b) =>
                      b.id === board.id ? { ...b, pinned: !b.pinned } : b,
                    ),
                  }));
                  setMenu(false);
                }}
              >
                {board.pinned ? "Unpin board" : "Pin board"}
              </button>
              <button
                onClick={() => {
                  download(
                    `${filename(board.title)}.md`,
                    boardMarkdown(w, board.id),
                  );
                  setMenu(false);
                }}
              >
                Export board as Markdown
              </button>
              <button
                onClick={() => {
                  setView("Library");
                  setFolder(null);
                  setMenu(false);
                }}
              >
                Switch board
              </button>
            </div>
          )}
          {list ? (
            <main className="board-list">
              <div className="list-heading">
                <h2>{notes.length} notes</h2>
                <button className="glass" onClick={() => addNote("butter")}>
                  + New note
                </button>
              </div>
              {notes.map((n) => (
                <button
                  key={n.id}
                  className="list-note"
                  onClick={() => openNote(n.id)}
                >
                  <span className={`list-dot ${n.colour}`} />
                  <strong>{n.title}</strong>
                  <span>{n.category}</span>
                  <small>{n.meta}</small>
                  <span>↗</span>
                </button>
              ))}
              {!notes.length && (
                <p className="empty">
                  A little structure. Space to think. Create your first note.
                </p>
              )}
            </main>
          ) : (
            <div
              ref={canvas}
              className={`board-canvas tool-${tool.toLowerCase()}`}
              onPointerDown={(e) => startDrag(e)}
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => {
                e.preventDefault();
                const c = e.dataTransfer.getData("sprig/colour") as Colour;
                if (!colours.includes(c)) return;
                const r = e.currentTarget.getBoundingClientRect();
                addNote(
                  c,
                  (e.clientX - r.left - pan.x) / scale - 128,
                  (e.clientY - r.top - pan.y) / scale - 50,
                );
              }}
            >
              <div
                className="board-world"
                style={{
                  transform: `translate(${pan.x}px, ${pan.y}px) scale(${scale})`,
                }}
              >
                <svg
                  className="connections"
                  width="10000"
                  height="10000"
                  aria-label="Note connections"
                >
                  {w.connections.map((c) => {
                    const a = notes.find((n) => n.id === c.from),
                      b = notes.find((n) => n.id === c.to);
                    if (!a || !b) return null;
                    return (
                      <g key={c.id}>
                        <line
                          x1={a.x + 128}
                          y1={a.y + 128}
                          x2={b.x + 128}
                          y2={b.y + 128}
                        />
                        <line
                          className="connection-hit"
                          x1={a.x + 128}
                          y1={a.y + 128}
                          x2={b.x + 128}
                          y2={b.y + 128}
                          role="button"
                          tabIndex={0}
                          aria-label={`Remove connection from ${a.title} to ${b.title}`}
                          onClick={() =>
                            commit((s) => ({
                              ...s,
                              connections: s.connections.filter(
                                (l) => l.id !== c.id,
                              ),
                            }))
                          }
                          onKeyDown={(e) => {
                            if (e.key === "Enter" || e.key === " ")
                              commit((s) => ({
                                ...s,
                                connections: s.connections.filter(
                                  (l) => l.id !== c.id,
                                ),
                              }));
                          }}
                        />
                      </g>
                    );
                  })}
                </svg>
                {notes.map((n) => (
                  <NoteCard
                    key={n.id}
                    note={n}
                    selected={selected === n.id}
                    style={{ left: n.x, top: n.y }}
                    onPointerDown={(e) => {
                      e.stopPropagation();
                      startDrag(e, n);
                    }}
                    onOpen={() =>
                      tool === "Connect" ? selectNote(n) : openNote(n.id)
                    }
                  />
                ))}
              </div>
              {!notes.length && (
                <div className="board-empty">
                  <h2>Space to think.</h2>
                  <p>Drag a coloured note onto your board, or click a stack.</p>
                  <button className="glass" onClick={() => addNote("butter")}>
                    + Create your first note
                  </button>
                </div>
              )}
            </div>
          )}
          {!list && (
            <aside className="note-piles" aria-label="Create a note">
              {colours.map((c) => (
                <button
                  key={c}
                  className={`note-pile ${c}`}
                  draggable
                  onDragStart={(e) => e.dataTransfer.setData("sprig/colour", c)}
                  onClick={() => addNote(c)}
                  aria-label={`New ${c} note`}
                  title={`Drag or click to create a ${c} note`}
                >
                  <i />
                  <i />
                  <i />
                </button>
              ))}
            </aside>
          )}
          {selectedNote && !editor && tool === "Select" && (
            <div className="selection-actions glass">
              <button onClick={() => openNote(selectedNote.id)}>Edit</button>
              <div className="swatches">
                {colours.map((c) => (
                  <button
                    key={c}
                    className={c}
                    aria-label={`Change selected note to ${c}`}
                    onClick={() => patchNote(selectedNote.id, { colour: c })}
                  />
                ))}
              </div>
              <button onClick={() => duplicate(selectedNote)}>Duplicate</button>
              <button onClick={() => deleteNote(selectedNote.id)}>Trash</button>
            </div>
          )}
          <div className="view-history glass">
            <button
              className={!list ? "active" : ""}
              onClick={() => setList(false)}
            >
              Board
            </button>
            <button
              className={list ? "active" : ""}
              onClick={() => setList(true)}
            >
              List
            </button>
            <span className="divider" />
            <button onClick={undo} disabled={!canUndo} aria-label="Undo">
              <Icon name="Undo" group="detail1" size={18} />
            </button>
            <button onClick={redo} disabled={!canRedo} aria-label="Redo">
              <Icon name="Redo" group="detail1" size={18} />
            </button>
          </div>
          {!list && (
            <>
              <div
                className="workspace-tools glass"
                role="toolbar"
                aria-label="Workspace tools"
              >
                {(["Select", "Pan", "Connect"] as const).map((t) => (
                  <button
                    key={t}
                    className={tool === t ? "active" : ""}
                    onClick={() => {
                      setTool(t);
                      setSelected(null);
                    }}
                  >
                    <Icon name={t} group="component3" size={18} />
                    {t}
                  </button>
                ))}
              </div>
              <div className="zoom-tools">
                <button
                  className="glass fit"
                  onClick={fit}
                  aria-label="Fit board"
                >
                  <Icon name="Fit" group="detail1" size={18} />
                </button>
                <div className="glass zoom">
                  <button
                    onClick={() => setZoom((z) => Math.max(0.25, z - 0.1))}
                    aria-label="Zoom out"
                  >
                    −
                  </button>
                  <button
                    onClick={() => {
                      setZoom(1);
                      setPan({ x: 0, y: 0 });
                    }}
                    aria-label="Reset zoom"
                  >
                    {Math.round(zoom * 100)}%
                  </button>
                  <button
                    onClick={() => setZoom((z) => Math.min(2.5, z + 0.1))}
                    aria-label="Zoom in"
                  >
                    +
                  </button>
                </div>
              </div>
            </>
          )}
          {tool === "Connect" && (
            <p className="tool-hint">
              {selected
                ? "Choose another note to connect."
                : "Choose two notes to connect them."}
            </p>
          )}
        </>
      )}
      {view === "Library" && (
        <main className="library-layout">
          <aside className="library-sidebar">
            <h2>Your library</h2>
            <button
              className={`folder-row ${!folder && !trash ? "active" : ""}`}
              onClick={() => {
                setFolder(null);
                setTrash(false);
              }}
            >
              All notes & boards
            </button>
            {folderTree(null)}
            <button className="folder-row" onClick={() => showForm("folder")}>
              + New folder
            </button>
            <button
              className={`folder-row ${trash ? "active" : ""}`}
              onClick={() => setTrash(true)}
            >
              Trash <span>{w.notes.filter((n) => n.deletedAt).length}</span>
            </button>
            <div className="library-backup">
              <button
                onClick={() =>
                  download(
                    "sprig-backup.json",
                    JSON.stringify(w, null, 2),
                    "application/json",
                  )
                }
              >
                Export workspace backup
              </button>
              <button onClick={() => importInput.current?.click()}>
                Import backup
              </button>
            </div>
          </aside>
          <section className="library-main">
            <div className="list-heading">
              <h2>
                {trash
                  ? "Trash"
                  : folder
                    ? w.folders.find((f) => f.id === folder)?.name
                    : "All notes & boards"}
              </h2>
              {!trash && (
                <button className="glass" onClick={() => showForm("board")}>
                  + New board
                </button>
              )}
            </div>
            {trash ? (
              <>
                <p className="muted">Notes stay here until you restore them.</p>
                {w.notes
                  .filter((n) => n.deletedAt)
                  .map((n) => (
                    <div className="list-note" key={n.id}>
                      <strong>{n.title}</strong>
                      <button
                        onClick={() =>
                          patchNote(n.id, { deletedAt: undefined })
                        }
                      >
                        Restore note
                      </button>
                    </div>
                  ))}
                {!w.notes.some((n) => n.deletedAt) && (
                  <p className="empty">Your trash is empty.</p>
                )}
              </>
            ) : (
              <>
                {folder && (
                  <div className="subfolders">
                    {w.folders
                      .filter((f) => f.parentId === folder)
                      .map((f) => (
                        <button
                          className="glass"
                          key={f.id}
                          onClick={() => setFolder(f.id)}
                        >
                          ▱ {f.name}
                        </button>
                      ))}
                  </div>
                )}
                <div className="library-boards">
                  {libraryBoards.map((b) => (
                    <button
                      className="library-board"
                      key={b.id}
                      onClick={() => openBoard(b.id)}
                    >
                      <span className={`board-thumb ${b.colour}`}>
                        <Icon name="Board" group="component0" size={22} />
                      </span>
                      <strong>{b.title}</strong>
                      <small>
                        {folderPath(w.folders, b.folderId)
                          .map((f) => f.name)
                          .join(" / ")}
                      </small>
                      <span>
                        {activeNotes.filter((n) => n.boardId === b.id).length}{" "}
                        notes ↗
                      </span>
                    </button>
                  ))}
                </div>
                <h2 className="library-notes-heading">Notes</h2>
                <div className="note-grid">
                  {activeNotes
                    .filter(
                      (n) =>
                        !folder ||
                        w.boards.find((b) => b.id === n.boardId)?.folderId ===
                          folder,
                    )
                    .map((n) => {
                      const b = w.boards.find((b) => b.id === n.boardId)!;
                      return (
                        <NoteCard
                          key={n.id}
                          note={n}
                          compact
                          board={b.title}
                          subject={subject(b)}
                          onOpen={() => openNote(n.id)}
                        />
                      );
                    })}
                </div>
              </>
            )}
          </section>
        </main>
      )}
      {view === "Search" && (
        <main className="search-content">
          <label className="search-box glass">
            <Icon name="Search" />
            <input
              aria-label="Search notes"
              autoFocus
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Find a thought, topic or note…"
            />
            <kbd>⌘K</kbd>
          </label>
          <p className="muted">
            {query
              ? `${searchResults.length} matching notes`
              : "Search across your notes and Markdown."}
          </p>
          <div className="note-grid">
            {searchResults.map((n) => {
              const b = w.boards.find((b) => b.id === n.boardId)!;
              return (
                <NoteCard
                  key={n.id}
                  note={n}
                  compact
                  board={b.title}
                  subject={subject(b)}
                  onOpen={() => openNote(n.id)}
                />
              );
            })}
          </div>
          {!searchResults.length && (
            <p className="empty">No notes found. Try a different word.</p>
          )}
        </main>
      )}
      {form && (
        <Dialog
          title={
            form === "folder"
              ? "New folder"
              : form === "board"
                ? "New board"
                : "Rename board"
          }
          onClose={() => setForm(null)}
        >
          <form onSubmit={submitForm}>
            <label>
              Name
              <input
                autoFocus
                aria-label="Name"
                required
                maxLength={120}
                value={formName}
                onChange={(e) => setFormName(e.target.value)}
                placeholder={
                  form === "folder"
                    ? "e.g. Social psychology"
                    : "e.g. Conformity"
                }
              />
            </label>
            {form !== "rename" && (
              <label>
                {form === "folder" ? "Inside folder" : "Folder"}
                <select
                  value={formParent}
                  onChange={(e) => setFormParent(e.target.value)}
                >
                  {form === "folder" && <option value="">Top level</option>}
                  {w.folders.map((f) => (
                    <option key={f.id} value={f.id}>
                      {folderPath(w.folders, f.id)
                        .map((p) => p.name)
                        .join(" / ")}
                    </option>
                  ))}
                </select>
              </label>
            )}
            <div className="form-actions">
              <button type="button" onClick={() => setForm(null)}>
                Cancel
              </button>
              <button className="primary" type="submit">
                {form === "rename" ? "Save name" : "Create"}
              </button>
            </div>
          </form>
        </Dialog>
      )}
      {editor && (
        <NoteEditor
          key={editor.id}
          note={editor}
          update={(patch) =>
            patchNote(
              editor.id,
              patch,
              `editor-${editor.id}-${editSession.current}`,
            )
          }
          close={() => setEditorId(null)}
          saved
          error={error}
          onDelete={() => deleteNote(editor.id)}
          onDuplicate={() => duplicate(editor)}
        />
      )}
      <input
        type="file"
        ref={importInput}
        accept="application/json,.json"
        hidden
        onChange={(e) => importBackup(e.target.files?.[0])}
      />
      {message && (
        <div className="toast glass" role="status">
          {message}
        </div>
      )}
    </div>
  );
}
