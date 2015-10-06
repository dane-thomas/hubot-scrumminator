CronJob = require('cron').CronJob
https = require('https')
Client = require('ftp')

class Scrum
    token = process.env.HUBOT_GITTER2_TOKEN
    id_count = 1

    constructor: (robot, time, room, id) ->
        that = this
        that._robot = robot
        that._room = room
        that._roomId = null
        that._time = time
        that._id = id
        that._scrumLog = []
        that._recentMessage = false

        that.cronJob = new CronJob(time, startScrum, null, true, null, this)

        options =
            hostname: 'api.gitter.im',
            port:     443,
            path:     '/v1/rooms/',
            method:   'GET',
            headers:  {'Authorization': 'Bearer ' + token}

        req = https.request(options, (res) ->
            output = ''
            res.on('data', (chunk) ->
                output += chunk.toString()
                )
            res.on('end', ->
                for entry in JSON.parse(output)
                    if entry.url == '/' + that._room
                        that._roomId = entry.id
                )
            )

        req.on('error', (e) ->
            that._robot.send e )

        req.end()

    startScrum = ->
        that = this
        that._robot.send
            room: that._room
            """Scrum time! Please provide answers to the following:
            1. What have you done since yesterday?
            2. What are you planning to do today?
            3. Do you have any blocks
            4. Any tasks to add to the Sprint Backlog? (If applicable)
            5. Have you learned or decided anything new? (If applicable)"""

        that._scrumLog['Room'] = that._room
        now = new Date()
        day = now.getDate()
        month = now.getMonth() + 1
        year = now.getFullYear()
        hour = now.getHours()
        minutes = now.getMinutes()
        that._scrumLog['Timestamp'] = day.toString() + '/' + month.toString() + '/' + year.toString + ' at ' +
            hour.toString() + ':' + minutes.toString()

        options =
            hostname: 'stream.gitter.im',
            port:     443,
            path:     '/v1/rooms/' + that._roomId + '/chatMessages',
            method:   'GET',
            headers:  {'Authorization': 'Bearer ' + token}


        req = https.request(options, (res) ->
            output = ''
            res.on('data', (chunk) ->
                    # ugly fix for split up chunks
                    if chunk.toString() != ' \n'
                        output += chunk.toString()
                        try
                            JSON.parse output
                        catch
                            console.log '... waiting on rest of response ...'
                            return
                        parseLog output
                        output = ''
                )
            )

        reqSocket = null
        req.on('socket', (socket) ->
            reqSocket = socket)

        req.on('error', (e) ->
            that._robot.send e )

        req.end()

        options2 =
            hostname: 'api.gitter.im',
            port:     443,
            path:     '/v1/rooms/' + that._roomId + '/users',
            method:   'GET',
            headers:  {'Authorization': 'Bearer ' + token}

        req2 = https.request(options2, (res) ->
            output = ''
            res.on('data', (chunk) ->
                output += chunk.toString()
                )
            res.on('end', ->
                for user in JSON.parse(output)
                    if user.username != 'ramp-pcar-bot'
                        that._scrumLog[user.username] = {
                            'username': user.username,
                            'displayName': user.displayName,
                            'answers': ['', '', '', '', '']
                        }
                )
            )
        req2.on('error', (e) ->
            that._robot.send e )

        req2.end()

        parseLog = (response) ->
            if (response == ' \n')
                return
            data = JSON.parse(response.toString())
            messages = data.text.split('\n')
            userid = data.fromUser.username
            displayname = data.fromUser.displayName

            answerPattern = /^([0-9])\.(.+)$/i

            for message in messages
                if userid != 'ramp-pcar-bot' && message.match answerPattern
                    that._recentMessage = true
                    num = answerPattern.exec(message)[1]
                    that._scrumLog[userid].answers[num-1] = message
                    that._robot.send
                        room: that._room
                        'Answer pattern matched'

        activityCheck = () ->
            if !that._recentMessage
                that.checkCronJob.stop()
                if reqSocket then reqSocket.end()
                ftpOptions = {
                    host: '69.89.25.92'
                    user: 'FGP'
                    password: 'FGPvizR2'
                }
                c = new Client()
                b = new Buffer(JSON.stringify(that._scrumLog))
                c.on 'ready', ->
                    c.put b, 'scrum.txt', (err) ->
                        if err
                            throw err
                        c.end
                c.connect ftpOptions
            that._recentMessage = false

        that.checkCronJob = new CronJob('*/30 * * * * *', activityCheck, null, true, null)

    cancelCronJob: ->
        this.cronJob.stop()

    toPrintable: ->
        this._id.toString() + ": " + this._room.toString() + " at " + this._time.toString()

    getId: ->
        this._id

    getLog: ->
        this._scrumLog

#   team: ->
#     new Team(@robot)
#
#   players: ->
#     @.team().players()
#
#   ##
#   # Get specific player by name
#   player: (name) ->
#     Player.find(@robot, name)
#
#   prompt: (player, message) ->
#     Player.dm(@robot, player.name, message)
#
#   demo: ->
#
#
#   # FIXME: This should take a player object
#   # and return the total points they have
#   # there are a few ways to do this:
#   #   - we just find the last scrum they participated
#   #     in copy it and add 10 points, this makes it hard
#   #     to account for bonus points earned for consecutive
#   #     days of particpating in the scrum
#   #   - we scan back and total up all their points ever, grouping
#   #     the consecutive ones and applying the appropriate bonus points
#   #     for those instances
#
#
#
#   # takes a player and a callback
#   # the callback is going to receive the score for the player
#   getScore: (player, fn) ->
#     client().zscore("scrum", player.name, (err, scoreFromRedis) ->
#       if scoreFromRedis
#         player.score = scoreFromRedis
#         fn(player)
#       else
#         console.log(
#           "getScoreError: didn't get a response got \' #{scoreFromRedis} \'\n" + "player was: #{player.name}"
#         )
#     )
#
#   # TODO: JP
#   # Fix me! maybe use promises here?
#   getScores: (players, fn) ->
#     for player in players
#       client().zscore("scrum", player.name, (err, scoreFromRedis) ->
#         if scoreFromRedis
#           player.score = scoreFromRedis
#         else
#           console.log(
#             "getScoreError: didn't get a response got \' #{scoreFromRedis} \'\n" + "player was: #{player.name}"
#           )
#       ).then(fn(players))
#
#   ##
#   # Just return a key for the current day ie 2015-4-5
#   date: ->
#     new Date().toJSON().slice(0,10)


module.exports = Scrum
