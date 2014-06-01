# Description:
#   Quizz in french.
#
# Commands:
#   hubot quizzfr - Start quizz in french
#   hubot score - Show quizz score

_ = require 'lodash'
fs = require 'fs'
path = require 'path'

class Question
  constructor: (@data, @room, @time) ->
    @answers = {}
    @_answerList = _.pick @data, (value, key) ->
      return key in ['1', '2', '3', '4']

  question:    -> "#{@data.question} (#{@time}s)"
  rightAnswer: -> "Answer: #{@data.response}:「#{@data[@data.response]}」"
  answerList:  ->
    result = []
    _.forIn @_answerList, (v, k) ->
      result.push "#{k}:「#{v}」"
    result.join(' ')

  getSolvers: ->
    @solvers = []
    for solver, answerIndex of @answers
      @solvers.push solver if answerIndex is "#{@data.response}"
    if @solvers.length is 0
      'No one found.'
    else
      "Winners: #{@solvers.join(', ')}"

module.exports = (robot) ->
  robot.brain.on 'loaded', =>
    robot.brain.data.quizzfr_score ||= {}

  currentQuestion = null

  robot.hear /^\s*[1-4]\s*$/, (msg) ->
    return unless currentQuestion?.room is msg.message.room
    answer = msg.message.text.trim()
    currentQuestion.answers[msg.message.user.name] = answer

  setQuiz = (msg, data, time) ->
    return msg.send 'Quizz already in progress...' if currentQuestion?

    currentQuestion = new Question(data, msg.message.room, time)
    msg.send currentQuestion.question()
    msg.send currentQuestion.answerList()
    setTimeout ->
      robot.messageRoom currentQuestion.room, currentQuestion.rightAnswer()
      robot.messageRoom currentQuestion.room, currentQuestion.getSolvers()
      for solver in currentQuestion.solvers
        robot.brain.data.quizzfr_score[solver] ||= 0
        robot.brain.data.quizzfr_score[solver] += 1
      currentQuestion = null
    , time * 1000

  robot.respond /QUIZZFR$/i, (msg) ->
    quizzPath = path.resolve __dirname, '../../data/quizzfr.json'
    try
      data = fs.readFileSync quizzPath, 'utf-8'
      if data
        quizz = JSON.parse(data)
    catch error
      console.log('Unable to read file', error) unless error.code is 'ENOENT'
    setQuiz(msg, _.sample(quizz), 30)

  robot.respond /SCORE$/i, (msg) ->
    robot.messageRoom msg.message.room, JSON.stringify(robot.brain.data.quizzfr_score)
