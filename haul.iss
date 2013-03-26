
#include "HaulLibrary.iss"
variable(script) int EndScript = 0
/* Helps us determine who to warp to */
variable(script) index:fleetmember GangMember
variable(script) int GangMemberCount
variable(script) int Turn = 1
variable(script) bool Loiter
variable(script) bool FallingBehind


/* origin is base camp, destination is mining spot */
function main(string Origin, string Destination, bool IceMining=FALSE)
{

LogFile:Set["${Script.CurrentDirectory}/logs/${Time.Month}-${Time.Day}-${Time.Year}.log"]
variable int i = 0
variable int j = 0
variable int Pilots = 0
variable int DynamicDelay
variable bool No3D
DynamicDelay:Set[2500]
Verbose:Set[2]
Loiter:Set[FALSE]
No3D:Set[FALSE]
FallingBehind:Set[FALSE]
ui -load haul

	;call ToggleCargo
			
/* Primary loop, runs constantly unless critical error */
	do
	{

/* Dropping ore in the station */
		if ${Me.InStation}
		{
			EVE:CloseAllMessageBoxes
			wait 5
			
			if ${EVE.Is3DDisplayOn} && ${No3D}
   			EVE:Toggle3DDisplay
			
			;call ToggleCargo
			call TransferEverythingToHangar
			
			wait 20
			
			call LogEcho "In station? ${Me.InStation}! Undocking"
			call Undock
			wait 15
			
			if ${Me.Ship.CargoCapacity} > 40000
			{
				call WaitForSpeedLessThan 0.20
			}
			
			if ${Verbose} > 2
				call LogEcho "Does AlignTarget bookmark exist? ${EVE.Bookmark[AlignTarget](exists)}"
			
			if ${EVE.Bookmark[AlignTarget](exists)}
			{	

				call GetModulesInformation
				if ${Verbose} > 1
					call LogEcho "Aligning to outbound gate."
					
				EVE.Bookmark[AlignTarget]:AlignTo
				wait 2
				
				if ${Me.Ship.CargoCapacity} > 40000
				{
					call PulseAfterburner
				}
				
			}
		}
    
   	 	if ${EVE.Is3DDisplayOn} && ${No3D}
   		EVE:Toggle3DDisplay
   			
		call AutoPilotTo ${Destination}
		
		call LoadGangMembers
		wait 10
		
		if ${EVE.Is3DDisplayOn} && ${No3D}
   		EVE:Toggle3DDisplay
		
		;wait 30
		;call ToggleCargo

		do
		{
			/* If I have mindlinks, go to a miner, and wait a while before hauling. */
			while ((${MindlinkCount} > 0) && !${IceMining} && !${FallingBehind}) && ${Me.Ship.UsedCargoCapacity}<${Math.Calc[${Me.Ship.CargoCapacity}*.90]}
			{
				call WarpToMiner
				EVE:CloseAllMessageBoxes
				
				call BoostSensors
				
				call LogEcho "Activating mindlinks for ${Math.Calc[WAIT_LOOT_TIMER*30/600]} minutes."
				call Check_Mindlinks
				
				do
				{
					call CheckForLoot
					if ${Verbose} > 1
						call LogEcho "Line _LINE_: Waiting WAIT_LOOT_TIMER. Value of j is ${j}."
					wait WAIT_LOOT_TIMER
					EVE:CloseAllMessageBoxes
				}
				while ${j:Inc}<30 && ${Me.Ship.UsedCargoCapacity}<${Math.Calc[${Me.Ship.CargoCapacity}*.90]}
			
				if ${Verbose} > 1
					call LogEcho "Line _LINE_: Mindlink While loop completed."
					
				
			}
				
			j:Set[0]
			
			/* loop to cause bot to warp between gang members if cargo still has room */
			while ((${Me.Ship.UsedCargoCapacity}<${Math.Calc[${Me.Ship.CargoCapacity}*.90]}) && ((${i:Inc}<=${GangMemberCount}) || ${Loiter})
			{
				if ${IceMining}
				{
					call WarpToBookmark Haul
				}
				else
				{
					call WarpToMiner
					EVE:CloseAllMessageBoxes
					call SetTurns
					;call ProspectBelt
				}

				call BoostSensors
				call Check_DamageControl
				call Check_Mindlinks

				EVE:CloseAllMessageBoxes
								
				wait WAIT_LOOT_TIMER
				call CheckForLoot
				call CheckForLeftovers
			
				if ${IceMining} && (${Me.Ship.UsedCargoCapacity}<${Math.Calc[${Me.Ship.CargoCapacity}*.90]})
				{
					if ${Verbose} > 1
					call LogEcho "Waiting ${Math.Calc[${DynamicDelay}/600]} minutes before next loot check."
					wait ${DynamicDelay}
				}
			
			}
			/* end  loop for warping between members. */

			if ((${Me.Ship.UsedCargoCapacity}>${Math.Calc[${Me.Ship.CargoCapacity}*.90]}) && !${IceMining} && (${i}<${GangMemberCount}))
			{
				FallingBehind:Set[TRUE]
			}
			else
			{
				FallingBehind:Set[FALSE]
			}

			/* Just in case someone disconnected */
			call LoadGangMembers
			wait 10
			i:Set[1]

			EVE:CloseAllMessageBoxes
			wait 20
	
		}
		while ${Me.Ship.UsedCargoCapacity}<${Math.Calc[${Me.Ship.CargoCapacity}*.90]} && ${MindlinkCount} > 0
		
		/* If we had a can that was left (empty bugged can, ignored loot, etc) reset it so we can loot it again on next cycle. */
		ProcessedEntities:Clear
		
		if ${EVE.Bookmark[AlignHaul](exists)}
		{
			if ${Verbose} > 1
				call LogEcho "Aligning to AlignTarget"
				
			EVE.Bookmark[AlignHaul]:AlignTo
			call PulseAfterburner
		}
	
		call AutoPilotTo ${Origin}
		wait 10
		
		if ${EVE.Is3DDisplayOn} && ${No3D}
		EVE:Toggle3DDisplay

	}
	while ${EndScript} == 0

}

function atexit()
{
UIElement -kill "TheHauler"
}



