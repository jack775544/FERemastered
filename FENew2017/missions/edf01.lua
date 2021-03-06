require "FE13Dev.FEAddon.lua.GlobalHandler";

-- Variables Not saved. Constants that never change.
local NUM_TANKS = 6
local NUM_SURVIVORS = 10
--Strings
local _Text1 = "Your vehicle is equipped with\na special scanning device.\nScan the power source by\ngetting near it.";
local _Text2 = "Hostiles are moving to attack!!\nTake action!";
local _Text3 = "Have your subordinate tanks pick\nup the survivors, and bring them\nback to the dropships.  Only the\nsubordinate Sabres can get them.";
local _Text4 = "Tanks carrying survivors will be\nplaced in Group 10 automatically.\nThey can't pick you up while\ncarrying a survivor.  Don't lose\nany survivors!";
local _Text5 = "Scan the next highlighted\npower source.";
local _Text6 = "You've lost too many tanks\nto complete this mission.";
local _Text7 = "That's two survivors dead.  That\nlast one was no ordinary survivor,\nbut General Hardin himself!";
local _Text8 = "The Hadeans have overrun the\narea.  There's no hope now.";
local _Text9 = "Congratulations.  All the\nsurvivors are safe.  General\nHardin was among them, and\nwould like to thank you.";
local _Text10 = "A survivor was KILLED.  We\nCANNOT afford to lose another!!!";
local _Text11 = "All the remaining survivors are\nsafe.  We lost one, regretably.";


local Routines = {};
local RoutineToIDMap = {};

local M = {
--Mission State
	RoutineState = {},
	RoutineWakeTime = {},
	RoutineActive = {},
	MissionOver = false,
-- Bools
	
-- Floats
	CameraEndTime = 0.0,
-- Handles
	Player = nil,
	Hadean1 = nil,	--Hadean tank at "Observer1"
	Hadean2 = nil,	--Hadean tank at "Observer2"
	PowerSource = nil,
	PlayerTanks = {},
	ShultzTank = nil,
	ShultzPilot = nil,
	Dropship = nil,
	Survivors = {},
	SafeNav = nil,
	FriendTurret1 = nil,
	FriendTurret2 = nil,
	FriendTurret3 = nil,
	APC1 = nil,
	APC2 = nil,
--Vectors
	Position1 = SetVector( -10, 50, -10 );	--Camera offset
-- Ints
	TPS = 10,
	ScanPercentage = 0,	--Cthonian power source scan percentage
	PowerScanned = 0,	--# of power sources scanned
	SurvivorIndex1 = 0,
	SurvivorIndex2 = 0,
	SurvivorsWaiting = 0,
	SurvivorsRescued = 0,
	SabresRemaining = 8,
	HadeanUnitsCount = 0,	--if this gets over 24, player loses.
	SurvivorsKilled = 0,
	endme = 0
};

function DefineRoutine(routineID, func, activeOnStart)
	if routineID == nil or Routines[routineID]~= nil then
		error("DefineRoutine: duplicate or invalid routineID: "..tostring(routineID));
	elseif func == nil then
		error("DefineRoutine: func is nil for id "..tostring(routineID), 2);
	else
		Routines[routineID] = func;
		RoutineToIDMap[func] = routineID;
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

function SetRoutineActive(routine, active)
	local routineID = RoutineToIDMap[routine] or routine or error("SetRoutineActive(): routine '"..tostring(routine).." not found.", 2);
	M.RoutineActive[routineID] = active;
end

--gets an object handle by label. If it doesn't exist, throws an error.
function GetHandleOrDie(name)
	return GetHandle(name) or error("Error: object '"..name.."' not found!", 2);
end

function DefineRoutines()
	DefineRoutine(1, HandleIntro, true);
	DefineRoutine(2, HandleMainState, true);
	DefineRoutine(3, HandleSurvivorPickup, false);
	DefineRoutine(4, HandleSurvivorDropoff, false);
	DefineRoutine(5, SpawnHadeans, false);
	DefineRoutine(6, CheckHadeanOverrun, true);
	DefineRoutine(7, HighlightSurvivors, false);
	DefineRoutine(8, CheckTanksRemaining, false);
end


function InitialSetup()
	M.TPS = EnableHighTPS();
	DefineRoutines();
	--Preload to reduce lag spikes when resources are used for the first time.
	local preloadODFs = {
		"ivturr",
		"ivtank",
		"ivtank_e01",
		"ivapc",
		"ivserv",
		"evtank",
		"evscout",
		"evturr",
		"evmisl"
	};
	local preloadAudio = {
		"edf01_01.wav",
		"edf01_02.wav",
		"edf01_03.wav",
		"edf01_04.wav",
		"edf01_05.wav",
		"edf01_05A.wav",
		"edf01_05B.wav",
		"edf01_06.wav",
		"edf01_06A.wav",
		"edf01_07.wav",
		"edf01_08.wav",
		"edf01_09.wav",
		"edf01_10.wav",
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
	M.Dropship = GetHandleOrDie("DropShip");
	GLOBAL_lock(_G);	--prevents script from accidentally creating new global variables.
end


function AddObject(h)
	if GetCfg(h) == "ispilo" and not IsPlayer(h) and M.RoutineState[1] < 4 then
		M.ShultzPilot = h;
	elseif GetCfg(h) == "evtank" or GetCfg(h) == "evscout" then
		M.HadeanUnitsCount = M.HadeanUnitsCount + 1;
	end
end

function DeleteObject(h)
	if GetCfg(h) == "evtank" or GetCfg(h) == "evscout" then
		M.HadeanUnitsCount = M.HadeanUnitsCount - 1;
	elseif GetCfg(h) == "ivtank" or GetCfg(h) == "ivtank_e01" then
		M.SabresRemaining = M.SabresRemaining - 1;
		SetRoutineActive(CheckTanksRemaining, true);--M.CheckRemainingTanks = true;
	end
end

function Update()
	M.Player = GetPlayerHandle();
	for routineID,r in pairs(Routines) do
		if M.RoutineActive[routineID] and M.RoutineWakeTime[routineID] <= GetTime() then
			r(routineID, M.RoutineState[routineID]);
		end
	end
end

--Code for handling shultz ejecting and scanning the Cthonian power things
function HandleIntro(R, STATE)
	if STATE == 0 then
		SetPerceivedTeam(M.Player, 5);
		M.FriendTurret1 = BuildObject("ivturr", 1, "FriendTurret1");
		M.FriendTurret2 = BuildObject("ivturr", 1, "FriendTurret2");
		M.FriendTurret3 = BuildObject("ivturr", 1, "FriendTurret3");
		SetGroup(M.FriendTurret1, 1);
		SetGroup(M.FriendTurret2, 1);
		SetGroup(M.FriendTurret3, 1);
		Stop(M.FriendTurret1, 1);
		Stop(M.FriendTurret2, 1);
		Stop(M.FriendTurret3, 1);
		M.APC1 = BuildObject("ivapc", 1, "APC1");
		M.APC2 = BuildObject("ivapc", 1, "APC2");
		Stop(M.APC1, 1);
		Stop(M.APC2, 1);
		for i = 1,NUM_TANKS do
			M.PlayerTanks[i] = BuildObject("ivtank", 1, string.format("Buddy%d", i));
			Stop(M.PlayerTanks[i], 1);
			SetPerceivedTeam(M.PlayerTanks[i], 5);
		end
		M.ShultzTank = BuildObject("ivtank", 1, "Dummy");
		Stop(M.ShultzTank, 1);
		SetObjectiveName(M.ShultzTank, "Schulz");
		SetObjectiveOn(M.ShultzTank);
		Advance(R, 4.0);
	elseif STATE == 1 then
		AudioMessage("edf01_01.wav");	--Shultz:"Looks like these Hadeans ain't all they're cracked up to be..."
		Goto(M.APC1, "APCDest", 1);
		Goto(M.APC2, "APCDest", 1);
		Advance(R, 17.0);
	elseif STATE == 2 then
		EjectPilot(M.ShultzTank);
		Advance(R, 3.0);
	elseif STATE == 3 then
		AudioMessage("edf01_02.wav");	--Shultz:"Piece of junk just blew up on me..."
		Goto(M.ShultzPilot, M.Dropship, 1);
		CameraReady();
		M.CameraEndTime = GetTime() + 18;
		Advance(R);
	elseif STATE == 4 then
		CameraObject(M.Dropship, M.Position1, M.ShultzPilot);
		if M.CameraEndTime < GetTime() then
			CameraFinish();
			Advance(R, 2.0);
		end
	elseif STATE == 5 then
		RemoveObject(M.ShultzPilot);
		Advance(R);
	elseif STATE == 6 then
		AddObjective(_Text1, "white");
		AudioMessage("edf01_03.wav");	--Stewart:"Bravo Leader, scan those power sources..."
		Advance(R, 3.0);
	elseif STATE == 7 then	--LOC_49
		Goto(M.PlayerTanks[1], string.format("Nav%iA", M.PowerScanned), 1);
		Goto(M.PlayerTanks[2], string.format("Nav%iA", M.PowerScanned), 1);
		Goto(M.PlayerTanks[3], string.format("Nav%iA", M.PowerScanned), 1);
		Goto(M.PlayerTanks[4], string.format("Nav%iB", M.PowerScanned), 1);
		Goto(M.PlayerTanks[5], string.format("Nav%iB", M.PowerScanned), 1);
		Goto(M.PlayerTanks[6], string.format("Nav%iB", M.PowerScanned), 1);
		M.PowerSource = GetHandle(string.format("PowerSource%i", M.PowerScanned));
		SetObjectiveName(M.PowerSource, string.format("Power source: %i%% scanned", M.ScanPercentage));
		SetObjectiveOn(M.PowerSource);
		Advance(R);
	elseif STATE == 8 then	--LOC_58
		if GetDistance(M.Player, M.PowerSource) < 190 then
			M.ScanPercentage = M.ScanPercentage + 4;
			SetObjectiveName(M.PowerSource, string.format("Power source: %i%% scanned", M.ScanPercentage));
			if M.ScanPercentage == 100 then
				Advance(R);
			else
				Wait(R, 0.4);	--scan percentage goes up by 4 every .4s
			end
		end
	elseif STATE == 9 then
		SetObjectiveOff(M.PowerSource);
		M.ScanPercentage = 0;
		M.PowerScanned = M.PowerScanned + 1;
		if M.PowerScanned > 1 then
			M.SpawnHadeanReinforcements = true;
			Advance(R);
		else
			ClearObjectives();
			AddObjective(_Text5, "white");
			SetState(R, 7);--to LOC_49
		end
	end
end

--Main mission state. Deals with aggro-ing the Hadeans and controlling the other states.
function HandleMainState(R, STATE)
	if STATE == 0 then
		Advance(R, 40.0);
	elseif STATE == 1 then
		M.Hadean1 = BuildObject("evtank", 5, "Observer1");
		M.Hadean2 = BuildObject("evtank", 5, "Observer2");
		LookAt(M.Hadean1, M.Player, 0);
		LookAt(M.Hadean2, M.Player, 0);
		Advance(R, 10.0);
	elseif STATE == 2 then
		RemoveObject(M.APC1);
		RemoveObject(M.APC2);
		Advance(R);
	elseif STATE == 3 then	--LOC_136
		if GetTime() > 200 then
			SetState(R, 5, 4.0);--to LOC_150
		elseif M.PowerScanned >= 1 then
			Advance(R);
		end
	elseif STATE == 4 then	--LOC_140
		if GetTime() > 200 
		or GetTeamNum(GetWhoShotMe(M.Hadean1)) == 1 
		or GetTeamNum(GetWhoShotMe(M.Hadean2)) == 1 
		or M.ScanPercentage >= 45 then
			Advance(R, 4.0);
		end
	elseif STATE == 5 then	--LOC_150
		AudioMessage("edf01_04.wav");	--Stewart:"Heads up, 2 hostiles closing in"
		SetPerceivedTeam(M.Player, 1);
		for i = 1,NUM_TANKS do
			SetPerceivedTeam(M.PlayerTanks[i], 1);
		end
		ClearObjectives();
		AddObjective(_Text2, "white");
		Advance(R);
	elseif STATE == 6 then
		--Attack() doesn't seem to work if called in the same tick as SetPerceivedTeam()	
		Attack(M.Hadean1, M.PlayerTanks[1], 0);
		Attack(M.Hadean2, M.PlayerTanks[2], 0);
		Advance(R, 4.0);
	elseif STATE == 7 then
		for i = 1,NUM_TANKS do
			SetGroup(M.PlayerTanks[i], 0);
			Stop(M.PlayerTanks[i], 0);
		end
		SetObjectiveOff(M.PowerSource);
		Advance(R);
	elseif STATE == 8 then	--LOC_179
		if not (IsAlive(M.Hadean1) and GetTeamNum(M.Hadean1) == 5 
		and IsAlive(M.Hadean2) and GetTeamNum(M.Hadean2) == 5) then
			SetRoutineActive(SpawnHadeans, true); --m_SpawnHadeanReinforcements = true;
			SetRoutineActive(HandleSurvivorPickup, true);--m_HandleSurvivorPickup = true;
			SetRoutineActive(HandleSurvivorDropoff, true);--m_HandleSurvivorDropoff = true;
			SetRoutineActive(HighlightSurvivors, true);--m_HandleSurvivorBeacons = true;
			Advance(R, 7.0);
		end
	elseif STATE == 9 then
		AudioMessage("edf01_05.wav");	--Lt. Minner:"Team Alpha's dropships were shot down, require assistance..."
		Advance(R, 8.0);
	elseif STATE == 10 then
		ClearObjectives();
		AddObjective(_Text3, "white");
		AddObjective(_Text4, "white");
		Advance(R, 6.0);
	elseif STATE == 11 then
		AudioMessage("edf01_05A.wav");	--Stewart: "Rescue the Alpha survivors..."
		M.SafeNav = BuildObject("ibnav", 1, "SafeNav");
		SetObjectiveName(M.SafeNav, "Survivor Dropoff");
		SetObjectiveOn(M.SafeNav);
		local nav1 = BuildObject("ibnav", 1, "SurvivorNav1");
		local nav2 = BuildObject("ibnav", 1, "SurvivorNav2");
		SetObjectiveName(nav1, "Survivors");
		SetObjectiveName(nav2, "Survivors");
		SetObjectiveOn(nav1);
		SetObjectiveOn(nav2);
		BuildObject("evscout", 5, "Enemy2");
		BuildObject("evscout", 5, "Enemy3");
		Advance(R, 140.0);
	elseif STATE == 12 then	--LOC_209
		if GetDistance(M.Player, M.Dropship) > 200 then
			Goto(BuildObject("evturr", 5, "TurretSpawn"), "Turret1", 1);
			Goto(BuildObject("evturr", 5, "TurretSpawn"), "Turret2", 1);
			Goto(BuildObject("evturr", 5, "TurretSpawn"), "Turret3", 1);
			Stop(M.FriendTurret1, 0);
			Stop(M.FriendTurret2, 0);
			Stop(M.FriendTurret3, 0);
			SetGroup(BuildObject("ivserv", 1, "Buddy4"), 2);
			SetGroup(BuildObject("ivserv", 1, "Buddy5"), 3);
			SetGroup(BuildObject("ivserv", 1, "Buddy6"), 4);
			AudioMessage("edf01_05B.wav");	--Stewart:"I've put some turrets and service trucks at your disposal..."
			Advance(R);
		end
	end
end

--Code for handling tanks picking up survivors
function HandleSurvivorPickup(R, STATE)	--Routine5
	if STATE == 0 then	--LOC_278
		for i = 1,NUM_SURVIVORS do
			M.Survivors[i] = GetHandle(string.format("Survivor%i", i-1));
			SetMaxHealth(M.Survivors[i], 800);
			SetCurHealth(M.Survivors[i], 800);
		end
		M.SurvivorIndex1 = 1;
		Advance(R);
	elseif STATE == 1 then	--LOC_285
		local survivor = M.Survivors[M.SurvivorIndex1];
		if not IsAround(survivor) then
			if M.SurvivorsKilled > 0 then
				--2 survivors died
				ClearObjectives();
				AddObjective(_Text7, "red");
				AudioMessage("edf01_07.wav");	--Stewart:"You just let another survivor die. It was Hardin..."
				FailMission(GetTime() + 15, "edf01L2.txt");
				SetRoutineActive(R, false);
			elseif M.SurvivorsRescued >= NUM_SURVIVORS - 1 then
				--rescued 9 survivors and one died
				m_HandleSurvivorDropoff = false;
				ClearObjectives();
				AddObjective(_Text10, "red");
				AudioMessage("edf01_06a.wav");	--Stewart:"You've just lost a survivor..."
				SetState(R, 199, 10.0);
			else
				--one died, rest still need rescue
				ClearObjectives();
				AddObjective(_Text10, "red");
				AudioMessage("edf01_06a.wav");	--Stewart:"You've just lost a survivor..."
				Advance(R);
			end
			M.SurvivorsKilled = 1;
			M.Survivors[M.SurvivorIndex1] = M.Dropship;	--set the dead handle to the dropship to stop it from being counted again
		elseif GetCfg(survivor) == "ispilo" then
			local h = GetNearestVehicle(survivor);
			if not IsPlayer(h) and GetCfg(h) == "ivtank" and GetDistance(h, survivor) < 24 then
				--player's henchman picks up the pilot
				M.SabresRemaining = M.SabresRemaining + 1;
				RemoveObject(survivor);
				h = ReplaceObject2(h, "ivtank_e01");
				M.Survivors[M.SurvivorIndex1] = h;
				AudioMessage("ivtank03.wav");	--Tank:"I've got 'em"
				SetObjectiveName(h, string.format("Has survivor %i", M.SurvivorIndex1));
				SetObjectiveOn(h);
				SetGroup(h, 9);
				Follow(h, M.Player, 0);
			end
			Advance(R);
		else
			Advance(R);
		end
	elseif STATE == 2 then
		M.SurvivorIndex1 = M.SurvivorIndex1 + 1;
		if M.SurvivorIndex1 > NUM_SURVIVORS then
			M.SurvivorIndex1 = 1;
		end
		SetState(R, STATE - 1);--to LOC_285
	elseif STATE == 199 then
		ClearObjectives();
		AddObjective(_Text11, "green");
		AudioMessage("edf01_06.wav");	--Stewart:"Good work Corber. You may be surprised to hear Gen. Hardin was among the survivors..."
		SucceedMission(GetTime() + 16, "edf01W2.txt");--15
		Advance(R);
	end
end

--Code for handling survivors being dropped off at SafeNav
function HandleSurvivorDropoff(R, STATE)
	local h = M.Survivors[M.SurvivorIndex2];
	if GetCfg(h) == "ivtank_e01" and GetDistance(h, "SafeNav") < 60 then	--85
		M.SabresRemaining = M.SabresRemaining + 1;
		M.Survivors[M.SurvivorIndex2] = M.Dropship;
		h = ReplaceObject2(h, "ivtank");
		Stop(h, 0);
		SetGroup(h, 0);
		M.SurvivorsRescued = M.SurvivorsRescued + 1;
		SetObjectiveName(M.SafeNav, string.format("Survivor Dropoff: %i safe", M.SurvivorsRescued));
		if M.SurvivorsRescued == 3 
		or M.SurvivorsRescued == 7 
		or (M.SurvivorsRescued == 9 and M.SurvivorsKilled == 0) then
			Goto(BuildObject("evtank", 5, "AttackerSpawn2"), "SafeNav", 0);
			Goto(BuildObject("evmisl", 5, "AttackerSpawn2"), "SafeNav", 0);
			Goto(BuildObject("evmisl", 5, "AttackerSpawn2"), "SafeNav", 0);
		elseif M.SurvivorsRescued == 9 then	--LOC_365
			--win - 1 survivor died
			ClearObjectives();
			AddObjective(_Text11, "green");
			AudioMessage("edf01_06.wav");
			SucceedMission(GetTime() + 15, "edf01W2.txt");
			SetRoutineActive(R, false);
		elseif M.SurvivorsRescued == 10 then	--LOC_372
			--win - no survivors died
			AudioMessage("edf01_06.wav");	--Stewart:"Good work Corber. You may be surprised to hear Gen. Hardin was among the survivors..."
			ClearObjectives();
			AddObjective(_Text9, "green");
			SucceedMission(GetTime() + 16, "edf01W1.txt");--15
			SetRoutineActive(R, false);
		end
	else
		M.SurvivorIndex2 = M.SurvivorIndex2 + 1;
		if M.SurvivorIndex2 > NUM_SURVIVORS then
			M.SurvivorIndex2 = 1;
		end
	end
end

--Code for spawning in Hadean reinforcements
function SpawnHadeans(R, STATE)
	if STATE == 0 then	--LOC_72
		Advance(R, 61.0);
	elseif STATE == 1 then
		Patrol(BuildObject("evscout", 5, "AttackerSpawn1"), "EnemyPatrol1", 0);
		Patrol(BuildObject("evscout", 5, "AttackerSpawn1"), "EnemyPatrol1", 0);
		Advance(R, 67.0);
	elseif STATE == 2 then
		Patrol(BuildObject("evtank", 5, "AttackerSpawn1"), "EnemyPatrol1", 0);
		Advance(R, 61.0);
	elseif STATE == 3 then
		Patrol(BuildObject("evtank", 5, "AttackerSpawn1"), "EnemyPatrol1", 0);
		Advance(R);
	elseif STATE == 4 then	--LOC_83
		if M.SurvivorsRescued > 0 then
			SetState(R, 7);--to LOC_101
		else
			Advance(R, 7.0);
		end
	elseif STATE == 5 then
		Patrol(BuildObject("evscout", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		Patrol(BuildObject("evscout", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		if M.SurvivorsRescued > 0 then
			SetState(R, 7);--to LOC_101
		else
			Advance(R, 95.0);
		end
	elseif STATE == 6 then
		Patrol(BuildObject("evtank", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		if M.SurvivorsRescued > 0 then
			Advance(R);
		else
			SetState(R, 4);--to LOC_83
		end
	elseif STATE == 7 then	--LOC_101
		Advance(R, 75.0);
	elseif STATE == 8 then
		Patrol(BuildObject("evscout", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		Patrol(BuildObject("evscout", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		Advance(R, 95.0);
	elseif STATE == 9 then
		Patrol(BuildObject("evtank", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		Advance(R, 75.0);
	elseif STATE == 10 then
		Patrol(BuildObject("evtank", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		Advance(R, 75.0);
	elseif STATE == 11 then
		Patrol(BuildObject("evscout", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		Patrol(BuildObject("evscout", 5, "AttackerSpawn2"), "EnemyPatrol1", 0);
		Advance(R, 95.0);
	elseif STATE == 12 then
		Patrol(BuildObject("evtank", 5, "TurretSpawn"), "EnemyPatrol1", 0);
		Advance(R, 75.0);
	elseif STATE == 13 then
		Patrol(BuildObject("evtank", 5, "TurretSpawn"), "EnemyPatrol1", 0);
		if M.HadeanUnitsCount < 15 then
			SetState(R, 7);--to LOC_101
		else
			SetState(R, 7, 140.0);--to LOC_101
		end
	end
end

--fails the mission if there are too many Hadeans on the map and the survivors have not been rescued
function CheckHadeanOverrun(R, STATE) 
	if STATE == 0 then
		if M.HadeanUnitsCount > 24 and M.SurvivorsWaiting > 0 then
			ClearObjectives();
			AddObjective(_Text8, "red");
			AudioMessage("edf01_08.wav");	--Stewart:"You've taken too long! The Hadeans have control over the area." 
			Advance(R, 7.0);
		end
	elseif STATE == 1 then
		AudioMessage("edf01_10.wav");	--Stewart:"You've really bungled this one..."
		FailMission(GetTime() + 14, "edf01L3.txt");
		Advance(R);
	end
end

--places an objective marker on one of the survivors indicating how many survivors need rescue
function HighlightSurvivors(R, STATE)
	M.SurvivorsWaiting = 0;
	local survivor = nil;
	for i = 1, NUM_SURVIVORS do
		if GetCfg(M.Survivors[i]) == "ispilo" then
			M.SurvivorsWaiting = M.SurvivorsWaiting + 1;
			survivor = M.Survivors[i];
		end
	end
	if M.SurvivorsWaiting == 0 then
		SetRoutineActive(R, false);
	elseif M.SurvivorsWaiting == 1 then
		SetObjectiveName(survivor, "Last Waiting Survivor");
		SetObjectiveOn(survivor);
	else
		SetObjectiveName(survivor, string.format("%i Survivors Waiting", M.SurvivorsWaiting));
		SetObjectiveOn(survivor);
	end
	Wait(R, 2.0);	--update every 2s
end

--fails the mission if the player loses too many Sabres
function CheckTanksRemaining(R, STATE)
	if STATE == 0 then
		if M.SabresRemaining < 2 then
			ClearObjectives();
			AddObjective(_Text6, "red");
			AudioMessage("edf01_09.wav");	--Stewart:"Return to base, we've lost too many Sabres"
			Advance(R, 9.0);
		end
	elseif STATE == 1 then
		AudioMessage("edf01_10.wav");	--Stewart:"You've really bungled this one..."
		FailMission(GetTime() + 14, "edf01L1.txt");
		Advance(R);
	end
end

--work around for crash when ReplaceObject() is called on unit told to go to nav by player 
function ReplaceObject2(h, odf)
	local team = GetTeamNum(h);
	local health = GetCurHealth(h);
	local pos = GetTransform(h);
	RemoveObject(h);
	h = BuildObject(odf, team, pos);
	SetCurHealth(h, health);
	return h;
end
