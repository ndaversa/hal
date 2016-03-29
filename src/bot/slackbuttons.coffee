_ = require "underscore"
Utils = require "../utils"

module.exports =
  initialize: ->
    @robot.on "SlackEvents", (payload, res) => #requires JiraBot @ 6.8.3 or greater
      if not payload.handled and @shouldBotHandle(payload) and @isValid(payload)
        @onButtonActions(payload).then ->
          res.json payload.original_message
        .catch (error) ->
          @robot.logger.error error

  buttonsAttachment: (id, query) ->
    if _(query).isArray()
      actions = (_(button).omit "func" for button in query)
    else
      actions = (_(button).omit "func" for button in _(@slackButtons).where(query))

    fallback: "Unable to display quick action buttons"
    attachment_type: "default"
    callback_id: "#{@.constructor.name}_#{id}"
    color: "#EDB431"
    actions: actions

  isValid: (payload) -> yes

  onButtonActions: (payload) ->
    Promise.all payload.actions.map (action) =>
      Utils.Stats.increment "slack.button.#{@.constructor.name}.#{action.name}.#{action.value}"
      if button = _(@slackButtons).findWhere(name: action.name)
        button.func.call @, payload, action

  shouldBotHandle: (payload) ->
    if payload.callback_id.indexOf("#{@.constructor.name}_") is 0
      payload.callback_id = payload.callback_id.split("#{@.constructor.name}_")[1]
      payload.handled = yes
      return yes
    return no
