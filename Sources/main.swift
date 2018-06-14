//
//  main.swift
//  zeg_bot
//
//  Created by Shane Qi on 6/4/16.
//
//

import ZEGBot
import SQLite
import Foundation
import SwiftyJSON
import PerfectLib

let bot = ZEGBot(token: secret)
let plugin = ZEGBotPlugin(bot: bot)
let db = try! SQLite.init(
	in: dbPath,
	managing: [Post.self,
	           User.self])

var cuckoo = ""
var mode = 0
var lastJobsCheckingDay = 0

bot.run { update, bot in

	if case 1 = mode { print(update) }

	if let message = update.message {

		if let user = message.from {
			try? user.replace(into: db)
		}

		if let photo = message.photo?.last,
			let filePath = bot.getFile(ofId: photo.fileId)?.filePath {
			let fileUrl = "\"https://api.telegram.org/file/bot\(secret)/\(filePath)\""
			//var fileUrlBytes = [UInt8](fileUrl.utf8)
			var request = URLRequest(url: URL(string: "https://api.algorithmia.com/v1/algo/opencv/FaceDetectionBox/0.1.1")!)
			request.httpMethod = "POST"
			request.httpBody = fileUrl.data(using: .utf8)
			request.addValue("application/json", forHTTPHeaderField: "Content-Type")
			request.addValue("Simple \(algorithmiaApiKey)", forHTTPHeaderField: "Authorization")
			URLSession(configuration: .default).dataTask(with: request) { data, _, _ in
				guard let data = data else { return }
				let json = JSON(data: data)
				let hasFace = !json["result"].arrayValue.isEmpty
				var fileName = "\(message.messageId).jpg"
				var fileSaveRelativePath = "photos/"
				if hasFace { fileSaveRelativePath += "faces/" }
				let fileObsolutePath = filesPath + fileSaveRelativePath
				let dir = Dir(fileObsolutePath)
				do {
					if !dir.exists { try dir.create() }
					let file = PerfectLib.File(fileObsolutePath + fileName)
					let request = URLRequest(url: URL(string: "https://api.telegram.org/file/bot\(secret)/" + filePath)!)
					URLSession(configuration: .default).dataTask(with: request) { data, _, _ in
						do {
							guard let data = data else { return }
							try file.open(.readWrite, permissions: [.rwxUser, .rxGroup, .rxOther])
							let _ = try file.write(bytes: [UInt8](data))
							file.close()
							if hasFace { bot.send(message: "Gotcha!", to: message) }
							if let senderId = message.from?.id {
								let post = Post(uid: message.messageId,
								                content: fileSaveRelativePath + fileName,
								                senderId: senderId,
								                updatedAt: message.date,
								                parentUid: message.replyToMessage?.messageId,
								                type: .photo,
								                children: nil)
								try post.replace(into: db)
							}
						} catch(let error) {
							Log.error(message: "Failed to save file to \(fileObsolutePath + fileName), because \(error).")
						}
						}.resume()
				} catch(let error) {
					Log.error(message: "Failed to save file to \(fileObsolutePath + fileName), because \(error).")
				}
				}.resume()
		}

		if let senderId = message.from?.id,
			let text = message.text {
			let post = Post(uid: message.messageId,
			                content: text,
			                senderId: senderId,
			                updatedAt: message.date,
			                parentUid: message.replyToMessage?.messageId,
			                type: .text,
			                children: nil)
			do { try post.replace(into: db) } catch (let error) { print("error: \(error)") }
		}

		if let locationA = message.location,
			let locationB = message.replyToMessage?.location,
			let userB = message.replyToMessage?.from?.firstName {

			let distance = Int(plugin.distance(between: locationA, and: locationB))

			let _ = bot.send(message: "\(userB) is *\(distance)* miles away from you.", to: message)

		}

		if let text = message.text {

			var isCommand = true

			switch text.uppercased() {

				/* Rules go here (order sensitive). */
			case "/学长", "/学长@ZEG_BOT":
				plugin.smartReply(to: message, content: "눈_눈", type: .Text)

			case "/JOY", "/JOY@ZEG_BOT":
				plugin.smartReply(to: message, content: joy, type: .PhotoSize)

			case "/JAKE", "/JAKE@ZEG_BOT":
				plugin.smartReply(to: message, content: jake, type: .PhotoSize)

			case "/DUYAOO", "/DUYAOO@ZEG_BOT":
				plugin.smartReply(to: message, content: "哎呦喂，不得了了！妖妖灵！", type: .Text)

			case "/KR", "/KR@ZEG_BOT":
				plugin.smartReply(to: message, content: kr, type: .Sticker)

			case "#朝君ISTYPING":
				let _ = bot.send(sticker: cjtyping, to: message.chat)

			case "/WHOSYOURDADDY":
				guard message.from?.id == shane else { break }
				mode = (mode + 1) % 2
				if mode == 1 { print("Switched to dev mode.") }
				else { print("Switched to normal mode.") }

			default:
				isCommand = false
				break

			}

			if isCommand {

				cuckoo = ""

			} else if text == cuckoo {

				bot.send(message: "*\(text)*", to: message.chat, parseMode: .markdown)
				cuckoo = ""
				
			} else {
				
				cuckoo = text
				
			}
			
		}
		
	}
}
