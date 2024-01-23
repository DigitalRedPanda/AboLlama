from net import Socket, newSocket, send, recvLine
from os import sleep
from strutils import isEmptyOrWhitespace, split
from re import replace

type Client* = object
    token*, id*, displayName*: string
    socket*: Socket
type Event* = enum
    MessageEvent,
    CommandEvent,

template loop(body: untyped): void = 
    while true:
        body
proc sendMsg(socket: Socket, msg: string) = socket.send(msg & "\c\L")

func newClient*(userToken, userId, displayedName: string, userSocket = newSocket()): Client =
    return Client(token: userToken, id: userId,displayName: displayedName, socket: userSocket)

proc connectToChat*(client: Client) = 
    client.socket.sendMsg("PASS oauth:" & client.token & "\nNICK " & client.displayName)
   
proc sendChatMessage*(client: Client, channelName, message: string) = 
    client.socket.sendMsg("PRIVMSG #" & channelName & " :" & message)

proc on*(client: Client, event: Event, timeout: int, exec: proc(event: Event): void) = 
    loop:
        let message = client.socket.recvLine()
        echo message
        if not message.isEmptyOrWhitespace:
            let
                messageFeed = message.split(":") 
                identifiers = messageFeed[0].split(" ") 
            if identifiers[0] == "PING":
                client.socket.sendMsg("PONG :tmi.twitch.tv")
            else:
                case event:
                    of MessageEvent:
                        exec(event)
                    of CommandEvent:
                        exec(event)
        sleep(timeout)
