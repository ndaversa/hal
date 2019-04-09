/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
// Description:
//   Give or take away points. Keeps track and even prints out graphs.
//
// Dependencies:
//   "underscore": ">= 1.0.0"
//   "clark": "0.0.6"
//
// Configuration:
//   HUBOT_PLUSPLUS_KEYWORD: the keyword that will make hubot give the
//   score for a name and the reasons. For example you can set this to
//   "score|karma" so hubot will answer to both keywords.
//   If not provided will default to 'score'.
//
//   HUBOT_PLUSPLUS_REASON_CONJUNCTIONS: a pipe separated list of conjuntions to
//   be used when specifying reasons. The default value is
//   "for|because|cause|cuz|as", so it can be used like:
//   "foo++ for being awesome" or "foo++ cuz they are awesome".
//
// Commands:
//   <name>++ [<reason>] - Increment score for a name (for a reason)
//   <name>-- [<reason>] - Decrement score for a name (for a reason)
//   hubot score <name> - Display the score for a name and some of the reasons
//   hubot top <amount> - Display the top scoring <amount>
//   hubot bottom <amount> - Display the bottom scoring <amount>
//   hubot erase <name> [<reason>] - Remove the score for a name (for a reason)
//
// URLs:
//   /hubot/scores[?name=<name>][&direction=<top|botton>][&limit=<10>]
//
// Author:
//   ajacksified


const _ = require('underscore');
const clark = require('clark');
const querystring = require('querystring');
const ScoreKeeper = require('./scorekeeper');
const { WebClient } = require('@slack/client');

module.exports = function(robot) {
  const web = new WebClient(process.env.HUBOT_SLACK_API_TOKEN);
  const scoreKeeper = new ScoreKeeper(robot);
  const scoreKeyword   = process.env.HUBOT_PLUSPLUS_KEYWORD || 'score';
  const reasonsKeyword = process.env.HUBOT_PLUSPLUS_REASONS || 'raisins';
  const reasonConjunctions = process.env.HUBOT_PLUSPLUS_CONJUNCTIONS || 'for|because|cause|cuz|as';
  const commandRegex = new RegExp(`^([\\s\\w'@.\\-:\\u3040-\\u30FF\\uFF01-\\uFF60\\u4E00-\\u9FA0]*)\s*(\\+\\+|--|—)(?:\\s+(?:${reasonConjunctions})\\s+(.+))?$`, 'i');

  // Given the results of a match of commandRegex against a message, extracts
  // and returns an array in the order [ name, operator, reason ], or null if
  // there was no match
  function extractCommand(regexMatch) {
    if (!regexMatch) {
      return null;
    }

    let [_, name, operator, reason] = regexMatch;

    // do some sanitizing
    reason = reason != null ? reason.trim().toLowerCase() : undefined;

    if (name) {
      if (name.charAt(0) === ':') {
        name = (name.replace(/(^\s*@)|([,\s]*$)/g, '')).trim().toLowerCase();
      } else {
        name = (name.replace(/(^\s*@)|([,:\s]*$)/g, '')).trim().toLowerCase();
      }
    }

    return [ name, operator, reason ];
  }

  robot.hear(commandRegex, async function (msg) {
    let [ name, operator, reason ] = extractCommand(msg.match);
    const from = msg.message.user.name.toLowerCase();
    const { room } = msg.message;

    // check whether a name was specified. check previous results if not
    if (!name || name === '') {
      let lastReason;
      if (msg.message.thread_ts) {
        let thread;

        try {
          thread = await web.conversations.history({
            channel: msg.envelope.room,
            latest: msg.message.thread_ts,
            count: 1,
            inclusive: true
          });
        } catch(e) {
          // Accept failure, and fall back to the old behaviour of looking it
          // up in the bot's brain
          console.log(`Couldn't look up thread from ${from} due to ${e}`);
        }

        if (thread && thread.messages.length) {
          let match = thread.messages[0].text.match(commandRegex);
          let extracted = extractCommand(thread.messages[0].text.match(commandRegex));
          if (extracted) {
            [ name, operator, lastReason ] = extracted;
          }
        }
      }

      if (!name) {
        [name, lastReason] = scoreKeeper.last(room);
      }

      if (!reason && lastReason) {
        reason = lastReason;
      }
    }

    // do the {up, down}vote, and figure out what the new score is
    const [score, reasonScore] = operator === "++" ? scoreKeeper.add(name, from, room, reason)
                                                   : scoreKeeper.subtract(name, from, room, reason);

    // if we got a score, then display all the things and fire off events!
    if (score != null) {
      const message = (reason != null) ?
                  (reasonScore === 1) || (reasonScore === -1) ?
                    (score === 1) || (score === -1) ?
                      `${name} has ${score} point for ${reason}.`
                    :
                      `${name} has ${score} points, ${reasonScore} of which is for ${reason}.`
                  :
                    `${name} has ${score} points, ${reasonScore} of which are for ${reason}.`
                :
                  score === 1 ?
                    `${name} has ${score} point`
                  :
                    `${name} has ${score} points`;


      // Make sure we're threading on the user's message
      if (msg.message.rawMessage.thread_ts) {
        msg.message.thread_ts = msg.message.rawMessage.thread_ts;
      } else {
        msg.message.thread_ts = msg.message.rawMessage.ts;
      }

      msg.send(message);

      robot.emit("plus-one", {
        name,
        direction: operator,
        room,
        reason,
        from
      });
    }
});

  robot.respond(new RegExp(`(?:erase )([\\s\\w'@.-:\\u3040-\\u30FF\\uFF01-\\uFF60\\u4E00-\\u9FA0]*)(?:\\s+(?:${reasonConjunctions})\\s+(.+))?$`, 'i'), function(msg) {
    let erased;
    let [__, name, reason] = Array.from(msg.match);
    const from = msg.message.user.name.toLowerCase();
    const { user } = msg.envelope;
    const { room } = msg.message;
    reason = reason != null ? reason.trim().toLowerCase() : undefined;

    if (name) {
      if (name.charAt(0) === ':') {
        name = (name.replace(/(^\s*@)|([,\s]*$)/g, '')).trim().toLowerCase();
      } else {
        name = (name.replace(/(^\s*@)|([,:\s]*$)/g, '')).trim().toLowerCase();
      }
    }

    const isAdmin = (this.robot.auth != null ? this.robot.auth.hasRole(user, 'plusplus-admin') : undefined) || (this.robot.auth != null ? this.robot.auth.hasRole(user, 'admin') : undefined);

    if ((this.robot.auth == null) || isAdmin) {
      erased = scoreKeeper.erase(name, from, room, reason);
    } else {
      return msg.reply("Sorry, you don't have authorization to do that.");
    }

    if (erased != null) {
      const message = (reason != null) ?
                  `Erased the following reason from ${name}: ${reason}`
                :
                  `Erased points for ${name}`;
      return msg.send(message);
    }
  });

  // Catch the message asking for the score.
  robot.respond(new RegExp(`(?:${scoreKeyword}) (for\s)?(.*)`, "i"), function(msg) {
    let name = msg.match[2].trim().toLowerCase();

    if (name) {
      if (name.charAt(0) === ':') {
        name = (name.replace(/(^\s*@)|([,\s]*$)/g, ''));
      } else {
        name = (name.replace(/(^\s*@)|([,:\s]*$)/g, ''));
      }
    }

    const score = scoreKeeper.scoreForUser(name);
    const reasons = scoreKeeper.reasonsForUser(name);

    const reasonString = (typeof reasons === 'object') && (Object.keys(reasons).length > 0) ?
                     `${name} has ${score} points. Here are some ${reasonsKeyword}:` +
                     _.reduce(reasons, (memo, val, key) => memo += `\n${key}: ${val} points`
                     , "")
                   :
                     `${name} has ${score} points.`;

    return msg.send(reasonString);
  });

  robot.respond(/(top|bottom) (\d+)/i, function(msg) {
    const amount = parseInt(msg.match[2]) || 10;
    const message = [];

    const tops = scoreKeeper[msg.match[1]](amount);

    if (tops.length > 0) {
      for (let i = 0, end = tops.length-1, asc = 0 <= end; asc ? i <= end : i >= end; asc ? i++ : i--) {
        message.push(`${i+1}. ${tops[i].name} : ${tops[i].score}`);
      }
    } else {
      message.push("No scores to keep track of yet!");
    }

    if(msg.match[1] === "top") {
      const graphSize = Math.min(tops.length, Math.min(amount, 20));
      message.splice(0, 0, clark(_.first(_.pluck(tops, "score"), graphSize)));
    }

    return msg.send(message.join("\n"));
  });

  robot.router.get(`/${robot.name}/normalize-points`, function(req, res) {
    scoreKeeper.normalize(function(score) {
      if (score > 0) {
        score = score - Math.ceil(score / 10);
      } else if (score < 0) {
        score = score - Math.floor(score / 10);
      }

      return score;
    });

    return res.end(JSON.stringify('done'));
  });

  return robot.router.get(`/${robot.name}/scores`, function(req, res) {
    const query = querystring.parse(req._parsedUrl.query);

    if (query.name) {
      const obj = {};
      obj[query.name] = scoreKeeper.scoreForUser(query.name);
      return res.end(JSON.stringify(obj));
    } else {
      const direction = query.direction || "top";
      const amount = query.limit || 10;

      const tops = scoreKeeper[direction](amount);

      return res.end(JSON.stringify(tops, null, 2));
    }
  });
};
