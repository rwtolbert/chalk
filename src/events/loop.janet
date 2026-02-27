# Layer 4: Event loop — synchronous tty reader using raw FFI read()
# read() returns within 100ms due to VMIN=0 VTIME=1 termios settings.

(import ../events/types)
(import ../platform/init :as platform)

(var- tty-fd nil)
(var- last-size nil)

(defn start
  "Open /dev/tty for raw reading."
  []
  (set tty-fd (platform/open-tty))
  (set last-size (platform/get-terminal-size)))

(defn read-events
  "Wait for input (up to 100ms), then return events.
   Generates resize events when terminal size changes."
  []
  (def events @[])

  # read() returns data immediately if available, or 0 bytes after 100ms
  (def bytes (platform/read-tty tty-fd 64))
  (when bytes
    (array/concat events (types/parse-input bytes)))

  # Check if terminal was resized
  (def size (platform/get-terminal-size))
  (when (not= size last-size)
    (set last-size size)
    (array/push events (types/resize-event (get size 0) (get size 1))))

  events)

(defn stop
  "Close tty fd."
  []
  (when tty-fd
    (platform/close-tty tty-fd)
    (set tty-fd nil)))
