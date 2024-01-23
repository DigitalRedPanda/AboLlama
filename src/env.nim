from strutils import split
from tables import `[]=`, TableRef, newTable

proc loadEnv*(file: string): TableRef[string,string] =
    let temp = newTable[string,string]()
    for line in file.lines:
        let property = line.split("=")
        temp[property[0]]=property[1]
    return temp
