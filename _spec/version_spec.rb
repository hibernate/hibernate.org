require_relative '../_ext/release_file_parser'
 
describe Awestruct::Extensions::Version do

    before :all do
        @versions = [
            Awestruct::Extensions::Version.new("1.0.0.Alpha1"),
            Awestruct::Extensions::Version.new("1.0.0.Alpha2"),
            Awestruct::Extensions::Version.new("1.0.0.Beta1"),
            Awestruct::Extensions::Version.new("1.0.0.CR1"),
            Awestruct::Extensions::Version.new("1.0.0.Final"),
            Awestruct::Extensions::Version.new("1.0.1.Final"),
            Awestruct::Extensions::Version.new("1.1.0.Alpha1"),
            Awestruct::Extensions::Version.new("2.0.0.Alpha1"),
            Awestruct::Extensions::Version.new("5.1.2.Beta4"),            
        ]
    end

    describe "#major" do
    	it "major number is correct" do
        	@versions[8].major.should eql 5
    	end
	end

	describe "#feature_group" do
    	it "feature_group number is correct" do
        	@versions[8].feature_group.should eql 1
    	end
	end

	describe "#feature" do
    	it "feature number is correct" do
        	@versions[8].feature.should eql 2
    	end
	end

	describe "#bugfix" do
    	it "bugfix number is correct" do
        	@versions[8].bugfix.should eql "Beta4"
    	end
	end

    describe "#<=>" do
		it "version array is in correct order" do
			@versions.each_with_index do |version, index|
				break if index == (@versions.length - 2)
				(version <=> @versions[index + 1] ).should == -1
			end
		end
	end 
end