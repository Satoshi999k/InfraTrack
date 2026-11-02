export function cloudinaryVideoThumbnailUrl(mediaUrl) {
  try {
    const parsedUrl = new URL(String(mediaUrl));
    const uploadMarker = "/video/upload/";
    const uploadIndex = parsedUrl.pathname.indexOf(uploadMarker);
    if (
      parsedUrl.protocol !== "https:" ||
      !parsedUrl.hostname.endsWith(".cloudinary.com") ||
      uploadIndex < 0
    ) {
      return null;
    }

    const assetPath = parsedUrl.pathname.slice(uploadIndex + uploadMarker.length);
    const videoExtension = /\.(mp4|mov|webm|m4v)$/i;
    if (!videoExtension.test(assetPath)) return null;

    const thumbnailPath = `${parsedUrl.pathname.slice(0, uploadIndex + uploadMarker.length)}so_0/${assetPath.replace(videoExtension, ".jpg")}`;
    parsedUrl.pathname = thumbnailPath;
    return parsedUrl.toString();
  } catch {
    return null;
  }
}
