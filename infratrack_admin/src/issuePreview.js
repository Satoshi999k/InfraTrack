export function getIssueMediaPreview(issue) {
  const mediaUrl = issue?.media_url || "";
  const isVideo =
    String(issue?.media_kind || "").toLowerCase() === "video" ||
    /\.(mp4|mov|m4v|webm|mkv)(?:[?#]|$)/i.test(mediaUrl);

  return {
    isVideo,
    thumbnailUrl: isVideo
      ? issue?.media_thumbnail_url || null
      : mediaUrl || null,
  };
}
