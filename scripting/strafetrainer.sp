#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define PL_VERSION "2.1.0"

#define GAUGE_MIN     1.0
#define GAUGE_MAX     200.0
#define GAUGE_PERFECT 100.0

#define AIR_SPEED_CAP 30.0

#define HUD_REDRAW_INTERVAL 0.05

#define TAU_SLOW 0.150
#define TAU_FAST 0.060

enum
{
    POS_TOP = 0,
    POS_DISCREET = 1,
    POS_MIDDLE = 2
};

enum
{
    PCTPOS_ABOVE = 0,
    PCTPOS_BELOW = 1
};

enum
{
    SPEED_SLOW = 0,
    SPEED_FAST = 1
};

enum
{
    TCOLOR_DEFAULT = 0,
    TCOLOR_RED,
    TCOLOR_YELLOW,
    TCOLOR_GREEN,
    TCOLOR_BLUE,
    TCOLOR_MAGENTA,
    TCOLOR_PURPLE,
    TCOLOR_PINK,
    TCOLOR_BLACK,
    TCOLOR_RAINBOW,
    TCOLOR_COUNT
};

bool  g_bEnabled[MAXPLAYERS + 1];
bool  g_bStrict[MAXPLAYERS + 1];
bool  g_bTrendMode[MAXPLAYERS + 1];
int   g_iSpeedMode[MAXPLAYERS + 1];
int   g_iPosition[MAXPLAYERS + 1];
int   g_iPctPos[MAXPLAYERS + 1];
int   g_iColourMode[MAXPLAYERS + 1];

float g_flDisplayValue[MAXPLAYERS + 1];
float g_flPrevDisplayValue[MAXPLAYERS + 1];
bool  g_bHasLastYaw[MAXPLAYERS + 1];
float g_flLastYaw[MAXPLAYERS + 1];

Handle g_hCookieEnabled;
Handle g_hCookieStrict;
Handle g_hCookieSpeed;
Handle g_hCookiePosition;
Handle g_hCookiePctPos;
Handle g_hCookieColour;
Handle g_hCookieTrend;

ConVar g_cvAirAccelerate;
ConVar g_cvMaxSpeed;

Handle g_hHudSync;
Handle g_hRedrawTimer;

public Plugin myinfo =
{
    name = "Strafe Trainer",
    author = "Luna",
    description = "Real-time strafe sync trainer HUD for bhop/surf",
    version = PL_VERSION,
    url = ""
};

public void OnPluginStart()
{
    g_hCookieEnabled  = RegClientCookie("st_enabled",  "Strafe trainer enabled",         CookieAccess_Protected);
    g_hCookieStrict   = RegClientCookie("st_strict",   "Strafe trainer strict colours",   CookieAccess_Protected);
    g_hCookieSpeed    = RegClientCookie("st_speed",    "Strafe trainer speed mode",      CookieAccess_Protected);
    g_hCookiePosition = RegClientCookie("st_position", "Strafe trainer HUD position",    CookieAccess_Protected);
    g_hCookiePctPos   = RegClientCookie("st_pctpos",   "Strafe trainer % text position", CookieAccess_Protected);
    g_hCookieColour    = RegClientCookie("st_colour",    "Strafe trainer colour mode",      CookieAccess_Protected);
    g_hCookieTrend     = RegClientCookie("st_trend",      "Strafe trainer trend overlay",    CookieAccess_Protected);

    RegConsoleCmd("sm_strafetrainer", Command_Toggle, "Toggle the strafe trainer HUD on/off");
    RegConsoleCmd("sm_strafetrainersettings", Command_Settings, "Open strafe trainer settings menu");
    RegConsoleCmd("sm_sthud", Command_Settings, "Open strafe trainer settings menu");

    g_cvAirAccelerate = FindConVar("sv_airaccelerate");
    g_cvMaxSpeed = FindConVar("sv_maxspeed");

    g_hHudSync = CreateHudSynchronizer();
    LogMessage("[ST DEBUG] g_hHudSync handle = %d", g_hHudSync);

    g_hRedrawTimer = CreateTimer(HUD_REDRAW_INTERVAL, Timer_Redraw, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    LogMessage("[ST DEBUG] OnPluginStart fired");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            LogMessage("[ST DEBUG] OnPluginStart late-init for client %d (cookies cached: %b)", i, AreClientCookiesCached(i));

            OnClientPutInServer(i);

        }
    }
}

public void OnMapEnd(){
    if (g_hHudSync != INVALID_HANDLE)
        delete g_hHudSync;
    if (g_hRedrawTimer != INVALID_HANDLE)
        delete g_hRedrawTimer;
} //don't know why but this seems to be needed on versions of sourcemod where IsValidHandle does not exist. 

public void OnMapStart()
{
    LogMessage("[ST DEBUG] OnMapStart fired");

    if (g_hHudSync != INVALID_HANDLE) //IsValidHandle deprecated?
        delete g_hHudSync;
    g_hHudSync = CreateHudSynchronizer();
    LogMessage("[ST DEBUG] g_hHudSync handle = %d", g_hHudSync);

    if (g_hRedrawTimer != INVALID_HANDLE)
        delete g_hRedrawTimer;
    g_hRedrawTimer = CreateTimer(HUD_REDRAW_INTERVAL, Timer_Redraw, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    LogMessage("[ST DEBUG] g_hRedrawTimer recreated on map start");
}

public void OnClientPutInServer(int client)
{
    LogMessage("[ST DEBUG] OnClientPutInServer fired for client %d — resetting to defaults", client);

    g_bEnabled[client] = true;
    g_bStrict[client] = false;
    g_iSpeedMode[client] = SPEED_SLOW;
    g_iPosition[client] = POS_TOP;
    g_iPctPos[client] = PCTPOS_ABOVE;
    g_iColourMode[client] = TCOLOR_DEFAULT;
    g_bTrendMode[client] = false;

    g_flDisplayValue[client] = GAUGE_PERFECT;
    g_flPrevDisplayValue[client] = GAUGE_PERFECT;
    g_bHasLastYaw[client] = false;

    if (AreClientCookiesCached(client))
    {
        OnClientCookiesCached(client);
    }
}

public void OnClientCookiesCached(int client)
{
    char buf[8];

    GetClientCookie(client, g_hCookieEnabled, buf, sizeof(buf));
    g_bEnabled[client] = (buf[0] == '\0') ? true : (StringToInt(buf) != 0);

    GetClientCookie(client, g_hCookieStrict, buf, sizeof(buf));
    g_bStrict[client] = (buf[0] == '\0') ? false : (StringToInt(buf) != 0);

    GetClientCookie(client, g_hCookieSpeed, buf, sizeof(buf));
    g_iSpeedMode[client] = (buf[0] == '\0') ? SPEED_SLOW : StringToInt(buf);

    GetClientCookie(client, g_hCookiePosition, buf, sizeof(buf));
    g_iPosition[client] = (buf[0] == '\0') ? POS_TOP : StringToInt(buf);

    GetClientCookie(client, g_hCookiePctPos, buf, sizeof(buf));
    g_iPctPos[client] = (buf[0] == '\0') ? PCTPOS_ABOVE : StringToInt(buf);

    GetClientCookie(client, g_hCookieColour, buf, sizeof(buf));
    g_iColourMode[client] = (buf[0] == '\0') ? TCOLOR_DEFAULT : StringToInt(buf);

    GetClientCookie(client, g_hCookieTrend, buf, sizeof(buf));
    g_bTrendMode[client] = (buf[0] == '\0') ? false : (StringToInt(buf) != 0);

    LogMessage("[ST DEBUG] OnClientCookiesCached fired for client %d — loaded position=%d enabled=%d strict=%d speed=%d pctpos=%d", client, g_iPosition[client], g_bEnabled[client], g_bStrict[client], g_iSpeedMode[client], g_iPctPos[client]);
}

void SaveBoolCookie(int client, Handle cookie, bool value)
{
    char buf[4];
    IntToString(value ? 1 : 0, buf, sizeof(buf));
    SetClientCookie(client, cookie, buf);
}

void SaveIntCookie(int client, Handle cookie, int value)
{
    char buf[4];
    IntToString(value, buf, sizeof(buf));
    SetClientCookie(client, cookie, buf);
}

public Action Command_Toggle(int client, int args)
{
    if (client == 0)
        return Plugin_Handled;

    ShowSettingsMenu(client);
    return Plugin_Handled;
}

public Action Command_Settings(int client, int args)
{
    if (client == 0)
        return Plugin_Handled;

    ShowSettingsMenu(client);
    return Plugin_Handled;
}

void ShowSettingsMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Settings);
    menu.SetTitle("Strafe Trainer Settings");

    char line[64];

    Format(line, sizeof(line), "Enabled: %s", g_bEnabled[client] ? "On" : "Off");
    menu.AddItem("0", line);

    Format(line, sizeof(line), "Strict Colours: %s", g_bStrict[client] ? "On" : "Off");
    menu.AddItem("1", line);

    Format(line, sizeof(line), "Trainer Speed: %s", g_iSpeedMode[client] == SPEED_FAST ? "Fast" : "Slow");
    menu.AddItem("2", line);

    char posLabel[16];
    switch (g_iPosition[client])
    {
        case POS_DISCREET: strcopy(posLabel, sizeof(posLabel), "Discreet");
        case POS_MIDDLE:   strcopy(posLabel, sizeof(posLabel), "Middle");
        default:           strcopy(posLabel, sizeof(posLabel), "Top");
    }
    Format(line, sizeof(line), "Position: %s", posLabel);
    menu.AddItem("3", line);

    Format(line, sizeof(line), "Strafe%% Position: %s", g_iPctPos[client] == PCTPOS_BELOW ? "Below" : "Above");
    menu.AddItem("4", line);

    Format(line, sizeof(line), "Avg Gain%%: %s", g_bTrendMode[client] ? "On" : "Off");
    menu.AddItem("5", line);

    char colourLabel[16];
    switch (g_iColourMode[client])
    {
        case TCOLOR_RED:     strcopy(colourLabel, sizeof(colourLabel), "Red");
        case TCOLOR_YELLOW:  strcopy(colourLabel, sizeof(colourLabel), "Yellow");
        case TCOLOR_GREEN:   strcopy(colourLabel, sizeof(colourLabel), "Green");
        case TCOLOR_BLUE:    strcopy(colourLabel, sizeof(colourLabel), "Blue");
        case TCOLOR_MAGENTA: strcopy(colourLabel, sizeof(colourLabel), "Magenta");
        case TCOLOR_PURPLE:  strcopy(colourLabel, sizeof(colourLabel), "Purple");
        case TCOLOR_PINK:    strcopy(colourLabel, sizeof(colourLabel), "Pink");
        case TCOLOR_BLACK:   strcopy(colourLabel, sizeof(colourLabel), "Black");
        case TCOLOR_RAINBOW: strcopy(colourLabel, sizeof(colourLabel), "Rainbow");
        default:              strcopy(colourLabel, sizeof(colourLabel), "Default");
    }
    Format(line, sizeof(line), "Trainer Colour: %s", colourLabel);
    menu.AddItem("6", line);

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Settings(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        switch (param2)
        {
            case 0:
            {
                g_bEnabled[client] = !g_bEnabled[client];
                SaveBoolCookie(client, g_hCookieEnabled, g_bEnabled[client]);
                if (!g_bEnabled[client])
                    ClearSyncHud(client, g_hHudSync);

                PrintToChat(client, "\x04[Strafe Trainer]\x01 %s", g_bEnabled[client] ? "Enabled" : "Disabled");
            }
            case 1:
            {
                g_bStrict[client] = !g_bStrict[client];
                SaveBoolCookie(client, g_hCookieStrict, g_bStrict[client]);
            }
            case 2:
            {
                g_iSpeedMode[client] = (g_iSpeedMode[client] == SPEED_SLOW) ? SPEED_FAST : SPEED_SLOW;
                SaveIntCookie(client, g_hCookieSpeed, g_iSpeedMode[client]);
            }
            case 3:
            {
                g_iPosition[client] = (g_iPosition[client] + 1) % 3;
                SaveIntCookie(client, g_hCookiePosition, g_iPosition[client]);
                LogMessage("[ST DEBUG] client %d changed position to %d via menu and saved cookie", client, g_iPosition[client]);
            }
            case 4:
            {
                g_iPctPos[client] = (g_iPctPos[client] == PCTPOS_ABOVE) ? PCTPOS_BELOW : PCTPOS_ABOVE;
                SaveIntCookie(client, g_hCookiePctPos, g_iPctPos[client]);
            }
            case 5:
            {
                g_bTrendMode[client] = !g_bTrendMode[client];
                SaveBoolCookie(client, g_hCookieTrend, g_bTrendMode[client]);
            }
            case 6:
            {
                g_iColourMode[client] = (g_iColourMode[client] + 1) % TCOLOR_COUNT;
                SaveIntCookie(client, g_hCookieColour, g_iColourMode[client]);
            }
        }

        ShowSettingsMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
    {
        g_bHasLastYaw[client] = false;
        return Plugin_Continue;
    }

    if (!g_bEnabled[client])
    {
        g_bHasLastYaw[client] = false;
        return Plugin_Continue;
    }

    float yaw = angles[1];

    float dt = GetTickInterval();
    if (dt <= 0.0)
        dt = 0.015;

    bool airborne = !(GetEntityFlags(client) & FL_ONGROUND);
    bool strafing = ((buttons & IN_MOVELEFT) != 0) != ((buttons & IN_MOVERIGHT) != 0) ||
    ((buttons & IN_FORWARD) != 0) != ((buttons & IN_BACK) != 0);
    if (!g_bHasLastYaw[client])
    {
        g_flLastYaw[client] = yaw;
        g_bHasLastYaw[client] = true;
        return Plugin_Continue;
    }

    float deltaYaw = NormalizeAngle(yaw - g_flLastYaw[client]);
    g_flLastYaw[client] = yaw;

    if (!strafing)
    {
        return Plugin_Continue;
    }

    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
    float speed = SquareRoot(velocity[0] * velocity[0] + velocity[1] * velocity[1]);

    if (speed < 1.0)
        return Plugin_Continue;

    float maxspeed = g_cvMaxSpeed.FloatValue;
    float wishspeed = (maxspeed < AIR_SPEED_CAP) ? maxspeed : AIR_SPEED_CAP;

    float idealAngleDeg = airborne ? ArcTangent(wishspeed / speed) * (180.0 / 3.14159265) : 1.188;

    if (idealAngleDeg < 0.01)
        return Plugin_Continue;

    float actualAngleDeg = FloatAbs(deltaYaw);

    float rawRatio = (actualAngleDeg / idealAngleDeg) * 100.0;
    rawRatio = Clamp(rawRatio, GAUGE_MIN, GAUGE_MAX);

    float tau = (g_iSpeedMode[client] == SPEED_FAST) ? TAU_FAST : TAU_SLOW;
    float alpha = 1.0 - Pow(2.718281828, -(dt / tau));

    g_flDisplayValue[client] += alpha * (rawRatio - g_flDisplayValue[client]);

    return Plugin_Continue;
}

public Action Timer_Redraw(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
            continue;

        if (!g_bEnabled[client] || !IsPlayerAlive(client))
        {
            continue;
        }

/*
        bool airborne = !(GetEntityFlags(client) & FL_ONGROUND);
        if (!airborne)
        {
            ClearSyncHud(client, g_hHudSync);
            continue;
        }
*/

        DrawHud(client);
    }

    return Plugin_Continue;
}

void DrawHud(int client)
{
    float value = g_flDisplayValue[client];

    int r, g, b;
    GetTrainerColour(client, value, r, g, b);

    char bar[32];
    BuildBar(value, bar, sizeof(bar));

    char valBuf[16];
    Format(valBuf, sizeof(valBuf), "%.1f%%", value);

    const int PCT_FIELD_WIDTH = 8;
    int padTotal = PCT_FIELD_WIDTH - strlen(valBuf);
    if (padTotal < 0)
        padTotal = 0;
    int padLeft = padTotal / 2;
    int padRight = padTotal - padLeft;

    char pctLine[32];
    strcopy(pctLine, sizeof(pctLine), "");
    for (int i = 0; i < padLeft; i++)
        StrCat(pctLine, sizeof(pctLine), " ");
    StrCat(pctLine, sizeof(pctLine), valBuf);
    for (int i = 0; i < padRight; i++)
        StrCat(pctLine, sizeof(pctLine), " ");

    char full[80];
    if (g_iPctPos[client] == PCTPOS_ABOVE)
    {
        Format(full, sizeof(full), "%s\n%s", pctLine, bar);
    }
    else
    {
        Format(full, sizeof(full), "%s\n%s", bar, pctLine);
    }

    float x, y;
    switch (g_iPosition[client])
    {
        case POS_DISCREET:
        {
            x = -1.0;
            y = 0.60;
        }
        case POS_MIDDLE:
        {
            x = -1.0;
            y = 0.385;
        }
        default:
        {
            x = -1.0;
            y = 0.12;
        }
    }

    SetHudTextParams(x, y, HUD_REDRAW_INTERVAL + 1.0, r, g, b, 255, 0, 0.0, 0.0, 0.0);
    ShowSyncHudText(client, g_hHudSync, full);
}

void BuildBar(float value, char[] outBuf, int maxlen)
{
    const int WIDTH = 21;
    int pos = RoundToNearest(((value - GAUGE_MIN) / (GAUGE_MAX - GAUGE_MIN)) * float(WIDTH - 1));
    pos = pos < 0 ? 0 : (pos > WIDTH - 1 ? WIDTH - 1 : pos);

    char buf[WIDTH + 1];
    for (int i = 0; i < WIDTH; i++)
    {
        if (i == WIDTH / 2)
            buf[i] = '|';
        else
            buf[i] = '-';
    }
    buf[pos] = 'o';
    buf[WIDTH] = '\0';

    Format(outBuf, maxlen, "[%s]", buf);
}

void GetTrainerColour(int client, float value, int &r, int &g, int &b)
{
    switch (g_iColourMode[client])
    {
        case TCOLOR_RED:     { r = 255; g = 0;   b = 0;   }
        case TCOLOR_YELLOW:  { r = 255; g = 255; b = 0;   }
        case TCOLOR_GREEN:   { r = 0;   g = 255; b = 0;   }
        case TCOLOR_BLUE:    { r = 0;   g = 0;   b = 255; }
        case TCOLOR_MAGENTA: { r = 255; g = 0;   b = 255; }
        case TCOLOR_PURPLE:  { r = 128; g = 0;   b = 255; }
        case TCOLOR_PINK:    { r = 255; g = 0;   b = 128; }
        case TCOLOR_BLACK:   { r = 15;  g = 15;  b = 15;  }
        case TCOLOR_RAINBOW:
        {
            float degPerSec = 60.0;
            float raw = GetGameTime() * degPerSec;
            float hue = raw - (float(RoundToFloor(raw / 360.0)) * 360.0);
            HSVtoRGB(hue, 1.0, 1.0, r, g, b);
        }
        default:
        {
            GetTieredColour(value, r, g, b);
        }
    }

    if (g_bTrendMode[client])
    {
        GetTrendColour(client, value, r, g, b);
    }
}

void HSVtoRGB(float h, float s, float v, int &r, int &g, int &b)
{
    float hh = h / 60.0;
    int i = RoundToFloor(hh);
    float f = hh - float(i);
    float p = v * (1.0 - s);
    float q = v * (1.0 - s * f);
    float t = v * (1.0 - s * (1.0 - f));

    float rf, gf, bf;
    switch (i % 6)
    {
        case 0: { rf = v; gf = t; bf = p; }
        case 1: { rf = q; gf = v; bf = p; }
        case 2: { rf = p; gf = v; bf = t; }
        case 3: { rf = p; gf = q; bf = v; }
        case 4: { rf = t; gf = p; bf = v; }
        default: { rf = v; gf = p; bf = q; }
    }

    r = RoundToNearest(rf * 255.0);
    g = RoundToNearest(gf * 255.0);
    b = RoundToNearest(bf * 255.0);
}

void GetTieredColour(float value, int &r, int &g, int &b)
{
    float dist = FloatAbs(value - GAUGE_PERFECT);
    float maxDist = (value < GAUGE_PERFECT) ? (GAUGE_PERFECT - GAUGE_MIN) : (GAUGE_MAX - GAUGE_PERFECT);
    float t = Clamp(dist / maxDist, 0.0, 1.0);

    int cR[5] = {255, 0,   0,   255, 255};
    int cG[5] = {255, 255, 255, 165, 0  };
    int cB[5] = {255, 255, 0,   0,   0  };
    float stops[5] = {0.0, 0.15, 0.35, 0.65, 1.0};

    int idx = 0;
    for (int i = 0; i < 4; i++)
    {
        if (t >= stops[i] && t <= stops[i + 1])
        {
            idx = i;
            break;
        }
    }

    float segT = (t - stops[idx]) / (stops[idx + 1] - stops[idx]);
    r = RoundToNearest(float(cR[idx]) + float(cR[idx + 1] - cR[idx]) * segT);
    g = RoundToNearest(float(cG[idx]) + float(cG[idx + 1] - cG[idx]) * segT);
    b = RoundToNearest(float(cB[idx]) + float(cB[idx + 1] - cB[idx]) * segT);
}

void GetTrendColour(int client, float value, int &r, int &g, int &b)
{
    float prev = g_flPrevDisplayValue[client];

    float prevDist = FloatAbs(prev - GAUGE_PERFECT);
    float curDist = FloatAbs(value - GAUGE_PERFECT);

    float delta = prevDist - curDist;

    g_flPrevDisplayValue[client] = value;

    const float DEADZONE = 0.15;
    const float MAX_DELTA = 4.0;

    if (FloatAbs(delta) < DEADZONE)
    {
        r = 255; g = 255; b = 255;
        return;
    }

    float t = Clamp(FloatAbs(delta) / MAX_DELTA, 0.0, 1.0);
    t = Pow(t, 0.5);

    if (delta > 0.0)
    {
        r = RoundToNearest(255.0 + (0.0 - 255.0) * t);
        g = 255;
        b = RoundToNearest(255.0 + (60.0 - 255.0) * t);
    }
    else
    {
        r = 255;
        g = RoundToNearest(255.0 + (0.0 - 255.0) * t);
        b = RoundToNearest(255.0 + (60.0 - 255.0) * t);
    }
}

void GetGaugeColour(float value, bool strict, int &r, int &g, int &b)
{
    bool isLow = value < GAUGE_PERFECT;
    float t;

    if (isLow)
    {
        float lowRange = GAUGE_PERFECT - GAUGE_MIN;
        t = (GAUGE_PERFECT - value) / lowRange;
    }
    else
    {
        float highRange = GAUGE_MAX - GAUGE_PERFECT;
        t = (value - GAUGE_PERFECT) / highRange;
    }

    // strict = harsher: reaches full saturated colour at half the distance to the extreme
    // non-strict = softer: needs the true 0 or 200 endpoint to reach full saturation
    float band = strict ? 0.2 : 0.4;
    t = Clamp(t / band, 0.0, 1.0);
    t = Pow(t, 0.25);

    int fromR = 255, fromG = 255, fromB = 255;
    int toR, toG, toB;

    if (isLow)
    {
        toR = 40; toG = 120; toB = 255; // blue, closer to value = 0
    }
    else
    {
        toR = 255; toG = 40; toB = 40; // red, closer to value = 200
    }

    r = RoundToNearest(float(fromR) + (float(toR) - float(fromR)) * t);
    g = RoundToNearest(float(fromG) + (float(toG) - float(fromG)) * t);
    b = RoundToNearest(float(fromB) + (float(toB) - float(fromB)) * t);
}

float NormalizeAngle(float angle)
{
    while (angle > 180.0)
        angle -= 360.0;
    while (angle < -180.0)
        angle += 360.0;
    return angle;
}

float Clamp(float val, float min, float max)
{
    if (val < min) return min;
    if (val > max) return max;
    return val;
}
