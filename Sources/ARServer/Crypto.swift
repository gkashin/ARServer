//
//  Crypto.swift
//  ARServer
//
//  Created by Георгий Кашин on 25.01.2020.
//

import Cryptor

func password(from str: String, salt: String) throws -> String {
    let key = try PBKDF.deriveKey(fromPassword: str, salt: salt, prf: .sha512, rounds: 250_000, derivedKeyLength: 64)
    return CryptoUtils.hexString(from: key)
}
