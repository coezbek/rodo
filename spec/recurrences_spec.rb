require 'rodo'
require 'rrule'

describe Recurrences do

  before do
    # allow(Date).to receive(:today).and_return Date.new(2021, 5, 31)
    Timecop.freeze(Time.local(2021, 5, 31))
  end

  it "Test RRule" do
    puts RRule.parse('FREQ=YEARLY', dtstart: Date.parse("1981-01-13")).all(limit: 2).first
  end

  it "Test LIMIT" do
    recur = <<~recurrences
      # Daily
       - LIMIT=2 [ ] Do it every day and catch up once on missed days
       - [ ] Do it every day but don't catch up
      
    recurrences

    journal = Journal.from_s("# #{Time.now.strftime("%Y-%m-%d")}\n")
    journal.recurrences = Recurrences.from_s(recur)

    Timecop.freeze(Time.parse("2021-06-02")) do 
      newDay = journal.close(journal.days[journal.most_recent_open_index])
      result = journal.days[newDay].to_s
      
      expect(result.scan("- [ ] Do it every day and catch up once on missed days").length).to eq(2)
      expect(result.scan("- [ ] Do it every day but don't catch up").length).to eq(1)
    end      
  
  end

end