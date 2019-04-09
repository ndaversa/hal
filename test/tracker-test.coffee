Config = require "./../src/config"
Helper = require "hubot-test-helper"
helper = new Helper "../src/tracker/index.coffee"
fetch = require "node-fetch"

sinon = require "sinon"
chai = require 'chai'
chaiAsPromised = require "chai-as-promised"
chai.use chaiAsPromised
expect = chai.expect

describe "TrackerBot", ->
  beforeEach ->
    @room = helper.createRoom()
    @now = sinon.stub Date, "now", -> 12345

  afterEach ->
    @room.destroy()
    @now.restore()

  describe 'POST /hubot/tracker/device/register', ->
    it "responds with status 403 when not provided a token", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/register",
        method: "POST"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 403

    it "responds with status 403 when provided an incorrect token", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/register",
        method: "POST"
        headers: Authorization: "Basic deadbeef"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 403

    it "responds with status 200 when a valid token is provided", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/register",
        method: "POST"
        headers: Authorization: "Basic #{Config.tracker.verification.token}"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 200

    it "responds with status 200 and persists the new device and returns an id", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/register",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          physical_id: 1234
          manufacuter: "LG"
          sdk: "16"
          model: "Nexus"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 200
        expect(response.json()).to.eventually.be.fulfilled.then (json) ->
          expect(json).to.deep.equal
            id: "81dc9bd"
            physical_id: 1234
            manufacuter: "LG"
            sdk: "16"
            model: "Nexus"

    it "responds with status 200 and updates the new device and returns an id", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/register",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          physical_id: 1234
          manufacuter: "LG"
          sdk: "17"
          model: "Nexus"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 200
        expect(response.json()).to.eventually.be.fulfilled.then (json) ->
          expect(json).to.deep.equal
            id: "81dc9bd"
            physical_id: 1234
            manufacuter: "LG"
            sdk: "17"
            model: "Nexus"

  describe 'POST /hubot/tracker/session/start', ->

    it "responds with status 403 when not provided a token", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/start",
        method: "POST"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 403

    it "responds with status 403 when provided an incorrect token", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/start",
        method: "POST"
        headers: Authorization: "Basic deadbeef"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 403

    it "responds with status 200 and starts a new session when required details are provided", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/start",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          id: "81dc9bd"
          name: "Nino D'Aversa"
          email: "nino@example.com"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 200
        expect(response.json()).to.eventually.be.fulfilled.then (json) ->
          expect(json).to.deep.equal
            id: "81dc9bd"
            name: "Nino D'Aversa"
            email: "nino@example.com"
            time: 12345

    it "responds with status 400 if the name parameter is missing", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/start",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          id: "81dc9bd"
          email: "nino@example.com"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 400

    it "responds with status 400 if the email parameter is missing", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/start",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          id: "81dc9bd"
          name: "Nino D'Aversa"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 400

    it "responds with status 400 if the id parameter is missing", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/start",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          email: "nino@example.com"
          name: "Nino D'Aversa"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 400

  describe 'POST /hubot/tracker/session/end', ->

    it "responds with status 403 when not provided a token", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/end",
        method: "POST"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 403

    it "responds with status 403 when provided an incorrect token", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/end",
        method: "POST"
        headers: Authorization: "Basic deadbeef"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 403

    it "responds with status 200 and ends a session when the required fields are provided", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/end",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          id: "81dc9bd"
          name: "Nino D'Aversa"
          email: "nino@example.com"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 200

    it "responds with status 400 if the name parameter is missing", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/end",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          id: "81dc9bd"
          email: "nino@example.com"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 400

    it "responds with status 400 if the email parameter is missing", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/end",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          id: "81dc9bd"
          name: "Nino D'Aversa"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 400

    it "responds with status 400 if the id parameter is missing", ->
      request = fetch "http://localhost:8080/hubot/tracker/device/session/end",
        method: "POST"
        headers:
          "Content-Type": "application/json"
          Authorization: "Basic #{Config.tracker.verification.token}"
        body: JSON.stringify
          email: "nino@example.com"
          name: "Nino D'Aversa"

      expect(request).to.eventually.be.fulfilled.then (response) ->
        expect(response.status).to.equal 400
