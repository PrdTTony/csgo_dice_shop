#include <sourcemod>
#include <menu-stocks>
#include <clientprefs>
#include <shop>
#include <emitsoundany>


#pragma semicolon 1;
#pragma newdecls required;

#define ACCEPT "#accept"
#define REJECT "#reject"
#define DISABLED "#disabled"

#define CHAT_PREFIX "* \x04[Dices]\x01 -"

#define WINNER_SOUND "ui/coin_pickup_01.wav"
#define LOSER_SOUND "ui/xp_rankdown_02.wav"
#define NOBODY_SOUND "ui/weapon_cant_buy.wav"

ConVar cv_EnablePlugin;
ConVar cv_MinBetValue;
ConVar cv_MaxBetValue;
//ConVar cv_ShowMessages;

Handle Dices_Cookie;

bool AreDicesEnabled[MAXPLAYERS + 1];
bool IsAlreadyPlaying[MAXPLAYERS + 1];

int g_iManualAmount[MAXPLAYERS + 1];
bool g_bTypingAmount[MAXPLAYERS + 1] = false;
int PlayerTarget[MAXPLAYERS + 1];
int iAmount[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Store/Shop: Dices",
	author = "xSLOW",
	description = "Gamble your credits.",
	version = "1.2",
	url = "https://steamcommunity.com/profiles/76561193897443537"
};


public void OnPluginStart()
{
    LoadTranslations("common.phrases");

    cv_EnablePlugin = CreateConVar("sm_dices_enableplugin", "1", "Enable plugin? 1 = true / 0 = false");
    cv_MinBetValue = CreateConVar("sm_dices_minbetvalue", "100", "Min bet value");
    cv_MaxBetValue = CreateConVar("sm_dices_maxbetvalue", "1000000", "Max bet value");
//   cv_ShowMessages = CreateConVar("sm_dices_showmessages", "3", "0 = No messages, 1= Chat Messages, 2= Hint Messages, 3= Chat + Hint messages");

    Dices_Cookie = RegClientCookie("Dices On/Off", "Dices On/Off", CookieAccess_Protected);

    AutoExecConfig(true, "dices");

    if(cv_EnablePlugin.BoolValue)
    {
        
        RegConsoleCmd("sm_dice", Command_MainMenu);     
        RegConsoleCmd("sm_barbut", Command_MainMenu);       

    }
}


public void OnMapStart() {

    if(FileExists(WINNER_SOUND))
    {
        AddFileToDownloadsTable(WINNER_SOUND);
    }

    if(FileExists(LOSER_SOUND))
    {
        AddFileToDownloadsTable(LOSER_SOUND);
    }

    if(FileExists(NOBODY_SOUND))
    {
        AddFileToDownloadsTable(LOSER_SOUND);
    }
	
    PrecacheSound(WINNER_SOUND);
    PrecacheSound(LOSER_SOUND);
    PrecacheSound(NOBODY_SOUND);
}

public void OnClientPutInServer(int client)
{
    AreDicesEnabled[client] = true;
    char buffer[2];
    GetClientCookie(client, Dices_Cookie, buffer, sizeof(buffer));
    if(StrEqual(buffer,"0"))
        AreDicesEnabled[client] = false;
}

public Action Command_MainMenu(int client, int args)
{
	if (client > 0 && args < 1)
	{		
		MainMenu(client).Display(client, 10);	
	}
	return Plugin_Handled;
}

Menu MainMenu(int client)
{
	Menu menu = new Menu(MainMenuHandler);
    menu.SetTitle("➤Dice System™ by TTony x xSlow © \n➤You have: %d credits\n‎ ", Shop_GetClientCredits(client));
    menu.AddItem("challenge", "➤Challenge a player");
    menu.AddItem("diceon", "➤Enable Dice Invites");
    menu.AddItem("diceoff", "➤Disable Dice Invites");
    return menu;
}

Menu ChallengePlayerMenu(int client)
{
	Menu menu = new Menu(ChallengePlayerHandler);
    menu.SetTitle("➤Dice System™ by TTony x xSlow © \n➤You have: %d credits \nChoose a player", Shop_GetClientCredits(client));
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;
            
        char name[MAX_NAME_LENGTH];
        if(!GetClientName(i, name, sizeof(name)))
            continue;
            
        char buffer[10];
        Format(buffer, sizeof(buffer), "%d", GetClientUserId(i));
        
        menu.AddItem(buffer, name);
    }
    return menu;
}

void ChooseMenuBet(int client)
{
	Menu menu = new Menu(ChooseMenuBetHandler);
    menu.SetTitle("➤Dice System™ by TTony x xSlow © \n➤You have: %d credits\n‎", Shop_GetClientCredits(client));
    menu.AddItem("a", "Please type an amount of credits in chat", ITEMDRAW_DISABLED);
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ChooseMenuBetHandler(Menu menu, MenuAction action, int client, int itemNUM)
{
	if (action == MenuAction_Select)
	{
		switch (itemNUM)
		{
			
            case 0:
			{
				if (Shop_GetClientCredits(client) < g_iManualAmount[client])
					PrintToChat(client, " \x07[DICE™] \x01You dont have enough credits to use the Dice System");
            }
            case MenuAction_End:
		    {
			    delete menu;
		    }
	    }
    }
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsClientInGame(client))
			{
				char option[32];
				menu.GetItem(selection, option, sizeof(option));
				if (StrEqual(option, "challenge"))
				{	
					ChallengePlayerMenu(client).Display(client, MENU_TIME_FOREVER);		
				}	
                if (StrEqual(option, "diceoff"))
				{	
					PrintToChat(client, " \x07[DICE™] \x01Dices requests are now \x07disabled.");
	                AreDicesEnabled[client] = false;
	                SetClientCookie(client, Dices_Cookie, "0");
				}	
                if (StrEqual(option, "diceon"))
				{	
					PrintToChat(client, " \x07[DICE™] \x01Dices requests are now \x04enabled.");
	                AreDicesEnabled[client] = true;
	                SetClientCookie(client, Dices_Cookie, "1");
				}	
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public int ChallengePlayerHandler(Menu menu, MenuAction action, int client, int param2)
{   
	switch(action)
	{
		case MenuAction_Select:
		{          
			if(IsClientInGame(client))
			{   
                g_bTypingAmount[client] = true;
                PrintToChat(client, " \x07[DICE™] \x04Please type an amount of credits in chat");
				char info[10];
                menu.GetItem(param2, info, sizeof(info));
                int userid = StringToInt(info);
                int target = GetClientOfUserId(userid);
                PlayerTarget[client] = target;
                if(!target)
                {
                    PrintToChat(client, "Invalid player");
                    return 0;
                }

                ChooseMenuBet(client);	
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}


/*public Action Command_DicesOFF(int client, int args) 
{
	CPrintToChat(client, "%s \x02Dices requests are now disabled.", CHAT_PREFIX);
	AreDicesEnabled[client] = false;
	SetClientCookie(client, Dices_Cookie, "0");
}

public Action Command_DicesON(int client, int args) 
{
	CPrintToChat(client, "%s \x04Dices requests are now enabled.", CHAT_PREFIX);
	AreDicesEnabled[client] = true;
	SetClientCookie(client, Dices_Cookie, "1");
}*/

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (g_bTypingAmount[client])
	{
		if (IsNumeric(sArgs))
		{
		
			//int iMaxAmount = "1000000";
			iAmount[client] = StringToInt(sArgs);
			if (iAmount[client] < 100)
			{
				PrintToChat(client, " \x07[DICE™] \x01Minimum amount of Credits is \x10100");
				return Plugin_Handled;
			}
			else if (iAmount[client] > 1000000)
			{
				PrintToChat(client, " \x07[DICE™] \x01Maximum amount of Credits is \x101000000");
				return Plugin_Handled;
			}
			g_iManualAmount[client] = iAmount[client];
			PrintToChat(client, " \x07[DICE™] \x01You chose \x04%i\x01 Credits to play with",iAmount[client]);

            Command_Dices(client);
		}
		else
			PrintToChat(client, " \x07[DICE™] \x01You can type only numbers..");

        
		g_bTypingAmount[client] = false;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
stock bool IsNumeric(const char[] buffer)
{
	int iLen = strlen(buffer);
	for (int i = 0; i < iLen; i++)
	{
		if (!IsCharNumeric(buffer[i]))
			return false;
	}
	return true;
}

public Action Command_Dices(int client)
{
    int Target = PlayerTarget[client];
    int BetValue = g_iManualAmount[client];

    if (Target == 0 || Target == -1) 
        return Plugin_Handled;  

    if(client == Target)
    {
		PrintToChat(client, " \x07[DICE™] \x01You cant challenge yourself!");
		return Plugin_Handled;
    }

    if(BetValue > cv_MaxBetValue.IntValue || BetValue < cv_MinBetValue.IntValue)
    {
		PrintToChat(client, " \x07[DICE™] \x01Credits bet value range: MIN: 100 credits - MAX: 1.000.000 credits");
		return Plugin_Handled; 
    }

    if(BetValue > Shop_GetClientCredits(client) || BetValue > Shop_GetClientCredits(Target))
    {
		PrintToChat(client, " \x07[DICE™] \x01You/Your opponent dont have enough credits");
		return Plugin_Handled;
    }

    if(IsAlreadyPlaying[client] == true || IsAlreadyPlaying[Target] == true)
    {
		PrintToChat(client, " \x07[DICE™] \x01You/Your opponent already playing");
		return Plugin_Handled;
    }

    if(AreDicesEnabled[client] == false || AreDicesEnabled[Target] == false) 
	{
		PrintToChat(client, " \x07[DICE™] \x01You/Your opponent disabled dices.");
		return Plugin_Handled;
	}


    if(IsClientValid(Target))
    {
        PrintToChat(client, "\x07[DICE™] \x01You have sent an invite to \x04%N \x01(\x07%d \x01credits).", Target, BetValue);
        AskTarget(client, Target, BetValue);
    }

    return Plugin_Handled;
}


public void AskTarget(int client, int target, int BetValue)
{
    IsAlreadyPlaying[client] = true;
    IsAlreadyPlaying[target] = true;

    Menu DicesMenu = new Menu(AskTargetHandler, MENU_ACTIONS_DEFAULT);
    char MenuTitle[50];
    FormatEx(MenuTitle, sizeof(MenuTitle), "➤Dice System™ by TTony x xSlow © \nDices: (%N) [%i Credits]", client, BetValue);
    DicesMenu.SetTitle(MenuTitle);
    DicesMenu.AddItem(DISABLED, "➤Be careful which button do you choose..", ITEMDRAW_DISABLED);
    DicesMenu.AddItem(DISABLED, "➤You risk to lose all your credits...", ITEMDRAW_DISABLED);
    DicesMenu.AddItem(DISABLED, "...by pressing random buttons.", ITEMDRAW_DISABLED);
    DicesMenu.AddItem(DISABLED, "", ITEMDRAW_SPACER);
    DicesMenu.AddItem(ACCEPT, "➤Accept");
    DicesMenu.AddItem(REJECT, "➤Reject");
	
    PushMenuCell(DicesMenu, "Client", client);
    PushMenuCell(DicesMenu, "Target", target);
    PushMenuCell(DicesMenu, "Credits", BetValue);

    DicesMenu.ExitButton = false;
    DicesMenu.Display(target, 15);
}


public int AskTargetHandler(Menu DicesMenu, MenuAction action, int param1, int param2)
{
    int client = GetMenuCell(DicesMenu, "Client");
    int target = GetMenuCell(DicesMenu, "Target");

    switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			DicesMenu.GetItem(param2, info, sizeof(info));
			if(StrEqual(info, ACCEPT))
			{
				PrintToChat(GetMenuCell(DicesMenu, "Client"), " \x07[DICE™] \x04%N \x04accepted\x01 your challenge for \x07%i \x01credits.",param1, GetMenuCell(DicesMenu, "Credits"));
				RollTheDices(GetMenuCell(DicesMenu, "Client"), param1, GetMenuCell(DicesMenu, "Credits"));
			}
			else
            {
                PrintToChat(GetMenuCell(DicesMenu, "Client"), " \x07[DICE™] \x04%N \x07rejected\x01 your challenge for \x07%i \x01credits.", param1, GetMenuCell(DicesMenu, "Credits"));
                IsAlreadyPlaying[client] = false;
                IsAlreadyPlaying[target] = false;
            }
		}
		
		case MenuAction_Cancel:
        {
            PrintToChat(GetMenuCell(DicesMenu, "Client"), " \x07[DICE™] Challenge to \x04%N\x01 was cancelled.", param1);
            IsAlreadyPlaying[client] = false;
            IsAlreadyPlaying[target] = false;
        }
	}
}


public void RollTheDices(int client, int target, int BetValue)
{
    Shop_SetClientCredits(target, Shop_GetClientCredits(target) - BetValue);
    Shop_SetClientCredits(client, Shop_GetClientCredits(client) - BetValue);

    int ClientFirstDice = GetRandomInt(1,6);
    int ClientSecondDice = GetRandomInt(1,6);
    int ClientSumDices = ClientFirstDice + ClientSecondDice;

    int TargetFirstDice = GetRandomInt(1,6);
    int TargetSecondDice = GetRandomInt(1,6);
    int TargetSumDices = TargetFirstDice + TargetSecondDice;

    if(ClientSumDices > TargetSumDices)
    {
        Shop_SetClientCredits(client, Shop_GetClientCredits(client) + BetValue*2);

        PrintToChat(client, " \x07[DICE™] \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 and you \x04won \x10%d credits.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintToChat(target, " \x07[DICE™] \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 and you \x02lost \x10%d credits.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);

        PrintCenterText(client, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> and you <font color='#2FDE0C'>won</font> %d credits.</center>", ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintCenterText(target, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> and you <font color='#F61B01'>lost</font> %d credits.</center>", TargetFirstDice, TargetSecondDice, client, ClientFirstDice, ClientSecondDice, BetValue);

        EmitSoundToClient(client, WINNER_SOUND);
        EmitSoundToClient(target, LOSER_SOUND);
    }
    else if(ClientSumDices < TargetSumDices)
    {

        Shop_SetClientCredits(target, Shop_GetClientCredits(target) + BetValue*2);

        PrintToChat(client, " \x07[DICE™] \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 and you \x02lost \x10%d credits.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintToChat(target, " \x07[DICE™] \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 and you \x04won \x10%d credits.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);

        PrintCenterText(client, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> and you <font color='#F61B01'>lost</font> %d credits.</center>", ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintCenterText(target, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> and you <font color='#2FDE0C'>won</font> %d credits.</center>", TargetFirstDice, TargetSecondDice, client, ClientFirstDice, ClientSecondDice, BetValue);

        EmitSoundToClient(target, WINNER_SOUND);
        EmitSoundToClient(client, LOSER_SOUND);
    }
    else
    {
        Shop_SetClientCredits(target, Shop_GetClientCredits(target) + BetValue);
        Shop_SetClientCredits(client, Shop_GetClientCredits(client) + BetValue);
        
        PrintToChat(client, " \x07[DICE™] \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 but \x02nobody won.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice);
        PrintToChat(target, " \x07[DICE™] \x0DYou\x01 rolled \x03(%d %d)\x01 against \x0D%N\x01 \x03(%d %d)\x01 but \x02nobody won.", CHAT_PREFIX, ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice);

        PrintCenterText(client, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> <font color='#F61B01'>but nobody won.</font></center>", ClientFirstDice, ClientSecondDice, target, TargetFirstDice, TargetSecondDice, BetValue);
        PrintCenterText(target, "<center>You rolled <font color='#F04B03'>(%d %d)</font> against <font color='#00FF8F'>%N</font> <font color='#F04B03'>(%d %d)</font> <font color='#F61B01'>but nobody won.</font></center>", TargetFirstDice, TargetSecondDice, client, ClientFirstDice, ClientSecondDice, BetValue);

        EmitSoundToClient(target, NOBODY_SOUND);
        EmitSoundToClient(client, NOBODY_SOUND);
    }

    IsAlreadyPlaying[client] = false;
    IsAlreadyPlaying[target] = false;
}

bool IsClientValid(int client)
{
    return (0 < client <= MaxClients) && IsClientInGame(client) && !IsFakeClient(client);
}