import React from "react";
import { createRoot } from "react-dom/client";
import { flushSync } from "react-dom";
import { renderToStaticMarkup } from "react-dom/server";
import { createLiveEditor } from "./editor";
import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkMath from "remark-math";
import rehypeKatex from "rehype-katex";
import "@fontsource/inter/400.css";
import "@fontsource/inter/500.css";
import "@fontsource/inter/600.css";
import "@fontsource/inter/700.css";
import "katex/dist/katex.min.css";
import "./preview.css";
function Content({ text }) {
  const reveal = text.match(
    /<details>\s*<summary>(.*?)<\/summary>([\s\S]*?)<\/details>/,
  );
  if (reveal)
    return (
      <>
        <Content text={text.slice(0, reveal.index)} />
        <details>
          <summary>{reveal[1]}</summary>
          <Content text={reveal[2]} />
        </details>
        <Content text={text.slice(reveal.index + reveal[0].length)} />
      </>
    );
  return (
    <Markdown
      remarkPlugins={[remarkGfm, remarkMath]}
      rehypePlugins={[rehypeKatex]}
    >
      {text}
    </Markdown>
  );
}
const root = createRoot(document.getElementById("root"));
window.sprigRender = (text, background) => {
  document.documentElement.style.background = background;
  flushSync(() => root.render(<Content text={text} />));
};
window.sprigRender("", "#fbf0bf");

window.sprigStartEditor = (text, sourceMode = false) => {
  flushSync(() => root.unmount());
  document.documentElement.classList.add('sprig-editing');
  document.documentElement.style.background = 'transparent';
  window.sprigEditor = createLiveEditor(document.getElementById('root'), text, text => renderToStaticMarkup(<Content text={text} />));
  window.sprigEditor.setMode(sourceMode);
  window.sprigEditor.focus();
};
