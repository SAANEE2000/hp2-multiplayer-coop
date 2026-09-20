// Main-menu multiplayer routing. No gameplay state or save data lives here.
class HPMultiplayerPage extends baseFEPage;

var HGameButton CoopButton, VersusButton, HostButton, JoinButton;
var HGameLabelControl ModeLabel, AddressLabel, PortLabel, NameLabel, HintLabel;
var UWindowEditControl AddressEdit, PortEdit, NameEdit;
var string SelectedMode;

function HGameButton AddMenuButton(string Caption, float X, float Y, float W)
{
    local HGameButton B;
    B = HGameButton(CreateControl(Class'HGameButton', X, Y, W, 30));
    B.SetFont(F_HPMenuLarge);
    B.TextColor.R = 250;
    B.TextColor.G = 250;
    B.TextColor.B = 250;
    B.bColorOver = True;
    B.OverColor.R = 250;
    B.OverColor.G = 5;
    B.OverColor.B = 5;
    B.Align = TA_Center;
    B.SetText(Caption);
    B.ToolTipString = Caption;
    return B;
}

function HGameLabelControl AddMenuLabel(string Caption, float X, float Y, float W)
{
    local HGameLabelControl L;
    L = HGameLabelControl(CreateControl(Class'HGameLabelControl', X, Y, W, 24));
    L.SetFont(F_Normal);
    L.TextColor.R = 250;
    L.TextColor.G = 250;
    L.TextColor.B = 250;
    L.SetText(Caption);
    return L;
}

function Created()
{
    Super.Created();
    CreateTitleButton("Multiplayer");
    CreateBackPageButton();
    ModeLabel = AddMenuLabel("Choose a mode", 230, 125, 240);
    CoopButton = AddMenuButton("Co-op campaign", 180, 175, 280);
    VersusButton = AddMenuButton("Versus", 180, 220, 280);
    HostButton = AddMenuButton("Create server", 180, 180, 280);
    JoinButton = AddMenuButton("Connect", 180, 225, 280);
    AddressLabel = AddMenuLabel("Server address", 100, 275, 150);
    PortLabel = AddMenuLabel("Port", 100, 310, 150);
    NameLabel = AddMenuLabel("Player name", 100, 345, 150);
    AddressEdit = UWindowEditControl(CreateControl(Class'UWindowEditControl', 250, 275, 280, 24));
    AddressEdit.SetMaxLength(253);
    AddressEdit.SetValue("127.0.0.1");
    PortEdit = UWindowEditControl(CreateControl(Class'UWindowEditControl', 250, 310, 120, 24));
    PortEdit.SetMaxLength(5);
    PortEdit.SetNumericOnly(True);
    PortEdit.SetValue("7777");
    NameEdit = UWindowEditControl(CreateControl(Class'UWindowEditControl', 250, 345, 200, 24));
    NameEdit.SetMaxLength(23);
    NameEdit.SetValue("Harry");
    HintLabel = AddMenuLabel("", 100, 390, 460);
    ShowModeSelection();
}

function ShowModeSelection()
{
    SelectedMode = "";
    ModeLabel.SetText("Choose a mode");
    CoopButton.ShowWindow();
    VersusButton.ShowWindow();
    HostButton.HideWindow();
    JoinButton.HideWindow();
    AddressLabel.HideWindow();
    AddressEdit.HideWindow();
    PortLabel.HideWindow();
    PortEdit.HideWindow();
    NameLabel.HideWindow();
    NameEdit.HideWindow();
    HintLabel.SetText("Select Co-op or Versus");
}

function SelectMode(string NewMode)
{
    SelectedMode = NewMode;
    ModeLabel.SetText(NewMode $ " - create or connect");
    CoopButton.HideWindow();
    VersusButton.HideWindow();
    HostButton.ShowWindow();
    JoinButton.ShowWindow();
    AddressLabel.ShowWindow();
    AddressEdit.ShowWindow();
    PortLabel.ShowWindow();
    PortEdit.ShowWindow();
    NameLabel.ShowWindow();
    NameEdit.ShowWindow();
    if (NewMode == "Coop")
        HintLabel.SetText("Co-op campaign is experimental. Host port: 7777.");
    else
        HintLabel.SetText("Host port: 7777. Address and port are for Connect.");
}

function bool IsSafeToken(string Value, string Allowed, int MaxLength)
{
    local int I;
    if (Len(Value) < 1 || Len(Value) > MaxLength) return False;
    for (I = 0; I < Len(Value); I++)
        if (InStr(Allowed, Mid(Value, I, 1)) < 0) return False;
    return True;
}

function bool ValidateName()
{
    if (IsSafeToken(NameEdit.GetValue(),
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-", 23))
        return True;
    HintLabel.SetText("Player name: 1-23 letters, digits, _ or -.");
    return False;
}

function string HostMap()
{
    if (SelectedMode == "Coop") return "Ch1Rictusempra.unr";
    if (SelectedMode == "Versus") return "HPV_Entry.unr";
    return "";
}

function string HostGameClass()
{
    if (SelectedMode == "Coop") return "HGame.HPCoopGame";
    if (SelectedMode == "Versus") return "HGame.HPVersusGame";
    return "";
}

function CreateServer()
{
    local string URL;
    if (!ValidateName() || HostMap() == "" || HostGameClass() == "") return;
    URL = HostMap() $ "?game=" $ HostGameClass() $ "?listen?MaxPlayers=2"
        $ "?Name=" $ NameEdit.GetValue();
    if (SelectedMode == "Versus") URL = URL $ "?ScoreLimit=3";
    Log("[MP_MENU] create mode=" $ SelectedMode $ " url=" $ URL);
    FEBook(book).bGamePlaying = True;
    FEBook(book).CloseBook();
    GetPlayerOwner().ConsoleCommand("open " $ URL);
}

function ConnectServer()
{
    local string Host, PortText, URL;
    local int Port;
    if (!ValidateName() || SelectedMode == "") return;
    Host = AddressEdit.GetValue();
    PortText = PortEdit.GetValue();
    if (!IsSafeToken(Host,
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-", 253)
        || Mid(Host, 0, 1) == "." || Right(Host, 1) == ".")
    {
        HintLabel.SetText("Enter an IPv4 address or DNS name without URL options.");
        return;
    }
    if (!IsSafeToken(PortText, "0123456789", 5))
    {
        HintLabel.SetText("Port must contain only digits.");
        return;
    }
    Port = int(PortText);
    if (Port < 1024 || Port > 65535)
    {
        HintLabel.SetText("Port must be 1024-65535.");
        return;
    }
    URL = "unreal://" $ Host $ ":" $ PortText $ "/?Name=" $ NameEdit.GetValue()
        $ "?MPMode=" $ SelectedMode;
    Log("[MP_MENU] connect mode=" $ SelectedMode $ " host=" $ Host $ " port=" $ Port);
    FEBook(book).bGamePlaying = True;
    FEBook(book).CloseBook();
    GetPlayerOwner().ClientTravel(URL, TRAVEL_Absolute, False);
}

function Notify(UWindowDialogControl C, byte E)
{
    Super.Notify(C, E);
    if (E != DE_Click) return;
    if (C == BackPageButton)
    {
        if (SelectedMode != "") ShowModeSelection();
        else FEBook(book).ChangePage(FEBook(book).MainPage);
    }
    else if (C == CoopButton) SelectMode("Coop");
    else if (C == VersusButton) SelectMode("Versus");
    else if (C == HostButton) CreateServer();
    else if (C == JoinButton) ConnectServer();
}

function bool HandleEscFromPage()
{
    if (SelectedMode == "") return False;
    ShowModeSelection();
    return True;
}

function PostSwitchPage()
{
    FEBook(book).bShowMainBack = True;
    FEBook(book).bShowNewBack = True;
}

defaultproperties
{
    PageName="MULTIPLAYER"
}
