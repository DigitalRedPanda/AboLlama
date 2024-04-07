import db_connector/db_sqlite

let connection = open("","","","")

proc createTableIfNotExists(tableName: string) =  
