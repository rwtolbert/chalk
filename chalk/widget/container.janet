# Layer 7: Container widget
# Groups child widgets, optionally fills background.

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

(defn container
  "Create a container widget. Children are added via widget-add-child."
  [&named id classes style flex-direction width height flex-grow flex-shrink
   margin padding dock children
   border-style border-color border-title border-title-align]
  (def w (proto/make-widget
           "container"
           :id id
           :classes classes
           :style style
           :flex-direction flex-direction
           :width width
           :height height
           :flex-grow flex-grow
           :flex-shrink flex-shrink
           :margin margin
           :padding padding
           :dock dock
           :border-style border-style
           :border-color border-color
           :border-title border-title
           :border-title-align border-title-align
           :paint
           (fn [self scr rect]
             (def effective (resolve-effective-style self))
             (when-let [st effective
                        bg (get st :bg)]
               (def s (style/make-style ;(kvs st)))
               (for row (rect :row) (+ (rect :row) (rect :height))
                 (for col (rect :col) (+ (rect :col) (rect :width))
                   (screen/screen-put scr col row " " s)))))))

  # Add initial children
  (when children
    (each child children
      (proto/widget-add-child w child)))

  w)
