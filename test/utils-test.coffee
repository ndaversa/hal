chai = require 'chai'
expect = chai.expect
users = require "./users.json"
Utils = require "../src/utils"

describe "Utils", ->
  beforeEach ->
    @robot = Utils.robot
    Utils.robot =
      logger:
        debug: ->
        info: ->
      brain: users: -> users
      adapter: client: rtm: dataStore: users: users

  afterEach ->
    Utils.robot = @robot

  describe "fuzzyFindChatUser", ->

    it "properly matches Nino", ->
      found = Utils.fuzzyFindChatUser "Nino"
      expect(found).to.eql
        id: "SLACKUSERID"
        name: "ndaversa"
        real_name: "Nino D'Aversa"
        email: "nino"

