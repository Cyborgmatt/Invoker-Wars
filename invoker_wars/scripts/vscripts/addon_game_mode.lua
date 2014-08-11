-- Varibles
MAX_KILLS = 50
THINK_TIME = 0.1

if InvokerWars == nil then
	InvokerWars = class({})
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = InvokerWars()
	GameRules.AddonTemplate:InitGameMode()
end

function InvokerWars:InitGameMode()
	print( "[Invoker Wars] Gamemode is initialising." )

    -- Set GameMode parameters
    GameMode = GameRules:GetGameModeEntity()    
    -- Override the normal camera distance.  Usual is 1134
    GameMode:SetCameraDistanceOverride( 1404.0 )
    -- Disable buyback
    GameMode:SetBuybackEnabled( false )
    -- Override the top bar values to show your own settings instead of total deaths
    GameMode:SetTopBarTeamValuesOverride ( true )

	-- Setup rules
	GameRules:SetHeroRespawnEnabled( false )
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetSameHeroSelectionEnabled( true )
	GameRules:SetHeroSelectionTime( 15.0 )
	GameRules:SetPreGameTime( 30.0)
	GameRules:SetPostGameTime( 30.0 )
	print( "[Invoker Wars] Gamemode rules are set." )

	-- Init self
	InvokerWars = self
	-- Timers
	self.timers = {}
	--Score
	self.scoreDire = 0
	self.scoreRadiant = 0
	self.kills_to_win = 50

	-- Register Think
	GameMode:SetContextThink("InvokerWarsThink", Dynamic_Wrap( InvokerWars, 'Think' ), THINK_TIME )

	-- Register Game Events
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap( InvokerWars, "OnGameRulesStateChange" ), self )
	ListenToGameEvent('entity_killed', Dynamic_Wrap(InvokerWars, 'OnEntityKilled'), self )
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(InvokerWars, 'OnNPCSpawned'), self )
end

-- Pregame welcome message
function InvokerWars:OnGameRulesStateChange()
	local nNewState = GameRules:State_Get()
	if nNewState == DOTA_GAMERULES_STATE_PRE_GAME then
		print( "[Invoker Wars] Gamemode is running." )
		ShowGenericPopup( "#invokerwars_instructions_title", "#invokerwars_instructions_body", "", "", DOTA_SHOWGENERICPOPUP_TINT_SCREEN )
	end
end

-- Show a message to all players
function InvokerWars:ShowCenterMessage( msg, dur )
	local msg = {
	message = msg,
	duration = dur
}
print( "[Invoker Wars] Sending message to all clients." )
FireGameEvent("show_center_message",msg)
end

-- Start players at level 6
function InvokerWars:OnNPCSpawned( keys )
	print ( '[InvokerWars] OnNPCSpawned' )
	local spawnedUnit = EntIndexToHScript( keys.entindex )
	if not spawnedUnit:IsIllusion() and spawnedUnit:IsHero() then
		local level = spawnedUnit:GetLevel()
		while level < 6 do
			spawnedUnit:AddExperience (2000,false)
			level = spawnedUnit:GetLevel()
		end
	end
end

-- Think and timers
function InvokerWars:Think()
  -- If the game's over, it's over.
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
  	return
  end

  -- Track game time, since the dt passed in to think is actually wall-clock time not simulation time.
  local now = GameRules:GetGameTime()
  --print("now: " .. now)
  if InvokerWars.t0 == nil then
  	InvokerWars.t0 = now
  end
  local dt = now - InvokerWars.t0
  InvokerWars.t0 = now

  -- Process timers
  for k,v in pairs(InvokerWars.timers) do
  	local bUseGameTime = false
  	if v.useGameTime and v.useGameTime == true then
  		bUseGameTime = true;
  	end
    -- Check if the timer has finished
    if (bUseGameTime and GameRules:GetGameTime() > v.endTime) or (not bUseGameTime and Time() > v.endTime) then
      -- Remove from timers list
      InvokerWars.timers[k] = nil

      -- Run the callback
      local status, nextCall = pcall(v.callback, InvokerWars, v)

      -- Make sure it worked
      if status then
        -- Check if it needs to loop
        if nextCall then
          -- Change it's end time
          v.endTime = nextCall
          InvokerWars.timers[k] = v
      end

  else
        -- Nope, handle the error
        InvokerWars:HandleEventError('Timer', k, nextCall, v)
    end
end
end

return THINK_TIME
end

function InvokerWars:HandleEventError(name, event, err, v)
  -- This gets fired when an event throws an error

  -- Log to console
  print(err)

  -- Ensure we have data
  name = tostring(name or 'unknown')
  event = tostring(event or 'unknown')
  err = tostring(err or 'unknown')

  -- Tell everyone there was an error
  Say(nil, name .. ' threw an error on event '..event, false)
  Say(nil, err, false)

  if v.errorcallback then
    v.errorcallback() -- call the errorcallback specified by the timer
end

  -- Prevent loop arounds
  if not self.errorHandled then
    -- Store that we handled an error
    self.errorHandled = true
end
end

function InvokerWars:CreateTimer(name, args)
  --[[
  args: {
  endTime = Time you want this timer to end: Time() + 30 (for 30 seconds from now),
  useGameTime = use Game Time instead of Time()
  callback = function(frota, args) to run when this timer expires,
  text = text to display to clients,
  send = set this to true if you want clients to get this,
  persist = bool: Should we keep this timer even if the match ends?
  }

  If you want your timer to loop, simply return the time of the next callback inside of your callback, for example:

  callback = function()
  return Time() + 30 -- Will fire again in 30 seconds
  end
  ]]

  if not args.endTime or not args.callback then
  print("Invalid timer created: "..name)
  return
end

  -- Store the timer
  self.timers[name] = args
end

function InvokerWars:RemoveTimer(name)
  -- Remove this timer
  self.timers[name] = nil
end

function InvokerWars:RemoveTimers(killAll)
	local timers = {}

  -- If we shouldn't kill all timers
  if not killAll then
    -- Loop over all timers
    for k,v in pairs(self.timers) do
      -- Check if it is persistant
      if v.persist then
        -- Add it to our new timer list
        timers[k] = v
    end
end
end

  -- Store the new batch of timers
  self.timers = timers
end

function InvokerWars:OnEntityKilled( keys )
	local killedUnit = EntIndexToHScript( keys.entindex_killed )
	local killerEntity = nil
	if keys.entindex_attacker == nil then
		return
	end

	killerEntity = EntIndexToHScript( keys.entindex_attacker )
	local killedTeam = killedUnit:GetTeam()
	local killerTeam = killerEntity:GetTeam()

	if killedUnit:IsRealHero() == true then
		local death_count_down = 5
		killedUnit:SetTimeUntilRespawn(death_count_down)

		InvokerWars:CreateTimer(DoUniqueString("respawn"), {
			endTime = GameRules:GetGameTime() + 1,
			useGameTime = true,
			callback = function(reflex, args)
			death_count_down = death_count_down - 1
			if death_count_down == 0 then
          --Respawn hero after 5 seconds
          killedUnit:RespawnHero(false,false,false)
          return
      else
      	killedUnit:SetTimeUntilRespawn(death_count_down)
      	return GameRules:GetGameTime() + 1
      end
  end
  })

	-- Display 10 kills remaining message
	if self.scoreRadiant == 40 then
		InvokerWars:ShowCenterMessage("#invokerwars_radiant_10kills",6)
	end
	if self.scoreDire == 40 then
		InvokerWars:ShowCenterMessage("#invokerwars_dire_10kills",6)
	end

	-- Add on the kill
	if killedTeam == DOTA_TEAM_BADGUYS then
		if killerTeam == 2 then
			self.scoreRadiant = self.scoreRadiant + 1
		end
		elseif killedTeam == DOTA_TEAM_GOODGUYS then
			if killerTeam == 3 then
				self.scoreDire = self.scoreDire + 1
			end
		end

	-- Set the custom score values
	GameMode:SetTopBarTeamValue ( DOTA_TEAM_BADGUYS, self.scoreDire)
	GameMode:SetTopBarTeamValue ( DOTA_TEAM_GOODGUYS, self.scoreRadiant )

	-- Victory checking
	if self.scoreDire >= self.kills_to_win then
		GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
		GameRules:MakeTeamLose(DOTA_TEAM_GOODGUYS)
		GameRules:Defeated()
	end
	if self.scoreRadiant >= self.kills_to_win  then
		GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		GameRules:MakeTeamLose(DOTA_TEAM_BADGUYS)
		GameRules:Defeated()
	end
end
end