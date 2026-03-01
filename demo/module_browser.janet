# ================================================================
# Module Browser - A chalk demo application
# ================================================================
# Browse installed Janet packages, modules, and their exports.
#
# Keybindings:
#   ctrl-c            quit
#   tab / shift-tab   cycle focus (tree -> detail -> search -> checkbox)
#   enter / space     expand package or select module
#   /                 jump to search input
#   escape            clear search, return to tree
#   j/k / up/down     navigate lists

# --- Chalk Imports ---
# Platform: terminal raw mode and size detection (FFI to libc)
(import ../chalk/platform/init :as platform)
# Terminal output: buffered escape sequences (cursor, color, alt screen)
(import ../chalk/terminal/output :as output)
# Virtual screen buffer with diff-based rendering
(import ../chalk/terminal/screen :as screen)
# SGR style codes (fg, bg, bold, etc.)
(import ../chalk/terminal/style :as style)
# Synchronous event loop: read keypresses and resize events
(import ../chalk/events/loop :as loop)
# Widget protocol: mount-tree lifecycle hook
(import ../chalk/widget/proto)
# Leaf widgets: text display, input field, checkbox, list, border
(import ../chalk/widget/text)
(import ../chalk/widget/container)
(import ../chalk/widget/border)
(import ../chalk/widget/list)
(import ../chalk/widget/input)
(import ../chalk/widget/checkbox)
# Render pipeline: layout + paint widget tree onto screen buffer
(import ../chalk/widget/render)
# CSS cascade: parse stylesheet and apply styles to widget tree
(import ../chalk/style/cascade)

# --- Stylesheet ---
# Chalk supports a CSS subset for styling widget trees. Selectors match
# widget :id values (#header), and properties map to terminal attributes.
# The `dock` property pins a widget to a screen edge (top/bottom).
(def app-css `
  #header {
    background: blue;
    color: white;
    bold: true;
    dock: top;
    height: 1;
  }

  #footer {
    background: bright-black;
    color: white;
    dock: bottom;
    height: 1;
  }
`)

# ================================================================
# Data Layer: Module Discovery & Introspection
# ================================================================

# --- Type Classification ---

(defn- classify-value
  ```
  Return a type string for a binding's value (function, macro, cfunction, etc.).
  Used to label exports in the detail panel.
  ```
  [meta value]
  (cond
    (get meta :macro) "macro"
    (function? value) "function"
    (cfunction? value) "cfunction"
    (fiber? value) "fiber"
    (number? value) "number"
    (string? value) "string"
    (array? value) "array"
    (table? value) "table"
    (tuple? value) "tuple"
    (buffer? value) "buffer"
    (keyword? value) "keyword"
    (symbol? value) "symbol"
    (boolean? value) "boolean"
    (nil? value) "nil"
    "value"))

(def type-colors
  {"function" {:fg :cyan}
   "cfunction" {:fg :cyan}
   "macro" {:fg :magenta}
   "number" {:fg :yellow}
   "string" {:fg :green}
   "boolean" {:fg :yellow}
   "keyword" {:fg :green}
   "table" {:fg :yellow}
   "array" {:fg :yellow}
   "tuple" {:fg :yellow}
   "fiber" {:fg :red}
   "nil" {:fg :bright-black}})

# --- Package Scanning ---

# Detect native module extension for this platform (.so, .dll, etc.)
(def native-ext
  (let [expanded (module/expand-path "_" ":all::native:")]
    (string/slice expanded (+ (string/find "." expanded)))))

(defn- scan-dir-recursive
  "Recursively find .janet and native modules under dir."
  [dir prefix]
  (def modules @[])
  (try
    (do
      (def entries (os/dir dir))
      (each f (sort entries)
        (when (not (string/has-prefix? "." f))
          (def full (string dir "/" f))
          (def mode (os/stat full :mode))
          (cond
            (and (= mode :file)
                 (string/has-suffix? ".janet" f)
                 (not (string/has-suffix? ".meta.janet" f)))
            (do
              (def mod-name (string prefix (string/slice f 0 (- (length f) 6))))
              (array/push modules mod-name))

            (and (= mode :file)
                 (string/has-suffix? native-ext f))
            (do
              (def mod-name (string prefix (string/slice f 0 (- (length f) (length native-ext)))))
              (array/push modules mod-name))

            (= mode :directory)
            (array/concat modules (scan-dir-recursive full (string prefix f "/")))))))
    ([_] nil))
  modules)

(defn- scan-root-env
  ```
  Scan root-env and group symbols by prefix (string, math, os, etc.).
  Returns a package entry for Janet builtins.
  ```
  []
  (def prefixes @{})
  (each [k _] (pairs root-env)
    (def s (string k))
    (when (and (not (string/has-prefix? "_" s))
               (not (string/has-prefix? ":" s)))
      (def idx (string/find "/" s))
      (def prefix (if idx (string/slice s 0 idx) "core"))
      (when (> (length prefix) 0)
        (put prefixes prefix true))))
  (def modules (sort (keys prefixes)))
  @{:name "janet" :modules modules :expanded false})

(defn- scan-packages
  "Scan syspath for installed packages and their modules."
  []
  (def syspath (dyn *syspath* "."))
  (def results @[])
  (def seen @{})

  # Walk the syspath directory looking for subdirectories with .janet files
  (try
    (do
      (def entries (os/dir syspath))
      (each entry (sort entries)
        (when (not (get seen entry))
          # Skip hidden dirs, bin, man, .cache, bundle, etc.
          (when (and (not (string/has-prefix? "." entry))
                     (not (find |(= entry $) ["bin" "man" "lib" "bundle" "_bundle" ".cache"])))
            (def full-path (string syspath "/" entry))
            (when (= :directory (os/stat full-path :mode))
              (def modules (scan-dir-recursive full-path ""))
              (when (> (length modules) 0)
                (put seen entry true)
                (array/push results @{:name entry
                                      :modules modules
                                      :expanded false})))))))
    ([_] nil))

  # Prepend Janet builtins as the first package
  (array/insert results 0 (scan-root-env))
  results)

# --- Export Loading ---

(defn- load-root-env-exports
  ```
  Load exports from root-env for a given prefix module.
  prefix "core" means unprefixed symbols.
  ```
  [mod-name show-private]
  (def exports @[])
  (def is-core (= mod-name "core"))
  (def prefix-slash (if is-core nil (string mod-name "/")))

  (each [k v] (pairs root-env)
    (def name-str (string k))
    (def meta (if (table? v) v @{}))
    (when (and (not (string/has-prefix? "_" name-str))
               (not (string/has-prefix? ":" name-str))
               (or show-private (not (get meta :private))))
      (def has-slash (string/find "/" name-str))
      (def has-prefix (and has-slash (> has-slash 0)))
      (def matches
        (if is-core
          (not has-prefix)
          (and prefix-slash (string/has-prefix? prefix-slash name-str))))
      (when matches
        (def doc-str (get meta :doc))
        (def value (or (get meta :value) (get meta :ref)))
        (def type-str (classify-value meta value))
        (array/push exports @{:name name-str :type type-str :doc doc-str}))))

  (sort-by |($ :name) exports)
  exports)

(defn- load-module-exports
  "Load a module's exports via require. Returns sorted array of export info."
  [pkg-name mod-name cache &opt show-private]
  (default show-private false)
  (def cache-key (string pkg-name "/" mod-name (if show-private "/+private" "")))
  (when (get cache cache-key)
    (break (get cache cache-key)))

  # Janet builtins come from root-env, not require
  (when (= pkg-name "janet")
    (def exports (load-root-env-exports mod-name show-private))
    (put cache cache-key exports)
    (break exports))

  (def mod-path (string pkg-name "/" mod-name))
  (def mod-suffix (string "/" pkg-name "/" mod-name ".janet"))

  (def exports @[])
  (try
    (do
      (def env (require mod-path))
      (each [k v] (pairs env)
        (def name-str (string k))
        # Skip private symbols (starting with _) and module metadata
        (def meta (if (table? v) v @{}))
        (when (and (not (string/has-prefix? "_" name-str))
                   (not (string/has-prefix? ":" name-str))
                   (not (find |(= name-str $) ["*module*" "*should-not-redef*" "native" "current-file" "source"]))
                   (or show-private (not (get meta :private))))
          # Skip re-exported symbols by checking source-map
          # Native (C) modules have source-maps pointing to .c files
          (def sm (get meta :source-map))
          (def sm-file (when sm (get sm 0)))
          (when (or (nil? sm)
                    (string/has-suffix? mod-suffix sm-file)
                    (string/has-suffix? ".c" sm-file)
                    (string/has-suffix? ".cpp" sm-file)
                    (string/has-suffix? ".h" sm-file))
            (def doc-str (get meta :doc))
            (def value (or (get meta :value) (get meta :ref)))
            (def type-str (classify-value meta value))
            (array/push exports @{:name name-str :type type-str :doc doc-str})))))
    ([err]
      (array/push exports @{:name "(error loading module)" :type "error" :doc (string err)})))

  (sort-by |($ :name) exports)
  (put cache cache-key exports)
  exports)

# --- Tree Model ---

(defn- module-exports-match?
  ```
  Check if any export in a module matches the filter text.
  Loads exports lazily via cache.
  ```
  [pkg-name mod-name filter-text exports-cache &opt show-private]
  (def exports (load-module-exports pkg-name mod-name exports-cache show-private))
  (var found false)
  (each exp exports
    (when (and (not found)
               (not (nil? (string/find filter-text (string/ascii-lower (exp :name))))))
      (set found true)))
  found)

(defn- rebuild-tree
  ```
  Flatten packages into display items + metadata map.
  Returns [tree-items tree-map].
  Filter matches against export names within modules.
  ```
  [packages search-text exports-cache &opt show-private]
  (def items @[])
  (def tmap @[])
  (def filter-text (if (and search-text (> (length search-text) 0))
                     (string/ascii-lower search-text)
                     nil))

  (each pkg packages
    (def pkg-name (pkg :name))

    (var has-matching-module false)
    (def matching-modules @[])

    (each mod-name (pkg :modules)
      (if filter-text
        (when (module-exports-match? pkg-name mod-name filter-text exports-cache show-private)
          (set has-matching-module true)
          (array/push matching-modules mod-name))
        (array/push matching-modules mod-name)))

    (when (or (not filter-text) has-matching-module)
      (def expanded (or (pkg :expanded) (and filter-text has-matching-module)))
      (def prefix (if expanded "v " "> "))
      (array/push items (string prefix pkg-name))
      (array/push tmap @{:type :package :name pkg-name :pkg pkg})

      (when expanded
        (each mod-name matching-modules
          (array/push items (string "    " mod-name))
          (array/push tmap @{:type :module :name mod-name :pkg-name pkg-name})))))

  [items tmap])

# --- Detail Formatting ---

(defn- wrap-line
  "Word-wrap a line to fit within max-width columns. Returns array of lines."
  [text max-width]
  (if (<= (length text) max-width)
    @[text]
    (do
      (def lines @[])
      (var remaining text)
      (while (> (length remaining) max-width)
        # Find last space within max-width
        (var break-at nil)
        (for i 0 max-width
          (when (= (get remaining i) (chr " "))
            (set break-at i)))
        (if break-at
          (do
            (array/push lines (string/slice remaining 0 break-at))
            (set remaining (string/slice remaining (+ break-at 1))))
          (do
            # No space found -- hard break
            (array/push lines (string/slice remaining 0 max-width))
            (set remaining (string/slice remaining max-width)))))
      (when (> (length remaining) 0)
        (array/push lines remaining))
      lines)))

(var detail-wrap-width 60)

(defn- build-detail-items
  ```
  Format exports into display strings for the detail list.
  When filter-text is non-empty, only shows exports whose name matches.
  Returns [items item-styles].
  ```
  [exports &opt filter-text]
  (def ft (if (and filter-text (> (length filter-text) 0))
            (string/ascii-lower filter-text)
            nil))
  (def wrap-width detail-wrap-width)
  (def items @[])
  (def styles @[])
  (each exp exports
    (when (or (nil? ft)
              (not (nil? (string/find ft (string/ascii-lower (exp :name))))))
      (def color (get type-colors (exp :type)))
      (array/push items (string (exp :name) " [" (exp :type) "]"))
      (array/push styles color)
      (when (exp :doc)
        (def doc-lines (string/split "\n" (exp :doc)))
        (each line doc-lines
          (def wrapped (wrap-line (string "  " line) wrap-width))
          (each wl wrapped
            (array/push items wl)
            (array/push styles nil))))
      (array/push items "")
      (array/push styles nil)))
  (if (= (length items) 0)
    [@[(if ft "(no matching exports)" "(no exports)")] @[nil]]
    [items styles]))

# ================================================================
# UI Layer: Layout, Widgets & Event Loop
# ================================================================

(defn main [&]
  (def [cols rows] (platform/get-terminal-size))
  (var current-cols cols)
  (var current-rows rows)
  (var quit false)

  # App state
  (def packages (scan-packages))
  (def exports-cache @{})
  (var tree-items @[])
  (var tree-map @[])
  (var detail-items @["Select a module to view exports"])
  (var detail-styles @[nil])
  (var search-text "")
  (var show-private false)
  (var focus :tree) # :tree, :detail, :search, or :checkbox
  (var selected-mod nil)
  (var tree-sel-override nil) # when non-nil, force tree selection to this index on next redraw
  (var tree-panel-width 32)

  # --- Helper closures ---
  # These close over app state vars above to eliminate repeated inline patterns.

  (defn refresh-tree-data []
    (def rebuilt (rebuild-tree packages search-text exports-cache show-private))
    (set tree-items (get rebuilt 0))
    (set tree-map (get rebuilt 1)))

  (defn refresh-detail [&opt filter]
    (when selected-mod
      (def [pkg-name mod-name] (string/split "/" selected-mod 0 2))
      (def exports (load-module-exports pkg-name mod-name exports-cache show-private))
      (let [[di ds] (build-detail-items exports (or filter search-text))]
        (set detail-items di)
        (set detail-styles ds))))

  (defn select-module [entry]
    (set selected-mod (string (entry :pkg-name) "/" (entry :name)))
    (refresh-detail))

  # Initial tree build
  (refresh-tree-data)

  (defn compute-tree-width []
    # Auto-widen from longest item + 2 (list padding) + 2 (border), capped at 40% of screen
    (var longest 10)
    (each item tree-items
      (when (> (length item) longest)
        (set longest (length item))))
    (def max-width (math/floor (* current-cols 0.4)))
    (min (+ longest 4) max-width))

  (defn truncate-item [item max-len]
    (if (> (length item) max-len)
      (string (string/slice item 0 (- max-len 3)) "...")
      item))

  # build-ui constructs a fresh widget tree from current state each frame.
  # This "rebuild-on-change" pattern avoids stale closures: instead of mutating
  # widgets in place, we recreate the tree and restore selection indices.
  (defn build-ui []
    (set tree-panel-width (compute-tree-width))
    (set detail-wrap-width (max 20 (- current-cols tree-panel-width 6)))
    (def inner-width (- tree-panel-width 4))
    (def display-items (map |(truncate-item $ inner-width) tree-items))

    # List widget: scrollable, keyboard-navigable list of items
    (def tree-list (list/list-widget
                     :id "tree-list"
                     :items display-items
                     :style {:fg :white}
                     :width (- tree-panel-width 2)))

    (def detail-list (list/list-widget
                       :id "detail-list"
                       :items detail-items
                       :item-styles detail-styles
                       :style {:fg :white}
                       :flex-grow 1))

    # Input widget: single-line text field with placeholder
    (def search-input (input/input-widget
                        :id "search-input"
                        :value search-text
                        :placeholder "type to filter..."
                        :style {:fg :white}
                        :flex-grow 1
                        :height 1))

    # Checkbox widget: toggleable boolean with label
    (def private-checkbox (checkbox/checkbox-widget
                            :id "private-checkbox"
                            :checked show-private
                            :label "private"
                            :checkbox-style :square
                            :style (if (= focus :checkbox)
                                     {:fg :cyan}
                                     {:fg :white})
                            :height 1))

    (def detail-title
      (if selected-mod
        (string " " selected-mod " ")
        " Exports "))

    # Container: flex layout parent. Border: decorative frame around a child.
    # The tree assembles as: column[ header, footer(docked), row[ tree-panel, detail-panel ] ]
    (def root
      (container/container
        :id "app"
        :flex-direction :column
        :children
        @[# Header
          (container/container
            :id "header"
            :children
            @[(text/text "Janet Module Browser" :text-align :center :flex-grow 1)])

          # Footer (docked to bottom via CSS)
          (container/container
            :id "footer"
            :flex-direction :row
            :children
            @[(text/text " /: search " :width 12)
              search-input
              (text/text " " :width 1)
              private-checkbox
              (text/text " esc: clear | ctrl-c: quit " :width 28)])

          # Main area: side-by-side tree and detail panels
          (container/container
            :id "main"
            :flex-direction :row
            :flex-grow 1
            :children
            @[# Tree panel
              (border/border
                tree-list
                :id "tree-panel"
                :border-style :rounded
                :width tree-panel-width
                :title (if (= focus :tree) " Packages (active) " " Packages ")
                :style (if (= focus :tree) {:fg :cyan} {:fg :white}))

              # Detail panel
              (border/border
                detail-list
                :id "detail-panel"
                :border-style :rounded
                :flex-grow 1
                :title (if (= focus :detail)
                         (string detail-title "(active) ")
                         detail-title)
                :style (if (= focus :detail) {:fg :cyan} {:fg :white}))])]))

    # Apply CSS stylesheet to the widget tree (selector matching + cascade)
    (cascade/apply-stylesheet app-css root)
    [root tree-list detail-list search-input private-checkbox])

  # --- Event loop setup ---
  # Enter raw mode so we receive individual keypresses instead of line-buffered input.
  # Alt screen preserves the user's terminal content and restores it on exit.
  (platform/enter-raw-mode)
  (defer (do
           (loop/stop)
           (output/disable-mouse)
           (output/reset-style)
           (output/exit-alt-screen)
           (output/show-cursor)
           (output/flush)
           (platform/exit-raw-mode))

    (output/enter-alt-screen)
    (output/hide-cursor)
    (output/flush)

    # Screen buffer: virtual grid that diffs against previous frame to minimize escape sequences
    (var scr (screen/make-screen current-cols current-rows))
    (screen/screen-force-redraw scr)

    (loop/start)

    # mount-tree runs lifecycle hooks; render-tree does layout + paint
    (var ui-parts (build-ui))
    (var root (get ui-parts 0))
    (var tree-list (get ui-parts 1))
    (var detail-list (get ui-parts 2))
    (var search-input (get ui-parts 3))
    (var private-cb (get ui-parts 4))
    (proto/mount-tree root)
    (render/render-tree scr root current-cols current-rows)

    # --- Main event loop ---
    # Each iteration: read events, handle input, rebuild UI if state changed.
    (while (not quit)
      (def events (loop/read-events))
      (var needs-redraw false)

      (each event events
        (case (event :type)
          :key
          (let [k (event :key)]
            (cond
              # Quit
              (= k :ctrl-c)
              (set quit true)

              # Tab: cycle focus forward
              (= k :tab)
              (do
                (set focus (case focus
                             :tree :detail
                             :detail :search
                             :search :checkbox
                             :checkbox :tree))
                (set needs-redraw true))

              # Shift-tab: cycle focus backward
              (= k :shift-tab)
              (do
                (set focus (case focus
                             :tree :checkbox
                             :detail :tree
                             :search :detail
                             :checkbox :search))
                (set needs-redraw true))

              # Slash: jump to search (unless already in search)
              (and (= k "/") (not= focus :search))
              (do
                (set focus :search)
                (set needs-redraw true))

              # Escape: clear search and go to tree
              (= k :escape)
              (do
                (set search-text "")
                (set focus :tree)
                (refresh-tree-data)
                (refresh-detail "")
                (set needs-redraw true))

              # Tree focus: navigate and select
              (= focus :tree)
              (do
                (cond
                  # Enter/space: toggle package or select module
                  (or (= k :enter) (= k " "))
                  (do
                    (def sel (get-in tree-list [:state :selected] 0))
                    (when (< sel (length tree-map))
                      (def entry (get tree-map sel))
                      (case (entry :type)
                        :package
                        (do
                          (def pkg (entry :pkg))
                          (put pkg :expanded (not (pkg :expanded)))
                          (refresh-tree-data)
                          (set needs-redraw true))

                        :module
                        (do
                          (select-module entry)
                          (set needs-redraw true)))))

                  # Navigation: forward to list widget
                  (do
                    (def result ((tree-list :handle-event) tree-list event))
                    (when result (set needs-redraw true))
                    # Auto-load exports when cursor lands on a module
                    (def sel (get-in tree-list [:state :selected] 0))
                    (when (< sel (length tree-map))
                      (def entry (get tree-map sel))
                      (when (= (entry :type) :module)
                        (select-module entry)
                        (set needs-redraw true))))))

              # Detail focus: forward all keys to the detail list
              (= focus :detail)
              (do
                (def result ((detail-list :handle-event) detail-list event))
                (when result (set needs-redraw true)))

              # Checkbox focus: toggle show-private on space/enter
              (= focus :checkbox)
              (do
                (when (or (= k " ") (= k :enter))
                  (set show-private (not show-private))
                  # Invalidate exports cache
                  (each ck (keys exports-cache)
                    (put exports-cache ck nil))
                  (refresh-detail)
                  (set needs-redraw true)))

              # Search focus: type to filter, enter to confirm
              (= focus :search)
              (if (= k :enter)
                (do
                  (set focus :tree)
                  (set needs-redraw true))
                (do
                  (def result ((search-input :handle-event) search-input event))
                  (set search-text (get-in search-input [:state :value] ""))
                  (refresh-tree-data)
                  # Sync tree selection with selected-mod
                  # Find current module's index in the new tree
                  (var found-idx nil)
                  (when selected-mod
                    (for i 0 (length tree-map)
                      (def entry (get tree-map i))
                      (when (and (not found-idx)
                                 (= (entry :type) :module)
                                 (= (string (entry :pkg-name) "/" (entry :name)) selected-mod))
                        (set found-idx i))))
                  (if found-idx
                    (do
                      # Current module still visible - keep it selected
                      (set tree-sel-override found-idx)
                      (refresh-detail))
                    (do
                      # Current module gone or none selected - auto-select first module
                      (var first-mod-idx nil)
                      (for i 0 (length tree-map)
                        (when (and (not first-mod-idx)
                                   (= ((get tree-map i) :type) :module))
                          (set first-mod-idx i)))
                      (if first-mod-idx
                        (do
                          (def entry (get tree-map first-mod-idx))
                          (select-module entry)
                          (set tree-sel-override first-mod-idx))
                        (do
                          (set selected-mod nil)
                          (set detail-items @["No matching exports"])
                          (set detail-styles @[nil])))))
                  (when result (set needs-redraw true))))))

          :resize
          (do
            (set current-cols (event :cols))
            (set current-rows (event :rows))
            (set scr (screen/make-screen current-cols current-rows))
            (screen/screen-force-redraw scr)
            (set needs-redraw true))))

      # --- Redraw ---
      # Save selection indices, rebuild the entire widget tree from current state,
      # then restore selections. This avoids stale widget references.
      (when (and needs-redraw (not quit))
        (def old-tree-sel (get-in tree-list [:state :selected] 0))
        (def old-detail-sel (get-in detail-list [:state :selected] 0))

        (def new-ui (build-ui))
        (set root (get new-ui 0))
        (set tree-list (get new-ui 1))
        (set detail-list (get new-ui 2))
        (set search-input (get new-ui 3))
        (set private-cb (get new-ui 4))

        # Restore selections - use override if set, otherwise preserve old index
        (def tree-sel
          (if tree-sel-override
            tree-sel-override
            (min old-tree-sel (max 0 (- (length tree-items) 1)))))
        (set tree-sel-override nil)
        (put (tree-list :state) :selected tree-sel)
        (put (detail-list :state) :selected (min old-detail-sel (max 0 (- (length detail-items) 1))))

        (proto/mount-tree root)
        (render/render-tree scr root current-cols current-rows)))))

(main)
(os/exit 0)
