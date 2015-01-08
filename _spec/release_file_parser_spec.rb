require 'awestruct/logger'
# need to create the logger prior to loading the engine module to avoid errors when the code
# tries to access the logger
$LOG = Logger.new(Awestruct::AwestructLoggerMultiIO.new)
$LOG.level = Logger::DEBUG
$LOG.formatter = Awestruct::AwestructLogFormatter.new

require 'awestruct/engine'
require 'awestruct/config'
require 'awestruct/cli/options'
require_relative '../_ext/releases'
require_relative '../_ext/release_file_parser'

describe Awestruct::Extensions::ReleaseFileParser do

    before :all do
        @expectedReleases = ["5.1.0.Alpha1", "5.0.1.Final", "4.3.1.Final"]

        site_dir = File.join(File.dirname(__FILE__), '..')
        opts = Awestruct::CLI::Options.new
        opts.source_dir = site_dir
        @config = Awestruct::Config.new( opts )

        @engine = Awestruct::Engine.new( @config )
        @engine.load_default_site_yaml
    end

    it "correct test releases found" do
        # reset the config dir to load the test data. DataDir is relative to site.dir
        @config.dir = File.dirname(__FILE__) + '/release_file_parser_test_data_1'
        site = Awestruct::Site.new( @engine, @config )

        data_dir = Awestruct::Extensions::ReleaseFileParser.new
        data_dir.execute( site )
        expect(site.projects[:foo].releases.length).to eql 3

        @expectedReleases.each do |x|
           expect(site.projects[:foo].releases.has_key?( x )).to be_truthy
        end
    end

    it "sorted releases are getting created" do
        # reset the config dir to load the test data. DataDir is relative to site.dir
        @config.dir = File.dirname(__FILE__) + '/release_file_parser_test_data_1'
        site = Awestruct::Site.new( @engine, @config )

        data_dir = Awestruct::Extensions::ReleaseFileParser.new
        data_dir.execute( site )

        expect(site.projects[:foo].releases).to be_an_instance_of Hash
        expect(site.projects[:foo].sorted_releases).to be_an_instance_of Array

        site.projects[:foo].sorted_releases.each_with_index do |releaseHash, index|
            expect(releaseHash[:version]).to eql @expectedReleases[index]
        end
    end

    it "Missing .yml extension is aborting the extension" do
        # reset the config dir to load the test data. DataDir is relative to site.dir
        @config.dir = File.dirname(__FILE__) + '/release_file_parser_test_data_2'
        site = Awestruct::Site.new( @engine, @config )

        data_dir = Awestruct::Extensions::ReleaseFileParser.new
        expect(lambda { data_dir.execute( site ) }).to raise_error(SystemExit, /The release file .* does not have the YAML \(.yml\) extension!/)
    end

    it "release unrelated files should be ignored" do
        # reset the config dir to load the test data. DataDir is relative to site.dir
        @config.dir = File.dirname(__FILE__) + '/release_file_parser_test_data_3'
        site = Awestruct::Site.new( @engine, @config )

        data_dir = Awestruct::Extensions::ReleaseFileParser.new
        data_dir.execute( site )
        expect(site.projects[:foo].releases.length).to eql 1
    end
end