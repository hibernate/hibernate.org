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
        	suffix = @versions[8].suffix
        	expect(suffix.prefix).to eql "Beta"
        	expect(suffix.number).to eql 4
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

	describe "#initialize" do
		it "rejects version with leading whitespace" do
			expect { Awestruct::Extensions::Version.new(" 1.0.0.Final") }.to raise_error(ArgumentError, /must not have leading or trailing whitespace/)
		end

		it "rejects version with trailing whitespace" do
			expect { Awestruct::Extensions::Version.new("1.0.0.Final ") }.to raise_error(ArgumentError, /must not have leading or trailing whitespace/)
		end

		it "rejects version with both leading and trailing whitespace" do
			expect { Awestruct::Extensions::Version.new(" 1.0.0.Final ") }.to raise_error(ArgumentError, /must not have leading or trailing whitespace/)
		end

		it "accepts version without extra whitespace" do
			expect { Awestruct::Extensions::Version.new("1.0.0.Final") }.not_to raise_error
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

		it "expands ranges across major versions" do
			# Include explicit versions to provide bounds for each major version
			constraint_versions = [
				{ :from => '5.6', :to => '7.16' },
				'5.50',  # Establishes max minor for major 5
				'6.50',  # Establishes max minor for major 6
				'7.50'   # Establishes max minor for major 7
			]
			versions = Awestruct::Extensions::Version.expand_from_constraints(constraint_versions, 'test_integration', nil)
			# Should include endpoints
			expect(versions).to include('5.6', '7.16')
			# Should include intermediate minor versions in starting major
			expect(versions).to include('5.7', '5.8', '5.9', '5.10')
			# Should include versions in intermediate major
			expect(versions).to include('6.0', '6.1', '6.2')
			# Should include versions in ending major
			expect(versions).to include('7.0', '7.1', '7.10', '7.15')
			# Should be sorted with latest first
			expect(versions.first).to eq('7.50')
			expect(versions.last).to eq('5.6')
		end

		it "expands single-component version ranges" do
			# WildFly-style single-component versions (just major, no minor)
			constraint_versions = [{ :from => '13', :to => '16' }]
			versions = Awestruct::Extensions::Version.expand_from_constraints(constraint_versions, 'test_integration', nil)
			# Should include all major versions in range
			expect(versions).to eq(['16', '15', '14', '13'])
		end
	end
end
