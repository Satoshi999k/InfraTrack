export function normalizeAdvisoryEngagement(result) {
  if (
    !result ||
    typeof result !== "object" ||
    !result.advisory ||
    typeof result.advisory !== "object" ||
    Array.isArray(result.advisory) ||
    !Array.isArray(result.comments) ||
    !Array.isArray(result.reactions)
  ) {
    throw new Error("The server returned invalid advisory activity.");
  }

  return {
    ...result,
    advisory: {
      ...result.advisory,
      title:
        typeof result.advisory.title === "string"
          ? result.advisory.title
          : "City advisory",
      message:
        typeof result.advisory.message === "string"
          ? result.advisory.message
          : "",
      author_name:
        typeof result.advisory.author_name === "string"
          ? result.advisory.author_name
          : "Mati City",
    },
    comments: result.comments.map((comment) => {
      if (!comment || typeof comment !== "object" || Array.isArray(comment)) {
        throw new Error("The server returned invalid advisory comments.");
      }
      return {
        ...comment,
        author_name:
          typeof comment.author_name === "string"
            ? comment.author_name
            : "Former user",
        author_role:
          typeof comment.author_role === "string" ? comment.author_role : "",
        body: typeof comment.body === "string" ? comment.body : "",
      };
    }),
    reactions: result.reactions.map((reaction) => {
      if (!reaction || typeof reaction !== "object" || Array.isArray(reaction)) {
        throw new Error("The server returned invalid advisory reactions.");
      }
      return {
        ...reaction,
        user_name:
          typeof reaction.user_name === "string"
            ? reaction.user_name
            : "Former user",
      };
    }),
  };
}

export function groupAdvisoryComments(comments) {
  const commentsById = new Map(
    comments.map((comment) => [Number(comment.id), comment]),
  );
  const topLevelComments = [];
  const repliesByParent = new Map();

  for (const comment of comments) {
    const parentId = Number(comment.parent_comment_id);
    if (comment.parent_comment_id == null || !commentsById.has(parentId)) {
      topLevelComments.push(comment);
      continue;
    }

    const parent = commentsById.get(parentId);
    const parentRootId = Number(parent.parent_comment_id);
    const threadId =
      parent.parent_comment_id != null && commentsById.has(parentRootId)
        ? parentRootId
        : parentId;
    const replies = repliesByParent.get(threadId) ?? [];
    replies.push(comment);
    repliesByParent.set(threadId, replies);
  }

  return { topLevelComments, repliesByParent };
}
