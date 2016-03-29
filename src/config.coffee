class Config

  @debug: process.env.HUBOT_LOG_LEVEL is "debug"

  @server:
    url: process.env.EXPRESS_URL
    credentials:
      name: process.env.EXPRESS_USERNAME
      pass: process.env.EXPRESS_PASSWORD

  @stats:
    host: process.env.STATSD_HOST
    port: process.env.STATSD_PORT
    prefix: process.env.STATS_PREFIX or ""

  @anonymous: channels: ["ceo", "deadbeef"]

  @birthday: calendar: url: process.env.HUBOT_BIRTHDAY_ICAL

  @cache:
    expiry: 60*60*1000 # 1 hour
    usergroups: 
      users: expiry: 15*60*1000 # 15 mins
      list: expiry: 60*60*1000 # 1 hour
    calendar: expiry: 15*60*1000 # 15 mins

  @calendar:
    map: JSON.parse process.env.HUBOT_CALENDAR_MAP
    verification: token: process.env.HUBOT_CALENDAR_VERIFICATION_TOKEN

  @meeting:
    verification: token: process.env.HUBOT_MEETING_VERIFICATION_TOKEN
    server: url: process.env.HUBOT_AGORA_URL

  @threesixty:
    intro: expiry: 3*60*60*1000 # 3 hours
    answer: expiry: 15*60*1000 # 15 minutes
    usergroup: process.env.HUBOT_360_ADMIN_USERGROUP

  @slack:
    token: process.env.HUBOT_SLACK_API_TOKEN
    verification: token: process.env.HUBOT_SLACK_VERIFICATION_TOKEN

  @tracker:
    verification: token: process.env.HUBOT_TRACKER_VERIFICATION_TOKEN

  @status:
    channel: message: room: process.env.HUBOT_STATUSBOT_CHANNEL
    usergroup: process.env.HUBOT_STATUSBOT_USERGROUP

  @zendesk:
    channel: message: room: process.env.HUBOT_ZENDESK_CHANNEL
    username: process.env.HUBOT_ZENDESK_USERNAME
    url: process.env.HUBOT_ZENDESK_URL
    token: process.env.HUBOT_ZENDESK_TOKEN
    section: process.env.HUBOT_ZENDESK_SECTION

  @statuspage:
    url: "https://api.statuspage.io/v1"
    homepage: "https://manage.statuspage.io/pages/#{process.env.HUBOT_STATUSPAGE_ID}"
    id: process.env.HUBOT_STATUSPAGE_ID
    token: process.env.HUBOT_STATUSPAGE_API_KEY

  @vacation: calendar: url: process.env.HUBOT_VACATION_ICAL

  @topic:
    calendars: JSON.parse process.env.HUBOT_ICAL_CHANNEL_MAP
    labels: JSON.parse process.env.HUBOT_ICAL_LABEL_CHANNEL_MAP
    cronTime: process.env.HUBOT_ICAL_CRON_UPDATE_INTERVAL || "0 */15 * * * *"
    duplicateResolution: process.env.HUBOT_ICAL_DUPLICATE_RESOLVER || "OVERRIDE: "
    regex: "(__LABEL__:(?:[^|]*)\\s*\\|\\s*)?(.*)"

module.exports = Config
