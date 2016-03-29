# Assertions and Stubbing
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'youtube-v3', ->
  
  beforeEach ->
    @robot =
      respond: sinon.spy()
    
    # API Key used for testing to function, need to keep that secret
    process.env.HUBOT_GOOGLE_API = "xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXx"
      
    # load the module under test and configure it for the
    # robot. This is in place of external-scripts
    require('../src/youtube-v3')(@robot)

  it 'registers a respond listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(?:youtube|yt)(?: me)?\s(.*)/i)
