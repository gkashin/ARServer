//
//  MySQLDatabase.swift
//  ARServer
//
//  Created by Георгий Кашин on 25.01.2020.
//

import MySQL

func connectToDatabase() throws -> (Database, Connection) {
    let mysql = try Database(
        host: "localhost",
        user: "aruser",
        password: "arpassword",
        database: "ardb"
    )
    
    let connection = try mysql.makeConnection()
    return (mysql, connection)
}
