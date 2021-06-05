describe Journal do

  before do
    allow(Date).to receive(:today).and_return Date.new(2021, 5, 31)
  end

  it "Journal::postpone will create a new day" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30
       - [ ] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    postponed_day = j.postpone(j.days[0], 1)

    expect(postponed_day.date).to eql(Date.new(2021, 5, 31))
    expect(j.days.size).to eql(3)
    expect(j.days[0]).to eql(postponed_day)

  end

  it "Journal::postpone will reuse existing day" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30
       - [ ] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    postponed_day = j.postpone(j.days[1], 1)

    expect(postponed_day.date).to eql(Date.new(2021, 5, 30))
    expect(j.days.size).to eql(2)
    expect(j.days[0]).to eql(postponed_day)
  end

  it "Journal::postpone will reuse later of two existing target days" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30 9:12
       - [ ] My Todo

      # 2021-05-30
       - [>] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    postponed_day = j.postpone(j.days[2], 1)

    expect(postponed_day.date).to eql(Date.new(2021, 5, 30))
    expect(j.days.size).to eql(3)
    expect(j.days[0]).to eql(postponed_day)
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

  it "Journal::close basic test case" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30

       - [ ] Main Todo 1
         - [ ] Sub Todo 1
         - [x] Sub Todo 2
       - [x] Main Todo 2
         - [ ] Sub Todo 3

      Heading 1
       - [ ] Main Todo 3
         - [ ] Sub Todo 4

      # 2021-05-29

       - [x] Data from other day 1
       - [ ] Data from other day 2
    EOL
    )

    i = j.close(j.days[0])

    expect(j.days.size).to eql(3)
    expect(i).to eql(0)
    expect(j.days[i].lines.join("\n")).to eql(<<~EOL
      # 2021-05-31

       - [ ] Main Todo 1
         - [ ] Sub Todo 1
       - [x] Main Todo 2
         - [ ] Sub Todo 3

      Heading 1
       - [ ] Main Todo 3
         - [ ] Sub Todo 4
   EOL
    )
  end


end