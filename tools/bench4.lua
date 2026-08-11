local addon = dofile("run.lua")
addon:EnsureDB()

-- 120 BNet-друзів × 2 ігрові акаунти + 40 у застарілому списку
local FRIENDS, ACCTS = 120, 2
local calls = 0
C_FriendList = {
  GetNumFriends = function() calls=calls+1; return 40 end,
  GetFriendInfoByIndex = function(i) calls=calls+1; return { name = "Legacy"..i.."-Realm" } end,
  IsLegacyFriendSystemEnabled = function() return true end,
}
C_BattleNet = {
  GetNumFriends = function() calls=calls+1; return FRIENDS end,
  GetFriendNumGameAccounts = function() calls=calls+1; return ACCTS end,
  GetFriendGameAccountInfo = function(i,j) calls=calls+1; return { characterName = "Bnet"..i.."_"..j } end,
  IsBattleNetFriendsListEnabled = function() return true end,
}
C_SocialRestrictions = { IsFriendsDisabled = function() return false end }

local function burst(n)
  calls = 0
  for _ = 1, n do
    addon:InvalidateSocialCaches()
    addon:RebuildFriendCache(false)
  end
  return calls
end

-- стара поведінка: примусова перебудова на кожну подію
calls = 0
for _ = 1, 50 do addon:RebuildFriendCache(true) end
local old = calls

-- нова: 50 подій підряд, потім один реальний запит
addon:InvalidateSocialCaches()
calls = 0
for _ = 1, 50 do addon:InvalidateSocialCaches() end
addon:RebuildFriendCache(false)
local new = calls

print_orig(string.format("50 подій BN_FRIEND_INFO_CHANGED:"))
print_orig(string.format("  було: %d викликів API", old))
print_orig(string.format("  стало: %d викликів API (%.0fx менше)", new, old/math.max(new,1)))

-- система друзів вимкнена (12.1)
C_SocialRestrictions.IsFriendsDisabled = function() return true end
addon:InvalidateSocialCaches(); calls = 0
addon:RebuildFriendCache(true)
print_orig(string.format("система друзів вимкнена -> %d викликів API", calls))
