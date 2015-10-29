# Description:
#   Manage your Trello differential diagnosis boards from Hubot
#
#   (based on https://github.com/hubot-scripts/hubot-trello by Jared Barboza)
#
# Dependencies:
#   "node-trello-ddx": "latest"
#
# Configuration:
#   HUBOT_DDX_KEY - Trello application key
#   HUBOT_DDX_TOKEN - Trello API token
#
# Commands:
#   hubot ddx start <problem description> - Start a new DDx board (and update room topic)
#   hubot ddx link - Echo a link to the actie DDx board
#   hubot ddx symptom <description> - Create a new DDx symptom
#   hubot ddx hypo <description> - Create a new DDx hypothesis
#   hubot ddx test <description> - Create a new DDx test
#   hubot ddx falsify <hypo_id> - Falsify a DDx hypothesis
#   hubot ddx finish <test_id> - Mark a DDx test finished
#
# Author:
#   Dan Slimmon <dan.slimmon@exosite.com>

Trello = require 'node-trello'

trello = new Trello process.env.HUBOT_DDX_KEY, process.env.HUBOT_DDX_TOKEN, process.env.HUBOT_DDX_ORGID

# verify that all the environment vars are available
ensureConfig = (out) ->
  out "Error: Trello app key is not specified" if not process.env.HUBOT_DDX_KEY
  out "Error: Trello token is not specified" if not process.env.HUBOT_DDX_TOKEN
  out "Error: Trello org ID is not specified" if not process.env.HUBOT_DDX_ORGID
  return false unless (process.env.HUBOT_DDX_KEY and process.env.HUBOT_DDX_TOKEN and process.env.HUBOT_DDX_ORGID)
  true

##############################
# API Methods
##############################

startBoard = (msg, problem_desc) ->
  msg.reply "Starting DDx..."
  ensureConfig msg.send
  boardName = "DDx: " + problem_desc
  trello.post "/1/boards", {
    name: boardName,
    idOrganization: process.env.HUBOT_DDX_ORGID,
    prefs_permission_level: "org",
    prefs_comments: "org"
  }

createCard = (msg, list_name, cardName) ->
  msg.reply "Sure thing boss. I'll create that card for you."
  ensureConfig msg.send
  id = lists[list_name.toLowerCase()].id
  trello.post "/1/cards", {name: cardName, idList: id}, (err, data) ->
    msg.reply "There was an error creating the card" if err
    msg.reply "OK, I created that card for you. You can see it here: #{data.url}" unless err

moveCard = (msg, card_id, list_name) ->
  ensureConfig msg.send
  id = lists[list_name.toLowerCase()].id
  msg.reply "I couldn't find a list named: #{list_name}." unless id
  if id
    trello.put "/1/cards/#{card_id}/idList", {value: id}, (err, data) ->
      msg.reply "Sorry boss, I couldn't move that card after all." if err
      msg.reply "Yep, ok, I moved that card to #{list_name}." unless err

module.exports = (robot) ->
  # fetch our board data when the script is loaded
  ensureConfig console.log

  robot.respond /ddx start (.+)/i, (msg) ->
    ensureConfig msg.send
    problem_desc = msg.match[1]

    if problem_desc.length == 0
      msg.reply "You must give a description of the problem you're diagnosing"
      return

    return unless ensureConfig()

    startBoard msg, problem_desc

  robot.respond /trello list ["'](.+)["']/i, (msg) ->
    showCards msg, msg.match[1]

  robot.respond /trello move (\w+) ["'](.+)["']/i, (msg) ->
    moveCard msg, msg.match[1], msg.match[2]

  robot.respond /trello list lists/i, (msg) ->
    msg.reply "Here are all the lists on your board."
    Object.keys(lists).forEach (key) ->
      msg.send " * " + key

  robot.respond /trello help/i, (msg) ->
    msg.reply "Here are all the commands for me."
    msg.send " *  trello new \"<ListName>\" <TaskName>"
    msg.send " *  trello list \"<ListName>\""
    msg.send " *  shows * [<card.shortLink>] <card.name> - <card.shortUrl>"
    msg.send " *  trello move <card.shortlink> \"<ListName>\""
    msg.send " *  trello list lists"

