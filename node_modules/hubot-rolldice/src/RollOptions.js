function createBasicReroll(val){
  return function(diceValue){
    return diceValue === val;
  }
}

function createLessThanReroll(val, lte){
  return function(diceValue){
    if(lte) {
      return diceValue <= val;
    }
    return diceValue < val;
  }
}

function createGreaterThanReroll(val, gte){
  return function(diceValue){
    if(gte) {
      return diceValue >= val;
    }
    return diceValue > val;
  }
}

function needReroll(num){
  var rule;
  for(var jk in this.reroll){
    rule = this.reroll[jk];
    if(rule(num)){
      return true;
    }
  }
  return false;
}

/**
 * Parse the roll options out of the given options string
 */
function RollOptions(options){
  /**
   * If truthy, keep only a certain number of dice from the roll
   */
  this.keep = false;
  /**
   * If truthy, drop a certain number of dice from the roll
   */
  this.drop = false;
  /**
   * If truthy, keep/drop the highest rolls
   */
  this.highestRolls = false;
  /**
   * If truthy, keep/drop the lowest rolls
   */
  this.lowestRolls = false;
  /**
   * Any rules to examine a roll and determine if it should be rerolled
   */
  this.reroll = [];
  /**
   * If these options were parsed successfully
   */
  this.isValid = true;
  /**
   * Determine if a single roll needs to be rerolled by consulting this.reroll
   */
  this.needReroll = needReroll.bind(this);
  
  // r4r2 = reroll 4's and 2's
  // r<3 = reroll anything less than 3
  // r>3 = reroll anything greather than 3
  // k4 or kh4 = keep 4 highest rolls
  // d4 or dl4 = drop 4 lowest rolls
  var optString = options;
  var optionPattern = /^([rkd])([^rkd]+)/i;
  var parseKeepDrop = (function(kd, val, dfltHighest){
    if(val){
      val = val.toLowerCase();
      var kdPattern = /([hl]?)([0-9]+)/i;
      var match = kdPattern.exec(val);
      if(match){
        if(!match[1] && dfltHighest){
          this.highestRolls = true;
        } else if(match[1] === 'h'){
          this.highestRolls = true;
        } else {
          this.lowestRolls = true;
        }
        //make sure the parsed amount of dice is a valid number
        var amt = parseInt(match[2], 10);
        if(isNaN(amt) || !amt){
          this.isValid = false;
        } else {
          this[kd] = amt;
        }
      } else {
        this.isValid = false;
      }
    } else {
      this.isValid = false;
    }
  }).bind(this);
  var parseReroll = (function(val){
    var rerollPattern = /([<>]?)([=]?)([0-9]+)/
    var match = rerollPattern.exec(val);
    if(match){
      var rolledValue = parseInt(match[3], 10);
      if(isNaN(rolledValue) || !rolledValue){
        this.isValid = false;
      } else {
        var thanEquals = false;
        if(match[2]){
          thanEquals = true;
        }
        if(match[1] === '<'){
          this.reroll.push(createLessThanReroll(rolledValue, thanEquals));
        } else if(match[1] === '>') {
          this.reroll.push(createGreaterThanReroll(rolledValue, thanEquals));
        } else {
          this.reroll.push(createBasicReroll(rolledValue));
        }
      }
    } else {
      this.isValid = false;
    }
  }).bind(this);
  while(optString){
    var match = optionPattern.exec(optString);
    if(match){
      var optType = match[1].toLowerCase();
      var optValue = match[2];
      switch(optType){
        case 'r':
          parseReroll(optValue);
          break;
        case 'k':
          if(this.keep || this.drop) this.isValid = false;
          this.keep = true;
          parseKeepDrop('keep', optValue, true);
          break;
        case 'd':
          if(this.keep || this.drop) this.isValid = false;
          this.drop = true;
          parseKeepDrop('drop', optValue, false);
          break;
      }
      //advance the string
      optString = optString.length > match[0].length ? optString.substr(match[0].length) : null;
    } else {
      //no more optionts to find
      optString = null;
    }
  }
  
  //cleanup
  parseKeepDrop = null;
  parseReroll = null;
  optionPattern = null;
  
  this.toString = function(){
    return options;
  };
}

module.exports = RollOptions;