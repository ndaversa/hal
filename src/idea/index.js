/* Description:
 *  This allows the user to create an Idea ticket. It will prompt the user to answer a few more questions
 *  before creating the ticket in Jira
 *
 * Dependencies:
 *   - hubot-jira-bot
 *   - hubot-conversation
 *
 * Configuration:
 *   None
 *
 * Commands:
 *   hubot idea <idea summary>
 *
 * Author:
 *   orrie
 */

var Conversation, IdeaBot, Jira;

Jira = require( "../../node_modules/hubot-jira-bot/src/jira" );

Conversation = require( "hubot-conversation" );

IdeaBot = ( function() {
  function IdeaBot( robot ) {
    this.robot = robot;
    if ( !( this instanceof IdeaBot ) ) {
      return new IdeaBot( this.robot );
    }

    var quitRegex = new RegExp( "^(" + robot.name + " )?(x|n|q|quit|exit|stop)$" );
    var switchboard = new Conversation( this.robot );

    this.robot.respond( /(idea)\b(.*)/, function( idea ) {
      var dialog = switchboard.startDialog( idea, 300000 ); // After 5 minutes of inactivity the dialog will end

      idea.reply( "Neat idea! \n Before I can make a ticket I need to ask some more questions. Type 'q' at anytime to cancel creating the ticket." +
        "\n\n First up, what is the problem you're trying to solve?" );
      dialog.addChoice( quitRegex, cancelFunction );
      dialog.addChoice( /(.*)/, function( problem ) {
        problem.reply( "Great, who are you trying to solve this problem for?" )
        dialog.addChoice( quitRegex, cancelFunction );
        dialog.addChoice( /.*/, function( who ) {
          who.reply( "Alright, how will you determine success?" )
          dialog.addChoice( quitRegex, cancelFunction );
          dialog.addChoice( /.*/, function( success ) {
            success.reply( "Last question, what team is this most relevant to? (audience, storyteller, ads, growth, internal) " +
              "\n Don't worry if you get this wrong, make your best educated guess" );
            dialog.addChoice( /.*/, function( relevantTeam ) {
              relevantTeam.reply( "Ok, here's a summary of your idea: " +
                "\n Idea: " + idea.match[ 2 ] +
                "\n Problem: " + problem.message.text +
                "\n Who: " + who.message.text +
                "\n Success: " + success.message.text +
                "\n Team: " + relevantTeam.message.text +
                "\n \n Would you like me to create a Jira ticket for this idea? (y/n)"
              );
              dialog.addChoice( quitRegex, cancelFunction );
              dialog.addChoice( /(y|yes|ok)/, function( createTicket ) {
                createTicket.reply( "OK! Making ticket..." );
                var fields = {
                  "customfield_12301": problem.message.text,
                  "customfield_12700": who.message.text,
                  "customfield_12701": success.message.text,
                  "labels": [ relevantTeam.message.text ]
                }
                Jira.Create.with( "DISC", "Idea", idea.match[ 2 ], createTicket, fields ).then( function( ticket ) {
                  createTicket.reply( "Created ticket!" );
                } )
              } );
            } )

          } );
        } );

      } );
    } );

    var cancelFunction = function( cancel ) {
      cancel.reply( "I really though we had something there... :(" );
    }
  }

  return IdeaBot;

} )();

module.exports = IdeaBot;
