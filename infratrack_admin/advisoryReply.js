export function formatAdvisoryMention(authorName) {
  const name = String(authorName ?? "")
    .trim()
    .replace(/\s+/g, " ");
  return name ? `@${name} ` : "";
}
