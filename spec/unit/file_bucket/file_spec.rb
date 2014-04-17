#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_bucket/file'
require 'digest/md5'
require 'digest/sha1'

describe Puppet::FileBucket::File do
  include PuppetSpec::Files

  let(:contents) { "file\r\n contents" }
  let(:digest) { "8b3702ad1aed1ace7e32bde76ffffb2d" }
  let(:checksum) { "{md5}#{digest}" }
  # this is the default from spec_helper, but it keeps getting reset at odd times
  let(:bucketdir) { Puppet[:bucketdir] = tmpdir('bucket') }
  let(:destdir) { File.join(bucketdir, "8/b/3/7/0/2/a/d/#{digest}") }
  let(:sha1digest) { "8b1ab916151c0e1c2fedd3380e1d5c427e7d3924" }
  let(:sha1checksum) { "{sha1}#{sha1digest}" }
  let(:sha1destdir) { File.join(bucketdir, "8/b/1/a/b/9/1/6/#{sha1digest}") }
  let(:sha256digest) { "7152323bbca95871b2090190e80a02e05d7f164df9c4c3f543f6ff63dd817523" }
  let(:sha256checksum) { "{sha256}#{sha256digest}" }
  let(:sha256destdir) { File.join(bucketdir, "7/1/5/2/3/2/3/b/#{sha256digest}") }

  it "defaults to serializing to `:s`" do
    expect(Puppet::FileBucket::File.default_format).to eq(:s)
  end

  it "accepts s and pson" do
   expect(Puppet::FileBucket::File.supported_formats).to include(:s, :pson)
  end

  it "can make a round trip through `s`" do
    file = Puppet::FileBucket::File.new(contents)

    tripped = Puppet::FileBucket::File.convert_from(:s, file.render)

    expect(tripped.contents).to eq(contents)
  end

  it "can make a round trip through `pson`" do
    file = Puppet::FileBucket::File.new(contents)

    tripped = Puppet::FileBucket::File.convert_from(:pson, file.render(:pson))

    expect(tripped.contents).to eq(contents)
  end

  it "should raise an error if changing content" do
    x = Puppet::FileBucket::File.new("first")
    expect { x.contents = "new" }.to raise_error(NoMethodError, /undefined method .contents=/)
  end

  it "should require contents to be a string" do
    expect { Puppet::FileBucket::File.new(5) }.to raise_error(ArgumentError, /contents must be a String, got a Fixnum$/)
  end

  it "should complain about options other than :bucket_path" do
    expect {
      Puppet::FileBucket::File.new('5', :crazy_option => 'should not be passed')
    }.to raise_error(ArgumentError, /Unknown option\(s\): crazy_option/)
  end

  it "should set the contents appropriately" do
    Puppet::FileBucket::File.new(contents).contents.should == contents
  end

  describe "with digest_algorithms = md5" do
    include_context 'digest_algorithms', 'md5'

    it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
      Puppet::FileBucket::File.new(contents).checksum_type.should == :md5
    end

    it "should calculate the MD5 checksum" do
      Puppet::FileBucket::File.new(contents).checksum.should == checksum
    end

    it "should return a url-ish name with md5 in it" do
      Puppet::FileBucket::File.new(contents).name.should == "md5/#{digest}"
    end
  end

  describe "with digest_algorithms = sha1, sha256" do
    include_context 'digest_algorithms', 'sha1, sha256'

    it "should default to 'sha1' as the checksum algorithm if the algorithm is not in the name" do
      Puppet::FileBucket::File.new(contents).checksum_type.should == :sha1
    end

    it "should calculate the SHA-1 checksum" do
      Puppet::FileBucket::File.new(contents).checksum.should == sha1checksum
    end

    it "should return a url-ish name with sha1 in it" do
      Puppet::FileBucket::File.new(contents).name.should == "sha1/#{sha1digest}"
    end
  end

  describe "when using back-ends" do
    it "should redirect using Puppet::Indirector" do
      Puppet::Indirector::Indirection.instance(:file_bucket_file).model.should equal(Puppet::FileBucket::File)
    end

    it "should have a :save instance method" do
      Puppet::FileBucket::File.indirection.should respond_to(:save)
    end
  end

  it "should reject a url-ish name with an invalid checksum" do
    bucket = Puppet::FileBucket::File.new(contents)
    expect { bucket.name = "sha1/ae548c0cd614fb7885aaa0b6cb191c34/new/path" }.to raise_error(NoMethodError, /undefined method .name=/)
  end

  it "should convert the contents to PSON" do
    Puppet.expects(:deprecation_warning).with('Serializing Puppet::FileBucket::File objects to pson is deprecated.')
    Puppet::FileBucket::File.new("file contents").to_pson.should == '{"contents":"file contents"}'
  end

  it "should load from PSON" do
    Puppet.expects(:deprecation_warning).with('Deserializing Puppet::FileBucket::File objects from pson is deprecated. Upgrade to a newer version.')
    Puppet::FileBucket::File.from_pson({"contents"=>"file contents"}).contents.should == "file contents"
  end


  describe "with digest_algorithms = md5" do
    include_context 'digest_algorithms', 'md5'
    def make_bucketed_file
      FileUtils.mkdir_p(destdir)
      File.open("#{destdir}/contents", 'wb') { |f| f.write contents }
    end

    describe "using the indirector's find method" do
      it "should return nil if a file doesn't exist" do
        bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{digest}")
        bucketfile.should == nil
      end

      it "should find a filebucket if the file exists" do
        make_bucketed_file
        bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{digest}")
        bucketfile.checksum.should == checksum
      end
      # The "using RESTish notation" tests that used to be here became
      # redundant in 89f56920.
    end

    it "should save a bucketed file using the md5 checksum" do
      fbf = Puppet::FileBucket::File.new contents, :bucket_path => bucketdir
      t = Puppet::FileBucket::File.indirection.terminus(:file)
      t.expects(:save_to_disk).once.with(any_parameters) { |a,b,c,d| c.to_s.include? destdir }
      Puppet::FileBucket::File.indirection.save(fbf)
    end
  end

  describe "with digest_algorithms = sha1, sha256" do
    include_context 'digest_algorithms', 'sha1, sha256'
    def make_bucketed_file
      FileUtils.mkdir_p(sha1destdir)
      FileUtils.mkdir_p(sha256destdir)
      File.open("#{sha1destdir}/contents", 'wb') { |f| f.write contents }
      File.open("#{sha256destdir}/contents", 'wb') { |f| f.write contents }
    end

    describe "using the indirector's find method" do
      it "should return nil if a file doesn't exist" do
        bucketfile = Puppet::FileBucket::File.indirection.find("sha1/#{sha1digest}")
        bucketfile.should == nil
      end

      it "should find a filebucket if the file exists using sha1" do
        make_bucketed_file
        bucketfile = Puppet::FileBucket::File.indirection.find("sha1/#{sha1digest}")
        bucketfile.checksum.should == sha1checksum
      end

      it "should find a filebucket if the file exists using sha256" do
        make_bucketed_file
        bucketfile = Puppet::FileBucket::File.indirection.find("sha256/#{sha256digest}")
        # Is this really weird? Will it break things?
        bucketfile.checksum.should == sha1checksum
      end
    end

    it "should save a bucketed file using both the sha1 and sha256 checksums" do
      fbf = Puppet::FileBucket::File.new contents, :bucket_path => bucketdir
      t = Puppet::FileBucket::File.indirection.terminus(:file)
      t.expects(:save_to_disk).once.with(any_parameters) { |a,b,c,d| c.to_s.include? sha1destdir }
      t.expects(:save_to_disk).once.with(any_parameters) { |a,b,c,d| c.to_s.include? sha256destdir }
      Puppet::FileBucket::File.indirection.save(fbf)
    end
  end
end
