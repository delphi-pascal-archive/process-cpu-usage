{Автор Зорков Игорь - zorkovigor@mail.ru}

unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, XPMan, ExtCtrls, StdCtrls;

type
  TForm1 = class(TForm)
    ListView1: TListView;
    XPManifest1: TXPManifest;
    Timer1: TTimer;
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure ListView1CustomDrawItem(Sender: TCustomListView;
      Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
  private
    { Private declarations }
  public
    procedure RefreshInfo;
  end;

type
  NTSTATUS = Integer;

const
  STATUS_SUCCESS = NTSTATUS($00000000);
  STATUS_INFO_LENGTH_MISMATCH = NTSTATUS($C0000004);

type
  UNICODE_STRING = packed record
    Length, MaximumLength: WORD;
    Buffer: PWideChar;
  end;
  PUNICODE_STRING = ^UNICODE_STRING;

  PVOID = Pointer;

  KPRIORITY = Integer;

  CLIENT_ID = packed record
    UniqueProcess: THandle;
    UniqueThread: THandle;
  end;

  THREAD_STATE = Integer;

  _KWAIT_REASON = (
    Executive,
    FreePage,
    PageIn,
    PoolAllocation,
    DelayExecution,
    Suspended,
    UserRequest,
    WrExecutive,
    WrFreePage,
    WrPageIn,
    WrPoolAllocation,
    WrDelayExecution,
    WrSuspended,
    WrUserRequest,
    WrEventPair,
    WrQueue,
    WrLpcReceive,
    WrLpcReply,
    WrVirtualMemory,
    WrPageOut,
    WrRendezvous,
    Spare2,
    Spare3,
    Spare4,
    Spare5,
    Spare6,
    WrKernel,
    MaximumWaitReason);
  KWAIT_REASON = _KWAIT_REASON;

  QWORD = LARGE_INTEGER;

  SYSTEM_THREADS = packed record
    KernelTime: LARGE_INTEGER;
    UserTime: LARGE_INTEGER;
    CreateTime: LARGE_INTEGER;
    WaitTime: ULONG;
    StartAddress: PVOID;
    ClientId: CLIENT_ID;
    Priority: KPRIORITY;
    BasePriority: KPRIORITY;
    ContextSwitchCount: ULONG;
    State: THREAD_STATE;
    WaitReason: Integer;
    Reserved: ULONG;
  end;

  SYSTEM_THREADS_ARRAY = array[0..1024] of SYSTEM_THREADS;
  PSYSTEM_THREADS_ARRAY = ^SYSTEM_THREADS_ARRAY;

  _VM_COUNTERS = packed record
    PeakVirtualSize: ULONG;
    VirtualSize: ULONG;
    PageFaultCount: ULONG;
    PeakWorkingSetSize: ULONG;
    WorkingSetSize: ULONG;
    QuotaPeakPagedPoolUsage: ULONG;
    QuotaPagedPoolUsage: ULONG;
    QuotaPeakNonPagedPoolUsage: ULONG;
    QuotaNonPagedPoolUsage: ULONG;
    PageFileUsage: ULONG;
    PeakPageFileUsage: ULONG;
  end;

  _IO_COUNTERS = packed record
    ReadOperationCount: Int64;
    WriteOperationCount: Int64;
    OtherOperationCount: Int64;
    ReadTransferCount: Int64;
    WriteTransferCount: Int64;
    OtherTransferCount: Int64;
  end;

  SYSTEM_PROCESS_INFORMATION = packed record
    NextEntryDelta: ULONG;
    ThreadCount: ULONG;
    Reserved1: array[0..5] of ULONG;
    CreateTime: FILETIME;
    UserTime: FILETIME;
    KernelTime: FILETIME;
    ProcessName: UNICODE_STRING;
    BasePriority: KPRIORITY;
    ProcessId: ULONG;
    InheritedFromProcessId: ULONG;
    HandleCount: ULONG;
    Reserved2: array[0..1] of ULONG;
    VmCounters: _VM_COUNTERS;
    PrivatePageCount: ULONG;
    IoCounters: _IO_COUNTERS;
    Threads: array[0..1024] of SYSTEM_THREADS;
  end;
  PSYSTEM_PROCESS_INFORMATION = ^SYSTEM_PROCESS_INFORMATION;

  SYSTEM_BASIC_INFORMATION = packed record
    AlwaysZero: ULONG;
    uKeMaximumIncrement: ULONG;
    uPageSize: ULONG;
    uMmNumberOfPhysicalPages: ULONG;
    uMmLowestPhysicalPage: ULONG;
    uMmHighestPhysicalPage: ULONG;
    uAllocationGranularity: ULONG;
    pLowestUserAddress: POINTER;
    pMmHighestUserAddress: POINTER;
    uKeActiveProcessors: POINTER;
    bKeNumberProcessors: byte;
    Filler: array[0..2] of byte;
  end;
  PSYSTEM_BASIC_INFORMATION = ^SYSTEM_BASIC_INFORMATION;

  TNtQuerySystemInformation = function(SystemInformationClass: Longint; SystemInformation: Pointer; SystemInformationLength: ULONG; ReturnLength: PDWORD): Integer; stdcall;

type
  TProcess = record
    Process: string;
    PID: Cardinal;
    CreateTime: FILETIME;
    UserTime: FILETIME;
    KernelTime: FILETIME;
  end;
  TProcesses = array of TProcess;

type
  TProcessInfo = class(TObject)
    Process: string;
    PID: Cardinal;
    CPU, CPUDelta: Extended;
    New, Terminated: Integer;
  end;

var
  Form1: TForm1;
  bRefreshFirstTime: Boolean = True;
  NumberProcessors: Cardinal = 0;
  TickCountOld: Extended = 0;
  TickCount: Extended = 0;
  ProcessInfo: array of TProcessInfo;
  NewPIDList, PIDList, ProcessInfoList: TStringList;
  _NtQuerySystemInformation: TNtQuerySystemInformation;

implementation

{$R *.dfm}

function EnablePrivilege(Privilege: string): Boolean;
var
  TokenHandle: THandle;
  TokenPrivileges: TTokenPrivileges;
  ReturnLength: Cardinal;
begin
  Result:= False;
  if Windows.OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, TokenHandle) then
  begin
    try
      LookupPrivilegeValue(nil, PAnsiChar(Privilege), TokenPrivileges.Privileges[0].Luid);
      TokenPrivileges.PrivilegeCount:= 1;
      TokenPrivileges.Privileges[0].Attributes:= SE_PRIVILEGE_ENABLED;
      if AdjustTokenPrivileges(TokenHandle, False, TokenPrivileges, 0, nil, ReturnLength) then
        Result:= True;
    finally
      CloseHandle(TokenHandle);
    end;
  end;
end;

function GetNumberProcessors: Cardinal;
var
  ReturnLength: DWORD;
  SBI: SYSTEM_BASIC_INFORMATION;
begin
  _NtQuerySystemInformation(0, @SBI, SizeOf(SYSTEM_BASIC_INFORMATION), @ReturnLength);
  Result:= SBI.bKeNumberProcessors;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  NTDLL: HMODULE;
begin
  EnablePrivilege('SeDebugPrivilege');
  ListView1.DoubleBuffered:= True;
  ListView1.Left:= 3;
  ListView1.Top:= 3;
  ListView1.Width:= ClientWidth - 6;
  ListView1.Height:= ClientHeight - 6;
  Font.Name:= 'Microsoft Sans Serif';
  Left:= Screen.Width div 2 - Width div 2;
  Top:= Screen.Height div 2 - Height div 2;
  NewPIDList:= TStringList.Create;
  PIDList:= TStringList.Create;
  ProcessInfoList:= TStringList.Create;
  NTDLL:= LoadLibrary('ntdll.dll');
  if NTDLL <> 0 then
    @_NtQuerySystemInformation:= GetProcAddress(NTDLL, 'NtQuerySystemInformation');
  NumberProcessors:= GetNumberProcessors;
  bRefreshFirstTime:= True;
  TickCountOld:= GetTickCount;
  TickCount:= GetTickCount;
  RefreshInfo;
  Timer1.Enabled:= True;
end;

function UnicodeStringToAnsiString(UString: UNICODE_STRING): AnsiString;
begin
  Result:= WideCharLenToString(UString.Buffer, UString.Length div SizeOf(WideChar));
end;

function GetProcesses(var Processes: TProcesses): Cardinal;
var
  ProcessCount, i: DWORD;
  SystemInformation: Pointer;
  SystemInformationLength: Integer;
  ReturnLength: DWORD;
  ReturnStatus: NTSTATUS;
  PSPI: PSYSTEM_PROCESS_INFORMATION;
begin
  Result:= 0;
  Finalize(Processes);
  SystemInformationLength:= $1000;
  GetMem(SystemInformation, SystemInformationLength);
  ReturnStatus:= _NtQuerySystemInformation(5, SystemInformation, SystemInformationLength, @ReturnLength);
  while (ReturnStatus = STATUS_INFO_LENGTH_MISMATCH) do
  begin
    FreeMem(SystemInformation);
    SystemInformationLength:= SystemInformationLength * 2;
    GetMem(SystemInformation, SystemInformationLength);
    ReturnStatus:= _NtQuerySystemInformation(5, SystemInformation, SystemInformationLength, @ReturnLength);
  end;
  try
    if ReturnStatus = STATUS_SUCCESS then
    begin
      PSPI:= PSYSTEM_PROCESS_INFORMATION(SystemInformation);
      repeat
        SetLength(Processes, Length(Processes) + 1);
        if PSPI^.ProcessId = 0 then
          Processes[Result].Process:= 'System Idle Process'
        else
          Processes[Result].Process:= UnicodeStringToAnsiString(PSPI^.ProcessName);
        Processes[Result].CreateTime:= PSPI^.CreateTime;
        Processes[Result].UserTime:= PSPI^.UserTime;
        Processes[Result].KernelTime:= PSPI^.KernelTime;
        Processes[Result].PID:= PSPI^.ProcessId;
        Inc(Result);
        if PSPI^.NextEntryDelta = 0 then
          Break;
        PSPI:= PSYSTEM_PROCESS_INFORMATION(PAnsiChar(PSPI) + PSPI^.NextEntryDelta);
      until
        False;
    end;
  finally
    FreeMem(SystemInformation);
    SystemInformation:= nil;
  end;
end;

procedure TForm1.RefreshInfo;
var
  i, ProcessCount: Integer;
  Processes: TProcesses;
  CPU, CPUIdle: Extended;
begin
  TickCountOld:= GetTickCount - TickCount;
  TickCount:= GetTickCount;
  ProcessCount:= GetProcesses(Processes);
  NewPIDList.Clear;
  for i:= 0 to ProcessCount - 1 do
    NewPIDList.Add(IntToStr(Processes[i].PID));
  if (NewPIDList.Text <> PIDList.Text) then
  begin
    if NewPIDList.Count > 0 then
    begin
      for i:= 0 to NewPIDList.Count - 1 do
      begin
        if PIDList.IndexOf(NewPIDList.Strings[i]) = -1 then
        begin
          SetLength(ProcessInfo, Length(ProcessInfo) + 1);
          ProcessInfo[ProcessInfoList.Count]:= TProcessInfo.Create;
          ProcessInfo[ProcessInfoList.Count].Process:= Processes[i].Process;
          ProcessInfo[ProcessInfoList.Count].PID:= Processes[i].PID;
          CPU:= Int64(Processes[i].KernelTime.dwLowDateTime or (Processes[i].KernelTime.dwHighDateTime shr 32)) + Int64(Processes[i].UserTime.dwLowDateTime or (Processes[i].UserTime.dwHighDateTime shr 32));
          ProcessInfo[ProcessInfoList.Count].CPU:= CPU;
          ProcessInfo[ProcessInfoList.Count].CPUDelta:= CPU;
          if bRefreshFirstTime then
            ProcessInfo[ProcessInfoList.Count].New:= 2
          else
            ProcessInfo[ProcessInfoList.Count].New:= 0;
          ProcessInfo[ProcessInfoList.Count].Terminated:= 20;
          ProcessInfoList.AddObject(NewPIDList.Strings[i], ProcessInfo[ProcessInfoList.Count]);
        end;
      end;
    end;

    if PIDList.Count > 0 then
    begin
      for i:= 0 to PIDList.Count - 1 do
      begin
        if NewPIDList.IndexOf(PIDList.Strings[i]) = -1 then
        begin
          if ProcessInfoList.IndexOf(PIDList.Strings[i]) <> -1 then
          begin
            if (ProcessInfoList.Objects[ProcessInfoList.IndexOf(PIDList.Strings[i])] as TProcessInfo).Terminated = 20 then
              (ProcessInfoList.Objects[ProcessInfoList.IndexOf(PIDList.Strings[i])] as TProcessInfo).Terminated:= 0;
          end;
        end;
      end;
    end;

    PIDList.Assign(NewPIDList);
  end;

  CPUIdle:= 0;
  for i:= 0 to ProcessCount - 1 do
  begin
    CPU:= Int64(Processes[i].KernelTime.dwLowDateTime or (Processes[i].KernelTime.dwHighDateTime)) + Int64(Processes[i].UserTime.dwLowDateTime or (Processes[i].UserTime.dwHighDateTime));
    (ProcessInfoList.Objects[ProcessInfoList.IndexOf(IntToStr(Processes[i].PID))] as TProcessInfo).CPUDelta:= CPU - (ProcessInfoList.Objects[ProcessInfoList.IndexOf(IntToStr(Processes[i].PID))] as TProcessInfo).CPU;
    (ProcessInfoList.Objects[ProcessInfoList.IndexOf(IntToStr(Processes[i].PID))] as TProcessInfo).CPU:= CPU;
    if Processes[i].PID <> 0 then
      CPUIdle:= CPUIdle + (ProcessInfoList.Objects[ProcessInfoList.IndexOf(IntToStr(Processes[i].PID))] as TProcessInfo).CPUDelta;
  end;
  if CPUIdle > 0 then
    (ProcessInfoList.Objects[ProcessInfoList.IndexOf('0')] as TProcessInfo).CPUDelta:= CPUIdle
  else
    (ProcessInfoList.Objects[ProcessInfoList.IndexOf('0')] as TProcessInfo).CPUDelta:= 100;

  ListView1.Items.BeginUpdate;

  for i:= 0 to ProcessInfoList.Count - 1 do
  begin
    if (ProcessInfoList.Objects[i] as TProcessInfo).New < 2 then
      Inc((ProcessInfoList.Objects[i] as TProcessInfo).New);
    if (ProcessInfoList.Objects[i] as TProcessInfo).Terminated < 2 then
      Inc((ProcessInfoList.Objects[i] as TProcessInfo).Terminated);
  end;

  i:= 0;
  while i < ProcessInfoList.Count do
  begin
    if ((ProcessInfoList.Objects[i] as TProcessInfo).Terminated >= 2) and
      ((ProcessInfoList.Objects[i] as TProcessInfo).Terminated < 20) then
    begin
      ProcessInfoList.Objects[i].Free;
      ProcessInfoList.Delete(i);
      i:= -1;
    end;
    Inc(i);
  end;

  if ListView1.Items.Count < ProcessInfoList.Count then
  begin
    for i:= ListView1.Items.Count to ProcessInfoList.Count - 1 do
    begin
      with ListView1.Items.Add do
      begin
        Caption:= '';
        SubItems.Add('');
        SubItems.Add('');
      end;
    end;
  end
  else if ProcessInfoList.Count < ListView1.Items.Count then
  begin
    for i:= 0 to ListView1.Items.Count - ProcessInfoList.Count - 1 do
    begin
      ListView1.Items.Delete(ListView1.Items.Count - 1);
    end;
  end;

  for i:= 0 to ProcessInfoList.Count - 1 do
  begin
    ListView1.Items.Item[i].Caption:= (ProcessInfoList.Objects[i] as TProcessInfo).Process;
    ListView1.Items.Item[i].SubItems[0]:= IntToStr((ProcessInfoList.Objects[i] as TProcessInfo).PID);
    if ((ProcessInfoList.Objects[i] as TProcessInfo).CPUDelta > 0) then
    begin
      if TickCountOld > 0 then
      begin
        if (ProcessInfoList.Objects[i] as TProcessInfo).PID = 0 then
          ListView1.Items.Item[i].SubItems[1]:= FormatFloat('0.00', 100 - ((ProcessInfoList.Objects[i] as TProcessInfo).CPUDelta / TickCountOld / 100 / NumberProcessors))
        else
          ListView1.Items.Item[i].SubItems[1]:= FormatFloat('0.00', (ProcessInfoList.Objects[i] as TProcessInfo).CPUDelta / TickCountOld / 100 / NumberProcessors);
      end;
    end
    else
      ListView1.Items.Item[i].SubItems[1]:= '';
    if (ProcessInfoList.Objects[i] as TProcessInfo).New < 2 then
      ListView1.Items.Item[i].Data:= Pointer(clLime)
    else if (ProcessInfoList.Objects[i] as TProcessInfo).Terminated < 2 then
      ListView1.Items.Item[i].Data:= Pointer(clRed)
    else
      ListView1.Items.Item[i].Data:= Pointer(clWhite);
  end;

  ListView1.Items.EndUpdate;

  bRefreshFirstTime:= False;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  RefreshInfo;
end;

procedure TForm1.ListView1CustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  Sender.Canvas.Brush.Color:= TColor(Item.Data);
end;

end.

