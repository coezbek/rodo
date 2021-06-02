require 'curses'

module Curses

  KEY_CTRL_RIGHT = Curses::REQ_SCR_FCHAR
  KEY_CTRL_LEFT = Curses::REQ_DEL_CHAR

  @@debug_win = nil

  def self.debug_win= debug_win
    @@debug_win = debug_win
  end

  def self.debug_win
    @@debug_win
  end

  def self.debug message
    if @@debug_win
      @@debug_win.puts message
      @@debug_win.refresh
    end
  end

  # Switch on bracketed paste mode
  # and reset it at end of application
  def self.bracketed_paste
    print("\x1b[?2004h")
    at_exit {
      print("\x1b[?2004l")
    }
  end

  module WindowExtensions

    # Create a subwindow inside this window which is padded by the given number n (lines and characters)
    def inset(n=1)
      subwin(maxy - 2 * n, maxx - 2 * n, begy + n, begx + n)
    end

    # Override box() to call box(0, 0)
    def box(*args)
      if args.size == 0
        super(0, 0)
      else
        super(*args)
      end
    end

    # Add the given string to this window and put the cursor on the next line
    def puts(string)
      if maxx - curx == string.length
        addstr(string)
      else
        addstr(string + "\n")
      end
    end

    # Return the current coordinates of the cursor [y,x]
    def getyx
      return [cury(), curx()]
    end

    # Add the given string to the top left borner of a box window
    def caption(string)
      p = getyx
      setpos(0,1)
      addstr(string)
      setpos(*p)
    end

    def addstr_with_cursor(line, cursor_x)
      line = line + " "

      Curses.debug "Before Cursor: '#{line[...cursor_x]}'"
      Curses.debug "Cursor_x: '#{cursor_x}'"

      cursor_x = 0 if cursor_x < 0
      cursor_x = line.size - 1 if cursor_x >= line.size

      addstr line[...cursor_x] if cursor_x > 0
      attron(Curses::A_REVERSE)
      addstr line[cursor_x]
      attroff(Curses::A_REVERSE)
      addstr(line[(cursor_x+1)..]) if cursor_x < line.size
      addstr("\n")
    end

    # Will read until the end of a bracketed paste marker "\x1b[201~"
    # Requires that the "\x1b[200~" start marker has already been processed.
    # The returned text does NOT include the end marker "200~"
    def get_paste_text
      pasted = ""
      loop do
        d = get_char2
        case d
        in csi: "201~" # Bracketed paste ended
          break
        else
          pasted += d
        end
      end
      return pasted
    end

    # Reads a Control Sequence Introducer (CSI) from `get_char`
    #
    # Requires that ANSI Control Sequence "\x1b[" has already been consumed.
    #
    # Assumes that there are no errors in the CSI.
    #
    # For CSI, or "Control Sequence Introducer" commands,
    # the ESC [ is followed by
    # 1.) any number (including none) of "parameter bytes" in the range
    #     0x30–0x3F (ASCII 0–9:;<=>?), then by
    # 2.) any number of "intermediate bytes" in the range
    #     0x20–0x2F (ASCII space and !"#$%&'()*+,-./), then finally by
    # 3.) a single "final byte" in the range
    #     0x40–0x7E (ASCII @A–Z[\]^_`a–z{|}~).
    #
    # From: https://handwiki.org/wiki/ANSI_escape_code
    def get_csi

      result = "".dup
      loop do
        c = get_char
        result += c
        if c.ord >= 0x40 && c.ord <= 0x7E
          return result
        end
      end

    end

    # Just like get_char, but will read \x1b[<csi>
    # return it as a hash { csi: ... }, 
    # everything else is just returned as-is
    def get_char2
      c = get_char
      case c
      when "\e" # ESC
        d = get_char
        case d
        when '['
          return { csi: get_csi }
        else
          Curses.unget_char(d)
          return "\e"
          # Curses.abort("Unhandled command sequence")
          # raise "¯\_(ツ)_/¯"
        end
      else
        return c
      end
    end

    # Just like get_char2, but will read csi: "200~" as bracketed paste and
    # return it as a hash { paste: <text> },
    # everything else is just returned as from get_char2
    def get_char3
      c = get_char2
      case c
      in csi: "200~" # Bracketed paste started
        return { paste: get_paste_text }
      else
        return c
      end
    end

    # Will take care of reading a string from the user, given the start_string
    def gets(start_string)

      line = start_string
      cursor_x = line.length
      start_pos = getyx

      loop do

        clear
        setpos(*start_pos)
        addstr_with_cursor(line, cursor_x)

        yield line

        char = get_char
        case char

        when CTRLC, CTRLC.chr, ESC, ESC.chr
          return :close

        when "\u0001" # CTRL+A
          cursor_x = 0

        when "\u0005" # CTRL+E
          cursor_x = line.length

        when Curses::KEY_LEFT
          cursor_x -= 1 if cursor_x > 0

        when Curses::KEY_RIGHT
          cursor_x += 1 if cursor_x < line.length - 1

        when Curses::KEY_DC, "\u0004" # DEL, CTRL+D
          if cursor_x < line.size
            line.slice!(cursor_x)
          end

        when Curses::KEY_BACKSPACE
          if cursor_x > 0
            line.slice!(cursor_x - 1)
            cursor_x -= 1
          end

        when ENTER, ENTER.chr
          return line

        when /[[:print:]]/

          line.insert(cursor_x, char)
          cursor_x += 1

        else
          Curses.debug "Char not handled: " + Curses::char_info(char)
        end

      end

    end
  end

  class Window
    prepend WindowExtensions
  end

  def self.cputs(string)
    w = stdscr.inset
    w.puts string
    w.getch
    w.close
  end

  # Enable bracketed paste mode and reset it upon exit
  def bracketed_paste
    print("\x1b[?2004h")
    at_exit {
      print("\x1b[?2004l")
    }
  end

  def self.char_info(char)

    case char
    when Integer
      key = Curses::ch2key(char)
      return "Char: #{char} - Class Integer " + (key != nil ? "Constant: #{key}" : "To chr(): #{char.chr}")

    # when String

    else
      return "Char: #{char.inspect} - Class: #{char.class}"
    end
  end

  def self.ch2key(ch)

    if !defined?(@@map)
      @@map = {}
      Curses.constants(false).each { |s|
        c = Curses.const_get(s)
        @@map[c] ||= []
        @@map[c] << s
      }
    end
    @@map[ch]
  end

  def self.abort(msg)

    Curses.close_screen
    puts "Traceback (most recent call last):"
    puts caller.each_with_index.map { |s, i| "#{(i+1).to_s.rjust(9)}: from #{s}" }.reverse
    puts msg
    Kernel.exit(-1)

  end

end