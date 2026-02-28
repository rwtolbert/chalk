# Layer 6 Demo: Layout engine test
# Creates a layout tree (header/sidebar+content/footer),
# runs layout, paints colored rects to screen buffer.
# Press q or ctrl-c to quit.

(import ../chalk/platform/init :as platform)
(import ../chalk/terminal/output :as output)
(import ../chalk/terminal/style :as style)
(import ../chalk/terminal/screen :as screen)
(import ../chalk/events/loop :as loop)
(import ../chalk/layout/box)
(import ../chalk/layout/flex)

(defn- fill-rect [scr rect s]
  "Fill a rect with spaces in the given style."
  (for row (rect :row) (+ (rect :row) (rect :height))
    (for col (rect :col) (+ (rect :col) (rect :width))
      (screen/screen-put scr col row " " s))))

(defn- label-rect [scr rect text s]
  "Put a label in the center of a rect."
  (def cx (+ (rect :col) (math/floor (/ (- (rect :width) (length text)) 2))))
  (def cy (+ (rect :row) (math/floor (/ (rect :height) 2))))
  (when (and (> cx 0) (> cy 0))
    (screen/screen-put-string scr (max 1 cx) cy text s)))

(defn main [&]
  (def [cols rows] (platform/get-terminal-size))
  (var current-cols cols)
  (var current-rows rows)
  (var quit false)

  (platform/enter-raw-mode)
  (defer (do
           (loop/stop)
           (output/reset-style)
           (output/exit-alt-screen)
           (output/show-cursor)
           (output/flush)
           (platform/exit-raw-mode))

    (output/enter-alt-screen)
    (output/hide-cursor)
    (output/flush)

    (var scr (screen/make-screen current-cols current-rows))
    (screen/screen-force-redraw scr)
    (loop/start)

    (defn draw [w h]
      # Build layout tree
      (def root (box/make-node "root" :flex-direction :column))
      (def header (box/make-node "header" :height 3 :dock :top))
      (def footer (box/make-node "footer" :height 3 :dock :bottom))
      (def middle (box/make-node "middle" :flex-direction :row :flex-grow 1))
      (def sidebar (box/make-node "sidebar" :width 20))
      (def content (box/make-node "content" :flex-grow 1))

      (array/push (root :children) header)
      (array/push (root :children) footer)
      (array/push (root :children) middle)
      (array/push (middle :children) sidebar)
      (array/push (middle :children) content)

      # Run layout
      (flex/layout root w h)

      # Paint
      (screen/screen-clear scr)

      (def header-style (style/make-style :bg :blue :fg :white :bold true))
      (def footer-style (style/make-style :bg :magenta :fg :bright-white))
      (def sidebar-style (style/make-style :bg :green :fg :black))
      (def content-style (style/make-style :bg :bright-black :fg :white))

      (fill-rect scr (header :rect) header-style)
      (label-rect scr (header :rect) "HEADER (docked top, h=3)" header-style)

      (fill-rect scr (footer :rect) footer-style)
      (label-rect scr (footer :rect) "FOOTER (docked bottom, h=3)" footer-style)

      (fill-rect scr (sidebar :rect) sidebar-style)
      (label-rect scr (sidebar :rect) "SIDEBAR (w=20)" sidebar-style)

      (fill-rect scr (content :rect) content-style)
      (def cr (content :rect))
      (label-rect scr cr
                  (string/format "CONTENT (flex-grow=1) %dx%d" (cr :width) (cr :height))
                  content-style)

      # Show layout info
      (def info-style (style/make-style :fg :yellow))
      (screen/screen-put-string scr 2 (- h 0)
                                (string/format "Layout: %dx%d | q to quit" w h)
                                info-style)

      (screen/screen-render scr))

    (draw current-cols current-rows)

    (while (not quit)
      (def events (loop/read-events))
      (var needs-redraw false)

      (each event events
        (case (event :type)
          :key
          (when (or (= (event :key) "q") (= (event :key) :ctrl-c))
            (set quit true))

          :resize
          (do
            (set current-cols (event :cols))
            (set current-rows (event :rows))
            (set scr (screen/make-screen current-cols current-rows))
            (screen/screen-force-redraw scr)
            (set needs-redraw true))))

      (when (and needs-redraw (not quit))
        (draw current-cols current-rows)))))

(main)
(os/exit 0)
