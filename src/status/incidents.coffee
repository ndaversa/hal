# Description:
#  Track incidents with associated Zendesk articles
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

class Incidents

  @key: "statusbot-incidents-map"

  constructor: (@robot) ->
    return new Incidents @robot unless @ instanceof Incidents
    @robot.brain.once 'loaded', =>
      @incidents = @robot.brain.get(Incidents.key) or {}

  save: ->
    @robot.brain.set Incidents.key, @incidents

  get: (key) ->
    return @incidents unless key
    return @incidents[key]

  activate: (incident, id) ->
    incident.statuspage.incident.id = id
    @save()

  deactivate: (incident) ->
    incident.statuspage.incident.id = null
    @save()

  remove: (incident) ->
    delete @incidents[incident.zendesk.article.id]
    @save()

  create: (incident) ->
    Promise.resolve @incidents[incident.articleId] if incident.articleId
    Zendesk.createArticle(incident.description)
    .then (json) =>
      @incidents[json.article.id] =
        description: incident.description
        statuspage: incident: id: null
        zendesk: article: id: json.article.id
      @save()

      return @incidents[json.article.id]

module.exports = Incidents
