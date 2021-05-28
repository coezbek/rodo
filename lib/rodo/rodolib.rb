
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

  def postpone(day, number_of_days_to_postpone)

    number_of_days_to_postpone = 1 if number_of_days_to_postpone < 1

    target_date = (day.date || Date.today).next_day(number_of_days_to_postpone)
    index = days.find_index { |x| x.date <= target_date } || -1

    if index < 0 || days[index].date != target_date
      days.insert(index, TodoDay.new(["# #{target_date.strftime("%Y-%m-%d")}"]))
    end
    return days[index]
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