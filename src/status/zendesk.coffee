# Description:
#  Interact with Zendesk via the API
#
# Dependencies:
#   - underscore
#
# Configuration:
#   HUBOT_ZENDESK_TOKEN
#   HUBOT_ZENDESK_URL
#   HUBOT_ZENDESK_USERNAME
#
# Commands:
#   None
#
# Author:
#   ndaversa

_ = require "underscore"
Config = require "../config"
Utils = require "../utils"

class Zendesk
  @robot: null

  @fetch: (url, opts={}) ->
    headers =
      "Authorization": 'Basic ' + new Buffer("#{Config.zendesk.username}/token:#{Config.zendesk.token}").toString('base64')
      "Content-Type": "application/json"

    headers = _(headers).extend opts.headers

    Utils.fetch url, _(opts).extend headers: headers

  @makeUrl: (article) ->
    "https://EXAMPLE.COM/hc/en-us/articles/#{article.id}"

  @activateArticle: (article) ->
    Zendesk.fetch "#{Config.zendesk.url}/help_center/articles/#{article.id}/translations/en-us.json",
      method: "PUT"
      body: JSON.stringify translation: draft: no

  @deactivateArticle: (article) ->
    Zendesk.fetch "#{Config.zendesk.url}/help_center/articles/#{article.id}/translations/en-us.json",
      method: "PUT"
      body: JSON.stringify translation: draft: yes

  @removeArticle: (article) ->
    Zendesk.fetch "#{Config.zendesk.url}/help_center/articles/#{article.id}.json",
      method: "DELETE"
    .then (json) ->
      Zendesk.robot.emit "ZendeskArticleDeleted", json
      json

  @createArticle: (description) ->
    Zendesk.fetch "#{Config.zendesk.url}/help_center/sections/#{Config.zendesk.section}/articles.json",
      method: "POST"
      body: JSON.stringify
        article:
          title: description
          draft: yes
          label_names: ["ios", "android", "hal"]
          locale: "en-us"
    .then (json) ->
      Zendesk.robot.emit "ZendeskArticleCreated", json
      json

  @fetchArticles: ->
    Zendesk.fetch("#{Config.zendesk.url}/help_center/sections/#{Config.zendesk.section}/articles.json")

module.exports = Zendesk
