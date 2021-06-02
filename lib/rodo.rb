# frozen_string_literal: true

require_relative "rodo/version"

#
# rodo.rb
#
# Keybindings:
#
#  n = New Todo
#  <space> or . = Toggle Todo
#  <up> <down> go to next in same hierarchy
#  <left, right> go to subtasks
#  <enter> edit current todo
#  p <n> = Postpone for <n> days. If <n> is left blank, postpone to tomorrow (config_postpone_days_default)
#  w <n> = Mark this entry as waiting for a response. This will mark this todo complete
#          but create a todo in the future (<n> days) to check for the result actually being complete
#          If <n> is left blank will postpone until next week (7 days, config_waiting_days_default)
#  t (today) = Create a new journal entry for the current date (today), marks all unfinished todos of the current day as [u] and copies them as
#          as empty todos [ ] to today.
#

require 'curses'
require 'fileutils'
require_relative 'rodo/curses_util'
require_relative 'rodo/rodolib'
require_relative 'rodo/commands'

CTRLC = 3
ENTER = 13
ESC = 27

class Rodo

  include Commands

  attr_accessor :file_name
  attr_accessor :win1, :win1b
  attr_accessor :cursor_line, :cursor_x, :current_day_index, :newly_added_line
  attr_accessor :journal
  attr_accessor :mode
  attr_accessor :debug

  def init
    Curses.ESCDELAY = 50        # 50 milliseconds (ESC is always a key, never a sequence until automatic)
    Curses.raw
    Curses.noecho               # Don't print user input
    Curses.nonl
    Curses.stdscr.keypad = true # Control keys should be returned as keycodes
    Curses.init_screen
    Curses.curs_set(0)          # Invisible cursor
    Curses.bracketed_paste      # From CursesUtils: Enable Bracketed Paste Mode

    if !Curses.has_colors?
      Curses.abort "Curses doesn't have color support in this TTY."
    else
      Curses.start_color
      Curses.colors.times { |i|
        Curses.init_pair(i, i, 0)
      }
    end

    # If no file is given, assume the user wants to edit "~/plan.md"
    if ARGV.empty?
      @file_name = "plan.md"
      Dir.chdir Dir.home
    else
      @file_name = ARGV[0]
    end
    File.write(@file_name, "# #{Time.now.strftime("%Y-%m-%d")}\n") if !File.exist?(@file_name)

    @journal = Journal.from_s(File.read(@file_name))
    @cursor_line = 0
    @cursor_x = 0
    @mode = :scroll
    @current_day_index = @journal.most_recent_index
    @newly_added_line = nil
    @debug = $DEBUG || $VERBOSE || ENV["BUNDLE_BIN_PATH"]
  end

  def main_loop

    status = init()
    return if status == :close

    begin

      build_windows()

      loop do
        render_windows()

        char = @win1::get_char3

        if char == Curses::KEY_RESIZE
          sleep(0.5)
          build_windows
          next
        end

        case char
        in paste:
          process_paste(paste)
        else
          status = process_input(char)
          return if status == :close
        end
      end

    ensure
      Curses.close_screen
    end
  end

  def build_windows

    @win1.close if @win1
    if Curses.debug_win
      Curses.debug_win.close
      Curses.debug_win = nil
    end

    # Building a static window
    @win1 = Curses::Window.new(Curses.lines, Curses.cols / (@debug ? 2 : 1), 0, 0)
    @win1.keypad = true
    @win1b = @win1.subwin(@win1.maxy - 2, @win1.maxx - 3, 1, 2)

    if @debug
      debug_win = Curses::Window.new(Curses.lines, Curses.cols / 2, 0, Curses.cols / 2)
      debug_win.box
      debug_win.caption "Debug information"
      debug_win.refresh
      Curses.debug_win = debug_win.inset
    end
  end

  def get_cmd(win, pos_y, pos_x, command_prototyp_list)

    size_y = 10
    size_x = [win.maxx - win.begx - 2 * pos_x - 2, 10].max

    cmd_win = Curses::Window.new(size_y + 2, size_x + 2, win.begy + pos_y, win.begx + pos_x)
    cmd_win.keypad = true
    cmd_win.box
    cmd_win.refresh
    inset = cmd_win.inset(1)
    inset.keypad = true
    result = inset.gets("> ".dup) { |s|

      if s =~ /^\s*\>\s*(.*)$/
        cmd = $1 # Remove prompt
        list = command_prototyp_list.dup
        if cmd.strip != ""
          list.select! { |c|
            if c.instance_of? Hash
              if c.has_key?(:regex)
                c[:regex] =~ cmd
              elsif c.has_key?(:description)
                c[:description].include?(cmd)
              else
                true
              end
            else
              c.include?(cmd)
            end
          }
        end
        #Curses.debug_win.puts cmd
        #Curses.debug_win.puts list.inspect
        #Curses.debug_win.refresh
        list.push "No matching commands" if list.empty?
        list.each { |c|
          if c.instance_of? Hash
            if c.has_key?(:description)
              inset.puts c[:description]
            end
          else
            inset.puts c
          end
        }
      end

    }

    # Curses.debug_win.puts "Result: #{result}"

    return result
  end

  def render_windows

    current_day = @journal.days[@current_day_index]

    @win1.box

    if Curses.debug_win
      Curses.debug_win.setpos(0, 0)
      Curses.debug_win.puts "Cursor @ #{@cursor_line}"
      Curses.debug_win.puts "Mode: #{@mode}"
      Curses.debug_win.refresh
    end

    # Next / prev Navigation
    has_next_day = @current_day_index > 0
    has_prev_day = @current_day_index < @journal.days.size - 1

    nav_str = []
    nav_str << "❮ #{@journal.days[@current_day_index + 1].date_name}"   if has_prev_day
    nav_str <<   "#{@journal.days[@current_day_index - 1].date_name} ❯" if has_next_day

    nav_str = nav_str.join(" ")
    @win1b.setpos(0, @win1b.maxx - nav_str.length - 1)
    @win1b.addstr(nav_str)

    # Contents of current day:
    lines = current_day.lines
    overflows = 0
    lines.each_with_index do |line, i|
      Curses.abort("Line #{i} is nil") if line == nil

      @win1b.setpos(i + overflows + 1, 0)
      if @cursor_line == i
        @win1b.attron(Curses.color_pair(255))
      else
        @win1b.attron(Curses.color_pair(246))
      end
      if (%i[scroll move].include?(@mode) && (@cursor_line != i || line.size != 0)) ||
         (%i[edit journalling].include?(@mode) && @cursor_line != i)
      then
         @win1b.puts line
      else
        line = line + " "

        if Curses.debug_win
          Curses.debug_win.puts "Before Cursor: '#{line[...@cursor_x]}'"
          Curses.debug_win.puts "Cursor_x: '#{@cursor_x}'"
          Curses.debug_win.refresh
        end

        @cursor_x = 0 if ![:edit, :journalling].include?(@mode)
        @cursor_x = line.size - 1 if @cursor_x >= line.size

        @win1b.addstr line[...@cursor_x] if @cursor_x > 0
        @win1b.attron(Curses::A_REVERSE)
        @win1b.addstr line[@cursor_x]
        @win1b.attroff(Curses::A_REVERSE)
        @win1b.addstr(line[(@cursor_x+1)..]) if @cursor_x < line.size
        @win1b.addstr("\n")
      end

      overflows += line.length / @win1b.maxx
    end

    # At the end switch color to normal again
    @win1b.attron(Curses.color_pair(246))
  end

  def process_paste(pasted)

    pasted.gsub! /\r\n?/, "\n"
    # Curses.debug "Pasted: #{pasted.inspect}"

    current_day = @journal.days[@current_day_index]
    lines = current_day.lines

    # Todo Clean-up Pasted Special characters (bullets)
    pasted.gsub! /^\t/, " " # Replace initial tabs with 1 space
    pasted.gsub! /\t/, "  " # Replace other tabs with 2 spaces
    pasted.gsub! /^(\s*)[•□○®◊§] /, "\\1- "

    case @mode
    when :journalling, :edit

      # When in journalling or edit mode, then pasting will split the current line

      pasted_lines = pasted.lines

      left  = lines[@cursor_line][0...@cursor_x]
      right = lines[@cursor_line][@cursor_x..-1]

      pasted_lines.each_with_index { |line, i|
        # On the first line, append to text left of cursor
        if i == 0
          lines[@cursor_line] = left + line
        else
          lines.insert(@cursor_line, line)
        end

        # On the last line, append existing text right of cursor
        if i == pasted_lines.size - 1
          @cursor_x = lines[@cursor_line].length
          lines[@cursor_line] += right
        else
          @cursor_line += 1
        end
      }

    when :scroll, :move
      # Insert each line after the current line
      pasted.each_line { |l|
        @cursor_line += 1
        lines.insert(@cursor_line, l)
      }
      @cursor_x = lines[@cursor_line].size

    else
      Curses.abort("Case not handled: #{@mode}");
    end
  end

  def process_input(char)

    current_day = @journal.days[@current_day_index]
    lines = current_day.lines

    case @mode

    when :journalling

      case char

      when CTRLC, CTRLC.chr
        return :close

      when Curses::KEY_UP
        @cursor_line -= 1 if @cursor_line > 0

      when Curses::KEY_DOWN
        @cursor_line += 1 if @cursor_line < lines.size - 1

      when "\u0001" # CTRL+A

        @cursor_x = 0

      when "\u0005" # CTRL+E

        @cursor_x = lines[@cursor_line].length

      when Curses::KEY_LEFT

        if @cursor_x == 0
          if @cursor_line > 0
            @cursor_line -= 1
            @cursor_x = lines[@cursor_line].length
          end
        else
         @cursor_x -= 1 if @cursor_x > 0
        end

      when Curses::KEY_RIGHT

        if @cursor_x >= lines[@cursor_line].length - 1
          if @cursor_line < lines.size - 1
            @cursor_line += 1
            @cursor_x = 0
          end
        else
          @cursor_x += 1 if @cursor_x < lines[@cursor_line].length - 1
        end

      when Curses::KEY_DC, "\u0004" # DEL, CTRL+D

        if @cursor_x >= lines[@cursor_line].size
          if @cursor_line < lines.size - 1
            lines[@cursor_line] += lines[@cursor_line + 1]
            lines.delete_at(@cursor_line + 1)
          end
        else
          lines[@cursor_line].slice!(@cursor_x)
        end
        win1b.clear

      when Curses::KEY_BACKSPACE

        if @cursor_x == 0 && @cursor_line > 0
          @cursor_line -= 1
          @cursor_x = lines[@cursor_line].length
          lines[@cursor_line] += lines[@cursor_line + 1]
          lines.delete_at(@cursor_line + 1)
        elsif @cursor_x > 0
          lines[@cursor_line].slice!(@cursor_x - 1)
          @cursor_x -= 1
        end

      when "\v" # CTRL K
        if lines.size > 1
          lines.delete_at(@cursor_line)
          @cursor_line -= 1 if @cursor_line >= lines.size
        else
          lines[0] = "".dup
        end
        @win1b.clear

      when ENTER, ENTER.chr

        left  = lines[@cursor_line][0...@cursor_x]
        right = lines[@cursor_line][@cursor_x..-1]

        # If line to the left of cursor starts with "- [ ]" or with a star or dash
        if /^(?<lead>\s+[*-])(?<option>\s\[.\]\s?)?(?<rest>.*?)$/ =~ left && !(right =~ /^\s+[*-]/)

          if rest.strip.length == 0 and right.strip.length == 0
            # line is empty, except for */-/[ ]
            right = nil
            # unindent
            if /^\s\s(?<lead2>.*)$/ =~ lead
              lead = lead2
            else
              lead = ""
              option = ""
            end
            left = lead + option
          else
            if option =~ /^\s\[.\]/
              option = " [ ]"
            end
          end

          option = "" if !option
          lead = lead + option.rstrip + " "
          right = lead + right.lstrip if right
          @cursor_x = lead.length
        else
          @cursor_x = 0
        end

        lines[@cursor_line] = left
        if right != nil
          @cursor_line += 1
          lines.insert(@cursor_line, right)
        end
      when ESC, ESC.chr

        @mode = :scroll
        @journal.days[@current_day_index] = TodoDay.new(lines) # Reparse day after edit

      when /[[:print:]]/

        lines[@cursor_line].insert(@cursor_x, char)
        @cursor_x += 1

      when "\t", "\t".ord
        if lines[@cursor_line] =~ /\s*[-+*]/
          lines[@cursor_line].sub!(/^/, "  ")
          @cursor_x += 2
        end

      when Curses::KEY_BTAB
        if lines[@cursor_line] =~ /(  |\t)\s*[-+*]/
          lines[@cursor_line].sub!(/^(  |\t)/, "")
          @cursor_x -= 2
          @cursor_x = 0 if @cursor_x < 0
        end

      else
        if Curses.debug_win
          Curses.debug_win.puts "Char not handled: " + Curses::char_info(char)
          Curses.debug_win.refresh
        end
      end

    when :edit

      case char

      when CTRLC, CTRLC.chr
        return :close

      #when CTRLA then buffer.beginning_of_line
      #when CTRLE then buffer.end_of_line
      #when Curses::KEY_UP
      #  @cursor_line -= 1 if @cursor_line > 0
      #when Curses::KEY_DOWN
      #  @cursor_line += 1 if @cursor_line < lines.size - 1

      when "\u0001" # CTRL+A

        @cursor_x = 0

      when "\u0005" # CTRL+E

        @cursor_x = lines[@cursor_line].length

      when Curses::KEY_LEFT

        @cursor_x -= 1 if @cursor_x > 0

      when Curses::KEY_RIGHT

        @cursor_x += 1 if @cursor_x < lines[@cursor_line].length - 1

      when Curses::KEY_DC, "\u0004" # DEL, CTRL+D

        if @cursor_x < lines[@cursor_line].size
          lines[@cursor_line].slice!(@cursor_x)
        end

      when Curses::KEY_BACKSPACE
        if @cursor_x > 0
          lines[@cursor_line].slice!(@cursor_x - 1)
          @cursor_x -= 1
        end

      when ENTER, ENTER.chr
        @mode = :scroll
        @newly_added_line = nil
        @journal.days[@current_day_index] = TodoDay.new(lines) # Reparse day after edit

      when ESC, ESC.chr
        # When pressing ESC after an insert, which didn't change anything then undo the insertion
        if @newly_added_line && lines[@cursor_line] == @newly_added_line
          lines.delete_at(@cursor_line)
          @cursor_line -= 1 if @cursor_line >= lines.size
          @win1b.clear
        end
        # Debug:
        # Curses.debug "Lines[@cursor_line] == #{lines[@cursor_line].inspect }, @newly_added_line == #{@newly_added_line.inspect}"

        @mode = :scroll
        @newly_added_line = nil
        @journal.days[@current_day_index] = TodoDay.new(lines) # Reparse day after edit

      when /[[:print:]]/

        lines[@cursor_line].insert(@cursor_x, char)
        # Curses.setpos(@cursor_line + 2, lines[@cursor_line].length + 2)
        @cursor_x += 1

      when "\t", "\t".ord
        if lines[@cursor_line] =~ /\s*[-+*]/
          lines[@cursor_line].sub!(/^/, "  ")
          @cursor_x += 2
        end

      when Curses::KEY_BTAB
        if lines[@cursor_line] =~ /(  |\t)\s*[-+*]/
          lines[@cursor_line].sub!(/^(  |\t)/, "")
          @cursor_x -= 2
          @cursor_x = 0 if @cursor_x < 0
        end

      else
        if Curses.debug_win
          Curses.debug_win.puts "Char not handled: " + Curses::char_info(char)
          Curses.debug_win.refresh
        end
      end

    when :scroll

      case char
        when 'q'
          FileUtils.mkdir_p "_bak"
          FileUtils.cp(@file_name, File.join(File.dirname(@file_name), "_bak", File.basename(@file_name) + "-#{Time.now.strftime("%Y-%m-%dT%H-%M-%S")}.bak"))
          File.write(@file_name, @journal.to_s)

          return :close

        when '~'
          @debug = !@debug
          build_windows

        when CTRLC, CTRLC.chr
          return :close

        #when CTRLA then buffer.beginning_of_line
        #when CTRLE then buffer.end_of_line
        when Curses::KEY_UP
          @cursor_line -= 1 if @cursor_line > 0

        when Curses::KEY_DOWN
          @cursor_line += 1 if @cursor_line < lines.size - 1

        when Curses::KEY_RIGHT then
          @current_day_index -= 1 if @current_day_index > 0
          @win1b.clear

        when Curses::KEY_LEFT then
          @current_day_index += 1 if @current_day_index < @journal.days.size - 1
          @win1b.clear

        when "\t", "\t".ord
          if lines[@cursor_line] =~ /\s*[-+*]/
            lines[@cursor_line].sub!(/^/, "  ")
          end

        when Curses::KEY_F1

          cmd = get_cmd(@win1b, 1, 1, @command_prototyp_list)
          if cmd == :close
            # do nothing, because user closed window
          elsif cmd =~ /^\s*>\s*(.*)$/

            cmd = $1 # Remove prompt

            # Search list of available commands for a match and run the cmd
            @command_prototyp_list.find { |command_prototype|
              case command_prototype
              in regex: r, do_cmd: c
                if r =~ cmd
                  c.call(cmd, lines, current_day)
                  next true
                else
                  next false
                end

              in description: d
                if d.start_with? cmd.strip
                  Curses.unget_char(cmd.strip)
                  next true
                end
                next false

              in String
                if command_prototype.start_with? cmd.strip
                  Curses.unget_char(cmd.strip)
                  next true
                end
                next false
              else
                if Curses.debug_win
                  Curses.debug_win.puts "Unknown command enter from F1: #{cmd}"
                  Curses.debug_win.refresh
                end
              end
            }
          end

        when Curses::KEY_BTAB
          if lines[@cursor_line] =~ /(  |\t)\s*[-+*]/
            lines[@cursor_line].sub!(/^(  |\t)/, "")
          end

          #when Curses::KEY_BACKSPACE then
        #  buffer.remove_char_before_cursor
        #when ENTER then buffer.new_line
        when '.', 'x'
          if lines[@cursor_line] =~ /\[\s\]/
            lines[@cursor_line].gsub!(/\[\s\]/, "[x]")
          elsif lines[@cursor_line] =~ /\[[xX]\]/
            lines[@cursor_line].gsub!(/\[[xX]\]/, "[ ]")
          end
        #when /[[:print:]]/ then buffer.add_char(char)

        when '2'
          # ★

        when 'e' # Edit
          @mode = :journalling
          @cursor_x = lines[@cursor_line].length

        when 'm' # Move
          @mode = :move

        when 'i' # Insert
          @cursor_line = 1 if @cursor_line == 0
          @newly_added_line = current_day.line_prototype(@cursor_line)
          lines.insert(@cursor_line, @newly_added_line.dup)
          @mode = :edit
          @cursor_x = lines[@cursor_line].size

        when ENTER, ENTER.chr
          @mode = :edit
          @cursor_x = lines[@cursor_line].size

        when 'a' # append

          @newly_added_line = current_day.line_prototype(@cursor_line)
          @cursor_line += 1
          lines.insert(@cursor_line, @newly_added_line.dup)
          @mode = :edit
          @cursor_x = lines[@cursor_line].size

        when 't' # t(oday)

          current_day = current_day.close
          insertion_index = @journal.days.index { |d| current_day.date >= d.date } || 0
          @journal.days.insert(insertion_index, current_day)
          @current_day_index = insertion_index
          @win1b.clear

        when 'k' # kill
          if lines.size > 1
            lines.delete_at(@cursor_line)
            @cursor_line -= 1 if @cursor_line >= lines.size
          else
            lines[0] = "".dup
          end
          @win1b.clear

        when 'w' # waiting

          if lines[@cursor_line] =~ /\[\s\]/

            line_to_wait_for = lines[@cursor_line].dup

            if !(line_to_wait_for =~ / - ⌛ since \d\d\d\d-\d\d-\d\d$/) && current_day.date
              line_to_wait_for = line_to_wait_for.rstrip + " - ⌛ since #{current_day.date_name}"
            end

            # Get target day (and create if it doesn't exist) and add there
            postpone_day = @journal.postpone(current_day, 7)
            postpone_day.lines.insert(1, line_to_wait_for)

            # Adjust @current_day_index if a new day was created
            @current_day_index += 1 if current_day != @journal.days[@current_day_index]

            # Add hourclass here
            lines[@cursor_line].gsub!(/\[\s\]/, "[⌛]")

          end

        when 'p' # postpone

          postpone(lines, current_day, 1)

        else
          if Curses.debug_win
            Curses.debug_win.puts "Char not handled: " + Curses::char_info(char)
            Curses.debug_win.refresh
          end
      end

    when :move

      case char
        when 'q'
          FileUtils.mkdir_p "_bak"
          FileUtils.cp(@file_name, "_bak/" + @file_name + "-#{Time.now.strftime("%Y-%m-%dT%H-%M-%S")}.bak")
          File.write(@file_name, @journal.to_s)

          return :close

        when CTRLC, CTRLC.chr
          return :close

        when Curses::KEY_UP

          if @cursor_line > 0
            lines[@cursor_line], lines[@cursor_line - 1] = lines[@cursor_line - 1], lines[@cursor_line]
            @cursor_line -= 1
          end

        when Curses::KEY_DOWN

          if @cursor_line < lines.size - 1
            lines[@cursor_line], lines[@cursor_line + 1] = lines[@cursor_line + 1], lines[@cursor_line]
            @cursor_line += 1
          end

        when "\t", "\t".ord, Curses::KEY_RIGHT
          if lines[@cursor_line] =~ /\s*[-+*]/
            lines[@cursor_line].sub!(/^/, "  ")
          end

        when Curses::KEY_BTAB, Curses::KEY_LEFT
          if lines[@cursor_line] =~ /(  |\t)\s*[-+*]/
            lines[@cursor_line].sub!(/^(  |\t)/, "")
          end

        when ENTER, ENTER.chr, ESC, ESC.chr
          @mode = :scroll

        else
          Curses.debug "Char not handled: " + Curses::char_info(char)
      end
    else
      Curses.abort "Mode #{@mode} not handled"
    end

    return nil
  end

  def postpone(lines, current_day, n)

    if lines[@cursor_line] =~ /\[\s\]/

      # Get target day (and create if it doesn't exist) and add there
      postpone_day = @journal.postpone(current_day, n)
      postpone_day.lines.insert(1, lines[@cursor_line])

      # Adjust @current_day_index if a new day was created
      @current_day_index += 1 if current_day != @journal.days[@current_day_index]

      # Delete here
      if lines.size > 1
        lines.delete_at(@cursor_line)
        @cursor_line -= 1 if @cursor_line >= lines.size
      else
        lines[0] = "".dup
      end
      @win1b.clear

    end
  end

end

if __FILE__==$0
  Rodo.new.main_loop
end