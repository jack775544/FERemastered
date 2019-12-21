print("Loading _FECore.lua");
--===================================================
-- Forgotten Enemies Core Helper Lua.
-- Written by General BlackDragon.
-- Links all the individual Lua Moduels together.
--===================================================

-- Key Asset/Require Loader. -- Already in root ODFs.
--assert(load(assert(LoadFile("_requirefix.lua")),"_requirefix.lua"))();

-- Helper Luas.
require('_GlobalHandler');
require('_GlobalVariables');
require('_DLLUtils');
local _MapReloader = require('_MapReloader');
local _PropHeightFix = require('_PropHeightFix');

-- FE Moduels.
--require('_PortalHelper');
--require('_DispatchHelper');
--require('_AttacherHelper');
--require('_AIWeaponHelper');
--require('_CarrierHelper');


local _FECore = {}

-- Core game functions.
function _FECore.InitialSetup()

-- Call helper functions.

	_MapReloader.InitialSetup();

end

function _FECore.Start()

-- Call helper functions.

	_PropHeightFix.Start();

end

function _FECore.Load()

-- Call helper functions.

end

function _FECore.Save()

-- Call helper functions.

end

function _FECore.AddObject(h)

-- Call helper functions.

	_PropHeightFix.AddObject(h);

end

function _FECore.DeleteObject(h)

-- Call helper functions.

end

function _FECore.Update()

-- Call helper functions.

end

--]]

print("Finished _FECore.lua");

return _FECore;