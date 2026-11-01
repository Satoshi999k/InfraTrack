import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const template = await readFile(
  new URL("../src/site-content.html", import.meta.url),
  "utf8",
);

test("the HTML template contains every section required by the React shell", () => {
  for (const selector of [
    'class="skip"',
    'id="nav"',
    'id="menu"',
    'id="stage"',
    'id="rm"',
    'id="final"',
    'class="footer"',
  ]) {
    assert.ok(
      template.includes(selector),
      `Missing required selector ${selector}`,
    );
  }
});

test("the skip link targets the main landmark and navigation stays labeled", () => {
  assert.match(template, /<a class="skip" href="#main">/);
  assert.match(template, /<nav class="nav-links" aria-label="Sections">/);
  assert.match(
    template,
    /<nav class="menu" id="menu" aria-label="Mobile sections">/,
  );
  assert.match(template, /<main id="main">/);
});
