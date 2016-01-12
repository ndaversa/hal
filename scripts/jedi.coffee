# Description:
#  Quickly open Jedi tickets in JIRA and transition to In Progress
#
# Dependencies:
# - node-fetch
# - underscore.string
#
# Configuration:
#   HUBOT_JIRA_URL (format: "https://jira-domain.com:9090")
#   HUBOT_JIRA_USERNAME
#   HUBOT_JIRA_PASSWORD
#   HUBOT_JIRA_PROJECTS_MAP  \{\"web\":\"WEB\",\"android\":\"AN\",\"ios\":\"IOS\",\"platform\":\"PLAT\"\}
#   HUBOT_GITHUB_TOKEN - Github Application Token
#
# Author:
#   ndaversa
#
fetch = require 'node-fetch'
_ = require 'underscore.string'

module.exports = (robot) ->
  jiraUrl = process.env.HUBOT_JIRA_URL
  jiraUsername = process.env.HUBOT_JIRA_USERNAME
  jiraPassword = process.env.HUBOT_JIRA_PASSWORD
  headers =
      "Content-Type": "application/json"
      "Authorization": 'Basic ' + new Buffer("#{jiraUsername}:#{jiraPassword}").toString('base64')

  token = process.env.HUBOT_GITHUB_TOKEN
  projects = JSON.parse process.env.HUBOT_JIRA_PROJECTS_MAP
  prefixes = (key for team, key of projects).reduce (x,y) -> x + "-|" + y

  parseJSON = (response) ->
    return response.json()

  checkStatus = (response) ->
    if response.status >= 200 and response.status < 300
      return response
    else
      error = new Error(response.statusText)
      error.response = response
      throw error

  report = (project, type, msg) ->
    reporter = null
    ticket = null
    transitions = null

    fetch("#{jiraUrl}/rest/api/2/user/search?username=#{msg.message.user.email_address}", headers: headers)
    .then (res) ->
      checkStatus res
    .then (res) ->
      parseJSON res
    .then (user) ->
      reporter = user[0] if user and user.length is 1
      quoteRegex = /`{1,3}([^]*?)`{1,3}/
      labelsRegex = /#\S+\s?/g
      labels = ["jedi"]
      [__, message] = msg.match

      desc = message.match(quoteRegex)[1] if quoteRegex.test(message)
      message = message.replace(quoteRegex, "") if desc

      if labelsRegex.test(message)
        labels = (message.match(labelsRegex).map((label) -> label.replace('#', '').trim())).concat(labels)
        message = message.replace(labelsRegex, "")

      issue =
        fields:
          project:
            key: project
          summary: message
          labels: labels
          description: """
            #{(if desc then desc + "\n\n" else "")}
            Reported by #{msg.message.user.name} in ##{msg.message.room} on #{robot.adapterName}
            https://#{robot.adapter.client.team.domain}.slack.com/archives/#{msg.message.room}/p#{msg.message.id.replace '.', ''}
          """
          issuetype:
            name: type

      if reporter
        issue.fields.reporter = reporter
        issue.fields.assignee = reporter

      issue
    .then (issue) ->
      fetch "#{jiraUrl}/rest/api/2/issue",
        headers: headers
        method: "POST"
        body: JSON.stringify issue
    .then (res) ->
      checkStatus res
    .then (res) ->
      parseJSON res
    .then (json) ->
      ticket = json
      msg.send "<@#{msg.message.user.id}> Ticket created: #{jiraUrl}/browse/#{ticket.key}"
    .then (json) ->
      fetch "#{jiraUrl}/rest/api/2/issue/#{ticket.key}/transitions?expand=transitions.fields", headers: headers
    .then (res) ->
      checkStatus res
    .then (res) ->
      parseJSON res
    .then (data) ->
      transitions = data.transitions
      backlog = transition for transition in transitions when _(transition.to.name).toLowerCase().contains "backlog"
      if backlog
        msg.send "<@#{msg.message.user.id}> Transitioning issue to `Backlog`"
        fetch "#{jiraUrl}/rest/api/2/issue/#{ticket.key}/transitions",
          headers: headers
          method: "POST"
          body: JSON.stringify
            transition:
              id: backlog.id
    .then (json) ->
      fetch "#{jiraUrl}/rest/api/2/issue/#{ticket.key}/transitions?expand=transitions.fields", headers: headers
    .then (res) ->
      checkStatus res
    .then (res) ->
      parseJSON res
    .then (data) ->
      transitions = data.transitions
      selectedForDev = transition for transition in transitions when _(transition.to.name).toLowerCase().contains "for dev"
      if selectedForDev
        msg.send "<@#{msg.message.user.id}> Transitioning issue to `Selected for Development`"
        fetch "#{jiraUrl}/rest/api/2/issue/#{ticket.key}/transitions",
          headers: headers
          method: "POST"
          body: JSON.stringify
            transition:
              id: selectedForDev.id
    .then (json) ->
      fetch "#{jiraUrl}/rest/api/2/issue/#{ticket.key}/transitions?expand=transitions.fields", headers: headers
    .then (res) ->
      checkStatus res
    .then (res) ->
      parseJSON res
    .then (data) ->
      transitions = data.transitions
      inProgress = transition for transition in transitions when _(transition.to.name).toLowerCase().contains "progress"
      if inProgress
        msg.send "<@#{msg.message.user.id}> Transitioning issue to `In Progress`"
        fetch "#{jiraUrl}/rest/api/2/issue/#{ticket.key}/transitions",
          headers: headers
          method: "POST"
          body: JSON.stringify
            transition:
              id: inProgress.id
    .catch (error) ->
      msg.send "<@#{msg.message.user.id}> An error has occured: #{error}"

  robot.respond /jedi ([^]+)/i, (msg) ->
    [ __, command ] = msg.match
    room = msg.message.room
    project = projects[room]
    type = "Task"

    if not project
      channels = []
      for team, key of projects
        channel = robot.adapter.client.getChannelGroupOrDMByName team
        channels.push " <\##{channel.id}|#{channel.name}>" if channel
      return msg.reply "#{type} must be submitted in one of the following project channels:" + channels

    report project, type, msg
