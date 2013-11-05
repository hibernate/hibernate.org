require 'awestruct/logger'
require 'awestruct/cli/options'
require 'awestruct/engine'
require_relative '../_ext/releases'
require_relative '../_ext/release_file_parser'
 
describe Awestruct::Extensions::ReleaseFileParser do

    before :all do
        @expectedReleases = ["5.1.0.Alpha1", "5.0.1.Final", "4.3.1.Final"]

        $LOG = Logger.new(Awestruct::AwestructLoggerMultiIO.new(true, STDOUT))
        config = Awestruct::Config.new( File.dirname(__FILE__) + '/..' )
      
        engine = Awestruct::Engine.new( config )
        engine.load_default_site_yaml

        # reset the config dir to load the test data. DataDir is relative to site.dir 
        config.dir = File.dirname(__FILE__) + '/test-data'
        @site = Awestruct::Site.new( engine, config )
    end

    it "correct test releases found" do
        data_dir = Awestruct::Extensions::ReleaseFileParser.new
        data_dir.execute( @site )
        @site.projects[:foo].releases.length.should eql 3

        @expectedReleases.each do |x| 
           @site.projects[:foo].releases.has_key?( x ).should be_true  
        end       
    end

    it "sorted releases are getting created" do
        data_dir = Awestruct::Extensions::ReleaseFileParser.new
        data_dir.execute( @site )

        @site.projects[:foo].releases.should be_an_instance_of Hash
        @site.projects[:foo].sorted_releases.should be_an_instance_of Array

        @site.projects[:foo].sorted_releases.each_with_index do |releaseHash, index| 
            releaseHash[:version].should eql @expectedReleases[index] 
        end
    end
end