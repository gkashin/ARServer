//
//  Roots.swift
//  ARServer
//
//  Created by Георгий Кашин on 25.01.2020.
//

import Foundation
import Kitura
import KituraNet
import HeliumLogger
import LoggerAPI

func initRoots() {
    router.post("/", middleware: BodyParser())
    
    router.get("/:password/:salt") { request, response, next in
        defer { next() }
        
        guard let str = request.parameters["password"],
            let salt = request.parameters["salt"] else { return }
        
        guard let pass = try? password(from: str, salt: salt) else { return }
        
        Log.debug("\(pass)")
    }
    
    router.get("/:user/objects") { request, response, next in
        defer { next() }
        
        // Find out which user name is passed
        guard let user = request.parameters["user"] else { return }
        
        // Connect to MySQL
        let (database, connection) = try connectToDatabase()
        
        // Query a query string
        let query = "select id, user, url, date from objects where user = ? order by date desc;"
        
        // Merge query string with a user parameter
        let objects = try database.execute(query, [user], connection)
        
        // Convert result into dictionaries
        var parsedObjects = [[String: Any]]()
        
        for object in objects {
            var objectDictionary = [String: Any]()
            objectDictionary["id"] = object["id"]?.int
            objectDictionary["user"] = object["user"]?.string
            objectDictionary["url"] = object["url"]?.string
            objectDictionary["date"] = object["date"]?.string
            parsedObjects.append(objectDictionary)
        }
        
        var result = [String: Any]()
        result["status"] = "ok"
        result["objects"] = parsedObjects
        
        do {
            try response.status(.OK).send(json: result).end()
        } catch {
            Log.warning("Could not send /:user/objects for \(user): \(error.localizedDescription)")
        }
    }
    
    router.post("/login") { request, response, next in
        defer { next() }
        
        // Make sure that "username" and "password" fields were passed
        guard let fields = getPost(for: request, fields: ["username", "password"]) else {
            send(error: "Missing required fields", code: .badRequest, to: response)
            return
        }
        
        Log.debug("\(fields)")
        
        // Connect to MySQL
        let (database, connection) = try connectToDatabase()
        
        // Get the password and salt for the user
        let query = "select password, salt from users where id = ?;"
        let users = try database.execute(query, [fields["username"]!], connection)
        
        Log.debug("users = \(users)")
        
        // Check if at least one user exists
        guard let user = users.first else { return }
        
        // Get both bales from MySQL result
        guard let savedPassword = user["password"]?.string else { return }
        guard let savedSalt = user["salt"]?.string else { return }
        
        Log.debug("savedPassword = \(savedPassword), savedSalt = \(savedSalt)")
        
        // Use the saved salt to create a hash from submitted password
        guard let testPassword = try? password(from: fields["password"]!, salt: savedSalt) else { return }
        
        Log.debug("testPassword = \(testPassword)")
        
        // Check if hashes are correct
        if savedPassword == testPassword {
            // success — clear out any expired tokens
            try database.execute("delete from tokens where expiry < now();", [], connection)
            
            // generate a new random string for this token
            let token = UUID().uuidString
            
            // add token to our database with username and expired date
            try database.execute(
                "insert into tokens value (?, ?, date_add(now(), interval 1 day));",
                [token, fields["username"]!],
                connection
            )
            
            // send the token back to the user
            var result = [String: Any]()
            result["status"] = "ok"
            result["token"] = token
            
            do {
                try response.status(.OK).send(json: result).end()
            } catch {
                Log.warning("Failed to send /login for \(user): \(error.localizedDescription)")
            }
        }
    }
}
