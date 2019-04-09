_ = require "underscore"
Utils = require "../utils"

class Bot

  constructor: (@robot) ->
    cb.call(@) for cb in @_initializers if @_initializers
    Utils.robot = @robot unless Utils.robot

    for command in @commands
      Utils.robot.logger.debug "Registering Command:", command

      if command.listen
        @robot.listen command.listen.bind(@), command.func.bind(@)
      else
        func = do (command) => =>
          Utils.Stats.increment "command.#{command.name}"
          @[command.name].apply @, arguments

        if command.hear
          @hear command.regex, command.usergroup, func
        else
          @respond command.regex, command.usergroup, func

  commands: []

  normalizeContext: (context) ->
    if _(context).isString()
      normalized = message: room: context
    else if context?.room
      normalized = message: context
    else if context?.message?.room
      normalized = context
    else if context?.id?
      normalized = message: room: context.id
    normalized

  send: (contexts, message) ->
    contexts = [contexts] unless _(contexts).isArray()
    for context in contexts
      payload = text: ""
      context = @normalizeContext context

      if _(message).isString()
        payload.text = message
      else
        payload = _(payload).chain().extend(message).pick("text", "attachments").value()

      payload.text = " " if payload.attachments?.length > 0 and payload.text.length is 0
      if payload.text.length > 0
        @robot.adapter.send 
          room: context.message.room
          message: thread_ts: context.message.thread_ts
        , payload

  dm: (users, message) ->
    users = [ users ] unless _(users).isArray()
    for user in users when user
      @send message: room: user.id, message

  fetch: (url, opts={}) ->
    opts.token = @credentials.token if @credentials?.token?

    if opts.querystring
      delete opts.querystring
      qs = ("#{key}=#{value}" for key, value of opts).join "&"
      @robot.logger.debug "Fetching: #{url}?#{qs}"
      Utils.fetch "#{url}?#{qs}"
    else
      @robot.logger.debug "Fetching: #{url} with #{JSON.stringify opts}"
      Utils.fetch url, opts

  authorize: (context, usergroup=null) ->
    if usergroup
      auth = Utils.authorizeUser(context, usergroup)
    else
      auth = Promise.resolve()

  hear: (regex, usergroup=null, cb) ->
    @robot.hear regex, (context) =>
      @authorize context, usergroup
      .then =>
        cb context
      .catch (error) =>
        @robot.logger.error error
        @robot.logger.error error.stack
        @send context, "<@#{context.message.user.id}>: #{error}"

  respond: (regex, usergroup=null, cb) ->
    @robot.respond regex, (context) =>
      @authorize context, usergroup
      .then =>
        cb context
      .catch (error) =>
        @robot.logger.error error
        @robot.logger.error error.stack
        @send context, "<@#{context.message.user.id}>: #{error}"

  @include = (obj) ->
    excluded = ['extended', 'included', 'initialize']

    for key, value of obj when key not in excluded
      @::[key] = value

    if obj.initialize?
      @::._initializers or= []
      @::._initializers.push obj.initialize
    obj.included?.apply(@)
    this

module.exports = Bot
