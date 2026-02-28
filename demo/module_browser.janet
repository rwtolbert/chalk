# Module Browser Demo: Browse installed Janet packages, modules, and exports
# ctrl-c to quit, tab/shift-tab to cycle focus, enter/space to expand/select,
# / to search, escape to clear search, j/k/up/down to navigate

(import ../chalk/platform/init :as platform)
(import ../chalk/terminal/output :as output)
(import ../chalk/terminal/screen :as screen)
(import ../chalk/terminal/style :as style)
(import ../chalk/events/loop :as loop)
(import ../chalk/widget/proto)
(import ../chalk/widget/text)
(import ../chalk/widget/container)
(import ../chalk/widget/border)
(import ../chalk/widget/list)
(import ../chalk/widget/input)
(import ../chalk/widget/render)
(import ../chalk/style/cascade)

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

# --- Module Discovery ---

(defn- scan-dir-recursive
  "Recursively find .janet files under dir, returning module names relative to dir."
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

            (= mode :directory)
            (array/concat modules (scan-dir-recursive full (string prefix f "/")))))))
    ([_] nil))
  modules)

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
  results)

(defn- load-module-exports
  "Load a module's exports via require. Returns sorted array of export info."
  [pkg-name mod-name cache]
  (def cache-key (string pkg-name "/" mod-name))
  (when (get cache cache-key)
    (break (get cache cache-key)))

  (def mod-path (string pkg-name "/" mod-name))
  (def mod-suffix (string "/" pkg-name "/" mod-name ".janet"))

  (def exports @[])
  (try
    (do
      (def env (require mod-path))
      (each [k v] (pairs env)
        (def name-str (string k))
        # Skip private symbols (starting with _) and module metadata
        (when (and (not (string/has-prefix? "_" name-str))
                   (not (string/has-prefix? ":" name-str))
                   (not (find |(= name-str $) ["*module*" "*should-not-redef*"])))
          (def meta (if (table? v) v @{}))
          # Skip re-exported symbols by checking source-map
          (def sm (get meta :source-map))
          (when (or (nil? sm)
                    (string/has-suffix? mod-suffix (get sm 0)))
            (def doc-str (get meta :doc))
            (def value (or (get meta :value) (get meta :ref)))
            (def type-str
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
            (array/push exports @{:name name-str :type type-str :doc doc-str})))))
    ([err]
      (array/push exports @{:name "(error loading module)" :type "error" :doc (string err)})))

  (sort-by |($ :name) exports)
  (put cache cache-key exports)
  exports)

# --- Tree Flattening ---

(defn- module-exports-match?
  "Check if any export in a module matches the filter text.
   Loads exports lazily via cache."
  [pkg-name mod-name filter-text exports-cache]
  (def exports (load-module-exports pkg-name mod-name exports-cache))
  (var found false)
  (each exp exports
    (when (and (not found)
               (not (nil? (string/find filter-text (string/ascii-lower (exp :name))))))
      (set found true)))
  found)

(defn- rebuild-tree
  "Flatten packages into display items + metadata map.
   Returns [tree-items tree-map].
   Filter matches against export names within modules."
  [packages search-text exports-cache]
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
        (when (module-exports-match? pkg-name mod-name filter-text exports-cache)
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
            # No space found — hard break
            (array/push lines (string/slice remaining 0 max-width))
            (set remaining (string/slice remaining max-width)))))
      (when (> (length remaining) 0)
        (array/push lines remaining))
      lines)))

(var detail-wrap-width 60)

(defn- build-detail-items
  "Format exports into display strings for the detail list.
   When filter-text is non-empty, only shows exports whose name matches."
  [exports &opt filter-text]
  (def ft (if (and filter-text (> (length filter-text) 0))
            (string/ascii-lower filter-text)
            nil))
  (def wrap-width detail-wrap-width)
  (def items @[])
  (each exp exports
    (when (or (nil? ft)
              (not (nil? (string/find ft (string/ascii-lower (exp :name))))))
      (array/push items (string (exp :name) " [" (exp :type) "]"))
      (when (exp :doc)
        (def doc-lines (string/split "\n" (exp :doc)))
        (each line doc-lines
          (def wrapped (wrap-line (string "  " line) wrap-width))
          (each wl wrapped
            (array/push items wl))))
      (array/push items "")))
  (if (= (length items) 0)
    @[(if ft "(no matching exports)" "(no exports)")]
    items))

# --- Main ---

(defn main [&]
  (def [cols rows] (platform/get-terminal-size))
  (var current-cols cols)
  (var current-rows rows)
  (var quit false)
  # Detail panel width: total cols minus tree (32) minus borders (4) minus list padding (2)
  (set detail-wrap-width (max 20 (- cols 38)))

  # App state
  (def packages (scan-packages))
  (def exports-cache @{})
  (var tree-items @[])
  (var tree-map @[])
  (var detail-items @["Select a module to view exports"])
  (var search-text "")
  (var focus :tree) # :tree, :detail, or :search
  (var selected-mod nil)
  (var tree-sel-override nil) # when non-nil, force tree selection to this index on next redraw

  # Initial tree build
  (def initial (rebuild-tree packages search-text exports-cache))
  (set tree-items (get initial 0))
  (set tree-map (get initial 1))

  (defn build-ui []
    (def tree-list (list/list-widget
                     :id "tree-list"
                     :items tree-items
                     :style {:fg :white}
                     :width 30))

    (def detail-list (list/list-widget
                       :id "detail-list"
                       :items detail-items
                       :style {:fg :white}
                       :flex-grow 1))

    (def search-input (input/input-widget
                        :id "search-input"
                        :value search-text
                        :placeholder "type to filter..."
                        :style {:fg :white}
                        :flex-grow 1
                        :height 1))

    (def detail-title
      (if selected-mod
        (string " " selected-mod " ")
        " Exports "))

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

          # Footer
          (container/container
            :id "footer"
            :flex-direction :row
            :children
            @[(text/text " /: search " :width 12)
              search-input
              (text/text " esc: clear | ctrl-c: quit " :width 28)])

          # Main area
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
                :width 32
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

    (cascade/apply-stylesheet app-css root)
    [root tree-list detail-list search-input])

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

    (var scr (screen/make-screen current-cols current-rows))
    (screen/screen-force-redraw scr)

    (loop/start)

    (var ui-parts (build-ui))
    (var root (get ui-parts 0))
    (var tree-list (get ui-parts 1))
    (var detail-list (get ui-parts 2))
    (var search-input (get ui-parts 3))
    (proto/mount-tree root)
    (render/render-tree scr root current-cols current-rows)

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
                             :search :tree))
                (set needs-redraw true))

              # Shift-tab: cycle focus backward
              (= k :shift-tab)
              (do
                (set focus (case focus
                             :tree :search
                             :detail :tree
                             :search :detail))
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
                (def rebuilt (rebuild-tree packages search-text exports-cache))
                (set tree-items (get rebuilt 0))
                (set tree-map (get rebuilt 1))
                # Clear filter from detail panel
                (when selected-mod
                  (def [pkg-name mod-name] (string/split "/" selected-mod 0 2))
                  (def exports (load-module-exports pkg-name mod-name exports-cache))
                  (set detail-items (build-detail-items exports)))
                (set needs-redraw true))

              # Tree focus
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
                          (def rebuilt (rebuild-tree packages search-text exports-cache))
                          (set tree-items (get rebuilt 0))
                          (set tree-map (get rebuilt 1))
                          (set needs-redraw true))

                        :module
                        (do
                          (def exports (load-module-exports (entry :pkg-name) (entry :name) exports-cache))
                          (set detail-items (build-detail-items exports search-text))
                          (set selected-mod (string (entry :pkg-name) "/" (entry :name)))
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
                        (def exports (load-module-exports (entry :pkg-name) (entry :name) exports-cache))
                        (set detail-items (build-detail-items exports search-text))
                        (set selected-mod (string (entry :pkg-name) "/" (entry :name)))
                        (set needs-redraw true))))))

              # Detail focus
              (= focus :detail)
              (do
                (def result ((detail-list :handle-event) detail-list event))
                (when result (set needs-redraw true)))

              # Search focus
              (= focus :search)
              (if (= k :enter)
                (do
                  (set focus :tree)
                  (set needs-redraw true))
                (do
                  (def result ((search-input :handle-event) search-input event))
                  (set search-text (get-in search-input [:state :value] ""))
                  (def rebuilt (rebuild-tree packages search-text exports-cache))
                  (set tree-items (get rebuilt 0))
                  (set tree-map (get rebuilt 1))
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
                      # Current module still visible — keep it selected
                      (set tree-sel-override found-idx)
                      (def [pkg-name mod-name] (string/split "/" selected-mod 0 2))
                      (def exports (load-module-exports pkg-name mod-name exports-cache))
                      (set detail-items (build-detail-items exports search-text)))
                    (do
                      # Current module gone or none selected — auto-select first module
                      (var first-mod-idx nil)
                      (for i 0 (length tree-map)
                        (when (and (not first-mod-idx)
                                   (= ((get tree-map i) :type) :module))
                          (set first-mod-idx i)))
                      (if first-mod-idx
                        (do
                          (def entry (get tree-map first-mod-idx))
                          (set selected-mod (string (entry :pkg-name) "/" (entry :name)))
                          (set tree-sel-override first-mod-idx)
                          (def exports (load-module-exports (entry :pkg-name) (entry :name) exports-cache))
                          (set detail-items (build-detail-items exports search-text)))
                        (do
                          (set selected-mod nil)
                          (set detail-items @["No matching exports"])))))
                  (when result (set needs-redraw true))))))

          :resize
          (do
            (set current-cols (event :cols))
            (set current-rows (event :rows))
            (set detail-wrap-width (max 20 (- current-cols 38)))
            (set scr (screen/make-screen current-cols current-rows))
            (screen/screen-force-redraw scr)
            (set needs-redraw true))))

      (when (and needs-redraw (not quit))
        # Save selection state
        (def old-tree-sel (get-in tree-list [:state :selected] 0))
        (def old-detail-sel (get-in detail-list [:state :selected] 0))

        # Rebuild UI
        (def new-ui (build-ui))
        (set root (get new-ui 0))
        (set tree-list (get new-ui 1))
        (set detail-list (get new-ui 2))
        (set search-input (get new-ui 3))

        # Restore selections — use override if set, otherwise preserve old index
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
