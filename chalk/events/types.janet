# Layer 3: Event constructors and PEG-based input parser

# --- Event constructors ---

(defn key-event
  "Create a key event."
  [key &named mods]
  {:type :key :key key :mods (or mods :none)})

(defn mouse-event
  "Create a mouse event."
  [button col row action &named mods]
  {:type :mouse :button button :col col :row row :action action :mods (or mods :none)})

(defn resize-event
  "Create a resize event."
  [cols rows]
  {:type :resize :cols cols :rows rows})

(defn quit-event
  "Create a quit event."
  []
  {:type :quit})

# --- Key name tables ---

(def- csi-key-map
  {"A" :up "B" :down "C" :right "D" :left
   "H" :home "F" :end
   "Z" :shift-tab})

(def- csi-tilde-map
  {"1" :home "2" :insert "3" :delete "4" :end
   "5" :page-up "6" :page-down
   "15" :f5 "17" :f6 "18" :f7 "19" :f8
   "20" :f9 "21" :f10 "23" :f11 "24" :f12})

(def- ss3-key-map
  {"P" :f1 "Q" :f2 "R" :f3 "S" :f4})

(def- ctrl-key-map
  {1 :ctrl-a 2 :ctrl-b 3 :ctrl-c 4 :ctrl-d
   5 :ctrl-e 6 :ctrl-f 7 :ctrl-g 8 :backspace
   9 :tab 10 :enter 11 :ctrl-k 12 :ctrl-l
   13 :enter 14 :ctrl-n 15 :ctrl-o 16 :ctrl-p
   17 :ctrl-q 18 :ctrl-r 19 :ctrl-s 20 :ctrl-t
   21 :ctrl-u 22 :ctrl-v 23 :ctrl-w 24 :ctrl-x
   25 :ctrl-y 26 :ctrl-z 27 :escape 127 :backspace})

# --- PEG grammar ---
# Each branch emits a :tag constant first, then its captures, then position ($).

(def input-grammar
  (peg/compile
    ~{:main (* (+ :sgr-mouse :csi-tilde :csi :ss3 :alt-key :utf8 :ctrl :ascii) ($))

      # SGR mouse: ESC [ < button ; col ; row [Mm]
      :sgr-mouse (* (constant :sgr-mouse) "\e[<"
                    (capture :digits) ";"
                    (capture :digits) ";"
                    (capture :digits)
                    (capture (set "Mm")))

      # CSI with tilde: ESC [ number ~
      :csi-tilde (* (constant :csi-tilde) "\e["
                    (capture :digits) "~")

      # CSI: ESC [ params final-byte
      :csi (* (constant :csi) "\e["
              (capture (any (+ :d (set ";:"))))
              (capture (range "A~")))

      # SS3: ESC O letter
      :ss3 (* (constant :ss3) "\eO" (capture (range "AZ")))

      # Alt+key: ESC followed by printable char
      :alt-key (* (constant :alt-key) "\e" (capture (range "\x20\x7e")))

      # Multi-byte UTF-8
      :utf8 (+ :utf8-4 :utf8-3 :utf8-2)
      :utf8-2 (* (constant :utf8) (capture (* (range "\xc0\xdf") (range "\x80\xbf"))))
      :utf8-3 (* (constant :utf8) (capture (* (range "\xe0\xef") (range "\x80\xbf") (range "\x80\xbf"))))
      :utf8-4 (* (constant :utf8) (capture (* (range "\xf0\xf7") (range "\x80\xbf") (range "\x80\xbf") (range "\x80\xbf"))))

      # Control chars (0x01-0x1f, 0x7f)
      :ctrl (* (constant :ctrl) (capture (+ (range "\x01\x1f") "\x7f")))

      # Plain printable ASCII
      :ascii (* (constant :ascii) (capture (range "\x20\x7e")))

      :digits (some :d)}))

# --- Sequence-to-event translation ---

(defn- parse-one
  "Parse a PEG match result (tag + captures + position) into [event consumed]."
  [captures]
  (def tag (get captures 0))
  (def pos (last captures))

  (case tag
    :sgr-mouse
    (let [btn-code (scan-number (get captures 1))
          col (scan-number (get captures 2))
          row (scan-number (get captures 3))
          act-ch (get captures 4)
          button (band btn-code 0x03)
          action (if (= act-ch "M")
                   (if (not= 0 (band btn-code 0x20)) :move
                     (if (not= 0 (band btn-code 0x40)) :scroll :press))
                   :release)]
      [(mouse-event button col row action) pos])

    :csi-tilde
    (let [num (get captures 1)
          key (get csi-tilde-map num (keyword (string "f-" num)))]
      [(key-event key) pos])

    :csi
    (let [params (get captures 1)
          final (get captures 2)
          key (get csi-key-map final nil)]
      (if key
        [(key-event key) pos]
        [(key-event (keyword (string "csi-" final))) pos]))

    :ss3
    (let [letter (get captures 1)
          key (get ss3-key-map letter (keyword (string "ss3-" letter)))]
      [(key-event key) pos])

    :alt-key
    (let [ch (get captures 1)]
      [(key-event (keyword (string "alt-" ch))) pos])

    :utf8
    [(key-event (get captures 1)) pos]

    :ctrl
    (let [s (get captures 1)
          byte (get s 0)
          key (get ctrl-key-map byte (keyword (string "ctrl-" (string/from-bytes (+ byte 96)))))]
      [(key-event key) pos])

    :ascii
    [(key-event (get captures 1)) pos]

    # Fallback
    [nil pos]))

(defn parse-input
  ```Parse a byte buffer into a sequence of events.
   Returns an array of event structs.```
  [bytes]
  (def events @[])
  (var offset 0)
  (def blen (length bytes))
  (while (< offset blen)
    (def result (peg/match input-grammar bytes offset))
    (if (nil? result)
      (++ offset)
      (let [[event consumed] (parse-one result)
            abs-consumed (- consumed offset)]
        (when event (array/push events event))
        (if (> abs-consumed 0)
          (+= offset abs-consumed)
          (++ offset)))))
  events)
