import { useEffect, useRef, useState } from "react";
import { createDemo, validateWorkspace, type Workspace } from "./model";
export const STORAGE_KEY = "tandemry.sprig.workspace.v1";
function load(): { workspace: Workspace; error: string; blocked: boolean } {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { workspace: createDemo(), error: "", blocked: false };
    const parsed = JSON.parse(raw);
    if (!validateWorkspace(parsed)) throw new Error("Invalid workspace");
    return { workspace: parsed, error: "", blocked: false };
  } catch {
    return {
      workspace: createDemo(),
      error:
        "Your saved workspace could not be read. The original data has been kept. Export a backup before starting a new session.",
      blocked: true,
    };
  }
}
export function useWorkspace() {
  const [initial] = useState(load),
    [workspace, setWorkspace] = useState(initial.workspace),
    [error, setError] = useState(initial.error);
  const [revision, setRevision] = useState(0),
    past = useRef<Workspace[]>([]),
    future = useRef<Workspace[]>([]),
    current = useRef(workspace),
    lastGroup = useRef("");
  useEffect(() => {
    if (initial.blocked) return;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(workspace));
      setError("");
    } catch {
      setError(
        "Changes could not be saved on this device. Export a backup now to keep your work.",
      );
    }
  }, [workspace, initial.blocked]);
  function commit(change: (w: Workspace) => Workspace, group = "") {
    const next = change(current.current);
    if (next === current.current) return;
    if (!group || lastGroup.current !== group)
      past.current = [...past.current.slice(-79), current.current];
    future.current = [];
    lastGroup.current = group;
    current.current = next;
    setWorkspace(next);
    setRevision((r) => r + 1);
  }
  function undo() {
    const prev = past.current.pop();
    if (!prev) return;
    future.current.push(current.current);
    current.current = prev;
    lastGroup.current = "";
    setWorkspace(prev);
    setRevision((r) => r + 1);
  }
  function redo() {
    const next = future.current.pop();
    if (!next) return;
    past.current.push(current.current);
    current.current = next;
    lastGroup.current = "";
    setWorkspace(next);
    setRevision((r) => r + 1);
  }
  return {
    workspace,
    commit,
    undo,
    redo,
    canUndo: past.current.length > 0,
    canRedo: future.current.length > 0,
    error,
    revision,
  };
}
