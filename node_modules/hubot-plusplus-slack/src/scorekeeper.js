/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
// Description:
//   Helper class responsible for storing scores
//
// Dependencies:
//
// Configuration:
//
// Commands:
//
// Author:
//   ajacksified
class ScoreKeeper {
  constructor(robot) {
    this.robot = robot;
    const storageLoaded = () => {
      this.storage = this.robot.brain.data.plusPlus || (this.robot.brain.data.plusPlus = {
        scores: {},
        log: {},
        reasons: {},
        last: {}
      });
      if (typeof this.storage.last === "string") {
        this.storage.last = {};
      }

      return this.robot.logger.debug(`Plus Plus Data Loaded: ${JSON.stringify(this.storage, null, 2)}`);
    };
    this.robot.brain.on("loaded", storageLoaded);
    storageLoaded(); // just in case storage was loaded before we got here
  }


  getUser(user) {
    if (!this.storage.scores[user]) { this.storage.scores[user] = 0; }
    if (!this.storage.reasons[user]) { this.storage.reasons[user] = {}; }
    return user;
  }

  saveUser(user, from, room, reason) {
    this.saveScoreLog(user, from, room, reason);
    this.robot.brain.save();

    return [this.storage.scores[user], this.storage.reasons[user][reason] || "none"];
  }

  add(user, from, room, reason) {
    if (this.validate(user, from)) {
      user = this.getUser(user);
      this.storage.scores[user]++;
      if (!this.storage.reasons[user]) { this.storage.reasons[user] = {}; }

      if (reason) {
        if (!this.storage.reasons[user][reason]) { this.storage.reasons[user][reason] = 0; }
        this.storage.reasons[user][reason]++;
      }

      return this.saveUser(user, from, room, reason);
    } else {
      return [null, null];
    }
  }

  subtract(user, from, room, reason) {
    if (this.validate(user, from)) {
      user = this.getUser(user);
      this.storage.scores[user]--;
      if (!this.storage.reasons[user]) { this.storage.reasons[user] = {}; }

      if (reason) {
        if (!this.storage.reasons[user][reason]) { this.storage.reasons[user][reason] = 0; }
        this.storage.reasons[user][reason]--;
      }

      return this.saveUser(user, from, room, reason);
    } else {
      return [null, null];
    }
  }

  erase(user, from, room, reason) {
    user = this.getUser(user);

    if (reason) {
      delete this.storage.reasons[user][reason];
      this.saveUser(user, from.name, room);
      return true;
    } else {
      delete this.storage.scores[user];
      delete this.storage.reasons[user];
      return true;
    }

    return false;
  }

  scoreForUser(user) {
    user = this.getUser(user);
    return this.storage.scores[user];
  }

  reasonsForUser(user) {
    user = this.getUser(user);
    return this.storage.reasons[user];
  }

  saveScoreLog(user, from, room, reason) {
    if (typeof this.storage.log[from] !== "object") {
      this.storage.log[from] = {};
    }

    this.storage.log[from][user] = new Date();
    return this.storage.last[room] = {user, reason};
  }

  last(room) {
    const last = this.storage.last[room];
    if (typeof last === 'string') {
      return [last, ''];
    } else {
      return [last.user, last.reason];
    }
  }

  isSpam(user, from) {
    if (!this.storage.log[from]) { this.storage.log[from] = {}; }

    if (!this.storage.log[from][user]) {
      return false;
    }

    const dateSubmitted = this.storage.log[from][user];

    const date = new Date(dateSubmitted);
    const messageIsSpam = date.setSeconds(date.getSeconds() + 5) > new Date();

    if (!messageIsSpam) {
      delete this.storage.log[from][user]; //clean it up
    }

    return messageIsSpam;
  }

  validate(user, from) {
    return (user !== from) && (user !== "") && !this.isSpam(user, from);
  }

  length() {
    return this.storage.log.length;
  }

  top(amount) {
    let score;
    const tops = [];

    for (let name in this.storage.scores) {
      score = this.storage.scores[name];
      tops.push({name, score});
    }

    return tops.sort((a,b) => b.score - a.score).slice(0,amount);
  }

  bottom(amount) {
    const all = this.top(this.storage.scores.length);
    return all.sort((a,b) => b.score - a.score).reverse().slice(0,amount);
  }

  normalize(fn) {
    const scores = {};

    _.each(this.storage.scores, function(score, name) {
      scores[name] = fn(score);
      if (scores[name] === 0) { return delete scores[name]; }
    });

    this.storage.scores = scores;
    return this.robot.brain.save();
  }
}

module.exports = ScoreKeeper;
