# Layer 1: FFI bindings to libc for terminal control (POSIX)
# Supports macOS (arm64/x86_64) and Linux (x86_64)

(ffi/context nil)

# --- FFI bindings ---

(ffi/defbind tcgetattr :int [fd :int buf :ptr])
(ffi/defbind tcsetattr :int [fd :int action :int buf :ptr])
(ffi/defbind ioctl :int [fd :int request :ulong buf :ptr])
(ffi/defbind isatty :int [fd :int])
(ffi/defbind open :int [path :string flags :int])
(ffi/defbind close :int [fd :int])
(ffi/defbind read :long [fd :int buf :ptr count :ulong])
(ffi/defbind write :long [fd :int buf :ptr count :ulong])
(ffi/defbind poll :int [fds :ptr nfds :uint timeout :int])

# --- Platform detection ---

(def- os-type (os/which))

# --- termios constants (platform-specific) ---

(def- STDIN-FD 0)
(def- STDOUT-FD 1)

(def- TCSADRAIN 1)
(def- TCSAFLUSH 2)

# termios struct layout differs between macOS and Linux:
#
# macOS arm64 (72 bytes):
#   c_iflag  :u64   offset 0    c_oflag  :u64   offset 8
#   c_cflag  :u64   offset 16   c_lflag  :u64   offset 24
#   c_cc[20]        offset 32   c_ispeed :u64   offset 56
#   c_ospeed :u64   offset 64
#
# Linux x86_64 (60 bytes):
#   c_iflag  :u32   offset 0    c_oflag  :u32   offset 4
#   c_cflag  :u32   offset 8    c_lflag  :u32   offset 12
#   c_line   :u8    offset 16
#   c_cc[32]        offset 17   c_ispeed :u32   offset 52
#   c_ospeed :u32   offset 56

(def- linux? (= os-type :linux))

(def- FLAG-WIDTH (if linux? 4 8))
(def- TERMIOS-SIZE (if linux? 60 72))

(def- OFF-IFLAG 0)
(def- OFF-OFLAG (if linux? 4 8))
(def- OFF-CFLAG (if linux? 8 16))
(def- OFF-LFLAG (if linux? 12 24))
(def- OFF-CC (if linux? 17 32))

# Input flags (c_iflag)
(def- ICRNL 0x100)
(def- IXON (if linux? 0x400 0x200))
(def- BRKINT 0x02)
(def- INPCK 0x10)
(def- ISTRIP 0x20)

# Output flags (c_oflag)
(def- OPOST 0x1)

# Control flags (c_cflag)
(def- CS8 (if linux? 0x30 0x300))

# Local flags (c_lflag)
(def- ECHO 0x8)
(def- ICANON (if linux? 0x2 0x100))
(def- ISIG (if linux? 0x1 0x80))
(def- IEXTEN (if linux? 0x8000 0x400))

# c_cc indices
(def- VMIN (if linux? 6 16))
(def- VTIME (if linux? 5 17))

# ioctl
(def- TIOCGWINSZ (if linux? 0x5413 0x40087468))

# winsize struct: 4x unsigned short = 8 bytes
# { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel }
(def- WINSIZE-SIZE 8)

# --- State ---

(var- saved-termios nil)
(var- in-raw-mode false)

# --- Helpers ---

# Read a little-endian unsigned int from buffer (width bytes: 4 or 8)
(defn- read-flag [buf offset]
  (if linux?
    (do
      (var v (int/u64 0))
      (for i 0 4
        (set v (bor v (blshift (int/u64 (get buf (+ offset i))) (* i 8)))))
      v)
    (do
      (var v (int/u64 0))
      (for i 0 8
        (set v (bor v (blshift (int/u64 (get buf (+ offset i))) (* i 8)))))
      v)))

# Write a little-endian unsigned int into buffer (width bytes: 4 or 8)
(defn- write-flag [val buf offset]
  (def v (int/u64 val))
  (for i 0 FLAG-WIDTH
    (def byte-val (band (brshift v (* i 8)) 0xFF))
    (put buf (+ offset i) (int/to-number byte-val))))

(defn- flag-clear [buf offset & flags]
  (var current (read-flag buf offset))
  (each f flags
    (set current (band current (bnot (int/u64 f)))))
  (write-flag current buf offset))

(defn- flag-set [buf offset & flags]
  (var current (read-flag buf offset))
  (each f flags
    (set current (bor current (int/u64 f))))
  (write-flag current buf offset))

# --- Public API ---

(defn raw-mode?
  "Return true if the terminal is currently in raw mode."
  []
  in-raw-mode)

(defn enter-raw-mode
  "Put stdin into raw mode. Saves original termios for later restoration."
  []
  (when in-raw-mode (break))
  (assert (not= 0 (isatty STDIN-FD)) "stdin is not a tty")

  # Save original termios
  (set saved-termios (buffer/new-filled TERMIOS-SIZE 0))
  (assert (= 0 (tcgetattr STDIN-FD saved-termios)) "tcgetattr failed")

  # Copy to working buffer
  (def raw (buffer/new TERMIOS-SIZE))
  (buffer/push raw saved-termios)

  # Input flags: clear ICRNL IXON BRKINT INPCK ISTRIP
  (flag-clear raw OFF-IFLAG ICRNL IXON BRKINT INPCK ISTRIP)

  # Output flags: clear OPOST
  (flag-clear raw OFF-OFLAG OPOST)

  # Control flags: set CS8
  (flag-set raw OFF-CFLAG CS8)

  # Local flags: clear ECHO ICANON ISIG IEXTEN
  (flag-clear raw OFF-LFLAG ECHO ICANON ISIG IEXTEN)

  # c_cc: VMIN=0 VTIME=1 (read returns after 100ms if no input)
  (put raw (+ OFF-CC VMIN) 0)
  (put raw (+ OFF-CC VTIME) 1)

  (assert (= 0 (tcsetattr STDIN-FD TCSAFLUSH raw)) "tcsetattr failed")
  (set in-raw-mode true))

(defn exit-raw-mode
  "Restore the terminal to its original mode."
  []
  (when (not in-raw-mode) (break))
  (when saved-termios
    (tcsetattr STDIN-FD TCSADRAIN saved-termios)
    (set saved-termios nil))
  (set in-raw-mode false))

(def- O-RDONLY 0)

(defn get-terminal-size
  "Return [cols rows] of the terminal."
  []
  (def result
    (try
      (do
        # stty uses -F on Linux, -f on macOS
        (def flag (if linux? "-F" "-f"))
        (def proc (os/spawn ["stty" flag "/dev/tty" "size"] :p {:out :pipe}))
        (def out (string (:read (proc :out) :all)))
        (:wait proc)
        (def parts (string/split " " (string/trim out)))
        (when (>= (length parts) 2)
          (def rows (scan-number (get parts 0)))
          (def cols (scan-number (get parts 1)))
          (when (and rows cols (> rows 0) (> cols 0))
            [cols rows])))
      ([_] nil)))
  (if result
    result
    (do
      (def env-cols (os/getenv "COLUMNS"))
      (def env-rows (os/getenv "LINES"))
      (if (and env-cols env-rows)
        [(scan-number env-cols) (scan-number env-rows)]
        [80 24]))))

(defn open-tty
  "Open /dev/tty for reading. Returns a raw fd (integer)."
  []
  (def fd (open "/dev/tty" O-RDONLY))
  (assert (>= fd 0) "failed to open /dev/tty")
  fd)

(defn close-tty
  "Close a raw tty fd."
  [fd]
  (close fd))

# struct pollfd { int fd; short events; short revents; } = 8 bytes
# POLLIN = 0x0001
(def- POLLIN 0x0001)

(defn poll-tty
  "Wait up to timeout-ms for data on fd. Returns true if data is ready."
  [fd timeout-ms]
  (def pfd (buffer/new-filled 8 0))
  # fd (int32 LE at offset 0)
  (put pfd 0 (band fd 0xFF))
  (put pfd 1 (band (brshift fd 8) 0xFF))
  (put pfd 2 (band (brshift fd 16) 0xFF))
  (put pfd 3 (band (brshift fd 24) 0xFF))
  # events = POLLIN (int16 LE at offset 4)
  (put pfd 4 (band POLLIN 0xFF))
  (put pfd 5 (band (brshift POLLIN 8) 0xFF))
  (def ret (poll pfd 1 timeout-ms))
  (> ret 0))

(defn read-tty
  ```Blocking read from a raw fd. Returns a buffer of bytes read, or nil on timeout/error.
   Retries automatically if interrupted by a signal (EINTR).```
  [fd nbytes]
  (def buf (buffer/new-filled nbytes 0))
  (var n -1)
  (var retries 0)
  (while (and (< n 0) (< retries 3))
    (set n (int/to-number (read fd buf nbytes)))
    (++ retries))
  (if (> n 0)
    (buffer/slice buf 0 n)
    nil))

(defn write-stdout
  "Write a buffer directly to stdout fd 1."
  [buf]
  (write STDOUT-FD buf (length buf)))
