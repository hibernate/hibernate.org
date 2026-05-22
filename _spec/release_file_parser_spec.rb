require 'awestruct/engine'
require 'awestruct/config'
require 'awestruct/cli/options'
require_relative '../_ext/releases'
require_relative '../_ext/release_file_parser'

describe Awestruct::Extensions::ReleaseFileParser do

    before :all do
        @expectedSeries = ["5.3", "5.2", "5.1", "5.0", "4.3"]
        @expectedReleases = ["5.3.1.Final", "5.3.0.CR1", "5.2.0.Final", "5.2.0.Alpha2", "5.1.0.Alpha1", "5.0.1.Final", "4.3.1.Final"]

        # Use shared test config directory
        test_config_dir = File.join(File.dirname(__FILE__), 'release_file_parser_test_config')
        opts = Awestruct::CLI::Options.new
        opts.source_dir = test_config_dir
        @config = Awestruct::Config.new( opts )
        @config.dir = test_config_dir

        @engine = Awestruct::Engine.new( @config )
        @engine.load_default_site_yaml
    end

    before :each do
        # Create a fresh site object for each test
        @site = Awestruct::Site.new( @engine, @config )

        # Load and merge site.yml data into the site object
        site_yml_path = File.join(@config.dir, '_config', 'site.yml')
        site_data = @engine.load_yaml(site_yml_path)
        site_data.each { |key, value| @site[key] = value }
    end

    it "correct metadata found" do
        # Pass the test-specific data directory
        test_data_dir = File.join(File.dirname(__FILE__), 'release_file_parser_test_data_1', '_data')
        data_dir = Awestruct::Extensions::ReleaseFileParser.new(test_data_dir)
        data_dir.execute( @site )

        expect(@site.projects[:foo].releases.keys).to eql @expectedReleases
        expect(@site.projects[:foo].release_series.keys).to eql @expectedSeries
    end

    it "releases are getting sorted" do
        # Pass the test-specific data directory
        test_data_dir = File.join(File.dirname(__FILE__), 'release_file_parser_test_data_1', '_data')
        data_dir = Awestruct::Extensions::ReleaseFileParser.new(test_data_dir)
        data_dir.execute( @site )

        expect(@site.projects[:foo].releases).to be_an_instance_of Hash
        expect(@site.projects[:foo].latest_series.version).to eql "5.3"
        expect(@site.projects[:foo].latest_stable_series.version).to eql "5.3"
        expect(@site.projects[:foo].latest_release.version).to eql "5.3.1.Final"
        expect(@site.projects[:foo].latest_stable_release.version).to eql "5.3.1.Final"

        @site.projects[:foo].releases.values.each_with_index do |release, index|
            expect(release[:version]).to eql @expectedReleases[index]
        end

        @site.projects[:foo].release_series.values.each_with_index do |series, index|
            expect(series[:version]).to eql @expectedSeries[index]
        end
    end

    it "Missing .yml extension is aborting the extension" do
        # Pass the test-specific data directory
        test_data_dir = File.join(File.dirname(__FILE__), 'release_file_parser_test_data_2', '_data')
        data_dir = Awestruct::Extensions::ReleaseFileParser.new(test_data_dir)
        expect(lambda { data_dir.execute( @site ) }).to raise_error(SystemExit, /The release file .* does not have the YAML \(.yml\) extension!/)
    end

    it "release unrelated files should be ignored" do
        # Pass the test-specific data directory
        test_data_dir = File.join(File.dirname(__FILE__), 'release_file_parser_test_data_3', '_data')
        data_dir = Awestruct::Extensions::ReleaseFileParser.new(test_data_dir)
        data_dir.execute( @site )
        expect(@site.projects[:foo].releases.length).to eql 1
    end

    describe "#extractCommentFromConstraint" do
        before :each do
            @parser = Awestruct::Extensions::ReleaseFileParser.new
        end

        it "extracts comment from single range hash" do
            constraint = { from: '38', to: '39', comment: 'Preview' }
            expect(@parser.send(:extractCommentFromConstraint, constraint, '38')).to eql 'Preview'
            expect(@parser.send(:extractCommentFromConstraint, constraint, '39')).to eql 'Preview'
        end

        it "extracts comment from array of discrete values" do
            constraint = [
                { value: '11', comment: 'Java 11' },
                { value: '17', comment: 'Java 17' }
            ]
            expect(@parser.send(:extractCommentFromConstraint, constraint, '11')).to eql 'Java 11'
            expect(@parser.send(:extractCommentFromConstraint, constraint, '17')).to eql 'Java 17'
        end

        it "extracts comment from array of range hashes" do
            constraint = [
                { from: '34', to: '39' },
                { from: '40', to: '41', comment: 'EE 10 variant' }
            ]
            expect(@parser.send(:extractCommentFromConstraint, constraint, '34')).to be_nil
            expect(@parser.send(:extractCommentFromConstraint, constraint, '39')).to be_nil
            expect(@parser.send(:extractCommentFromConstraint, constraint, '40')).to eql 'EE 10 variant'
            expect(@parser.send(:extractCommentFromConstraint, constraint, '41')).to eql 'EE 10 variant'
        end

        it "returns nil when version is outside commented range" do
            constraint = [
                { from: '40', to: '41', comment: 'EE 10 variant' }
            ]
            expect(@parser.send(:extractCommentFromConstraint, constraint, '39')).to be_nil
            expect(@parser.send(:extractCommentFromConstraint, constraint, '42')).to be_nil
        end

        it "returns nil when no comment exists" do
            constraint = { from: '34', to: '39' }
            expect(@parser.send(:extractCommentFromConstraint, constraint, '34')).to be_nil
        end
    end
end
