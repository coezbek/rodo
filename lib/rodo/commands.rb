
module Commands

    def initialize
    @command_prototyp_list = [
      {
        description: "p(ostpone) todo by number of n days (p <n>)",
        regex: /^po?s?t?p?o?n?e?\s*(\d*)\s*$/,
        prototype: "p ",
        do_cmd: lambda { |cmd, lines, day|
          if cmd =~ /^p\s*(\d*)\s*$/
            postpone(lines, day, $1.to_i, '>')
          end
        }
      },
      "t(oday): move all unfinished tasks to today's entry",
      "k(ill): remove the current line",
      "m(ove): enter movement mode",
      "a(ppend): insert a new todo after the current line",
      "i(nsert): insert a new todo before the current line",
      "w(aiting): move the current todo 7 days into the future",
      {
        description: "q(uit): exit and save",
        prototype: "q"
      }
    ]
  end

end