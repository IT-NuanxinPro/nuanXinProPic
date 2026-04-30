#!/usr/bin/env bash

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "用法: ./scripts/process-video.sh <视频文件相对路径>"
  echo "示例: ./scripts/process-video.sh wallpaper/video/desktop/通用/demo.mp4"
  exit 1
fi

INPUT_PATH="$1"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_FILE="$PROJECT_ROOT/$INPUT_PATH"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "文件不存在: $SOURCE_FILE"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "缺少 ffmpeg"
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "缺少 ffprobe"
  exit 1
fi

RELATIVE_PATH="${INPUT_PATH#wallpaper/video/}"
FILENAME="$(basename "$RELATIVE_PATH")"
FILENAME_NO_EXT="${FILENAME%.*}"
SUBDIR="$(dirname "$RELATIVE_PATH")"

PREVIEW_DIR="$PROJECT_ROOT/preview/video/$SUBDIR"
THUMBNAIL_DIR="$PROJECT_ROOT/thumbnail/video/$SUBDIR"
PREVIEW_FILE="$PREVIEW_DIR/$FILENAME_NO_EXT.mp4"
THUMBNAIL_FILE="$THUMBNAIL_DIR/$FILENAME_NO_EXT.webp"
TMP_PREVIEW_FRAME_PNG="$PREVIEW_DIR/$FILENAME_NO_EXT-preview-frame.png"
TMP_THUMBNAIL_PNG="$THUMBNAIL_DIR/$FILENAME_NO_EXT.png"

mkdir -p "$PREVIEW_DIR" "$THUMBNAIL_DIR"

VIDEO_INFO="$(ffprobe -v quiet -print_format json -show_streams "$SOURCE_FILE")"
WIDTH="$(printf '%s' "$VIDEO_INFO" | ruby -rjson -e 'info = JSON.parse(STDIN.read); stream = info["streams"]&.find { |s| s["codec_type"] == "video" } || {}; print(stream["width"] || 0)')"
HEIGHT="$(printf '%s' "$VIDEO_INFO" | ruby -rjson -e 'info = JSON.parse(STDIN.read); stream = info["streams"]&.find { |s| s["codec_type"] == "video" } || {}; print(stream["height"] || 0)')"
VIDEO_CODEC="$(printf '%s' "$VIDEO_INFO" | ruby -rjson -e 'info = JSON.parse(STDIN.read); stream = info["streams"]&.find { |s| s["codec_type"] == "video" } || {}; print(stream["codec_name"] || "")')"
CONTAINER_FORMAT="$(ffprobe -v quiet -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$SOURCE_FILE")"

LONG_EDGE="$WIDTH"
if [ "${HEIGHT:-0}" -gt "${WIDTH:-0}" ]; then
  LONG_EDGE="$HEIGHT"
fi

TARGET_LONG_EDGE=1920
SCALE_FILTER="scale='if(gt(iw,ih),min(iw,${TARGET_LONG_EDGE}),-2)':'if(gt(iw,ih),-2,min(ih,${TARGET_LONG_EDGE}))'"

CAN_REMUX_DIRECTLY="false"
if [ "${LONG_EDGE:-0}" -le "${TARGET_LONG_EDGE}" ] && [ "$VIDEO_CODEC" = "h264" ] && [[ "$CONTAINER_FORMAT" == *"mp4"* || "$CONTAINER_FORMAT" == *"mov"* ]]; then
  CAN_REMUX_DIRECTLY="true"
fi

if [ "$CAN_REMUX_DIRECTLY" = "true" ]; then
  echo "源视频已在 1080p 档内，直接复用视频流生成预览..."
  ffmpeg -y -i "$SOURCE_FILE" \
    -map 0:v:0 \
    -c:v copy \
    -movflags +faststart \
    "$PREVIEW_FILE"
else
  echo "生成 1080p 预览视频..."
  ffmpeg -y -i "$SOURCE_FILE" \
    -vf "$SCALE_FILTER" \
    -c:v libx264 -preset medium -crf 24 \
    -movflags +faststart \
    -an \
    "$PREVIEW_FILE"
fi

echo "提取缩略图首帧..."
ffmpeg -y -i "$PREVIEW_FILE" -vf "select='eq(n\,0)'" -frames:v 1 -update 1 "$TMP_PREVIEW_FRAME_PNG"

echo "生成缩略图..."
ffmpeg -y -i "$TMP_PREVIEW_FRAME_PNG" -vf "scale=480:-1" -update 1 "$TMP_THUMBNAIL_PNG"

if sips -s format webp "$TMP_THUMBNAIL_PNG" --out "$THUMBNAIL_FILE" >/dev/null 2>&1; then
  rm -f "$TMP_THUMBNAIL_PNG"
  FINAL_THUMBNAIL_FILE="$THUMBNAIL_FILE"
else
  FINAL_THUMBNAIL_FILE="$TMP_THUMBNAIL_PNG"
fi

rm -f "$TMP_PREVIEW_FRAME_PNG"

echo "资源信息:"
ffprobe -v quiet -show_entries format=duration,size -show_entries stream=width,height -of default=noprint_wrappers=1 "$SOURCE_FILE"

echo "完成:"
echo "  预览视频: $PREVIEW_FILE"
echo "  缩略图: $FINAL_THUMBNAIL_FILE"
