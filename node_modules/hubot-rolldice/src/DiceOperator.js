function addition(left, right){
  return left + right;
}
function subtraction(left, right){
  var diff = left - right;
  return diff > 0 ? diff : 0;
}

function DiceOperator(op){
  this.operator = op;
  this.isValid = (op === '-' || op === '+');
  this.toString = function() { return ' ' + op + ' '; };
  this.delegate = addition;
  if(this.isValid){
    if(op==='-'){
      this.delegate = subtraction;
    }
  }
}

module.exports = DiceOperator;