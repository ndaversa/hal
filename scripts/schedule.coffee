# Description:
#   Display information about the current engineering schedule
#
# Dependencies:
#  - google-spreadsheet
#  - moment
#  - underscore
#  - columnify
#
# Configuration:
# HUBOT_SCHEDULE_SPREADSHEET_ID
# HUBOT_SCHEDULE_EMAIL_ACCOUNT
# HUBOT_SCHEDULE_PRIVATE_KEY
#
# Commands:
#   hubot schedule for <team>
#
# Author:
#   ndaversa

_ = require "underscore"
moment = require "moment"
columnify = require 'columnify'
GoogleSpreadsheet = require "google-spreadsheet"
Fuse = require 'fuse.js'

spreadsheet = new GoogleSpreadsheet process.env.HUBOT_SCHEDULE_SPREADSHEET_ID
creds = require "./google-generated-creds.json"
expansions = J: "Jedi", C: "Changeling", A: "Architect", V: "Vacation", IP: "Internal", "O": "Onboarding"
WEEKS = 52

module.exports = (robot) ->

  send = (context, message, prependUsername=no) ->
    robot.adapter.customMessage
      channel: context.message.room
      text: "#{if prependUsername then "<@#{context.message.user.id}> " else ""}#{message}"

  lookupUser = (name) ->
    users = robot.brain.users()
    users = _(users).keys().map (id) ->
      u = users[id]
      if not u.slack.deleted and not u.slack.is_bot and u.email_address?.includes '@wattpad'
        id: u.id
        name: u.name.toLowerCase()
        real_name: u.real_name.toLowerCase()
        email: u.email_address?.split('@')[0].toLowerCase() or ''
      else
        null
    users = _(users).compact()

    f = new Fuse users,
      keys: ['real_name']
      shouldSort: yes
      verbose: no
    results = f.search name
    if results? and results.length >=1
      return "@#{results[0].name}"
    else
      return name

  _engineering = []
  _schedule = []
  scheduleExpiry = moment()
  getSchedule = ->
    if _engineering.length > 0 and moment().isBefore scheduleExpiry
      robot.logger.info 'Returning cached schedule'
      return Promise.resolve _engineering
    return new Promise (resolve, reject) ->
      robot.logger.info 'Schedule cache expired, fetching fresh schedule'
      spreadsheet.useServiceAccountAuth creds, (err) ->
        return reject "Authentication Failed" if err
        spreadsheet.getInfo (err, info) ->
          return reject "Unable to get spreadsheet info" if err
          sheet = s for s in info.worksheets when s.title is "engineering"
          return reject "Could not find the engineering sheet" unless sheet
          sheet.getCells "min-row": 1, "max-row": 45, "min-col": 1, "max-col": WEEKS, "return-empty": true, (err, data) ->
            return reject "Unable to get the cells from the engineering sheet" if err
            _engineering = data;
            sheet = s for s in info.worksheets when s.title is "schedule"
            return reject "Could not find the schedule sheet" unless sheet
            sheet.getCells "min-row": 1, "max-row": 45, "min-col": 1, "max-col": WEEKS, "return-empty": true, (err, data) ->
              return reject "Unable to get the cells from the schedule sheet" if err
              _schedule = data;
              scheduleExpiry = moment().add 30, 'minutes'
              resolve _engineering

  findColumnForThisWeek = ->
    for cell, index in _engineering
      date = moment(cell.value, "MMM-D")
      if date.isValid() and date.isAfter()
        return _engineering[index-1].col

  findRowsFor = (team) ->
    for cell, index in _engineering
      teamHeaderRegex = eval "/#{team} - \\d/i"
      if teamHeaderRegex.test cell.value
        selection = cell
        i = 0
        selection = _engineering[ i++ * WEEKS + index ] while selection.value
        break
    start: cell?.row + 1
    end: selection?.row - 1

  findRowForLane = (team, lane) ->
    for cell, index in _schedule
      teamHeaderRegex = eval "/#{team} - \\d/i"
      if teamHeaderRegex.test cell.value
        selection = cell
        i = 0
        while selection.value isnt "Lane #{lane}"
          selection = _schedule[ i++ * WEEKS + index ]
        selection = _schedule[ i * WEEKS + index ]
        break
    return selection?.row

  findProjectFor = (team, lane, column) ->
    row = findRowForLane team, lane
    project = _schedule[ (row-1)*WEEKS + column ]?.value or "TBD"
    return project

  generateScheduleFor = (team, rows, column, numWeeks=5) ->
    employees = []
    columns = [ "name" ]
    for e in [rows.start..rows.end]
      active = _engineering[ (e-1)*WEEKS + 1 ].value
      continue unless active
      employee = name: lookupUser _engineering[ (e-1)*WEEKS ].value
      for w in [column-1..column+3]
        columns.push "#{w}"
        employee[w] = _engineering[ (e-1)*WEEKS + w ].value
        if employee[w] and expansions[employee[w]]
          employee[w] = expansions[employee[w]]
        else if /\d/.test employee[w]
          employee[w] = findProjectFor team, employee[w], w
        else if not employee[w]
          employee[w] = "-"
      employees.push employee

    table = columnify employees,
      columns: _(columns).unique()
      columnSplitter: " | "
      align: 'center'
      config: name: align: 'left'
      headingTransform: (h) ->
        week = parseInt h, 10
        rc = if week then _engineering[week].value else h
        return rc.toUpperCase()

    """
    ```#{table}```
    """

  robot.hear /^(?:Reminder:|hal|pal) schedule for (web|ios|android|platform)\.?$/, (context) ->
    [ __, team ] = context.match
    getSchedule().then (data) ->
      column =  findColumnForThisWeek()
      rows = findRowsFor team
      channel = robot.adapter.client.getChannelGroupOrDMByName team
      channel = if channel then "<\##{channel.id}|#{channel.name}>" else "\##{team}"
      """
      Schedule for the #{channel} team
      #{generateScheduleFor team, rows, column}
      """
    .then (message) ->
      send context, message
    .catch (error) ->
      robot.logger.error "Error: #{error}"
      robot.logger.error error?.stack
