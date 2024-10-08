
require 'date'

class Command

  def redo()

  end

  def undo()

  end

end


class Processor


  def command(c, line, verb)

  end


end

#
# Journal is the datastore class for the todo list managed by rodolib.
#
# Responsible for:
#   - Parsing a md file into a rodolib Journal
#   - Serialization into a md file
#   - Splitting into days
#
class Journal

  # Array of TodoDay objects in reverse chronological order (newest day first)!
  attr_accessor :days
  attr_accessor :recurrences

  def self.from_s(s)

    j = Journal.new
    j.days = []
    j.recurrences = nil

    next_day = []
    s.each_line { |line|
      if line =~ /^\s*\#\s*(\d\d\d\d-\d\d-\d\d)/ && next_day.size > 0
        j.days << TodoDay.new(next_day)
        next_day = []
      end
      next_day << line.rstrip if next_day.size > 0 || line.strip.length > 0 # Skip leading empty lines
    }
    if (next_day.size > 0 && next_day.any? { |line| line.strip.length > 0 })
      j.days << TodoDay.new(next_day)
    end

    return j
  end

  def to_s
    days.map { |day| day.to_s }.join("\n\n") + (days.empty? ? "" : "\n")
  end

  # Returns the TodoDay for the given date creating it if it doesn't exist
  def ensure_day(target_date)
    index = days.find_index { |x| x.date <= target_date } || -1

    if index < 0 || days[index].date != target_date
      days.insert(index, TodoDay.new(["# #{target_date.strftime("%Y-%m-%d %a")}"]))
    end
    return days[index]
  end

  # Returns the day, number of days in the future from the given day, but at never before today
  def postpone_day(day, number_of_days_to_postpone=1)

    number_of_days_to_postpone = 1 if number_of_days_to_postpone < 1

    target_date = (day.date || Date.today).next_day(number_of_days_to_postpone)

    # target_date shouldn't be in the past
    target_date = Date.today if target_date.to_date < Date.today

    return ensure_day(target_date)
  end

  # Move/postpone the given line on the given day by the given number of days into the future (defaults to 1 day)
  #
  # Will replace the todo character by the given postpone_char (defaults to '>')
  #
  # If a block is given the line on the given day/line_index is yielded and the returned
  # string is inserted into the future day.
  #
  # Returns false, if there is no todo which can be postponed on the given line
  # Returns the target date to which the line was moved if successful.
  def postpone_line(day, line_index, number_of_days_to_postpone=1, postpone_char='>')

    line = day.lines[line_index]

    # Postpone only works for todos
    return false if !(line =~ /^\s*(-\s+)?\[(.)\]/)

    # Postpone only works for unfinished todos
    return false if $2 != " "

    # First create the target day
    target_day = postpone_day(day, number_of_days_to_postpone)

    # Determine all affected lines
    unfinished_lines = [nil] * day.lines.size

    # Copy all unfinished tasks and...
    unfinished_lines[line_index] = block_given? ? yield(line.dup) : line.dup

    # ...their parent entries (recursively)
    parent_index = line_index
    while (parent_index = day.parent_index(parent_index)) != nil
      unfinished_lines[parent_index] ||= day.lines[parent_index].dup
    end

    # Copy up to 1 whitespace line preceeding
    unfinished_lines.each_with_index { |e, i|
      if e != nil && i != 0 && day.indent_depth(i - 1) == nil
        unfinished_lines[i-1] = ""
      end
    }

    # ...and the children as well!
    # TODO

    # Mark line itself as postponed
    line.sub!(/\[\s\]/, "[#{postpone_char}]")

    # Get rid of primary header
    if unfinished_lines[0] =~ /^\s*\#\s*(\d\d\d\d-\d\d-\d\d)/
      unfinished_lines.shift
    end

    # Only append non-empty lines
    unfinished_lines.select! { |l| l != nil }

    target_day.merge_lines(unfinished_lines)

    return target_day
  end

  #
  # Returns upcoming todos taking recurring events into account
  #
  def upcoming(day_index)

    if day_index == 0
      journal_days = {}
    else
      journal_days = days.take( day_index ).reverse.map { |day| [day.date, day] }.to_h
    end
    recurrences_days = @recurrences&.determine_recurring_tasks(Date.today, Date.today + 60, by_date: true) || {}
    
    upcoming_dates = (journal_days.keys + recurrences_days.keys).uniq.sort
      
    return upcoming_dates.map { |date|

      lines = []
      
      if journal_days.has_key?(date)
        if recurrences_days.has_key?(date)
          lines = journal_days[date].dup.merge_lines(recurrences_days[date])
        else
          lines = journal_days[date].lines
        end
      else
        lines = ["# #{date.strftime("%Y-%m-%d %a")}"]
        lines += recurrences_days[date]
        lines << ""
      end

      lines.join("\n")
    }.join("\n") 
  end

  # Postpones all unfinished todos to today's date
  # Returns the index of the target date to which things were postponed
  def close(day)

    unfinished_lines = [nil] * day.lines.size

    day.lines.each_with_index { |line, index|
      if line =~ /^\s*(-\s+)?\[(.)\]/

        if $2 == " "
          # Copy all unfinished tasks and...
          unfinished_lines[index] = line.dup

          # ...their parent entries (recursively)
          parent_index = index
          while (parent_index = day.parent_index(parent_index)) != nil
            unfinished_lines[parent_index] ||= day.lines[parent_index].dup
          end
          line.sub!(/\[\s\]/, "[>]")
        end

      # Copy top level structure:
      elsif !(line =~ /^\s*[-*]\s+/ || line =~ /^\s*#\s/)
        unfinished_lines[index] = line.dup
      end
    }

    if unfinished_lines[0] =~ /^\s*\#\s*(\d\d\d\d-\d\d-\d\d)/
      unfinished_lines.shift
    end

    target_day = ensure_day(Date.today)

    recurring_tasks = []
    
    if target_day == day
      # When closing on the same day: append hour and minutes
      newDate = "# #{Time.now.strftime("%Y-%m-%d %a %H:%M")}"
      target_day = TodoDay.new([newDate])
      insertion_index = days.index { |d| target_day.date >= d.date } || 0
      days.insert(insertion_index, target_day)
    else
      # When moving at least one day into the future determine recurring tasks
      if recurrences != nil
        recurring_tasks = recurrences.determine_recurring_tasks(day.date, target_day.date)  
        # raise recurring_tasks.inspect
      end
    end

    # Only append non-empty lines
    unfinished_lines.select! { |l| l != nil }

    target_day.merge_lines(unfinished_lines)

    # Append recurring tasks
    target_day.merge_lines(recurring_tasks.select { |l| l != nil })

    return days.find_index(target_day)
  end

  #
  # Returns the index of the day in the Journal which is most recent but not in the future
  # If no such day exists, returns 0
  # 
  def most_recent_index
    today = Date.today
    return days.find_index { |x| x.date <= today } || 0
  end

  #
  # Returns the index of the TodoDay which comes after the most recent closed TodoDay
  # 
  def most_recent_open_index
    today = Date.today
    result = days.each_cons(2).find_index { |cur, prev|
      # puts "cur: #{cur.date} prev: #{prev.date} today: #{today} cur_closed: #{cur.is_closed?} prev_closed: #{prev.is_closed?}"
      (cur.date <= today) && (cur.is_closed? || prev.is_closed?)
    }
    if !result 
      if days.size > 0
        result = days.size - 1
      else
        result = 0
      end
    end
    return result
  end

end

#
# Encapsulates the position of the cursor in the following dimensions:
#
#  - which *x* position the cursor is on, on a particular *line*
#  - which *line* the cursor is on, on a particular *day*
#  - which *day* is currently shown on the main screen
#  - which *x* position would be on ('shadow x'), if the line would be longer
#  - which *line* the cursor would be on ('shadow line'), if the current day would have more lines
#
class Cursor

  attr_accessor :journal
  attr_accessor :day

  def initialize(journal)
    @journal = journal
    @shadow_line = 0
    @shadow_x = 0
    self.day = @journal.most_recent_index
    # self.line = 0
    # self.x = 0
  end

  def day=(day)
    @day = [[0, day].max, @journal.days.size - 1].min
    @line = [@journal.days[@day].lines.size - 1, @shadow_line].min
    @x = [@journal.days[@day].lines[@line].size, @shadow_x].min
  end

  def line=(line)
    line = [[0, line].max, @journal.days[@day].lines.size - 1].min
    @line = @shadow_line = line
    @x = [@journal.days[@day].lines[@line].size, @shadow_x].min
  end

  def x=(x)
    # note x is clamped 1 character beyond the length of the line
    x = [[0, x].max, @journal.days[@day].lines[@line].size].min
    @x = @shadow_x = x
  end

  def line
    @line
  end

  def x
    @x
  end

end

# Encapsulate a single date of todo information
class TodoDay

  attr_accessor :date
  attr_accessor :lines

  def initialize(lines)
    self.lines = lines

    if lines.size > 0 && lines[0] =~ /^\s*\#\s*(\d\d\d\d-\d\d-\d\d)/
      self.date = Date.parse($1)
      raise "Date couldn't be parsed on line #{lines[0]}" if self.date == nil
    end
  end

  def date_name
    return date.strftime("%Y-%m-%d") if date
    return "undefined"
  end

  def to_s
    lines.join("\n").rstrip
  end

  def line_prototype(line_index)
    line = lines[line_index]
    if /^(?<lead>\s+[*-])(?<option>\s\[.\]\s?)?(?<rest>.*?)$/ =~ line
      if option =~ /^\s\[.\]/
        option = " [ ]"
      end
    else
      lead = " -"
      option = " [ ]"
    end

    option = "" if !option
    return lead + option.rstrip + " "
  end

  # Returns the number of leading spaces of the given line
  def indent_depth(line_index)
    return nil if !lines[line_index] || lines[line_index].strip.length == 0

    lines[line_index][/\A\s*/].length
  end

  # Returns the line index of the parent line if any or nil
  # The parent line is the line with a reduced indentation or the section header in case there no reduced indented line
  def parent_index(line_index)
    j = line_index - 1
    my_indent = indent_depth(line_index)
    return nil if !my_indent
    while j > 0 # Day header does not count as parent
      other_indent = indent_depth(j)
      if other_indent && other_indent < my_indent
        return j
      end
      j -= 1
    end
    return nil
  end

  # Turns the linear list of lines of this TodoDay into a nested structure of the form
  # [{text: "text", children: [...]}, ...]
  # where ... is the same hash structure {text: "text", children: [...]}
  def structure

    indents = [nil] * lines.size
    (lines.size - 1).downto(0).each { |i|
      indents[i] = indent_depth(i) || (i+1 < indents.size ? indents[i+1] : 0)
    }

    stack = [{depth: -1, children: []}]
    lines.each_with_index { |s, i|
      indent = indents[i]
      new_child = {depth: indent, text: s, index: i, children: []}
      while indent <= stack.last[:depth]
        stack.pop
      end
      stack.last[:children] << new_child
      stack << new_child
    }

    return stack.first[:children]
  end

  def is_any_open?
    return lines.any? { |line| line =~ /^\s*(-\s+)?\[\s\]/ }
  end

  def is_closed?
    return !is_any_open?
  end

  def close

    unfinished_lines = []
    lines.each { |line|
      if line =~ /^\s*(-\s+)?\[(.)\]/

        if $2 == " "
          unfinished_lines << line.dup
          line.sub!(/\[\s\]/, "[>]")
        end

      # Copy structure:
      elsif !(line =~ /^\s*[-*]\s+/ || line =~ /^\s*#\s/)
        unfinished_lines << line.dup
      end
    }

    if unfinished_lines[0] =~ /^\s*\#\s*(\d\d\d\d-\d\d-\d\d)/
      unfinished_lines.shift
    end

    # When closing on the same day: append hour and minutes
    newDate = "# #{Time.now.strftime("%Y-%m-%d %a")}"
    if lines.size > 0 && lines[0].start_with?(newDate)
      newDate = "# #{Time.now.strftime("%Y-%m-%d %a %H:%M")}"
    end

    return TodoDay.new([newDate, *unfinished_lines])

  end

  # Merge alls entries from source into target
  def self.merge_structures(target, source)
    # Attempt 1.3:
    to_prepend = []
    source.each { |new_block|
      existing_block_index = target.find_index { |existing_block|
        new_block != nil && existing_block != nil && new_block[:text] != "" && new_block[:text] == existing_block[:text]
      }

      if existing_block_index
        existing_block = target[existing_block_index]

        # Insert everything in the to_prepend queue at the given position...

        # ... but merge whitespace now
        whitespace_check_index = existing_block_index - 1
        while whitespace_check_index >=0 && to_prepend.size > 0 && to_prepend[0][:text] == "" && target[whitespace_check_index][:text] = ""
          to_prepend.shift
          whitespace_check_index -= 1
        end

        target.insert(existing_block_index, *to_prepend)

        # Start queue from scratch
        to_prepend = []
        merge_structures(existing_block[:children], new_block[:children])
      else
        to_prepend << new_block.dup
      end
    }
    # Everything that couldn't be matched, goes to the end
    # TODO Whitespace merging
    target.concat(to_prepend)

    TodoDay::structure_reindex(target)

    return target
  end

  def self.structure_to_a(structure)
    result = []
    structure.each { |block|
      result << block[:text]
      result.concat(structure_to_a(block[:children]))
    }
    return result
  end

  # Will traverse the given structure and update all indices to be in increasing order
  def self.structure_reindex(structure, index = 0)
    structure.each { |block|
      block[:index] = index
      index = structure_reindex(block[:children], index + 1)
    }
    return index
  end

  def merge_lines(lines_to_append)

    return if lines_to_append.empty?

    end_lines = []
    end_lines << lines.pop while lines.size > 0 && lines.last.strip.size == 0

    my_structure = structure
    ap_structure = TodoDay.new(lines_to_append).structure

    TodoDay::merge_structures(my_structure, ap_structure)

    @lines = TodoDay::structure_to_a(my_structure)

    lines.concat(end_lines)
  end

end

class Recurrences

  # Array of TodoDay objects in reverse chronological order (newest day first)!
  attr_accessor :rules

  # Returns an array of lines which are recurring tasks between the given dates
  #
  # The format of the lines is:
  # ```
  # Section
  #   - [ ] Task
  # ```
  #
  # No date header is prepended to the task
  #
  def determine_recurring_tasks(from_date, to_date, by_date: false)

    lines = {}
    section = nil

    rules.each { |rule|

      limit = rule[:limit] || (rule[:mode] == 'DAILY' ? 1 : nil)

      # puts rule[:rule].between(from_date.to_time, to_date.to_time, limit: limit).inspect
  
      rule[:rule].between(from_date.to_time, to_date.to_time, limit: limit).each { |date|

        lines[date] ||= []

        # Prepend section if it has changed and exists
        if rule[:section] != section
          section = rule[:section]
          if section != nil
            lines[date] << ""
            lines[date] << section
          end
        end

        startDate = rule[:rule].dtstart.to_time

        task = rule[:text].gsub(/%(\w+)%/) { |_|
          
          cmd = $~[1] 
          case cmd.downcase
          when 'recurrence', 'age'
            rule[:rule].between(startDate, date.to_time).size

          when 'recurrenceth', 'ageth'
            require 'active_support'
            rule[:rule].between(startDate, date.to_time).size.ordinalize

          when 'quarter'
            date.month / 4 + 1

          else
            date.strftime("%#{cmd}")            
          end
        }

        # Append the task
        lines[date] << " - [ ] #{task}"
      
      }  
    }

    if by_date
      # raise lines.sort_by { |k, _| k }.reverse.to_h.inspect
      return lines.sort_by { |k, _| k }.reverse.to_h
    else
      return lines.values.flatten
    end
  
  end

  def self.from_s(s)

    require 'rrule'

    r = Recurrences.new
    r.rules = []

    mode = nil
    section = nil

    y = Date.today.year
    # m = Date.today.month
    # d = Date.today.day

    s.each_line { |line|

      if line =~ /^\s*\#\s*(yearly|monthly|weekly|daily)/i
        mode = $1.upcase
        section = nil
        next
      end

      if line =~ /^(\w+.*)$/
        section = $1
        next
      end
      
      # Empty line
      if line =~ /^\s*-\s+\[\s\]\s+(.*)/
        raise "No recurrence mode set. Add a section with 'yearly', 'monthly' etc." if mode == nil
        r.rules << {rule: RRule.parse("FREQ=#{mode}", dtstart: Date.new(y-1, 1, 1)), text: $1, section: section, mode: mode}
        next
      end

      # ISO and european date format
      if line =~ /^\s*-\s+(\d\d\d\d\d\d\d\d|\d\d\d\d-\d\d-\d\d|\d{1,2}\.\d{1,2}\.\d{4})\s+\[\s\]\s+(.*)/
        raise "No recurrence mode set. Add a section with 'yearly', 'monthly' etc." if mode == nil
        r.rules << {rule: RRule.parse("FREQ=#{mode}", dtstart: Date.parse($1)), text: $2, section: section, mode: mode}
        next
      end

      # US date format
      if line =~ /^\s*-\s+(\d{1,2}\/\d{1,2}\/\d{4})\s+\[\s\]\s+(.*)/
        raise "No recurrence mode set. Add a section with 'yearly', 'monthly' etc." if mode == nil
        r.rules << {rule: RRule.parse("FREQ=#{mode}", dtstart: Date.strptime($1, "%m/%d/%Y")), text: $2, section: section, mode: mode}
        next
      end

      # Short european date format '13.01' for yearly recurrences
      if mode == 'YEARLY' && line =~ /^\s*-\s+(\d{1,2}\.\d{1,2})\.?\s+\[\s\]\s+(.*)/
        raise "No recurrence mode set. Add a section with 'yearly', 'monthly' etc." if mode == nil
        r.rules << {rule: RRule.parse("FREQ=#{mode}", dtstart: Date.strptime($1, '%d.%m')), text: $2, section: section, mode: mode}
        next
      end

      # Short US date format 01/13 for yearly recurrences
      if mode == 'YEARLY' && line =~ /^\s*-\s+(\d{1,2}\/\d{1,2})\s+\[\s\]\s+(.*)/
        raise "No recurrence mode set. Add a section with 'yearly', 'monthly' etc." if mode == nil
        r.rules << {rule: RRule.parse("FREQ=#{mode}", dtstart: Date.strptime($1, "%m/%d")), text: $2, section: section, mode: mode}
        next
      end

      # Short date format '13.' for monthly recurrences
      if mode == 'MONTHLY' && line =~ /^\s*-\s+(\d{1,2})\.?\s+\[\s\]\s+(.*)/
        raise "No recurrence mode set. Add a section with 'yearly', 'monthly' etc." if mode == nil
        r.rules << {rule: RRule.parse("FREQ=#{mode};BYMONTHDAY=#{$1}", dtstart: Date.new(y-1, 1, 1)), text: $2, section: section, mode: mode}
        next
      end

      # Weekday format
      if mode == 'WEEKLY' && line =~ /^\s*-\s+(mo|tu|we|th|fr|sa|su)\p{Alpha}*\s+\[\s\]\s+(.*)/i
        raise "No recurrence mode set. Add a section with 'yearly', 'monthly' etc." if mode == nil

        startDate = Date.new(y-1, 1, 1)
        r.rules << {rule: RRule.parse("FREQ=#{mode};BYDAY=#{$1.upcase}", dtstart: startDate), 
          text: $2, 
          section: section, 
          mode: mode
        }
        next
      end

      # RRULE format, e.g:
      # # Weekly
      # - FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH [ ] Submit timesheet 
      rrulevoc = 'RRULE|LIMIT|FREQ|COUNT|UNTIL|INTERVAL|BYHOUR|BYMINUTE|BYSECOND|BYDAY|BYSETPOS|WKST|BYMONTH|BYMONTHDAY|BYWEEKNO|BYYEARDAY'
      
      if line =~ /^\s*-\s+((?:#{rrulevoc}).*?)\s+\[\s\]\s+(.*)/

        rules = $1
        task = $2
        
        startDate = Date.new(y-1, 1, 1)
        limit = nil
        temp_mode = nil

        has_prefix = rules =~ /^RRULE:/
        rules = rules.delete_prefix('RRULE:') if has_prefix

        # Append FREQ if not present
        if !(rules =~ /FREQ=/) && mode != nil
          rules = "FREQ=#{mode};#{rules}"
        end
        
        # Filter DTSTART and LIMTI parameters which are custom
        rules = rules.split(';').filter { |param| 
          option, value = param.split('=')

          case option
          when 'START', "DTSTART", "TSTART"
            startDate = Date.strptime(value, "%Y%m%d")
            next false
          when 'LIMIT'
            limit = value.to_i
            next false
          when 'FREQ'
            temp_mode = value
            next true
          end
          true
        }.join(';')

        if limit == nil
          case temp_mode
          when 'DAILY'
            limit = 1
          else # 'WEEKLY', 'MONTHLY', 'YEARLY'
            limit = 0
          end          
        end

        rules = "RRULE:" + rules if has_prefix
        
        # if line =~ /^\s*-\s+(D?T?START[:=](\d{8});)?((#{rrulevoc}).*?)\s+\[\s\]\s+(.*)/

        r.rules << { 
          rule: RRule.parse(rules, dtstart: startDate), 
          text: task, 
          section: section,
          limit: limit,
          mode: temp_mode 
        }
        next        
      end
    }

    # File.write('out.log', r.rules.map { |r| r.inspect }.join("\n")  , mode: 'a+')

    return r
  end

end