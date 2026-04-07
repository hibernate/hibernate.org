module Awestruct
  module Extensions
    # Custom version class able to understand and compare the project versions of Hibernate projects
    class Version
      include Comparable

      attr_reader :major, :minor, :micro, :suffix

      def initialize(version="")
        version_str = version.is_a?(Hash) ? (version[:value] || version['value']) : version
        version_str = version_str.to_s

        # Validate that version string has no leading or trailing whitespace
        if version_str != version_str.strip
          raise ArgumentError, "Version string '#{version_str}' must not have leading or trailing whitespace"
        end

        v = version_str.split(".")
        @major = v[0].to_i
        @minor = v[1].to_i
        @micro = v[2].to_i
        @suffix = v[3] == nil ? nil : VersionSuffix.new(v[3])
        # Track how many components were in the original version string
        # This helps distinguish "8" (1 component) from "8.0" (2 components)
        @component_count = v.length
      end

      def <=>(other)
        return @major <=> other.major if ((@major <=> other.major) != 0)
        return @minor <=> other.minor if ((@minor <=> other.minor) != 0)
        return @micro <=> other.micro if ((@micro <=> other.micro) != 0)
        return @suffix <=> other.suffix
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
          # Constraint "7.0.0" (3+ components) matches exactly "7.0.0"
          return false if @major != constraint_version.major
          return true if constraint_version.instance_variable_get(:@component_count) == 1

          return false if @minor != constraint_version.minor
          return true if constraint_version.instance_variable_get(:@component_count) == 2

          return @micro == constraint_version.micro
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
        max_minor_by_major = collect_version_bounds(constraint_versions)

        constraint_versions.each do |constraint_version|
          extract_versions_from_constraint(constraint_version, versions_set, max_minor_by_major, integration_id, integration)
        end

        # Convert to array and sort with latest first
        versions_set.to_a.sort_by { |v| Version.new(v) }.reverse
      end

      private

      # Collect the maximum minor version for each major version from all constraints
      # This helps us know when to transition to the next major version when expanding ranges
      # Returns a hash where keys are major versions and values are either:
      # - An integer (the max minor version seen)
      # - '*' (no explicit bound, expand generously)
      def self.collect_version_bounds(constraint_versions)
        max_minor_by_major = Hash.new('*')

        constraint_versions.each do |constraint_version|
          collect_bounds_from_constraint(constraint_version, max_minor_by_major)
        end

        max_minor_by_major
      end

      def self.collect_bounds_from_constraint(version, max_minor_by_major)
        if version.is_a?(Array)
          version.each do |v|
            collect_bounds_from_constraint(v, max_minor_by_major)
          end
        elsif version.is_a?(Hash) && version.key?(:from)
          # Range bounds
          update_max_minor(version[:from], max_minor_by_major)
          update_max_minor(version[:to], max_minor_by_major) if version[:to]
        elsif version.is_a?(Hash) && version.key?(:value)
          # Single value with comment
          update_max_minor(version[:value], max_minor_by_major)
        else
          # Simple value
          update_max_minor(version, max_minor_by_major)
        end
      end

      def self.update_max_minor(version_str, max_minor_by_major)
        return if version_str.nil?
        v = Version.new(version_str)
        current_max = max_minor_by_major[v.major]
        # If current is '*', keep the numeric value; otherwise take the max
        if current_max == '*'
          max_minor_by_major[v.major] = v.minor
        else
          max_minor_by_major[v.major] = [current_max, v.minor].max
        end
      end

      def self.extract_versions_from_constraint(version, versions_set, max_minor_by_major, integration_id, integration)
        if version.is_a?(Array)
          # Array of versions or ranges
          version.each do |v|
            extract_versions_from_constraint(v, versions_set, max_minor_by_major, integration_id, integration)
          end
        elsif version.is_a?(Hash) && version.key?(:from)
          # Range: expand from X to Y
          expand_range(version[:from], version[:to], versions_set, max_minor_by_major, integration_id, integration)
        elsif version.is_a?(Hash) && version.key?(:value)
          # Single value with comment
          versions_set.add(version[:value].to_s)
        else
          # Simple value
          versions_set.add(version.to_s)
        end
      end

      def self.expand_range(from_str, to_str, versions_set, max_minor_by_major, integration_id, integration)
        from_version = Version.new(from_str)
        to_version = to_str ? Version.new(to_str) : nil

        # Add the from version
        versions_set.add(from_str.to_s)

        # If there's a to version, add it as well
        if to_version
          versions_set.add(to_str.to_s)

          # Check if this range uses single-component versions (e.g., "13", "16" for WildFly)
          # If so, only increment major versions, not minors
          from_component_count = from_version.instance_variable_get(:@component_count)
          to_component_count = to_version.instance_variable_get(:@component_count)
          single_component_range = (from_component_count == 1 && to_component_count == 1)

          if single_component_range
            # Just increment major versions
            current_major = from_version.major + 1
            while current_major < to_version.major
              versions_set.add(current_major.to_s)
              current_major += 1
            end
          else
            # Expand intermediate versions by incrementing through the range
            # Safety limit to prevent infinite loops
            max_iterations = 500
            iterations = 0

            current_major = from_version.major
            current_minor = from_version.minor

            loop do
              iterations += 1
              break if iterations > max_iterations

              # Increment to next minor version
              current_minor += 1

              # Determine the limit for this major version
              limit = get_limit_for_major(current_major, max_minor_by_major)

              if limit.nil?
                # No bound found - skip this major version entirely
                # This handles gaps in version sequences (e.g., Elasticsearch 2.x -> 5.x skipping 3.x, 4.x)
                current_major += 1
                current_minor = 0
                next
              end

              if current_minor > limit
                # Move to the next major version
                current_major += 1
                current_minor = 0
              end

              next_version = Version.new("#{current_major}.#{current_minor}")

              # Stop if we've reached or passed the target version
              break if next_version >= to_version

              versions_set.add("#{current_major}.#{current_minor}")
            end
          end
        end
      end

      # Get the limit (max minor version) for a given major version from collected bounds
      # Returns nil if no bound is defined for this major version
      def self.get_limit_for_major(major_version, max_minor_by_major, _unused_latest_minors = nil)
        bound = max_minor_by_major[major_version]
        return nil if bound == '*'
        bound
      end

      def self.sort
        self.sort!{|a,b| a <=> b}
      end

      def to_s
        @major.to_s + "." + @minor.to_s + "." + @micro.to_s + "." + @suffix.to_s
      end
    end

    class VersionSuffix
      include Comparable

      attr_reader :prefix, :number

      def initialize(bugfix="")
        split = bugfix.scan(/^([A-Za-z\-_]+)([0-9]+)?$/)
        @prefix = split.first[0]
        @number = split.first[1]&.to_i
      end

      def <=>(other)
        return @prefix <=> other.prefix if ((@prefix <=> other.prefix) != 0)
        return @number <=> other.number
      end

      def self.sort
        self.sort!{|a,b| a <=> b}
      end

      def to_s
        @bugfix + @number&.to_s
      end
    end
  end
end
