import net, re, strutils, os, threadpool

type Event* = object 
    message*, user*, channel*: string

type Client* = object
    id*, displayName*, token*: string
    socket: Socket

type Events* = enum 
    MessageEvent, CommandEvent

var addedEvents: array[2, proc(event:Event) {.gcsafe.}]

let 
    messagePattern = re"(^([:!]\w+){2}|\.tmi\.twitch\.tv)"
    pattern = re":(\w+|tmi.twitch.tv) \d{3}"


template loop(code: untyped): untyped =
    while true:
        code

template sendMsg(client: Client, message: string) = client.socket.send(message & "\c\L")

func newClient*(id, displayName, token: string, socket=newSocket()): Client = Client(id:id, displayName:displayName, token:token, socket:socket)

proc joinChannel*(client: Client, channel: string) =
    client.sendMsg("JOIN " & channel)

proc sendChannelMessage*(client: Client, channel, message: string) = client.sendMsg("PRIVMSG " & channel & " :" & message)

func skipIndexTil(array: seq[string], index: int): seq[string] = 
    var temp = newSeq[string](array.len - index)
    for i in index..array.len: temp.add(array)
    return temp

proc addEvent*(client: Client, event: Events, exec: proc(event: Event) {.gcsafe.}) = 
    case event:
        of MessageEvent: addedEvents[0] = exec
        of CommandEvent: addedEvents[1] = exec

proc listen(client: Client) =
    loop:
        let msg = client.socket.recvLine().replace(messagePattern)
        if not (msg.isEmptyOrWhitespace or msg.match(pattern)):
            let msgFeed = msg.split(" ")
            if msgFeed[0] == "PING":
                client.sendMsg(":tmi.twitch.tv PONG")
            elif msgFeed[1] == "JOIN":
                echo "joined \e[1m", msgFeed[2], "\e[0m"
            else: 
                let feed = msg.split(":")
                if feed[1][0] != '!':
                    addedEvents[0](Event(message:feed[1], user:msgFeed[0] , channel:msgFeed[2]))
                else: 
                    addedEvents[1](Event(message:feed[1], user:msgFeed[0] , channel:msgFeed[2]))
        sleep(10)
proc connectToChat*(client: Client) = 
    client.socket.connect("irc.chat.twitch.tv", Port(6667))
    client.sendMsg("PASS oauth:" & client.token & "\nNICK " & client.displayName)
    client.joinChannel("#" & client.displayName)
    client.listen()
