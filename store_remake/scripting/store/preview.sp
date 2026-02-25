public void Store_OnPreviewItem(int client, char[] type, int index)
{
	Function fn;

	if (StrEqual(type, "pet"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "Pets_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "playerskin"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "PlayerSkin_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "hat"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "Hats_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "saysound"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "Saysound_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "trail"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "Trails_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "jump_effect"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "JumpEffect_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "rainbow_models"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "Rainbow_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "tracer"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "Tracers_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "lasersight"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "LaserSight_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "grenadetrail"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "GrenadeTrails_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "grenadeskin"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "GrenadeSkins_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
	else if (StrEqual(type, "glow"))
	{
		fn = GetFunctionByName(INVALID_HANDLE, "Glow_OnPreviewItem");
		if (fn != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, fn);
			Call_PushCell(client);
			Call_PushString(type);
			Call_PushCell(index);
			Call_Finish();
		}
	}
}