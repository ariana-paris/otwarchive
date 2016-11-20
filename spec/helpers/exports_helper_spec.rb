# encoding: utf-8
require 'spec_helper'

describe ExportsHelper do

  it "should generate a tab-delimited file from an array and a header" do
    array = [
      ["Column 1", "Column 2", "Column 3"],
      ["Thing 1", "Thing 2", "Thing 3"],
      ["Foo 1", "Foo 2", "Foo 3"]
    ]
    result = export_csv(array)
    expect(result.encode("utf-8")).to match Regexp.new(/.*Column 3\nThing 1\tThing 2.*/u)
  end
end
