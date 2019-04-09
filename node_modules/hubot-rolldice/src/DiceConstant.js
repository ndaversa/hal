function DiceConstant(val){
  this.results = {
    total: 0
  }
  this.isValid = true;
  this.toString = function(){ return '' + this.results.total; };
  var nval = parseInt(val, 10);
  if(isNaN(nval)){
    this.isValid = false;
  } else {
    this.results.total = nval;
  }
}

module.exports = DiceConstant;