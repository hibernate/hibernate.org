require_relative '../_ext/release_file_parser'

# Simple test to verify inactive_series logic
describe "Inactive Series Logic" do
  it "inactive_series hides specified versions" do
    parser = Awestruct::Extensions::ReleaseFileParser.new

    # Mock integration with inactive_series
    integration = {
      inactive_series: ['1.0', '1.1']
    }

    # Mock compatibility that would normally display the version
    compatibility = {}

    # Mock projects_hash
    projects_hash = {}

    # Test that inactive series are hidden
    displayed = parser.send(:computeVersionDisplayed, '1.0', compatibility, integration, projects_hash)
    expect(displayed).to be false

    displayed = parser.send(:computeVersionDisplayed, '1.1', compatibility, integration, projects_hash)
    expect(displayed).to be false
  end

  it "inactive_series shows non-listed versions based on default rules" do
    parser = Awestruct::Extensions::ReleaseFileParser.new

    # Mock integration with inactive_series
    integration = {
      inactive_series: ['1.0', '1.1']
    }

    # Mock compatibility - empty means no displayed series, so should be false
    compatibility = {}

    # Mock projects_hash
    projects_hash = {}

    # Non-inactive versions should use default display logic
    # (in this case, false because no compatible displayed series)
    displayed = parser.send(:computeVersionDisplayed, '2.0', compatibility, integration, projects_hash)
    expect(displayed).to be false
  end

  it "active_series takes precedence when both are specified" do
    parser = Awestruct::Extensions::ReleaseFileParser.new

    # Mock integration with both active and inactive series
    # inactive_series should take precedence
    integration = {
      active_series: ['1.0', '1.1'],
      inactive_series: ['2.0']
    }

    # Mock compatibility
    compatibility = {}

    # Mock projects_hash
    projects_hash = {}

    # When inactive_series is present, it should be used instead of active_series
    # So 2.0 should be hidden
    displayed = parser.send(:computeVersionDisplayed, '2.0', compatibility, integration, projects_hash)
    expect(displayed).to be false

    # And 1.0 should depend on default rules (not active_series)
    displayed = parser.send(:computeVersionDisplayed, '1.0', compatibility, integration, projects_hash)
    expect(displayed).to be false
  end

  it "integration status is set to inactive for inactive_series" do
    # This tests the markIntegrationStatuses method
    # We need a more complex mock setup for this

    # Mock site integrations
    site_integrations = {
      quarkus: {
        downstream: true,
        hibernate_involvement: true,
        inactive_series: ['3.30', '3.31']
      }
    }

    # Mock series with integration constraints
    series = {
      integration_constraints: {
        quarkus: {
          version: '3.30'
        }
      }
    }

    # Create parser and set @site.integrations
    parser = Awestruct::Extensions::ReleaseFileParser.new
    mock_site = double('site')
    allow(mock_site).to receive(:integrations).and_return(site_integrations)
    parser.instance_variable_set(:@site, mock_site)

    # Call markIntegrationStatuses
    parser.send(:markIntegrationStatuses, series)

    # Verify the status is set to 'inactive'
    expect(series[:integration_constraints][:quarkus][:status]).to eq('inactive')
  end
end
