import db_connector/db_sqlite
import "../twitch/user"

let connection = open("src/db/twitch.db","","","")

proc initDb*() = 
    connection.exec(sql"""
        CREATE TABLE IF NOT EXISTS channels(
            id INTEGER PRIMARY KEY,
            login VARCHAR UNIQUE NOT NULL,
            displayName VARCHAR UNIQUE NOT NULL
        );
    """)

proc getAllChannels*(): seq[User] =
    var temp = newSeq[User]()
    for i in connection.fastRows(sql("SELECT * FROM channels")):
       echo i 
    result = temp

proc insertChannel*(user: User) =  
    connection.exec(sql"INSERT INTO channels VALUES (?, ?, ?)", user.id, user.login, user.displayName)

proc deleteChannel*(user: User) = 
    connection.exec(sql"DELETE FROM channels WHERE id == ?", user.id)
