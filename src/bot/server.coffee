auth = require "basic-auth"
Utils = require "../utils"

module.exports =
  initialize: ->
    if @endpoints
      for endpoint in @endpoints
        if endpoint.type is "get"
          @get endpoint.path, endpoint.func.bind @
        else if endpoint.type is "post"
          @post endpoint.path, endpoint.func.bind @

  get: (path, cb) ->
    @robot.router.get path, (req, res) =>
      Utils.Stats.increment "server.get.#{path}"
      cb(req, res) if @isAuthorized req, res

  post: (path, cb) ->
    @robot.router.post path, (req, res) =>
      Utils.Stats.increment "server.post.#{path}"
      cb(req, res) if @isAuthorized req, res

  isAuthorized: (req, res) ->
    user = auth req
    unless user and user.name is credentials.name and user.pass is credentials.pass
      res.setHeader "WWW-Authenticate", 'Basic realm="Hubot"'
      res.status(403).send "Not authorized"
      return no
    return yes
