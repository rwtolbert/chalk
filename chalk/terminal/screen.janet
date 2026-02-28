# Layer 5: Virtual screen buffer with diff-based rendering
# Uses 1-based coordinates throughout (matching ANSI conventions).

(import ./output)
(import ./style)

(defn- make-cell
  "Create a screen cell."
  [&opt ch s]
  (default ch " ")
  @{:char ch :style s})

(defn- cell=
  "Compare two cells for equality."
  [a b]
  (and (= (a :char) (b :char))
       (let [sa (a :style)
             sb (b :style)]
         (cond
           (and (nil? sa) (nil? sb)) true
           (or (nil? sa) (nil? sb)) false
           (style/style= sa sb)))))

(defn- make-buffer
  "Create a buffer of cols*rows cells."
  [cols rows]
  (def size (* cols rows))
  (def buf (array/new size))
  (for i 0 size
    (array/push buf (make-cell)))
  buf)

(defn make-screen
  "Create a virtual screen with front (composing) and back (last frame) buffers."
  [cols rows]
  @{:cols cols
    :rows rows
    :front (make-buffer cols rows)
    :back (make-buffer cols rows)})

(defn screen-resize
  "Resize the screen buffers."
  [screen cols rows]
  (put screen :cols cols)
  (put screen :rows rows)
  (put screen :front (make-buffer cols rows))
  (put screen :back (make-buffer cols rows)))

(defn- cell-index
  "Convert 1-based col,row to 0-based array index."
  [screen col row]
  (+ (* (- row 1) (screen :cols)) (- col 1)))

(defn screen-put
  "Put a character at col,row (1-based) with optional style."
  [screen col row ch &opt s]
  (def idx (cell-index screen col row))
  (def front (screen :front))
  (when (and (>= idx 0) (< idx (length front)))
    (def cell (get front idx))
    (put cell :char ch)
    (put cell :style s)))

(defn screen-put-string
  "Write a string starting at col,row (1-based). Returns the column after the last char.
   Handles multi-byte UTF-8 characters correctly."
  [screen col row text &opt s]
  (def cols (screen :cols))
  (def len (length text))
  (var c col)
  (var i 0)
  (while (< i len)
    (when (> c cols) (break))
    (def b (get text i))
    # Determine UTF-8 byte length from leading byte
    (def char-len
      (cond
        (< b 0x80) 1
        (< b 0xE0) 2
        (< b 0xF0) 3
        4))
    (def ch (string/slice text i (min (+ i char-len) len)))
    (screen-put screen c row ch s)
    (++ c)
    (set i (+ i char-len)))
  c)

(defn screen-clear
  "Clear the front buffer (fill with spaces, nil style)."
  [screen]
  (each cell (screen :front)
    (put cell :char " ")
    (put cell :style nil)))

(defn screen-force-redraw
  "Invalidate the back buffer so the next render redraws everything."
  [screen]
  (each cell (screen :back)
    (put cell :char "\xff")
    (put cell :style nil)))

(defn screen-render
  "Diff front vs back buffer and emit only changed cells."
  [screen]
  (def {:cols cols :rows rows :front front :back back} screen)
  (def size (* cols rows))
  (var last-style nil)
  (var dirty false)

  (for i 0 size
    (def fcell (get front i))
    (def bcell (get back i))
    (when (not (cell= fcell bcell))
      (set dirty true)
      (def col (+ (mod i cols) 1))
      (def row (+ (div i cols) 1))
      (output/move-to col row)

      # Only emit SGR if style changed from last dirty cell
      (def s (fcell :style))
      (if (nil? s)
        (when (not (nil? last-style))
          (output/reset-style)
          (set last-style nil))
        (when (or (nil? last-style) (not (style/style= s last-style)))
          (output/set-style s)
          (set last-style s)))

      (output/put-text (fcell :char))

      # Update back buffer
      (put bcell :char (fcell :char))
      (put bcell :style (fcell :style))))

  (when dirty
    (output/reset-style))

  (output/flush))
