# Description:
#  Track StatusPage components with associated Zendesk articles
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   None
#
# Author:
#   ndaversa

Zendesk = require "./zendesk"

class Components

  @key: "statusbot-components-map"

  constructor: (@robot) ->
    return new Components @robot unless @ instanceof Components
    @robot.brain.once 'loaded', =>
      @components = @robot.brain.get(Components.key) or {}
      @robot.logger.debug JSON.stringify @components

  save: ->
    @robot.brain.set Components.key, @components

  get: (component) ->
    @components

  degraded: (component, status="major_outage") ->
    if component.status isnt status
      component.status = status
      @save()
      @robot.emit "ComponentDegraded", component

  operational: (component) ->
    if component.status isnt "operational"
      component.status = "operational"
      @save()
      @robot.emit "ComponentOperational", component

  create: (component) ->
    return Promise.resolve @components[component.id] if @components[component.id]

    Zendesk.createArticle(component.name)
    .then (json) =>
      @components[component.id] =
        description: component.name
        status: component.status
        zendesk: article: id: json.article.id
      @save()

      return @components[component.id]

module.exports = Components
