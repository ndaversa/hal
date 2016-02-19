# Description:
#  Manage the Jedi schedule and update team and jedi channel topics
#  Also update the Jedi usergroup on slack when the rotation changes
#
# Dependencies:
#   - underscore
#   - node-fetch
#
# Configuration:
#   HUBOT_SLACK_API_TOKEN
#   HUBOT_JEDI_CHANNEL
#   HUBOT_JEDI_PLATFORM_CHANNELS
#   HUBOT_JEDI_LIGHTSABERS
#   HUBOT_JEDI_USER_GROUP
#
# Commands:
#   None
#
# Author:
#   ndaversa

_ = require "underscore"
nodeFetch = require "node-fetch"
token = process.env.HUBOT_SLACK_API_TOKEN
jediChannel = process.env.HUBOT_JEDI_CHANNEL
jediUsergroup = process.env.HUBOT_JEDI_USER_GROUP
rooms = JSON.parse process.env.HUBOT_JEDI_PLATFORM_CHANNELS
lightsabers = process.env.HUBOT_JEDI_LIGHTSABERS
jediRegex = eval "/:(#{lightsabers}): (?:jedi:? ?)?@([\\w._]*)/i"


fetch = (url, opts) ->
  robot.logger.info "Fetching: #{url}"
  options = {}
  options = _(options).extend opts

  nodeFetch(url,options).then (response) ->
    if response.status >= 200 and response.status < 300
      return response
    else
      error = new Error(response.statusText)
      error.response = response
      throw error
  .then (response) ->
    response.json()
  .catch (error) ->
    robot.logger.error error.stack

lookupUser = (username) ->
  users = robot.brain.users()
  result = (users[user] for user of users when users[user].name is username)
  if result?.length is 1
    return result[0]
  else
    return null

module.exports = (robot) ->

  robot.topic (res) ->
    return if not _(rooms).contains res.message.room
    jediTopicComponents = ["@jedis for everyone"]
    jedis = []

    for room in rooms
      channel = robot.adapter.client.getChannelGroupOrDMByName room
      continue if not channel
      topic = channel.topic.value
      continue if not jediRegex.test topic
      [ __, lightsaber, username ] = topic.match jediRegex
      continue if not lightsaber or not username

      jedi = ":#{room}: :#{lightsaber}: @#{username}"
      jediTopicComponents.push jedi
      jedis.push lookupUser username

    channel = robot.adapter.client.getChannelGroupOrDMByName jediChannel
    newJediTopic = jediTopicComponents.join "  |  "
    channel.setTopic newJediTopic if channel? and newJediTopic isnt channel.topic.value

    robot.logger.info "Updating Jedi user group #{ jediUsergroup } with [ #{ (jedis.map (j) -> j.name).join ', ' }]"
    fetch "https://slack.com/api/usergroups.users.update?token=#{token}&usergroup=#{jediUsergroup}&users=#{ (jedis.map (j) -> j.id).join ','}"
    .catch (error) ->
      robot.logger.error "An error occured trying to update the Jedi user group #{error}"

