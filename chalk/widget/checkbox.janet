# Checkbox widget
# Toggleable checkbox with label and configurable character styles.

(import ./proto)
(import ../terminal/screen)
(import ../terminal/style)


(def checkbox-styles
  "Named checkbox character sets: [unchecked checked]."
  {:ascii ["[ ]" "[x]"]
   :square ["\xe2\x96\xa1" "\xe2\x96\xa0"]
   :round ["\xe2\x97\x8b" "\xe2\x97\x8f"]})

(defn checkbox-widget
  ```Create a checkbox widget.
   checked: initial state (default false)
   label: text shown after the indicator
   on-change: callback (fn [checked])
   checkbox-style: :ascii, :square (default), or :round```
  [&named checked label on-change checkbox-style id classes style style-focused
   width height flex-grow flex-shrink margin padding dock]
  (default checked false)
  (default label "")
  (default checkbox-style :square)

  (def chars (or (get checkbox-styles checkbox-style)
                 (get checkbox-styles :square)))

  (def indicator-width (length (get chars 0)))
  (def auto-width (+ indicator-width 1 (length label)))

  (def w (proto/make-widget
           "checkbox"
           :id id
           :classes classes
           :style style
           :style-focused style-focused
           :width (or width auto-width)
           :height (or height 1)
           :flex-grow flex-grow
           :flex-shrink flex-shrink
           :margin margin
           :padding padding
           :dock dock
           :focusable true

           :handle-event
           (fn [self event]
             (case (event :type)
               :key
               (let [k (event :key)]
                 (when (or (= k " ") (= k :enter))
                   (def state (self :state))
                   (def new-val (not (state :checked)))
                   (put state :checked new-val)
                   (when (state :on-change)
                     ((state :on-change) new-val))
                   {:redraw true
                    :msg {:type :checkbox-changed :id (self :id)
                          :checked new-val}}))

               :mouse
               (when (and (= (event :action) :press) (= (event :button) 0))
                 (def state (self :state))
                 (def new-val (not (state :checked)))
                 (put state :checked new-val)
                 (when (state :on-change)
                   ((state :on-change) new-val))
                 {:redraw true
                  :msg {:type :checkbox-changed :id (self :id)
                        :checked new-val}})))

           :paint
           (fn [self scr rect]
             (def state (self :state))
             (def chk (state :checked))
             (def lbl (state :label))
             (def ch (state :chars))
             (def indicator (get ch (if chk 1 0)))
             (def display (string indicator " " lbl))
             (def w (rect :width))

             (def effective (proto/resolve-effective-style self))
             (def normal-style
               (when effective (style/make-style ;(kvs effective))))

             # Clear background
             (for c (rect :col) (+ (rect :col) w)
               (screen/screen-put scr c (rect :row) " " normal-style))

             # Draw checkbox + label, clipped to width
             (def clipped (if (> (length display) w)
                            (string/slice display 0 w)
                            display))
             (screen/screen-put-string scr (rect :col) (rect :row)
                                       clipped normal-style))))

  # Initialize state
  (put (w :state) :checked checked)
  (put (w :state) :label label)
  (put (w :state) :on-change on-change)
  (put (w :state) :chars chars)

  w)
