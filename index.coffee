module.exports = class

    nextId: -> @_nextId++

    constructor: ->
        @_eventCallbacks = {}
        @_collections = {}
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
                    @_debug "[#{events.join ', '}] ------> ##{id}"
                    cb received...

        @_debug "##{id} is receiver for [#{events.join ', '}]"

    sendOne: (event) ->

        id = @nextId()

        called = false

        cb = (err, result) =>
            if @_failed
                @_debug "instance failed: not forwarding [#{event}]"
                return

            if called
                throw new Error "sender ##{id} called twice"
            called = true

            if @_eventCallbacks[event] is false
                throw new Error "[#{event}] already sent"

            if err?
                @_debug "##{id} ---[#{event} ✖]-->"
                @_failed = true
                if not @_onError?
                    throw new Error """
                        signal for "#{event}" failed with "#{err}"
                        but no onError callback was registered
                    """
                @_onError err
            else
                @_debug "##{id} ---[#{event} ✔]-->"
                callbacks = @_eventCallbacks[event]
                if not callbacks?
                    throw new Error """
                        "#{event}" was signalled
                        but no callbacks were found
                    """
                callbacks.forEach (cb) -> cb result
                # mark event as sent
                @_eventCallbacks[event] = false
                    # TODO nextTick??
        @_debug "##{id} is sender for [#{event}]"
        cb

    sendMany: (count, event) =>
        if count is 0
            callbacks = @_eventCallbacks[event]
            if not callbacks?
                throw new Error """
                    "#{event}" was signalled
                    but no callbacks were found
                """
            callbacks.forEach (cb) -> cb []
            # mark event as sent
            @_eventCallbacks[event] = false

        collection = @_collections[event]

        if collection?
            unless collection.expectedCount is count
                throw new Error """
                    trying to register collector for [#{event}]
                    with count #{count}, but another collector
                    with count #{collection.expectedCount}
                    is already registered
                """
        else
            @_collections[event] = collection =
                expectedCount: count
                collectorCount: 0
                collectedCount: 0
                collected: []

        if collection.expectedCount < collection.collectorCount
            throw new Error """
                trying to register collector for [#{event}]
                with count #{count}, but there are already
                #{collection.collectorCount} collectors
                registered
            """

        id = @nextId()

        collectorIndex = collection.collectorCount
        collection.collectorCount++
        called = false
        cb = (err, result) =>
            if @_failed
                @_debug "instance failed: not forwarding [#{event}]"
                return

            if called
                throw new Error "collector ##{id} called twice"

            called = true

            if @_eventCallbacks[event] is false
                throw new Error "[#{event}] already sent"

            if err?
                @_debug "##{id} ---[#{event} ✖]-->"
                @_failed = true
                if not @_onError?
                    throw new Error """
                        signal for "#{event}" failed with "#{err}"
                        but no onError callback was registered
                    """
                @_onError err
            else
                @_debug "##{id} ---[#{event} ✔]--> collected"
                collection.collected[collectorIndex] = result
                collection.collectedCount++

                if collection.collectedCount is collection.expectedCount

                    callbacks = @_eventCallbacks[event]
                    if not callbacks?
                        throw new Error """
                            "#{event}" was signalled
                            but no callbacks were found
                        """
                    callbacks.forEach (cb) -> cb collection.collected
                    # mark event as sent
                    @_eventCallbacks[event] = false
                        # TODO nextTick??

        @_debug "##{id} is collector #{collectorIndex} of #{count} for [#{event}]"
        cb

    send: (count, event) =>
        if not event?
            event = count
            count = null

        unless typeof event is 'string'
            throw new TypeError """
                event must be string
                but is #{typeof event}
            """

        if @_failed
            throw new Error """
                send called on failed instance
            """

        if @_eventCallbacks[event] is false
            throw new Error """
                [#{event}] trying to register sender but event was already sent
            """

        if count?
            @sendMany count, event
        else
            @sendOne event
