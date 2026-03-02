# Tree widget
# Hierarchical tree with expand/collapse, keyboard/mouse navigation,
# and optional filtering. Nodes are plain tables with :label, :children, :data.

(import ./proto)
(import ../terminal/screen)
(import ../terminal/style)

(defn- resolve-effective-style
  "Walk up parent chain to find an inherited style, merge with own style."
  [widget]
  (var base nil)
  (var p (widget :parent))
  (while (and p (nil? base))
    (when (p :style)
      (set base (p :style)))
    (set p (p :parent)))
  (def own (widget :style))
  (cond
    (and base own) (merge base own)
    own own
    base base
    nil))

(defn- branch?
  "True if node has non-empty :children."
  [node]
  (def ch (node :children))
  (and ch (> (length ch) 0)))

(defn- node-or-descendants-match?
  "Recursively check if node or any descendant passes filter-fn."
  [node filter-fn]
  (if (filter-fn node)
    true
    (if (branch? node)
      (do
        (var found false)
        (each child (node :children)
          (when (and (not found) (node-or-descendants-match? child filter-fn))
            (set found true)))
        found)
      false)))

(defn- rebuild-flat
  "Flatten visible nodes into the :flat array on state."
  [state]
  (def nodes (state :nodes))
  (def expanded-set (state :expanded-set))
  (def filter-fn (state :filter-fn))
  (def flat @[])

  (defn walk [node-list depth]
    (each node node-list
      (def is-branch (branch? node))
      (if filter-fn
        # With filter: show node if it or any descendant matches
        (when (or (not is-branch) (node-or-descendants-match? node filter-fn))
          (if is-branch
            (do
              # Branch: auto-expand if descendants match filter
              (def force-expand (node-or-descendants-match? node filter-fn))
              (def expanded (or (get expanded-set node) force-expand))
              (array/push flat @{:node node :depth depth
                                 :is-branch true :expanded expanded})
              (when expanded
                (walk (node :children) (+ depth 1))))
            (when (filter-fn node)
              (array/push flat @{:node node :depth depth
                                 :is-branch false :expanded false}))))
        # No filter: show all nodes, respect manual expand state
        (do
          (def expanded (if is-branch (truthy? (get expanded-set node)) false))
          (array/push flat @{:node node :depth depth
                             :is-branch is-branch :expanded expanded})
          (when (and is-branch expanded)
            (walk (node :children) (+ depth 1)))))))

  (walk nodes 0)
  (put state :flat flat)

  # Clamp selection
  (def count (length flat))
  (if (= count 0)
    (put state :selected 0)
    (when (>= (state :selected) count)
      (put state :selected (- count 1)))))

(defn tree-widget
  ```Create a tree widget for hierarchical data.
   nodes: array of node tables, each with :label (string), optional :children and :data
   indent: spaces per depth level (default 4)
   expanded-prefix: prefix for expanded branches (default "v ")
   collapsed-prefix: prefix for collapsed branches (default "> ")
   leaf-prefix: prefix for leaf nodes (default "  ")
   initially-expanded: array of node refs to start expanded (default @[])
   filter-fn: (fn [node] bool) or nil for show-all
   on-select: callback (fn [index node])```
  [&named nodes indent expanded-prefix collapsed-prefix leaf-prefix
   initially-expanded filter-fn on-select
   id classes style width height flex-grow flex-shrink margin padding dock]
  (default nodes @[])
  (default indent 4)
  (default expanded-prefix "v ")
  (default collapsed-prefix "> ")
  (default leaf-prefix "  ")
  (default initially-expanded @[])

  (def w (proto/make-widget
           "tree"
           :id id
           :classes classes
           :style style
           :width width
           :height height
           :flex-grow flex-grow
           :flex-shrink flex-shrink
           :margin margin
           :padding padding
           :dock dock
           :focusable true

           :handle-event
           (fn [self event]
             (def state (self :state))
             (def flat (state :flat))
             (def count (length flat))
             (when (= count 0) (break nil))
             (def sel (state :selected))

             (case (event :type)
               :key
               (case (event :key)
                 :up
                 (do
                   (def new-sel (max 0 (- sel 1)))
                   (put state :selected new-sel)
                   (when (< new-sel (state :scroll-offset))
                     (put state :scroll-offset new-sel))
                   (def entry (get flat new-sel))
                   {:redraw true
                    :msg {:type :tree-changed :id (self :id)
                          :index new-sel :node (entry :node)}})

                 :down
                 (do
                   (def new-sel (min (- count 1) (+ sel 1)))
                   (put state :selected new-sel)
                   (def entry (get flat new-sel))
                   {:redraw true
                    :msg {:type :tree-changed :id (self :id)
                          :index new-sel :node (entry :node)}})

                 "k"
                 (do
                   (def new-sel (max 0 (- sel 1)))
                   (put state :selected new-sel)
                   (when (< new-sel (state :scroll-offset))
                     (put state :scroll-offset new-sel))
                   (def entry (get flat new-sel))
                   {:redraw true
                    :msg {:type :tree-changed :id (self :id)
                          :index new-sel :node (entry :node)}})

                 "j"
                 (do
                   (def new-sel (min (- count 1) (+ sel 1)))
                   (put state :selected new-sel)
                   (def entry (get flat new-sel))
                   {:redraw true
                    :msg {:type :tree-changed :id (self :id)
                          :index new-sel :node (entry :node)}})

                 :enter
                 (do
                   (def entry (get flat sel))
                   (if (entry :is-branch)
                     (do
                       (def node (entry :node))
                       (def expanded-set (state :expanded-set))
                       (def was-expanded (truthy? (get expanded-set node)))
                       (if was-expanded
                         (put expanded-set node nil)
                         (put expanded-set node true))
                       (rebuild-flat state)
                       {:redraw true
                        :msg {:type :tree-node-toggled :id (self :id)
                              :node node :expanded (not was-expanded)}})
                     (do
                       (when (state :on-select)
                         ((state :on-select) sel (entry :node)))
                       {:redraw true
                        :msg {:type :tree-node-selected :id (self :id)
                              :index sel :node (entry :node)}})))

                 " "
                 (do
                   (def entry (get flat sel))
                   (if (entry :is-branch)
                     (do
                       (def node (entry :node))
                       (def expanded-set (state :expanded-set))
                       (def was-expanded (truthy? (get expanded-set node)))
                       (if was-expanded
                         (put expanded-set node nil)
                         (put expanded-set node true))
                       (rebuild-flat state)
                       {:redraw true
                        :msg {:type :tree-node-toggled :id (self :id)
                              :node node :expanded (not was-expanded)}})
                     (do
                       (when (state :on-select)
                         ((state :on-select) sel (entry :node)))
                       {:redraw true
                        :msg {:type :tree-node-selected :id (self :id)
                              :index sel :node (entry :node)}}))))

               :mouse
               (let [action (event :action)
                     button (event :button)]
                 (cond
                   # Click to select/toggle
                   (and (= action :press) (= button 0))
                   (when-let [node (self :layout-node)
                              rect (node :rect)]
                     (def item-idx (+ (state :scroll-offset)
                                      (- (event :row) (rect :row))))
                     (when (and (>= item-idx 0) (< item-idx count))
                       (put state :selected item-idx)
                       (def entry (get flat item-idx))
                       (if (entry :is-branch)
                         (do
                           (def tnode (entry :node))
                           (def expanded-set (state :expanded-set))
                           (def was-expanded (truthy? (get expanded-set tnode)))
                           (if was-expanded
                             (put expanded-set tnode nil)
                             (put expanded-set tnode true))
                           (rebuild-flat state)
                           {:redraw true
                            :msg {:type :tree-node-toggled :id (self :id)
                                  :node tnode :expanded (not was-expanded)}})
                         (do
                           (when (state :on-select)
                             ((state :on-select) item-idx (entry :node)))
                           {:redraw true
                            :msg {:type :tree-node-selected :id (self :id)
                                  :index item-idx :node (entry :node)}}))))

                   # Scroll wheel
                   (= action :scroll)
                   (let [new-sel (if (= button 0)
                                   (max 0 (- sel 1))
                                   (min (- count 1) (+ sel 1)))]
                     (put state :selected new-sel)
                     (when (< new-sel (state :scroll-offset))
                       (put state :scroll-offset new-sel))
                     (def entry (get flat new-sel))
                     {:redraw true
                      :msg {:type :tree-changed :id (self :id)
                            :index new-sel :node (entry :node)}})))))

           :paint
           (fn [self scr rect]
             (def state (self :state))
             (def flat (state :flat))
             (def sel (state :selected))
             (def visible-h (rect :height))
             (def indent-size (state :indent))
             (def exp-prefix (state :expanded-prefix))
             (def col-prefix (state :collapsed-prefix))
             (def lf-prefix (state :leaf-prefix))

             # Adjust scroll offset
             (var offset (or (state :scroll-offset) 0))
             (when (>= sel (+ offset visible-h))
               (set offset (- sel visible-h -1)))
             (when (< sel offset)
               (set offset sel))
             (put state :scroll-offset offset)

             (def effective (resolve-effective-style self))
             (def normal-style
               (when effective (style/make-style ;(kvs effective))))
             (def sel-style (style/make-style :reverse true
                                              :fg (when effective
                                                    (get effective :fg))
                                              :bg (when effective
                                                    (get effective :bg))))

             (for i 0 visible-h
               (def item-idx (+ offset i))
               (def row (+ (rect :row) i))
               (if (< item-idx (length flat))
                 (do
                   (def entry (get flat item-idx))
                   (def node (entry :node))
                   (def depth (entry :depth))
                   (def prefix
                     (if (entry :is-branch)
                       (if (entry :expanded) exp-prefix col-prefix)
                       lf-prefix))
                   (def indent-str (string/repeat " " (* depth indent-size)))
                   (def label (or (node :label) ""))
                   (def display (string indent-str prefix label))
                   (def s (if (= item-idx sel) sel-style normal-style))
                   # Clear the line
                   (for c (rect :col) (+ (rect :col) (rect :width))
                     (screen/screen-put scr c row " " s))
                   # Draw display text, clipped
                   (def clipped (if (> (length display) (rect :width))
                                  (string/slice display 0 (rect :width))
                                  display))
                   (screen/screen-put-string scr (rect :col) row
                                             (string " " clipped) s))
                 # Clear empty rows below items
                 (for c (rect :col) (+ (rect :col) (rect :width))
                   (screen/screen-put scr c row " " normal-style)))))))

  # Initialize state
  (def expanded-set @{})
  (each node initially-expanded
    (put expanded-set node true))

  (put (w :state) :nodes nodes)
  (put (w :state) :expanded-set expanded-set)
  (put (w :state) :filter-fn filter-fn)
  (put (w :state) :flat @[])
  (put (w :state) :selected 0)
  (put (w :state) :scroll-offset 0)
  (put (w :state) :indent indent)
  (put (w :state) :expanded-prefix expanded-prefix)
  (put (w :state) :collapsed-prefix collapsed-prefix)
  (put (w :state) :leaf-prefix leaf-prefix)
  (put (w :state) :on-select on-select)

  # Build initial flat list
  (rebuild-flat (w :state))

  w)

# --- Public Mutation API ---

(defn tree-set-nodes
  "Replace all nodes and reset selection."
  [widget nodes]
  (def state (widget :state))
  (put state :nodes nodes)
  (put state :expanded-set @{})
  (put state :selected 0)
  (put state :scroll-offset 0)
  (rebuild-flat state))

(defn tree-set-filter
  "Set or clear the filter function. nil = show all."
  [widget filter-fn]
  (def state (widget :state))
  (put state :filter-fn filter-fn)
  (rebuild-flat state))

(defn tree-expand-node
  "Expand a specific node."
  [widget node]
  (def state (widget :state))
  (put (state :expanded-set) node true)
  (rebuild-flat state))

(defn tree-collapse-node
  "Collapse a specific node."
  [widget node]
  (def state (widget :state))
  (put (state :expanded-set) node nil)
  (rebuild-flat state))

(defn tree-selected-node
  "Get the currently selected node, or nil if empty."
  [widget]
  (def state (widget :state))
  (def flat (state :flat))
  (def sel (state :selected))
  (when (and (> (length flat) 0) (< sel (length flat)))
    ((get flat sel) :node)))

(defn tree-select-node
  "Select a node by reference. Returns true if found."
  [widget node]
  (def state (widget :state))
  (def flat (state :flat))
  (var found false)
  (for i 0 (length flat)
    (when (and (not found) (= ((get flat i) :node) node))
      (put state :selected i)
      (set found true)))
  found)
