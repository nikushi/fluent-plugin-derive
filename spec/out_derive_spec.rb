# encoding: UTF-8
require_relative 'spec_helper'

describe Fluent::DeriveOutput do
  before { Fluent::Test.setup }
  let(:tag) { 'counter.host1' }
  let(:driver) { Fluent::Test::OutputTestDriver.new(Fluent::DeriveOutput, tag).configure(config) }

  describe 'test configure' do
    describe 'bad configuration' do
      context 'none of key_pattern or key1 are included' do
        let(:config) { "" }
        it { expect { driver }.to raise_error(Fluent::ConfigError) }
      end
      context 'none of tag, add_tag_prefix, or remove_tag_prefix are included' do
        let(:config) { "key1 foo" }
      end
      context 'min greater than max' do
        let(:config) {%[
          tag rate
          key1 foo_count
          min 1
          max 0
        ]}
        it { expect { driver }.to raise_error(Fluent::ConfigError) }
      end
      context 'min == max' do
        let(:config) {%[
          tag rate
          key1 foo_count
          min 1
          max 1
        ]}
        it { expect { driver }.to raise_error(Fluent::ConfigError) }
      end
    end

    describe 'good configuration' do
      subject { driver.instance }
      
      context "check default" do
        let(:config) { %[
          tag rate
          key1 foo
        ] }
        its(:tag) { should eq "rate" }
        its(:add_tag_prefix) { should be_nil }
        its(:remove_tag_prefix) { should be_nil }
        its(:min) { should be_nil }
        its(:max) { should be_nil }
      end

      context "key_pattern" do
        let(:config) {%[
          tag rate
          key_pattern _count$
        ]}
        it { subject.key_pattern.should == Regexp.compile("_count$") }
      end

      context "key_pattern_adjustment" do
        let(:config) {%[
          tag rate
          key_pattern _count$ *1000
        ]}
        it { subject.key_pattern_adjustment.should eq ['*', 1000] }
      end

      context "keys" do
        let(:config) {%[
          tag rate
          key1 foo_count
          key2 bar_count
        ]}
        it { subject.keys["foo_count"].should be_nil }
        it { subject.keys["bar_count"].should be_nil }
      end

      context "keys adjustment" do
        let(:config) {%[
          tag rate
          key1 foo_count *1000
          key2 bar_count /1000
        ]}
        it { subject.keys["foo_count"].should eq ['*', 1000] }
        it { subject.keys["bar_count"].should eq ['/', 1000] }
      end

      context 'min < max' do
        let(:config) {%[
          tag rate
          key1 foo_count
          min 0
          max 1
        ]}
        it { expect { driver }.not_to raise_error(Fluent::ConfigError) }
      end
 
    end
  end

  describe 'test emit' do
    let(:time) { Time.now.to_i }

    context 'keys' do

      context 'normal' do
        let(:config) { %[
          tag rate
          key1 foo_count
          key2 bar_count
        ]}
        before do
          driver.run { 
            driver.emit({'foo_count'=> 100, 'bar_count' =>200, 'other_key' => 'abc'}, time) 
            driver.emit({'foo_count'=> 700, 'bar_count' =>1400}, time + 60) 
            driver.emit({'foo_count'=> 700, 'bar_count' =>800}, time + 120) 
          }
        end
        it {
          driver.emits[0].should == ['rate', time, {'foo_count' => nil, 'bar_count' => nil, 'other_key' => 'abc'}]
          driver.emits[1].should == ['rate', time + 60, {'foo_count' => 10, 'bar_count' => 20}]
          driver.emits[2].should == ['rate', time + 120, {'foo_count' => 0, 'bar_count' => -10}]
          driver.instance.prev.should == {"#{tag}:foo_count"=>[time+120, 700], "#{tag}:bar_count"=>[time+120, 800]}
        }
      end

      context 'multiple records in same time' do
        let(:config) { %[
          tag rate
          key1 foo_count
          key2 bar_count
        ]}
        before do
          driver.run { 
            driver.emit({'foo_count'=> 100, 'bar_count' =>200}, time) 
            driver.emit({'foo_count'=> 100, 'bar_count' =>200}, time) 
          }
        end
        it {
          driver.emits[1].should == ['rate', time, {'foo_count' => nil, 'bar_count' => nil}]
        }
      end

      context 'adjustment' do
        let(:config) { %[ 
          tag rate
          key1 foo_count
          key2 bar_count
          key3 baz_count *1000
        ]}
        before do
          driver.run {
            driver.emit({'foo_count'=> 100, 'bar_count' =>200, 'baz_count' => 300}, time) 
            driver.emit({'foo_count'=> 700, 'bar_count' =>1400, 'baz_count' => 900}, time + 60) 
          }
        end
        it {
          driver.emits[0].should == ['rate', time, {'foo_count' => nil, 'bar_count' => nil, 'baz_count' => nil}]
          driver.emits[1].should == ['rate', time + 60, {'foo_count' => 10, 'bar_count' => 20, 'baz_count' => 10000}]
        }
      end

      context 'min/max' do
        let(:config) { %[ 
          tag rate
          key1 foo_count
          key2 bar_count *1000000
          min 0
          max 1000
        ]}
        before do
          driver.run {
            driver.emit({'foo_count'=> 100, 'bar_count'=>0}, time) 
            driver.emit({'foo_count'=> 0,   'bar_count'=>6000}, time + 60) 
          }
        end
        it {
          driver.emits[1].should == ['rate', time + 60, {'foo_count' => 0, 'bar_count' => 1000}]
        }
      end

      context 'add_tag_prefix' do
        let(:config) {%[
          add_tag_prefix rate
          key1 foo_count
          key2 bar_count
        ]}
        before do
          driver.run { 
            driver.emit({'foo_count'=> 100, 'bar_count' =>200, 'other_key' => 'abc'}, time) 
          }
        end
        it { driver.emits[0][0].should == "rate.#{tag}" }
      end

      context 'remove_tag_prefix' do
        let(:config) {%[
          remove_tag_prefix counter
          key1 foo_count
          key2 bar_count
        ]}
        before do
          driver.run { 
            driver.emit({'foo_count'=> 100, 'bar_count' =>200, 'other_key' => 'abc'}, time) 
          }
        end
        it { driver.emits[0][0].should == 'host1' }
      end
    end

    context 'key_pattern' do

      context 'normal' do
        let(:config) { %[
          tag rate
          key_pattern .*_count$
        ]}
        before do
          driver.run { 
            driver.emit({'foo_count'=> 100, 'bar_count' =>200, 'other_key' => 'abc'}, time) 
            driver.emit({'foo_count'=> 700, 'bar_count' =>1400}, time + 60) 
            driver.emit({'foo_count'=> 700, 'bar_count' =>800}, time + 120) 
          }
        end
        it {
          driver.emits[0].should == ['rate', time, {'foo_count' => nil, 'bar_count' => nil, 'other_key' => 'abc'}]
          driver.emits[1].should == ['rate', time + 60, {'foo_count' => 10, 'bar_count' => 20}]
          driver.emits[2].should == ['rate', time + 120, {'foo_count' => 0, 'bar_count' => -10}]
          driver.instance.prev.should == {"#{tag}:foo_count"=>[time+120, 700], "#{tag}:bar_count"=>[time+120, 800]}
        }
      end

      context 'multiple records in same time' do
        let(:config) { %[
          tag rate
          key_pattern .*_count$
        ]}
        before do
          driver.run { 
            driver.emit({'foo_count'=> 100, 'bar_count' =>200}, time) 
            driver.emit({'foo_count'=> 100, 'bar_count' =>200}, time) 
          }
        end
        it {
          driver.emits[1].should == ['rate', time, {'foo_count' => nil, 'bar_count' => nil}]
        }
      end

      context 'adjustment' do
        let(:config) { %[ 
          tag rate
          key_pattern .*_count$ /10
        ]}
        before do
          driver.run {
            driver.emit({'foo_count'=> 100, 'bar_count' =>200, 'baz_count' => 300}, time) 
            driver.emit({'foo_count'=> 700, 'bar_count' =>1400, 'baz_count' => 900}, time + 60) 
          }
        end
        it {
          driver.emits[0].should == ['rate', time, {'foo_count' => nil, 'bar_count' => nil, 'baz_count' => nil}]
          driver.emits[1].should == ['rate', time + 60, {'foo_count' => 1, 'bar_count' => 2, 'baz_count' => 1}]
        }
      end

      context 'min/max' do
        let(:config) { %[ 
          tag rate
          key_pattern .*_count$ *10000
          min 0
          max 1000
        ]}
        before do
          driver.run {
            driver.emit({'foo_count'=> 100, 'bar_count'=>0}, time) 
            driver.emit({'foo_count'=> 0,   'bar_count'=>6000}, time + 60) 
          }
        end
        it {
          driver.emits[1].should == ['rate', time + 60, {'foo_count' => 0, 'bar_count' => 1000}]
        }
      end


    end

  end
end
