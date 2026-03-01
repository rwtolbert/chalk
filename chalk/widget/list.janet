# Layer 10: Scrollable list widget
# Displays a list of items with keyboard selection.

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

(defn list-widget
  ```Create a scrollable list widget.
   items: array of strings
   item-styles: optional array of style tables parallel to items
   selected: initial selected index (default 0)
   on-select: callback (fn [index item]) called on enter```
  [&named items item-styles selected on-select id classes style
   width height flex-grow flex-shrink margin padding dock]
  (default items @[])
  (default selected 0)

  (def w (proto/make-widget
           "list"
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
             (when (= (event :type) :key)
               (def state (self :state))
               (def items-list (state :items))
               (def count (length items-list))
               (when (= count 0) (break nil))

               (def sel (state :selected))
               (case (event :key)
                 :up
                 (do
                   (def new-sel (max 0 (- sel 1)))
                   (put state :selected new-sel)
                   (when (< new-sel (state :scroll-offset))
                     (put state :scroll-offset new-sel))
                   {:redraw true
                    :msg {:type :list-changed :id (self :id) :index new-sel}})

                 :down
                 (do
                   (def new-sel (min (- count 1) (+ sel 1)))
                   (put state :selected new-sel)
                   {:redraw true
                    :msg {:type :list-changed :id (self :id) :index new-sel}})

                 "k"
                 (do
                   (def new-sel (max 0 (- sel 1)))
                   (put state :selected new-sel)
                   (when (< new-sel (state :scroll-offset))
                     (put state :scroll-offset new-sel))
                   {:redraw true
                    :msg {:type :list-changed :id (self :id) :index new-sel}})

                 "j"
                 (do
                   (def new-sel (min (- count 1) (+ sel 1)))
                   (put state :selected new-sel)
                   {:redraw true
                    :msg {:type :list-changed :id (self :id) :index new-sel}})

                 :enter
                 (do
                   (when (state :on-select)
                     ((state :on-select) sel (get items-list sel)))
                   {:redraw true
                    :msg {:type :list-selected :id (self :id)
                          :index sel :item (get items-list sel)}}))))

           :paint
           (fn [self scr rect]
             (def state (self :state))
             (def items-list (state :items))
             (def sel (state :selected))
             (def visible-h (rect :height))

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

             (def istyles (state :item-styles))

             (for i 0 visible-h
               (def item-idx (+ offset i))
               (def row (+ (rect :row) i))
               (if (< item-idx (length items-list))
                 (do
                   (def item (get items-list item-idx))
                   # Per-item style override
                   (def item-s
                     (when istyles
                       (when-let [is (get istyles item-idx)]
                         (style/make-style ;(kvs (if effective (merge effective is) is))))))
                   (def base-s (or item-s normal-style))
                   (def s (if (= item-idx sel)
                            (style/make-style :reverse true
                                              :fg (when base-s (get (if item-s (get istyles item-idx) (or effective {})) :fg))
                                              :bg (when effective (get effective :bg)))
                            base-s))
                   # Clear the line
                   (for c (rect :col) (+ (rect :col) (rect :width))
                     (screen/screen-put scr c row " " s))
                   # Draw item text, clipped
                   (def display (if (> (length item) (rect :width))
                                  (string/slice item 0 (rect :width))
                                  item))
                   (screen/screen-put-string scr (rect :col) row
                                             (string " " display) s))
                 # Clear empty rows below items
                 (for c (rect :col) (+ (rect :col) (rect :width))
                   (screen/screen-put scr c row " " normal-style)))))))

  # Initialize state
  (put (w :state) :items items)
  (put (w :state) :item-styles item-styles)
  (put (w :state) :selected selected)
  (put (w :state) :scroll-offset 0)
  (put (w :state) :on-select on-select)

  w)
