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
  "Create a scrollable list widget.
   items: array of strings
   selected: initial selected index (default 0)
   on-select: callback (fn [index item]) called on enter"
  [&named items selected on-select id classes style
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
                   (put state :selected (max 0 (- sel 1)))
                   # Scroll if needed
                   (when (< (state :selected) (state :scroll-offset))
                     (put state :scroll-offset (state :selected)))
                   {:redraw true})

                 :down
                 (do
                   (put state :selected (min (- count 1) (+ sel 1)))
                   {:redraw true})

                 "k"
                 (do
                   (put state :selected (max 0 (- sel 1)))
                   (when (< (state :selected) (state :scroll-offset))
                     (put state :scroll-offset (state :selected)))
                   {:redraw true})

                 "j"
                 (do
                   (put state :selected (min (- count 1) (+ sel 1)))
                   {:redraw true})

                 :enter
                 (do
                   (when (state :on-select)
                     ((state :on-select) sel (get items-list sel)))
                   {:redraw true}))))

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

             (for i 0 visible-h
               (def item-idx (+ offset i))
               (def row (+ (rect :row) i))
               (if (< item-idx (length items-list))
                 (do
                   (def item (get items-list item-idx))
                   (def s (if (= item-idx sel) sel-style normal-style))
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
  (put (w :state) :selected selected)
  (put (w :state) :scroll-offset 0)
  (put (w :state) :on-select on-select)

  w)
