module Awestruct
  module Extensions
    # Custom version class able to understand and compare the project versions of Hibernate projects
    class Version
      include Comparable

      attr_reader :major, :minor, :micro, :patch, :suffix, :numeric_components

      def initialize(version="")
        version_str = version.is_a?(Hash) ? (version[:value] || version['value']) : version
        version_str = version_str.to_s

        # Validate that version string has no leading or trailing whitespace
        if version_str != version_str.strip
          raise ArgumentError, "Version string '#{version_str}' must not have leading or trailing whitespace"
        end

        # Parse version string, handling multiple formats:
        # - 4-component: 26.0.0.5, 26.0.0.5.Final
        # - 3-component: 1.0.0.Final, 3.5.0-Beta-2
        # - 2-component: 3.0, 3.0beta1, 3.1.ga
        # - 1-component: 8

        # Try 4-component version first: major.minor.micro.patch[separator][suffix]
        match = version_str.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)(?:[\.\-](.+))?$/)
        if match
          @major = match[1].to_i
          @minor = match[2].to_i
          @micro = match[3].to_i
          @patch = match[4].to_i
          @suffix = match[5] ? VersionSuffix.new(match[5]) : nil
          @numeric_components = 4
        else
          # Try 3-component version: major.minor.micro[separator][suffix]
          match = version_str.match(/^(\d+)\.(\d+)\.(\d+)(?:[\.\-]?(.+))?$/)
          if match
            @major = match[1].to_i
            @minor = match[2].to_i
            @micro = match[3].to_i
            @patch = 0
            @suffix = match[4] ? VersionSuffix.new(match[4]) : nil
            @numeric_components = 3
          else
            # Try 2-component version: major.minor[separator][suffix]
            match = version_str.match(/^(\d+)\.(\d+)(?:[\.\-]?(.+))?$/)
            if match
              @major = match[1].to_i
              @minor = match[2].to_i
              @micro = 0
              @patch = 0
              @suffix = match[3] ? VersionSuffix.new(match[3]) : nil
              @numeric_components = 2
            else
              # Fallback to old dot-splitting behavior for 1-component versions (e.g., "8")
              v = version_str.split(".")
              @major = v[0].to_i
              @minor = v[1].to_i
              @micro = v[2].to_i
              @patch = 0
              @suffix = v[3] ? VersionSuffix.new(v[3]) : nil
              @numeric_components = v.length
            end
          end
        end
      end

      def <=>(other)
        return @major <=> other.major if ((@major <=> other.major) != 0)
        return @minor <=> other.minor if ((@minor <=> other.minor) != 0)
        return @micro <=> other.micro if ((@micro <=> other.micro) != 0)
        return @patch <=> other.patch if ((@patch <=> other.patch) != 0)

        # Handle suffix comparison with nil values
        # nil suffix = plain version (e.g., "3.0.1")
        # Ordering: Alpha/Beta/CR < nil (plain) < Final/GA/SP
        return 0 if @suffix.nil? && other.suffix.nil?

        # If one has nil suffix and other doesn't, compare based on stability
        if @suffix.nil?
          # nil < stable suffixes (Final, GA, SP), nil > pre-release suffixes (Alpha, Beta, CR)
          return other.suffix.stable? ? -1 : 1
        elsif other.suffix.nil?
          # stable suffixes > nil, pre-release suffixes < nil
          return @suffix.stable? ? 1 : -1
        end

        return @suffix <=> other.suffix
      end

      # Determine if this version represents a stable release
      # Versions with no suffix (e.g., 3.0, 3.0.1) or stable suffixes (Final, GA, SP) are stable
      # Versions with unstable suffixes (Alpha, Beta, CR) are unstable
      def stable?
        return true if @suffix.nil?
        @suffix.stable?
      end

      def matches?(constraint)
        if constraint.is_a?(Array)
          constraint.each do |c|
            if self.matches?(c)
              return true
            end
          end
        elsif constraint.is_a?(Hash) && constraint.key?(:from)
          from_version = Version.new(constraint[:from])
          to_version = constraint[:to] ? Version.new(constraint[:to]) : nil
          return self >= from_version && (to_version.nil? || self <= to_version)
        else
          constraint_version = Version.new(constraint)
          # Constraint "7" (1 component) matches "7.0", "7.1", "7.2", etc.
          # Constraint "7.0" (2 components) matches "7.0.0", "7.0.1", etc., but NOT "7.1"
          # Constraint "7.0.0" (3 components) matches "7.0.0", "7.0.0.Final", "7.0.0.5", etc.
          # Constraint "26.0.0.5" (4 components) matches exactly "26.0.0.5"
          return false if @major != constraint_version.major
          return true if constraint_version.numeric_components == 1

          return false if @minor != constraint_version.minor
          return true if constraint_version.numeric_components == 2

          return false if @micro != constraint_version.micro
          return true if constraint_version.numeric_components == 3

          return @patch == constraint_version.patch
        end
        false
      end

      # Expand all integration versions from a list of constraint values
      # Returns an array of version strings, sorted with latest first
      #
      # @param constraint_versions [Array] Array of constraint version values (can be strings, hashes, arrays, ranges)
      # @param integration_id [String] Integration ID (for error messages)
      # @param integration [Hash] Integration data (may contain :latest_minors)
      # @return [Array<String>] Sorted array of version strings with latest first
      def self.expand_from_constraints(constraint_versions, integration_id = nil, integration = nil)
        versions_set = Set.new

        # First pass: collect all explicitly mentioned versions to determine bounds
        bounds = collect_version_bounds(constraint_versions)

        constraint_versions.each do |constraint_version|
          extract_versions_from_constraint(constraint_version, versions_set, bounds, integration_id, integration)
        end

        # Convert to array and sort with latest first
        versions_set.to_a.sort_by { |v| Version.new(v) }.reverse
      end

      private

      # Collect bounds from all constraints for range expansion.
      # Returns a hash with :max_minor (max minor version per major)
      # and :max_patch (max patch version per major, for 4-component versions).
      def self.collect_version_bounds(constraint_versions)
        bounds = {
          max_minor: Hash.new('*'),
          max_patch: Hash.new('*')
        }

        constraint_versions.each do |constraint_version|
          collect_bounds_from_constraint(constraint_version, bounds)
        end

        bounds
      end

      def self.collect_bounds_from_constraint(version, bounds)
        if version.is_a?(Array)
          version.each do |v|
            collect_bounds_from_constraint(v, bounds)
          end
        elsif version.is_a?(Hash) && version.key?(:from)
          # Range bounds
          update_bounds(version[:from], bounds)
          update_bounds(version[:to], bounds) if version[:to]
        elsif version.is_a?(Hash) && version.key?(:value)
          # Single value with comment
          update_bounds(version[:value], bounds)
        else
          # Simple value
          update_bounds(version, bounds)
        end
      end

      def self.update_bounds(version_str, bounds)
        return if version_str.nil?
        v = Version.new(version_str)

        current_minor = bounds[:max_minor][v.major]
        if current_minor == '*'
          bounds[:max_minor][v.major] = v.minor
        else
          bounds[:max_minor][v.major] = [current_minor, v.minor].max
        end

        if v.numeric_components >= 4
          current_patch = bounds[:max_patch][v.major]
          if current_patch == '*'
            bounds[:max_patch][v.major] = v.patch
          else
            bounds[:max_patch][v.major] = [current_patch, v.patch].max
          end
        end
      end

      def self.extract_versions_from_constraint(version, versions_set, bounds, integration_id, integration)
        if version.is_a?(Array)
          # Array of versions or ranges
          version.each do |v|
            extract_versions_from_constraint(v, versions_set, bounds, integration_id, integration)
          end
        elsif version.is_a?(Hash) && version.key?(:from)
          # Range: expand from X to Y
          expand_range(version[:from], version[:to], versions_set, bounds, integration_id, integration)
        elsif version.is_a?(Hash) && version.key?(:value)
          # Single value with comment
          versions_set.add(version[:value].to_s)
        else
          # Simple value
          versions_set.add(version.to_s)
        end
      end

      def self.expand_range(from_str, to_str, versions_set, bounds, integration_id, integration)
        from_version = Version.new(from_str)
        to_version = to_str ? Version.new(to_str) : nil

        # Add the from version
        versions_set.add(from_str.to_s)

        # If there's a to version, add it as well and expand intermediates
        if to_version
          versions_set.add(to_str.to_s)

          if from_version.numeric_components == 1 && to_version.numeric_components == 1
            # Single-component range (e.g., WildFly "13" to "16"): increment major only
            current_major = from_version.major + 1
            while current_major < to_version.major
              versions_set.add(current_major.to_s)
              current_major += 1
            end
          elsif from_version.numeric_components == 4 && to_version.numeric_components == 4
            # 4-component range (e.g., Liberty "18.0.0.2" to "26.0.0.5"):
            # increment patch within each major
            expand_4_component_range(from_version, to_version, versions_set, bounds)
          else
            # Multi-component range: increment minor within each major
            expand_minor_range(from_version, to_version, versions_set, bounds)
          end
        end
      end

      def self.expand_4_component_range(from_version, to_version, versions_set, bounds)
        max_iterations = 500
        iterations = 0

        current_major = from_version.major
        current_patch = from_version.patch
        fixed_minor = from_version.minor
        fixed_micro = from_version.micro

        loop do
          iterations += 1
          break if iterations > max_iterations

          current_patch += 1

          limit = bounds[:max_patch][current_major]
          if limit == '*'
            current_major += 1
            current_patch = 0
            next
          end

          if current_patch > limit
            current_major += 1
            current_patch = 0
            next
          end

          version_str = "#{current_major}.#{fixed_minor}.#{fixed_micro}.#{current_patch}"
          next_version = Version.new(version_str)

          break if next_version >= to_version

          versions_set.add(version_str)
        end
      end

      def self.expand_minor_range(from_version, to_version, versions_set, bounds)
        max_iterations = 500
        iterations = 0

        current_major = from_version.major
        current_minor = from_version.minor

        loop do
          iterations += 1
          break if iterations > max_iterations

          current_minor += 1

          limit = bounds[:max_minor][current_major]
          if limit == '*'
            current_major += 1
            current_minor = 0
            next
          end

          if current_minor > limit
            current_major += 1
            current_minor = 0
          end

          next_version = Version.new("#{current_major}.#{current_minor}")
          break if next_version >= to_version

          versions_set.add("#{current_major}.#{current_minor}")
        end
      end

      def self.sort
        self.sort!{|a,b| a <=> b}
      end

      def to_s
        result = "#{@major}.#{@minor}.#{@micro}"
        result += ".#{@patch}" if @numeric_components >= 4
        result += ".#{@suffix}" if @suffix
        result
      end
    end

    class VersionSuffix
      include Comparable

      attr_reader :prefix, :number

      def initialize(suffix_str="")
        # Handle multiple formats:
        # - "Final" -> prefix: "Final", number: nil
        # - "Alpha1" -> prefix: "Alpha", number: 1
        # - "Beta-2" -> prefix: "Beta", number: 2
        # - "CR-1" -> prefix: "CR", number: 1
        # - "ga" -> prefix: "ga", number: nil
        # - "sp1" -> prefix: "sp", number: 1
        # - "beta4b" -> prefix: "beta", number: 4 (letter suffix ignored)

        # Match: prefix, optional hyphen, optional number, optional letter suffix
        match = suffix_str.match(/^([A-Za-z]+)\-?([0-9]+)?[a-z]?$/)
        if match
          @prefix = match[1]
          @number = match[2]&.to_i
        else
          # Fallback for edge cases
          @prefix = suffix_str
          @number = nil
        end
      end

      def <=>(other)
        # Case-insensitive comparison of prefix (so "cr" == "CR")
        prefix_cmp = @prefix.downcase <=> other.prefix.downcase
        return prefix_cmp if prefix_cmp != 0

        # Compare numbers second (so cr1 < cr2, CR1 < CR2)
        number_cmp = @number <=> other.number
        return number_cmp if number_cmp != 0

        # If prefixes and numbers are equal, compare case as final tiebreaker
        # This ensures lowercase comes before uppercase (cr1 < CR1)
        # Note: In ASCII, uppercase < lowercase, so we reverse the comparison
        return other.prefix <=> @prefix
      end

      def self.sort
        self.sort!{|a,b| a <=> b}
      end

      # Determine if this suffix represents a stable release
      # Stable: Final, GA, SP (service packs)
      # Unstable: Alpha, Beta, CR (candidate release)
      def stable?
        prefix_lower = @prefix.downcase
        case prefix_lower
        when 'final', 'ga', 'sp'
          true
        when 'alpha', 'beta', 'cr'
          false
        else
          # Unknown suffix - conservative default is unstable
          false
        end
      end

      def to_s
        @number ? "#{@prefix}#{@number}" : @prefix
      end
    end
  end
end
