# Demo: Interactive hello world exercising all 5 layers
# Run from project root: janet demo/hello.janet

(import ../chalk/platform/init :as platform)
(import ../chalk/terminal/output :as output)
(import ../chalk/terminal/style :as style)
(import ../chalk/terminal/screen :as screen)
(import ../chalk/events/loop :as loop)

(defn- draw-title-bar [scr cols text]
  (def bar-style (style/make-style :fg :white :bg :blue :bold true))
  (for c 1 (+ cols 1)
    (screen/screen-put scr c 1 " " bar-style))
  (def offset (max 1 (math/floor (+ 1 (/ (- cols (length text)) 2)))))
  (screen/screen-put-string scr offset 1 text bar-style))

(defn- draw-footer [scr cols rows text]
  (def footer-style (style/make-style :fg :bright-white :bg :magenta))
  (for c 1 (+ cols 1)
    (screen/screen-put scr c rows " " footer-style))
  (screen/screen-put-string scr 2 rows text footer-style))

(defn- draw-content [scr cols rows last-key mouse-pos]
  (def label-style (style/make-style :fg :cyan :bold true))
  (def value-style (style/make-style :fg :white))
  (def dim-style (style/make-style :fg :bright-black))

  (screen/screen-put-string scr 3 4 "Last key: " label-style)
  (screen/screen-put-string scr 13 4 (or last-key "(none)") value-style)
  (def klen (length (or last-key "(none)")))
  (for c (+ 13 klen) (+ cols 1)
    (screen/screen-put scr c 4 " "))

  (screen/screen-put-string scr 3 6 "Mouse:    " label-style)
  (screen/screen-put-string scr 13 6 (or mouse-pos "(move mouse here)") value-style)
  (def mlen (length (or mouse-pos "(move mouse here)")))
  (for c (+ 13 mlen) (+ cols 1)
    (screen/screen-put scr c 6 " "))

  (screen/screen-put-string scr 3 8 "Terminal: " label-style)
  (screen/screen-put-string scr 13 8 (string/format "%dx%d" cols rows) value-style)

  (screen/screen-put-string scr 3 10 "Press keys, move mouse, or resize the terminal." dim-style))

(defn- redraw [scr cols rows last-key mouse-pos]
  (screen/screen-clear scr)
  (def title (string/format "chalk demo  |  %dx%d" cols rows))
  (draw-title-bar scr cols title)
  (draw-footer scr cols rows "q/ctrl-c: quit  |  chalk TUI library")
  (draw-content scr cols rows last-key mouse-pos)
  (screen/screen-render scr))

(defn main [&]
  (def [cols rows] (platform/get-terminal-size))
  (var current-cols cols)
  (var current-rows rows)
  (var last-key nil)
  (var mouse-pos nil)
  (var quit false)

  # Enter raw mode + alt screen
  (platform/enter-raw-mode)
  (defer (do
           (loop/stop)
           (output/disable-mouse)
           (output/reset-style)
           (output/exit-alt-screen)
           (output/show-cursor)
           (output/flush)
           (platform/exit-raw-mode))

    (output/enter-alt-screen)
    (output/enable-mouse)
    (output/hide-cursor)
    (output/flush)

    # Create virtual screen
    (var scr (screen/make-screen current-cols current-rows))
    (screen/screen-force-redraw scr)

    # Start tty reader
    (loop/start)

    # Initial draw
    (redraw scr current-cols current-rows last-key mouse-pos)

    # Event loop
    (while (not quit)
      (def events (loop/read-events))
      (var needs-redraw false)

      (each event events
        (case (event :type)
          :key
          (let [k (event :key)]
            (if (or (= k "q") (= k :ctrl-c))
              (set quit true)
              (do
                (set last-key (string k))
                (set needs-redraw true))))

          :mouse
          (do
            (set mouse-pos (string/format "col=%d row=%d btn=%d %s"
                                          (event :col) (event :row)
                                          (event :button) (string (event :action))))
            (set needs-redraw true))

          :resize
          (do
            (set current-cols (event :cols))
            (set current-rows (event :rows))
            (set scr (screen/make-screen current-cols current-rows))
            (screen/screen-force-redraw scr)
            (set needs-redraw true))))

      (when (and needs-redraw (not quit))
        (redraw scr current-cols current-rows last-key mouse-pos)))))

(main)
(os/exit 0)
