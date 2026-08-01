# Builds motivational wallpapers: a Pexels photo with a ZenQuotes quote
# composited over it, written into a cache directory that rotate-wallpaper
# draws from.
#
# Every failure path here exits 0. This runs on a timer with no supervision,
# and a dead network or a rate-limited API should leave the existing cache
# alone rather than fail a unit -- rotate-wallpaper falls back to the nix
# pool if the cache is empty anyway.
#
# WALLPAPER_FONT / WALLPAPER_FONT_BOLD are set by the nix wrapper above.

: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"

CACHE_DIR="$XDG_CACHE_HOME/wallpaper-fetch"
IMAGE_DIR="$CACHE_DIR/images"
QUOTES="$CACHE_DIR/quotes.json"

# Deliberately a runtime file rather than a nix value: anything interpolated
# into a derivation lands in /nix/store, which is world-readable. Point this
# at a sops secret (owner = whitehead) if you'd rather manage it declaratively.
KEY_FILE="${PEXELS_KEY_FILE:-$XDG_CONFIG_HOME/wallpaper-fetch/pexels-key}"

# Both monitors are 2560x1440 (see hyprland.conf).
WIDTH=2560
HEIGHT=1440

# Images built per run. The timer is daily, the rotation is every 30 minutes,
# so this is about how fast the pool turns over rather than how much is on
# screen.
COUNT="${WALLPAPER_FETCH_COUNT:-6}"
KEEP="${WALLPAPER_FETCH_KEEP:-60}"

# Quotes long enough to need three lines look cramped against a photo.
MAX_QUOTE_LEN=180

log() { printf 'wallpaper-fetch: %s\n' "$*" >&2; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$IMAGE_DIR"

if [ ! -r "$KEY_FILE" ]; then
  log "no Pexels API key at $KEY_FILE -- nothing to do"
  exit 0
fi

KEY=$(tr -d '[:space:]' <"$KEY_FILE")
if [ -z "$KEY" ]; then
  log "Pexels API key at $KEY_FILE is empty -- nothing to do"
  exit 0
fi

# --- quotes ---------------------------------------------------------------
#
# ZenQuotes hands back 50 at a time and needs no auth, but keyless callers are
# limited to roughly 5 requests per 30s, and over the limit it returns a
# well-formed array whose single element is authored by "zenquotes.io". Filter
# that sentinel out or it ends up rendered on a wallpaper.

refresh_quotes() {
  local raw="$WORK/quotes-raw.json"

  if ! curl -fsS --max-time 20 https://zenquotes.io/api/quotes -o "$raw"; then
    log "quote fetch failed"
    return 1
  fi

  if ! jq -e 'type == "array" and length > 5' "$raw" >/dev/null 2>&1; then
    log "quote response was not a usable array (rate limited?)"
    return 1
  fi

  jq --argjson max "$MAX_QUOTE_LEN" \
    '[ .[]
       | select(.a != "zenquotes.io")
       | select((.q | length) <= $max)
       | {q, a} ]' "$raw" >"$WORK/quotes.json" || return 1

  if ! jq -e 'length > 0' "$WORK/quotes.json" >/dev/null 2>&1; then
    log "no quotes survived filtering"
    return 1
  fi

  mv "$WORK/quotes.json" "$QUOTES"
}

# Refresh weekly. The pool is 50 quotes and the rotation is every 30 minutes,
# so anything less frequent gets repetitive fast.
if [ ! -s "$QUOTES" ] || [ -n "$(find "$QUOTES" -mtime +7 -print -quit 2>/dev/null)" ]; then
  refresh_quotes || true
fi

if [ ! -s "$QUOTES" ]; then
  log "no quote cache and refresh failed -- leaving the image cache as it is"
  exit 0
fi

QUOTE_COUNT=$(jq 'length' "$QUOTES")

# --- imagery --------------------------------------------------------------
#
# Broad motivational range rather than one motif -- summits, open road, effort,
# solitude, scale. A single term ("marathon finish line") exhausts its good
# results within a few dozen images and starts repeating.

TERMS=(
  "mountain summit sunrise"
  "marathon finish line"
  "climber reaching peak"
  "runner sunrise silhouette"
  "open road horizon"
  "sailboat open ocean"
  "hiker mountain overlook"
  "starry night sky mountains"
  "rowing team sunrise"
  "cyclist mountain pass"
  "swimmer training pool"
  "desert road sunrise"
  "lighthouse storm waves"
  "forest path sunlight"
  "eagle flying sky"
  "waterfall long exposure"
  "city skyline sunrise"
  "person standing cliff edge"
  "kayak river rapids"
  "sunrise over clouds aerial"
  "winding road mountains"
  "boxer training gym"
  "aurora borealis mountains"
  "trail running mountains"
)

built=0

for ((n = 0; n < COUNT; n++)); do
  term=${TERMS[RANDOM % ${#TERMS[@]}]}
  # Pexels caps per_page at 80. Randomising the page stops every run from
  # drawing on the same first 80 results for a given term.
  page=$(((RANDOM % 5) + 1))
  resp="$WORK/resp.json"

  if ! curl -fsS --max-time 30 \
    -H "Authorization: $KEY" \
    --get \
    --data-urlencode "query=$term" \
    --data "orientation=landscape" \
    --data "size=large" \
    --data "per_page=80" \
    --data "page=$page" \
    https://api.pexels.com/v1/search -o "$resp"; then
    log "search failed for '$term' (rate limited or offline)"
    continue
  fi

  photos=$(jq '.photos | length' "$resp" 2>/dev/null || echo 0)
  if [ "$photos" -eq 0 ]; then
    log "no results for '$term' page $page"
    continue
  fi

  idx=$((RANDOM % photos))
  id=$(jq -r ".photos[$idx].id" "$resp")
  url=$(jq -r ".photos[$idx].src.original" "$resp")
  who=$(jq -r ".photos[$idx].photographer" "$resp")

  out="$IMAGE_DIR/pexels-$id.png"
  # Same photo can surface under several terms; don't pay to rebuild it.
  [ -e "$out" ] && continue

  raw="$WORK/raw"
  if ! curl -fsS --max-time 60 "$url" -o "$raw"; then
    log "download failed for photo $id"
    continue
  fi

  # Crop to fill rather than letterbox, then knock the photo back: these are
  # stock images shot for punch, and full-strength saturation behind a bar and
  # terminal windows is exhausting. The flat scrim on top is what actually
  # guarantees the text has contrast to sit on -- brightness alone doesn't,
  # since a summit shot can be near-white exactly where the quote lands.
  if ! magick "$raw" \
    -resize "${WIDTH}x${HEIGHT}^" \
    -gravity center -extent "${WIDTH}x${HEIGHT}" \
    -modulate 100,80,100 \
    -brightness-contrast -10x-6 \
    \( -size "${WIDTH}x${HEIGHT}" xc:'rgba(29,32,33,0.45)' \) \
    -compose over -composite \
    "$WORK/base.png" 2>/dev/null; then
    log "could not process photo $id"
    continue
  fi

  qi=$((RANDOM % QUOTE_COUNT))
  quote=$(jq -r ".[$qi].q" "$QUOTES")
  author=$(jq -r ".[$qi].a" "$QUOTES")

  # caption: word-wraps to the -size width and grows vertically, which is the
  # only way to lay out text of unknown length without measuring it first.
  magick -background none -fill '#d4be98' \
    -font "$WALLPAPER_FONT" -pointsize 66 \
    -size 1800x -gravity center \
    caption:"$quote" "$WORK/quote.png"

  magick -background none -fill '#d8a657' \
    -font "$WALLPAPER_FONT_BOLD" -pointsize 40 \
    label:"— $author" "$WORK/author.png"

  # A gap row between quote and attribution; -append has no spacing control.
  magick -size 1x28 xc:none "$WORK/gap.png"

  magick "$WORK/quote.png" "$WORK/gap.png" "$WORK/author.png" \
    -background none -gravity center -append "$WORK/text.png"

  # Drop shadow under the whole block. The scrim handles average brightness;
  # this handles the local case where a bright cloud sits directly behind a
  # glyph.
  magick "$WORK/text.png" \
    \( +clone -background black -shadow 90x8+0+3 \) \
    +swap -background none -layers merge +repage "$WORK/text-shadow.png"

  # Sitting slightly above centre reads better than dead centre -- optical
  # centre is high, and it keeps the quote clear of the panel.
  magick "$WORK/base.png" "$WORK/text-shadow.png" \
    -gravity center -geometry +0-40 -composite "$WORK/out.png"

  # Pexels doesn't require attribution, but crediting the photographer costs
  # one dim line in a corner. Some photos carry an empty (or null) photographer
  # field, which rendered as a bare "/ Pexels"; credit the source alone there.
  credit="Pexels"
  if [ -n "$who" ] && [ "$who" != "null" ]; then
    credit="$who / Pexels"
  fi

  magick "$WORK/out.png" \
    -font "$WALLPAPER_FONT" -pointsize 22 -fill '#a89984' \
    -gravity southeast -annotate +30+24 "$credit" \
    "$WORK/final.png"

  mv "$WORK/final.png" "$out"
  built=$((built + 1))
done

# --- prune ----------------------------------------------------------------
#
# Newest KEEP survive. Without this the cache grows without bound at COUNT
# images a day.
find "$IMAGE_DIR" -maxdepth 1 -type f -name '*.png' -printf '%T@ %p\0' |
  sort -zrn |
  tail -zn "+$((KEEP + 1))" |
  cut -z -d' ' -f2- |
  xargs -0r rm -f

log "built $built image(s); cache holds $(find "$IMAGE_DIR" -maxdepth 1 -type f -name '*.png' | wc -l)"
