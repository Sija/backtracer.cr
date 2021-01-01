require "../../spec_helper"

describe Backtracer::Backtrace::Frame do
  it "#inspect" do
    with_foo_frame do |frame|
      frame.inspect.should match(/Backtrace::Frame(.*)$/)
    end
  end

  it "#to_s" do
    with_foo_frame(path: "#{__DIR__}/foo.cr") do |frame|
      frame.to_s.should eq "`foo_bar?` at #{__DIR__}/foo.cr:1:7"
    end
  end

  it "#==" do
    with_foo_frame do |frame|
      with_foo_frame do |frame2|
        frame.should eq(frame2)
      end
      with_foo_frame(method: "other_method") do |frame3|
        frame.should_not eq(frame3)
      end
    end
  end
end
