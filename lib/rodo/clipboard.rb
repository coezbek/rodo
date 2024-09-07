
class Clipboard

  def self.wsl?
    @@wsl ||= File.file?('/proc/version') && File.open('/proc/version', &:gets).downcase.include?("microsoft")
  end

  # Returns the given format
  def self.get(format)

    if wsl?

      case format
      when :auto
        # html = <<~`HEREDOC`
        #   powershell.exe '
        #     add-type -an system.windows.forms;
        #     $content = [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::Html);
        #     [Console]::OutputEncoding = [System.Text.Encoding]::UTF8;
        #     [Console]::WriteLine($content)
        #   '
        # HEREDOC

        clip = <<~`HEREDOC`
          powershell.exe '
            add-type -an system.windows.forms;

            # Check if the clipboard contains HTML data
            $htmlAvailable = [System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::Html);
            
            if ($htmlAvailable) {
              # Get HTML content from clipboard and prepend "HTML:"
              $content = "HTML:" + [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::Html);
            } else {
              # Fallback to plain text if no HTML is found and prepend "TXT:"
              $content = "TXT:" + [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::Text);
            }

            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8;
            [Console]::WriteLine($content);
          '
        HEREDOC

        if clip =~ /HTML:(.*)/m
          html = $1
          if html =~ /<!--StartFragment-->(.*)<!--EndFragment-->/m
            html = "<html><body>#{$1}</body></html>"
          elsif html =~ /\A.*?(<html>.*\Z)/m
            html = $1
          end
          return { type: :html, content: html }
        else
          return { type: :text, content: clip.delete_prefix("TXT:") }
        end
      end

    end
    return nil
  end

  def self.get_continuous(format)

    require 'open3'
    Open3.popen3('powershell.exe -NoExit -NonInteractive -Command "add-type -an system.windows.forms;"') do |stdin, stdout, stderr, wait_thr|
      stdin.puts <<~HEREDOC
        $content = [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::Html);
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8;
        [Console]::WriteLine($content)
      HEREDOC
      begin
        puts stdout.read_nonblock(1)
      rescue IO::WaitReadable
        IO.select([stdin])
        retry
      end
      # puts "stdout is:" + stdout.read_nonblock(100)
      #puts "stderr is:" + stderr.read
    end
  end

end

if __FILE__==$0
  html = Clipboard.get_continuous(:html)

  puts html
  puts

  require 'reverse_markdown'
  markdown = ReverseMarkdown.convert(html, unknown_tags: :bypass)
  puts markdown.gsub('&nbsp;', ' ')

end