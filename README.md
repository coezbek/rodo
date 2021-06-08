# Rodo
Rodo is terminal-based todo manager written in Ruby with a inbox-zero mentality. It takes inspiration from bullet journalling.

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

## Things not working currently

Rodo comes with no warranty and is still rough. The most notable things missing in the release 0.1.0:

 - No undo/redo
 - No autosave
 - No scrolling
 - No mouse interaction
 - No special handling for any markdown except unordered lists, headings and todos.

## Installation & First Run

Install the `rodo` gem locally

    $ gem install rodo

Then run it:

    $ rodo

Starting rodo without arguments will use '~/plan.md' as the markdown file.

Note: Rodo requires Ruby 2.7 and higher due to using the pattern matching `case` statement.

Note: When running with `rbenv` you need to `rbenv rehash` after you installed the gem for the command line wrapper to become visible on the path.

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

Rodo is licensed under GPL-v3 or later.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/coezbek/rodo.
