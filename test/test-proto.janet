# Tests for chalk/widget/proto.janet - focus system, dispatch, and message bubbling

(import ../chalk/widget/proto)
(import ../chalk/widget/list)
(import ../chalk/widget/input)
(import ../chalk/widget/checkbox)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- build-focus-ring ---

(check "build-focus-ring returns only focusable widgets in document order"
       (let [root (proto/make-widget "root")
             a (proto/make-widget "a" :focusable true)
             b (proto/make-widget "b")
             c (proto/make-widget "c" :focusable true)
             _ (proto/widget-add-child root a)
             _ (proto/widget-add-child root b)
             _ (proto/widget-add-child root c)
             ring (proto/build-focus-ring root)]
         (and (= 2 (length ring))
              (= a (get ring 0))
              (= c (get ring 1)))))

(check "build-focus-ring with no focusable widgets returns empty array"
       (let [root (proto/make-widget "root")
             a (proto/make-widget "a")
             _ (proto/widget-add-child root a)
             ring (proto/build-focus-ring root)]
         (= 0 (length ring))))

# --- init-focus ---

(check "init-focus sets up focus-state on root"
       (let [root (proto/make-widget "root")
             a (proto/make-widget "a" :focusable true)
             _ (proto/widget-add-child root a)
             fs (proto/init-focus root)]
         (and (not (nil? fs))
              (= fs (root :focus-state))
              (= 0 (fs :index))
              (= 1 (length (fs :ring))))))

# --- focus-next / focus-prev ---

(check "focus-next and focus-prev wrap around"
       (let [root (proto/make-widget "root")
             a (proto/make-widget "a" :focusable true :id "a")
             b (proto/make-widget "b" :focusable true :id "b")
             c (proto/make-widget "c" :focusable true :id "c")
             _ (proto/widget-add-child root a)
             _ (proto/widget-add-child root b)
             _ (proto/widget-add-child root c)
             fs (proto/init-focus root)]
         # Start at 0 (a)
         (and (= a (proto/focused-widget fs))
              # Next -> b
              (do (proto/focus-next fs) (= b (proto/focused-widget fs)))
              # Next -> c
              (do (proto/focus-next fs) (= c (proto/focused-widget fs)))
              # Next wraps -> a
              (do (proto/focus-next fs) (= a (proto/focused-widget fs)))
              # Prev wraps -> c
              (do (proto/focus-prev fs) (= c (proto/focused-widget fs)))
              # Prev -> b
              (do (proto/focus-prev fs) (= b (proto/focused-widget fs))))))

# --- set-focus ---

(check "set-focus finds correct widget by reference"
       (let [root (proto/make-widget "root")
             a (proto/make-widget "a" :focusable true :id "a")
             b (proto/make-widget "b" :focusable true :id "b")
             _ (proto/widget-add-child root a)
             _ (proto/widget-add-child root b)
             fs (proto/init-focus root)]
         (and (= a (proto/focused-widget fs))
              (proto/set-focus fs b)
              (= b (proto/focused-widget fs)))))

# --- dispatch-event key routing ---

(check "dispatch-event routes key to focused widget"
       (let [root (proto/make-widget "root")
             received @{:hit false}
             a (proto/make-widget "a" :focusable true
                                  :handle-event (fn [self event]
                                                  (put received :hit true)
                                                  {:redraw true}))
             b (proto/make-widget "b" :focusable true)
             _ (proto/widget-add-child root a)
             _ (proto/widget-add-child root b)
             result (proto/dispatch-event root {:type :key :key "x"})]
         (and (received :hit) result)))

(check "dispatch-event with empty ring routes key to root"
       (let [received @{:hit false}
             root (proto/make-widget "root"
                                     :handle-event (fn [self event]
                                                     (put received :hit true)
                                                     {:redraw true}))
             a (proto/make-widget "a") # not focusable
             _ (proto/widget-add-child root a)
             result (proto/dispatch-event root {:type :key :key "x"})]
         (and (received :hit) result)))

(check "dispatch-event Tab cycles focus when widget doesn't consume it"
       (let [root (proto/make-widget "root")
             a (proto/make-widget "a" :focusable true :id "a")
             b (proto/make-widget "b" :focusable true :id "b")
             _ (proto/widget-add-child root a)
             _ (proto/widget-add-child root b)
             _ (proto/init-focus root)
             fs (root :focus-state)]
         # Start at a
         (and (= a (proto/focused-widget fs))
              # Tab -> cycles to b
              (do (proto/dispatch-event root {:type :key :key :tab})
                (= b (proto/focused-widget fs))))))

# --- Key fallback ---

(check "key fallback: focused widget returns nil, root handle-event fires"
       (let [root-hit @{:hit false}
             root (proto/make-widget "root"
                                     :handle-event (fn [self event]
                                                     (put root-hit :hit true)
                                                     {:redraw true}))
             a (proto/make-widget "a" :focusable true
                                  :handle-event (fn [self event] nil)) # doesn't consume
             _ (proto/widget-add-child root a)
             result (proto/dispatch-event root {:type :key :key "/"})]
         (and (root-hit :hit) result)))

# --- Message bubbling ---

(check "message bubbling: widget msg reaches parent update"
       (let [received @{:msg nil}
             root (proto/make-widget "root"
                                     :update (fn [self msg]
                                               (put received :msg msg)))
             a (proto/make-widget "a" :focusable true
                                  :handle-event (fn [self event]
                                                  {:redraw true :msg {:type :test-msg :data 42}}))
             _ (proto/widget-add-child root a)
             _ (proto/init-focus root)
             result (proto/dispatch-event root {:type :key :key "x"})]
         (and (not (nil? (received :msg)))
              (= :test-msg ((received :msg) :type))
              (= 42 ((received :msg) :data)))))

# --- List widget messages ---

(check "list emits :list-changed on navigation and :list-selected on enter"
       (let [msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             lst (list/list-widget :id "lst" :items @["a" "b" "c"])
             _ (proto/widget-add-child root lst)
             _ (proto/init-focus root)]
         # Navigate down
         (proto/dispatch-event root {:type :key :key "j"})
         # Press enter
         (proto/dispatch-event root {:type :key :key :enter})
         (and (>= (length msgs) 2)
              (= :list-changed ((get msgs 0) :type))
              (= 1 ((get msgs 0) :index))
              (= :list-selected ((get msgs 1) :type))
              (= 1 ((get msgs 1) :index)))))

# --- Input widget messages ---

(check "input emits :input-changed on text change"
       (let [msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             inp (input/input-widget :id "inp" :value "")
             _ (proto/widget-add-child root inp)
             _ (proto/init-focus root)]
         (proto/dispatch-event root {:type :key :key "a"})
         (and (= 1 (length msgs))
              (= :input-changed ((get msgs 0) :type))
              (= "a" ((get msgs 0) :value)))))

# --- Checkbox widget messages ---

(check "checkbox emits :checkbox-changed on toggle"
       (let [msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             cb (checkbox/checkbox-widget :id "cb" :checked false :label "test")
             _ (proto/widget-add-child root cb)
             _ (proto/init-focus root)]
         (proto/dispatch-event root {:type :key :key " "})
         (and (= 1 (length msgs))
              (= :checkbox-changed ((get msgs 0) :type))
              (= true ((get msgs 0) :checked)))))

# --- Mouse interaction: List ---

(check "list click selects and activates correct item"
       (let [msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             lst (list/list-widget :id "lst" :items @["a" "b" "c" "d"])
             _ (proto/widget-add-child root lst)
             _ (proto/build-layout-tree root)]
         # Fake rects for hit-testing (root must encompass children)
         (put (root :layout-node) :rect {:row 1 :col 1 :width 20 :height 4})
         (put (lst :layout-node) :rect {:row 1 :col 1 :width 20 :height 4})
         # Click on row 3 (0-based offset 2 -> item "c")
         (proto/dispatch-event root {:type :mouse :button 0 :col 5 :row 3 :action :press})
         (and (= 1 (length msgs))
              (= :list-selected ((get msgs 0) :type))
              (= 2 ((get msgs 0) :index))
              (= "c" ((get msgs 0) :item))
              (= 2 (get-in lst [:state :selected])))))

(check "list click with scroll offset selects correct item"
       (let [msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             lst (list/list-widget :id "lst" :items @["a" "b" "c" "d" "e"])
             _ (proto/widget-add-child root lst)
             _ (proto/build-layout-tree root)]
         (put (root :layout-node) :rect {:row 1 :col 1 :width 20 :height 3})
         (put (lst :layout-node) :rect {:row 1 :col 1 :width 20 :height 3})
         # Simulate scroll offset of 2 (items "c","d","e" visible)
         (put (lst :state) :scroll-offset 2)
         # Click on row 2 (offset 2 + (2 - 1) = 3 -> item "d")
         (proto/dispatch-event root {:type :mouse :button 0 :col 5 :row 2 :action :press})
         (and (= 1 (length msgs))
              (= :list-selected ((get msgs 0) :type))
              (= 3 ((get msgs 0) :index))
              (= "d" ((get msgs 0) :item))
              (= 3 (get-in lst [:state :selected])))))

(check "list scroll wheel navigates selection"
       (let [msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             lst (list/list-widget :id "lst" :items @["a" "b" "c"] :selected 1)
             _ (proto/widget-add-child root lst)
             _ (proto/build-layout-tree root)]
         (put (root :layout-node) :rect {:row 1 :col 1 :width 20 :height 3})
         (put (lst :layout-node) :rect {:row 1 :col 1 :width 20 :height 3})
         # Scroll up (button 0) -> selected goes 1 -> 0
         (proto/dispatch-event root {:type :mouse :button 0 :col 5 :row 2 :action :scroll})
         (def after-up (get-in lst [:state :selected]))
         # Scroll down (button 1) -> selected goes 0 -> 1
         (proto/dispatch-event root {:type :mouse :button 1 :col 5 :row 2 :action :scroll})
         (def after-down (get-in lst [:state :selected]))
         (and (= 0 after-up)
              (= 1 after-down)
              (= 2 (length msgs)))))

# --- Mouse interaction: Checkbox ---

(check "checkbox click toggles checked state"
       (let [msgs @[]
             root (proto/make-widget "root"
                                     :update (fn [self msg] (array/push msgs msg)))
             cb (checkbox/checkbox-widget :id "cb" :checked false :label "test")
             _ (proto/widget-add-child root cb)
             _ (proto/build-layout-tree root)]
         (put (root :layout-node) :rect {:row 1 :col 1 :width 10 :height 1})
         (put (cb :layout-node) :rect {:row 1 :col 1 :width 10 :height 1})
         # Click to toggle on
         (proto/dispatch-event root {:type :mouse :button 0 :col 3 :row 1 :action :press})
         (def checked-after (get-in cb [:state :checked]))
         # Click again to toggle off
         (proto/dispatch-event root {:type :mouse :button 0 :col 3 :row 1 :action :press})
         (def unchecked-after (get-in cb [:state :checked]))
         (and (= true checked-after)
              (= false unchecked-after)
              (= 2 (length msgs))
              (= :checkbox-changed ((get msgs 0) :type))
              (= true ((get msgs 0) :checked))
              (= false ((get msgs 1) :checked)))))

(printf "  %d tests passed" pass)
