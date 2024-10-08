require 'rodo'
require 'timecop'

describe TodoDay do

  before do
    #allow(Date).to receive(:today).and_return Date.new(2021, 5, 31)
    #now = Time.now
    #allow(Time).to receive(:now).and_return Time.new(2021, 5, 31, now.hour, now.min, now.sec)    

    Timecop.freeze(Time.local(2021, 5, 31))
  end

  it "TodoDay::merge basic case (single line)" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30
       - [ ] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    j.days[0].merge_lines([" - [ ] My new Todo"])

    expect(j.days.size).to eql(2)

    expect(j.to_s).to eql(<<~EOL
      # 2021-05-30
       - [ ] My Todo
       - [ ] My new Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )
  end

  it "TodoDay::structure_to_a" do

    structure = [
      {:depth=>0, :text=>"# 2021-05-30", :index=>0, :children=>
        [
          {:depth=>1,
            :text=>" - [ ] My Todo",
            :index=>1,
            :children=>[{:depth=>1, :text=>"", :index=>2, :children=>[]}]
          }
        ]
      },
      {:depth=>1, :text=>" - [ ] My new Todo", :index=>0, :children=>[]}
    ]

    expect(TodoDay::structure_to_a(structure)).to eql(
      ["# 2021-05-30",
       " - [ ] My Todo",
       "",
       " - [ ] My new Todo"]
     )
  end


  it "TodoDay::structure simple 1" do

    j = Journal.from_s(<<~EOL
      Text1
      Text2
    EOL
    )

    s = j.days[0].structure

    expect(s.size).to eql(2)
    expect(s[0][:depth]).to eql(0)
    expect(s[0][:text]).to eql("Text1")
    expect(s[1][:text]).to eql("Text2")
  end

  it "TodoDay::structure simple 2" do

    j = Journal.from_s(<<~EOL
      Text1
        Subtext1
      Text2
    EOL
    )

    s = j.days[0].structure

    expect(s).to eql([
      {depth: 0, text: "Text1", index: 0, children: [
        {depth: 2, text: "  Subtext1", index: 1, children: []}
      ]},
      {depth: 0, text: "Text2", index: 2, children: []}
    ])

    expect(s.size).to eql(2)
    expect(s[0][:depth]).to eql(0)
    expect(s[0][:text]).to eql("Text1")
    expect(s[0][:children].size).to eql(1)
    expect(s[1][:text]).to eql("Text2")
  end

  it "TodoDay::structure" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30
       - [ ] My Todo

      H1:
       - [ ] A1
         - [ ] B11
         - [ ] B12
       - [ ] A2
         - [ ] B21
           - [ ] C211

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    s = j.days[0].structure

    expect(s).to eql(
      [
        {:depth=>0, :text=>"# 2021-05-30", index: 0, :children=>[
          {:depth=>1, :text=>" - [ ] My Todo", index: 1, :children=>[]},
        ]},
        {:depth=>0, :text=>"", index: 2, :children=>[]},
        {:depth=>0, :text=>"H1:", index: 3, :children=>
          [
            {:depth=>1, :text=>" - [ ] A1", index: 4, :children=>
              [
                {:depth=>3, :text=>"   - [ ] B11", index: 5, :children=>[]},
                {:depth=>3, :text=>"   - [ ] B12", index: 6, :children=>[]}
              ]},
            {:depth=>1, :text=>" - [ ] A2", index: 7, :children=>
              [
                {:depth=>3, :text=>"   - [ ] B21", index: 8, :children=>
                  [
                    { :depth=>5, :text=>"     - [ ] C211", index: 9, :children=>[]},
                  ]
                }
              ]
            }
          ]
        },
        { :depth=>0, :text=>"", index: 10, :children=>[]}
      ]
    )

    expect(s.size).to eql(4)
    expect(s[0][:depth]).to eql(0)
    expect(s[0][:text]).to eql("# 2021-05-30")
  end

  it "TodoDay::merge case with heading (single line)" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30
       - [ ] My Todo

      Project Todos:
       - [ ] Setup project schedule

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    j.days[0].merge_lines(["Project Todos:", " - [x] Draft whitepaper"])

    expect(j.days.size).to eql(2)

    expect(j.to_s).to eql(<<~EOL
      # 2021-05-30
       - [ ] My Todo

      Project Todos:
       - [ ] Setup project schedule
       - [x] Draft whitepaper

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )
  end

  it "TodoDay::merge case with multiple headings" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30

      Journal:
       - Dear Diary

      Project Todos:
       - [ ] Setup project schedule

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    j.days[0].merge_lines(["Project Todos:", " - [x] Draft whitepaper", "Journal:", " - This was a nice day"])

    expect(j.days.size).to eql(2)

    expect(j.to_s).to eql(<<~EOL
      # 2021-05-30

      Journal:
       - Dear Diary
       - This was a nice day

      Project Todos:
       - [ ] Setup project schedule
       - [x] Draft whitepaper

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )
  end

  it "TodoDay::parent will not get confused by newlines" do

    j = Journal.from_s(<<~EOL + "\n         " # Add line with just spaces
      # 2021-05-30

       - [ ] Main Todo 1

      Heading 1

       - [ ] Main Todo 2

         - [ ] Sub Todo

      Heading 2

       - [ ] Empty Space todo
    EOL
    )

    expect(j.days[0].parent_index(8)).to eql(6)
    expect(j.days[0].parent_index(6)).to eql(4)
    expect(j.days[0].parent_index(4)).to eql(nil)
    expect(j.days[0].parent_index(2)).to eql(nil)
    expect(j.days[0].parent_index(0)).to eql(nil)
    expect(j.days[0].parent_index(13)).to eql(nil)
  end

  it "TodoDay::merge case with complicated newlines" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30

      Journal:
       - Dear Diary

       - There was a break here 1

         - There was a break here 2

      Project Todos:
       - [ ] Setup project schedule

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    j.days[0].merge_lines(["Journal:", " - There was a break here 1", "   - New Todo below break here 2"])

    expect(j.days.size).to eql(2)

    expect(j.to_s).to eql(<<~EOL
      # 2021-05-30

      Journal:
       - Dear Diary

       - There was a break here 1

         - There was a break here 2
         - New Todo below break here 2

      Project Todos:
       - [ ] Setup project schedule

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )
  end

  it "TodoDay::merge_lines and maintain order of new sections" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30

      Project Todos:
       - [ ] Setup project schedule

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    j.days[0].merge_lines(["", "Journal:", " - This was a nice day", "", "Project Todos:", " - [x] Draft whitepaper"])

    expect(j.days.size).to eql(2)

    expect(j.to_s).to eql(<<~EOL
      # 2021-05-30

      Journal:
       - This was a nice day

      Project Todos:
       - [ ] Setup project schedule
       - [x] Draft whitepaper

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )
  end

  it "TodoDay::structure_merge will maintain section ordering" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30

      Project Todos:
       - [ ] Setup project schedule

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    s1 = j.days[0].structure
    s2 = TodoDay.new(["", "Journal:", " - This was a nice day", "", "Project Todos:", " - [x] Draft whitepaper"]).structure
    TodoDay::merge_structures(s1, s2)

    expect(s1).to eql(
      [
        {:children=>[], :depth=>0, :index=>0, :text=>"# 2021-05-30"},
        {:children=>[], :depth=>0, :index=>1, :text=>""},
        { :depth=>0, :index=>2, :text=>"Journal:",
          :children=> [{:children=>[], :depth=>1, :index=>3, :text=>" - This was a nice day"}],
        },
        {:children=>[], :depth=>0, :index=>4, :text=>""},
        {:depth=>0, :index=>5, :text=>"Project Todos:", :children=>
           [{:children=>[],
             :depth=>1,
            :index=>6,
           :text=>" - [ ] Setup project schedule"},
          {:children=>[], :depth=>1, :index=>7, :text=>" - [x] Draft whitepaper"}],
        },
        {:children=>[], :depth=>0, :index=>8, :text=>""}])
  end

  it "TodoDay::is_any_open? and is_closed?" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30
       - [ ] Setup project schedule
       - [x] Draft whitepaper

      # 2021-05-29
       - [ ] My old Todo

      # 2021-05-28
       - [x] Finished fodo
       - [x] Start a todo list
    EOL
    )

    expect(j.days[0].is_any_open?).to eql(true)
    expect(j.days[1].is_any_open?).to eql(true)
    expect(j.days[2].is_any_open?).to eql(false)

    expect(j.days[0].is_closed?).to eql(false)
    expect(j.days[1].is_closed?).to eql(false)
    expect(j.days[2].is_closed?).to eql(true)
  end

  it "TodoDay::test strptime" do

    puts Time.now

    d = Date.strptime("27", "%d", now=Time.now)
    
    expect(d).to eql(Date.new(2021, 5, 27))

  end

end