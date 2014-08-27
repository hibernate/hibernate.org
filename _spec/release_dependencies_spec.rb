require 'awestruct/logger'
# need to create the logger prior to loading the engine module to avoid errors when the code
# tries to access the logger
$LOG = Logger.new(Awestruct::AwestructLoggerMultiIO.new)
$LOG.level = Logger::DEBUG
$LOG.formatter = Awestruct::AwestructLogFormatter.new

require_relative '../_ext/release_file_parser'

describe Awestruct::Extensions::ReleaseDependencies do

  before :all do
    site_dir = File.join(File.dirname(__FILE__), '..')
    opts = Awestruct::CLI::Options.new
    opts.source_dir = site_dir
    @config = Awestruct::Config.new( opts )

    @engine = Awestruct::Engine.new( @config )
    @engine.load_default_site_yaml
    @site = Awestruct::Site.new( @engine, @config )

    @deps = [
      Awestruct::Extensions::ReleaseDependencies.new(@site, 'org.hibernate', 'hibernate-core', '4.0.0.Beta1'),
      Awestruct::Extensions::ReleaseDependencies.new(@site, 'org.hibernate', 'hibernate-search-parent', '3.4.0.Final'),
      Awestruct::Extensions::ReleaseDependencies.new(@site, 'org.hibernate', 'hibernate-search', '3.4.0.Final')
    ]
  end

  describe "#initalize" do
    it 'raises error when pom cannot be accessed for production profile' do
      site = Awestruct::Site.new( @engine, @config )
      site.profile = 'production'
      expect { Awestruct::Extensions::ReleaseDependencies.new(site, 'org.hibernate', 'hibernate-core', '0.Final') }
      .to raise_error(/Aborting site generation, since the production build requires the release POM information/)
    end
  end

  describe "#get_value" do
    context "pom w/o properties" do
      it "results in no properties" do
        expect(@deps[0].get_value('project.build.sourceEncoding')).to be_nil
      end
    end
    context "pom w/ properties" do
      it "allows to retrieve property value" do
        expect(@deps[1].get_value('project.build.sourceEncoding')).to eql 'UTF-8'
      end
    end
  end

  describe "#get_version" do
    it "retrieve direct version" do
      expect(@deps[0].get_version('junit', 'junit')).to eql '4.8.2'
    end

    it "retrieve variable version" do
      expect(@deps[2].get_version('org.hibernate', 'hibernate-core')).to eql '3.6.3.Final'
    end
  end
end
