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
}