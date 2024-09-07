# Rodo
Rodo is a terminal-based todo manager written in Ruby with a inbox-zero mentality. It takes inspiration from bullet journalling.

## Screenshot

![Screenshot of Rodo used on plan.md from this repository](https://user-images.githubusercontent.com/12127567/121207217-67065b80-c879-11eb-8976-f8ba3d162341.png)

## Detail Description

Rodo is a todo/task manager with a terminal-based user interface (TUI). It uses `markdown` as the underlying file format, which allows you to also edit the resulting todo files with any other text editor. Rodo structures your todos primarily using dates ("What do I need to do today?") and only then using sub-sections for projects.

Rodo is a text editor, but with a rich command vocabulary which perform actions related to todo and task management. It is similar to `vi` in that by default you are not in a mode where you can `edit`, but in a command mode where keystroke are interpreted as commands. For examples, pressing <kbd>A</kbd> will append a todo to the currently selected day and enter `single line edit mode`.

Rodo suggests that every day you start at a blank page and take over the relevant entries from the previous days. This idea originates from bullet journalling (e.g. https://bulletjournal.com/pages/learn), but gets software support in Rodo:

 - You can either press <kbd>T</kbd> (today) to create a new entry for the current date and copy all tasks which are unfinished over automatically.
 - Or you can move individual entries over to the next day by pressing <kbd>P</kbd> (postpone).

Rodo is programmed in Ruby and uses `ncurses` under the hood.

## Features

Rodo is work in progress but can already be used for basic todo tracking. Currently the following features are supported:

- Command mode, single line edit mode, journalling mode.
- Append, Insert, Edit, Kill, <kbd>⭾TAB</kbd> and <kbd>⇧Shift+⭾TAB</kbd></kbd> to indent and unindent, Save+Quit <kbd>Q</kbd>
- CTRL+C will exit without saving
- Bracketed paste support allows to paste from the clipboard without seeing indentation artifacts.
- Backup before save (stored to `_bak\`)

## Recurring Todos

Rodo has support for recurring todos, which you want to show up daily, weekly, monthly or yearly. 

To define recurring tasks put a recurring.md file in the same directory as your plan.md. The format is as follows:

```
# Yearly
Name of the section to put the todo into:
- [ ] Do something

Birthdays:
- 13.01. [ ] Christopher
- 7/27 [ ] John

# Monthly
- 25. [ ] Pay rent
...

# Weekly
- Friday [ ] Submit timesheet 
...

# Daily
...
```

The recurring todos will be copied over to the current day when you press `T` (today) and a new year, month, week or day has begun.

By default Rodo assumes that a new year starts on January 1st, a new month on the first of the month and a new week on Monday. You can adjust the day that the event is triggered by prepending information before the `[ ]`. Supported formats are:

 - For yearly events:
   - `DD.MM.` or `MM/DD` Event will trigger on the given day+month.
 - For monthly events:
   - `DD.` or `DD` Event will trigger on the given day of the month.
 - For weekly events:
   - `Weekday` (e.g. `Monday` or `Mo` or `Mon`) Event will trigger on the given weekday.
 - For all events:
   - `YYYYMMDD` or `DD.MM.YYYY` or `MM/DD/YYYY` Event will trigger based on the given date as the starting date. 

For more complex recurring events, alternatively to the above shorthand formats, you can use the iCalender RRULE syntax. For example, to create a recurring event every 2 weeks on Monday and Thursdays, you can use the following syntax:

```
# Weekly
- FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH [ ] Submit timesheet 
```

You can omit the `FREQ=WEEKLY` from the syntax, it is inferred from the section header.

You can prepend `DTSTART=YYYYMMDD;` or `DTSTART:YYYYMMDD;` to the RRULE to specify a start date for the recurring event. Caution: This is just parsed as YYYYMMDD and does not support any other date formats.

### Limit of tasks 

For daily todos, Rodo will by default at most create a single todo even if some days have passed while you last used Rodo. For example if you have defined a daily todo of " - [ ] Exercise 15 minutes", and you haven't used Rodo for two days, then only a single todo will be created. For yearly, monthly and weekly todos, Rodo will not skip over todos, but add all past todos. You can adjust this behavior by adding 'LIMIT=n' where 0 indicates no limit in batching and other integers indicate the maximum number of todos which are created in a single `t` (today) command.

### Expansion of placeholders

Rodo supports the following placeholders in the recurring todos:

 - `%quarter%` - Returns the quarter of the current month (1-4)
 - `%recurrence%` - Returns the number of times since the DTSTART that this task was created (or better could have been created) (also `%age%`)
 - `%recurrenceth%` - Same as %recurrence% but in ordinal form (1st, 2nd, 3rd, ...)
 - All others such as `%Y%`, `%b%` as in [https://ruby-doc.org/stdlib-2.6.1/libdoc/date/rdoc/DateTime.html#method-i-strftime](strftime)

### Examples

On the 1st of January, 1st of April, etc. the following todo will be created:
```
# Monthly
- INTERVAL=3 [ ] Send quarterly investor report for Q%quarter% %Y% 
```

## Things not working currently

Rodo comes with no warranty and is still rough. The most notable things missing in the release 0.1.0:

 - No undo/redo
 - No autosave
 - No scrolling
 - No mouse interaction
 - No special handling for any markdown except unordered lists, headings and todos
 - No file locking for exclusive read/write (won't change)

## Command line options

Rodo supports the following command line options:

 - `-d` - Enable debug mode. This will show the debug info in a separate ncurses window.
 - `-f` - Enable the future todo window.
 - `-r=YYYYMMDD` - Output the todos for the given date including recurring tasks


## Installation & First Run

Install the `rodo` gem locally

    $ gem install rodo

Then run it:

    $ rodo

Starting rodo without arguments will use '~/plan.md' as the markdown file.

Note: Rodo requires Ruby 2.7 and higher due to using the pattern matching `case` statement.

Note: When running with `rbenv` you need to `rbenv rehash` after you installed the gem for the command line wrapper to become visible on the path.

## Usage

To run:

    $ rodo [file]
    
By default rodo is in `scroll` mode, with the following keys supported:

 - <kbd>cursor keys</kbd> Up/Down select particular line, Left/Right go to previous/next day
 - <kbd>Q</kbd> Quit with Save
 - <kbd>CTRL+C</kbd> Quit without Save
 - <kbd>A</kbd> Append new todo below with same indent as current line
 - <kbd>I</kbd> Insert new todo before the current line with same indent as current line
 - <kbd>K</kbd> Kill (delete) current line
 - <kbd>P</kbd> Postpone current line to tomorrow
 - <kbd>W</kbd> Mark current todo as waiting for reply/other person (put a reminder in 7 days)
 - <kbd>T</kbd> Create a new entry for today's date and move all unfinished todos over. This will also copy all top level entries (section headers), even if they are empy.
 - <kbd>X</kbd> Toggle current line as Complete/Incomplete
 - <kbd>⭾TAB</kbd> and <kbd>⇧Shift+⭾TAB</kbd></kbd> to indent and unindent
 - <kbd>ENTER</kbd> Start editing the current line. Finish editing with another `ENTER`.
 - <kbd>E</kbd> Enter editing mode. ENTER will create a new line in this mode.
 - <kbd>F1</kbd> See a command palette.

In `editing` mode most keys will just create resulting in typing, except:

 - <kbd>CTRL+A</kbd>, <kbd>CTRL+E</kbd> Put cursor at start of line, end of line.
 - <kbd>⭾TAB</kbd> and <kbd>CTRL+RIGHT</kbd> Move to beginning/end of next/previous word. 

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

Rodo is licensed under GPL-v3 or later.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/coezbek/rodo.

## Related Work

Todo trackers seem to scratch an itch for many. Notable related work from which Rodo draws inspiration:

- http://todotxt.org/ - Even more bare-bone text-based file format for todo tracking. Lots of tools supporting it.
- https://bulletjournal.com/ - Paper-based journalling methodology.
- https://orgmode.org/ - If you want to bring emacs into the game.
