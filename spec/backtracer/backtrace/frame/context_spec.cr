require "../../../spec_helper"

describe Backtracer::Backtrace::Frame::Context do
  describe ".to_h" do
    it "works with empty #pre and #post" do
      context = Backtracer::Backtrace::Frame::Context.new(
        lineno: 1,
        pre: %w[],
        line: "violent offender!",
        post: %w[],
      )
      context.to_h.should eq({1 => "violent offender!"})
    end

    it "returns hash with #pre, #line and #post strings" do
      context = Backtracer::Backtrace::Frame::Context.new(
        lineno: 10,
        pre: %w[foo bar baz],
        line: "violent offender!",
        post: %w[boo far faz],
      )
      context.to_h.should eq({
         7 => "foo",
         8 => "bar",
         9 => "baz",
        10 => "violent offender!",
        11 => "boo",
        12 => "far",
        13 => "faz",
      })
    end
  end
end
