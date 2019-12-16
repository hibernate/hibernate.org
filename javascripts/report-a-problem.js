  jQuery.ajax({
    url: "https://hibernate.atlassian.net/s/d41d8cd98f00b204e9800998ecf8427e/en_US-ny35gm-1988229788/6206/19/1.4.1/_/download/batch/com.atlassian.jira.collector.plugin.jira-issue-collector-plugin:issuecollector-embededjs/com.atlassian.jira.collector.plugin.jira-issue-collector-plugin:issuecollector-embededjs.js?collectorId=7d71341e",
    type: "get",
    cache: true,
    dataType: "script"
  });
  window.ATL_JQ_PAGE_PROPS = {
    "triggerFunction": function(showCollectorDialog) {
      jQuery("#feedback-button").click(function(e) {
        e.preventDefault();
        showCollectorDialog();
      });
    },
    fieldValues: {
        components : '10380',
        summary: 'Broken link: ' + window.location.href,
        description: 'Broken link: ' + window.location.href + '\n\n' +
        		'Please provide your page of origin:\n' + document.referrer + '\n\n' +
        		'Please describe what you expected this link to point to:\n\n'
    }
  };

