# Tests for chalk/events/types.janet (event constructors + PEG input parser)

(import ../chalk/events/types)

(var pass 0)
(defn check [name & assertions]
  (each a assertions (assert a name))
  (++ pass))

# --- Event constructors ---

(check "key-event constructor"
  (let [e (types/key-event :a)]
    (and (= :key (e :type))
         (= :a (e :key))
         (= :none (e :mods)))))

(check "key-event with mods"
  (let [e (types/key-event :a :mods :shift)]
    (= :shift (e :mods))))

(check "mouse-event constructor"
  (let [e (types/mouse-event 0 10 5 :press)]
    (and (= :mouse (e :type))
         (= 0 (e :button))
         (= 10 (e :col))
         (= 5 (e :row))
         (= :press (e :action))
         (= :none (e :mods)))))

(check "resize-event constructor"
  (let [e (types/resize-event 80 24)]
    (and (= :resize (e :type))
         (= 80 (e :cols))
         (= 24 (e :rows)))))

(check "quit-event constructor"
  (let [e (types/quit-event)]
    (= :quit (e :type))))

# --- Printable ASCII ---

(check "parse single letter a"
  (let [events (types/parse-input "a")]
    (and (= 1 (length events))
         (= :key ((get events 0) :type))
         (= "a" ((get events 0) :key)))))

(check "parse single letter Z"
  (let [events (types/parse-input "Z")]
    (= "Z" ((get events 0) :key))))

(check "parse space"
  (let [events (types/parse-input " ")]
    (= " " ((get events 0) :key))))

(check "parse digit"
  (let [events (types/parse-input "5")]
    (= "5" ((get events 0) :key))))

# --- Control codes ---

(check "parse ctrl-a (0x01)"
  (let [events (types/parse-input "\x01")]
    (= :ctrl-a ((get events 0) :key))))

(check "parse ctrl-c (0x03)"
  (let [events (types/parse-input "\x03")]
    (= :ctrl-c ((get events 0) :key))))

(check "parse backspace (0x7f)"
  (let [events (types/parse-input "\x7f")]
    (= :backspace ((get events 0) :key))))

(check "parse backspace (0x08)"
  (let [events (types/parse-input "\x08")]
    (= :backspace ((get events 0) :key))))

(check "parse tab (0x09)"
  (let [events (types/parse-input "\x09")]
    (= :tab ((get events 0) :key))))

(check "parse enter (0x0a)"
  (let [events (types/parse-input "\x0a")]
    (= :enter ((get events 0) :key))))

(check "parse enter (0x0d)"
  (let [events (types/parse-input "\x0d")]
    (= :enter ((get events 0) :key))))

(check "parse escape (0x1b alone)"
  (let [events (types/parse-input "\x1b")]
    (= :escape ((get events 0) :key))))

# --- Arrow keys ---

(check "parse arrow up"
  (let [events (types/parse-input "\e[A")]
    (= :up ((get events 0) :key))))

(check "parse arrow down"
  (let [events (types/parse-input "\e[B")]
    (= :down ((get events 0) :key))))

(check "parse arrow right"
  (let [events (types/parse-input "\e[C")]
    (= :right ((get events 0) :key))))

(check "parse arrow left"
  (let [events (types/parse-input "\e[D")]
    (= :left ((get events 0) :key))))

# --- Function keys ---

(check "parse f1 (SS3)"
  (let [events (types/parse-input "\eOP")]
    (= :f1 ((get events 0) :key))))

(check "parse f2 (SS3)"
  (let [events (types/parse-input "\eOQ")]
    (= :f2 ((get events 0) :key))))

(check "parse f5 (CSI tilde)"
  (let [events (types/parse-input "\e[15~")]
    (= :f5 ((get events 0) :key))))

(check "parse f12 (CSI tilde)"
  (let [events (types/parse-input "\e[24~")]
    (= :f12 ((get events 0) :key))))

# --- Home/End ---

(check "parse home"
  (let [events (types/parse-input "\e[H")]
    (= :home ((get events 0) :key))))

(check "parse end"
  (let [events (types/parse-input "\e[F")]
    (= :end ((get events 0) :key))))

# --- Delete/Insert/PageUp/PageDown ---

(check "parse delete"
  (let [events (types/parse-input "\e[3~")]
    (= :delete ((get events 0) :key))))

(check "parse insert"
  (let [events (types/parse-input "\e[2~")]
    (= :insert ((get events 0) :key))))

(check "parse page-up"
  (let [events (types/parse-input "\e[5~")]
    (= :page-up ((get events 0) :key))))

(check "parse page-down"
  (let [events (types/parse-input "\e[6~")]
    (= :page-down ((get events 0) :key))))

# --- Shift-tab ---

(check "parse shift-tab"
  (let [events (types/parse-input "\e[Z")]
    (= :shift-tab ((get events 0) :key))))

# --- Alt+key ---

(check "parse alt-a"
  (let [events (types/parse-input "\ea")]
    (= :alt-a ((get events 0) :key))))

(check "parse alt-z"
  (let [events (types/parse-input "\ez")]
    (= :alt-z ((get events 0) :key))))

# --- SGR mouse ---

(check "parse SGR mouse press"
  (let [events (types/parse-input "\e[<0;10;5M")]
    (let [e (get events 0)]
      (and (= :mouse (e :type))
           (= 0 (e :button))
           (= 10 (e :col))
           (= 5 (e :row))
           (= :press (e :action))))))

(check "parse SGR mouse release"
  (let [events (types/parse-input "\e[<0;10;5m")]
    (= :release ((get events 0) :action))))

(check "parse SGR mouse right button"
  (let [events (types/parse-input "\e[<2;20;15M")]
    (and (= 2 ((get events 0) :button))
         (= 20 ((get events 0) :col))
         (= 15 ((get events 0) :row)))))

# --- UTF-8 ---

(check "parse 2-byte UTF-8"
  (let [events (types/parse-input "\xC3\xA9")] # é
    (and (= 1 (length events))
         (= :key ((get events 0) :type))
         (= "\xC3\xA9" ((get events 0) :key)))))

(check "parse 3-byte UTF-8"
  (let [events (types/parse-input "\xE2\x9C\x93")] # checkmark ✓
    (and (= 1 (length events))
         (= "\xE2\x9C\x93" ((get events 0) :key)))))

# --- Multiple events in one buffer ---

(check "multiple events: a + up-arrow + b"
  (let [events (types/parse-input "a\e[Ab")]
    (and (= 3 (length events))
         (= "a" ((get events 0) :key))
         (= :up ((get events 1) :key))
         (= "b" ((get events 2) :key)))))

(check "multiple printable chars"
  (let [events (types/parse-input "abc")]
    (and (= 3 (length events))
         (= "a" ((get events 0) :key))
         (= "b" ((get events 1) :key))
         (= "c" ((get events 2) :key)))))

# --- Empty buffer ---

(check "empty buffer returns empty array"
  (let [events (types/parse-input "")]
    (= 0 (length events))))

(printf "  %d tests passed" pass)
