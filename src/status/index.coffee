# Description:
#  Manage Site Status with StatusPage and Zendesk
#
# Dependencies:
#   - underscore
#   - columnify
#
# Configuration:
#   HUBOT_STATUSBOT_CHANNEL
#   HUBOT_STATUSBOT_USERGROUP
#   HUBOT_ZENDESK_CHANNEL
#   EXPRESS_URL
#   EXPRESS_USERNAME
#   EXPRESS_PASSWORD
#
# Commands:
#   hubot status - Get a overview on StatusPage Components and Incidents
#   hubot incident list - Get an overview of incidents currently active
#   hubot incident active - Get a list of active incidents
#   hubot incident create <description> - Create a new incident. This will create a draft Zendesk article with the <description>. This command WILL NOT ACTIVATE the incident.
# Author:
#   ndaversa

_ = require "underscore"
columnify = require "columnify"

Bot = require "../bot"
Server = require "../bot/server"
Config = require "../config"
Components = require "../status/components"
Incidents = require "../status/incidents"
StatusPage = require "../status/statuspage"
Utils = require "../utils"
Zendesk = require "../status/zendesk"

class StatusBot extends Bot
  @include Server

  constructor: (@robot) ->
    @commands = [
      regex: /status$/i
      usergroup: Config.status.usergroup
      name: "statusCommand"
    ,
      regex: /incident( list)?$/i
      usergroup: Config.status.usergroup
      name: "listIncidentsCommand"
    ,
      regex: /incident active$/i
      usergroup: Config.status.usergroup
      name: "listActiveIncidentsCommand"
    ,
      regex: /incident create ([^]+)/i
      usergroup: Config.status.usergroup
      name: "createIncidentCommand"
    ]

    @endpoints = [
      path: "/hubot/status/activate/:id"
      type: "get"
      func: @getActivate
    ,
      path: "/hubot/status/deactivate/:id"
      type: "get"
      func: @getDeactivate
    ,
      path: "/hubot/status/remove/:id"
      type: "get"
      func: @getRemove
    ]

    Zendesk.robot = @robot
    @incidents = new Incidents @robot
    @components = new Components @robot
    @registerEventListeners()
    @robot.brain.once 'loaded', =>
      setInterval @refreshComponents.bind(@), 60*1000 # Every 1 minute
      @refreshComponents()
    super

  processNextComponent: (components) ->
    c = components.shift()
    return unless c
    @components.create(c)
    .then (component) =>
      if c.status is "operational"
        @components.operational component
      else
        @components.degraded component, c.status
      @processNextComponent components

  renderComponents: (components, msg) ->
    data = []
    for id, component of components
      data.push
        article: "<#{Zendesk.makeUrl component.zendesk.article}|:zendesk:>"
        status: "<#{Config.statuspage.homepage}|:#{component.status}:>"
        description: component.description
    columnify data,
      truncate: yes
      columnSplitter: "     "
      align: "left"
      showHeaders: no
      config: description: maxWidth: 60

  renderIncidents: (incidents, msg) ->
    data = []
    for id, incident of incidents
      status = if incident.statuspage.incident.id then "deactivate" else "activate"
      data.push
        remove: "<#{Config.server.url}/hubot/status/remove/#{id}?channel=#{msg.message.room}|:x:>"
        article: "<#{Zendesk.makeUrl incident.zendesk.article}|:zendesk:>"
        toggle: "<#{Config.server.url}/hubot/status/#{status}/#{id}?channel=#{msg.message.room}|:#{status}:>"
        description: incident.description
    columnify data,
      truncate: yes
      columnSplitter: "     "
      align: "left"
      showHeaders: no
      config: description: maxWidth: 60

  listIncidents: (msg, onlyActive=no) ->
    incidents = {}
    for id, incident of @incidents.get()
      if onlyActive and incident.statuspage.incident.id
        incidents[id] = incident
      else if not onlyActive
        incidents[id] = incident
    _.defer =>
      @send msg, """
        ```Incidents```
        #{@renderIncidents incidents, msg}#{if _(incidents).isEmpty() then "There are no#{if onlyActive then " active" else ""} incidents" else ""}
      """

  listComponents: (msg) ->
    components = @components.get()
    _.defer =>
      @send msg, """
        ```Components```
        #{@renderComponents components, msg}#{if _(components).isEmpty() then "There are no components" else ""}
      """

  activate: (incident, msg) ->
    @robot.logger.info "Activating incident", incident
    StatusPage.createIncident
      name: incident.description
      status: "investigating"
    .then (json) =>
      @send msg, "StatusPage <#{json.shortlink}|incident> *created*"
      @incidents.activate incident, json.id
      Zendesk.activateArticle incident.zendesk.article
    .then (json) =>
      @send msg, "Zendesk <#{Zendesk.makeUrl incident.zendesk.article}|article> *added* to known issues list"
      @listIncidents msg
    .catch (error) =>
      @send msg, "Something went wrong: #{error}"

  deactivate: (incident, msg) ->
    @robot.logger.info "Deactivating incident", incident
    StatusPage.resolveIncident(incident)
    .then (json) =>
      @send msg, "StatusPage <#{json.shortlink}|incident> resolved"
      @incidents.deactivate incident, json.id
      Zendesk.deactivateArticle incident.zendesk.article
    .then (json) =>
      @send msg, "Zendesk <#{Zendesk.makeUrl incident.zendesk.article}|article> *removed* from known issues list"
      @listIncidents msg
    .catch (error) =>
      @send msg, "Something went wrong: #{error}"

  remove: (incident, msg) ->
    @robot.logger.info "Removing incident", incident
    Zendesk.removeArticle(incident.zendesk.article)
    .then =>
      @send msg, "Zendesk <#{Zendesk.makeUrl incident.zendesk.article}|article> *removed*"
      if incident.statuspage.incident.id
        StatusPage.resolveIncident(incident)
        .then =>
          @send msg, "StatusPage <#{json.shortlink}|incident> resolved"
    .then =>
      @incidents.remove incident
      @send msg, "Incident `#{incident.description}` *removed*"
      @listIncidents msg
    .catch (error) =>
      @send msg, "Something went wrong: #{error}"

  refreshComponents: ->
    StatusPage.fetchComponents()
    .then (components) =>
      @processNextComponent components
    .catch (error) =>
      @robot.logger.error error

  getActivate: (req, res) ->
    incident = @incidents.get req.params.id
    channel = req.query.channel
    if incident and channel
      msg =  message: room: channel
      @activate incident, msg
      message = "Activating `#{incident.description}`"
      @send msg, message
      Promise.resolve message
    else
      Promise.reject "Invalid channel or incident"

  getDeactivate: (req, res) ->
    incident = @incidents.get req.params.id
    channel = req.query.channel
    if incident and channel
      msg =  message: room: channel
      @deactivate incident, msg
      message = "Deactivating `#{incident.description}`"
      @send msg, message
      Promise.resolve message
    else
      Promise.reject "Invalid channel or incident"

  getRemove: (req, res) ->
    incident = @incidents.get req.params.id
    channel = req.query.channel
    if incident and channel
      msg =  message: room: channel
      @remove incident, msg
      message = "Removing `#{incident.description}`"
      @send msg, message
      Promise.resolve message
    else
      Promise.reject "Invalid channel or incident"

  registerEventListeners: ->
    @robot.on "ComponentDegraded", (component) =>
      Zendesk.activateArticle(component.zendesk.article)
      .then =>
        @send [Config.status.channel, Config.zendesk.channel], """
          `#{component.description}` is :major_outage:
          :zendesk: <#{Zendesk.makeUrl component.zendesk.article}|article> *added* to known issues list
        """

    @robot.on "ComponentOperational", (component) =>
      Zendesk.deactivateArticle(component.zendesk.article)
      .then =>
        @send [Config.status.channel, Config.zendesk.channel], """
          `#{component.description}` is now :operational:
          :zendesk: <#{Zendesk.makeUrl component.zendesk.article}|article> *removed* from known issues list
        """

    @robot.on "ZendeskArticleCreated", (json) =>
      @send Config.zendesk.channel, """
        A new :zendesk: article <#{Zendesk.makeUrl json.article}|#{json.article.title}> has been *created* in response to a new incident
      """

    @robot.on "ZendeskArticleDeleted", (json) =>
      @send Config.zendesk.channel, """
        :zendesk: article <#{Zendesk.makeUrl json.article}|#{json.article.title}> has been *deleted* since the corresponding incident was removed
      """

  statusCommand: (context) ->
    context.finish()
    @refreshComponents()
    .then =>
      @listComponents context
      @listIncidents context
      @send context, "You can activate an known incident type from above or create a new incident with: `#{@robot.name} incident create description goes here`"

  listIncidentsCommand: (context) ->
    context.finish()
    @listIncidents context
    @send context, "You can activate an known incident type from above or create a new incident with: `#{@robot.name} incident create description goes here`"

  listActiveIncidentsCommand: (context) ->
    context.finish()
    @listIncidents context, yes
    @send context, "To create a new incident: `#{@robot.name} incident create description goes here`"

  createIncidentCommand: (context) ->
    [ __, description ] = context.match
    @incidents.create(description: description)
    .then (incident) =>
      @send context, ":zendesk: <#{Zendesk.makeUrl incident.zendesk.article}|article> *created*"
      @listIncidents context

module.exports = StatusBot
