#Hubot AWS Bot
A hubot script to query aws for instance information

###Dependencies
  * coffee-script
  * cron
  * aws-sdk
  * underscore
  * moment

###Configuration
 - `HUBOT_AWS_REQUIRED_TAGS` - A comma seperated list of required tag names to scan for
 - `HUBOT_AWS_REGION` - The AWS region eg. "us-east-1"
 - `AWS_SECRET_ACCESS_KEY` - AWS Secret Key
 - `AWS_ACCESS_KEY_ID` - AWS Acesss Key

###Commands
 - `hubot aws untagged [running for <duration>]` - List the instances that are not tagged with a role optional minimum runtime <duration> (HH:MM)
 - `hubot aws untagged [running for <duration>] at <crontime>` - Schedule a recurring job for untagged instances at <crontime> interval optional minimum runtime <duration> (HH:MM)
 - `hubot aws query <query> [running for <duration>]` - Search aws instances where instance tag Name contains <query> optionally for those that have been running for at least <duration>
 - `hubot aws query <query> [running for <duration>] at <crontime>` - Schedule a recurring job for search for <query> with optional <duration> at <crontime> interval
 - `hubot aws jobs` - List all the running jobs
 - `hubot aws remove job <number>` - Removes the given job number

###Cron Ranges
Internally this uses [node-cron](https://github.com/ncb000gt/node-cron)

When specifying your cron values you'll need to make sure that your values fall within the ranges. For instance, some cron's use a 0-7 range for the day of week where both 0 and 7 represent Sunday. We do not.

  * Seconds: 0-59
  * Minutes: 0-59
  * Hours: 0-23
  * Day of Month: 1-31
  * Months: 0-11
  * Day of Week: 0-6
