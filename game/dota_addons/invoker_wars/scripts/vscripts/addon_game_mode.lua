-- This is the entry-point to your game mode and should be used primarily to precache models/particles/sounds/etc
require("statcollection/init")
require('internal/util')
require('gamemode')

function Precache( context )

end

-- Create the game mode when we activate
function Activate()
  GameRules.GameMode = GameMode()
  GameRules.GameMode:_InitGameMode()
end