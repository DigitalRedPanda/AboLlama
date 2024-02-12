from net import Socket, newSocket, send, recvLine, connect, Port
from os import sleep
from strutils import isEmptyOrWhitespace, split
import re

type Client* = object
    token*, id*, displayName*: string
    socket*: Socket

type Event* = enum
    MessageEvent,
    CommandEvent,

let 
    messagePattern = re"(^([:!]\w+){2}|\.tmi\.twitch\.tv)"
    pattern = re"^:tmi\.twitch\.tv \d{3}"

template loop(body: untyped): void = 
    while true:
        body
proc sendMsg*(socket: Socket, msg: string) = socket.send(msg & "\r\n")

func newClient*(userToken, userId, displayedName: string, userSocket = newSocket()): Client =
    return Client(token: userToken, id: userId, displayName: displayedName, socket: userSocket)

proc joinChannel*(client: Client, channel: string) =
    client.socket.sendMsg("JOIN #" & channel)

proc connectToChat*(client: Client) = 
    client.socket.connect("irc.chat.twitch.tv", Port(6667))
    client.socket.sendMsg("PASS oauth:" & client.token & "\nNICK " & client.displayName)
    client.joinChannel(client.displayName)

proc sendChatMessage*(client: Client, channelName, message: string) = 
    client.socket.sendMsg("PRIVMSG #" & channelName & " :" & message)

proc on*(client: Client, event: Event, timeout: int, exec: proc(channel, user, message: string): void) =  
    loop:
        let message = client.socket.recvLine().replace(messagePattern)
        try:
            if not (message.isEmptyOrWhitespace or message.match(pattern)):
                let identifiers = message.split(" ") 
                if identifiers[0] == "PING":
                    client.socket.sendMsg("PONG :tmi.twitch.tv")
                elif identifiers[1] == "JOIN":
                    stdout.writeLine "joined \e[1m" & identifiers[2] & "\e[0m"
                else:
                    let messageFeed = message.split(":") 
                    case event:
                        of MessageEvent:
                          if messageFeed[1][0] != '!':
                            exec(channel=identifiers[2], user=identifiers[0], message=messageFeed[1])
                        of CommandEvent:
                          if messageFeed[1][0] == '!':
                            exec(channel=identifiers[2], user=identifiers[0], message=messageFeed[1])
        except:
            stdout.writeLine("[\e[1;31mERROR\e[0m] message `\e[1m" & message & "\e[0m` have raised `\e[1m" & getCurrentExceptionMsg() & "\e[0m`")
        sleep(timeout)
