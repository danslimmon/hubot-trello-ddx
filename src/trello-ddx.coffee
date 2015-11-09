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
#   ddx start <problem description> - Start a new DDx board (and update room topic)
#   ddx symptom <description> - Create a new DDx symptom
#   ddx hypo <description> - Create a new DDx hypothesis
#   ddx test <description> - Create a new DDx test
#   ddx falsify <hypo_id> [because <reason>] - Falsify a DDx hypothesis
#   ddx finish <test_id> - Mark a DDx test finished
#
# Author:
#   Dan Slimmon <dan.slimmon@gmail.com>

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

# brainKey returns a key under which to store brain data for this session
#
# `msg` should be a Response object (as passed to a robot.hear() callback)
brainKey = (msg) ->
  return "ddx_#{msg.envelope.room}"

# makeShortname returns a shortname with the given prefix and the given index
makeShortname = (prefix, ind) ->
  if ind < 10
    return "#{prefix}0#{ind}"
  return "#{prefix}#{ind}"

# startBoard creates a new DDx board and links to it in the chatroom topic
startBoard = (msg, problemDesc) ->
  msg.send "Starting DDx for issue '#{problemDesc}'..."
  ensureConfig msg.send
  boardName = "DDx: " + problemDesc
  board = null

  # 1. Create board
  trello.post "/1/boards", {
    name: boardName,
    idOrganization: process.env.HUBOT_DDX_ORGID,
    prefs_permissionLevel: "org",
    prefs_comments: "org"
  }, (err, data) ->
    if err
      console.log "Error creating DDx board: #{err}"
      msg.reply "Error creating DDx board: #{err}"
      return

    # 2. Add organization as board admin
    board = data
    trello.post "/1/board/#{board.id}/members/#{board.idOrganization}", {
      type: "admin"
    }, (err, data) ->
      if err
        console.log "Error making DDx board writable by the organization: #{err}"
        msg.reply "Error making DDx board writable by the organization: #{err}"
        return

      # 3. Retrieve initial list IDs
      trello.get "/1/boards/#{board.id}/lists", {}, (err, data) ->
        if err
          console.log "Error retreiving board's initial lists: #{err}"
          msg.reply "Error retreiving board's initial lists: #{err}"
          return

        # 4. Remove initial lists
        lists = data
        closeList = (listId, failure) ->
          trello.put "/1/lists/#{listId}/closed", {
            value: true
          }, (err, data) ->
            failure(err, data) if err
        closeFailureCb = (err, data) ->
          console.log "Error closing list: #{err}"
          msg.reply "Error closing list: #{err}"
        for list in lists
          closeList(list.id, closeFailureCb)

        # 5. Add DDx lists to board
        createList = (boardId, listName, listPos, failure, success) ->
          trello.post "/1/board/#{boardId}/lists", {
            name: listName,
            pos: listPos
          }, (err, data) ->
            if err
              failure(err, data)
            else
              success(err, data)
        createFailureCb = (err, data) ->
          console.log "Error creating list: #{err}"
          msg.reply "Error creating list: #{err}"
        ddxLists = {}
        createList board.id, "Symptoms", "bottom", createFailureCb, (err, data) ->
          ddxLists["Symptoms"] = {id: data.id, lastShortnameIndex: -1}
          createList board.id, "Hypotheses", "bottom", createFailureCb, (err, data) ->
            ddxLists["Hypotheses"] = {id: data.id, lastShortnameIndex: -1}
            createList board.id, "Tests", "bottom", createFailureCb, (err, data) ->
              ddxLists["Tests"] = {id: data.id, lastShortnameIndex: -1}
              # 6. Write board ID and list IDs to brain
              #
              # Brain entry has a key specific to the current room, and a value as follows:
              #
              # {
              #   boardId: <board ID>,
              #   lists: {
              #     Symptoms: {
              #       id: <symptom list ID>,
              #       lastShortnameIndex: <integer index of the most recent shortname>
              #     },
              #     Hypotheses: {
              #       id: <hypothesis list ID>,
              #       lastShortnameIndex: <integer index of the most recent shortname>
              #     },
              #     Tests: {
              #       id: <test list ID>,
              #       lastShortnameIndex: <integer index of the most recent shortname>
              #     }
              #   }
              # }
              brainEntry = {
                boardId: board.id,
                lists: ddxLists
              }
              msg.robot.brain.set brainKey(msg), brainEntry
              msg.robot.brain.save

              # 7. Report success
              msg.reply "Created DDx board: #{board.shortUrl}"
              msg.topic "[#{board.shortUrl}] #{problemDesc}"

# addSymptom creates a symptom on the active DDx board
addSymptom = (msg, sympDesc) ->
  ensureConfig msg.send
  brainEntry = msg.robot.brain.get(brainKey msg)
  list = brainEntry.lists.Symptoms
  if not list or not list.id
    msg.reply "Error: No 'Symptoms' list defined for the Trello board"

  brainEntry.lists.Symptoms.lastShortnameIndex += 1
  shortnameIndex = brainEntry.lists.Symptoms.lastShortnameIndex
  shortname = makeShortname "sy", shortnameIndex
  cardName = "[#{shortname}] #{sympDesc}"
  trello.post "/1/lists/#{list.id}/cards", {
    name: cardName,
    idList: list.id
  }, (err, data) ->
    if err
      console.log "Error creating the symptom '#{sympDesc}': #{err}"
      msg.reply "Error creating the symptom '#{sympDesc}': #{err}"
      return

    # Save to brain
    msg.robot.brain.set brainKey(msg), brainEntry
    msg.robot.brain.save

    # Report success
    msg.send "Created Symptom: #{cardName}"

# addHypo creates a hypothesis on the active DDx board
addHypo = (msg, hypoDesc) ->
  ensureConfig msg.send
  brainEntry = msg.robot.brain.get(brainKey msg)
  list = brainEntry.lists.Hypotheses
  if not list or not list.id
    msg.reply "Error: No 'Hypotheses' list defined for the Trello board"

  brainEntry.lists.Hypotheses.lastShortnameIndex += 1
  shortnameIndex = brainEntry.lists.Hypotheses.lastShortnameIndex
  shortname = makeShortname "hy", shortnameIndex
  cardName = "[#{shortname}] #{hypoDesc}"
  trello.post "/1/lists/#{list.id}/cards", {
    name: cardName,
    idList: list.id
  }, (err, data) ->
    if err
      console.log "Error creating the hypothesis '#{hypoDesc}': #{err}"
      msg.reply "Error creating the hypothesis '#{hypoDesc}': #{err}"
      return

    # Save to brain
    msg.robot.brain.set brainKey(msg), brainEntry
    msg.robot.brain.save

    # Report success
    msg.send "Created Hypothesis: #{cardName}"

# addTest creates a test on the active DDx board
addTest = (msg, testDesc) ->
  ensureConfig msg.send
  brainEntry = msg.robot.brain.get(brainKey msg)
  list = brainEntry.lists.Tests
  if not list or not list.id
    msg.reply "Error: No 'Tests' list defined for the Trello board"

  brainEntry.lists.Tests.lastShortnameIndex += 1
  shortnameIndex = brainEntry.lists.Tests.lastShortnameIndex
  shortname = makeShortname "te", shortnameIndex
  cardName = "[#{shortname}] #{testDesc}"
  trello.post "/1/lists/#{list.id}/cards", {
    name: cardName,
    idList: list.id
  }, (err, data) ->
    if err
      console.log "Error creating the test '#{testDesc}': #{err}"
      msg.reply "Error creating the test '#{testDesc}': #{err}"
      return

    # Save to brain
    msg.robot.brain.set brainKey(msg), brainEntry
    msg.robot.brain.save

    # Report success
    msg.send "Created Test: #{cardName}"

# labelAndDrop labels a card and moves it down the list until it hits other cards
# with the same label. This is the behavior when falsifying hypotheses and finishing
# tests.
labelAndDrop = (msg, shortName, reason, listName, labelName, successCb) ->
  ensureConfig msg.send
  brainEntry = msg.robot.brain.get(brainKey msg)
  list = brainEntry.lists[listName]
  if not list or not list.id
    msg.reply "Error: No '#{listName}' list defined for the Trello board"

  # 1. Retrieve the relevant card
  trello.get "/1/lists/#{list.id}/cards", {}, (err, data) ->
    if err
      console.log "Error retrieving cards: #{err}"
      msg.reply "Error retrieving cards: #{err}"
      return
    allCards = data
    matchingCards = (card for card in allCards when card["name"].match ///^\[#{shortName}\]///)
    if matchingCards.length < 1
      msg.reply "Error: found no card for '#{shortName}'"
      return
    if matchingCards.length > 1
      msg.reply "Error: found more than one card for '#{shortName}'"
      return
    cardToChange = matchingCards[0]

    # 2. Move the card down to where the labeled cards are
    destPos = null
    for card in allCards
      for label in card.labels
        if label.name == labelName
          destPos = card.pos - 1
          break
      break if destPos
    destPos = "bottom" if not destPos

    trello.put "/1/cards/#{cardToChange.id}/pos", {value: destPos}, (err, data) ->
      if err
        console.log "Error moving card: #{err}"
        msg.reply "Error moving card: #{err}"
        return

      # 3. Label the card
      trello.post "/1/cards/#{cardToChange.id}/labels", {
        color: 'blue',
        name: labelName
      }, (err, data) ->
        if err
          console.log "Error labeling card: #{err}"
          msg.reply "Error labeling card: #{err}"

        if reason
          trello.post "/1/cards/#{cardToChange.id}/actions/comments", {
            text: "#{msg.message.user.name} closed this card because #{reason}"
          }, (err, data) ->

        # 4. Call success callback
        return successCb cardToChange

# falsifyHypo falsifies a hypothesis, optionally adding a reason as a comment
falsifyHypo = (msg, hypoId, reason) ->
  labelAndDrop msg, hypoId, reason, "Hypotheses", "falsified", (card) ->
    msg.send "Falsified Hypothesis: #{card.name}"

# finishTest finishes a test
finishTest = (msg, testId) ->
  labelAndDrop msg, testId, null, "Tests", "finished", (card) ->
    msg.send "Finished Test: #{card.name}"

module.exports = (robot) ->
  # fetch our board data when the script is loaded
  ensureConfig console.log

  # Regexes match any unambiguous prefix of a command (e.g. "start" can be shortened
  # to "st" but not "s"
  #
  # 'ddx start': start a new DDX board
  robot.hear /ddx st.*? (.+)/i, (msg) ->
    ensureConfig msg.send
    return unless ensureConfig()
    startBoard msg, msg.match[1]

  # 'ddx symptom': add a symptom
  robot.hear /ddx sy.*? (.+)/i, (msg) ->
    addSymptom msg, msg.match[1]

  # 'ddx hypothesis': add a hypothesis
  robot.hear /ddx hy.*? (.+)/i, (msg) ->
    addHypo msg, msg.match[1]

  # 'ddx test': add a test
  robot.hear /ddx t.*? (.+)/i, (msg) ->
    addTest msg, msg.match[1]

  # 'ddx falsify': falsify a hypothesis
  robot.hear /ddx fa.*? ([a-z0-9]+)(?: (?:because|cause|cuz|bc|b\/c) (.*))?/i, (msg) ->
    falsifyHypo msg, msg.match[1], msg.match[2]

  # 'ddx finish': finish a test
  robot.hear /ddx fi.*? ([a-z0-9]+)/i, (msg) ->
    finishTest msg, msg.match[1]

  # 'ddx help': print a usage message
  robot.hear /ddx help/i, (msg) ->
    msg.reply "Here are all the commands for DDx."
    msg.send " *  ddx start <ProblemDescription>"
    msg.send " *  ddx symptom <SymptomDescription>"
    msg.send " *  ddx hypo <HypothesisDescription>"
    msg.send " *  ddx test <TestDescription>"
    msg.send " *  ddx falsify <HypothesisShortname>"
    msg.send " *  ddx finish <TestShortname>"
