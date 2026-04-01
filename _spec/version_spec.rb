require_relative '../_ext/version'
require 'set'

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
        	expect(@versions[8].major).to eql 5
    	end
	end

	describe "#feature_group" do
    	it "feature_group number is correct" do
        	expect(@versions[8].minor).to eql 1
    	end
	end

	describe "#feature" do
    	it "feature number is correct" do
        	expect(@versions[8].micro).to eql 2
    	end
	end

	describe "#bugfix" do
    	it "bugfix number is correct" do
        	expect(@versions[8].suffix).to eql "Beta4"
    	end
	end

    describe "#<=>" do
		it "version array is in correct order" do
			@versions.each_with_index do |version, index|
				break if index == (@versions.length - 2)
				expect((version <=> @versions[index + 1] )).to eq -1
			end
		end
	end

	describe ".expand_from_constraints" do
		it "expands simple versions" do
			constraint_versions = ['3.20', '3.27']
			versions = Awestruct::Extensions::Version.expand_from_constraints(constraint_versions)
			expect(versions).to eq(['3.27', '3.20'])
		end

		it "expands version ranges" do
			constraint_versions = [{ :from => '3.14', :to => '3.23' }]
			versions = Awestruct::Extensions::Version.expand_from_constraints(constraint_versions)
			# Should include at minimum the from and to versions
			expect(versions).to include('3.14', '3.23')
			# Should be sorted with latest first
			expect(versions.first).to eq('3.23')
			expect(versions.last).to eq('3.14')
		end

		it "handles arrays of versions" do
			constraint_versions = [[11, 17, 21]]
			versions = Awestruct::Extensions::Version.expand_from_constraints(constraint_versions)
			expect(versions).to eq(['21', '17', '11'])
		end

		it "handles hash values with comments" do
			constraint_versions = [[
				21,
				{ :value => 25, :comment => '6.6.40+' }
			]]
			versions = Awestruct::Extensions::Version.expand_from_constraints(constraint_versions)
			expect(versions).to eq(['25', '21'])
		end

		it "returns empty array when no constraints provided" do
			constraint_versions = []
			versions = Awestruct::Extensions::Version.expand_from_constraints(constraint_versions)
			expect(versions).to eq([])
		end

		it "handles multiple constraints from different projects" do
			constraint_versions = [
				'3.20',
				{ :from => '3.14', :to => '3.23' },
				[11, 17, 21]
			]
			versions = Awestruct::Extensions::Version.expand_from_constraints(constraint_versions)
			# Should deduplicate and sort
			expect(versions).to include('3.20', '3.14', '3.23', '21', '17', '11')
		end
	end
end
