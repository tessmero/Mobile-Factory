---- Recreate the Data Network Table --
global.dataNetworkTable = {}

-- Check all Data Center --
for k, obj in pairs(global.dataCenterTable) do
	-- Create the new Data Network --
	obj.dataNetwork = DN:new(obj)
end
-- Check the Data Center MF --
if global.MF ~= nil and global.MF.dataCenter ~= nil then
	-- Create the new Data Network --
	global.MF.dataCenter.dataNetwork = DN:new(global.MF.dataCenter)
end