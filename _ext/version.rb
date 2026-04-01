module Awestruct
  module Extensions
    # Custom version class able to understand and compare the project versions of Hibernate projects
    class Version
      include Comparable

      attr_reader :major, :minor, :micro, :suffix

      def initialize(version="")
        version_str = version.is_a?(Hash) ? (version[:value] || version['value']) : version
        v = version_str.to_s.split(".")
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
      # @return [Array<String>] Sorted array of version strings with latest first
      def self.expand_from_constraints(constraint_versions)
        versions_set = Set.new

        constraint_versions.each do |constraint_version|
          extract_versions_from_constraint(constraint_version, versions_set)
        end

        # Convert to array and sort with latest first
        versions_set.to_a.sort_by { |v| Version.new(v) }.reverse
      end

      private

      def self.extract_versions_from_constraint(version, versions_set)
        if version.is_a?(Array)
          # Array of versions or ranges
          version.each do |v|
            extract_versions_from_constraint(v, versions_set)
          end
        elsif version.is_a?(Hash) && version.key?(:from)
          # Range: expand from X to Y
          expand_range(version[:from], version[:to], versions_set)
        elsif version.is_a?(Hash) && version.key?(:value)
          # Single value with comment
          versions_set.add(version[:value].to_s)
        else
          # Simple value
          versions_set.add(version.to_s)
        end
      end

      def self.expand_range(from_str, to_str, versions_set)
        from_version = Version.new(from_str)
        to_version = to_str ? Version.new(to_str) : nil

        # Add the from version
        versions_set.add(from_str.to_s)

        # If there's a to version, add it as well
        if to_version
          versions_set.add(to_str.to_s)

          # Only try to expand intermediate versions if they're in the same major version
          # This is a heuristic - we can only reliably expand within the same major version
          if from_version.major == to_version.major
            current = from_version
            # Safety limit to prevent infinite loops
            max_iterations = 100
            iterations = 0

            loop do
              iterations += 1
              break if iterations > max_iterations

              next_minor = Version.new("#{current.major}.#{current.minor + 1}.0")
              break if next_minor > to_version
              versions_set.add("#{next_minor.major}.#{next_minor.minor}")
              current = next_minor
            end
          end
        end
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
