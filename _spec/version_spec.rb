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

	describe "legacy version formats" do
		describe "2-component versions" do
			it "parses plain 2-component versions" do
				version = Awestruct::Extensions::Version.new("3.0")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(0)
				expect(version.micro).to eq(0)
				expect(version.suffix).to be_nil
				expect(version.stable?).to be true
			end

			it "parses 2-component versions with lowercase suffix (no separator)" do
				version = Awestruct::Extensions::Version.new("3.0beta1")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(0)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("beta")
				expect(version.suffix.number).to eq(1)
				expect(version.stable?).to be false
			end

			it "parses 2-component versions with letter suffix after number" do
				version = Awestruct::Extensions::Version.new("3.0beta4b")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(0)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("beta")
				expect(version.suffix.number).to eq(4)
				expect(version.stable?).to be false
			end

			it "parses 2-component versions with alpha suffix" do
				version = Awestruct::Extensions::Version.new("3.0alpha")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(0)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("alpha")
				expect(version.suffix.number).to be_nil
				expect(version.stable?).to be false
			end
		end

		describe "hyphenated versions" do
			it "parses hyphenated Beta versions" do
				version = Awestruct::Extensions::Version.new("3.5.0-Beta-2")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(5)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("Beta")
				expect(version.suffix.number).to eq(2)
			end

			it "parses hyphenated CR versions" do
				version = Awestruct::Extensions::Version.new("3.5.0-CR-1")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(5)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("CR")
				expect(version.suffix.number).to eq(1)
			end

			it "parses hyphenated Final versions" do
				version = Awestruct::Extensions::Version.new("3.5.0-Final")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(5)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("Final")
				expect(version.suffix.number).to be_nil
			end

			it "parses mixed dot-hyphen versions" do
				version = Awestruct::Extensions::Version.new("3.5.0.Beta-1")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(5)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("Beta")
				expect(version.suffix.number).to eq(1)
			end
		end

		describe "lowercase legacy versions" do
			it "parses lowercase ga versions" do
				version = Awestruct::Extensions::Version.new("3.2.0.ga")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(2)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("ga")
				expect(version.suffix.number).to be_nil
			end

			it "parses lowercase cr versions" do
				version = Awestruct::Extensions::Version.new("3.2.0.cr1")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(2)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("cr")
				expect(version.suffix.number).to eq(1)
			end

			it "parses lowercase sp versions" do
				version = Awestruct::Extensions::Version.new("3.2.4.sp1")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(2)
				expect(version.micro).to eq(4)
				expect(version.suffix.prefix).to eq("sp")
				expect(version.suffix.number).to eq(1)
			end
		end

		describe "uppercase legacy versions" do
			it "parses uppercase GA versions" do
				version = Awestruct::Extensions::Version.new("3.3.0.GA")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(3)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("GA")
				expect(version.suffix.number).to be_nil
			end

			it "parses uppercase CR versions" do
				version = Awestruct::Extensions::Version.new("3.3.0.CR1")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(3)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("CR")
				expect(version.suffix.number).to eq(1)
			end

			it "parses uppercase SP versions" do
				version = Awestruct::Extensions::Version.new("3.3.0.SP1")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(3)
				expect(version.micro).to eq(0)
				expect(version.suffix.prefix).to eq("SP")
				expect(version.suffix.number).to eq(1)
			end
		end

		describe "plain versions without suffix" do
			it "parses plain version numbers" do
				version = Awestruct::Extensions::Version.new("3.0.1")
				expect(version.major).to eq(3)
				expect(version.minor).to eq(0)
				expect(version.micro).to eq(1)
				expect(version.suffix).to be_nil
			end
		end

		describe "version comparison with legacy formats" do
			it "correctly orders mixed version formats" do
				versions = [
					Awestruct::Extensions::Version.new("3.2.0.cr1"),
					Awestruct::Extensions::Version.new("3.2.0.ga"),
					Awestruct::Extensions::Version.new("3.2.1.ga"),
					Awestruct::Extensions::Version.new("3.5.0-Beta-2"),
					Awestruct::Extensions::Version.new("3.5.0-CR-1"),
					Awestruct::Extensions::Version.new("3.5.0-Final"),
					Awestruct::Extensions::Version.new("3.5.1-Final"),
				]

				# Verify versions are in ascending order
				versions.each_with_index do |version, index|
					break if index == (versions.length - 1)
					expect(version <=> versions[index + 1]).to eq(-1),
						"Expected #{version} < #{versions[index + 1]}"
				end
			end

			it "treats GA as stable release equivalent to Final" do
				ga_version = Awestruct::Extensions::Version.new("3.2.0.ga")
				cr_version = Awestruct::Extensions::Version.new("3.2.0.cr1")
				expect(ga_version > cr_version).to be true
			end

			it "treats plain versions as stable releases" do
				plain_version = Awestruct::Extensions::Version.new("3.0.1")
				expect(plain_version.suffix).to be_nil
			end
		end

		describe "nil suffix comparison" do
			it "treats nil suffix as greater than pre-release suffixes" do
				plain = Awestruct::Extensions::Version.new("3.0.1")
				alpha = Awestruct::Extensions::Version.new("3.0.1.Alpha1")
				beta = Awestruct::Extensions::Version.new("3.0.1.Beta1")
				cr = Awestruct::Extensions::Version.new("3.0.1.CR1")

				expect(plain > alpha).to be true
				expect(plain > beta).to be true
				expect(plain > cr).to be true
			end

			it "compares two nil suffixes as equal" do
				v1 = Awestruct::Extensions::Version.new("3.0.1")
				v2 = Awestruct::Extensions::Version.new("3.0.1")
				expect(v1 <=> v2).to eq(0)
			end

			it "orders versions with mixed nil and non-nil suffixes correctly" do
				versions = [
					Awestruct::Extensions::Version.new("3.0.1.Alpha1"),
					Awestruct::Extensions::Version.new("3.0.1.Beta1"),
					Awestruct::Extensions::Version.new("3.0.1.CR1"),
					Awestruct::Extensions::Version.new("3.0.1"),  # nil suffix (stable)
					Awestruct::Extensions::Version.new("3.0.1.Final"),
					Awestruct::Extensions::Version.new("3.0.2"),  # nil suffix (stable, next micro)
				]

				# Verify they're in ascending order
				versions.each_with_index do |version, index|
					break if index == (versions.length - 1)
					result = version <=> versions[index + 1]
					expect(result).to eq(-1),
						"Expected #{version} < #{versions[index + 1]}, but got #{result}"
				end
			end

			describe "stability determination" do
				it "treats plain versions as stable" do
					expect(Awestruct::Extensions::Version.new("3.0").stable?).to be true
					expect(Awestruct::Extensions::Version.new("3.0.1").stable?).to be true
				end

				it "treats alpha versions as unstable" do
					expect(Awestruct::Extensions::Version.new("3.0alpha").stable?).to be false
					expect(Awestruct::Extensions::Version.new("3.0.1.Alpha1").stable?).to be false
				end

				it "treats beta versions as unstable" do
					expect(Awestruct::Extensions::Version.new("3.0beta1").stable?).to be false
					expect(Awestruct::Extensions::Version.new("3.0.1.Beta1").stable?).to be false
				end

				it "treats CR versions as unstable" do
					expect(Awestruct::Extensions::Version.new("3.0.1.CR1").stable?).to be false
					expect(Awestruct::Extensions::Version.new("3.0.1.cr1").stable?).to be false
				end

				it "treats Final versions as stable" do
					expect(Awestruct::Extensions::Version.new("3.0.1.Final").stable?).to be true
				end

				it "treats GA versions as stable" do
					expect(Awestruct::Extensions::Version.new("3.0.1.GA").stable?).to be true
					expect(Awestruct::Extensions::Version.new("3.0.1.ga").stable?).to be true
				end

				it "treats SP versions as stable" do
					expect(Awestruct::Extensions::Version.new("3.0.1.SP1").stable?).to be true
				end
			end

			describe "case-sensitive suffix ordering" do
				it "orders lowercase before uppercase for same suffix and number" do
					lowercase = Awestruct::Extensions::Version.new("3.2.0.cr1")
					uppercase = Awestruct::Extensions::Version.new("3.2.0.CR1")
					expect(lowercase < uppercase).to be true
				end

				it "orders by number before case" do
					# cr1 < CR1 < cr2 < CR2
					v1 = Awestruct::Extensions::Version.new("3.2.0.cr1")
					v2 = Awestruct::Extensions::Version.new("3.2.0.CR1")
					v3 = Awestruct::Extensions::Version.new("3.2.0.cr2")
					v4 = Awestruct::Extensions::Version.new("3.2.0.CR2")

					expect(v1 < v2).to be true
					expect(v2 < v3).to be true
					expect(v3 < v4).to be true
				end

				it "orders mixed-case versions correctly" do
					versions = [
						Awestruct::Extensions::Version.new("3.2.0.cr1"),
						Awestruct::Extensions::Version.new("3.2.0.CR1"),
						Awestruct::Extensions::Version.new("3.2.0.cr2"),
						Awestruct::Extensions::Version.new("3.2.0.CR2"),
						Awestruct::Extensions::Version.new("3.2.0.ga"),
						Awestruct::Extensions::Version.new("3.2.0.GA"),
					]

					# Verify they're in ascending order
					versions.each_with_index do |version, index|
						break if index == (versions.length - 1)
						result = version <=> versions[index + 1]
						expect(result).to eq(-1),
							"Expected #{version} < #{versions[index + 1]}, but got #{result}"
					end
				end
			end
		end
	end
end
