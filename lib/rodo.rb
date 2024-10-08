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
require_relative 'rodo/clipboard'
require_relative "rodo/backup"

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

  def process_args

    @debug = false
    @future = false
    @simulate = nil

    # Process ARGS:
    #   -d = Debug
    #   -f = Show Future Window
    #   -r=YYYYMMDD = Simulate Recurring Tasks for the given date and exit
    while ARGV[0] =~ /^-+(\w)(.*)$/
      case $1
      when "d"
        @debug = true
      when "f"
        @future = true
      when "r"
        # Simulate Recurring Tasks: "-r=YYYYMMDD" will set the current day to the given date and return the result of closing the last day
        @simulate = $2.split("=")[1]
      else
        Curses.abort("Unknown option: #{$1}")
      end
      ARGV.shift
    end

    # If no file is given, assume the user wants to edit "~/plan.md"
    if ARGV.empty?
      @file_name = "plan.md"
      Dir.chdir Dir.home
    else
      @file_name = ARGV[0]
    end

    return nil
  end

  def init

    # If file does not exist
    File.write(@file_name, "# #{Time.now.strftime("%Y-%m-%d")}\n") if !File.exist?(@file_name)

    @journal = Journal.from_s(File.read(@file_name))

    @rec_file_name = "recurrence.md"
    @journal.recurrences = Recurrences.from_s(File.read(@rec_file_name)) if File.exist?(@rec_file_name)

    if @simulate
      require 'timecop'
      Timecop.freeze(Time.parse(@simulate)) do 
        newDay = @journal.close(@journal.days[@journal.most_recent_open_index])
        puts @journal.days[newDay].to_s
        exit(0)        
      end      
    end
    
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

    @cursor = Cursor.new(@journal)
    @cursor.day = @journal.most_recent_open_index
    @mode = :scroll
    @newly_added_line = nil
    
    @debug = @debug || $DEBUG || $VERBOSE # || ENV["BUNDLE_BIN_PATH"]
  end

  def main_loop

    status = process_args
    return if status == :close

    status = check_for_stale_backup_and_recover
    return if status == :close

    status = init
    return if status == :close

    begin

      build_windows()

      loop do
        render_windows()

        char = @win1::get_char3

        # If the user didn't type a key for 15 seconds or after 5 minutes, auto-save to the backup file
        if char == nil || seconds_since_last_backup >= BACKUP_MAX_BACKUP_INTERVAL_SECONDS
          backup_auto_save
          next if char == nil
        end

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

  def create_bak
    FileUtils.mkdir_p "_bak"
    FileUtils.cp(@file_name,
      File.join(
        File.dirname(@file_name),
        "_bak",
        File.basename(@file_name) + "-#{Time.now.strftime("%Y-%m-%dT%H-%M-%S")}.bak"))
  end

  def save
    create_bak

    to_write = @journal.to_s
    if File.read(@file_name) != to_write
      File.write(@file_name, to_write)
    end

    if File.exist?(backup_file_name)
      if File.read(@file_name) == to_write
        File.delete(backup_file_name)
      else
        # Saving failed
        # Make sure the backup file has a more recent modification date
        FileUtils.touch(backup_file_name)
      end
    end

    return :close
  end

  def close_without_save
    File.delete(backup_file_name) if File.exist?(backup_file_name)
    return :close
  end

  def build_windows

    if @win1
      @win1.close
      @win1 = nil
    end
    if Curses.debug_win
      Curses.debug_win.close
      Curses.debug_win = nil
    end
    if Curses.future_win
      Curses.future_win.close
      Curses.future_win = nil
    end

    cols = Curses.cols / (1 + (@debug ? 1 : 0) + (@future ? 1 : 0))
    cur_col = 0

    # Building a static window
    @win1 = Curses::Window.new(Curses.lines, cols, 0, cur_col)
    @win1.keypad = true
    @win1.timeout = BACKUP_INACTIVITY_INTERVAL_SECONDS * 1000 # Use 15s inactivity as an indicator for saving automatically

    @win1b = @win1.subwin(@win1.maxy - 2, @win1.maxx - 3, 1, 2)

    cur_col += cols

    if @future
      future_win = Curses::Window.new(Curses.lines, @debug ? cols : Curses.cols - cols, 0, cur_col)
      future_win.box
      future_win.caption "Upcoming todos"
      future_win.refresh
      Curses.future_win = future_win.inset

      cur_col += cols
    end

    if @debug
      debug_win = Curses::Window.new(Curses.lines, Curses.cols - cur_col, 0, cur_col)
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

  def render_debug_window
    if @debug && Curses.debug_win
      Curses.debug_win.setpos(0, 0)
      Curses.debug_win.puts "Cursor @ #{@cursor.line}"
      Curses.debug_win.puts "Mode: #{@mode}"
      Curses.debug_win.refresh
    end
  end

  def render_future_window
    if @future && Curses.future_win

      upcoming_lines = @journal.upcoming(@cursor.day)

      if @upcoming_lines != upcoming_lines
        Curses.future_win.clear
        Curses.future_win.setpos(1, 0)
        if upcoming_lines
          raise Exception.new(upcoming_lines.inspect) if !(upcoming_lines.instance_of? String)
          Curses.future_win.puts upcoming_lines
        else
          Curses.future_win.puts "No upcoming todos"
        end
        Curses.future_win.refresh
        @upcoming_lines = upcoming_lines
      end
    end
  end


  def render_windows

    current_day = @journal.days[@cursor.day]
    @win1.box
    render_debug_window

    render_future_window

    # Next / prev Navigation
    has_next_day = @cursor.day > 0
    has_prev_day = @cursor.day < @journal.days.size - 1

    nav_str = []
    nav_str << "❮ #{@journal.days[@cursor.day + 1].date_name}"   if has_prev_day
    nav_str <<   "#{@journal.days[@cursor.day - 1].date_name} ❯" if has_next_day

    nav_str = nav_str.join(" ")
    @win1b.setpos(0, @win1b.maxx - nav_str.length - 1)
    @win1b.addstr(nav_str)

    if @mode == :focus

      line = current_day.lines[@cursor.line]

      @win1b.puts_center(line)

    else

      # Contents of current day:
      lines = current_day.lines
      overflows = 0
      lines.each_with_index do |line, i|
        Curses.abort("Line #{i} is nil") if line == nil

        @win1b.setpos(i + overflows + 1, 0)
        if @cursor.line == i
          @win1b.attron(Curses.color_pair(255))
        else
          @win1b.attron(Curses.color_pair(246))
        end
        if (%i[scroll move focus].include?(@mode) && (@cursor.line != i || line.size != 0)) ||
          (%i[edit journalling].include?(@mode) && @cursor.line != i)
        then
          @win1b.puts line
        else
          line = line + " "

          if Curses.debug_win
            Curses.debug_win.puts "Before Cursor: '#{line[...@cursor.x]}'"
            Curses.debug_win.puts "Cursor_x: '#{@cursor.x}'"
            Curses.debug_win.refresh
          end

          @cursor.x = 0 if ![:edit, :journalling].include?(@mode)
          @cursor.x = line.size - 1 if @cursor.x >= line.size

          @win1b.addstr line[...@cursor.x] if @cursor.x > 0
          @win1b.attron(Curses::A_REVERSE)
          @win1b.addstr line[@cursor.x]
          @win1b.attroff(Curses::A_REVERSE)
          @win1b.addstr(line[(@cursor.x+1)..]) if @cursor.x < line.size
          @win1b.addstr("\n")
        end

        overflows += line.length / @win1b.maxx
      end

      # At the end switch color to normal again
      @win1b.attron(Curses.color_pair(246))
    end
  end

  def process_html_paste(html, target: :txt)

    require 'reverse_markdown'
    markdown = ReverseMarkdown.convert html, unknown_tags: :bypass
    markdown.gsub!(/&nbsp;|Â/, " ")

    # Curses.debug "Markdown: #{markdown.inspect}"
    
    if target == :txt
      require 'redcarpet'
      require 'redcarpet/render_strip'    
      return Redcarpet::Markdown.new(Redcarpet::Render::StripDown).render(markdown)
    else
      return markdown
    end

  end

  def process_paste(pasted)

    # If there is HTML on the clipboard, prefer this.
    clip = Clipboard.get(:auto)
    html = clip[:type]
    Curses.debug "Pasted: #{clip.inspect}"
    if clip[:type] == :html
      pasted = process_html_paste(clip[:content], target: :md)
    else
      pasted = clip[:content]
    end

    # Normalize line endings 
    pasted.gsub! /\r\n?/ , "\n"
    # Curses.debug "Pasted: #{pasted.inspect}"

    current_day = @journal.days[@cursor.day]
    lines = current_day.lines

    # Todo Clean-up Pasted Special characters (bullets)
    pasted.gsub! /^\t/, " " # Replace initial tabs with 1 space
    pasted.gsub! /\t/, "  " # Replace other tabs with 2 spaces
    pasted.gsub! /^(\s*)[•□○®◊§] /, "\\1- " # Replace bullets with dashes
    pasted.gsub! /^(\s*)[✓✔✗✘] /, "\\1- [x] " # Replace checkmarks with [x]


    case @mode
    when :journalling, :edit

      # When in journalling or edit mode, then pasting will split the current line

      pasted_lines = pasted.lines

      left  = lines[@cursor.line][0...@cursor.x]
      right = lines[@cursor.line][@cursor.x..-1]

      pasted_lines.each_with_index { |line, i|
        # On the first line, append to text left of cursor
        if i == 0
          lines[@cursor.line] = left + line
        else
          lines.insert(@cursor.line, line)
        end

        # On the last line, append existing text right of cursor
        if i == pasted_lines.size - 1
          @cursor.x = lines[@cursor.line].length
          lines[@cursor.line] += right
        else
          @cursor.line += 1
        end
      }

    when :scroll, :move
      # Insert each line after the current line
      pasted.each_line { |l|
        @cursor.line += 1
        lines.insert(@cursor.line, l)
      }
      @cursor.x = lines[@cursor.line].size

    else
      Curses.abort("Case not handled: #{@mode}");
    end
  end

  def process_input(char)

    current_day = @journal.days[@cursor.day]
    lines = current_day.lines

    case @mode

    when :focus

      case char
      when '.', 'x', ' '
        if lines[@cursor.line] =~ /\[\s\]/
          lines[@cursor.line].gsub!(/\[\s\]/, "[x]")
          set_dirty
        elsif lines[@cursor.line] =~ /\[[xX>]\]/
          lines[@cursor.line].gsub!(/\[[xX>]\]/, "[ ]")
          set_dirty
        end

      when '-'
        if lines[@cursor.line] =~ /\[\s\]/
          lines[@cursor.line].gsub!(/\[\s\]/, "[-]")
          set_dirty
        elsif lines[@cursor.line] =~ /\[-\]/
          lines[@cursor.line].gsub!(/\[-\]/, "[ ]")
          set_dirty
        end
      else
        @mode = :scroll
        @win1b.clear
      end

    when :journalling

      case char

      when CTRLC, CTRLC.chr
        return close_without_save

      when Curses::KEY_UP
        @cursor.line -= 1 if @cursor.line > 0

      when Curses::KEY_DOWN
        @cursor.line += 1 if @cursor.line < lines.size - 1

      when "\u0001" # CTRL+A

        @cursor.x = 0

      when "\u0005" # CTRL+E

        @cursor.x = lines[@cursor.line].length

      when Curses::KEY_LEFT

        if @cursor.x == 0
          if @cursor.line > 0
            @cursor.line -= 1
            @cursor.x = lines[@cursor.line].length
          end
        else
         @cursor.x -= 1 if @cursor.x > 0
        end

      when Curses::KEY_RIGHT

        if @cursor.x >= lines[@cursor.line].length
          if @cursor.line < lines.size - 1
            @cursor.line += 1
            @cursor.x = 0
          end
        else
          @cursor.x += 1 if @cursor.x < lines[@cursor.line].length
        end

      when Curses::KEY_CTRL_LEFT

        if @cursor.x == 0
          if @cursor.line > 0
            @cursor.line -= 1
            @cursor.x = lines[@cursor.line].length
          end
        end

        left = lines[@cursor.line][0...@cursor.x]
        if /\b?((^|\S+)\s*)$/ =~ left
          @cursor.x -= $1.length
        end

      when Curses::KEY_CTRL_RIGHT

        if @cursor.x >= lines[@cursor.line].length - 1
          if @cursor.line < lines.size - 1
            @cursor.line += 1
            @cursor.x = 0
          end
        end
        right = lines[@cursor.line][@cursor.x..-1]
        if /^(\s*\S+\b?\s*)/ =~ right
          @cursor.x += $1.length
        end

      when Curses::KEY_DC, "\u0004" # DEL, CTRL+D

        if @cursor.x >= lines[@cursor.line].size
          if @cursor.line < lines.size - 1
            lines[@cursor.line] += lines[@cursor.line + 1]
            lines.delete_at(@cursor.line + 1)
            @win1b.clear
            set_dirty
          end
        else
          lines[@cursor.line].slice!(@cursor.x)
          @win1b.clear
          set_dirty
        end

      when Curses::KEY_BACKSPACE

        if @cursor.x == 0 && @cursor.line > 0
          @cursor.line -= 1
          @cursor.x = lines[@cursor.line].length
          lines[@cursor.line] += lines[@cursor.line + 1]
          lines.delete_at(@cursor.line + 1)
          @win1b.clear
          set_dirty
        elsif @cursor.x > 0
          lines[@cursor.line].slice!(@cursor.x - 1)
          @cursor.x -= 1
          @win1b.clear
          set_dirty
        end

      when "\v" # CTRL K
        if lines.size > 1
          lines.delete_at(@cursor.line)
          @cursor.line -= 1 if @cursor.line >= lines.size
        else
          lines[0] = "".dup
        end
        @win1b.clear
        set_dirty

      when ENTER, ENTER.chr

        left  = lines[@cursor.line][0...@cursor.x]
        right = lines[@cursor.line][@cursor.x..-1]

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
          @cursor.x = lead.length
        else
          @cursor.x = 0
        end

        lines[@cursor.line] = left
        if right != nil
          lines.insert(@cursor.line + 1, right)
          @cursor.line += 1
        end
        set_dirty

      when ESC, ESC.chr

        @mode = :scroll
        @journal.days[@cursor.day] = TodoDay.new(lines) # Reparse day after edit

      when /[[:print:]]/

        lines[@cursor.line].insert(@cursor.x, char)
        @cursor.x += 1
        set_dirty

      when "\t", "\t".ord
        if lines[@cursor.line] =~ /\s*[-+*]/
          lines[@cursor.line].sub!(/^/, "  ")
          @cursor.x += 2
          set_dirty
        end

      when Curses::KEY_BTAB
        if lines[@cursor.line] =~ /(  |\t)\s*[-+*]/
          lines[@cursor.line].sub!(/^(  |\t)/, "")
          @cursor.x -= 2
          @cursor.x = 0 if @cursor.x < 0
          set_dirty
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
        return close_without_save

      when "\u0001" # CTRL+A

        @cursor.x = 0

      when "\u0005" # CTRL+E

        @cursor.x = lines[@cursor.line].length

      when Curses::KEY_LEFT

        @cursor.x -= 1 if @cursor.x > 0

      when Curses::KEY_RIGHT

        @cursor.x += 1 if @cursor.x < lines[@cursor.line].length

      when Curses::KEY_CTRL_LEFT

        left = lines[@cursor.line][0...@cursor.x]
        if /((^|\w+?|\W+?)\s*)$/ =~ left
          @cursor.x -= $1.length
        end

      when Curses::KEY_CTRL_RIGHT

        right = lines[@cursor.line][@cursor.x..-1]
        if /^(\s*|\S+\s*)/ =~ right
          @cursor.x += $1.length
        end

      when Curses::KEY_DC, "\u0004" # DEL, CTRL+D

        if @cursor.x < lines[@cursor.line].size
          lines[@cursor.line].slice!(@cursor.x)
          set_dirty
        end

      when Curses::KEY_BACKSPACE
        if @cursor.x > 0
          lines[@cursor.line].slice!(@cursor.x - 1)
          @cursor.x -= 1
          set_dirty
        end

      when ENTER, ENTER.chr
        @mode = :scroll
        @newly_added_line = nil
        @journal.days[@cursor.day] = TodoDay.new(lines) # Reparse day after edit

      when ESC, ESC.chr
        # When pressing ESC after an insert, which didn't change anything then undo the insertion
        if @newly_added_line && lines[@cursor.line] == @newly_added_line
          lines.delete_at(@cursor.line)
          @cursor.line -= 1 if @cursor.line >= lines.size
          @win1b.clear
          set_dirty
        end
        # Debug:
        # Curses.debug "Lines[@cursor.line] == #{lines[@cursor.line].inspect }, @newly_added_line == #{@newly_added_line.inspect}"

        @mode = :scroll
        @newly_added_line = nil
        @journal.days[@cursor.day] = TodoDay.new(lines) # Reparse day after edit

      when /[[:print:]]/

        lines[@cursor.line].insert(@cursor.x, char)
        # Curses.setpos(@cursor.line + 2, lines[@cursor.line].length + 2)
        @cursor.x += 1

      when "\t", "\t".ord
        if lines[@cursor.line] =~ /\s*[-+*]/
          lines[@cursor.line].sub!(/^/, "  ")
          @cursor.x += 2
          set_dirty
        end

      when Curses::KEY_BTAB
        if lines[@cursor.line] =~ /(  |\t)\s*[-+*]/
          lines[@cursor.line].sub!(/^(  |\t)/, "")
          @cursor.x -= 2
          @cursor.x = 0 if @cursor.x < 0
          set_dirty
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
          return self.save

        when CTRLC, CTRLC.chr
          return close_without_save

        when '~'
          @debug = !@debug
          build_windows

        when '^'
          @future = !@future
          @upcoming_lines = nil
          build_windows

        when Curses::KEY_UP
          @cursor.line -= 1 if @cursor.line > 0

        when Curses::KEY_DOWN
          @cursor.line += 1 if @cursor.line < lines.size - 1

        when Curses::KEY_RIGHT then
          @cursor.day -= 1 if @cursor.day > 0
          @win1b.clear

        when Curses::KEY_LEFT then
          @cursor.day += 1 if @cursor.day < @journal.days.size - 1
          @win1b.clear

        when "\t", "\t".ord
          if lines[@cursor.line] =~ /\s*[-+*]/
            lines[@cursor.line].sub!(/^/, "  ")
            set_dirty
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
          if lines[@cursor.line] =~ /(  |\t)\s*[-+*]/
            lines[@cursor.line].sub!(/^(  |\t)/, "")
            set_dirty
          end

        #when ENTER then buffer.new_line
        when '.', 'x', ' '
          if lines[@cursor.line] =~ /\[\s\]/
            lines[@cursor.line].gsub!(/\[\s\]/, "[x]")
            set_dirty
          elsif lines[@cursor.line] =~ /\[[xX>]\]/
            lines[@cursor.line].gsub!(/\[[xX>]\]/, "[ ]")
            set_dirty
          end

        when '-'
          if lines[@cursor.line] =~ /\[\s\]/
            lines[@cursor.line].gsub!(/\[\s\]/, "[-]")
            set_dirty
          elsif lines[@cursor.line] =~ /\[-\]/
            lines[@cursor.line].gsub!(/\[-\]/, "[ ]")
            set_dirty
          end
        #when /[[:print:]]/ then buffer.add_char(char)

        # Focus mode
        when '1'
          @mode = :focus
          @win1b.clear

        # Star Toggle # ★
        when '2'

          # If line to the left of cursor starts with "- [ ]" or with a star or dash
          if /^(?<lead>\s+[*-]\s)(?<option>\[.\]\s)?(?<star>★\s)?(?<rest>.*?)$/ =~ lines[@cursor.line]

            if star == nil
              star = "★ "
            else
              star = ""
            end
            lines[@cursor.line] = [lead, option, star, rest].join('')
            set_dirty
          end

        when 'e', Curses::KEY_F2 # Edit
          @mode = :journalling
          @cursor.x = lines[@cursor.line].length

        when 'm' # Move
          @mode = :move

        when 'i' # Insert
          @cursor.line = 1 if @cursor.line == 0
          @newly_added_line = current_day.line_prototype(@cursor.line)
          lines.insert(@cursor.line, @newly_added_line.dup)
          @mode = :edit
          @cursor.x = lines[@cursor.line].size
          set_dirty

        when ENTER, ENTER.chr
          @mode = :edit
          @cursor.x = lines[@cursor.line].size

        when 'a' # append

          @newly_added_line = current_day.line_prototype(@cursor.line)
          @cursor.line += 1
          lines.insert(@cursor.line, @newly_added_line.dup)
          @mode = :edit
          @cursor.x = lines[@cursor.line].size
          set_dirty

        when 't' # t(oday)

          @cursor.day = @journal.close(current_day)
          @current_day = @journal.days[@cursor.day]
          @win1b.clear
          set_dirty

        when 'k' # kill
          if lines.size > 1
            lines.delete_at(@cursor.line)
            @cursor.line -= 1 if @cursor.line >= lines.size
          else
            lines[0] = "".dup
          end
          @win1b.clear
          set_dirty

        when 'w' # waiting

          postpone(lines, current_day, 7, '⌛') { |line|

            if !(line =~ / - ⌛ since \d\d\d\d-\d\d-\d\d$/) && current_day.date
              line = line.rstrip + " - ⌛ since #{current_day.date_name}"
            end

            next line
          }

          # if lines[@cursor.line] =~ /\[\s\]/

          #   line_to_wait_for = lines[@cursor.line].dup

          #   if !(line_to_wait_for =~ / - ⌛ since \d\d\d\d-\d\d-\d\d$/) && current_day.date
          #     line_to_wait_for = line_to_wait_for.rstrip + " - ⌛ since #{current_day.date_name}"
          #   end

          #   # Get target day (and create if it doesn't exist) and add there
          #   postpone_day = @journal.postpone_day(current_day, 7)
          #   postpone_day.lines.insert(1, line_to_wait_for)

          #   # Adjust @cursor.day if a new day was created
          #   @cursor.day += 1 if current_day != @journal.days[@cursor.day]

          #   # Add hourclass here
          #   lines[@cursor.line].gsub!(/\[\s\]/, "[⌛]")
          #   set_dirty

          # end

        when 'p' # postpone

          postpone(lines, current_day, 1, '>')

        else
          if Curses.debug_win
            Curses.debug_win.puts "Char not handled: " + Curses::char_info(char)
            Curses.debug_win.refresh
          end
      end

    when :move

      case char
        when 'q'
          return self.save

        when CTRLC, CTRLC.chr
          return close_without_save

        when Curses::KEY_UP

          if @cursor.line > 0
            lines[@cursor.line], lines[@cursor.line - 1] = lines[@cursor.line - 1], lines[@cursor.line]
            @cursor.line -= 1
            set_dirty
          end

        when Curses::KEY_DOWN

          if @cursor.line < lines.size - 1
            lines[@cursor.line], lines[@cursor.line + 1] = lines[@cursor.line + 1], lines[@cursor.line]
            @cursor.line += 1
            set_dirty
          end

        when "\t", "\t".ord, Curses::KEY_RIGHT
          if lines[@cursor.line] =~ /\s*[-+*]/
            lines[@cursor.line].sub!(/^/, "  ")
            set_dirty
          end

        when Curses::KEY_BTAB, Curses::KEY_LEFT
          if lines[@cursor.line] =~ /(  |\t)\s*[-+*]/
            lines[@cursor.line].sub!(/^(  |\t)/, "")
            set_dirty
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

  def postpone(lines, current_day, n, postpone_char, &block)

    target_day = @journal.postpone_line(current_day, @cursor.line, n, postpone_char, &block)
    return false unless target_day

    # Adjust @cursor.day if a new day was created
    @cursor.day += 1 if current_day != @journal.days[@cursor.day]

    set_dirty
  end

end

if __FILE__==$0
  Rodo.new.main_loop
end