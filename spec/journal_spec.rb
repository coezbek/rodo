require 'rodo'

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

    postponed_day = j.postpone_day(j.days[0], 1)

    expect(postponed_day.date).to eql(Date.new(2021, 5, 31))
    expect(j.days.size).to eql(3)
    expect(j.days[0]).to eql(postponed_day)

  end

  it "Journal::postpone_line will move line to new day" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30
       - [ ] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    postponed_day = j.postpone_line(j.days[0], 1, 1)

    expect(postponed_day.date).to eql(Date.new(2021, 5, 31))
    expect(j.days.size).to eql(3)
    expect(j.days[0]).to eql(postponed_day)

    expect(j.to_s).to eql(<<~EOL
      # 2021-05-31
       - [ ] My Todo

      # 2021-05-30
       - [>] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )
  end

  it "Journal::postpone_line will move line and heading to new day and maintain spacing" do

    j = Journal.from_s(<<~EOL
      # 2021-05-30

      Section
       - [ ] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    postponed_day = j.postpone_line(j.days[0], 3, 1)

    expect(j.days[0].to_s).to eql(<<~EOL.chomp
      # 2021-05-31

      Section
       - [ ] My Todo
    EOL
    )
  end

  it "Journal::postpone_line will merge with existing headings" do

    j = Journal.from_s(<<~EOL
      # 2021-05-31

      Section 1
       - [ ] My Waiting Todo

      # 2021-05-30

      Section 1
       - [ ] My Todo 1

      Section 2
       - [ ] My Todo 2

    EOL
    )

    postponed_day = j.postpone_line(j.days[1], 3, 1)
    expect(postponed_day.date).to eql(Date.new(2021, 5, 31))

    expect(j.days[0].to_s).to eql(<<~EOL.chomp
      # 2021-05-31

      Section 1
       - [ ] My Waiting Todo
       - [ ] My Todo 1
      EOL
    )
  end

  it "Journal::postpone_line will maintain section ordering" do

    j = Journal.from_s(<<~EOL
      # 2021-05-31

      Section 2
       - [ ] My Waiting Todo

      # 2021-05-30

      Section 1
       - [ ] My Todo 1

      Section 2
       - [ ] My Todo 2

    EOL
    )

    postponed_day = j.postpone_line(j.days[1], 3, 1)
    expect(postponed_day.date).to eql(Date.new(2021, 5, 31))

    expect(j.days[0].to_s).to eql(<<~EOL.chomp
      # 2021-05-31

      Section 1
      - [ ] My Todo 1

      Section 2
       - [ ] My Waiting Todo
      EOL
    )
  end

  it "Journal::postpone will reuse existing day" do

    j = Journal.from_s(<<~EOL
      # 2021-05-31
       - [ ] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    postponed_day = j.postpone_day(j.days[1], 1)

    expect(postponed_day.date).to eql(Date.new(2021, 5, 31))
    expect(j.days.size).to eql(2)
    expect(j.days[0]).to eql(postponed_day)
  end

  it "Journal::postpone will reuse later of two existing target days" do

    j = Journal.from_s(<<~EOL
      # 2021-05-31 9:12
       - [ ] My Todo

      # 2021-05-31
       - [>] My Todo

      # 2021-05-29
       - [ ] My old Todo
    EOL
    )

    postponed_day = j.postpone_day(j.days[2], 1)

    expect(postponed_day.date).to eql(Date.new(2021, 5, 31))
    expect(j.days.size).to eql(3)
    expect(j.days[0]).to eql(postponed_day)
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