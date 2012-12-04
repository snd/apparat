# apparat

[![Build Status](https://travis-ci.org/snd/apparat.png)](https://travis-ci.org/snd/apparat)

apparat is a simple but powerful way to organize async code for nodejs

### install

    npm install apparat

### use

read domain from file `domain.txt`.

write resolved IPV4 addresses to `addresses4.txt` and
write resolved IPV6 addresses to `addresses6.txt` in parallel.

remove `domain.txt` when both files have been written successfully.

```coffeescript
fs = require 'fs'
dns = require 'dns'

apparat = require 'apparat'

{receive, send, onError, debug} = apparat

debug console.log
onError (err) -> throw err

fs.readFile 'domain.txt', send 'contents'

receive 'contents', (contents) ->
    domain = contents.toString().trim()
    # parallel
    dns.resolve4 domain, send 'addresses4'
    dns.resolve6 domain, send 'addresses6'

receive 'addresses4', (addresses) ->
    fs.writeFile 'addresses4.txt', addresses.join('\n'), send 'addresses4 written'

receive 'addresses6', (addresses) ->
    fs.writeFile 'addresses6.txt', addresses.join('\n'), send 'addresses6 written'

receive 'addresses4 written', 'addresses6 written', ->
    fs.unlink 'domain.txt', send 'deleted'

receive 'deleted', ->
    console.log 'OK'
```

#### license: MIT
