/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const chai = require('chai');
const sinon = require('sinon');
chai.use(require('sinon-chai'));

const { expect } = chai;

const ScoreKeeper = require('../src/scorekeeper');

let robotStub = {};

describe('ScoreKeeper', function() {
  let s = {};

  beforeEach(function() {
    robotStub = {
      brain: {
        data: { },
        on() {},
        emit() {},
        save() {}
      },
      logger: {
        debug() {}
      }
    };
    return s = new ScoreKeeper(robotStub);
  });

  describe('adding', function() {
    it('adds points to a user', function() {
      const r = s.add('to', 'from', 'room');
      return expect(r[0]).to.equal(1);
    });

    it('adds points to a user for a reason', function() {
      const r = s.add('to', 'from', 'room', 'because points');
      return expect(r).to.deep.equal([1, 1]);
    });

    it('does not allow spamming points', function() {
      const r = s.add('to', 'from', 'room', 'because points');
      const r2 = s.add('to', 'from', 'room', 'because points');
      return expect(r2).to.deep.equal([null, null]);
    });

    return it('adds more points to a user for a reason', function() {
      let r = s.add('to', 'from', 'room', 'because points');
      r = s.add('to', 'another-from', 'room', 'because points');
      return expect(r).to.deep.equal([2, 2]);
    });
  });

  describe('subtracting', function() {
    it('adds points to a user', function() {
      const r = s.subtract('to', 'from', 'room');
      return expect(r[0]).to.equal(-1);
    });

    it('subtracts points from a user for a reason', function() {
      const r = s.subtract('to', 'from', 'room', 'because points');
      return expect(r).to.deep.equal([-1, -1]);
    });

    it('does not allow spamming points', function() {
      const r = s.subtract('to', 'from', 'room', 'because points');
      const r2 = s.subtract('to', 'from', 'room', 'because points');
      return expect(r2).to.deep.equal([null, null]);
    });

    return it('subtracts more points from a user for a reason', function() {
      let r = s.subtract('to', 'from', 'room', 'because points');
      r = s.subtract('to', 'another-from', 'room', 'because points');
      return expect(r).to.deep.equal([-2, -2]);
    });
  });

  describe('erasing', function() {
    it('erases a reason from a user', function() {
      const p = s.add('to', 'from', 'room', 'reason');
      const r = s.erase('to', 'from', 'room', 'reason');
      expect(r).to.deep.equal(true);
      const rs = s.reasonsForUser('to');
      return expect(rs.reason).to.equal(undefined);
    });

    return it('erases a user from the scoreboard', function() {
      const p = s.add('to', 'from', 'room', 'reason');
      expect(p).to.deep.equal([1, 1]);
      const r = s.erase('to', 'from', 'room');
      expect(r).to.equal(true);
      const p2 = s.scoreForUser('to');
      return expect(p2).to.equal(0);
    });
  });

  return describe('scores', function() {
    it('returns the score for a user', function() {
      s.add('to', 'from', 'room');
      const r = s.scoreForUser('to');
      return expect(r).to.equal(1);
    });

    return it('returns the reasons for a user', function() {
      s.add('to', 'from', 'room', 'because points');
      const r = s.reasonsForUser('to');
      return expect(r).to.deep.equal({ 'because points': 1 });
    });
  });
});
