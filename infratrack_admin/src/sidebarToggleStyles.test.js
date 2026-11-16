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

test("sidebar toggle is large, high-contrast, and inset inside the sidebar", () => {
  const toggle = getStyles(".sidebar-toggle");

  assert.equal(toggle.right, "12px");
  assert.equal(toggle.width, "36px");
  assert.equal(toggle.height, "36px");
  assert.equal(toggle.border, "2px solid #fff");
  assert.equal(toggle.color, "#fff");
});

test("collapsed sidebar keeps the toggle centered beneath the brand mark", () => {
  const collapsedToggle = getStyles(".sidebar-collapsed .sidebar-toggle");
  const collapsedHeading = getStyles(".sidebar-collapsed .sidebar-heading");

  assert.equal(collapsedToggle.right, "50%");
  assert.equal(collapsedToggle.transform, "translateX(50%)");
  assert.equal(collapsedHeading["padding-bottom"], "46px");
});
