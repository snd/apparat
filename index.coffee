Apparat = class

    nextId: -> @_nextId++

    constructor: ->
        @_eventCallbacks = {}
        @_failed = false
        @_nextId = 1

    debug: (@_debugCallback) =>
        @_debugCallback 'debugCallback registered'

    _debug: (message) =>
        if @_debugCallback?
            @_debugCallback message

    onError: (onError) =>
        unless typeof onError is 'function'
            throw new TypeError """
                first argument must be a function"
                but is #{typeof onError}
            """
        @_onError = onError
        @_debug 'onError callback registered'

    receive: (args...) =>

        # preconditions

        if @_failed
            throw new Error """
                receive called on failed instance
            """

        argc = args.length

        if argc < 2
            throw new Error "at least two arguments are required"

        cb = args[argc-1]
        unless typeof cb is 'function'
            throw new TypeError """
                last argument must be function
                but is #{typeof cb}
            """
        events = args[0...argc-1]
        events.forEach (event, index) ->
            unless typeof event is 'string'
                throw new TypeError """
                    event argument #{index} must be string
                    but is #{typeof event}
                """

        id = @nextId()

        received = []
        receivedCount = 0
        events.forEach (event, index) =>
            @_eventCallbacks[event] ?= []
            @_eventCallbacks[event].push (result) =>
                received[index] = result
                receivedCount++
                if receivedCount is events.length
                    @_debug "##{id} receiving [#{events.join ', '}]"
                    cb received...

        @_debug "##{id} receiver for [#{events.join ', '}]"

    send: (event) =>
        unless typeof event is 'string'
            throw new TypeError """
                event must be string
                but is #{typeof event}
            """

        if @_failed
            throw new Error """
                send called on failed apparat
            """

        if @_eventCallbacks[event] is false
            throw new Error """
                [#{event}] trying to register sender but event was already sent
            """

        id = @nextId()

        called = false

        cb = (err, result) =>
            if @_failed
                @_debug "failed apparat: not forwarding [#{event}]"
                return

            if called
                throw new Error "sender ##{id} called twice"
            called = true

            if @_eventCallbacks[event] is false
                throw new Error "[#{event}] already sent"

            if err?
                @_debug "##{id} sending [#{event}] ✖"
                @_failed = true
                if not @_onError?
                    throw new Error """
                        send for "#{event}" failed with "#{err}"
                        but no onError callback was registered
                    """
                @_onError err
            else
                @_debug "##{id} sending [#{event}] ✔"
                callbacks = @_eventCallbacks[event]
                if not callbacks?
                    throw new Error """
                        "#{event}" was sent
                        but no callbacks were found
                    """
                callbacks.forEach (cb) -> cb result
                # mark event as sent
                @_eventCallbacks[event] = false
                    # TODO nextTick??
        @_debug "##{id} sender for [#{event}]"

        return cb

module.exports = -> new Apparat
