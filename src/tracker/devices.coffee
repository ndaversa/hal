# Description:
#  Track Devices
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

class Devices

  @key: "trackerbot-device-map"

  constructor: (@robot) ->
    return new Devices @robot unless @ instanceof Devices
    @robot.brain.once 'loaded', =>
      @devices = @robot.brain.get(Devices.key) or {}

  save: ->
    @robot.brain.set Devices.key, @devices

  all: -> return @devices

  get: (key) ->
    return @devices unless key
    return @devices[key]

  remove: (device) ->
    delete @devices[device.id]
    @save()

  add: (device) ->
    @devices[device.id] = device
    @save()
    @devices[device.id]

module.exports = Devices
