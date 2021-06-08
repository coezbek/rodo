# 2021-06-08

Todos until Rodo 0.1.0
 - [ ] Release
 - [ ] Test on Mac
 - [ ] Update README.md
 - [ ] Short introvideo
 - [x] Silence warnings about pattern matching

Todos for Rodo 0.2.0 and later
 - [x] When postponing copy section headers and parent todos
 - [ ] When closing days, use a checkmark to mark the day as done
 - [ ] Multiline/wrap support
 - [ ] Autosave
 - [ ] Add migration mode
 - [ ] Montly Log Mode
 - [ ] Copy and Paste from <ul>/<ol> and OneNote
 - [ ] Improve command palette with support for cursor keys

# 2021-06-02

Todos until Rodo 0.1.0
 - [>] Release
 - [x] Improve postponing, so that it merges better with day closure.
 - [x] Postponing should postpone at least 1 day, but never to a day in the past (same with close)
 - [x] Add support for shadow cursor
 - [>] Test on Mac

Todos for Rodo 0.2.0 and later
 - [>] When postponing copy section headers and parent todos
 - [>] When closing days, use a checkmark to mark the day as done
 - [>] Multiline/wrap support
 - [>] Autosave
 - [>] Add migration mode
 - [>] Montly Log Mode
 - [>] Copy and Paste from <ul>/<ol> and OneNote
 - [>] Improve command palette with support for cursor keys

# 2021-05-30 Sun

Todos until Rodo 0.1.0
 - [x] When closing merge text, with existing days
 - [x] Add some tests
 - [>] Release

Todos for Rodo 0.2.0 and later
 - [>] When postponing copy section headers and parent todos
 - [>] When closing days, use a checkmark to mark the day as done
 - [>] Multiline/wrap support
 - [>] Autosave
 - [>] Add migration mode
 - [>] Montly Log Mode
 - [>] Copy and Paste from <ul>/<ol> and OneNote
 - [>] Improve command palette with support for cursor keys

# 2021-05-27 Thu

Todos until Rodo 0.1.0
 - [>] When closing merge text with existing days
 - [x] Only start debug window when run with ruby $DEBUG
 - [x] Use Shift+~ to Toogle Debug Console
 - [x] Copy and Paste with Bracketed Paste mode and some basic clean-ups (tabs)
 - [x] CTRL+Cursor Keys should navigate in text line

Todos for Rodo 0.2.0 and later
 - [>] When postponing copy section headers and parent todos
 - [>] When closing days, use a checkmark to mark the day as done
 - [>] Multiline/wrap support
 - [>] Autosave
 - [>] Add migration mode
 - [>] Montly Log Mode
 - [>] Copy and Paste from <ul>/<ol> and OneNote
 - [>] Improve command palette with support for cursor keys

# 2021-05-26 Wed

Todos until Rodo 0.1.0
 - [x] Add command area
   - [x] Add utility functions for creating an input box
   - [x] Show list of options
   - [-] Size of command area should match available options
   - [x] Add support for postpone several (p+number+ENTER)
 - [x] When inserting and appending respect indent
 - [>] When closing merge text with existing days
 - [x] Switched [u] to [>] after reading the bullet journal website
 - [>] Only start debug window when run with ruby -w

Todos for Rodo 0.2.0 and later
 - [>] When postponing copy section headers and parent todos
 - [>] When closing days, use a checkmark to mark the day as done
 - [>] Multiline/wrap support
 - [>] Autosave
 - [>] Add migration mode
 - [>] Montly Log Mode
 - [>] Copy and Paste from <ul>/<ol> and OneNote

# 2021-05-25
 - [>] Add command area
   - [>] Add utility functions for creating an input box
   - [>] Show list of options
   - [>] Size of command area should match available options
   - [>] Add support for postpone several (p+number+ENTER)
 - [>] When inserting and appending respect indent
 - [>] When closing merge text with existing days
 - [x] FIX: Bundler freezes strings, so we need to .dup string literals which we want to modify later

Long term todos:
 - [>] When postponing copy section headers and parent todos
 - [>] When closing days, use a checkmark to mark the day as done
 - [>] Multiline/wrap support

# 2021-05-22 08:12
 - [u] Add command area
   - [u] Add utility functions for creating an input box
   - [u] Show list of options
   - [u] Size of command area should match available options
   - [u] Add support for postpone several (p+number+ENTER)
 - [u] When inserting and appending respect indent
 - [u] When closing merge text with existing days
 - [x] BUG: Pressing escape shouldn't delete line, if user typed something.
 - [x] Host on github

Long term todos:
 - [u] When postponing copy section headers and parent todos
 - [u] When closing days, use a checkmark to mark the day as done
 - [u] Multiline/wrap support

# 2021-05-22
 - [x] Reduce ESC delay: https://stackoverflow.com/questions/27372068/why-does-the-escape-key-have-a-delay-in-python-curses

# 2021-05-21
 - [u] Add command area
   - [u] Add utility functions for creating an input box
   - [u] Show list of options
   - [u] Size of command area should match available options
 - [u] When postponing copy section headers and parent todos
 - [u] When closing days, use a checkmark to mark the day as done
 - [u] Add support for postpone several (p+number+ENTER)
 - [u] Multiline/wrap support
 - [x] In journalling mode: When pressing enter twice, remove indent/marks
 - [x] When entering journalling mode, move cursor to end of line

# 2021-05-18
 - [x] Test task for waiting - ⌛ since 2021-05-11

# 2021-05-17
 - [u] Add command area
   - [u] Add utility functions for creating an input box
   - [u] Show list of options
   - [u] Size of command area should match available options
   - [x] Filter options while typing
 - [u] When postponing copy section headers and parent todos
 - [u] When closing days, use a checkmark to mark the day as done
 - [u] When inserting and appending respect indent
 - [u] Add support for postpone several (p+number+ENTER)
 - [u] Multiline/wrap support
 - [x] Add automatic prefixing of lines which start with '\s[-*]\s\[.\]'

# 2021-05-16 14:28
 - [u] Add undo support
 - [u] Add command area
 - [u] Add support for postpone several (p+number+ENTER)
 - [u] Reduce ESC delay: https://stackoverflow.com/questions/27372068/why-does-the-escape-key-have-a-delay-in-python-curses
 - [u] Multiline/wrap support
 - [x] CTRL+D for DEL
 - [x] Add mode to 'm'ove entries back and forth

# 2021-05-16
 - [u] Add undo support
 - [u] Add command area
 - [u] Add support for postpone several (p+number+ENTER)
 - [x] Support resize
 - [x] Sort entry correctly on append
 - [x] Save *.bak to _bak folder (and create it if it doesn't exist)
 - [x] Fix highlighting of page indicator
 - [u] Reduce ESC delay: https://stackoverflow.com/questions/27372068/why-does-the-escape-key-have-a-delay-in-python-curses
 - [u] Multiline/wrap support

# 2021-05-15
 - [u] Add undo support
 - [u] Add command area
 - [u] Add support for postpone several (p+number+ENTER)
 - [u] Support resize
 - [x] Journaling mode (ENTER doesn't stop editing)
 - [u] Sort entry correctly on append

Sub-Section:
 - [u] Fix highlighting of page indicator
 - [u] Reduce ESC delay: https://stackoverflow.com/questions/27372068/why-does-the-escape-key-have-a-delay-in-python-curses
 - [u] Multiline/wrap support

# 2021-05-11 14:00
 - [x] Support for Tab/S+Tab during edit mode
 - [x] Add support for 'w'aiting and add a waiting window
 - [⌛] Test task for waiting
 - [x] Start on current date or most recent day in the past
 - [x] Put [u] back in, because we need to close out old tasks when moving to new days
 - [u] Add undo support
 - [u] Add command area
 - [u] Add support for postpone several (p+number+ENTER)
 - [u] Support resize
 - [u] Journaling mode (ENTER doesn't stop editing)

Sub-Section:
 - [u] Fix highlighting of page indicator
 - [u] Reduce ESC delay: https://stackoverflow.com/questions/27372068/why-does-the-escape-key-have-a-delay-in-python-curses
 - [u] Multiline/wrap support

# 2021-05-11 09:02
 - [x] Don't use [u] when tasks are pushed to the next day
 - [ ] Start on current date or most recent day in the past
 - [ ] Add undo support
 - [x] Pressing escape on a line which was just inserted remove it again
 - [ ] Add command area
 - [ ] Add support for postpone several (p+number+ENTER)
 - [x] Add support for DEL during edit mode
 - [x] Add support for cursor positioning using arrow keys.
 - [x] Add support for CTRL+A and CTRL+E during edit mode.
 - [ ] Support resize

Sub-Section:
 - [ ] Fix highlighting of page indicator
 - [ ] Reduce ESC delay: https://stackoverflow.com/questions/27372068/why-does-the-escape-key-have-a-delay-in-python-curses
 - [ ] Multiline/wrap support

# 2021-05-11
 - [u] Start on current date or most recent day in the past
 - [u] Add undo support
 - [u] Add support for postpone several (p+number+ENTER)
Sub-Section:
 - [u] Fix highlighting of page indicator
 - [u] Reduce ESC delay: https://stackoverflow.com/questions/27372068/why-does-the-escape-key-have-a-delay-in-python-curses
 - [u] Multiline/wrap support
 - [x] Closing a day should copy all sections

# 2021-05-08
 - [u] Start on current date or most recent day in the past
 - [u] Add undo support
 - [u] Add support for postpone several (p+number+ENTER)
 - [u] Fix highlighting of page indicator
 - [u] Reduce ESC delay: https://stackoverflow.com/questions/27372068/why-does-the-escape-key-have-a-delay-in-python-curses

 - [x] Backspace Key: Crashes when 0
 - [x] Add edit mode 'e'

# 2021-05-07
 - [x] Create file if it does not exist (with current day)
 - [x] Add support for postpone (p)
 - [x] I(nsert) will actually a(append) when on the first line
 - [u] Start on current date or most recent day in the past
 - [u] Add undo support
 - [u] Add support for postpone several (p+number+ENTER)
 - [u] Fix highlighting of page indicator
 - [x] Support for Umlauts äöü

# 2021-05-06
 - [x] Add way to add any date
 - [x] Show indicators that there are more days in the past/future.
 - [u] Start on current date or most recent day in the past
 - [x] Add support for kill (k)
 - [x] Add support for append (a)
 - [u] Add support for postpone (p)
 - [x] Get colors working

# 2021-05-01
 - [x] Serialization
 - [u] Get colors working
