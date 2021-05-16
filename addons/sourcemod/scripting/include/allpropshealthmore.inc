stock bool:ZRIsClientValid(client)
{
    if (!(client > 0 && client <= MaxClients) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client) || !IsPlayerAlive(client))
    {
        return false;
    }
    return true;
}

stock bool:ZRIsPlayerSpec(client)
{
	if (GetClientTeam(client) == 1)
    {
        return true;
    }
	return false;
}

stock GetRealClientCount()
{
	new iCount;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) != 1)
		{
			iCount++;
		}
	}
	
	return iCount;
}

public ZR_GetClientTeam(client)
{
	if(ZR_IsClientHuman(client)) 
	{
		return 3;
	}

	if(ZR_IsClientZombie(client))
	{
		return 2;
	}
	return 0;
}