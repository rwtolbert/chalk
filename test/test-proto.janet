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

(printf "  %d tests passed" pass)
