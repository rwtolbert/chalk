# Layer 9 Demo: Counter widget using defwidget
# Press +/= to increment, -/_ to decrement, q or ctrl-c to quit.

(import ../chalk/platform/init :as platform)
(import ../chalk/terminal/output :as output)
(import ../chalk/terminal/screen :as screen)
(import ../chalk/terminal/style :as style)
(import ../chalk/events/loop :as loop)
(import ../chalk/widget/proto)
(import ../chalk/widget/text)
(import ../chalk/widget/container)
(import ../chalk/widget/render)
(import ../chalk/widget/defwidget :as dw)

(defn build-counter-ui [count]
  "Build widget tree reflecting the current count."
  (container/container
    :id "counter-display"
    :flex-direction :column
    :flex-grow 1
    :padding 1
    :style {:bg :bright-black :fg :white}
    :children
    @[(text/text "Counter Demo" :style {:fg :cyan :bold true})
      (text/text "")
      (text/text (string/format "  Count: %d" count)
                 :style {:fg :yellow :bold true})
      (text/text "")
      (text/text "  +/= : increment")
      (text/text "  -/_ : decrement")
      (text/text "  r   : reset")
      (text/text "")
      (text/text "  q/ctrl-c : quit" :style {:fg :bright-black})]))

(defn main [&]
  (def [cols rows] (platform/get-terminal-size))
  (var current-cols cols)
  (var current-rows rows)
  (var quit false)
  (var count 0)

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

    (var root (build-counter-ui count))
    (render/render-tree scr root current-cols current-rows)

    (while (not quit)
      (def events (loop/read-events))
      (var needs-redraw false)

      (each event events
        (case (event :type)
          :key
          (let [k (event :key)]
            (cond
              (or (= k "q") (= k :ctrl-c))
              (set quit true)

              (or (= k "+") (= k "="))
              (do (++ count) (set needs-redraw true))

              (or (= k "-") (= k "_"))
              (do (-- count) (set needs-redraw true))

              (= k "r")
              (do (set count 0) (set needs-redraw true))))

          :resize
          (do
            (set current-cols (event :cols))
            (set current-rows (event :rows))
            (set scr (screen/make-screen current-cols current-rows))
            (screen/screen-force-redraw scr)
            (set needs-redraw true))))

      (when (and needs-redraw (not quit))
        (set root (build-counter-ui count))
        (render/render-tree scr root current-cols current-rows)))))

(main)
(os/exit 0)
