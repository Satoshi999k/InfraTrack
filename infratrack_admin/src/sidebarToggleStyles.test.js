import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import postcss from "postcss";

const stylesheet = postcss.parse(
  await readFile(new URL("./styles.css", import.meta.url), "utf8"),
);

function getStyles(selector) {
  const styles = {};
  stylesheet.walkRules(selector, (rule) => {
    rule.walkDecls((declaration) => {
      styles[declaration.prop] = declaration.value;
    });
  });
  return styles;
}

test("sidebar toggle is a small circular control attached to the sidebar edge", () => {
  const toggle = getStyles(".sidebar-toggle");

  assert.equal(toggle.top, "4px");
  assert.equal(toggle.right, "-13px");
  assert.equal(toggle.width, "26px");
  assert.equal(toggle.height, "26px");
  assert.equal(toggle["border-radius"], "50%");
  assert.equal(toggle.color, "#fff");
});

test("collapsed sidebar does not reposition the edge toggle", () => {
  assert.deepEqual(getStyles(".sidebar-collapsed .sidebar-toggle"), {});
});
