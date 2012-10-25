require 'spec_helper'

describe "Redis::Marshalling" do
  before(:each) do
    @store = Redis::Store.new :marshalling => true
    @rabbit = OpenStruct.new :name => "bunny"
    @white_rabbit = OpenStruct.new :color => "white"
    @store.set "rabbit", @rabbit
    @store.del "rabbit2"
  end

  after :each do
    @store.quit
  end

  it "should unmarshal an object on get" do
    @store.get("rabbit").should === @rabbit
  end

  it "should marshal object on set" do
    @store.set "rabbit", @white_rabbit
    @store.get("rabbit").should === @white_rabbit
  end

  if RUBY_VERSION.match /1\.9/
    it "should not unmarshal object on get if raw option is true" do
      @store.get("rabbit", :raw => true).should == "\x04\bU:\x0FOpenStruct{\x06:\tnameI\"\nbunny\x06:\x06EF"
    end
  else
    it "should not unmarshal object on get if raw option is true" do
      @store.get("rabbit", :raw => true).should == "\004\bU:\017OpenStruct{\006:\tname\"\nbunny"
    end
  end

  it "should not marshal object on set if raw option is true" do
    @store.set "rabbit", @white_rabbit, :raw => true
    @store.get("rabbit", :raw => true).should == %(#<OpenStruct color="white">)
  end

  it "should not unmarshal object if getting an empty string" do
    @store.set "empty_string", ""
    lambda { @store.get("empty_string").should == "" }.should_not raise_error
  end

  it "should not set an object if already exist" do
    @store.setnx "rabbit", @white_rabbit
    @store.get("rabbit").should === @rabbit
  end

  it "should marshal object on set_unless_exists" do
    @store.setnx "rabbit2", @white_rabbit
    @store.get("rabbit2").should === @white_rabbit
  end

  it "should not marshal object on set_unless_exists if raw option is true" do
    @store.setnx "rabbit2", @white_rabbit, :raw => true
    @store.get("rabbit2", :raw => true).should == %(#<OpenStruct color="white">)
  end

  it "should unmarshal object(s) on multi get" do
    @store.set "rabbit2", @white_rabbit
    rabbit, rabbit2 = @store.mget "rabbit", "rabbit2"
    rabbit.should  == @rabbit
    rabbit2.should == @white_rabbit
  end

  context "marshal with expire" do
    def test_expire_with_key(key)
      @store.setnx "rabbit", @rabbit, key => 1.minute
      @store.get("rabbit").should === @rabbit
    end

    it "should work with rack key" do
      test_expire_with_key(:expire_after)
    end

    it "should work with merb key" do
      test_expire_with_key(:expires_in)
    end

    it "should work with rails key" do
      test_expire_with_key(:expire_in)
    end
  end

  if RUBY_VERSION.match /1\.9/
    it "should not unmarshal object(s) on multi get if raw option is true" do
      @store.set "rabbit2", @white_rabbit
      rabbit, rabbit2 = @store.mget "rabbit", "rabbit2", :raw => true
      rabbit.should  == "\x04\bU:\x0FOpenStruct{\x06:\tnameI\"\nbunny\x06:\x06EF"
      rabbit2.should == "\x04\bU:\x0FOpenStruct{\x06:\ncolorI\"\nwhite\x06:\x06EF"
    end
  else
    it "should not unmarshal object(s) on multi get if raw option is true" do
      @store.set "rabbit2", @white_rabbit
      rabbit, rabbit2 = @store.mget "rabbit", "rabbit2", :raw => true
      rabbit.should  == "\004\bU:\017OpenStruct{\006:\tname\"\nbunny"
      rabbit2.should == "\004\bU:\017OpenStruct{\006:\ncolor\"\nwhite"
    end
  end

  describe "binary safety" do
    it "should marshal objects" do
      utf8_key = [51339].pack("U*")
      ascii_rabbit = OpenStruct.new(:name => [128].pack("C*"))

      @store.set(utf8_key, ascii_rabbit)
      @store.get(utf8_key).should === ascii_rabbit
    end

    it "should get and set raw values" do
      utf8_key = [51339].pack("U*")
      ascii_string = [128].pack("C*")

      @store.set(utf8_key, ascii_string, :raw => true)
      @store.get(utf8_key, :raw => true).bytes.to_a === ascii_string.bytes.to_a
    end

    it "should marshal objects on setnx" do
      utf8_key = [51339].pack("U*")
      ascii_rabbit = OpenStruct.new(:name => [128].pack("C*"))

      @store.del(utf8_key)
      @store.setnx(utf8_key, ascii_rabbit)
      @store.get(utf8_key).should === ascii_rabbit
    end

    it "should get and set raw values on setnx" do
      utf8_key = [51339].pack("U*")
      ascii_string = [128].pack("C*")

      @store.del(utf8_key)
      @store.setnx(utf8_key, ascii_string, :raw => true)
      @store.get(utf8_key, :raw => true).bytes.to_a === ascii_string.bytes.to_a
    end
  end if defined?(Encoding)
end

