# Layer 10: Text input field widget
# Single-line text input with cursor.

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

(defn input-widget
  "Create a text input widget.
   value: initial text
   placeholder: shown when empty
   on-change: callback (fn [value])
   on-submit: callback (fn [value]) called on enter"
  [&named value placeholder on-change on-submit id classes style
   width height flex-grow flex-shrink margin padding dock]
  (default value "")
  (default placeholder "")

  (def w (proto/make-widget
           "input"
           :id id
           :classes classes
           :style style
           :width width
           :height (or height 1)
           :flex-grow flex-grow
           :flex-shrink flex-shrink
           :margin margin
           :padding padding
           :dock dock

           :handle-event
           (fn [self event]
             (when (= (event :type) :key)
               (def state (self :state))
               (def val (state :value))
               (def pos (state :cursor-pos))
               (def k (event :key))

               (cond
                 # Printable character
                 (and (string? k) (= (length k) 1) (>= (get k 0) 32))
                 (do
                   (def new-val (string (string/slice val 0 pos) k
                                        (string/slice val pos)))
                   (put state :value new-val)
                   (put state :cursor-pos (+ pos 1))
                   (when (state :on-change) ((state :on-change) new-val))
                   {:redraw true})

                 (= k :backspace)
                 (when (> pos 0)
                   (def new-val (string (string/slice val 0 (- pos 1))
                                        (string/slice val pos)))
                   (put state :value new-val)
                   (put state :cursor-pos (- pos 1))
                   (when (state :on-change) ((state :on-change) new-val))
                   {:redraw true})

                 (= k :delete)
                 (when (< pos (length val))
                   (def new-val (string (string/slice val 0 pos)
                                        (string/slice val (+ pos 1))))
                   (put state :value new-val)
                   (when (state :on-change) ((state :on-change) new-val))
                   {:redraw true})

                 (= k :left)
                 (when (> pos 0)
                   (put state :cursor-pos (- pos 1))
                   {:redraw true})

                 (= k :right)
                 (when (< pos (length val))
                   (put state :cursor-pos (+ pos 1))
                   {:redraw true})

                 (= k :home)
                 (do
                   (put state :cursor-pos 0)
                   {:redraw true})

                 (= k :end)
                 (do
                   (put state :cursor-pos (length val))
                   {:redraw true})

                 (= k :enter)
                 (do
                   (when (state :on-submit) ((state :on-submit) val))
                   {:redraw true})

                 # ctrl-u: clear
                 (= k :ctrl-u)
                 (do
                   (put state :value "")
                   (put state :cursor-pos 0)
                   (when (state :on-change) ((state :on-change) ""))
                   {:redraw true}))))

           :paint
           (fn [self scr rect]
             (def state (self :state))
             (def val (state :value))
             (def pos (state :cursor-pos))
             (def ph (state :placeholder))
             (def w (rect :width))

             (def effective (resolve-effective-style self))
             (def normal-style
               (when effective (style/make-style ;(kvs effective))))
             (def cursor-style (style/make-style :reverse true))
             (def ph-style (style/make-style :fg :bright-black))

             # Clear background
             (for c (rect :col) (+ (rect :col) w)
               (screen/screen-put scr c (rect :row) " " normal-style))

             (if (= (length val) 0)
               # Show placeholder
               (do
                 (def display-ph (if (> (length ph) w) (string/slice ph 0 w) ph))
                 (screen/screen-put-string scr (rect :col) (rect :row) display-ph ph-style)
                 # Cursor at start
                 (screen/screen-put scr (rect :col) (rect :row) " " cursor-style))
               # Show value with cursor
               (do
                 # Scroll if cursor beyond visible area
                 (var scroll (or (state :scroll) 0))
                 (when (>= pos (+ scroll w))
                   (set scroll (- pos w -1)))
                 (when (< pos scroll)
                   (set scroll pos))
                 (put state :scroll scroll)

                 (def visible (string/slice val scroll (min (length val) (+ scroll w))))
                 (screen/screen-put-string scr (rect :col) (rect :row) visible normal-style)

                 # Draw cursor
                 (def cursor-col (+ (rect :col) (- pos scroll)))
                 (when (and (>= cursor-col (rect :col))
                            (< cursor-col (+ (rect :col) w)))
                   (def cursor-char (if (< pos (length val))
                                      (string/from-bytes (get val pos))
                                      " "))
                   (screen/screen-put scr cursor-col (rect :row) cursor-char cursor-style)))))))

  # Initialize state
  (put (w :state) :value value)
  (put (w :state) :cursor-pos (length value))
  (put (w :state) :placeholder placeholder)
  (put (w :state) :on-change on-change)
  (put (w :state) :on-submit on-submit)
  (put (w :state) :scroll 0)

  w)
