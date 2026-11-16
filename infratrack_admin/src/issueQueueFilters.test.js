import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import postcss from "postcss";

const stylesheet = postcss.parse(
  await readFile(new URL("./styles.css", import.meta.url), "utf8"),
);

function getStyles(selector, viewportWidth) {
  const styles = {};

  stylesheet.walkRules(selector, (rule) => {
    let parent = rule.parent;
    while (parent && parent.type !== "root") {
      if (parent.type === "atrule" && parent.name === "media") {
        const maxWidth = parent.params.match(/max-width:\s*(\d+)px/);
        const minWidth = parent.params.match(/min-width:\s*(\d+)px/);
        if (maxWidth && viewportWidth > Number(maxWidth[1])) return;
        if (minWidth && viewportWidth < Number(minWidth[1])) return;
      }
      parent = parent.parent;
    }

    rule.walkDecls((declaration) => {
      styles[declaration.prop] = declaration.value;
    });
  });

  return styles;
}

test("issue queue status filters remain in one horizontally scrollable row", () => {
  for (const viewportWidth of [390, 1024]) {
    const filterStyles = getStyles(".queue-filters", viewportWidth);

    assert.equal(filterStyles.display, "flex");
    assert.equal(filterStyles["flex-wrap"], "nowrap");
    assert.equal(filterStyles["overflow-x"], "auto");
    assert.equal(filterStyles["max-width"], "100%");
  }

  assert.equal(getStyles(".queue-filters .filter", 390).flex, "0 0 auto");
});
