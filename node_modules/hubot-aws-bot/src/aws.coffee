# Description:
# A hubot script to query aws for instance information
#
# Dependencies:
# - coffee-script
# - aws-sdk
# - cron
# - underscore
# - moment
#
# Configuration:
# HUBOT_AWS_REQUIRED_TAGS - A comma seperated list of required tag names to scan for
# HUBOT_AWS_REGION - The AWS region eg. "us-east-1"
# AWS_SECRET_ACCESS_KEY - AWS Secret Key
# AWS_ACCESS_KEY_ID - AWS Acesss Key
#
# Commands:
#   hubot aws untagged [running for <duration>] - List the instances that are not tagged with a role optional minimum runtime <duration> (HH:MM)
#   hubot aws untagged [running for <duration>] at <crontime> - Schedule a recurring job for untagged instances at <crontime> interval optional minimum runtime <duration> (HH:MM)
#   hubot aws query <query> [running for <duration>] - Search aws instances where instance tag Name contains <query> optionally for those that have been running for at least <duration>
#   hubot aws query <query> [running for <duration>] at <crontime> - Schedule a recurring job for search for <query> with optional <duration> at <crontime> interval
#   hubot aws jobs - List all the running jobs
#   hubot aws remove job <number> - Removes the given job number
#
# Author:
#   ndaversa

_ = require 'underscore'
moment = require 'moment'
cronJob = require("cron").CronJob
region = process.env.HUBOT_AWS_REGION
requiredTags = process.env.HUBOT_AWS_REQUIRED_TAGS.split ','
AWS = require 'aws-sdk'
AWS.config.region = region
ec2 = new AWS.EC2()

crons = []
instancesCache =
  data: []
  expiry: moment()

module.exports = (robot) ->

  createCron = (job) ->
    new cronJob(job.time, (-> run job ), null, true)

  run = (job) ->
    func = eval job.func
    args = JSON.parse job.args
    func.apply @, args

  getJobs = ->
    robot.brain.get('aws-jobs') or []

  saveJobs = (jobs) ->
    robot.brain.set 'aws-jobs', jobs

  setupJob = (func, args, cron) ->
    jobs = getJobs()
    job =
      func: func
      args: JSON.stringify args
      time: cron
    jobs.push job
    saveJobs jobs
    crons.push createCron job
    return job

  removeJob = (number) ->
    jobs = getJobs()
    if jobs[number]
      delete jobs[number]
      jobs = _(jobs).compact()
      saveJobs jobs

      crons[number].stop()
      delete crons[number]
      crons = _(crons).compact()
      return yes
    else
      return no

  listJobs = (room) ->
    message = ""
    for job, index in getJobs()
      message += "#{index}) Run `#{job.func}` with `#{job.args}` at cron `#{job.time}`\n"
    message = "No jobs have be scheduled" if not message
    robot.messageRoom room, message

  fetchInstances = (cb) ->
    if instancesCache.expiry.isAfter()
      cb instancesCache.data
    else
      ec2.describeInstances MaxResults: 500, (err, data) ->
        if err
          robot.logger.error "Received error #{JSON.stringify err}"
          robot.logger.error err.stack
        else
          instancesCache.data = data
          instancesCache.expiry = moment().add 5, 'seconds'
        cb data

  reportInstancesWithMessage = (instances, message, room) ->
      if instances.length > 0
        for reservation in instances
          for instance in reservation.Instances
            url = "https://console.aws.amazon.com/ec2/v2/home?region=#{region}#Instances:search=#{instance.InstanceId};sort=instanceId"
            name = _(instance.Tags).findWhere(Key: 'Name')?.Value or "Unnamed"
            message += "\n `#{name}` (launched #{moment(instance.LaunchTime).fromNow()}) <#{url}|Console Link>"

        robot.messageRoom room, message

  reportUntagged = (room, duration, reportZero) ->
    reportZero = no if not reportZero?
    duration = moment.duration duration if duration?

    fetchInstances (data) ->
      if not data
        robot.messageRoom room, "No instance data found"
        return

      untagged = _(data.Reservations).filter (reservation) ->
        instances = _(reservation.Instances).filter (instance) ->
          missing = _(requiredTags).any (tag) -> not _(instance.Tags).findWhere Key: tag
          missing and instance.State.Name is 'running'
        instances.length > 0

      untagged = _(untagged).filter (reservation) ->
        instances = _(reservation.Instances).filter (instance) ->
          inRange = yes
          if duration?
            diff = moment().diff instance.LaunchTime, 'seconds'
            inRange = diff > duration.asSeconds()
          inRange
        instances.length > 0

      if untagged.length > 0
        message = "The following instances are missing at least one of the tags (#{requiredTags})"
        message += " and have been running for at least #{duration.humanize()}" if duration?
        reportInstancesWithMessage untagged, message, room
      else
        message = "There are no untagged instances"
        message += " that have been running for at least #{duration.humanize()}" if duration?
        message += ", go team!"
        if reportZero
          robot.messageRoom room, message
        else
          robot.logger.info "#{room}: #{message}"

  reportOnQuery = (room, query, duration, reportZero) ->
    reportZero = no if not reportZero?
    duration = moment.duration duration if duration?

    fetchInstances (data) ->
      if not data
        return

      matches = _(data.Reservations).filter (reservation) ->
        instances = _(reservation.Instances).filter (instance) ->
          name = _(instance.Tags).findWhere(Key: 'Name')?.Value
          inRange = yes
          if duration?
            diff = moment().diff instance.LaunchTime, 'seconds'
            inRange = diff > duration.asSeconds()
          inRange and instance.State.Name is 'running' and name?.toLowerCase().indexOf(query.toLowerCase()) > -1
        instances.length > 0

      if matches.length > 0
        message = "There are #{matches.length} matches for `#{query}`"
        message += " that have been running for at least #{duration.humanize()}" if duration?
        reportInstancesWithMessage matches, message, room
      else
        message = "There are no matches for `#{query}`"
        message += " that have been running for at least #{duration.humanize()}" if duration?
        if reportZero
          robot.messageRoom room, message
        else
          robot.logger.info "#{room}: #{message}"

  robot.respond /aws jobs/, (msg) ->
    listJobs msg.message.room
    msg.finish()

  robot.respond /aws remove job (\d)/, (msg) ->
    [ __, id ] = msg.match
    if removeJob id
      msg.reply "Job ##{id} successfully removed"
    else
      msg.reply "Unable to remove Job ##{id}"
    msg.finish()

  robot.respond /aws untagged(?: running for ([^\s]+))?(?: at ([^]+))?/, (msg) ->
    [ __, duration, cron ] = msg.match
    if cron?
      job = setupJob 'reportUntagged', [ msg.message.room, duration ], cron
      msg.reply "Job ##{getJobs().length - 1} has been scheduled to run `#{job.func}` with `#{job.args}` at cron `#{job.time}`"
    else
      reportUntagged msg.message.room, duration, yes
    msg.finish()

  robot.respond /aws query ([^\s]+)(?: running for ([^\s]+))?(?: at ([^]+))?/, (msg) ->
    [ __, query, duration, cron ] = msg.match
    if cron?
      job = setupJob 'reportOnQuery', [ msg.message.room, query, duration ], cron
      msg.reply "Job ##{getJobs().length - 1} has been scheduled to run `#{job.func}` with `#{job.args}` at cron `#{job.time}`"
    else
      reportOnQuery msg.message.room, query, duration, yes
    msg.finish()

  robot.brain.once 'loaded', ->
    crons.push createCron job for job in getJobs()
