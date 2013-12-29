require_relative '../_ext/release_file_parser'

describe Awestruct::Extensions::ReleaseDependencies do

  before :all do
    @deps = [
      Awestruct::Extensions::ReleaseDependencies.new('org.hibernate', 'hibernate-core', '4.0.0.Beta1'),
      Awestruct::Extensions::ReleaseDependencies.new('org.hibernate', 'hibernate-search-parent', '3.4.0.Final'),
      Awestruct::Extensions::ReleaseDependencies.new('org.hibernate', 'hibernate-search', '3.4.0.Final')
    ]
  end

  describe "#initalize" do
    it 'raises error for invalid project/version' do
      expect { Awestruct::Extensions::ReleaseDependencies.new('org.hibernate', 'hibernate-core', '0.Final') }
      .to raise_error(/Unable to access uri/)
    end
  end

  describe "#get_value" do
    context "pom w/o properties" do
      it "results in no properties" do
        @deps[0].get_value('project.build.sourceEncoding').should be_nil
      end
    end
    context "pom w/ properties" do
      it "allows to retrieve property value" do
        @deps[1].get_value('project.build.sourceEncoding').should eql 'UTF-8'
      end
    end
  end

  describe "#get_version" do
    it "retrieve direct version" do
      @deps[0].get_version('junit', 'junit').should eql '4.8.2'
    end

    it "retrieve variable version" do
      @deps[2].get_version('org.hibernate', 'hibernate-core').should eql '3.6.3.Final'
    end
  end
end
