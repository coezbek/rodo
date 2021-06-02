
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

  attr_accessor :days
  def self.from_s(s)

    j = Journal.new
    j.days = []

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
    days.map { |day| day.to_s }.join("\n\n")
  end

  # Returns the TodoDay for the given date creating it if it doesn't exist
  def ensure_day(target_date)
    index = days.find_index { |x| x.date <= target_date } || -1

    if index < 0 || days[index].date != target_date
      days.insert(index, TodoDay.new(["# #{target_date.strftime("%Y-%m-%d")}"]))
    end
    return days[index]
  end

  # Returns the day, number of days in the future from the given day
  def postpone(day, number_of_days_to_postpone=1)

    number_of_days_to_postpone = 1 if number_of_days_to_postpone < 1

    target_date = (day.date || Date.today).next_day(number_of_days_to_postpone)
    return ensure_day(target_date)
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
    if target_day == day
      # When closing on the same day: append hour and minutes
      newDate = "# #{Time.now.strftime("%Y-%m-%d %a %H:%M")}"
      target_day = TodoDay.new([newDate])
      insertion_index = days.index { |d| target_day.date >= d.date } || 0
      days.insert(insertion_index, target_day)
    end

    # Only append empty lines
    unfinished_lines.select! { |l| l != nil }

    target_day.lines.concat(unfinished_lines)

    return days.find_index(target_day)
  end

  def most_recent_index
    today = Date.today
    return days.find_index { |x| x.date <= today } || 0
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
    return nil if lines[line_index].strip.length == 0

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

  def close()

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

end