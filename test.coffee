Mesh = require './index'

module.exports =

    'single event':

        'error in mesh triggers callback that was passed to onError': (test) ->
            {receive, send, onError} = new Mesh
            onError (err) ->
                test.equal err, 'this-is-an-error'
                test.done()
            receive 'my-event', -> test.fail()
            send('my-event') 'this-is-an-error'

        'send triggers receive': (test) ->
            {receive, send, onError} = new Mesh
            onError -> test.fail()
            receive 'my-event', -> test.done()
            send('my-event')()

        'value passed to send is passed to receive': (test) ->
            {receive, send, onError} = new Mesh
            onError (err) -> test.fail()
            receive 'my-event', (result) ->
                test.equal result, 'my-result'
                test.done()
            send('my-event') null, 'my-result'

        "send doesn't trigger other events": (test) ->
            {receive, send, onError} = new Mesh
            onError -> test.fail()
            receive 'my-first-event', -> test.fail()
            receive 'my-second-event', -> test.done()
            receive 'my-third-event', -> test.fail()
            send('my-second-event')()

    'many events':

        'error is received by onError': (test) ->
            {receive, send, onError} = new Mesh
            onError (err) ->
                test.equal err, 'this-is-an-error'
                test.done()
            receive 'my-event', 'my-event-with-error', -> test.fail()
            send('my-event') null, 'my-result'
            send('my-event-with-error') 'this-is-an-error'

        'receive is triggered after both events have been send': (test) ->
            {receive, send, onError, debug} = new Mesh
            onError (err) -> test.fail()
            receive 'my-event', 'my-other-event', (result, otherResult) ->
                test.equal result, 'my-result'
                test.equal otherResult, 'my-other-result'
                test.done()
            process.nextTick ->
                send('my-event') null, 'my-result'
                process.nextTick ->
                    send('my-other-event') null, 'my-other-result'

        'events are received in the order they are defined': (test) ->
            {receive, send, onError, debug} = new Mesh
            onError (err) -> test.fail()
            debug console.log
            receive 'my-other-event', 'my-event', (otherResult, result) ->
                test.equal result, 'my-result'
                test.equal otherResult, 'my-other-result'
                test.done()
            process.nextTick ->
                send('my-event') null, 'my-result'
                process.nextTick ->
                    send('my-other-event') null, 'my-other-result'

    'collected events':

        'error is handled': (test) ->
            {receive, send, onError} = new Mesh
            onError (err) ->
                test.equal err, 'this-is-an-error'
                test.done()
            receive 'my-event', -> test.fail()
            send(10, 'my-event') 'this-is-an-error'

        "can't call collector twice": (test) ->
            {receive, send, onError} = new Mesh
            onError -> test.fail()
            receive 'my-event', -> test.fail()
            collector = send(3, 'my-event')
            collector()
            test.throws -> collector()
            test.done()

        'receive is not called on first of three collects': (test) ->
            {receive, send, onError} = new Mesh
            onError -> test.fail()
            receive 'my-event', -> test.fail()
            send(3, 'my-event') null, 'my-first-result'
            send(3, 'my-event') null, 'my-second-result'
            test.done()

        'receive is called': (test) ->
            {receive, send, onError} = new Mesh
            onError -> test.fail()
            receive 'my-event', (results) ->
                test.deepEqual results, [
                    'my-first-result'
                    'my-second-result'
                    'my-third-result'
                ]
            send(3, 'my-event') null, 'my-first-result'
            send(3, 'my-event') null, 'my-second-result'
            send(3, 'my-event') null, 'my-third-result'
            test.done()

        'keep order of collectors': (test) ->
            {receive, send, onError} = new Mesh
            onError -> test.fail()
            test.expect 1
            receive 'my-event', (results) ->
                test.deepEqual results, [
                    'my-first-result'
                    'my-second-result'
                    'my-third-result'
                ]
            firstCollector = send 3, 'my-event'
            secondCollector = send 3, 'my-event'
            thirdCollector = send 3, 'my-event'

            thirdCollector null, 'my-third-result'
            firstCollector null, 'my-first-result'
            secondCollector null, 'my-second-result'

            test.done()

        'send with 0 calls event immediately with empty array': (test) ->
            {receive, send, onError} = new Mesh
            onError -> test.fail()
            test.expect 1
            receive 'my-event', (results) ->
                test.deepEqual results, []

            send 0, 'my-event'

            test.done()

    'throw':

        'type error':

            'when an invalid error callback is registered': (test) ->
                {receive, send, onError} = new Mesh
                test.throws ->
                    onError 'this-should-be-a-function'
                test.done()

            'when an invalid receive callback is registered': (test) ->
                {receive, send, onError} = new Mesh
                test.throws ->
                    receive {}, -> test.fail()
                test.throws ->
                    receive 'my-event', {}
                test.done()

            'when an invalid send is registered': (test) ->
                {receive, send, onError} = new Mesh
                receive 'event', -> test.fail()
                test.throws -> send {}
                test.done()

        'error':

            'when send is called on event for which no callback was registered': (test) ->
                {receive, send} = new Mesh
                test.throws -> send('my-event') null, 'my-result'
                test.done()

            'on fail if no failure callback is registered': (test) ->
                {receive, send} = new Mesh
                receive 'my-event', -> test.fail()
                test.throws ->
                    send('my-event') 'error'
                test.done()

            'when receive is called on failed conduct': (test) ->
                {receive, send, onError} = new Mesh
                test.expect 2
                onError (err) ->
                    test.ok true
                    test.throws ->
                        receive 'my-other-event', -> test.fail()
                    test.done()
                receive 'my-event', -> test.fail()
                send('my-event') 'this is an error'

            'when event is send multiple times through the same sender': (test) ->
                {receive, send, onError} = new Mesh
                onError -> test.fail()
                test.expect 2
                receive 'my-event', (result) ->
                    test.equal result, 'my-result'
                sender = send 'my-event'
                sender null, 'my-result'
                test.throws -> sender null, 'my-result'
                test.done()

            'when event is send multiple times through different senders': (test) ->
                {receive, send, onError} = new Mesh
                onError -> test.fail()
                test.expect 2
                receive 'my-event', (result) ->
                    test.equal result, 'my-first-result'
                send('my-event') null, 'my-first-result'
                test.throws -> send('my-event') null, 'my-second-result'
                test.done()
