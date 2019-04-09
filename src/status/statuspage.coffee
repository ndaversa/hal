# Description:
#  Interact with StatusPage via the API
#
# Dependencies:
#   - underscore
#
# Configuration:
#   HUBOT_STATUSPAGE_ID
#   HUBOT_STATUSPAGE_API_KEY
#
# Commands:
#   None
#
# Author:
#   ndaversa

_ = require "underscore"
Config = require "../config"
Utils = require "../utils"

class StatusPage

  @fetch: (url, opts={}) ->
    headers = "Authorization": "OAuth #{Config.statuspage.token}"
    headers = _(headers).extend opts.headers

    Utils.fetch url, _(opts).extend headers: headers

  @resolveIncident: (incident) ->
    StatusPage.fetch "#{Config.statuspage.url}/pages/#{Config.statuspage.id}/incidents/#{incident.statuspage.incident.id}.json",
      method: "PUT"
      body: JSON.stringify incident: status: "resolved"

  @createIncident: (incident) ->
    StatusPage.fetch "#{Config.statuspage.url}/pages/#{Config.statuspage.id}/incidents.json",
      method: "POST"
      body: JSON.stringify incident: incident

  @fetchIncidents: ->
    StatusPage.fetch("#{Config.statuspage.url}/pages/#{Config.statuspage.id}/incidents.json")

  @fetchComponents: ->
    StatusPage.fetch("#{Config.statuspage.url}/pages/#{Config.statuspage.id}/components.json")

module.exports = StatusPage

