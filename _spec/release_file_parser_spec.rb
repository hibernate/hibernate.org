require 'awestruct/engine'
require 'awestruct/config'
require 'awestruct/cli/options'
require_relative '../_ext/releases'
require_relative '../_ext/release_file_parser'

describe Awestruct::Extensions::ReleaseFileParser do

    before :all do
        @expectedSeries = ["5.3", "5.2", "5.1", "5.0", "4.3"]
        @expectedReleases = ["5.3.1.Final", "5.3.0.CR1", "5.2.0.Final", "5.2.0.Alpha2", "5.1.0.Alpha1", "5.0.1.Final", "4.3.1.Final"]

        site_dir = File.join(File.dirname(__FILE__), '..')
        opts = Awestruct::CLI::Options.new
        opts.source_dir = site_dir
        @config = Awestruct::Config.new( opts )

        @engine = Awestruct::Engine.new( @config )
        @engine.load_default_site_yaml
    end

    it "correct metadata found" do
        # reset the config dir to load the test data. DataDir is relative to site.dir
        @config.dir = File.dirname(__FILE__) + '/release_file_parser_test_data_1'
        site = Awestruct::Site.new( @engine, @config )

        data_dir = Awestruct::Extensions::ReleaseFileParser.new
        data_dir.execute( site )
        
        expect(site.projects[:foo].releases.keys).to eql @expectedReleases
        expect(site.projects[:foo].release_series.keys).to eql @expectedSeries
    end

    it "releases are getting sorted" do
        # reset the config dir to load the test data. DataDir is relative to site.dir
        @config.dir = File.dirname(__FILE__) + '/release_file_parser_test_data_1'
        site = Awestruct::Site.new( @engine, @config )

        data_dir = Awestruct::Extensions::ReleaseFileParser.new
        data_dir.execute( site )

        expect(site.projects[:foo].releases).to be_an_instance_of Hash
        expect(site.projects[:foo].latest_series.version).to eql "5.3"
        expect(site.projects[:foo].latest_stable_series.version).to eql "5.3"
        expect(site.projects[:foo].latest_release.version).to eql "5.3.1.Final"
        expect(site.projects[:foo].latest_stable_release.version).to eql "5.3.1.Final"

        site.projects[:foo].releases.values.each_with_index do |release, index|
            expect(release[:version]).to eql @expectedReleases[index]
        end

        site.projects[:foo].release_series.values.each_with_index do |series, index|
            expect(series[:version]).to eql @expectedSeries[index]
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
