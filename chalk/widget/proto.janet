# Layer 7: Widget protocol and tree utilities
# A widget is a mutable table with well-known keys for type, state,
# lifecycle hooks, layout node, children, and parent.

(import ../layout/box)

(defn make-widget
  "Create a widget table. Layout-related named args are forwarded to layout node creation."
  [type &named id classes style width height min-width max-width min-height max-height
   margin margin-top margin-right margin-bottom margin-left
   padding padding-top padding-right padding-bottom padding-left
   flex-direction flex-grow flex-shrink dock focusable
   border-style border-color border-title border-title-align
   border-color-focused border-title-focused
   style-focused
   mount unmount render paint handle-event update]
  @{:type type
    :id id
    :classes (or classes @[])
    :state @{}
    :style style
    :style-focused style-focused
    :layout-node nil
    :children @[]
    :parent nil
    :mounted false
    :focusable focusable
    # Layout props stored for build-layout-tree
    :width (or width :auto)
    :height (or height :auto)
    :min-width min-width
    :max-width max-width
    :min-height min-height
    :max-height max-height
    :margin margin
    :margin-top margin-top
    :margin-right margin-right
    :margin-bottom margin-bottom
    :margin-left margin-left
    :padding padding
    :padding-top padding-top
    :padding-right padding-right
    :padding-bottom padding-bottom
    :padding-left padding-left
    :flex-direction flex-direction
    :flex-grow flex-grow
    :flex-shrink flex-shrink
    :dock dock
    # Border properties
    :border-style border-style
    :border-color border-color
    :border-title border-title
    :border-title-align border-title-align
    :border-color-focused border-color-focused
    :border-title-focused border-title-focused
    # Lifecycle hooks
    :mount mount
    :unmount unmount
    :render render
    :paint paint
    :handle-event handle-event
    :update update})

(defn widget-add-child
  "Add a child widget to a parent."
  [parent child]
  (put child :parent parent)
  (array/push (parent :children) child)
  child)

(defn widget-remove-child
  "Remove a child widget from its parent."
  [parent child]
  (def children (parent :children))
  (def idx (find-index |(= $ child) children))
  (when idx
    (array/remove children idx)
    (put child :parent nil))
  child)

(defn build-layout-tree
  "Create a layout node tree from a widget tree. Attaches :layout-node to each widget."
  [widget]
  (def node (box/make-node
              (widget :type)
              :width (widget :width)
              :height (widget :height)
              :min-width (widget :min-width)
              :max-width (widget :max-width)
              :min-height (widget :min-height)
              :max-height (widget :max-height)
              :margin (widget :margin)
              :margin-top (widget :margin-top)
              :margin-right (widget :margin-right)
              :margin-bottom (widget :margin-bottom)
              :margin-left (widget :margin-left)
              :padding (widget :padding)
              :padding-top (widget :padding-top)
              :padding-right (widget :padding-right)
              :padding-bottom (widget :padding-bottom)
              :padding-left (widget :padding-left)
              :flex-direction (widget :flex-direction)
              :flex-grow (widget :flex-grow)
              :flex-shrink (widget :flex-shrink)
              :dock (widget :dock)))
  # Reserve space for border by adding 1 to each padding side
  (when (widget :border-style)
    (put node :padding-top (+ (node :padding-top) 1))
    (put node :padding-right (+ (node :padding-right) 1))
    (put node :padding-bottom (+ (node :padding-bottom) 1))
    (put node :padding-left (+ (node :padding-left) 1)))
  (put widget :layout-node node)
  (each child (widget :children)
    (def child-node (build-layout-tree child))
    (array/push (node :children) child-node))
  node)

(defn mount-tree
  "Recursively mount a widget tree (call :mount hooks depth-first, children first)."
  [widget]
  (each child (widget :children)
    (mount-tree child))
  (when (and (widget :mount) (not (widget :mounted)))
    ((widget :mount) widget))
  (put widget :mounted true))

(defn unmount-tree
  "Recursively unmount a widget tree (children first)."
  [widget]
  (each child (widget :children)
    (unmount-tree child))
  (when (and (widget :unmount) (widget :mounted))
    ((widget :unmount) widget))
  (put widget :mounted false))

(defn in-rect?
  "Test if (col, row) is inside a rect (1-based)."
  [rect col row]
  (and (>= col (rect :col))
       (< col (+ (rect :col) (rect :width)))
       (>= row (rect :row))
       (< row (+ (rect :row) (rect :height)))))

(defn find-by-id
  "Find a widget by :id in the tree (depth-first)."
  [root id]
  (if (= (root :id) id)
    root
    (do
      (var found nil)
      (each child (root :children)
        (when (not found)
          (set found (find-by-id child id))))
      found)))

# --- Focus system ---

(defn build-focus-ring
  "Depth-first walk, collect widgets with :focusable truthy. Returns flat array."
  [root]
  (def ring @[])
  (defn walk [w]
    (when (w :focusable) (array/push ring w))
    (each child (w :children) (walk child)))
  (walk root)
  ring)

(defn init-focus
  "Build focus ring and attach focus-state to root. Called lazily on first key event."
  [root]
  (def ring (build-focus-ring root))
  (def fs @{:ring ring :index 0 :root root})
  (put root :focus-state fs)
  fs)

(defn focused-widget
  "Return the currently focused widget, or nil if ring is empty."
  [focus-state]
  (def ring (focus-state :ring))
  (if (= (length ring) 0)
    nil
    (get ring (focus-state :index))))

(defn focus-next
  "Cycle focus forward, wrapping around."
  [focus-state]
  (def ring (focus-state :ring))
  (when (> (length ring) 0)
    (put focus-state :index (% (+ (focus-state :index) 1) (length ring)))))

(defn focus-prev
  "Cycle focus backward, wrapping around."
  [focus-state]
  (def ring (focus-state :ring))
  (when (> (length ring) 0)
    (put focus-state :index (% (+ (focus-state :index) (- (length ring) 1)) (length ring)))))

(defn set-focus
  "Focus a specific widget by reference. Returns true if found in ring."
  [focus-state widget]
  (def ring (focus-state :ring))
  (var found false)
  (for i 0 (length ring)
    (when (and (not found) (= (get ring i) widget))
      (put focus-state :index i)
      (set found true)))
  found)

(defn refresh-focus-ring
  "Rebuild ring after tree mutation. Preserve focus if widget still present."
  [focus-state]
  (def old-focused (focused-widget focus-state))
  (def root (focus-state :root))
  (def ring (build-focus-ring root))
  (put focus-state :ring ring)
  (if (and old-focused (find |(= $ old-focused) ring))
    (set-focus focus-state old-focused)
    (put focus-state :index 0)))

(defn widget-focused?
  "Check if a widget is the currently focused widget."
  [widget]
  (var root widget)
  (while (root :parent)
    (set root (root :parent)))
  (when-let [fs (root :focus-state)]
    (= widget (focused-widget fs))))

(defn resolve-effective-style
  ```Walk up parent chain to find an inherited style, merge with own style.
  If the widget is focused and has :style-focused, merges that on top.
  Returns a merged style table (not a compiled style) or nil.```
  [widget]
  (var base nil)
  (var parent (widget :parent))
  (while (and parent (nil? base))
    (when (parent :style)
      (set base (parent :style)))
    (set parent (parent :parent)))
  (def own (widget :style))
  (def focused-override
    (when (and (widget :style-focused) (widget-focused? widget))
      (widget :style-focused)))
  (def merged
    (cond
      (and base own focused-override) (merge base own focused-override)
      (and base own) (merge base own)
      (and base focused-override) (merge base focused-override)
      (and own focused-override) (merge own focused-override)
      focused-override focused-override
      own own
      base base
      nil))
  merged)

(defn- bubble-msg
  "Bubble a message from target up through ancestors' :update hooks."
  [target msg]
  (var w (target :parent))
  (while w
    (when (w :update)
      ((w :update) w msg))
    (set w (w :parent))))

(defn dispatch-event
  ```Deliver an event to the widget tree.
   Mouse events hit-test rects (deepest match wins).
   Key events route to focused widget (with root fallback).
   Handlers return {:msg m} to bubble to parent's :update.```
  [root event]
  (var target nil)
  (var result nil)

  (case (event :type)
    :mouse
    (do
      # Find deepest widget whose rect contains the mouse position
      (defn find-target [widget]
        (when-let [node (widget :layout-node)
                   rect (node :rect)]
          (when (in-rect? rect (event :col) (event :row))
            (set target widget)
            (each child (widget :children)
              (find-target child)))))
      (find-target root)
      # Focus clicked widget (or nearest focusable ancestor) on press
      (when (and target (= (event :action) :press))
        (def fs (or (root :focus-state) (init-focus root)))
        (var fw target)
        (while (and fw (not (fw :focusable)))
          (set fw (fw :parent)))
        (when (and fw (not= fw (focused-widget fs)))
          (set-focus fs fw)
          (set result @{:redraw true
                        :msg {:type :focus-changed
                              :widget-id (fw :id)}})))
      # Save focus-changed msg before handler may produce its own msg
      (def focus-msg (when result (get result :msg)))
      (when (and target (target :handle-event))
        (def handler-result ((target :handle-event) target event))
        (when handler-result
          (set result (or result @{}))
          (when (handler-result :redraw) (put result :redraw true))
          (when (handler-result :msg) (put result :msg (handler-result :msg)))))
      # Bubble focus-changed separately if handler overwrote it
      (when (and focus-msg target
                 (not= focus-msg (get result :msg)))
        (bubble-msg target focus-msg)))

    :key
    (do
      # Lazy-init focus on first key event
      (def fs (or (root :focus-state) (init-focus root)))
      (def focused (focused-widget fs))
      (def k (event :key))

      (cond
        # Tab: offer to focused widget first, cycle if not consumed
        (= k :tab)
        (do
          (var consumed nil)
          (when (and focused (focused :handle-event))
            (set consumed ((focused :handle-event) focused event)))
          (if consumed
            (do (set target focused) (set result consumed))
            (do
              (focus-next fs)
              (def new-focused (focused-widget fs))
              (set target new-focused)
              (set result {:redraw true
                           :msg {:type :focus-changed
                                 :widget-id (when new-focused (new-focused :id))}}))))

        # Shift-Tab: same but backwards
        (= k :shift-tab)
        (do
          (var consumed nil)
          (when (and focused (focused :handle-event))
            (set consumed ((focused :handle-event) focused event)))
          (if consumed
            (do (set target focused) (set result consumed))
            (do
              (focus-prev fs)
              (def new-focused (focused-widget fs))
              (set target new-focused)
              (set result {:redraw true
                           :msg {:type :focus-changed
                                 :widget-id (when new-focused (new-focused :id))}}))))

        # Other keys: route to focused widget, fallback to root
        (do
          (when (and focused (focused :handle-event))
            (set target focused)
            (set result ((focused :handle-event) focused event)))
          # Fallback to root if focused widget didn't consume and is not root
          (when (and (nil? result) focused (not= focused root) (root :handle-event))
            (set target root)
            (set result ((root :handle-event) root event)))
          # No focusable widgets: keys go to root
          (when (and (nil? focused) (root :handle-event))
            (set target root)
            (set result ((root :handle-event) root event))))))

    :resize
    (when (root :handle-event)
      (set target root)
      (set result ((root :handle-event) root event))))

  # Bubble messages up to parent's :update
  (when (and result (get result :msg) target)
    (bubble-msg target (result :msg)))

  result)
