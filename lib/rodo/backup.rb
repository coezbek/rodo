
#
# Utility functions for handling of backup files
#
# Rodos backup file system works in the following way:
#
# - When opening a file called plan.md, a backup file plan.md~ is created.
# - Periodically (every 5 minutes or after 15 seconds of inactivity) the current in-memory state of Rodo is saved to this file
# - When Rodo in a regulary fashion this file is removed
# - If Rodo crashes or the system goes down unexpectedly the file remains on disk.
# - You can recover the file either manually or you will be asked upon next start-up if you want to recover from this file.
#

class Rodo

  @last_backup_time = nil
  @dirty_since_auto_save = false

  BACKUP_INACTIVITY_INTERVAL_SECONDS = 15
  BACKUP_MAX_BACKUP_INTERVAL_SECONDS = 300

  def backup_file_name
    @file_name + "~"
  end

  def set_dirty
    @dirty_since_auto_save = true
  end

  def check_for_stale_backup_and_recover

    if File.exist?(backup_file_name) && File.mtime(backup_file_name) > File.mtime(@file_name)

      size_orig = File.size(@file_name).to_s
      size_back = File.size(backup_file_name).to_s
      max_length = [size_back.length, size_orig.length].max

      puts "Recovery file found #{backup_file_name}"
      puts
      puts "Original file: Size: #{size_orig.rjust(max_length)}, Last modified: #{File.mtime(@file_name)}"
      puts "Backup file:   Size: #{size_back.rjust(max_length)}, Last modified: #{File.mtime(backup_file_name) }"

      puts
      puts "Please enter: R(ecover from backup), D(elete backup), or any other key to do nothing and exit"
      input = STDIN.gets()

      case input.strip.downcase
      when 'r'

        puts ""
        puts "Please confirm that you want to recover from backup."
        puts "This will delete #{@file_name}"
        puts "And restore #{backup_file_name}"
        puts ""
        puts "To continue enter y or Y. Enter any other key to abort."

        confirmation = STDIN.gets()
        if confirmation.strip.downcase != 'y'
          return :close
        end

        create_bak()
        FileUtils.cp(backup_file_name, @file_name)

      when 'd'
        puts ""
        puts "Please confirm that you want to delete the recovery file."
        puts "This will delete #{backup_file_name}"
        puts ""
        puts "To continue enter y or Y. Enter any other key to abort."

        confirmation = STDIN.gets()
        if confirmation.strip.downcase != 'y'
          return :close
        end

        File.delete(backup_file_name)

      else
        return :close
      end
    end

    return nil
  end

  #
  # Returns the number of seconds since the last backup was performed
  #
  # Returns 0 if the database hasn't been modified since the last auto-save (nothing to save)
  #
  # Returns 86400 (1 day) if the database has never been backed-up
  #
  def seconds_since_last_backup

    return 0 if !@dirty_since_auto_save

    return 60*60*24 if !@last_backup_time

    return (Time.now - @last_backup_time).to_i
  end

  def backup_auto_save

    if !@dirty_since_auto_save
      @last_backup_time = Time.now
      return
    end

    if Curses.debug_win
      Curses.debug_win.puts "Starting backup: #{backup_file_name}"
      Curses.debug_win.refresh
    end

    File.write(backup_file_name, @journal.to_s)

    @last_backup_time = Time.now
    if Curses.debug_win
      Curses.debug_win.puts "Finished backup on #{@last_backup_time.strftime("%H:%M:%S.%L")}"
      Curses.debug_win.refresh
    end

    @dirty_since_auto_save = false
  end

end
