import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import postcss from "postcss";

const stylesheet = postcss.parse(
  await readFile(new URL("./styles.css", import.meta.url), "utf8"),
);

function getStyles(selector) {
  const styles = {};
  let rule;
  stylesheet.walkRules((candidate) => {
    if (!rule && candidate.selector === selector) rule = candidate;
  });

  rule?.walkDecls((declaration) => {
    styles[declaration.prop] = declaration.value;
  });
  return styles;
}

test("sidebar toggle is centered over the sidebar edge despite sidebar padding", () => {
  const toggle = getStyles(".sidebar-toggle");

  assert.equal(toggle.right, "-27px");
  assert.equal(toggle.width, "26px");
  assert.equal(toggle.height, "26px");
  assert.equal(toggle["border-radius"], "50%");
  assert.equal(toggle.display, "grid");
  assert.equal(toggle["place-items"], "center");
});

test("collapsed sidebar centers the toggle over its narrower edge", () => {
  const collapsedToggle = getStyles(".sidebar-collapsed .sidebar-toggle");

  assert.equal(collapsedToggle.right, "-23px");
});

test("chevron is optically centered inside the circular toggle", () => {
  assert.equal(
    getStyles(".sidebar-toggle svg").transform,
    "translateX(1px)",
  );
});

test("sidebar toggle stacks above the sticky header where they meet", () => {
  const sidebarLayer = Number(getStyles(".sidebar")["z-index"]);
  const headerLayer = Number(getStyles(".topbar")["z-index"]);

  assert.ok(sidebarLayer > headerLayer);
});
