#!/usr/bin/env ruby
require 'spec_helper'
require 'rspec/mocks'
require 'digest'

require 'puppet/settings'
require 'puppet/settings/digest_algorithms_setting'

describe Puppet::Settings::DigestAlgorithmsSetting do
  subject { described_class.new(:settings => mock('settings'), :desc => "test") }

  describe "when munging the setting" do
    it "raises an error if the value is empty" do
      expect { subject.munge('') }.to raise_error(Puppet::Settings::ValidationError)
    end

    it "raises an error if any algorithms have empty names" do
      expect { subject.munge(',') }.to raise_error(Puppet::Settings::ValidationError)
    end

    it "raises an error if an invalid algorithm is named" do
      expect { subject.munge('flarble') }.to raise_error(Puppet::Settings::ValidationError)
    end

    it "accepts a single named algorithm" do
      # carefully chosen: on FIPS 140-2 compliant hosts, MD5 fails, so
      # if we were to use MD5 in this example, it could pass or fail
      # not based on the code but based on the test host's
      # configuration
      subject.munge('sha256').should == [:sha256]
    end

    context "with a broken checksum algorithm", :sha1fail => true do
      # Avoid emitting warnings during testing
      before :each do
        subject.stubs(:warn)
      end

      it "raises an error if a failing algorithm is the only one named" do
        expect { subject.munge('sha1') }.to raise_error(Puppet::Settings::ValidationError)
      end
      
      it "accepts a single non-failing named algorithm" do
        subject.munge('sha256').should == [:sha256]
      end

      it "removes failing algorithms from a list of multiple algorithms to use" do
        subject.munge('sha1, sha256').should == [:sha256]
      end

      it "warns when a broken checksum algorithm is specified" do
        subject.expects(:warn)
        subject.munge('sha1, sha256')
      end
    end
  end
end

