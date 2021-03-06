--TTT csm for 0.4.15 servers

--upvalues
local active = false
local ishost = false
local timer = false
local players = false
local name = false
local times = {300, 240, 180, 120, 60, 30, 20, 10, 5, 4, 3, 2, 1}

local roles = {"Dead", "\27(c@#0f0)Innocent\27(c@#fff)", "\27(c@#f00)Traitor\27(c@#fff)"}
local rolesPlural = {"Dead", "\27(c@#0f0)Innocent\27(c@#fff)", "\27(c@#f00)Traitors\27(c@#fff)"}

local on_receive = minetest.register_on_receiving_chat_message or minetest.register_on_receiving_chat_messages
local on_send = minetest.register_on_sending_chat_message or minetest.register_on_sending_chat_messages
local display_msg = minetest.display_chat_message
local send_msg = minetest.send_chat_message

local function shuffle(n, t)
	local tbl = {}
	for i = 1, n do
		if i <= t then
			tbl[i] = 3
		else
			tbl[i] = 2
		end
	end
	
	for i = n, 2, -1 do
		local j = math.random(1, i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

local client = {}
local host = {}

math.randomseed(os.time())
--end


--clientfunctions
client.revive = minetest.send_respawn

function client.show_form(form)
	minetest.show_formspec("ttt_csm", form)
end

function client.join()
	if ishost then
		host.join(name)
	else
		send_msg("ttthost join " .. name)
	end
end

function client.leave()
	if ishost then
		host.leave(name)
	else
		send_msg("ttthost leave " .. name)
	end
end

function client.die()
	client.show_form("")
	if ishost then
		host.die(name)
	else
		send_msg("ttthost die " .. name)
	end
end

function client.display_time(time)
	display_msg("TTT: " .. time .. "s left")
end

function client.display_win(role)
	role = tonumber(role)
	display_msg("TTT: The " .. rolesPlural[role] .. " have won")
	active = false
	client.revive()
end

function client.show_role(role)
	role = tonumber(role)
	display_msg("TTT: You are a " .. roles[role])
	active = true
end

function client.chat(val)
	local names, msg = string.match(val, "([^;]+);(.*)")
	if names and msg then
		names = names .. ""
		if string.match(names, "(" .. name .. ")%s?") then
			display_msg("TTT: " .. msg)
		end
	end
end
--end


--hostfunctions
function host.join(name)
	players[name] = 1
end

function host.leave(name)
	players[name] = nil
	if active then
		host.check_win()
	end
end

function host.chat(val, all)
	local sender, msg = string.match(val, "(%S+)%s(.*)")
	local srole = tonumber(players[sender])
	srole = all and srole > 1 and 2 or srole
	
	local msgs = {"ttt chat"}
	local i = 2
	for pn, role in pairs(players) do
		if srole == 1 then
			if players[pn] and players[pn] == 1 then
				if pn == name then
					display_msg("TTT: " .. msg)
				end
				msgs[i] = pn
				i = i + 1
			end
		elseif srole == 2 then
			if players[pn] and players[pn] > 1 then
				if pn == name then
					display_msg("TTT: " .. msg)
				end
				msgs[i] = pn
				i = i + 1
			end
		elseif srole == 3 then
			if players[pn] and players[pn] == 3 then
				if pn == name then
					display_msg("TTT: " .. msg)
				end
				msgs[i] = pn
				i = i + 1
			end
		else
			return
		end
	end
	send_msg("ttt chat " .. table.concat(msgs, " ") .. ";" .. msg)
end

function host.check_win()
	local c
	for _,role in pairs(players) do
		c = c or (role and role > 1 and role)
		if c and role and role > 1 and c ~= role then
			return
		end
	end
	host.win(c or 1)
end

function host.win(role)
	timer = false
	active = false
	client.display_win(role)
	send_msg("ttt win " .. role)
end

function host.revive(name)
	send_msg("ttt revive " .. name)
end

function host.start_match()
	local n = 0
	for _,_ in pairs(players) do
		n = n + 1
	end
	
	local roleDist = shuffle(n, math.ceil(n/5))
		
	local msgs = {"ttt roles"}
	local i = 1
	for pn,_ in pairs(players) do
		players[pn] = roleDist[i]
		if pn == name then
			client.show_role(roleDist[i])
		else
			msgs[i] = pn .. " " .. roleDist[i]
		end
		i = i + 1
	end
	
	timer = 360
	send_msg(table.concat(msgs, " "))
end

function host.die(name)
	players[name] = 1
	host.check_win()
end

function host.timer(dtime)
	for _, time in ipairs(times) do
		if timer - dtime <= time and timer > time then
			client.display_time(time)
			send_msg("ttt time " .. time)
			timer = timer - dtime
			return
		end
	end
	
	if timer - dtime <= 0 and timer > 0 then
		client.display_win(2)
		send_msg("ttt win 2")
		timer = timer - dtime
		return
	end
	
	timer = timer - dtime
end
--end

minetest.register_on_connect(function()
	name = minetest.localplayer:get_name()
end)

minetest.register_on_shutdown(function()
	if ishost then
		send_msg("ttt win 1")
	else
		send_msg("ttthost leave " .. name)
	end
end)

minetest.register_on_death(function()
	if active then
		if ishost then
			host.die(name)
		else
			send_msg("ttthost die " .. name)
		end
		client.show_form("field[chat;Chat;]")
	end
end)

minetest.register_on_formspec_input(function(formname, fields)
	if formname == "ttt_csm" and fields and fields.chat then
		if ishost then
			host.chat(name .. " " .. fields.chat)
		else
			send_msg("ttthost chat " .. name .. " " .. fields.chat)
		end
		client.show_form("field[chat;Chat;]")
	end
end)

minetest.register_globalstep(function(dtime)
	if ishost and active and timer then
		host.timer(dtime)
	end
end)

on_send(function(msg)
	if not msg then
		return
	end
	
	local ok, cmd, val = string.match(msg, "(ttt)%s(%S+)%s?(.*)")
	if ok then
		if cmd == "join" then
			if ishost then
				host.join(name)
			else
				client.join()
			end
		elseif cmd == "leave" then
			if ishost then
				host.leave(name)
			else
				client.leave()
			end
		elseif cmd == "chat" then
			if ishost then
				host.chat(name .. " " .. val)
			else
				send_msg("ttthost chat " .. name .. " " .. val)
			end
		end
		return true
	end
	
	local ok, cmd, val = string.match(msg, "(ttthost)%s(%S+)%s?(.*)")
	if ok then
		if ishost then
			if cmd == "start" then
				host.start_match()
			elseif cmd == "die" then
				host.die(val)
			elseif cmd == "win" then
				host.win(val)
			elseif cmd == "revive" then
				if val == name then
					client.revive()
				else
					host.revive(val)
				end
			elseif cmd == "leave" then
				host.leave(val)
			end
		end
		return true
	end
	
	if active then
		if ishost then
			host.chat(name .. " " .. val, true)
		else
			send_msg("ttthost chatall " .. name .. " " .. val)
		end
		return true
	end
end)

on_receive(function(msg)
	if not msg then
		return
	end
	
	local ok, cmd, val = string.match(msg, "(ttt)%s(%S+)%s?(.*)")
	if ok then
		if cmd == "chat" then
			client.chat(val)
		elseif cmd == "revive" and val and val == name then
			client.revive()
		elseif cmd == "win" then
			client.display_win(val)
		elseif cmd == "roles" then
			for pn, role in string.gmatch(val, "(%S+)%s(%d+)%s?") do
				if pn == name then
					client.show_role(role)
					return true
				end
			end
		elseif cmd == "time" then
			display_msg("TTT: " .. val .. "s left")
		end
		return true
	end
	
	local ok, cmd, val = string.match(msg, "(ttthost)%s(%S+)%s?(.*)")
	if ok then
		if ishost then
			if cmd == "chat" then
				host.chat(val)
			elseif cmd == "chatall" then
				host.chat(val, true)
			elseif cmd == "die" then
				host.die(val)
			elseif cmd == "leave" then
				host.leave(val)
			elseif cmd == "join" then
				host.join(val)
			end
		end
		return true
	end
	
	if active then
		return true
	end
end)

minetest.register_chatcommand("ttt_host", {
	func = function()
		if ishost then
			if active then
				send_msg("ttt win 1")
			end
			players = false
			timer = false
			send_msg("TTT: " .. name .. " is no longer host")
			display_msg("TTT: " .. name .. " is no longer host")
			ishost = false
		elseif not active then
			ishost = true
			players = {}
			send_msg("TTT: " .. name .. " is now host")
			display_msg("TTT: " .. name .. " is now host")
		end
	end
})

minetest.register_chatcommand("ttt_debug", {
	func = function()
		display_msg(dump(players or {}))
	end
})