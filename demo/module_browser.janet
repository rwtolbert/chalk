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
(import ../chalk/app)
(import ../chalk/widget/proto)
(import ../chalk/widget/text)
(import ../chalk/widget/container)
(import ../chalk/widget/border)
(import ../chalk/widget/list)
(import ../chalk/widget/input)
(import ../chalk/widget/checkbox)

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

  (try
    (do
      (def entries (os/dir syspath))
      (each entry (sort entries)
        (when (not (get seen entry))
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
        (def meta (if (table? v) v @{}))
        (when (and (not (string/has-prefix? "_" name-str))
                   (not (string/has-prefix? ":" name-str))
                   (not (find |(= name-str $) ["*module*" "*should-not-redef*" "native" "current-file" "source"]))
                   (or show-private (not (get meta :private))))
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
      # Measure leading whitespace for continuation indent
      (var indent-len 0)
      (while (and (< indent-len (length text))
                  (= (get text indent-len) (chr " ")))
        (++ indent-len))
      (def indent (string/repeat " " indent-len))
      (def lines @[])
      (var remaining text)
      (while (> (length remaining) max-width)
        (var break-at nil)
        (for i 0 max-width
          (when (= (get remaining i) (chr " "))
            (set break-at i)))
        (if break-at
          (do
            (array/push lines (string/slice remaining 0 break-at))
            (set remaining (string indent
                                   (string/slice remaining (+ break-at 1)))))
          (do
            (array/push lines (string/slice remaining 0 max-width))
            (set remaining (string indent
                                   (string/slice remaining max-width))))))
      (when (> (length remaining) 0)
        (array/push lines remaining))
      lines)))

(var detail-wrap-width 76)

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
          (def prefixed (string "  " line))
          (if (> (length prefixed) wrap-width)
            # Long line: word-wrap it
            (each wl (wrap-line prefixed wrap-width)
              (array/push items wl)
              (array/push styles nil))
            # Short line: output as-is (preserves developer formatting)
            (do
              (array/push items prefixed)
              (array/push styles nil)))))
      (array/push items "")
      (array/push styles nil)))
  (if (= (length items) 0)
    [@[(if ft "(no matching exports)" "(no exports)")] @[nil]]
    [items styles]))

# ================================================================
# Helper Functions
# ================================================================

(defn- truncate-item [item max-len]
  (if (> (length item) max-len)
    (string (string/slice item 0 (- max-len 3)) "...")
    item))

(defn- compute-tree-width [tree-items cols]
  (var longest 10)
  (each item tree-items
    (when (> (length item) longest)
      (set longest (length item))))
  (def max-width (math/floor (* cols 0.4)))
  (min (+ longest 4) max-width))

(defn- refresh-tree [self]
  (def state (self :state))
  (def packages (state :packages))
  (def search-text (state :search-text))
  (def exports-cache (state :exports-cache))
  (def show-private (state :show-private))
  (def [items tmap] (rebuild-tree packages search-text exports-cache show-private))
  (put state :tree-items items)
  (put state :tree-map tmap)

  # Update tree-list widget
  (def tree-list (proto/find-by-id self "tree-list"))
  (when tree-list
    (def tree-panel-width (compute-tree-width items 80))
    (def inner-width (- tree-panel-width 4))
    (def display-items (map |(truncate-item $ inner-width) items))
    (put (tree-list :state) :items display-items)
    (put (tree-list :state) :item-styles nil)
    # Clamp selection
    (def sel (get-in tree-list [:state :selected] 0))
    (when (>= sel (length items))
      (put (tree-list :state) :selected (max 0 (- (length items) 1))))))

(defn- refresh-detail [self &opt filter]
  (def state (self :state))
  (def selected-mod (state :selected-mod))
  (when (nil? selected-mod) (break))
  (def exports-cache (state :exports-cache))
  (def show-private (state :show-private))
  (def search-text (or filter (state :search-text)))
  (def [pkg-name mod-name] (string/split "/" selected-mod 0 2))
  (def exports (load-module-exports pkg-name mod-name exports-cache show-private))
  (def [di ds] (build-detail-items exports search-text))

  (def detail-list (proto/find-by-id self "detail-list"))
  (when detail-list
    (put (detail-list :state) :items di)
    (put (detail-list :state) :item-styles ds)
    (put (detail-list :state) :selected 0)
    (put (detail-list :state) :scroll-offset 0))

  # Update detail panel title
  (def detail-panel (proto/find-by-id self "detail-panel"))
  (when detail-panel
    (put (detail-panel :state) :title (string " " selected-mod " "))))

(defn- select-module [self entry]
  (def state (self :state))
  (put state :selected-mod (string (entry :pkg-name) "/" (entry :name)))
  (refresh-detail self))

(defn- update-focus-indicators [self focused-id]
  (def state (self :state))
  (def selected-mod (state :selected-mod))

  (def tree-panel (proto/find-by-id self "tree-panel"))
  (when tree-panel
    (def active (= focused-id "tree-list"))
    (put tree-panel :style (if active {:fg :cyan} {:fg :white}))
    (put (tree-panel :state) :title
         (if active " Packages (active) " " Packages ")))

  (def detail-panel (proto/find-by-id self "detail-panel"))
  (when detail-panel
    (def active (= focused-id "detail-list"))
    (put detail-panel :style (if active {:fg :cyan} {:fg :white}))
    (def base-title (if selected-mod
                      (string " " selected-mod " ")
                      " Exports "))
    (put (detail-panel :state) :title
         (if active (string base-title "(active) ") base-title)))

  (def cb (proto/find-by-id self "private-checkbox"))
  (when cb
    (put cb :style (if (= focused-id "private-checkbox")
                     {:fg :cyan}
                     {:fg :white}))))

(defn- sync-tree-selection [self]
  ```
  After filtering, sync the tree selection to the current selected-mod
  or auto-select the first module.
  ```
  (def state (self :state))
  (def selected-mod (state :selected-mod))
  (def tree-map (state :tree-map))
  (def tree-list (proto/find-by-id self "tree-list"))
  (when (nil? tree-list) (break))

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
      (put (tree-list :state) :selected found-idx)
      (refresh-detail self))
    (do
      # Auto-select first module
      (var first-mod-idx nil)
      (for i 0 (length tree-map)
        (when (and (not first-mod-idx)
                   (= ((get tree-map i) :type) :module))
          (set first-mod-idx i)))
      (if first-mod-idx
        (do
          (def entry (get tree-map first-mod-idx))
          (select-module self entry)
          (put (tree-list :state) :selected first-mod-idx))
        (do
          (put state :selected-mod nil)
          (def detail-list (proto/find-by-id self "detail-list"))
          (when detail-list
            (put (detail-list :state) :items @["No matching exports"])
            (put (detail-list :state) :item-styles @[nil])))))))

# ================================================================
# App Definition
# ================================================================

(app/defapp module-browser
            (state {:packages @[]
                    :exports-cache @{}
                    :tree-items @[]
                    :tree-map @[]
                    :selected-mod nil
                    :search-text ""
                    :show-private false})

            (css `
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

            (render [self]
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
                          (input/input-widget
                            :id "search-input"
                            :value ""
                            :placeholder "type to filter..."
                            :style {:fg :white}
                            :flex-grow 1
                            :height 1)
                          (text/text " " :width 1)
                          (checkbox/checkbox-widget
                            :id "private-checkbox"
                            :checked false
                            :label "private"
                            :checkbox-style :square
                            :style {:fg :white}
                            :height 1)
                          (text/text " esc: clear | ctrl-c: quit " :width 28)])

                      # Main area: side-by-side tree and detail panels
                      (container/container
                        :id "main"
                        :flex-direction :row
                        :flex-grow 1
                        :children
                        @[# Tree panel
                          (border/border
                            (list/list-widget
                              :id "tree-list"
                              :items @[]
                              :style {:fg :white}
                              :width 30)
                            :id "tree-panel"
                            :border-style :rounded
                            :width 32
                            :title " Packages (active) "
                            :style {:fg :cyan})

                          # Detail panel
                          (border/border
                            (list/list-widget
                              :id "detail-list"
                              :items @["Select a module to view exports"]
                              :style {:fg :white}
                              :flex-grow 1)
                            :id "detail-panel"
                            :border-style :rounded
                            :flex-grow 1
                            :title " Exports "
                            :style {:fg :white})])])

            (mount [self]
                   (def state (self :state))
                   (def packages (scan-packages))
                   (put state :packages packages)
                   (put state :exports-cache @{})
                   (refresh-tree self)
                   # Set initial focus on tree-list
                   (def fs (proto/init-focus self))
                   (def tree-list (proto/find-by-id self "tree-list"))
                   (when tree-list
                     (proto/set-focus fs tree-list))
                   (update-focus-indicators self "tree-list"))

            # --- Global key handler (fallback when focused widget doesn't consume) ---
            (on :key [self event]
                (def k (event :key))
                (cond
                  # /: jump to search input
                  (= k "/")
                  (do
                    (def fs (self :focus-state))
                    (def search-input (proto/find-by-id self "search-input"))
                    (when (and fs search-input)
                      (proto/set-focus fs search-input)
                      (update-focus-indicators self "search-input"))
                    {:redraw true})

                  # escape: clear search and return to tree
                  (= k :escape)
                  (do
                    (def state (self :state))
                    (put state :search-text "")
                    (def search-input (proto/find-by-id self "search-input"))
                    (when search-input
                      (put (search-input :state) :value "")
                      (put (search-input :state) :cursor-pos 0))
                    (refresh-tree self)
                    (refresh-detail self "")
                    (def fs (self :focus-state))
                    (def tree-list (proto/find-by-id self "tree-list"))
                    (when (and fs tree-list)
                      (proto/set-focus fs tree-list)
                      (update-focus-indicators self "tree-list"))
                    {:redraw true})))

            # --- Message handlers ---

            # Tree list cursor moved - auto-load hovered module's exports
            (on :list-changed [self msg]
                (when (= (msg :id) "tree-list")
                  (def state (self :state))
                  (def tree-map (state :tree-map))
                  (def idx (msg :index))
                  (when (< idx (length tree-map))
                    (def entry (get tree-map idx))
                    (when (= (entry :type) :module)
                      (select-module self entry)))))

            # Enter on tree: toggle package expand/collapse or select module
            (on :list-selected [self msg]
                (when (= (msg :id) "tree-list")
                  (def state (self :state))
                  (def tree-map (state :tree-map))
                  (def idx (msg :index))
                  (when (< idx (length tree-map))
                    (def entry (get tree-map idx))
                    (case (entry :type)
                      :package
                      (do
                        (def pkg (entry :pkg))
                        (put pkg :expanded (not (pkg :expanded)))
                        (refresh-tree self)
                        (refresh-detail self))

                      :module
                      (select-module self entry)))))

            # Search text changed: filter tree in real-time
            (on :input-changed [self msg]
                (when (= (msg :id) "search-input")
                  (def state (self :state))
                  (put state :search-text (msg :value))
                  (refresh-tree self)
                  (sync-tree-selection self)))

            # Enter in search: focus back to tree
            (on :input-submitted [self msg]
                (when (= (msg :id) "search-input")
                  (def fs (self :focus-state))
                  (def tree-list (proto/find-by-id self "tree-list"))
                  (when (and fs tree-list)
                    (proto/set-focus fs tree-list)
                    (update-focus-indicators self "tree-list"))))

            # Toggle show-private: invalidate cache, refresh
            (on :checkbox-changed [self msg]
                (when (= (msg :id) "private-checkbox")
                  (def state (self :state))
                  (put state :show-private (msg :checked))
                  # Invalidate exports cache
                  (def exports-cache (state :exports-cache))
                  (each ck (keys exports-cache)
                    (put exports-cache ck nil))
                  (refresh-detail self)))

            # Focus changed: update border styles and titles
            (on :focus-changed [self msg]
                (update-focus-indicators self (msg :widget-id))))

(defn main [&] (app/run module-browser))
(main)
(os/exit 0)
