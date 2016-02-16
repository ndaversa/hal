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
#
# Commands:
#   None
#
# Author:
#   ndaversa

_ = require "underscore"
fetch = require "node-fetch"
token = process.env.HUBOT_SLACK_API_TOKEN

parseJSON = (response) ->
  return response.json()

checkStatus = (response) ->
  if response.status >= 200 and response.status < 300
    return response
  else
    error = new Error(response.statusText)
    error.response = response
    throw error

lookupUser = (username) ->
  users = robot.brain.users()
  result = (users[user] for user of users when users[user].name is username)
  if result?.length is 1
    return result[0].id
  else
    return null

module.exports = (robot) ->
  jediUsergroup = "S0LV4HX8W"
  rooms = ["ios", "android", "web", "platform"]
  baseRegex = ":(lightsaber|lightsaber-blue|kyloren|sith|sithlord): (?:jedi:? ?)?@([\\w._]*)"
  jediRegex = eval "/#{baseRegex}/i"
  jediChannelRegex = eval "/:(#{rooms.join '|'}): #{baseRegex}/gi"
  jediPlatformRegex = eval "/:(#{rooms.join '|'}): #{baseRegex}/i"

  robot.topic (res) ->
    room = res.message.room
    if _(rooms).contains room
      topic = res.message.text
      if jediRegex.test topic
        [ __, lightsaber, username ] = topic.match jediRegex
        if lightsaber and username
          channel = robot.adapter.client.getChannelGroupOrDMByName "jedi"
          jediTopic = channel.topic.value
          jediChannelComponents = jediTopic.match jediChannelRegex

          newJediChannelComponents = []
          found=no
          newJedi = ":#{room}: :#{lightsaber}: @#{username}"

          for match in jediChannelComponents
            if match.includes ":#{room}:"
              found=yes
              match = newJedi
            newJediChannelComponents.push match

          newJediChannelComponents.push newJedi if not found
          newTopic = newJediChannelComponents.join "  |  "
          channel.setTopic newTopic if newTopic isnt jediTopic

          jedi = newJediChannelComponents.map (jedi) ->
            components = jedi.match jediPlatformRegex
            if components.length >= 4
              return lookupUser components[3]
            else
              return undefined
          jedi = _(jedi).compact()

          fetch("https://slack.com/api/usergroups.users.update?token=#{token}&usergroup=#{jediUsergroup}&users=#{jedi.join ','}")
          .then (res) ->
            checkStatus res
          .then (res) ->
            parseJSON res
          .catch (error) ->
            console.log "An error occured trying to update the Jedi user group #{error}"

