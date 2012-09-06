# Apparat

a simple yet powerful way to organize async code

#### Install

    npm install apparat

#### Usage Example

read domain from file `domain.txt`.
in parallel
write resolved IPV4 addresses to `addresses4.txt` and
write resolved IPV6 addresses to `addresses6.txt`.
remove `domain.txt` when both files have been written successfully.

```coffeescript
fs = require 'fs'
dns = require 'dns'

Apparat = require 'apparat'

{receive, send, onError, debug} = new Apparat

debug console.log
onError (err) -> throw err

fs.readFile 'domain.txt', send 'contents'

receive 'contents', (contents) ->
    domain = contents.toString().trim()
    # parallel
    dns.resolve4 domain, send 'addresses4'
    dns.resolve6 domain, send 'addresses6'

receive 'addresses4', (addresses) ->
    fs.writeFile 'adresses4.txt', addresses.join('\n'), send 'addresses4 written'

receive 'addresses6', (addresses) ->
    fs.writeFile 'adresses6.txt', addresses.join('\n'), send 'addresses6 written'

receive 'addresses4 written', 'addresses6 written', ->
    fs.unlink 'domain.txt', send 'deleted'

receive 'deleted', ->
    console.log 'OK'
```

#### License: MIT
