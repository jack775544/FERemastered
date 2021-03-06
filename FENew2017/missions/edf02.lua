require "FE13Dev.FEAddon.lua.GlobalHandler";

-- Variables Not saved. Constants that never change.
local NUM_PORTALS = 5;
local NUM_ATTACKERS = 8;
--Strings
local _Text1 = "Scout ahead of the Recycler and\nmake sure this canyon is safe!";
local _Text2 = "You've lost the Recycler and\na platoon's worth of good men.\nWe now have no hope of securing\nour eastern flank.";
local _Text3 = "The Hadeans are alerted to our\npresence. You must act quickly to\n make it to safer ground!";
local _Text4 = "Deploy the Recycler, and get\nsome gun towers built. Hurry--you\ndon't have much time!";
local _Text5 = "Excellent job, Lieutenant! The\nGeneral will be pleased to hear\nthat we have a competent CO \nholding our eastern flank.\nReinforcements are en route.";
local _Text6 = "Command has some suspicions.\nStay clear and observe the\nactivity near the structure.";
local _Text7 = "Get your units out of the\ncanyon through that portal.\nIt may be your only hope.";
local _Text8 = "Use the 'I' key of your Digital\nControl Interface to scan the\nstructure.";
local _Text9 = "Try to pass through the portal\nby cruising under the arch. If\nyou succeed, try to return in the\nsame way.";
local _Text10 = "Sensors show a major attack wave\napproaching from two directions\nand closing fast!";
local _Text11 = "The Hadean attackers are almost\nwithin firing range!  Brace\n for an attack!";
local _Text12 = "You cannot seem to follow a\nsimple order, Lieutenant. Return\nto base and turn in your sidearm\nand wings.";


local Routines = {};

local M = {
--Mission State
	RoutineState = {},
	RoutineWakeTime = {},
	RoutineActive = {},
	MissionOver = false,
-- Bools
	RecyTeleported = false,
	ScavTeleported = false,
	PlayerTeleported = false,
-- Floats
	StewartNextNagTime = 0.0,
-- Handles
	StayPut = nil,
	Portals = {},
	Recycler = nil,
	Player = nil,
	EnemyScout1 = nil,	--xypos that spawns right after enemy scav
	BaseNav = nil,
	InvestigateNav = nil,
	ScrapPool = nil,
	HadeanScav = nil,
	DropshipFlying = nil,
	DropshipLanded = nil,
	Attackers = {},
	Dino1 = nil,
	Dino2 = nil,
--Vectors
	Position2 = SetVector( -450, -120, -1460 ),	--flying dropship start position
	Position3 = SetVector( -590, -155, -1190 ),	--flying dropship end position
	Position4 = SetVector( 420, 0, 920 ),	--deploy base location
-- Ints
	TPS = 10,
	StewartNagCounter = 0,
	GunTowersBuilt = 0,
	AttackWave = 0,	--hadean attack wave counter
	AttackIndex = 0,
	endme = 0
};

function DefineRoutine(routineID, func, activeOnStart)
	if routineID == nil or Routines[routineID]~= nil then
		error("DefineRoutine: duplicate or invalid routineID: "..tostring(routineID));
	elseif func == nil then
		error("DefineRoutine: func is nil for id "..tostring(routineID), 2);
	else
		Routines[routineID] = func;
		M.RoutineState[routineID] = 0;
		M.RoutineWakeTime[routineID] = 0.0;
		M.RoutineActive[routineID] = activeOnStart;
	end
end

function Advance(routineID, delay)
	routineID = routineID or error("Advance(): invalid routineID.", 2);
	SetState(routineID, M.RoutineState[routineID] + 1, delay);
end

function SetState(routineID, state, delay)
	routineID = routineID or error("SetState(): invalid routineID.", 2);
	delay = delay or 0.0;
	M.RoutineState[routineID] = state;
	M.RoutineWakeTime[routineID] = GetTime() + delay;
end

function Wait(routineID, delay)
	M.RoutineWakeTime[routineID] = GetTime() + delay;
end

function SetRoutineActive(routineID, active)
	M.RoutineActive[routineID] = active;
end

--gets an object handle by label. If it doesn't exist, throws an error.
function GetHandleOrDie(name)
	return GetHandle(name) or error("Error: object '"..name.."' not found!", 2);
end

function DefineRoutines()
	DefineRoutine(1, HandleMainState, true);
	DefineRoutine(2, SpawnDinos, true);
	DefineRoutine(3, HandleScavTeleport, true);
	DefineRoutine(4, HandleHadeanAttack, true);
	DefineRoutine(5, HandleStewartNag, false);
end


function InitialSetup()
	M.TPS = EnableHighTPS();
	DefineRoutines();
	--Preload to reduce lag spikes when resources are used for the first time.
	local preloadODFs = {
		"stayput",
		"evscout_e02",
		"evtank",
		"evscav",
		"evmislu",
		"evtanku",
		"evmort"
	};
	local preloadAudio = {
		"edf02_01.wav",
		"edf02_02.wav",
		"edf02_03.wav",
		"edf02_04.wav",
		"edf02_05.wav",
		"edf02_05A.wav",
		"edf02_06.wav",
		"edf02_07.wav",
		"edf02_08.wav",
		"edf02_09.wav",
		"edf02_10.wav",
		"edf02_11.wav",
		"edf02_12.wav"
	};
	for k,v in pairs(preloadODFs) do
		PreloadODF(v);
	end
	for k,v in pairs(preloadAudio) do
		PreloadAudioMessage(v);
	end
end

function Save()
    return M
end

function Load(...)
    if select('#', ...) > 0 then
		M = ...
    end
end

function Start()
	M.Recycler = GetHandleOrDie("Recycler");
	M.DropshipLanded = GetHandleOrDie("DropShip");
	M.Portals[1] = GetHandleOrDie("Portal1");	--first portal in canyon
	M.Portals[2] = GetHandleOrDie("Portal2");	--recycler portal east of deploy zone
	M.Portals[3] = GetHandleOrDie("Portal3");	--portal beside scrap pool
	M.Portals[4] = GetHandleOrDie("Portal4");	--south east portal
	M.Portals[5] = GetHandleOrDie("Portal5");	--player's portal (southern most one)
	M.ScrapPool = GetHandleOrDie("Pool1");
	GLOBAL_lock(_G);	--prevents script from accidentally creating new global variables.
end


function AddObject(h)
	if GetCfg(h) == "ibgtow" then
		M.GunTowersBuilt = M.GunTowersBuilt + 1;
	elseif GetCfg(h) == "ibrecy" then
		RemoveObject(M.BaseNav);
	end
end

function Update()
	M.Player = GetPlayerHandle();
	for routineID,r in pairs(Routines) do
		if M.RoutineActive[routineID] and M.RoutineWakeTime[routineID] <= GetTime() then
			r(routineID, M.RoutineState[routineID]);
		end
	end
	HandlePortals();
	CheckStuffIsAlive();
end

--Main mission state
function HandleMainState(R, STATE)
	if STATE == 0 then
		M.StayPut = BuildObject("stayput", 0, GetTransform(M.Player));
		Stop(M.Recycler, 1);
		StartEarthQuake(10.0);
		M.DropshipFlying = BuildObject("ivdrop_fly", 0, M.Position2);
		SetObjectiveName(BuildObject("ibnav", 1, M.Position2), "Position2");
		Advance(R, 7.0);
	elseif STATE == 1 then
		AudioMessage("edf02_01.wav");	--Pilot:"That blast came awfully close..."
		Advance(R, 3.0);
	elseif STATE == 2 then
		SetAnimation(M.DropshipLanded, "Deploy", 1);
		StartAnimation(M.DropshipLanded);	--open the landed dropship doors while player isn't looking
		CameraReady();
		Advance(R);
	elseif STATE == 3 then
		Move2(M.DropshipFlying, 0.0, 30.0, TerrainFloor(M.Position3));
		if CameraPath("CamPath", 5500, 3200, M.DropshipFlying) 
		or CameraCancelled() then
			CameraFinish();
			Advance(R);
		end
	elseif STATE == 4 then
		AudioMessage("xemt2.wav");
		StopEarthQuake();
		RemoveObject(M.DropshipFlying);
		RemoveObject(M.StayPut);
		SetPosition(M.Recycler, "RecyclerPath");
		SetVelocity(M.Recycler, SetVector(0, 0, 15));
		SetPosition(M.Player, "PlacePlayer");
		SetVelocity(M.Player, SetVector(0, 0, 40));
		local escort1 = BuildObject("ivtank", 1, "Escort1");
		local escort2 = BuildObject("ivscout", 1, "Escort2");
		local escort3 = BuildObject("ivscout", 1, "Escort3");
		local escort4 = BuildObject("ivscout", 1, "Escort4");
		Follow(escort1, M.Recycler, 0);
		Follow(escort2, M.Recycler, 0);
		Follow(escort3, M.Recycler, 0);
		Follow(escort4, M.Recycler, 0);
		SetGroup(escort1, 2);	
		SetGroup(escort2, 1);	
		SetGroup(escort3, 1);
		SetGroup(escort4, 1);
		SetSkill(BuildObject("evscout_e02", 5, "Enemy1"), 3);
		SetSkill(BuildObject("evscout_e02", 5, "Enemy2"), 3);
		SetGroup(M.Recycler, 0);
		SetScrap(1, 30);
		Advance(R, 3.0);
	elseif STATE == 5 then
		AudioMessage("edf02_02.wav");	--Stewart:"Good landing under the circumstances..."
		Goto(M.Recycler, "RecyclerPath", 1);
		M.InvestigateNav = BuildObject("ibnav", 1, "NavSpawn");
		SetObjectiveName(M.InvestigateNav, "Investigate");
		SetObjectiveOn(M.InvestigateNav);
		ClearObjectives();
		AddObjective(_Text1, "white");
		Advance(R, 30.0);
	elseif STATE == 6 then
		AudioMessage("edf02_03.wav");	--Stewart:"Our scanners just picked up a huge energy spike..."
		Advance(R, 220.0);
	elseif STATE == 7 then
		AudioMessage("edf02_04.wav");	--Stewart:"You've got enemy units in the canyon..."
		Advance(R, 5.0);
	elseif STATE == 8 then
		Patrol(BuildObject("evscout_e02", 5, "Spawn2"), "Patrol2", 0);
		Advance(R, 5.0);
	elseif STATE == 9 then	--LOC_43
		if GetTime() > 780 then
			Goto(BuildObject("evtank", 5, "Spawn1"), "Patrol1", 0);
			Advance(R, 27.0);
		else
			Advance(R);
		end
	elseif STATE == 10 then	--LOC_48
		Goto(BuildObject("evscout_e02", 5, "Spawn1"), "Patrol1", 0);
		SetState(R, STATE-1, 48.0);--to LOC_43
	end
end

--handles respawning dinos around player base
function SpawnDinos(R, STATE)
	if GetTime() > 360 then
		if not IsAround(M.Dino1) then
			M.Dino1 = BuildObject("raptor01", 3, "DinoSpawn1");
			Goto(M.Dino1, "DinoPatrol1", 0);
		elseif not IsAround(M.Dino2) then
			M.Dino2 = BuildObject("raptor01", 3, "DinoSpawn1");
			Goto(M.Dino2, "DinoPatrol1", 0);
		end
	end
end

--spawns in the Hadean Scav and tells it to go through the portal
function HandleScavTeleport(R, STATE)
	if STATE == 0 then
		if GetDistance(M.Player, M.InvestigateNav) < 220 then
			SetObjectiveOff(M.InvestigateNav);
			ClearObjectives();
			AddObjective(_Text6, "white");
			M.HadeanScav = BuildObject("evscav", 5, "EnemyScav");
			SetObjectiveName(M.HadeanScav, "Observe");
			SetObjectiveOn(M.HadeanScav);
			Goto(M.HadeanScav, M.Portals[1], 1);
			Advance(R, 25.0);
		end
	elseif STATE == 1 then
		M.EnemyScout1 = BuildObject("evscout", 5, "Spawn2");
		Goto(M.EnemyScout1, M.Portals[1], 0);
		Advance(R, 6.0);
	elseif STATE == 2 then
		if IsAround(M.EnemyScout1) then
			SetObjectiveOn(M.EnemyScout1);
			Advance(R);
		end
	end
end

--Scav teleport and Hadean assault waves
function HandleHadeanAttack(R, STATE)
	if STATE == 0 then
		if M.ScavTeleported then
			Advance(R, 3.0);
		end
	elseif STATE == 1 then
		AudioMessage("edf02_05.wav");	--Stewart:"Good God, that scav just vanished"
		Advance(R, 7.0);
	elseif STATE == 2 then
		SetObjectiveName(M.HadeanScav, "Teleported Harvester");
		SetObjectiveOff(M.HadeanScav);
		Stop(M.HadeanScav, 0);
		SetRoutineActive(5, true);--M.StewartNag = true;
		Advance(R, 900.0);
	elseif STATE == 3 then
		AudioMessage("edf02_08.wav");	--Stewart:"The first enemy squadron is closing in..."
		ClearObjectives();
		AddObjective(_Text10, "white");
		M.HadeanAttackTime = GetTime() + 600.0;
		Advance(R);
	elseif STATE == 4 then	--LOC_94
		if M.HadeanAttackTime < GetTime() then
			SetState(R, STATE + 2, 50.0);--to LOC_104
		elseif M.GunTowersBuilt > 0 then
			M.HadeanAttackTime = M.HadeanAttackTime + 230.0;
			Advance(R);
		end
	elseif STATE == 5 then	--LOC_100
		if M.GunTowersBuilt > 1 or M.HadeanAttackTime < GetTime() then
			Advance(R, 50.0);
		end
	elseif STATE == 6 then	--LOC_104
		AudioMessage("edf02_09.wav");	--Stewart:"The hostiles are just seconds away..."
		ClearObjectives();
		AddObjective(_Text11, "white");
		M.AttackIndex = 1;
		Advance(R);
	elseif STATE == 7 then	--LOC_107
		--Wave 1
		local odfs = {"evtank", "evtanku", "evscout_e02", "evmislu"};
		M.Attackers[M.AttackIndex] = BuildObject(odfs[M.AttackIndex], 5, "Wave1");
		Goto(M.Attackers[M.AttackIndex], M.Recycler, 1);
		if M.AttackIndex == 4 then
			M.AttackIndex = 1;
			Advance(R, 3.0);
		else
			M.AttackIndex = M.AttackIndex + 1;
			Wait(R, 3.0);
		end
	elseif STATE == 8 then
		--Wave 2
		local odfs = {"evtanku", "evmislu", "evscout_e02", "evmort"};
		M.Attackers[M.AttackIndex+4] = BuildObject(odfs[M.AttackIndex], 5, "Wave2");
		Goto(M.Attackers[M.AttackIndex+4], M.Recycler, 1);
		if M.AttackIndex == 4 then
			Advance(R, 3.0);
		else
			M.AttackIndex = M.AttackIndex + 1;
			Wait(R, 3.0);
		end
	elseif STATE == 9 then	--LOC_136
		local waveDead = true;
		for i = 1,NUM_ATTACKERS do
			if IsAlive(M.Attackers[i]) and GetTeamNum(M.Attackers[i]) == 5 then
				waveDead = false;
				break;
			end
		end
		if waveDead then
			M.AttackWave = M.AttackWave + 1;
			if M.AttackWave < 3 then
				SetState(R, 7)--to LOC_107
			else
				--Win
				AudioMessage("edf02_10.wav");	--Stewart:"Well done. You've smashed the Hadeans..."
				ClearObjectives();
				AddObjective(_Text5, "green");
				SucceedMission(GetTime() + 18, "edf02W1.txt");
				Advance(R);
			end
		end
	end
end

--Stewart nagging player to go through the portal after the Hadean Scav
function HandleStewartNag(R, STATE)
	if STATE == 0 then	--LOC_259
		AudioMessage("EDF02_05A.wav");	--Stewart:"Try going through that arch."
		ClearObjectives();
		AddObjective(_Text9, "white");
		M.StewartNextNagTime = GetTime() + 30.0;
		Advance(R);
	elseif STATE == 1 then
		if M.StewartNextNagTime < GetTime() then
			if M.StewartNagCounter > 3 then
				AudioMessage("EDF02_12.wav");	--Stewart:"You can't follow simple instructions..."
				FailMission(GetTime() + 12, "EDF02_L2.txt");
				M.MissionOver = true;
				SetState(R, 99);
			else
				AudioMessage("EDF02_05A.wav");	--Stewart:"Try going through the portal"
				M.StewartNagCounter = M.StewartNagCounter + 1;
				M.StewartNextNagTime = GetTime() + 30.0;
			end
		elseif M.PlayerTeleported then
			Advance(R, 3.0);
		end
	elseif STATE == 2 then
		AudioMessage("edf02_06.wav");	--Stewart:"Just as we suspected. It's a portal..."
		Advance(R, 3.0);
	elseif STATE == 3 then
		ClearObjectives();
		AddObjective(_Text7, "white");
		Advance(R);
	elseif STATE == 4 then
		if M.RecyTeleported and GetDistance(M.Player, M.Recycler) < 150 then
			SetObjectiveOn(M.ScrapPool);
			Advance(R, 5.0);
		end
	elseif STATE == 5 then
		AudioMessage("edf02_07.wav");	--Stewart:"You've got incoming Hadeans. Get some GTs up."
		Advance(R);
	end
end

function HandlePortals()
	for i = 1,NUM_PORTALS do
		local h = GetNearestVehicle(M.Portals[i]);
		if GetDistance(h, M.Portals[i]) < 15 then
			OnPortalDist(M.Portals[i], h);
		end
	end
end

function OnPortalDist(portal, h)
	if GetCfg(h) == "ivrecy" then
		if not M.RecyTeleported then
			SetObjectiveOff(M.Portals[1]);
			M.BaseNav = BuildObject("ibnav", 1, M.Position4);
			SetObjectiveName(M.BaseNav, "Deploy Base");
			SetObjectiveOn(M.BaseNav);
			Teleport(h, M.Portals[2], 30);
			ClearObjectives();
			AddObjective(_Text4, "white");
			Goto(M.Recycler, M.BaseNav, 0);
			M.RecyTeleported = true;
		end
	elseif portal == M.Portals[1] then
		if IsPlayer(h) then
			M.PlayerTeleported = true;
			Teleport(h, M.Portals[4], 30);
		elseif math.random(1,2) == 1 then
			Teleport(h, M.Portals[3], 30);
		else
			Teleport(h, M.Portals[5], 30);
		end

		if not M.ScavTeleported and h == M.HadeanScav then
			M.ScavTeleported = true;
		elseif GetTeamNum(h) == 5 then
			Goto(h, M.Recycler, 0);
		end
	else		
		if IsPlayer(h) then
			Teleport(h, M.Portals[1], 30);
		end
	end
end

function CheckStuffIsAlive()
	if not M.MissionOver then
		if not IsAround(M.Recycler) then
			AudioMessage("edf02_11.wav");	--Stewart:"You lost the recycler..."
			ClearObjectives();
			AddObjective(_Text2, "red");
			FailMission(GetTime() + 12, "edf02L1.txt");
			M.MissionOver = true;
		end
	end
end

function TerrainFloor(pos)
	return SetVector(pos.x, TerrainFindFloor(pos), pos.z);
end

function Teleport(h, dest, offset)
	BuildObject("teleportout", 0, GetPosition(h));
	local dir = Normalize(GetPosition(dest) - GetPosition(h))
	local pos = GetPosition(dest) + dir*offset;
	BuildObject("teleportin", 0, pos);
	SetPosition(h, pos);
	SetVelocity(h, Length(GetVelocity(h))*dir);
	if h == GetPlayerHandle() then
		StartSoundEffect("teleport.wav", nil);	--sound effects seem to get cut off when player is teleporting
	end
end

--work around for flickering caused by calling Move() on a building that was spawned off map (for dropship cutscene)
function Move2(h, r, v, dest)
	local oldTransform = GetTransform(h);
	local oldPos = GetTransform(h).posit;
	local d = dest - oldPos;
	if Length(d) < v / M.TPS then
		local newTransform = BuildDirectionalMatrix(dest);
		SetTransform(h, newTransform);
		SetInterpolablePosition(h, newTransform, oldTransform, true);
		return true;
	else
		local factor = v / (Length(d) * M.TPS);
		local offset = d * factor;
		local newPos = oldPos + offset;
		local newTransform = BuildDirectionalMatrix(newPos);
		SetTransform(h, newTransform);
		SetInterpolablePosition(h, newTransform, oldTransform, true);
		return false;
	end
end
