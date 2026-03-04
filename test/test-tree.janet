# Tests for chalk/widget/tree.janet - tree widget

(import ../chalk/widget/proto)
(import ../chalk/widget/tree)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- Helper: build a sample tree ---

(defn make-tree []
  (def leaf-a @{:label "leaf-a" :data {:id "a"}})
  (def leaf-b @{:label "leaf-b" :data {:id "b"}})
  (def leaf-c @{:label "leaf-c" :data {:id "c"}})
  (def branch-1 @{:label "branch-1" :children @[leaf-a leaf-b]
                  :data {:id "b1"}})
  (def branch-2 @{:label "branch-2" :children @[leaf-c]
                  :data {:id "b2"}})
  @{:nodes @[branch-1 branch-2]
    :branch-1 branch-1
    :branch-2 branch-2
    :leaf-a leaf-a
    :leaf-b leaf-b
    :leaf-c leaf-c})

# --- 1. Flat entry creation from simple tree (collapsed) ---

(check "collapsed roots produce one entry per root"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes))]
         (def flat (get-in w [:state :flat]))
         (= 2 (length flat))))

# --- 2. Expand/collapse changes flat list length ---

(check "expanding a branch adds its children to flat list"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes))]
         (tree/tree-expand-node w (t :branch-1))
         (def flat (get-in w [:state :flat]))
         # branch-1, leaf-a, leaf-b, branch-2
         (= 4 (length flat))))

(check "collapsing a branch removes its children from flat list"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes)
                                 :initially-expanded @[(t :branch-1)])]
         # Starts expanded: branch-1, leaf-a, leaf-b, branch-2 = 4
         (tree/tree-collapse-node w (t :branch-1))
         (def flat (get-in w [:state :flat]))
         (= 2 (length flat))))

# --- 3. Leaf vs branch classification ---

(check "branch and leaf entries classified correctly"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes)
                                 :initially-expanded @[(t :branch-1)])]
         (def flat (get-in w [:state :flat]))
         (and ((get flat 0) :is-branch) # branch-1
              (not ((get flat 1) :is-branch)) # leaf-a
              (not ((get flat 2) :is-branch)) # leaf-b
              ((get flat 3) :is-branch)))) # branch-2

# --- 4. Keyboard navigation emits :tree-changed ---

(check "keyboard down emits :tree-changed"
       (let [t (make-tree)
             msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             w (tree/tree-widget :id "tw" :nodes (t :nodes))
             _ (proto/widget-add-child root w)
             _ (proto/init-focus root)]
         (proto/dispatch-event root {:type :key :key :down})
         (and (= 1 (length msgs))
              (= :tree-changed ((get msgs 0) :type))
              (= 1 ((get msgs 0) :index)))))

(check "keyboard up emits :tree-changed"
       (let [t (make-tree)
             msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             w (tree/tree-widget :id "tw" :nodes (t :nodes))
             _ (proto/widget-add-child root w)
             _ (proto/init-focus root)]
         # Move down then up
         (proto/dispatch-event root {:type :key :key :down})
         (proto/dispatch-event root {:type :key :key :up})
         (and (= 2 (length msgs))
              (= :tree-changed ((get msgs 1) :type))
              (= 0 ((get msgs 1) :index)))))

# --- 5. Enter on branch emits :tree-node-toggled and rebuilds flat ---

(check "enter on branch emits :tree-node-toggled and expands"
       (let [t (make-tree)
             msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             w (tree/tree-widget :id "tw" :nodes (t :nodes))
             _ (proto/widget-add-child root w)
             _ (proto/init-focus root)]
         # Enter on branch-1 (selected=0)
         (proto/dispatch-event root {:type :key :key :enter})
         (def flat (get-in w [:state :flat]))
         (and (= 1 (length msgs))
              (= :tree-node-toggled ((get msgs 0) :type))
              (= true ((get msgs 0) :expanded))
              (= (t :branch-1) ((get msgs 0) :node))
              # Now flat = branch-1, leaf-a, leaf-b, branch-2
              (= 4 (length flat)))))

# --- 6. Enter on leaf emits :tree-node-selected ---

(check "enter on leaf emits :tree-node-selected"
       (let [t (make-tree)
             msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             w (tree/tree-widget :id "tw" :nodes (t :nodes)
                                 :initially-expanded @[(t :branch-1)])
             _ (proto/widget-add-child root w)
             _ (proto/init-focus root)]
         # Move to leaf-a (index 1)
         (proto/dispatch-event root {:type :key :key :down})
         # Enter on leaf
         (proto/dispatch-event root {:type :key :key :enter})
         (and (>= (length msgs) 2)
              (= :tree-node-selected ((get msgs 1) :type))
              (= (t :leaf-a) ((get msgs 1) :node))
              (= 1 ((get msgs 1) :index)))))

# --- 7. Mouse click on branch toggles ---

(check "mouse click on branch toggles expand/collapse"
       (let [t (make-tree)
             msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             w (tree/tree-widget :id "tw" :nodes (t :nodes))
             _ (proto/widget-add-child root w)
             _ (proto/build-layout-tree root)]
         (put (root :layout-node) :rect {:row 1 :col 1 :width 30 :height 10})
         (put (w :layout-node) :rect {:row 1 :col 1 :width 30 :height 10})
         # Click on row 1 = branch-1 (item-idx = 0 + (1 - 1) = 0)
         (proto/dispatch-event root {:type :mouse :button 0 :col 5 :row 1 :action :press})
         (and (= 1 (length msgs))
              (= :tree-node-toggled ((get msgs 0) :type))
              (= true ((get msgs 0) :expanded)))))

# --- 8. Mouse click on leaf selects ---

(check "mouse click on leaf emits :tree-node-selected"
       (let [t (make-tree)
             msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             w (tree/tree-widget :id "tw" :nodes (t :nodes)
                                 :initially-expanded @[(t :branch-1)])
             _ (proto/widget-add-child root w)
             _ (proto/build-layout-tree root)]
         (put (root :layout-node) :rect {:row 1 :col 1 :width 30 :height 10})
         (put (w :layout-node) :rect {:row 1 :col 1 :width 30 :height 10})
         # Click on row 2 = leaf-a (item-idx = 0 + (2 - 1) = 1)
         (proto/dispatch-event root {:type :mouse :button 0 :col 5 :row 2 :action :press})
         (and (= 1 (length msgs))
              (= :tree-node-selected ((get msgs 0) :type))
              (= (t :leaf-a) ((get msgs 0) :node)))))

# --- 9. Scroll wheel navigates ---

(check "scroll wheel moves selection"
       (let [t (make-tree)
             msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             w (tree/tree-widget :id "tw" :nodes (t :nodes))
             _ (proto/widget-add-child root w)
             _ (proto/build-layout-tree root)]
         (put (root :layout-node) :rect {:row 1 :col 1 :width 30 :height 10})
         (put (w :layout-node) :rect {:row 1 :col 1 :width 30 :height 10})
         # Scroll down (button 1) -> selected 0 -> 1
         (proto/dispatch-event root {:type :mouse :button 1 :col 5 :row 2 :action :scroll})
         (def after-down (get-in w [:state :selected]))
         # Scroll up (button 0) -> selected 1 -> 0
         (proto/dispatch-event root {:type :mouse :button 0 :col 5 :row 2 :action :scroll})
         (def after-up (get-in w [:state :selected]))
         (and (= 1 after-down)
              (= 0 after-up)
              (= 2 (length msgs)))))

# --- 10. Filter function hides non-matching leaves ---

(check "filter hides non-matching leaves"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes)
                                 :initially-expanded @[(t :branch-1) (t :branch-2)])]
         # Without filter: branch-1, leaf-a, leaf-b, branch-2, leaf-c = 5
         (def before (length (get-in w [:state :flat])))
         # Filter: only leaf nodes whose label is exactly "leaf-a"
         (tree/tree-set-filter w (fn [node] (= "leaf-a" (node :label))))
         (def flat (get-in w [:state :flat]))
         # branch-1 has leaf-a matching, so branch-1 + leaf-a = 2
         # branch-2 has no matching leaves, hidden
         (and (= 5 before)
              (= 2 (length flat)))))

# --- 11. Filter auto-expands branches with matching descendants ---

(check "filter auto-expands branches with matching descendants"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes))]
         # All collapsed initially, 2 entries
         (def before (length (get-in w [:state :flat])))
         # Filter: match leaf-c
         (tree/tree-set-filter w (fn [node] (= (node :label) "leaf-c")))
         (def flat (get-in w [:state :flat]))
         # branch-2 auto-expanded, showing leaf-c: 2 entries
         (and (= 2 before)
              (= 2 (length flat))
              ((get flat 0) :expanded)
              (= "branch-2" (get-in flat [0 :node :label]))
              (= "leaf-c" (get-in flat [1 :node :label])))))

# --- 12. Clear filter restores original expand state ---

(check "clearing filter restores original expand state"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes))]
         # All collapsed: 2 entries
         (tree/tree-set-filter w (fn [node] (= (node :label) "leaf-a")))
         # Filter active: branch-1 auto-expanded + leaf-a = 2
         (tree/tree-set-filter w nil)
         # After clearing: should go back to collapsed (2 entries)
         # branch-1 was NOT manually expanded, auto-expand is temporary
         (def flat (get-in w [:state :flat]))
         (= 2 (length flat))))

# --- 13. tree-set-nodes replaces data and resets selection ---

(check "tree-set-nodes replaces data and resets selection"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes))
             _ (put (w :state) :selected 1)]
         (def new-node @{:label "new-root" :children @[]})
         (tree/tree-set-nodes w @[new-node])
         (def flat (get-in w [:state :flat]))
         (and (= 1 (length flat))
              (= 0 (get-in w [:state :selected]))
              (= "new-root" (get-in flat [0 :node :label])))))

# --- 14. tree-select-node moves cursor to target ---

(check "tree-select-node moves cursor to target node"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes)
                                 :initially-expanded @[(t :branch-1)])]
         # flat: branch-1(0), leaf-a(1), leaf-b(2), branch-2(3)
         (tree/tree-select-node w (t :leaf-b))
         (= 2 (get-in w [:state :selected]))))

# --- 15. tree-selected-node returns correct node ---

(check "tree-selected-node returns correct node"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes)
                                 :initially-expanded @[(t :branch-1)])]
         (put (w :state) :selected 1)
         (= (t :leaf-a) (tree/tree-selected-node w))))

# --- 16. Deep nesting produces correct depths ---

(check "deep nesting produces correct depths"
       (let [deep-leaf @{:label "deep"}
             mid @{:label "mid" :children @[deep-leaf]}
             top @{:label "top" :children @[mid]}
             w (tree/tree-widget :nodes @[top]
                                 :initially-expanded @[top mid])]
         (def flat (get-in w [:state :flat]))
         (and (= 3 (length flat))
              (= 0 ((get flat 0) :depth))
              (= 1 ((get flat 1) :depth))
              (= 2 ((get flat 2) :depth)))))

# --- 17. Empty nodes array handles gracefully ---

(check "empty nodes array produces empty flat list"
       (let [w (tree/tree-widget :nodes @[])]
         (def flat (get-in w [:state :flat]))
         (and (= 0 (length flat))
              (= 0 (get-in w [:state :selected])))))

# --- 18. Selection clamping after collapse ---

(check "selection clamped after collapse reduces item count"
       (let [t (make-tree)
             w (tree/tree-widget :nodes (t :nodes)
                                 :initially-expanded @[(t :branch-1)])]
         # flat: branch-1(0), leaf-a(1), leaf-b(2), branch-2(3)
         (put (w :state) :selected 3) # select branch-2
         (tree/tree-collapse-node w (t :branch-1))
         # flat: branch-1(0), branch-2(1) -> selected clamped to 1
         (and (= 2 (length (get-in w [:state :flat])))
              (= 1 (get-in w [:state :selected])))))

# --- 19. Auto-expand sets width based on content ---

(check "auto-expand sets width based on content"
       (let [leaf-a @{:label "short" :data {:id "a"}}
             leaf-b @{:label "a-longer-label-here" :data {:id "b"}}
             branch @{:label "root" :children @[leaf-a leaf-b] :data {:id "r"}}
             w (tree/tree-widget :nodes @[branch] :width 10
                                 :auto-expand true
                                 :initially-expanded @[branch])]
         # Content: "root" with "> " prefix = 6 chars at depth 0
         #          "short" with "  " prefix = 7 + indent at depth 1
         #          "a-longer-label-here" with "  " prefix = 21 + indent at depth 1
         # Longest is 21 + 4 (default indent) = 25, desired = 25 + 2 = 27
         (and (> (w :width) 10)
              (= (w :width) 27))))

# --- 20. Auto-expand respects max-width ---

(check "auto-expand respects max-width"
       (let [leaf @{:label "a-very-long-label-that-exceeds-max" :data {:id "a"}}
             branch @{:label "root" :children @[leaf] :data {:id "r"}}
             w (tree/tree-widget :nodes @[branch] :width 10
                                 :auto-expand true :max-width 20
                                 :initially-expanded @[branch])]
         (<= (w :width) 20)))

# --- 21. Auto-expand does not go below initial width ---

(check "auto-expand does not shrink below initial width"
       (let [leaf @{:label "x" :data {:id "a"}}
             w (tree/tree-widget :nodes @[leaf] :width 30
                                 :auto-expand true)]
         # "x" with "  " prefix = 3 chars, desired = 5. But min-width is 30.
         (= (w :width) 30)))

# --- 22. Auto-expand updates on expand/collapse ---

(check "auto-expand updates width on expand"
       (let [leaf @{:label "a-long-child-name" :data {:id "a"}}
             branch @{:label "b" :children @[leaf] :data {:id "r"}}
             w (tree/tree-widget :nodes @[branch] :width 10
                                 :auto-expand true)]
         (def before (w :width))
         (tree/tree-expand-node w branch)
         (def after (w :width))
         # After expanding, width should grow to fit the child
         (> after before)))

# --- 23. tree-content-width returns correct value ---

(check "tree-content-width returns correct value"
       (let [leaf @{:label "hello" :data {:id "a"}}
             w (tree/tree-widget :nodes @[leaf])]
         # "hello" with leaf prefix "  " = 7 chars at depth 0
         (= 7 (tree/tree-content-width w))))

# --- 24. Auto-expand propagates width delta to fixed-width ancestors ---

(check "auto-expand propagates width delta to parent"
       (let [leaf @{:label "a-long-child-name" :data {:id "a"}}
             branch @{:label "b" :children @[leaf] :data {:id "r"}}
             w (tree/tree-widget :nodes @[branch] :width 10
                                 :auto-expand true)
             parent (proto/make-widget "border" :width 12)]
         (proto/widget-add-child parent w)
         # Expand: tree grows, parent should grow by the same delta
         (def parent-before (parent :width))
         (tree/tree-expand-node w branch)
         (def parent-after (parent :width))
         (def tree-delta (- (w :width) 10))
         (= parent-after (+ parent-before tree-delta))))

(printf "  %d tests passed" pass)
